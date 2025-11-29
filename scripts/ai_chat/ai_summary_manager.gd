extends Node

# Summary manager: handles summary API calls, address extraction and saving memory/diary

var owner_service: Node = null
var config_loader: Node = null
var logger: Node = null

func _init():
	pass

func call_summary_api_with_data(conversation_text: String, conversation_data: Array):
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

	var error = owner_service.http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("Summary 请求失败: " + str(error))

func handle_summary_response(response: Dictionary):
	if not response.has("choices") or response.choices.is_empty():
		push_error("Summary response format error")
		owner_service._handle_summary_failure("总结响应格式错误")
		return

	var message = response.choices[0].message
	var summary = message.content

	var messages = owner_service.http_request.get_meta("messages", [])
	if logger:
		logger.log_api_call("SUMMARY_RESPONSE", messages, summary)

	var conversation_text = owner_service.http_request.get_meta("conversation_text", "")
	var conversation_data = owner_service.http_request.get_meta("conversation_data", [])

	var timestamp = null
	if not conversation_data.is_empty():
		for i in range(conversation_data.size() - 1, -1, -1):
			if conversation_data[i].has("timestamp"):
				timestamp = conversation_data[i].timestamp
				break

	await _save_memory_and_diary(summary, conversation_text, timestamp)

	# call tuple and relationship via owner's managers
	owner_service.tuple_manager.call_tuple_model(summary, conversation_text, timestamp)

	# after successful summary, clear context via owner
	owner_service._clear_conversation_context()

	owner_service.pending_summary_data.clear()
	owner_service.summary_retry_count = 0

	owner_service._delete_temp_conversation()

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

	owner_service._call_address_api(conversation_text)

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
	elif conversation_count <= 8:
		return 90
	else:
		return 110

# handle address request created here
func on_address_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	# Try to find the address HTTPRequest under owner_service (not this manager)
	var address_request: HTTPRequest = null
	if owner_service:
		for child in owner_service.get_children():
			if child is HTTPRequest and child.has_meta("request_type") and child.get_meta("request_type") == "address":
				address_request = child
				break
	else:
		push_error("SummaryManager: owner_service not set when handling address response")
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("称呼模型请求失败: " + str(result))
		if address_request:
			address_request.queue_free()
		return

	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "称呼模型API错误 (%d): %s" % [response_code, error_text]
		print(error_msg)
		if address_request:
			address_request.queue_free()
		return

	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		push_error("称呼模型响应解析失败")
		if address_request:
			address_request.queue_free()
		return

	_handle_address_response(json.data, address_request)

	if address_request:
		address_request.queue_free()

func _handle_address_response(response: Dictionary, address_request: HTTPRequest):
	if not response.has("choices") or response.choices.is_empty():
		push_error("称呼模型响应格式错误")
		return

	var message = response.choices[0].message
	var new_address = message.content.strip_edges()

	var messages = []
	# Safely obtain messages meta: prefer the request node, fall back to owner_service.http_request
	if address_request and address_request.has_meta("messages"):
		messages = address_request.get_meta("messages", [])
	elif owner_service and owner_service.http_request and owner_service.http_request.has_meta("messages"):
		messages = owner_service.http_request.get_meta("messages", [])

	if logger:
		logger.log_api_call("ADDRESS_RESPONSE", messages, new_address)

	var save_mgr = owner_service.get_node("/root/SaveManager")
	var char_name = save_mgr.get_character_name()
	if new_address.contains(char_name):
		print("称呼模型返回包含角色名 '%s'，判定为错误，抛弃此次更新: %s" % [char_name, new_address])
		return
	save_mgr.set_user_address(new_address)
	print("称呼已更新: ", new_address)
