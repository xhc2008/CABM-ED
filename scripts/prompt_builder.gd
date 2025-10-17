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
	
	# 转换为描述文本
	var affection_level = _convert_affection_to_text(affection)
	var interaction_level = _convert_willingness_to_text(interaction_will)
	
	# 获取当前心情的文字描述
	var current_mood = get_current_mood_name(save_mgr.get_mood())
	
	# 格式化当前时间
	var current_time = _format_current_time()
	
	# 生成场景列表
	var scenes_list = _generate_scenes_list()
	
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
	prompt = prompt.replace("{scenes}", scenes_list)
	
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

func _generate_scenes_list() -> String:
	"""从scenes.json生成场景列表字符串"""
	var scenes_config = _load_scenes_config()
	if not scenes_config.has("scenes"):
		return "0=客厅, 1=卧室, 2=浴室, 3=书房"
	
	var scenes_array = []
	var index = 0
	for scene_id in scenes_config.scenes:
		var scene_name = scenes_config.scenes[scene_id].get("name", scene_id)
		scenes_array.append("%d=%s" % [index, scene_name])
		index += 1
	
	return ", ".join(scenes_array)

func get_scene_id_by_index(index: int) -> String:
	"""根据索引获取场景ID"""
	var scenes_config = _load_scenes_config()
	if not scenes_config.has("scenes"):
		return ""
	
	var scene_ids = scenes_config.scenes.keys()
	if index >= 0 and index < scene_ids.size():
		return scene_ids[index]
	
	return ""

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
	"""获取场景描述（从配置文件读取）"""
	var scenes_config = _load_scenes_config()
	if scenes_config.has("scenes") and scenes_config.scenes.has(scene_id):
		return scenes_config.scenes[scene_id].get("name", "未知场景")
	return "未知场景"

func _get_weather_description(weather_id: String) -> String:
	"""获取天气描述（从配置文件读取）"""
	var save_mgr = get_node("/root/SaveManager")
	var current_scene = save_mgr.get_character_scene()
	
	var scenes_config = _load_scenes_config()
	if scenes_config.has("scenes") and scenes_config.scenes.has(current_scene):
		var scene = scenes_config.scenes[current_scene]
		if scene.has("weathers") and scene.weathers.has(weather_id):
			return scene.weathers[weather_id]
	
	# 如果找不到，返回默认值
	return "晴天"

func _load_scenes_config() -> Dictionary:
	"""加载场景配置"""
	var config_path = "res://config/scenes.json"
	if not FileAccess.file_exists(config_path):
		return {}
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data
	return {}

func _convert_affection_to_text(affection: int) -> String:
	"""将好感度数值转换为描述文本"""
	# TODO: 根据需要自定义好感度描述
	var percentage = float(affection) / 100.0
	if percentage >= 0.8:
		return "高，愿意进行亲密互动"
	elif percentage >= 0.6:
		return "高"
	elif percentage >= 0.4:
		return "中"
	elif percentage >= 0.2:
		return "低"
	else:
		return "低，有些反感"

func _convert_willingness_to_text(willingness: int) -> String:
	"""将回复意愿数值转换为描述文本"""
	# TODO: 根据需要自定义回复意愿描述
	var percentage = float(willingness) / 100.0
	if percentage >= 0.8:
		return "高，乐意交流"
	elif percentage >= 0.6:
		return "中，愿意交流"
	elif percentage >= 0.4:
		return "中，略显冷漠"
	elif percentage >= 0.2:
		return "中，比较冷淡"
	else:
		return "低，不想互动"

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
		# timestamp 格式: "2024-01-15T14:30:00"
		# 提取为 "MM-DD HH:MM" 格式
		var timestamp_parts = memory.timestamp.split("T")
		if timestamp_parts.size() >= 2:
			var date_part = timestamp_parts[0] # "2024-01-15"
			var time_part = timestamp_parts[1] # "14:30:00"
			
			var date_components = date_part.split("-")
			var time_str = time_part.substr(0, 5) # "14:30"
			
			if date_components.size() >= 3:
				var month = date_components[1]
				var day = date_components[2]
				var formatted_time = "%s-%s %s" % [month, day, time_str]
				context_lines.append("[%s] %s" % [formatted_time, memory.content])
			else:
				# 如果日期格式不对，只显示时间
				context_lines.append("[%s] %s" % [time_str, memory.content])
		else:
			# 如果时间戳格式不对，直接显示内容
			context_lines.append("%s" % memory.content)
	
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
