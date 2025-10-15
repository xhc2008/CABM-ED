extends Node

# 提示词构建器 - 负责构建 AI 对话的系统提示词
# 自动加载单例

var config: Dictionary = {}

func _ready():
	_load_config()

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
		print("PromptBuilder: AI 配置加载成功")
	else:
		push_error("PromptBuilder: AI 配置解析失败")

func build_system_prompt(trigger_mode: String = "user_initiated") -> String:
	"""构建系统提示词"""
	if config.is_empty():
		push_error("PromptBuilder: 配置未加载")
		return ""
	
	var prompt_template = config.chat_model.system_prompt
	var save_mgr = get_node("/root/SaveManager")
	
	# 从 app_config.json 读取角色名称
	var app_config = _load_app_config()
	var character_name = app_config.get("character_name", "角色")
	
	# 从存档系统读取用户名
	var user_name = save_mgr.get_user_name()
	
	# 获取记忆上下文
	var memory_context = get_memory_context()
	
	# 从mood_config.json生成moods列表
	var moods = _generate_moods_list()
	
	# 获取触发上下文
	var trigger_context = _get_trigger_context(trigger_mode)
	
	# 获取好感度和交互意愿
	var affection = save_mgr.get_affection()
	var interaction_will = save_mgr.get_reply_willingness()
	
	# 转换为"高/中/低"
	var affection_level = _convert_to_level(affection, 100)
	var interaction_level = _convert_to_level(interaction_will, 150)
	
	# 获取当前心情的文字描述
	var current_mood = get_current_mood_name(save_mgr.get_mood())
	
	# 格式化当前时间
	var current_time = _format_current_time()
	
	# 替换占位符
	var prompt = prompt_template.replace("{character_name}", character_name)
	prompt = prompt.replace("{user_name}", user_name)
	prompt = prompt.replace("{current_scene}", _get_scene_description(save_mgr.get_character_scene()))
	prompt = prompt.replace("{current_weather}", _get_weather_description(save_mgr.get_current_weather()))
	prompt = prompt.replace("{memory_context}", memory_context)
	prompt = prompt.replace("{moods}", moods)
	prompt = prompt.replace("{trigger_context}", trigger_context)
	prompt = prompt.replace("{affection_level}", affection_level)
	prompt = prompt.replace("{interaction_level}", interaction_level)
	prompt = prompt.replace("{current_mood}", current_mood)
	prompt = prompt.replace("{current_time}", current_time)
	
	return prompt

func _generate_moods_list() -> String:
	"""从mood_config.json生成moods列表字符串"""
	var mood_config_path = "res://config/mood_config.json"
	if not FileAccess.file_exists(mood_config_path):
		# 如果配置文件不存在，使用默认值
		return "0=平静, 1=开心, 2=难过, 3=生气, 4=惊讶, 5=害怕, 6=厌恶"
	
	var file = FileAccess.open(mood_config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return "0=平静, 1=开心, 2=难过, 3=生气, 4=惊讶, 5=害怕, 6=厌恶"
	
	var mood_config = json.data
	if not mood_config.has("moods"):
		return "0=平静, 1=开心, 2=难过, 3=生气, 4=惊讶, 5=害怕, 6=厌恶"
	
	var moods_array = []
	for mood in mood_config.moods:
		moods_array.append("%d=%s" % [mood.id, mood.name])
	
	return ", ".join(moods_array)

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

func _get_weather_description(weather_id: String) -> String:
	"""获取天气描述"""
	var weather_names = {
		"sunny": "晴天",
		"rainy": "雨天",
		"storm": "雷雨"
	}
	return weather_names.get(weather_id, "晴天")

func _convert_to_level(value: int, max_value: int) -> String:
	"""将数值转换为"高/中/低"等级"""
	var percentage = float(value) / float(max_value)
	if percentage >= 0.7:
		return "高"
	elif percentage >= 0.3:
		return "中"
	else:
		return "低"

func get_current_mood_name(mood_id: String) -> String:
	"""获取当前心情的中文名称"""
	var mood_config_path = "res://config/mood_config.json"
	if not FileAccess.file_exists(mood_config_path):
		return "平静"
	
	var file = FileAccess.open(mood_config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return "平静"
	
	var mood_config = json.data
	if not mood_config.has("moods"):
		return "平静"
	
	for mood in mood_config.moods:
		if mood.name_en == mood_id:
			return mood.name
	
	return "平静"

func _format_current_time() -> String:
	"""格式化当前时间为"xx月xx日xx:xx，星期x"格式"""
	var datetime = Time.get_datetime_dict_from_system()
	
	var weekdays = ["日", "一", "二", "三", "四", "五", "六"]
	var weekday = weekdays[datetime.weekday]
	
	return "%d月%d日%02d:%02d，星期%s" % [
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		weekday
	]

func _get_trigger_context(trigger_mode: String) -> String:
	"""获取触发上下文文本"""
	if not config.has("chat_model") or not config.chat_model.has("trigger_contexts"):
		# 如果配置中没有trigger_contexts，使用默认值
		if trigger_mode == "character_initiated":
			return "现在，你想主动找用户聊天，说点什么吧。"
		elif trigger_mode == "ongoing":
			return "你在和用户聊天。"
		else:
			return "现在，用户找你聊天。"
	
	var trigger_contexts = config.chat_model.trigger_contexts
	return trigger_contexts.get(trigger_mode, "你在和用户聊天。")

func get_memory_context() -> String:
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

func get_mood_name_en(mood_id: int) -> String:
	"""根据mood ID获取英文名称"""
	var mood_config_path = "res://config/mood_config.json"
	if not FileAccess.file_exists(mood_config_path):
		return ""
	
	var file = FileAccess.open(mood_config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return ""
	
	var mood_config = json.data
	if not mood_config.has("moods"):
		return ""
	
	for mood in mood_config.moods:
		if mood.id == mood_id:
			return mood.name_en
	
	return ""
