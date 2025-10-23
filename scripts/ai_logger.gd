extends Node

# AI 日志记录器
# 负责记录 API 调用、响应和错误

func log_api_call(log_type: String, messages: Array, response: String):
	"""记录 API 调用日志"""
	var log_dir = "user://ai_logs"
	_ensure_log_dir(log_dir)
	
	var log_path = log_dir + "/log.txt"
	var log_file = _open_log_file(log_path)
	if log_file == null:
		return
	
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

func log_api_request(log_type: String, body: Dictionary, json_body: String):
	"""记录完整的 API 请求"""
	var log_dir = "user://ai_logs"
	_ensure_log_dir(log_dir)
	
	var log_path = log_dir + "/log.txt"
	var log_file = _open_log_file(log_path)
	if log_file == null:
		return
	
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

func log_api_error(status_code: int, error_text: String, request_body: Dictionary):
	"""记录 API 错误的详细信息"""
	var log_dir = "user://ai_logs"
	_ensure_log_dir(log_dir)
	
	var log_path = log_dir + "/log.txt"
	var log_file = _open_log_file(log_path)
	if log_file == null:
		return
	
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

func save_to_diary(summary: String, conversation_text: String):
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
	
	var datetime = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]
	var time_str = "%02d:%02d:%02d" % [datetime.hour, datetime.minute, datetime.second]
	
	var diary_path = diary_dir + "/" + date_str + ".jsonl"
	
	var diary_record = {
		"type": "chat",
		"timestamp": time_str,
		"summary": summary,
		"conversation": conversation_text
	}
	
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

func _ensure_log_dir(_log_dir: String):
	"""确保日志目录存在"""
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录进行日志记录")
		return
	
	if not dir.dir_exists("ai_logs"):
		var err = dir.make_dir("ai_logs")
		if err != OK:
			print("错误: 无法创建 ai_logs 目录，错误码: ", err)

func _open_log_file(log_path: String):
	"""打开日志文件"""
	var log_file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if log_file == null:
		log_file = FileAccess.open(log_path, FileAccess.WRITE)
		if log_file == null:
			var err = FileAccess.get_open_error()
			print("错误: 无法创建日志文件，错误码: ", err)
			return null
	else:
		log_file.seek_end()
	return log_file
