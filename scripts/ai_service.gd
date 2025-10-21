extends Node

# AI 服务 - 处理对话和总结
# 自动加载单例

signal chat_response_received(response: String)
signal chat_response_completed() # 流式响应完成信号
signal chat_fields_extracted(fields: Dictionary) # 字段提取完成信号（mood, will, like）
signal chat_error(error_message: String)
signal summary_completed(summary: String)

var config: Dictionary = {}
var api_key: String = ""
var http_request: HTTPRequest
var current_conversation: Array = [] # 当前对话历史
var is_chatting: bool = false
var is_first_message: bool = true # 标记是否是本次会话的首次消息

# 流式响应相关
var http_client: HTTPClient
var sse_buffer: String = "" # SSE行缓冲
var json_response_buffer: String = "" # 完整JSON响应缓冲
var msg_buffer: String = "" # 提取的msg内容缓冲
var extracted_fields: Dictionary = {} # 提取的其他字段（mood, will, like, goto）
var is_streaming: bool = false
var stream_host: String = ""
var stream_port: int = 443
var stream_use_tls: bool = true

# 超时控制
var request_start_time: float = 0.0
var request_timeout: float = 30.0

func _ready():
	_load_config()
	_load_api_key()
	
	# 创建 HTTP 请求节点（用于非流式请求，如总结）
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# 创建 HTTPClient（用于流式请求）
	http_client = HTTPClient.new()

func _load_config():
	"""加载 AI 配置"""
	var config_path = "res://config/ai_config.json"
	if not FileAccess.file_exists(config_path):
		push_error("AI 配置文件不存在")
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		config = json.data
		print("AI 配置加载成功")
	else:
		push_error("AI 配置解析失败")

func _load_api_key():
	"""加载 API 密钥和配置"""
	var new_key_path = "user://ai_keys.json"
	var old_key_path = "user://api_keys.json"
	
	# 优先加载新格式配置
	if FileAccess.file_exists(new_key_path):
		_load_new_format_config(new_key_path)
		return
	
	# 尝试加载旧格式配置
	if FileAccess.file_exists(old_key_path):
		_load_old_format_config(old_key_path)
		return
	
	# 尝试从配置目录复制旧格式
	var config_key_path = "res://config/api_keys.json"
	if FileAccess.file_exists(config_key_path):
		var config_file = FileAccess.open(config_key_path, FileAccess.READ)
		var content = config_file.get_as_text()
		config_file.close()
		
		var user_file = FileAccess.open(old_key_path, FileAccess.WRITE)
		user_file.store_string(content)
		user_file.close()
		
		_load_old_format_config(old_key_path)
		return
	
	push_error("API 密钥文件不存在，请配置 AI 设置")

func _load_new_format_config(path: String):
	"""加载新格式的配置文件"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开配置文件")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("配置文件解析失败")
		return
	
	var user_config = json.data
	var mode = user_config.get("mode", "")
	
	if mode == "simple":
		# 简单模式：使用默认配置，只替换密钥
		api_key = user_config.get("api_key", "")
		if api_key.is_empty():
			push_error("API 密钥为空")
		else:
			print("API 密钥加载成功 (简单模式)")
	
	elif mode == "detailed":
		# 详细模式：覆盖配置
		if user_config.has("chat_model"):
			var chat = user_config.chat_model
			config.chat_model.model = chat.get("model", config.chat_model.model)
			config.chat_model.base_url = chat.get("base_url", config.chat_model.base_url)
			api_key = chat.get("api_key", "")
		
		if user_config.has("summary_model"):
			var summary = user_config.summary_model
			config.summary_model.model = summary.get("model", config.summary_model.model)
			config.summary_model.base_url = summary.get("base_url", config.summary_model.base_url)
			# 注意：总结模型也使用同一个密钥（可以根据需要修改）
		
		if api_key.is_empty():
			push_error("API 密钥为空")
		else:
			print("API 配置加载成功 (详细模式)")
			print("  对话模型: ", config.chat_model.model)
			print("  总结模型: ", config.summary_model.model)
	else:
		push_error("未知的配置模式: " + mode)

func _load_old_format_config(path: String):
	"""加载旧格式的配置文件（兼容性）"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开配置文件")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var keys = json.data
		api_key = keys.get("openai_api_key", "")
		if api_key.is_empty():
			push_error("API 密钥为空")
		else:
			print("API 密钥加载成功 (旧格式)")
	else:
		push_error("API 密钥文件解析失败")

func add_to_history(role: String, content: String):
	"""手动添加消息到对话历史（用于特殊情况，如拒绝回复）"""
	current_conversation.append({"role": role, "content": content})
	print("手动添加到历史: ", role, " - ", content)

func start_chat(user_message: String = "", trigger_mode: String = "user_initiated"):
	"""
	开始对话
	user_message: 用户消息（角色主动触发时可为空）
	trigger_mode: "user_initiated" = 用户主动触发, "character_initiated" = 角色主动触发
	"""
	if is_chatting:
		push_warning("正在对话中，请等待...")
		return
	
	if api_key.is_empty():
		chat_error.emit("API 密钥未配置")
		return
	
	is_chatting = true
	
	# 判断实际使用的触发模式：首次消息使用传入的trigger_mode，后续使用"ongoing"
	var actual_trigger_mode = trigger_mode if is_first_message else "ongoing"
	
	# 构建系统提示词（使用 PromptBuilder）
	var prompt_builder = get_node("/root/PromptBuilder")
	var system_prompt = prompt_builder.build_system_prompt(actual_trigger_mode)
	
	# 构建消息列表
	var messages = [
		{"role": "system", "content": system_prompt}
	]
	
	# 添加对话历史（限制数量）
	var max_history = config.memory.max_conversation_history
	var history_start = max(0, current_conversation.size() - max_history)
	for i in range(history_start, current_conversation.size()):
		messages.append(current_conversation[i])
	
	# 只有用户主动触发时才添加用户消息
	if trigger_mode == "user_initiated" and not user_message.is_empty():
		messages.append({"role": "user", "content": user_message})
		current_conversation.append({"role": "user", "content": user_message})
	
	# 标记已经不是首次消息了
	if is_first_message:
		is_first_message = false
	
	# 调用 API
	_call_chat_api(messages, user_message)

# 提示词构建相关函数已移至 PromptBuilder 单例

func _call_chat_api(messages: Array, _user_message: String):
	"""调用对话 API"""
	var chat_config = config.chat_model
	var url = chat_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	# 构建请求体 - 确保格式正确，启用流式响应
	var body = {
		"model": chat_config.model,
		"messages": messages,
		"max_tokens": int(chat_config.max_tokens),
		"temperature": float(chat_config.temperature),
		"top_p": float(chat_config.top_p),
		"stream": true, # 启用流式响应
		"response_format": {"type": "json_object"}
	}
	
	var json_body = JSON.stringify(body)
	
	# 记录完整的请求日志（包含 JSON 请求体）
	_log_api_request("CHAT_REQUEST", body, json_body)
	
	# 重置流式缓冲
	sse_buffer = ""
	json_response_buffer = ""
	msg_buffer = ""
	extracted_fields = {}
	is_streaming = true
	
	# 存储消息用于日志
	http_request.set_meta("messages", messages)
	http_request.set_meta("request_body", body)
	
	# 解析URL
	var url_parts = chat_config.base_url.replace("https://", "").replace("http://", "").split("/")
	stream_host = url_parts[0]
	stream_use_tls = chat_config.base_url.begins_with("https://")
	stream_port = 443 if stream_use_tls else 80
	
	# 启动流式连接
	_start_stream_request(url, headers, json_body)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""HTTP 请求完成回调"""
	var request_type = http_request.get_meta("request_type", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		is_chatting = false
		is_streaming = false
		chat_error.emit("请求失败: " + str(result))
		return
	
	if response_code != 200:
		is_chatting = false
		is_streaming = false
		var error_text = body.get_string_from_utf8()
		var error_msg = "API 错误 (%d): %s" % [response_code, error_text]
		print(error_msg)
		chat_error.emit(error_msg)
		
		# 记录详细的错误信息
		var request_body = http_request.get_meta("request_body", {})
		_log_api_error(response_code, error_text, request_body)
		return
	
	var response_text = body.get_string_from_utf8()
	
	if request_type == "chat":
		# 处理流式响应
		_process_stream_data(response_text)
	elif request_type == "summary":
		# 总结请求不使用流式
		var json = JSON.new()
		if json.parse(response_text) != OK:
			push_error("总结响应解析失败")
			return
		_handle_summary_response(json.data)
	elif request_type == "relationship":
		# 关系模型请求不使用流式
		var json = JSON.new()
		if json.parse(response_text) != OK:
			push_error("关系模型响应解析失败")
			return
		_handle_relationship_response(json.data)

func _start_stream_request(url: String, headers: Array, json_body: String):
	"""启动流式HTTP请求"""
	var tls_options = null
	if stream_use_tls:
		tls_options = TLSOptions.client()
	
	var err = http_client.connect_to_host(stream_host, stream_port, tls_options)
	if err != OK:
		is_chatting = false
		is_streaming = false
		chat_error.emit("连接失败: " + str(err))
		return
	
	# 记录请求开始时间和超时设置
	request_start_time = Time.get_ticks_msec() / 1000.0
	request_timeout = config.chat_model.get("timeout", 30.0)
	
	# 存储请求信息以便在_process中使用
	set_meta("stream_url", url)
	set_meta("stream_headers", headers)
	set_meta("stream_body", json_body)
	set_meta("stream_state", "connecting")

func _process(_delta):
	"""处理流式HTTP连接"""
	if not is_streaming:
		return
	
	# 检查超时
	var elapsed = (Time.get_ticks_msec() / 1000.0) - request_start_time
	if elapsed > request_timeout:
		print("请求超时（%.1f秒）" % elapsed)
		is_chatting = false
		is_streaming = false
		http_client.close()
		
		# 如果已经收到部分内容，完成处理；否则显示"欲言又止"
		if not msg_buffer.is_empty():
			print("超时但已收到部分内容，完成处理")
			_finalize_stream_response()
		else:
			print("超时且未收到内容，触发欲言又止")
			# 添加"……"到对话历史
			current_conversation.append({"role": "assistant", "content": "……"})
			# 发送超时错误信号（chat_dialog会处理为"欲言又止"）
			chat_error.emit("响应超时")
		return
	
	http_client.poll()
	var status = http_client.get_status()
	
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			if get_meta("stream_state", "") == "connecting":
				# 连接失败
				is_chatting = false
				is_streaming = false
				chat_error.emit("连接断开")
		
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
			# 等待连接
			pass
		
		HTTPClient.STATUS_CONNECTED:
			# 连接成功，发送请求
			if get_meta("stream_state", "") == "connecting":
				_send_stream_request()
		
		HTTPClient.STATUS_REQUESTING:
			# 等待响应
			pass
		
		HTTPClient.STATUS_BODY:
			# 接收响应体
			_receive_stream_chunk()
		
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			is_chatting = false
			is_streaming = false
			chat_error.emit("连接错误: " + str(status))

func _send_stream_request():
	"""发送流式请求"""
	var headers_array = get_meta("stream_headers", [])
	var body = get_meta("stream_body", "")
	
	# 提取路径
	var path = "/v1/chat/completions"
	
	var err = http_client.request(HTTPClient.METHOD_POST, path, headers_array, body)
	if err != OK:
		is_chatting = false
		is_streaming = false
		chat_error.emit("请求发送失败: " + str(err))
		return
	
	set_meta("stream_state", "requesting")

func _receive_stream_chunk():
	"""接收流式数据块"""
	if http_client.has_response():
		var response_code = http_client.get_response_code()
		if response_code != 200:
			is_chatting = false
			is_streaming = false
			chat_error.emit("API 错误: " + str(response_code))
			return
		
		# 读取数据块
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			var text = chunk.get_string_from_utf8()
			_process_stream_data(text)

func _process_stream_data(data: String):
	"""处理流式响应数据（SSE格式）"""
	sse_buffer += data
	
	# 处理SSE格式的数据流
	var lines = sse_buffer.split("\n")
	
	# 保留最后一行（可能不完整）
	if not sse_buffer.ends_with("\n"):
		sse_buffer = lines[-1]
		lines = lines.slice(0, -1)
	else:
		sse_buffer = ""
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		
		if line == "data: [DONE]":
			# 流式结束，完成处理
			_finalize_stream_response()
			continue
		
		if line.begins_with("data: "):
			var json_str = line.substr(6) # 移除 "data: " 前缀
			_parse_stream_chunk(json_str)

func _parse_stream_chunk(json_str: String):
	"""解析单个流式数据块"""
	var json = JSON.new()
	if json.parse(json_str) != OK:
		print("流式块解析失败: ", json_str.substr(0, 100))
		return
	
	var chunk = json.data
	if not chunk.has("choices") or chunk.choices.is_empty():
		return
	
	var delta = chunk.choices[0].get("delta", {})
	if delta.has("content"):
		var content = delta.content
		# 将内容添加到完整响应缓冲（用于保存上下文）
		json_response_buffer += content
		print("接收到内容块: ", content)
		# 实时提取msg字段内容
		_extract_msg_from_buffer()

func _extract_msg_from_buffer():
	"""从流式缓冲中实时提取msg字段内容和mood字段"""
	var buffer_to_parse = json_response_buffer
	
	# 处理可能的 ```json 包裹
	if buffer_to_parse.contains("```json"):
		var json_start = buffer_to_parse.find("```json") + 7
		buffer_to_parse = buffer_to_parse.substr(json_start)
	elif buffer_to_parse.contains("```"):
		var json_start = buffer_to_parse.find("```") + 3
		buffer_to_parse = buffer_to_parse.substr(json_start)
	
	# 移除可能的结束标记
	if buffer_to_parse.contains("```"):
		var json_end = buffer_to_parse.find("```")
		buffer_to_parse = buffer_to_parse.substr(0, json_end)
	
	buffer_to_parse = buffer_to_parse.strip_edges()
	
	# 优先提取mood字段（mood一定在msg之前）
	_extract_mood_from_buffer(buffer_to_parse)
	
	# 查找 "msg" 字段的开始位置
	var msg_start = buffer_to_parse.find('"msg"')
	if msg_start == -1:
		return
	
	# 查找冒号和引号
	var colon_pos = buffer_to_parse.find(':', msg_start)
	if colon_pos == -1:
		return
	
	# 跳过空格找到引号
	var quote_start = -1
	for i in range(colon_pos + 1, buffer_to_parse.length()):
		if buffer_to_parse[i] == '"':
			quote_start = i
			break
		elif buffer_to_parse[i] != ' ' and buffer_to_parse[i] != '\t':
			break
	
	if quote_start == -1:
		return
	
	# 从引号后开始提取内容
	var content_start = quote_start + 1
	var current_pos = content_start
	var extracted_content = ""
	
	# 逐字符提取，直到遇到未转义的引号或数据结束
	while current_pos < buffer_to_parse.length():
		var ch = buffer_to_parse[current_pos]
		
		if ch == '\\' and current_pos + 1 < buffer_to_parse.length():
			# 处理转义字符
			var next_ch = buffer_to_parse[current_pos + 1]
			if next_ch == '"':
				extracted_content += '"'
				current_pos += 2
				continue
			elif next_ch == 'n':
				extracted_content += '\n'
				current_pos += 2
				continue
			elif next_ch == 't':
				extracted_content += '\t'
				current_pos += 2
				continue
			elif next_ch == '\\':
				extracted_content += '\\'
				current_pos += 2
				continue
			else:
				extracted_content += ch
				current_pos += 1
		elif ch == '"':
			# 找到结束引号，msg字段完整
			break
		else:
			extracted_content += ch
			current_pos += 1
	
	# 计算新增的内容
	if extracted_content.length() > msg_buffer.length():
		var new_content = extracted_content.substr(msg_buffer.length())
		msg_buffer = extracted_content
		
		# 发送新增内容给chat_dialog
		if not new_content.is_empty():
			print("发送新内容: ", new_content)
			chat_response_received.emit(new_content)

func _extract_mood_from_buffer(buffer: String):
	"""从缓冲中提取mood字段，一旦完整就立即更新"""
	# 如果已经提取过mood，不再重复提取
	if extracted_fields.has("mood"):
		return
	
	# 查找 "mood" 字段
	var mood_start = buffer.find('"mood"')
	if mood_start == -1:
		return
	
	# 查找冒号
	var colon_pos = buffer.find(':', mood_start)
	if colon_pos == -1:
		return
	
	# 跳过空格，查找数字或null
	var value_start = -1
	for i in range(colon_pos + 1, buffer.length()):
		var ch = buffer[i]
		if ch == ' ' or ch == '\t' or ch == '\n':
			continue
		value_start = i
		break
	
	if value_start == -1:
		return
	
	# 提取数字值（直到遇到逗号、换行、空格或右花括号）
	var value_str = ""
	for i in range(value_start, buffer.length()):
		var ch = buffer[i]
		if ch in [',', '\n', ' ', '\t', '}', '\r']:
			break
		value_str += ch
	
	# 检查是否是完整的数字（至少有一个字符）
	if value_str.is_empty():
		return
	
	# 检查是否是null
	if value_str.begins_with("null"):
		print("mood字段为null，跳过")
		extracted_fields["mood"] = null
		return
	
	# 验证是否是有效数字
	if not value_str.is_valid_int():
		return
	
	# 提取成功，立即应用
	var mood_id = int(value_str)
	extracted_fields["mood"] = mood_id
	
	print("实时提取到mood字段: ", mood_id)
	
	# 立即更新心情
	_apply_mood_immediately(mood_id)

func _finalize_stream_response():
	"""完成流式响应处理"""
	is_streaming = false
	is_chatting = false
	
	print("流式响应完成，完整内容: ", json_response_buffer)
	
	# 处理可能的 ```json 包裹
	var clean_json = json_response_buffer
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
	
	# 尝试解析完整的JSON以提取其他字段
	var json = JSON.new()
	if json.parse(clean_json) == OK:
		var full_response = json.data
		if full_response.has("mood") and full_response.mood != null:
			# 确保mood是整数类型
			extracted_fields["mood"] = int(full_response.mood)
		if full_response.has("will"):
			extracted_fields["will"] = full_response.will
		if full_response.has("like"):
			extracted_fields["like"] = full_response.like
		if full_response.has("goto") and full_response.goto != null:
			# 确保goto是整数类型（JSON可能解析为浮点数）
			extracted_fields["goto"] = int(full_response.goto)
		print("提取的字段: ", extracted_fields)
		
		# 应用字段到游戏状态（不包括goto，goto在对话结束时处理）
		_apply_extracted_fields()
	else:
		print("JSON解析失败: ", json.get_error_message())
		print("尝试解析的内容: ", clean_json.substr(0, 200))
	
	# 将完整的JSON添加到对话历史（用于上下文）
	current_conversation.append({"role": "assistant", "content": json_response_buffer})
	
	# 记录响应日志
	var messages = http_request.get_meta("messages", [])
	_log_api_call("CHAT_RESPONSE", messages, json_response_buffer)
	
	# 发送完成信号
	chat_response_completed.emit()

func _apply_mood_immediately(mood_id: int):
	"""立即应用mood字段（流式响应中实时调用）"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var prompt_builder = get_node("/root/PromptBuilder")
	
	var mood_name_en = prompt_builder.get_mood_name_en(mood_id)
	if not mood_name_en.is_empty():
		save_mgr.set_mood(mood_name_en)
		print("实时更新心情: ", mood_name_en, " (ID: ", mood_id, ")")
		
		# 发送mood字段提取信号（只包含mood）
		chat_fields_extracted.emit({"mood": mood_id})
	else:
		print("警告: 无法找到mood ID对应的英文名称: ", mood_id)

func _apply_extracted_fields():
	"""应用提取的字段到游戏状态（使用统一的边界控制）"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# mood字段已经在流式响应中实时应用，这里跳过
	# 但如果流式提取失败，这里作为兜底
	if extracted_fields.has("mood") and not extracted_fields.mood == null:
		var mood_id = extracted_fields.mood
		# 确保mood_id是整数类型（JSON解析可能返回float）
		if typeof(mood_id) == TYPE_STRING:
			mood_id = int(mood_id)
		elif typeof(mood_id) == TYPE_FLOAT:
			mood_id = int(mood_id)
		elif typeof(mood_id) != TYPE_INT:
			print("警告: mood字段类型不正确: ", typeof(mood_id), ", 值: ", mood_id)
			mood_id = 0 # 默认为平静
		
		var prompt_builder = get_node("/root/PromptBuilder")
		var mood_name_en = prompt_builder.get_mood_name_en(mood_id)
		if not mood_name_en.is_empty():
			save_mgr.set_mood(mood_name_en)
			print("兜底更新心情: ", mood_name_en, " (ID: ", mood_id, ")")
		else:
			print("警告: 无法找到mood ID对应的英文名称: ", mood_id)
	
	# 使用统一的边界控制
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		
		# 应用will字段（互动意愿增量）
		if extracted_fields.has("will"):
			var will_delta = extracted_fields.will
			# 确保will_delta是整数类型
			if typeof(will_delta) == TYPE_STRING:
				will_delta = int(will_delta)
			elif typeof(will_delta) == TYPE_FLOAT:
				will_delta = int(will_delta)
			elif typeof(will_delta) != TYPE_INT:
				print("警告: will字段类型不正确: ", typeof(will_delta), ", 值: ", will_delta)
				will_delta = 0
			helpers.modify_willingness(will_delta)
		
		# 应用like字段（好感度增量）
		if extracted_fields.has("like"):
			var like_delta = extracted_fields.like
			# 确保like_delta是整数类型
			if typeof(like_delta) == TYPE_STRING:
				like_delta = int(like_delta)
			elif typeof(like_delta) == TYPE_FLOAT:
				like_delta = int(like_delta)
			elif typeof(like_delta) != TYPE_INT:
				print("警告: like字段类型不正确: ", typeof(like_delta), ", 值: ", like_delta)
				like_delta = 0
			helpers.modify_affection(like_delta)
	
	# 发送字段提取完成信号（不包括goto和mood，mood已经单独发送）
	var fields_without_goto_mood = extracted_fields.duplicate()
	fields_without_goto_mood.erase("goto")
	fields_without_goto_mood.erase("mood")
	if not fields_without_goto_mood.is_empty():
		chat_fields_extracted.emit(fields_without_goto_mood)

# _get_mood_name_en 已移至 PromptBuilder 单例

func _handle_chat_response(response: Dictionary):
	"""处理对话响应（非流式，保留作为备用）"""
	if not response.has("choices") or response.choices.is_empty():
		is_chatting = false
		chat_error.emit("响应格式错误")
		return
	
	var message = response.choices[0].message
	var ai_response = message.content
	
	# 添加到对话历史
	current_conversation.append({"role": "assistant", "content": ai_response})
	
	# 记录响应日志
	var messages = http_request.get_meta("messages", [])
	_log_api_call("CHAT_RESPONSE", messages, ai_response)
	
	# 发送响应信号
	chat_response_received.emit(ai_response)
	
	is_chatting = false

func end_chat():
	"""结束对话，调用总结"""
	if current_conversation.is_empty():
		return
	
	# 提取本次对话（扁平化）
	var conversation_text = _flatten_conversation()
	
	# 调用总结 API（总结完成后会保存日记）
	_call_summary_api(conversation_text)
	
	# 清空当前对话
	current_conversation.clear()
	
	# 重置首次消息标记
	is_first_message = true

func get_goto_field() -> int:
	"""获取goto字段值，如果没有返回-1"""
	if extracted_fields.has("goto") and extracted_fields.goto != null:
		# 确保返回整数类型
		return int(extracted_fields.goto)
	return -1

func clear_goto_field():
	"""清除goto字段"""
	extracted_fields.erase("goto")

func _flatten_conversation() -> String:
	"""扁平化对话历史，只提取msg字段内容"""
	var lines = []
	
	# 从 app_config.json 读取角色名称（使用 PromptBuilder）
	var prompt_builder = get_node("/root/PromptBuilder")
	var app_config = prompt_builder._load_app_config()
	var char_name = app_config.get("character_name", "角色")
	
	# 从存档系统读取用户名
	var save_mgr = get_node("/root/SaveManager")
	var user_name = save_mgr.get_user_name()
	
	for msg in current_conversation:
		if msg.role == "user":
			lines.append("%s：%s" % [user_name, msg.content])
		elif msg.role == "assistant":
			# 尝试从JSON中提取msg字段
			var content = msg.content
			
			# 处理可能的 ```json 包裹
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
	var summary_config = config.summary_model
	var url = summary_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var messages = [
		{"role": "system", "content": summary_config.system_prompt},
		{"role": "user", "content": conversation_text}
	]
	
	# 构建请求体 - 确保格式正确
	var body = {
		"model": summary_config.model,
		"messages": messages,
		"max_tokens": int(summary_config.max_tokens),
		"temperature": float(summary_config.temperature),
		"top_p": float(summary_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	# 记录完整的请求日志
	_log_api_request("SUMMARY_REQUEST", body, json_body)
	
	http_request.set_meta("request_type", "summary")
	http_request.set_meta("request_body", body)
	http_request.set_meta("messages", messages)
	http_request.set_meta("conversation_text", conversation_text)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("总结请求失败: " + str(error))

func _handle_summary_response(response: Dictionary):
	"""处理总结响应"""
	if not response.has("choices") or response.choices.is_empty():
		push_error("总结响应格式错误")
		return
	
	var message = response.choices[0].message
	var summary = message.content
	
	# 记录响应日志
	var messages = http_request.get_meta("messages", [])
	_log_api_call("SUMMARY_RESPONSE", messages, summary)
	
	# 获取原始对话文本（用于保存到日记）
	var conversation_text = http_request.get_meta("conversation_text", "")
	
	# 保存到记忆和日记（关联总结和详细对话）
	_save_memory_and_diary(summary, conversation_text)
	
	# 发送信号
	summary_completed.emit(summary)

func _call_address_api(conversation_text: String):
	"""调用称呼模型 API（并发调用）"""
	var summary_config = config.summary_model
	var url = summary_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	# 获取角色名和用户名
	var prompt_builder = get_node("/root/PromptBuilder")
	var app_config = prompt_builder._load_app_config()
	var char_name = app_config.get("character_name", "角色")
	
	var save_mgr = get_node("/root/SaveManager")
	var user_name = save_mgr.get_user_name()
	var current_address = save_mgr.get_user_address()
	
	# 构建系统提示词（替换占位符，并添加当前称呼信息）
	var system_prompt = summary_config.address_system_prompt.replace("{character_name}", char_name).replace("{user_name}", user_name).replace("{current_address}", current_address)
	
	# 构建用户消息（对话内容）
	var user_message = conversation_text
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_message}
	]
	
	# 构建请求体
	var body = {
		"model": summary_config.model,
		"messages": messages,
		"max_tokens": int(summary_config.max_tokens),
		"temperature": float(summary_config.temperature),
		"top_p": float(summary_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	# 记录完整的请求日志
	_log_api_request("ADDRESS_REQUEST", body, json_body)
	
	# 创建新的HTTPRequest节点用于并发请求
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
	# 找到发起请求的HTTPRequest节点
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
	
	# 清理HTTPRequest节点
	if address_request:
		address_request.queue_free()

func _handle_address_response(response: Dictionary, address_request: HTTPRequest):
	"""处理称呼模型响应"""
	if not response.has("choices") or response.choices.is_empty():
		push_error("称呼模型响应格式错误")
		return
	
	var message = response.choices[0].message
	var new_address = message.content.strip_edges()
	
	# 记录响应日志
	var messages = address_request.get_meta("messages", [])
	_log_api_call("ADDRESS_RESPONSE", messages, new_address)
	
	# 更新user_address
	var save_mgr = get_node("/root/SaveManager")
	save_mgr.set_user_address(new_address)
	
	print("称呼已更新: ", new_address)

func _call_relationship_api():
	"""调用关系模型 API"""
	var relationship_config = config.relationship_model
	var url = relationship_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var prompt_builder = get_node("/root/PromptBuilder")
	
	# 获取当前的关系描述
	var current_relationship = prompt_builder.get_relationship_context()
	
	# 获取最近的总结内容作为输入
	var memory_context = prompt_builder.get_memory_context()
	
	# 构建系统提示词（替换占位符）
	var system_prompt = relationship_config.system_prompt.replace("{relationship}", current_relationship)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": memory_context}
	]
	
	# 构建请求体
	var body = {
		"model": relationship_config.model,
		"messages": messages,
		"max_tokens": int(relationship_config.max_tokens),
		"temperature": float(relationship_config.temperature),
		"top_p": float(relationship_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	# 记录完整的请求日志
	_log_api_request("RELATIONSHIP_REQUEST", body, json_body)
	
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
	
	# 记录响应日志
	var messages = http_request.get_meta("messages", [])
	_log_api_call("RELATIONSHIP_RESPONSE", messages, relationship_summary)
	
	# 保存到关系历史
	_save_relationship(relationship_summary)
	
	print("关系模型已更新: ", relationship_summary)

func _save_relationship(relationship_summary: String):
	"""保存关系信息到存档"""
	var save_mgr = get_node("/root/SaveManager")
	
	# 确保字段存在
	if not save_mgr.save_data.ai_data.has("relationship_history"):
		save_mgr.save_data.ai_data.relationship_history = []
	
	var timestamp = Time.get_datetime_string_from_system()
	
	# 清除开头的换行符
	var cleaned_summary = relationship_summary.strip_edges()
	
	var relationship_item = {
		"timestamp": timestamp,
		"content": cleaned_summary
	}
	
	# 添加到关系历史
	save_mgr.save_data.ai_data.relationship_history.append(relationship_item)
	
	# 检查是否超过最大条目数
	var max_relationship_history = config.memory.get("max_relationship_history", 2)
	if save_mgr.save_data.ai_data.relationship_history.size() > max_relationship_history:
		save_mgr.save_data.ai_data.relationship_history = save_mgr.save_data.ai_data.relationship_history.slice(-max_relationship_history)
	
	# 保存到存档
	save_mgr.save_game(save_mgr.current_slot)
	
	print("关系信息已保存: ", relationship_summary)

func _save_memory_and_diary(summary: String, conversation_text: String):
	"""保存记忆到存档，同时保存总结和详细对话到日记"""
	var save_mgr = get_node("/root/SaveManager")
	
	# 确保 ai_data 字段存在
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": [],
			"accumulated_summary_count": 0,
			"relationship_history": []
		}
	
	# 确保字段存在并强制转换为整数（JSON解析可能返回浮点数）
	if not save_mgr.save_data.ai_data.has("accumulated_summary_count"):
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
	else:
		# 强制转换为整数
		save_mgr.save_data.ai_data.accumulated_summary_count = int(save_mgr.save_data.ai_data.accumulated_summary_count)
	
	if not save_mgr.save_data.ai_data.has("relationship_history"):
		save_mgr.save_data.ai_data.relationship_history = []
	
	var timestamp = Time.get_datetime_string_from_system()
	
	# 清除开头的换行符（AI可能会在响应开头添加多个\n）
	var cleaned_summary = summary.strip_edges()
	
	var memory_item = {
		"timestamp": timestamp,
		"content": cleaned_summary
	}
	
	# 添加到中期记忆（存档中）
	save_mgr.save_data.ai_data.memory.append(memory_item)
	
	# 累计条目数+1
	save_mgr.save_data.ai_data.accumulated_summary_count += 1
	
	# 检查是否超过最大条目数
	var max_items = config.memory.max_memory_items
	if save_mgr.save_data.ai_data.memory.size() > max_items:
		save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)
	
	# 保存到存档
	save_mgr.save_game(save_mgr.current_slot)
	
	# 保存到日记（关联总结和详细对话）
	_save_to_diary(cleaned_summary, conversation_text)
	
	print("记忆已保存: ", summary)
	
	# 并发调用总结模型和称呼模型
	_call_address_api(conversation_text)
	
	# 检查是否需要调用关系模型
	if save_mgr.save_data.ai_data.accumulated_summary_count >= max_items:
		print("累计条目数达到上限，调用关系模型...")
		_call_relationship_api()
		# 清空累计条目数
		save_mgr.save_data.ai_data.accumulated_summary_count = 0
		save_mgr.save_game(save_mgr.current_slot)

func _save_to_diary(summary: String, conversation_text: String):
	"""保存总结和详细对话到日记（按日期分类）"""
	var diary_dir = "user://diary"
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录")
		return
	
	if not dir.dir_exists("diary"):
		var err = dir.make_dir("diary")
		if err != OK:
			print("错误: 无法创建 diary 目录，错误码: ", err)
			return
	
	# 获取当前日期和时间
	var datetime = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]
	var time_str = "%02d:%02d:%02d" % [datetime.hour, datetime.minute, datetime.second]
	
	# 日记文件路径（每天一个文件）
	var diary_path = diary_dir + "/" + date_str + ".jsonl"
	
	# 构建日记记录（包含总结和详细对话）
	var diary_record = {
		"timestamp": time_str,
		"summary": summary,
		"conversation": conversation_text
	}
	
	# 追加到日记文件
	var file = FileAccess.open(diary_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(diary_path, FileAccess.WRITE)
		if file == null:
			var err = FileAccess.get_open_error()
			print("错误: 无法创建日记文件，错误码: ", err)
			return
	else:
		file.seek_end()
	
	file.store_line(JSON.stringify(diary_record))
	file.close()
	
	print("日记已保存: ", date_str, " - ", summary.substr(0, 30), "...")



func _log_api_call(log_type: String, messages: Array, response: String):
	"""记录 API 调用日志"""
	var log_dir = "user://ai_logs"
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录进行日志记录")
		return
	
	if not dir.dir_exists("ai_logs"):
		var err = dir.make_dir("ai_logs")
		if err != OK:
			print("错误: 无法创建 ai_logs 目录，错误码: ", err)
			return
	
	var log_path = log_dir + "/log.txt"
	var log_file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if log_file == null:
		log_file = FileAccess.open(log_path, FileAccess.WRITE)
		if log_file == null:
			var err = FileAccess.get_open_error()
			print("错误: 无法创建日志文件，错误码: ", err)
			return
	else:
		log_file.seek_end()
	
	var timestamp = Time.get_datetime_string_from_system()
	log_file.store_line("\n" + "=".repeat(50))
	log_file.store_line("时间: " + timestamp)
	log_file.store_line("类型: " + log_type)
	
	if not messages.is_empty():
		log_file.store_line('"messages": [')
		for i in range(messages.size()):
			var msg = messages[i]
			var content = msg.content.replace('"', '\\"').replace("\n", "\\n")
			var comma = "," if i < messages.size() - 1 else ""
			log_file.store_line('  {"role": "%s","content": "%s"}%s' % [msg.role, content, comma])
		log_file.store_line(']')
	
	if not response.is_empty():
		log_file.store_line("响应消息:")
		log_file.store_line("  内容: " + response)
	
	log_file.store_line("=".repeat(50))
	log_file.close()

func _log_api_request(log_type: String, body: Dictionary, json_body: String):
	"""记录完整的 API 请求"""
	var log_dir = "user://ai_logs"
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录进行日志记录")
		return
	
	if not dir.dir_exists("ai_logs"):
		var err = dir.make_dir("ai_logs")
		if err != OK:
			print("错误: 无法创建 ai_logs 目录，错误码: ", err)
			return
	
	var log_path = log_dir + "/log.txt"
	var log_file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if log_file == null:
		log_file = FileAccess.open(log_path, FileAccess.WRITE)
		if log_file == null:
			var err = FileAccess.get_open_error()
			print("错误: 无法创建日志文件，错误码: ", err)
			return
	else:
		log_file.seek_end()
	
	var timestamp = Time.get_datetime_string_from_system()
	log_file.store_line("\n" + "=".repeat(50))
	log_file.store_line("时间: " + timestamp)
	log_file.store_line("类型: " + log_type)
	log_file.store_line("")
	log_file.store_line("完整请求体 (JSON):")
	log_file.store_line(json_body)
	log_file.store_line("")
	log_file.store_line("参数详情:")
	log_file.store_line("  model: " + str(body.model))
	log_file.store_line("  max_tokens: " + str(body.max_tokens) + " (类型: " + type_string(typeof(body.max_tokens)) + ")")
	log_file.store_line("  temperature: " + str(body.temperature) + " (类型: " + type_string(typeof(body.temperature)) + ")")
	log_file.store_line("  top_p: " + str(body.top_p) + " (类型: " + type_string(typeof(body.top_p)) + ")")
	log_file.store_line("  messages 数量: " + str(body.messages.size()))
	log_file.store_line("=".repeat(50))
	log_file.close()

func _log_api_error(status_code: int, error_text: String, request_body: Dictionary):
	"""记录 API 错误的详细信息"""
	var log_dir = "user://ai_logs"
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录进行日志记录")
		return
	
	if not dir.dir_exists("ai_logs"):
		var err = dir.make_dir("ai_logs")
		if err != OK:
			print("错误: 无法创建 ai_logs 目录，错误码: ", err)
			return
	
	var log_path = log_dir + "/log.txt"
	var log_file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if log_file == null:
		log_file = FileAccess.open(log_path, FileAccess.WRITE)
		if log_file == null:
			var err = FileAccess.get_open_error()
			print("错误: 无法创建日志文件，错误码: ", err)
			return
	else:
		log_file.seek_end()
	
	var timestamp = Time.get_datetime_string_from_system()
	log_file.store_line("\n" + "=".repeat(50))
	log_file.store_line("时间: " + timestamp)
	log_file.store_line("类型: API_ERROR")
	log_file.store_line("状态码: " + str(status_code))
	log_file.store_line("")
	log_file.store_line("发送的请求体:")
	log_file.store_line(JSON.stringify(request_body, "  "))
	log_file.store_line("")
	log_file.store_line("错误响应:")
	log_file.store_line(error_text)
	log_file.store_line("=".repeat(50))
	log_file.close()
