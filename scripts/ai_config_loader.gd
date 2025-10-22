extends Node

# AI 配置加载器
# 负责加载和管理 AI 配置和 API 密钥

var config: Dictionary = {}
var api_key: String = ""

func load_all():
	"""加载所有配置"""
	_load_config()
	_load_api_key()

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
	
	if FileAccess.file_exists(new_key_path):
		_load_new_format_config(new_key_path)
		return
	
	if FileAccess.file_exists(old_key_path):
		_load_old_format_config(old_key_path)
		return
	
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
		api_key = user_config.get("api_key", "")
		if api_key.is_empty():
			push_error("API 密钥为空")
		else:
			print("API 密钥加载成功 (简单模式)")
	
	elif mode == "detailed":
		if user_config.has("chat_model"):
			var chat = user_config.chat_model
			config.chat_model.model = chat.get("model", config.chat_model.model)
			config.chat_model.base_url = chat.get("base_url", config.chat_model.base_url)
			api_key = chat.get("api_key", "")
		
		if user_config.has("summary_model"):
			var summary = user_config.summary_model
			config.summary_model.model = summary.get("model", config.summary_model.model)
			config.summary_model.base_url = summary.get("base_url", config.summary_model.base_url)
		
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
