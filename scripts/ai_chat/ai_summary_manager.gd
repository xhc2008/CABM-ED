extends Node

# Summary manager: handles summary API calls, address extraction and saving memory/diary

var owner_service: Node = null
var config_loader: Node = null
var logger: Node = null

func _init():
	pass

func call_summary_api_with_data(conversation_text: String, conversation_data: Array, auto_save: bool = false):
	if not owner_service:
		push_error("SummaryManager: owner_service not set")
		return

	var summary_config = owner_service.config_loader.config.summary_model
	var model = summary_config.model
	var base_url = summary_config.base_url

	if model.is_empty() or base_url.is_empty():
		push_error("总结模型配置不完整 (SummaryManager)")
		owner_service._handle_summary_failure("总结模型配置不完整")
		return

	var url = base_url + "/chat/completions"
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + owner_service.config_loader.api_key]

	var save_mgr = owner_service.get_node("/root/SaveManager")
	var helpers = owner_service.get_node_or_null("/root/EventHelpers")
	var char_name = helpers.get_character_name() if helpers else ""
	var user_name = save_mgr.get_user_name()
	var user_address = save_mgr.get_user_address()

	var conversation_count = conversation_data.size()
	var word_limit = _calculate_word_limit(conversation_count)

	var summary_params = summary_config.summary
	var system_prompt = summary_params.system_prompt
	system_prompt = system_prompt.replace("{character_name}", char_name)
	system_prompt = system_prompt.replace("{user_name}", user_name)
	system_prompt = system_prompt.replace("{user_address}", user_address)
	system_prompt = system_prompt.replace("{word_limit}", str(word_limit))

	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": conversation_text}
	]

	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": int(summary_params.max_tokens),
		"temperature": float(summary_params.temperature),
		"top_p": float(summary_params.top_p)
	}

	var json_body = JSON.stringify(body)

	if logger:
		logger.log_api_request("SUMMARY_REQUEST", body, json_body)

	# If owner's http_request busy, cancel it first (same behavior as before)
	if owner_service.http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		owner_service.http_request.cancel_request()
		await owner_service.get_tree().process_frame

	owner_service.http_request.set_meta("request_type", "summary")
	owner_service.http_request.set_meta("request_body", body)
	owner_service.http_request.set_meta("messages", messages)
	owner_service.http_request.set_meta("conversation_text", conversation_text)
	owner_service.http_request.set_meta("conversation_data", conversation_data)
	owner_service.http_request.set_meta("auto_save", auto_save)

	var error = owner_service.http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("Summary 请求失败: " + str(error))

func handle_summary_response(response: Dictionary):
	if not response.has("choices") or response.choices.is_empty():
		push_error("Summary response format error")
		owner_service._handle_summary_failure("总结响应格式错误")
		return

	var message = response.choices[0].message
	var content = message.content

	var messages = owner_service.http_request.get_meta("messages", [])
	if logger:
		logger.log_api_call("SUMMARY_RESPONSE", messages, content)

	# 移除可能的 ```json``` 或 ``` 标记
	var cleaned_content = content.strip_edges()
	if cleaned_content.begins_with("```json"):
		cleaned_content = cleaned_content.substr(7)
	elif cleaned_content.begins_with("```"):
		cleaned_content = cleaned_content.substr(3)
	if cleaned_content.ends_with("```"):
		cleaned_content = cleaned_content.substr(0, cleaned_content.length() - 3)
	cleaned_content = cleaned_content.strip_edges()

	# 解析 JSON
	var json = JSON.new()
	if json.parse(cleaned_content) != OK:
		push_error("总结响应 JSON 解析失败: " + cleaned_content)
		owner_service._handle_summary_failure("总结响应 JSON 解析失败")
		return

	var data = json.data
	if not data.has("summary"):
		push_error("总结响应缺少 summary 字段")
		owner_service._handle_summary_failure("总结响应格式错误")
		return

	var summary = data.summary
	var new_address = data.get("address", "")

	var conversation_text = owner_service.http_request.get_meta("conversation_text", "")
	var conversation_data = owner_service.http_request.get_meta("conversation_data", [])

	var timestamp = null
	if not conversation_data.is_empty():
		for i in range(conversation_data.size() - 1, -1, -1):
			if conversation_data[i].has("timestamp"):
				timestamp = conversation_data[i].timestamp
				break

	# 如果是自动保存或任意保存，记录最后被总结的消息时间戳，便于上层避免重复总结
	var is_auto = false
	if owner_service.http_request.has_meta("auto_save"):
		is_auto = bool(owner_service.http_request.get_meta("auto_save", false))

	if timestamp != null:
		# 记录为 owner_service 的 last_summarized_timestamp，无论是否为自动保存
		owner_service.last_summarized_timestamp = float(timestamp)

	# 处理称呼更新
	_handle_address_update(new_address, conversation_text)

	await _save_memory_and_diary(summary, conversation_text, timestamp)

	# call tuple and relationship via owner's managers
	owner_service.tuple_manager.call_tuple_model(summary, conversation_text, timestamp)

	# 根据是否为自动保存(auto_save)决定是否清理会话上下文

	if not is_auto:
		# 非自动保存：执行原有的清理和后续流程
		owner_service._clear_conversation_context()
		owner_service.pending_summary_data.clear()
		owner_service.summary_retry_count = 0
		owner_service._delete_temp_conversation()
	else:
		# 自动保存：不要清除全局上下文，仅清除 pending_summary 并更新临时文件
		owner_service.pending_summary_data.clear()
		owner_service.summary_retry_count = 0
		owner_service._save_temp_conversation()

	# 通知 owner summary 完成（无论是否自动保存）
	owner_service.summary_completed.emit(summary)

func _save_memory_and_diary(summary: String, conversation_text: String, custom_timestamp = null):
	var save_mgr = owner_service.get_node("/root/SaveManager")

	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {"memory": [], "accumulated_summary_count": 0, "relationship_history": []}

	if not save_mgr.save_data.ai_data.has("accumulated_summary_count"):
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
	else:
		save_mgr.save_data.ai_data.accumulated_summary_count = int(save_mgr.save_data.ai_data.accumulated_summary_count)

	if not save_mgr.save_data.ai_data.has("relationship_history"):
		save_mgr.save_data.ai_data.relationship_history = []

	var unified_saver = owner_service.get_node_or_null("/root/UnifiedMemorySaver")
	if unified_saver:
		await unified_saver.save_memory(summary, unified_saver.MemoryType.CHAT, custom_timestamp, conversation_text, {})
	else:
		var timestamp: String
		if custom_timestamp != null:
			var timezone_offset = owner_service._get_timezone_offset()
			var local_dict = Time.get_datetime_dict_from_unix_time(int(custom_timestamp + timezone_offset))
			timestamp = "%04d-%02d-%02dT%02d:%02d:%02d" % [local_dict.year, local_dict.month, local_dict.day, local_dict.hour, local_dict.minute, local_dict.second]
		else:
			timestamp = owner_service._get_local_datetime_string()

		var cleaned_summary = summary.strip_edges()
		var memory_item = {"timestamp": timestamp, "content": cleaned_summary}
		save_mgr.save_data.ai_data.memory.append(memory_item)

		var max_items = owner_service.config_loader.config.memory.max_memory_items
		if save_mgr.save_data.ai_data.memory.size() > max_items:
			save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)

		save_mgr.save_game(save_mgr.current_slot)

		if logger:
			logger.save_to_diary(cleaned_summary, conversation_text, custom_timestamp)

		if owner_service.has_node("/root/MemoryManager"):
			var memory_mgr = owner_service.get_node("/root/MemoryManager")
			await memory_mgr.add_conversation_summary(cleaned_summary, {}, timestamp)

	save_mgr.save_data.ai_data.accumulated_summary_count += 1

	var max_memory_items = owner_service.config_loader.config.memory.max_memory_items
	if save_mgr.save_data.ai_data.accumulated_summary_count >= max_memory_items:
		print("累计条目数达到上限，调用关系模型...")
		owner_service.relationship_manager.call_relationship_api()
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
		save_mgr.save_game(save_mgr.current_slot)

func _calculate_word_limit(conversation_count: int) -> int:
	if conversation_count <= 2:
		return 30
	elif conversation_count <= 4:
		return 50
	elif conversation_count <= 6:
		return 70
	elif conversation_count <= 9:
		return 90
	elif conversation_count <= 12:
		return 110
	elif conversation_count <= 15:
		return 130
	else:
		return 150

func _handle_address_update(new_address: String, conversation_text: String):
	if new_address.is_empty():
		print("称呼字段为空，不更新")
		return

	new_address = new_address.strip_edges()
	
	var save_mgr = owner_service.get_node("/root/SaveManager")
	var char_name = save_mgr.get_character_name()
	var user_name = save_mgr.get_user_name()
	var current_address = save_mgr.get_user_address()

	# 抛弃机制1：包含角色名
	if new_address.contains(char_name):
		print("称呼包含角色名 '%s'，判定为错误，抛弃此次更新: %s" % [char_name, new_address])
		return

	# 抛弃机制2：AI判断结果为用户名，且当前称呼不为用户名，且对话中没有出现用户名
	if new_address == user_name and current_address != user_name:
		# 检查对话中是否出现用户名（排除前面的"{用户名}: "格式）
		var conversation_lines = conversation_text.split("\n")
		var user_name_mentioned = false
		for line in conversation_lines:
			# 移除开头的 "{用户名}: " 格式
			var cleaned_line = line
			if cleaned_line.begins_with(user_name):
				cleaned_line = cleaned_line.substr(user_name.length())
			
			# 检查剩余内容是否包含用户名
			if cleaned_line.contains(user_name):
				print("[称呼判断]:对话内容包含用户名")
				user_name_mentioned = true
				break
		
		if not user_name_mentioned:
			print("AI判断称呼为用户名 '%s'，但当前称呼不是用户名且对话中未提及，抛弃此次更新" % user_name)
			return

	# 通过所有检查，更新称呼
	save_mgr.set_user_address(new_address)
	print("称呼已更新: ", new_address)
