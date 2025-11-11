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
var last_conversation_time: float = 0.0 # 上次对话结束时间（Unix时间戳）
var temp_conversation_file: String = "user://temp_conversation.json" # 临时对话文件路径

# 总结重试机制
var summary_retry_count: int = 0
var max_summary_retries: int = 3
var summary_retry_delay: float = 2.0 # 重试延迟（秒）
var pending_summary_data: Dictionary = {} # 待总结的数据

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
	
	# 检查断点恢复
	_check_and_recover_interrupted_conversation()

func reload_config():
	"""重新加载配置和 API 密钥（公共接口）"""
	if config_loader:
		config_loader.load_all()
		print("AI 配置已重新加载")

func add_to_history(role: String, content: String):
	"""手动添加消息到对话历史"""
	var timestamp = Time.get_unix_time_from_system()
	current_conversation.append({"role": role, "content": content, "timestamp": timestamp})
	_save_temp_conversation()
	print("手动添加到历史: ", role, " - ", content)

func start_chat(user_message: String = "", trigger_mode: String = "user_initiated"):
	"""开始对话"""
	if is_chatting:
		push_warning("正在对话中，请等待...")
		return
	
	if config_loader.api_key.is_empty():
		chat_error.emit("API 密钥未配置")
		return
	
	# 只在新对话开始时检查是否需要清除上下文（距上次对话超过5分钟）
	if is_first_message:
		var current_time = Time.get_unix_time_from_system()
		if last_conversation_time > 0 and (current_time - last_conversation_time) > 300: # 5分钟 = 300秒
			print("距上次对话超过5分钟，清除全部上下文")
			current_conversation.clear()
	
	is_chatting = true
	
	var actual_trigger_mode = trigger_mode if is_first_message else "ongoing"
	
	var prompt_builder = get_node("/root/PromptBuilder")
	
	# 使用包含长期记忆的系统提示词
	var system_prompt: String
	if trigger_mode == "user_initiated" and not user_message.is_empty():
		# 用户主动对话，使用用户消息检索记忆
		print("检索长期记忆，查询: %s" % user_message.substr(0, 50))
		system_prompt = await prompt_builder.build_system_prompt_with_long_term_memory(actual_trigger_mode, user_message)
	else:
		# 其他情况（主动对话、继续对话等），使用基础提示词
		system_prompt = prompt_builder.build_system_prompt(actual_trigger_mode)
	
	var messages = [ {"role": "system", "content": system_prompt}]
	
	# 限制发送给对话模型的上下文数量（最多 max_conversation_history 条）
	var max_history = config_loader.config.memory.get("max_conversation_history", 10)
	var start_index = max(0, current_conversation.size() - max_history)
	var history_to_send = current_conversation.slice(start_index)
	
	print("开始对话，当前上下文总数: %d, 发送: %d 条（最多%d条）" % [current_conversation.size(), history_to_send.size(), max_history])
	for i in range(history_to_send.size()):
		var msg = {"role": history_to_send[i].role, "content": history_to_send[i].content}
		messages.append(msg)
	
	if trigger_mode == "user_initiated" and not user_message.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		messages.append({"role": "user", "content": user_message})
		current_conversation.append({"role": "user", "content": user_message, "timestamp": timestamp})
		_save_temp_conversation()
		print("添加用户消息到历史，当前上下文数量: %d" % current_conversation.size())
	
	# 检查最后一个消息是否为assistant，如果是则添加user占位符
	# 注意：这个占位符只用于API调用，不记录到历史中
	var last_role = messages[-1].role if messages.size() > 0 else ""
	if last_role == "assistant":
		messages.append({"role": "user", "content": "继续"})
		print("检测到最后一条消息为assistant，添加user占位符以避免前缀独写")
	elif last_role == "system":
		# 主动对话时，如果没有历史记录，添加一个空的user消息作为触发
		# 避免messages数组只有system消息导致API错误
		messages.append({"role": "user", "content": " "})
		print("主动对话且无历史记录，添加空user消息作为触发")
	
	if is_first_message:
		is_first_message = false
	
	_call_chat_api(messages, user_message)

func _call_chat_api(messages: Array, _user_message: String):
	"""调用对话 API"""
	# 验证messages数组的有效性
	if messages.is_empty():
		push_error("错误: messages数组为空")
		chat_error.emit("消息数组为空")
		is_chatting = false
		return
	
	# 验证最后一条消息不是assistant（OpenAI API要求）
	var last_msg = messages[-1]
	if last_msg.role == "assistant":
		push_error("错误: messages数组最后一条消息是assistant，这会导致400错误")
		# 添加一个占位符user消息
		messages.append({"role": "user", "content": "继续"})
		print("紧急修复: 添加user占位符以避免API错误")
	
	# 验证消息内容不为null
	for i in range(messages.size()):
		if not messages[i].has("content") or messages[i].content == null:
			messages[i].content = ""
			print("警告: 修复了第%d条消息的空content" % i)
	
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
	
	# 验证JSON是否有效
	var test_parse = JSON.new()
	if test_parse.parse(json_body) != OK:
		push_error("错误: 生成的JSON无效: " + test_parse.get_error_message())
		chat_error.emit("JSON序列化失败")
		is_chatting = false
		return
	
	logger.log_api_request("CHAT_REQUEST", body, json_body)
	
	# 额外的调试信息
	print("发送对话请求，messages数量: %d, 最后一条role: %s" % [messages.size(), messages[-1].role])
	
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
	var timestamp = Time.get_unix_time_from_system()
	current_conversation.append({"role": "assistant", "content": full_response, "timestamp": timestamp})
	
	# 实时记录AI回复时间
	last_conversation_time = timestamp
	print("记录AI回复时间: %f" % last_conversation_time)
	_save_temp_conversation()  # 立即保存时间戳
	
	print("添加AI回复到历史，当前上下文数量: %d" % current_conversation.size())
	
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
	
	# 先保存完整对话的拷贝用于总结
	var conversation_copy = current_conversation.duplicate(true)
	var conversation_text = _flatten_conversation_from_data(conversation_copy)
	
	# 保存待总结的数据（用于重试和断点恢复）
	pending_summary_data = {
		"conversation_copy": conversation_copy,
		"conversation_text": conversation_text,
		"original_count": current_conversation.size(),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 先保存完整对话到临时文件（包含待总结标记）
	_save_temp_conversation()
	
	# 重置重试计数
	summary_retry_count = 0
	
	# 调用总结API
	_call_summary_api_with_data(conversation_text, conversation_copy)

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

func _call_summary_api_with_data(conversation_text: String, conversation_data: Array):
	"""调用总结 API（使用指定的对话数据）"""
	var summary_config = config_loader.config.summary_model
	# 严格使用用户配置，不进行任何回退
	var model = summary_config.model
	var base_url = summary_config.base_url
	
	if model.is_empty() or base_url.is_empty():
		push_error("总结模型配置不完整: model='%s', base_url='%s'" % [model, base_url])
		_handle_summary_failure("总结模型配置不完整")
		return
	
	var url = base_url + "/chat/completions"
	
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
	
	# 根据对话条数动态计算字数限制
	var conversation_count = conversation_data.size()
	var word_limit = _calculate_word_limit(conversation_count)
	
	# 使用新的配置结构
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
		"model": model,  # 严格使用用户配置的模型
		"messages": messages,
		"max_tokens": int(summary_params.max_tokens),
		"temperature": float(summary_params.temperature),
		"top_p": float(summary_params.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	logger.log_api_request("SUMMARY_REQUEST", body, json_body)
	
	# 如果http_request正在处理请求，先取消它
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("检测到http_request正在忙碌，取消当前请求")
		http_request.cancel_request()
		# 等待一帧确保取消完成
		await get_tree().process_frame
	
	http_request.set_meta("request_type", "summary")
	http_request.set_meta("request_body", body)
	http_request.set_meta("messages", messages)
	http_request.set_meta("conversation_text", conversation_text)
	http_request.set_meta("conversation_data", conversation_data)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("总结请求失败: " + str(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""HTTP 请求完成回调"""
	var request_type = http_request.get_meta("request_type", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "请求失败: " + str(result)
		print(error_msg)
		# 替换 chat_error.emit(error_msg) 为：
		if request_type != "summary":
			chat_error.emit(error_msg)
		else:
			print("总结过程错误: " + error_msg)
		
		# 如果是总结请求失败，尝试重试
		if request_type == "summary":
			_handle_summary_failure(error_msg)
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "API 错误 (%d): %s" % [response_code, error_text]
		print(error_msg)
		if request_type != "summary":
			chat_error.emit(error_msg)
		else:
			print("总结过程错误: " + error_msg)
		
		var request_body = http_request.get_meta("request_body", {})
		logger.log_api_error(response_code, error_text, request_body)
		
		# 如果是总结请求失败，尝试重试
		if request_type == "summary":
			_handle_summary_failure(error_msg)
		return
	
	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		var error_msg = "响应解析失败"
		push_error(error_msg)
		
		# 如果是总结请求失败，尝试重试
		if request_type == "summary":
			_handle_summary_failure(error_msg)
		return
	
	if request_type == "summary":
		_handle_summary_response(json.data)
	elif request_type == "relationship":
		_handle_relationship_response(json.data)

func _handle_summary_response(response: Dictionary):
	"""处理总结响应"""
	if not response.has("choices") or response.choices.is_empty():
		push_error("总结响应格式错误")
		_handle_summary_failure("总结响应格式错误")
		return
	
	var message = response.choices[0].message
	var summary = message.content
	
	var messages = http_request.get_meta("messages", [])
	logger.log_api_call("SUMMARY_RESPONSE", messages, summary)
	
	var conversation_text = http_request.get_meta("conversation_text", "")
	var conversation_data = http_request.get_meta("conversation_data", [])
	
	# 使用对话数据中的时间戳（取最后一条消息的时间戳作为对话结束时间）
	var timestamp = null
	if not conversation_data.is_empty():
		# 从后往前找第一条有timestamp的消息
		for i in range(conversation_data.size() - 1, -1, -1):
			if conversation_data[i].has("timestamp"):
				timestamp = conversation_data[i].timestamp
				break
	
	await _save_memory_and_diary(summary, conversation_text, timestamp)
	
	# 总结成功后才清除上下文
	_clear_conversation_context()
	
	# 清除待总结数据
	pending_summary_data.clear()
	summary_retry_count = 0
	
	# 总结完成后删除临时文件
	_delete_temp_conversation()
	
	summary_completed.emit(summary)

func _save_memory_and_diary(summary: String, conversation_text: String, custom_timestamp = null):
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
	
	# 使用统一记忆保存器
	var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if unified_saver:
		await unified_saver.save_memory(
			summary,
			unified_saver.MemoryType.CHAT,
			custom_timestamp,
			conversation_text,
			{}
		)
	else:
		# 降级方案：使用旧逻辑
		push_warning("UnifiedMemorySaver 未找到，使用旧的保存逻辑")
		
		# 使用自定义时间戳（断点恢复）或当前时间
		var timestamp: String
		if custom_timestamp != null:
			var timezone_offset = _get_timezone_offset()
			var local_dict = Time.get_datetime_dict_from_unix_time(int(custom_timestamp + timezone_offset))
			timestamp = "%04d-%02d-%02dT%02d:%02d:%02d" % [
				local_dict.year, local_dict.month, local_dict.day,
				local_dict.hour, local_dict.minute, local_dict.second
			]
		else:
			timestamp = _get_local_datetime_string()
		
		var cleaned_summary = summary.strip_edges()
		
		var memory_item = {
			"timestamp": timestamp,
			"content": cleaned_summary
		}
		
		save_mgr.save_data.ai_data.memory.append(memory_item)
		
		var max_items = config_loader.config.memory.max_memory_items
		if save_mgr.save_data.ai_data.memory.size() > max_items:
			save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)
		
		save_mgr.save_game(save_mgr.current_slot)
		
		logger.save_to_diary(cleaned_summary, conversation_text, custom_timestamp)
		
		if has_node("/root/MemoryManager"):
			var memory_mgr = get_node("/root/MemoryManager")
			await memory_mgr.add_conversation_summary(cleaned_summary, {}, timestamp)
	
	print("记忆已保存: ", summary)
	
	# 更新累计计数
	save_mgr.save_data.ai_data.accumulated_summary_count += 1
	
	_call_address_api(conversation_text)
	
	var max_memory_items = config_loader.config.memory.max_memory_items
	if save_mgr.save_data.ai_data.accumulated_summary_count >= max_memory_items:
		print("累计条目数达到上限，调用关系模型...")
		_call_relationship_api()
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
		save_mgr.save_game(save_mgr.current_slot)

func _call_address_api(conversation_text: String):
	"""调用称呼模型 API"""
	var summary_config = config_loader.config.summary_model
	# 严格使用用户配置，不进行任何回退
	var model = summary_config.model
	var base_url = summary_config.base_url
	
	if model.is_empty() or base_url.is_empty():
		push_error("称呼模型配置不完整: model='%s', base_url='%s'" % [model, base_url])
		return
	
	var url = base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + config_loader.api_key
	]
	
	var save_mgr = get_node("/root/SaveManager")
	var char_name = save_mgr.get_character_name()
	var user_name = save_mgr.get_user_name()
	var current_address = save_mgr.get_user_address()
	
	# 使用新的配置结构
	var address_params = summary_config.address
	var system_prompt = address_params.system_prompt
	system_prompt = system_prompt.replace("{character_name}", char_name)
	system_prompt = system_prompt.replace("{user_name}", user_name)
	system_prompt = system_prompt.replace("{current_address}", current_address)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": conversation_text}
	]
	
	var body = {
		"model": model,  # 严格使用用户配置的模型
		"messages": messages,
		"max_tokens": int(address_params.max_tokens),
		"temperature": float(address_params.temperature),
		"top_p": float(address_params.top_p)
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
	
	# 获取角色名称用于验证
	var save_mgr = get_node("/root/SaveManager")
	var char_name = save_mgr.get_character_name()
	
	# 检查返回的称呼是否包含角色名，如果包含则认为是模型出错，抛弃此次更新
	if new_address.contains(char_name):
		print("称呼模型返回包含角色名 '%s'，判定为错误，抛弃此次更新: %s" % [char_name, new_address])
		return
	save_mgr.set_user_address(new_address)
	
	print("称呼已更新: ", new_address)

func _call_relationship_api():
	"""调用关系模型 API"""
	var summary_config = config_loader.config.summary_model
	# 严格使用用户配置，不进行任何回退
	var model = summary_config.model
	var base_url = summary_config.base_url
	
	if model.is_empty() or base_url.is_empty():
		push_error("关系模型配置不完整: model='%s', base_url='%s'" % [model, base_url])
		return
	
	var url = base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + config_loader.api_key
	]
	
	var prompt_builder = get_node("/root/PromptBuilder")
	var current_relationship = prompt_builder.get_relationship_context()
	var memory_context = prompt_builder.get_memory_context()
	
	# 使用新的配置结构
	var relationship_params = summary_config.relationship
	var system_prompt = relationship_params.system_prompt.replace("{relationship}", current_relationship)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": memory_context}
	]
	
	var body = {
		"model": model,  # 严格使用用户配置的模型
		"messages": messages,
		"max_tokens": int(relationship_params.max_tokens),
		"temperature": float(relationship_params.temperature),
		"top_p": float(relationship_params.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	logger.log_api_request("RELATIONSHIP_REQUEST", body, json_body)
	
	# 如果http_request正在处理请求，先取消它
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("检测到http_request正在忙碌，取消当前请求")
		http_request.cancel_request()
		# 等待一帧确保取消完成
		await get_tree().process_frame
	
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
	
	var timestamp = _get_local_datetime_string()
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

func _calculate_word_limit(conversation_count: int) -> int:
	"""根据对话条数动态计算字数限制
	
	规则：
	- 1-2条对话：30字
	- 3-4条对话：50字
	- 5-6条对话：70字
	- 7-8条对话：90字
	- 9条及以上：110字
	"""
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

func _save_temp_conversation():
	"""保存当前对话到临时文件"""
	var data = {
		"conversation": current_conversation,
		"last_time": last_conversation_time,
		"is_first_message": is_first_message,
		"pending_summary": pending_summary_data,
		"summary_retry_count": summary_retry_count
	}
	
	var file = FileAccess.open(temp_conversation_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_temp_conversation() -> Dictionary:
	"""从临时文件加载对话"""
	if not FileAccess.file_exists(temp_conversation_file):
		return {}
	
	var file = FileAccess.open(temp_conversation_file, FileAccess.READ)
	if not file:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) != OK:
		push_error("临时对话文件解析失败")
		return {}
	
	return json.data

func _delete_temp_conversation():
	"""删除临时对话文件"""
	if FileAccess.file_exists(temp_conversation_file):
		DirAccess.remove_absolute(temp_conversation_file)
		print("临时对话文件已删除")

func _check_and_recover_interrupted_conversation():
	"""检查并恢复中断的对话"""
	var temp_data = _load_temp_conversation()
	if temp_data.is_empty():
		return
	
	print("检测到未完成的对话，开始断点恢复...")
	
	# 关键修复：添加全局时间检查
	var last_time = temp_data.get("last_time", 0.0)
	var current_time = Time.get_unix_time_from_system()
	var time_elapsed = current_time - last_time
	
	# 检查是否有待总结的数据
	var pending_summary = temp_data.get("pending_summary", {})
	print("上次时间戳：",last_time)
	print("目前时间戳：",current_time)
	print("差值：",time_elapsed)
	# 情况1：超过5分钟且有待总结数据 → 继续总结
	if time_elapsed > 300 and not pending_summary.is_empty():
		print("距上次对话超过5分钟且有待总结数据，继续总结流程...")
		_recover_pending_summary(temp_data)
		
	# 情况2：超过5分钟且无待总结数据 → 先总结再清除
	elif time_elapsed > 300 and pending_summary.is_empty():
		print("距上次对话超过5分钟且无待总结数据，开始总结流程...")
		_start_summary_for_expired_conversation(temp_data)
		
	# 情况3：小于5分钟且有待总结数据 → 继续总结（可能是刚刚中断）
	elif time_elapsed <= 300 and not pending_summary.is_empty():
		print("距上次对话小于5分钟且有待总结数据，继续总结流程...")
		_recover_pending_summary(temp_data)
		
	# 情况4：小于5分钟且无待总结数据 → 恢复上下文
	else:
		print("距上次对话小于5分钟，恢复对话上下文")
		current_conversation = temp_data.get("conversation", [])
		last_conversation_time = temp_data.get("last_time", 0.0)
		is_first_message = temp_data.get("is_first_message", true)
		print("恢复上下文：%d条对话记录，last_time: %f, is_first_message: %s" % [
			current_conversation.size(), last_conversation_time, is_first_message
		])
		# 不自动总结，等待用户继续对话
		return

func _recover_pending_summary(temp_data: Dictionary):
	"""恢复待总结的数据处理流程"""
	# 恢复对话数据
	current_conversation = temp_data.get("conversation", [])
	pending_summary_data = temp_data.get("pending_summary", {})
	summary_retry_count = temp_data.get("summary_retry_count", 0)
	
	var conv_text = pending_summary_data.get("conversation_text", "")
	var conv_copy = pending_summary_data.get("conversation_copy", [])
	
	if not conv_copy.is_empty():
		print("恢复的对话包含 %d 条记录，继续总结..." % conv_copy.size())
		_call_summary_api_with_data(conv_text, conv_copy)
	else:
		print("警告: 待总结数据为空，删除临时文件")
		_delete_temp_conversation()

func _start_summary_for_expired_conversation(temp_data: Dictionary):
	"""为过期的对话开始总结流程"""
	var recovered_conversation = temp_data.get("conversation", [])
	if recovered_conversation.is_empty():
		print("对话记录为空，直接删除临时文件")
		_delete_temp_conversation()
		return
	
	# 扁平化对话文本用于总结
	var conversation_text = _flatten_conversation_from_data(recovered_conversation)
	
	print("过期的对话包含 %d 条记录，开始总结..." % recovered_conversation.size())
	
	# 设置待总结数据
	pending_summary_data = {
		"conversation_copy": recovered_conversation,
		"conversation_text": conversation_text,
		"original_count": recovered_conversation.size(),
		"timestamp": Time.get_unix_time_from_system()
	}
	current_conversation = recovered_conversation
	summary_retry_count = 0
	
	# 保存临时文件，标记为待总结状态
	_save_temp_conversation()
	
	# 调用总结API，使用恢复的对话数据
	_call_summary_api_with_data(conversation_text, recovered_conversation)
	
func _flatten_conversation_from_data(conversation_data: Array) -> String:
	"""从指定的对话数据扁平化对话历史"""
	var lines = []
	
	var save_mgr = get_node("/root/SaveManager")
	var char_name = save_mgr.get_character_name()
	var user_name = save_mgr.get_user_name()
	
	for msg in conversation_data:
		if msg.role == "user":
			# 过滤掉空消息或占位符
			var user_content = msg.content.strip_edges()
			if user_content.is_empty() or user_content == "继续":
				continue
			lines.append("%s：%s" % [user_name, user_content])
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
				if data.has("msg") and data.msg is String:
					content = data.msg
			else:
				# JSON解析失败，使用原始内容但记录警告
				print("警告: 无法解析assistant消息的JSON格式，使用原始内容")
			
			lines.append("%s：%s" % [char_name, content])
	
	return "\n".join(lines)

func _get_local_datetime_string() -> String:
	"""获取本地时间字符串（带时区转换）"""
	var unix_time = Time.get_unix_time_from_system()
	var timezone_offset = _get_timezone_offset()
	var local_dict = Time.get_datetime_dict_from_unix_time(int(unix_time + timezone_offset))
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		local_dict.year, local_dict.month, local_dict.day,
		local_dict.hour, local_dict.minute, local_dict.second
	]

func _get_timezone_offset() -> int:
	"""获取本地时区相对于UTC的偏移（秒）"""
	var local_time = Time.get_datetime_dict_from_system()
	var unix_time = Time.get_unix_time_from_system()
	var utc_time = Time.get_datetime_dict_from_unix_time(int(unix_time))
	
	# 计算小时差
	var hour_diff = local_time.hour - utc_time.hour
	
	# 处理跨日情况
	if hour_diff > 12:
		hour_diff -= 24
	elif hour_diff < -12:
		hour_diff += 24
	
	return hour_diff * 3600

func _handle_summary_failure(error_msg: String):
	"""处理总结失败，尝试重试"""
	summary_retry_count += 1
	
	if summary_retry_count <= max_summary_retries:
		print("总结失败（%s），%d秒后进行第%d次重试..." % [error_msg, summary_retry_delay, summary_retry_count])
		
		# 更新临时文件（保存重试计数）
		_save_temp_conversation()
		
		# 延迟后重试
		await get_tree().create_timer(summary_retry_delay).timeout
		
		if not pending_summary_data.is_empty():
			var conversation_text = pending_summary_data.get("conversation_text", "")
			var conversation_copy = pending_summary_data.get("conversation_copy", [])
			
			if not conversation_copy.is_empty():
				print("开始第%d次重试总结..." % summary_retry_count)
				_call_summary_api_with_data(conversation_text, conversation_copy)
			else:
				push_error("待总结数据为空，无法重试")
				_clear_conversation_context()
				_delete_temp_conversation()
		else:
			push_error("待总结数据丢失，无法重试")
			_clear_conversation_context()
			_delete_temp_conversation()
	else:
		push_error("总结失败，已达到最大重试次数（%d次），放弃总结" % max_summary_retries)
		
		# 即使总结失败，也要清除上下文避免内存泄漏
		_clear_conversation_context()
		
		# 清除待总结数据
		pending_summary_data.clear()
		summary_retry_count = 0
		
		# 删除临时文件
		_delete_temp_conversation()
		
		# chat_error.emit("总结失败: " + error_msg)

func _clear_conversation_context():
	"""清除对话上下文（保留后50%）"""
	if pending_summary_data.is_empty():
		return
	
	var original_count = pending_summary_data.get("original_count", current_conversation.size())
	
	# 修改这里：允许保留条数为0
	var keep_count = max(0, int(ceil(original_count * 0.5))) if original_count > 0 else 0
	var clear_count = original_count - keep_count
	
	if clear_count > 0 and current_conversation.size() >= original_count:
		for i in range(clear_count):
			current_conversation.pop_front()
		print("清除了 %d 条上下文，保留 %d 条" % [clear_count, current_conversation.size()])
	else:
		print("对话记录太少或已被清除，保留 %d 条" % current_conversation.size())
	
	# 记录对话结束时间
	last_conversation_time = Time.get_unix_time_from_system()
	
	# 重置为第一条消息状态
	is_first_message = true
