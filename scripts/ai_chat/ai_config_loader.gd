extends Node

# AI 配置加载器
# 职责：加载和管理 AI 配置和 API 密钥
# 加载策略：
# - api_key, base_url, model: 只从用户配置(user://ai_keys.json)加载
# - 其他配置：只从项目配置(res://config/ai_config.json)加载
# - 不回退，不混合，配置缺失就留空

var config: Dictionary = {}  # 合并后的完整配置
var api_key: String = ""     # 主 API 密钥

func load_all():
	"""加载所有配置"""
	_load_project_config()  # 先加载项目配置作为基础
	_load_user_config()     # 再加载用户配置覆盖特定字段

func _load_project_config():
	"""加载项目配置文件中的配置"""
	var config_path = "res://config/ai_config.json"
	if not FileAccess.file_exists(config_path):
		push_error("AI 项目配置文件不存在: " + config_path)
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("无法打开项目配置文件")
		return
	
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) == OK:
		config = json.data
		print("AI 项目配置加载成功")
	else:
		push_error("AI 项目配置解析失败")

func _load_user_config():
	"""加载用户配置文件中的 API 密钥和模型配置"""
	var user_config_path = "user://ai_keys.json"
	if not FileAccess.file_exists(user_config_path):
		push_error("AI 用户配置文件不存在: " + user_config_path)
		return

	var file = FileAccess.open(user_config_path, FileAccess.READ)
	if not file:
		push_error("无法打开用户配置文件")
		return
	
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("用户配置解析失败")
		return

	var user_config = json.data
	
	# 处理每个模型的配置：只更新 api_key, base_url, model
	_update_model_config("chat_model", user_config)
	_update_model_config("summary_model", user_config)
	_update_model_config("relationship_model", user_config)
	_update_model_config("tts_model", user_config)
	_update_model_config("embedding_model", user_config)
	_update_model_config("view_model", user_config)
	_update_model_config("stt_model", user_config)
	_update_model_config("rerank_model", user_config)
	
	# 兼容旧格式：直接读取 api_key 字段
	if user_config.has("api_key"):
		api_key = user_config.api_key
	
	print("AI 用户配置加载成功")

func _update_model_config(model_name: String, user_config: Dictionary):
	"""更新指定模型的配置（仅更新 api_key, base_url, model）"""
	if not user_config.has(model_name):
		return
	
	var user_model_config = user_config[model_name]
	
	# 确保配置字典中有该模型
	if not config.has(model_name):
		config[model_name] = {}
	
	# 只更新特定字段
	if user_model_config.has("api_key"):
		config[model_name]["api_key"] = user_model_config.api_key
		# 如果是 chat_model，也设置主 api_key
		if model_name == "chat_model" and api_key.is_empty():
			api_key = user_model_config.api_key
	
	if user_model_config.has("base_url"):
		config[model_name]["base_url"] = user_model_config.base_url
	
	if user_model_config.has("model"):
		config[model_name]["model"] = user_model_config.model

