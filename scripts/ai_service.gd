extends Node

# AI 服务 - 处理对话和总结
# 自动加载单例

signal chat_response_received(response: String)
signal chat_error(error_message: String)
signal summary_completed(summary: String)

var config: Dictionary = {}
var api_key: String = ""
var http_request: HTTPRequest
var current_conversation: Array = []  # 当前对话历史
var is_chatting: bool = false

func _ready():
	_load_config()
	_load_api_key()
	
	# 创建 HTTP 请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

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
	"""加载 API 密钥"""
	var key_path = "user://api_keys.json"
	
	# 如果用户目录没有，尝试从配置目录复制
	if not FileAccess.file_exists(key_path):
		var config_key_path = "res://config/api_keys.json"
		if FileAccess.file_exists(config_key_path):
			var config_file = FileAccess.open(config_key_path, FileAccess.READ)
			var content = config_file.get_as_text()
			config_file.close()
			
			var user_file = FileAccess.open(key_path, FileAccess.WRITE)
			user_file.store_string(content)
			user_file.close()
	
	if not FileAccess.file_exists(key_path):
		push_error("API 密钥文件不存在，请创建 user://api_keys.json")
		return
	
	var key_file = FileAccess.open(key_path, FileAccess.READ)
	var json_string = key_file.get_as_text()
	key_file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var keys = json.data
		api_key = keys.get("openai_api_key", "")
		if api_key.is_empty():
			push_error("API 密钥为空")
		else:
			print("API 密钥加载成功")
	else:
		push_error("API 密钥文件解析失败")

func start_chat(user_message: String):
	"""开始对话"""
	if is_chatting:
		push_warning("正在对话中，请等待...")
		return
	
	if api_key.is_empty():
		chat_error.emit("API 密钥未配置")
		return
	
	is_chatting = true
	
	# 构建系统提示词
	var system_prompt = _build_system_prompt()
	
	# 构建消息列表
	var messages = [
		{"role": "system", "content": system_prompt}
	]
	
	# 添加对话历史（限制数量）
	var max_history = config.memory.max_conversation_history
	var history_start = max(0, current_conversation.size() - max_history)
	for i in range(history_start, current_conversation.size()):
		messages.append(current_conversation[i])
	
	# 添加用户消息
	messages.append({"role": "user", "content": user_message})
	current_conversation.append({"role": "user", "content": user_message})
	
	# 调用 API
	_call_chat_api(messages, user_message)

func _build_system_prompt() -> String:
	"""构建系统提示词"""
	var prompt_template = config.chat_model.system_prompt
	var save_mgr = get_node("/root/SaveManager")
	
	# 从 app_config.json 读取角色信息
	var app_config = _load_app_config()
	var character_name = app_config.get("character_name", "角色")
	var user_name = app_config.get("user_name", "用户")
	
	# 获取记忆上下文
	var memory_context = _get_memory_context()
	
	# 替换占位符
	var prompt = prompt_template.replace("{character_name}", character_name)
	prompt = prompt.replace("{user_name}", user_name)
	prompt = prompt.replace("{current_scene}", _get_scene_description(save_mgr.get_character_scene()))
	prompt = prompt.replace("{current_weather}", "晴朗")  # 可以后续扩展
	prompt = prompt.replace("{memory_context}", memory_context)
	
	return prompt

func _load_app_config() -> Dictionary:
	"""加载应用配置"""
	var config_path = "res://config/app_config.json"
	if not FileAccess.file_exists(config_path):
		return {}
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data
	return {}

func _get_scene_description(scene_id: String) -> String:
	"""获取场景描述"""
	var scene_names = {
		"livingroom": "客厅"
	}
	return scene_names.get(scene_id, "未知场景")

func _get_memory_context() -> String:
	"""获取记忆上下文（仅从短期记忆）"""
	var save_mgr = get_node("/root/SaveManager")
	
	# 确保 ai_data 字段存在
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": []
		}
	
	var memories = save_mgr.save_data.ai_data.memory
	
	if memories.is_empty():
		return "（这是你们的第一次对话）"
	
	var context_lines = []
	for memory in memories:
		var time_str = memory.timestamp.split("T")[1].substr(0, 5)  # 提取 HH:MM
		context_lines.append("[%s] %s" % [time_str, memory.content])
	
	return "\n".join(context_lines)

func _call_chat_api(messages: Array, user_message: String):
	"""调用对话 API"""
	var chat_config = config.chat_model
	var url = chat_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	# 构建请求体 - 确保格式正确
	var body = {
		"model": chat_config.model,
		"messages": messages,
		"max_tokens": int(chat_config.max_tokens),
		"temperature": float(chat_config.temperature),
		"top_p": float(chat_config.top_p)
	}
	
	var json_body = JSON.stringify(body)
	
	# 记录完整的请求日志（包含 JSON 请求体）
	_log_api_request("CHAT_REQUEST", body, json_body)
	
	# 存储用户消息用于后续处理
	http_request.set_meta("user_message", user_message)
	http_request.set_meta("request_type", "chat")
	http_request.set_meta("messages", messages)
	http_request.set_meta("request_body", body)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		is_chatting = false
		chat_error.emit("HTTP 请求失败: " + str(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""HTTP 请求完成回调"""
	var request_type = http_request.get_meta("request_type", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		is_chatting = false
		chat_error.emit("请求失败: " + str(result))
		return
	
	if response_code != 200:
		is_chatting = false
		var error_text = body.get_string_from_utf8()
		var error_msg = "API 错误 (%d): %s" % [response_code, error_text]
		print(error_msg)
		chat_error.emit(error_msg)
		
		# 记录详细的错误信息
		var request_body = http_request.get_meta("request_body", {})
		_log_api_error(response_code, error_text, request_body)
		return
	
	var json_string = body.get_string_from_utf8()
	var json = JSON.new()
	
	if json.parse(json_string) != OK:
		is_chatting = false
		chat_error.emit("响应解析失败")
		return
	
	var response = json.data
	
	if request_type == "chat":
		_handle_chat_response(response)
	elif request_type == "summary":
		_handle_summary_response(response)

func _handle_chat_response(response: Dictionary):
	"""处理对话响应"""
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
	
	# 调用总结 API
	_call_summary_api(conversation_text)
	
	# 清空当前对话
	current_conversation.clear()

func _flatten_conversation() -> String:
	"""扁平化对话历史"""
	var lines = []
	
	# 从 app_config.json 读取角色信息
	var app_config = _load_app_config()
	var char_name = app_config.get("character_name", "角色")
	var user_name = app_config.get("user_name", "用户")
	
	for msg in current_conversation:
		if msg.role == "user":
			lines.append("%s：%s" % [user_name, msg.content])
		elif msg.role == "assistant":
			lines.append("%s：%s" % [char_name, msg.content])
	
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
	
	# 保存到记忆
	_save_memory(summary)
	
	# 发送信号
	summary_completed.emit(summary)

func _save_memory(summary: String):
	"""保存记忆到存档"""
	var save_mgr = get_node("/root/SaveManager")
	
	# 确保 ai_data 字段存在
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": []
		}
	
	var timestamp = Time.get_datetime_string_from_system()
	
	var memory_item = {
		"timestamp": timestamp,
		"content": summary
	}
	
	# 添加到短期记忆（存档中）
	save_mgr.save_data.ai_data.memory.append(memory_item)
	
	# 检查是否超过最大条目数
	var max_items = config.memory.max_memory_items
	if save_mgr.save_data.ai_data.memory.size() > max_items:
		save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)
	
	# 保存到存档
	save_mgr.save_game(save_mgr.current_slot)
	
	# 同时追加到永久存储文件（独立文件）
	_append_to_permanent_storage(memory_item)
	
	print("记忆已保存: ", summary)

func _append_to_permanent_storage(memory_item: Dictionary):
	"""追加到永久存储文件（独立于存档）"""
	var storage_dir = "user://ai_storage"
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录进行永久存储")
		return
	
	if not dir.dir_exists("ai_storage"):
		var err = dir.make_dir("ai_storage")
		if err != OK:
			print("错误: 无法创建 ai_storage 目录，错误码: ", err)
			return
	
	# 使用 JSONL 格式（每行一个 JSON 对象），便于追加
	var storage_path = storage_dir + "/permanent_memory.jsonl"
	var file = FileAccess.open(storage_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(storage_path, FileAccess.WRITE)
		if file == null:
			var err = FileAccess.get_open_error()
			print("错误: 无法创建永久存储文件，错误码: ", err)
			return
	else:
		file.seek_end()
	
	# 追加一行 JSON
	file.store_line(JSON.stringify(memory_item))
	file.close()
	
	print("永久存储已更新")

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
