extends Node

# AI 服务 - 处理对话和总结
# 自动加载单例

signal chat_response_received(response: String)
signal chat_response_completed()
signal chat_fields_extracted(fields: Dictionary)
signal chat_error(error_message: String)
signal summary_completed(summary: String)

# 子模块
var config_loader: Node
var http_client_module: Node
var response_parser: Node
var logger: Node

# HTTP 请求节点
var http_request: HTTPRequest

# 对话状态
var current_conversation: Array = []
var is_chatting: bool = false
var is_first_message: bool = true

# 公共访问器（向后兼容）
var api_key: String:
	get:
		return config_loader.api_key if config_loader else ""

var config: Dictionary:
	get:
		return config_loader.config if config_loader else {}

func _ready():
	# 初始化子模块
	config_loader = preload("res://scripts/ai_config_loader.gd").new()
	add_child(config_loader)
	config_loader.load_all()
	
	http_client_module = preload("res://scripts/ai_http_client.gd").new()
	add_child(http_client_module)
	http_client_module.stream_chunk_received.connect(_on_stream_chunk_received)
	http_client_module.stream_completed.connect(_on_stream_completed)
	http_client_module.stream_error.connect(_on_stream_error)
	
	response_parser = preload("res://scripts/ai_response_parser.gd").new()
	add_child(response_parser)
	response_parser.content_received.connect(_on_content_received)
	response_parser.mood_extracted.connect(_on_mood_extracted)
	
	logger = preload("res://scripts/ai_logger.gd").new()
	add_child(logger)
	
	# 创建 HTTP 请求节点（用于非流式请求）
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func reload_config():
	"""重新加载配置和 API 密钥（公共接口）"""
	if config_loader:
		config_loader.load_all()
		print("AI 配置已重新加载")

func add_to_history(role: String, content: String):
	"""手动添加消息到对话历史"""
	current_conversation.append({"role": role, "content": content})
	print("手动添加到历史: ", role, " - ", content)

func start_chat(user_message: String = "", trigger_mode: String = "user_initiated"):
	"""开始对话"""
	if is_chatting:
		push_warning("正在对话中，请等待...")
		return
	
	if config_loader.api_key.is_empty():
		chat_error.emit("API 密钥未配置")
		return
	
	is_chatting = true
	
	var actual_trigger_mode = trigger_mode if is_first_message else "ongoing"
	
	var prompt_builder = get_node("/root/PromptBuilder")
	var system_prompt = prompt_builder.build_system_prompt(actual_trigger_mode)
	
	var messages = [{"role": "system", "content": system_prompt}]
	
	var max_history = config_loader.config.memory.max_conversation_history
	var history_start = max(0, current_conversation.size() - max_history)
	for i in range(history_start, current_conversation.size()):
		messages.append(current_conversation[i])
	
	if trigger_mode == "user_initiated" and not user_message.is_empty():
		messages.append({"role": "user", "content": user_message})
		current_conversation.append({"role": "user", "content": user_message})
	
	if is_first_message:
		is_first_message = false
	
	_call_chat_api(messages, user_message)

func _call_chat_api(messages: Array, _user_message: String):
	"""调用对话 API"""
	var chat_config = config_loader.config.chat_model
	var url = chat_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + config_loader.api_key
	]
	
	var body = {
		"model": chat_config.model,
		"messages": messages,
		"max_tokens": int(chat_config.max_tokens),
		"temperature": float(chat_config.temperature),
		"top_p": float(chat_config.top_p),
		"stream": true,
		"response_format": {"type": "json_object"}
	}
	
	var json_body = JSON.stringify(body)
	
	logger.log_api_request("CHAT_REQUEST", body, json_body)
	
	response_parser.reset()
	
	http_request.set_meta("messages", messages)
	http_request.set_meta("request_body", body)
	
	var timeout = config_loader.config.chat_model.get("timeout", 30.0)
	http_client_module.start_stream_request(url, headers, json_body, timeout)

func _on_stream_chunk_received(data: String):
	"""处理流式数据块"""
	var is_done = response_parser.process_stream_data(data)
	if is_done:
		_finalize_stream_response()

func _on_stream_completed():
	"""流式请求完成"""
	pass

func _on_stream_error(error_message: String):
	"""流式请求错误"""
	is_chatting = false
	
	if not response_parser.msg_buffer.is_empty():
		print("超时但已收到部分内容，完成处理")
		_finalize_stream_response()
	else:
		print("超时且未收到内容，触发欲言又止")
		current_conversation.append({"role": "assistant", "content": "……"})
		chat_error.emit(error_message)

func _on_content_received(content: String):
	"""接收到新内容"""
	chat_response_received.emit(content)

func _on_mood_extracted(mood_id: int):
	"""mood字段提取完成"""
	_apply_mood_immediately(mood_id)

func _finalize_stream_response():
	"""完成流式响应处理"""
	http_client_module.stop_streaming()
	is_chatting = false
	
	var extracted_fields = response_parser.finalize_response()
	_apply_extracted_fields(extracted_fields)
	
	var full_response = response_parser.get_full_response()
	current_conversation.append({"role": "assistant", "content": full_response})
	
	var messages = http_request.get_meta("messages", [])
	logger.log_api_call("CHAT_RESPONSE", messages, full_response)
	
	chat_response_completed.emit()

func _apply_mood_immediately(mood_id: int):
	"""立即应用mood字段"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var prompt_builder = get_node("/root/PromptBuilder")
	
	var mood_name_en = prompt_builder.get_mood_name_en(mood_id)
	if not mood_name_en.is_empty():
		save_mgr.set_mood(mood_name_en)
		print("实时更新心情: ", mood_name_en, " (ID: ", mood_id, ")")
		chat_fields_extracted.emit({"mood": mood_id})
	else:
		print("警告: 无法找到mood ID对应的英文名称: ", mood_id)

func _apply_extracted_fields(extracted_fields: Dictionary):
	"""应用提取的字段到游戏状态"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# mood字段兜底处理
	if extracted_fields.has("mood") and not extracted_fields.mood == null:
		var mood_id = int(extracted_fields.mood)
		var prompt_builder = get_node("/root/PromptBuilder")
		var mood_name_en = prompt_builder.get_mood_name_en(mood_id)
		if not mood_name_en.is_empty():
			save_mgr.set_mood(mood_name_en)
			print("兜底更新心情: ", mood_name_en, " (ID: ", mood_id, ")")
	
	# 应用will和like字段
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		
		if extracted_fields.has("will"):
			var will_delta = int(extracted_fields.will)
			helpers.modify_willingness(will_delta)
		
		if extracted_fields.has("like"):
			var like_delta = int(extracted_fields.like)
			helpers.modify_affection(like_delta)
	
	# 发送字段提取完成信号
	var fields_without_goto_mood = extracted_fields.duplicate()
	fields_without_goto_mood.erase("goto")
	fields_without_goto_mood.erase("mood")
	if not fields_without_goto_mood.is_empty():
		chat_fields_extracted.emit(fields_without_goto_mood)

func end_chat():
	"""结束对话，调用总结"""
	if current_conversation.is_empty():
		return
	
	var conversation_text = _flatten_conversation()
	_call_summary_api(conversation_text)
	
	current_conversation.clear()
	is_first_message = true

func get_goto_field() -> int:
	"""获取goto字段值"""
	var extracted_fields = response_parser.extracted_fields
	if extracted_fields.has("goto") and extracted_fields.goto != null:
		return int(extracted_fields.goto)
	return -1

func get_pending_goto() -> int:
	"""获取暂存的goto字段值"""
	return response_parser.pending_goto

func set_pending_goto(goto_value: int):
	"""设置暂存的goto字段"""
	response_parser.pending_goto = goto_value

func clear_goto_field():
	"""清除goto字段"""
	response_parser.extracted_fields.erase("goto")

func clear_pending_goto():
	"""清除暂存的goto字段"""
	response_parser.pending_goto = -1

func remove_goto_from_history():
	"""从对话历史中移除最后一条assistant消息的goto字段"""
	if current_conversation.is_empty():
		return
	
	var last_msg = current_conversation[-1]
	if last_msg.role != "assistant":
		return
	
	var content = last_msg.content
	
	# 解析JSON并移除goto字段
	var clean_json = content
	if clean_json.contains("```json"):
		var json_start = clean_json.find("```json") + 7
		clean_json = clean_json.substr(json_start)
	elif clean_json.contains("```"):
		var json_start = clean_json.find("```") + 3
		clean_json = clean_json.substr(json_start)
	
	if clean_json.contains("```"):
		var json_end = clean_json.find("```")
		clean_json = clean_json.substr(0, json_end)
	
	clean_json = clean_json.strip_edges()
	
	var json = JSON.new()
	if json.parse(clean_json) == OK:
		var data = json.data
		if data.has("goto"):
			data.erase("goto")
			# 重新序列化为JSON
			var new_content = JSON.stringify(data)
			current_conversation[-1].content = new_content
			print("已从历史记录中移除goto字段")

func _flatten_conversation() -> String:
	"""扁平化对话历史"""
	var lines = []
	
	var prompt_builder = get_node("/root/PromptBuilder")
	var app_config = prompt_builder._load_app_config()
	var char_name = app_config.get("character_name", "角色")
	
	var save_mgr = get_node("/root/SaveManager")
	var user_name = save_mgr.get_user_name()
	
	for msg in current_conversation:
		if msg.role == "user":
			lines.append("%s：%s" % [user_name, msg.content])
		elif msg.role == "assistant":
			var content = msg.content
			var clean_content = content
			if clean_content.contains("```json"):
				var json_start = clean_content.find("```json") + 7
				clean_content = clean_content.substr(json_start)
			elif clean_content.contains("```"):
				var json_start = clean_content.find("```") + 3
				clean_content = clean_content.substr(json_start)
			
			if clean_content.contains("```"):
				var json_end = clean_content.find("```")
				clean_content = clean_content.substr(0, json_end)
			
			clean_content = clean_content.strip_edges()
			
			var json = JSON.new()
			if json.parse(clean_content) == OK:
				var data = json.data
				if data.has("msg"):
					content = data.msg
			
			lines.append("%s：%s" % [char_name, content])
	
	return "\n".join(lines)

func _call_summary_api(conversation_text: String):
	"""调用总结 API"""
	var summary_config = config_loader.config.summary_model
	var url = summary_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + config_loader.api_key
	]
	
	# 获取角色和用户信息用于占位符替换
	var save_mgr = get_node("/root/SaveManager")
	var helpers = get_node("/root/EventHelpers")
	var char_name = helpers.get_character_name()
	var user_name = save_mgr.get_user_name()
	var user_address = save_mgr.get_user_address()
	
	# 替换system_prompt中的占位符
	var system_prompt = summary_config.system_prompt
	system_prompt = system_prompt.replace("{character_name}", char_name)
	system_prompt = system_prompt.replace("{user_name}", user_name)
	system_prompt = system_prompt.replace("{user_address}", user_address)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": conversation_text}
	]
	
	var body = {
		"model": summary_config.model,
		"messages": messages,
		"max_tokens": int(summary_config.max_tokens),
		"temperature": float(summary_config.temperature),
		"top_p": float(summary_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	logger.log_api_request("SUMMARY_REQUEST", body, json_body)
	
	http_request.set_meta("request_type", "summary")
	http_request.set_meta("request_body", body)
	http_request.set_meta("messages", messages)
	http_request.set_meta("conversation_text", conversation_text)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("总结请求失败: " + str(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""HTTP 请求完成回调"""
	var request_type = http_request.get_meta("request_type", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		chat_error.emit("请求失败: " + str(result))
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "API 错误 (%d): %s" % [response_code, error_text]
		print(error_msg)
		chat_error.emit(error_msg)
		
		var request_body = http_request.get_meta("request_body", {})
		logger.log_api_error(response_code, error_text, request_body)
		return
	
	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		push_error("响应解析失败")
		return
	
	if request_type == "summary":
		_handle_summary_response(json.data)
	elif request_type == "relationship":
		_handle_relationship_response(json.data)

func _handle_summary_response(response: Dictionary):
	"""处理总结响应"""
	if not response.has("choices") or response.choices.is_empty():
		push_error("总结响应格式错误")
		return
	
	var message = response.choices[0].message
	var summary = message.content
	
	var messages = http_request.get_meta("messages", [])
	logger.log_api_call("SUMMARY_RESPONSE", messages, summary)
	
	var conversation_text = http_request.get_meta("conversation_text", "")
	
	_save_memory_and_diary(summary, conversation_text)
	
	summary_completed.emit(summary)

func _save_memory_and_diary(summary: String, conversation_text: String):
	"""保存记忆到存档，同时保存总结和详细对话到日记"""
	var save_mgr = get_node("/root/SaveManager")
	
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": [],
			"accumulated_summary_count": 0,
			"relationship_history": []
		}
	
	if not save_mgr.save_data.ai_data.has("accumulated_summary_count"):
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
	else:
		save_mgr.save_data.ai_data.accumulated_summary_count = int(save_mgr.save_data.ai_data.accumulated_summary_count)
	
	if not save_mgr.save_data.ai_data.has("relationship_history"):
		save_mgr.save_data.ai_data.relationship_history = []
	
	var timestamp = Time.get_datetime_string_from_system()
	var cleaned_summary = summary.strip_edges()
	
	var memory_item = {
		"timestamp": timestamp,
		"content": cleaned_summary
	}
	
	save_mgr.save_data.ai_data.memory.append(memory_item)
	save_mgr.save_data.ai_data.accumulated_summary_count += 1
	
	var max_items = config_loader.config.memory.max_memory_items
	if save_mgr.save_data.ai_data.memory.size() > max_items:
		save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)
	
	save_mgr.save_game(save_mgr.current_slot)
	
	logger.save_to_diary(cleaned_summary, conversation_text)
	
	print("记忆已保存: ", summary)
	
	_call_address_api(conversation_text)
	
	if save_mgr.save_data.ai_data.accumulated_summary_count >= max_items:
		print("累计条目数达到上限，调用关系模型...")
		_call_relationship_api()
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
		save_mgr.save_game(save_mgr.current_slot)

func _call_address_api(conversation_text: String):
	"""调用称呼模型 API"""
	var summary_config = config_loader.config.summary_model
	var url = summary_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + config_loader.api_key
	]
	
	var prompt_builder = get_node("/root/PromptBuilder")
	var app_config = prompt_builder._load_app_config()
	var char_name = app_config.get("character_name", "角色")
	
	var save_mgr = get_node("/root/SaveManager")
	var user_name = save_mgr.get_user_name()
	var current_address = save_mgr.get_user_address()
	
	var system_prompt = summary_config.address_system_prompt.replace("{character_name}", char_name).replace("{user_name}", user_name).replace("{current_address}", current_address)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": conversation_text}
	]
	
	var body = {
		"model": summary_config.model,
		"messages": messages,
		"max_tokens": int(summary_config.max_tokens),
		"temperature": float(summary_config.temperature),
		"top_p": float(summary_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	logger.log_api_request("ADDRESS_REQUEST", body, json_body)
	
	var address_request = HTTPRequest.new()
	add_child(address_request)
	address_request.request_completed.connect(_on_address_request_completed)
	
	address_request.set_meta("request_type", "address")
	address_request.set_meta("request_body", body)
	address_request.set_meta("messages", messages)
	
	var error = address_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("称呼模型请求失败: " + str(error))
		address_request.queue_free()

func _on_address_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""称呼模型请求完成回调"""
	var address_request = null
	for child in get_children():
		if child is HTTPRequest and child.has_meta("request_type") and child.get_meta("request_type") == "address":
			address_request = child
			break
	
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
	"""处理称呼模型响应"""
	if not response.has("choices") or response.choices.is_empty():
		push_error("称呼模型响应格式错误")
		return
	
	var message = response.choices[0].message
	var new_address = message.content.strip_edges()
	
	var messages = address_request.get_meta("messages", [])
	logger.log_api_call("ADDRESS_RESPONSE", messages, new_address)
	
	var save_mgr = get_node("/root/SaveManager")
	save_mgr.set_user_address(new_address)
	
	print("称呼已更新: ", new_address)

func _call_relationship_api():
	"""调用关系模型 API"""
	var relationship_config = config_loader.config.relationship_model
	var url = relationship_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + config_loader.api_key
	]
	
	var prompt_builder = get_node("/root/PromptBuilder")
	var current_relationship = prompt_builder.get_relationship_context()
	var memory_context = prompt_builder.get_memory_context()
	
	var system_prompt = relationship_config.system_prompt.replace("{relationship}", current_relationship)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": memory_context}
	]
	
	var body = {
		"model": relationship_config.model,
		"messages": messages,
		"max_tokens": int(relationship_config.max_tokens),
		"temperature": float(relationship_config.temperature),
		"top_p": float(relationship_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	logger.log_api_request("RELATIONSHIP_REQUEST", body, json_body)
	
	http_request.set_meta("request_type", "relationship")
	http_request.set_meta("request_body", body)
	http_request.set_meta("messages", messages)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("关系模型请求失败: " + str(error))

func _handle_relationship_response(response: Dictionary):
	"""处理关系模型响应"""
	if not response.has("choices") or response.choices.is_empty():
		push_error("关系模型响应格式错误")
		return
	
	var message = response.choices[0].message
	var relationship_summary = message.content
	
	var messages = http_request.get_meta("messages", [])
	logger.log_api_call("RELATIONSHIP_RESPONSE", messages, relationship_summary)
	
	_save_relationship(relationship_summary)
	
	print("关系模型已更新: ", relationship_summary)

func _save_relationship(relationship_summary: String):
	"""保存关系信息到存档"""
	var save_mgr = get_node("/root/SaveManager")
	
	if not save_mgr.save_data.ai_data.has("relationship_history"):
		save_mgr.save_data.ai_data.relationship_history = []
	
	var timestamp = Time.get_datetime_string_from_system()
	var cleaned_summary = relationship_summary.strip_edges()
	
	var relationship_item = {
		"timestamp": timestamp,
		"content": cleaned_summary
	}
	
	save_mgr.save_data.ai_data.relationship_history.append(relationship_item)
	
	var max_relationship_history = config_loader.config.memory.get("max_relationship_history", 2)
	if save_mgr.save_data.ai_data.relationship_history.size() > max_relationship_history:
		save_mgr.save_data.ai_data.relationship_history = save_mgr.save_data.ai_data.relationship_history.slice(-max_relationship_history)
	
	save_mgr.save_game(save_mgr.current_slot)
	
	print("关系信息已保存: ", relationship_summary)
