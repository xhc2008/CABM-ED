extends Node

# 离线时间管理器 - 处理玩家离线期间的数值变化
# 根据离线时长调整角色状态

const MOOD_CONFIG_PATH = "res://config/mood_config.json"

var mood_list: Array = []

func _ready():
	_load_mood_config()

func _load_mood_config():
	"""加载心情配置"""
	if not FileAccess.file_exists(MOOD_CONFIG_PATH):
		print("警告: 心情配置文件不存在")
		return
	
	var file = FileAccess.open(MOOD_CONFIG_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var data = json.data
		if data.has("moods"):
			mood_list = data.moods

func check_and_apply_offline_changes():
	"""检查并应用离线时间变化"""
	# 尝试获取Unix时间戳格式的时间（新格式）
	var last_played_unix = SaveManager.save_data.timestamp.get("last_played_at_unix", 0.0)
	
	# 如果没有Unix时间戳，尝试从字符串解析（旧格式兼容）
	if last_played_unix == 0.0:
		var last_played_str = SaveManager.save_data.timestamp.get("last_played_at", "")
		if last_played_str == "":
			print("首次进入游戏，无需处理离线时间")
			return
		last_played_unix = _parse_datetime(last_played_str)
	
	var current_time = Time.get_unix_time_from_system()
	
	print("=== 离线时间检查 ===")
	print("上次游玩时间: ", Time.get_datetime_string_from_unix_time(int(last_played_unix)))
	print("当前时间: ", Time.get_datetime_string_from_system())
	print("上次游玩Unix时间戳: ", last_played_unix)
	print("当前Unix时间戳: ", current_time)
	
	# 计算离线时长（秒）
	var offline_seconds = current_time - last_played_unix
	var offline_minutes = offline_seconds / 60.0
	var offline_hours = offline_minutes / 60.0
	
	print("离线时长: %.2f 秒 (%.2f 分钟, %.2f 小时)" % [offline_seconds, offline_minutes, offline_hours])
	
	# 如果离线时间是负数，说明系统时间被修改或有其他问题
	if offline_seconds < 0:
		print("警告: 离线时间为负数，可能是系统时间被修改。跳过离线处理。")
		print("===================\n")
		return
	
	# 根据离线时长应用不同的变化
	if offline_minutes < 5:
		print("离线时间小于5分钟，无变化")
		_apply_no_change()
	elif offline_hours < 3:
		print("离线时间 5分钟~3小时")
		_apply_short_offline(offline_minutes)
	elif offline_hours < 24:
		print("离线时间 3小时~24小时")
		_apply_medium_offline(offline_hours)
	else:
		print("离线时间 24小时以上")
		_apply_long_offline(offline_hours)
	
	print("===================\n")

func _apply_no_change():
	"""小于5分钟：无变化"""
	pass

func _apply_short_offline(_minutes: float):
	"""5分钟~3小时：心情变化，回复意愿随机增加-30~30"""
	# 心情变化
	_change_mood_randomly()
	
	# 回复意愿随机增加-30~30
	var current_willingness = SaveManager.get_reply_willingness()
	var change = randi_range(-30, 30)
	var new_willingness = clamp(current_willingness + change, 0, 100)
	SaveManager.set_reply_willingness(new_willingness)
	
	print("回复意愿变化: %d -> %d (变化: %+d)" % [current_willingness, new_willingness, change])

func _apply_medium_offline(_hours: float):
	"""3小时~24小时：心情变化；好感度随机增加-20~10；回复意愿随机增加0~50"""
	# 心情变化
	_change_mood_randomly()
	
	# 好感度随机增加-20~10
	var current_affection = SaveManager.get_affection()
	var affection_change = randi_range(-20, 10)
	var new_affection = current_affection + affection_change
	SaveManager.set_affection(new_affection)
	
	print("好感度变化: %d -> %d (变化: %+d)" % [current_affection, new_affection, affection_change])
	
	# 回复意愿随机增加0~50
	var current_willingness = SaveManager.get_reply_willingness()
	var willingness_change = randi_range(0, 50)
	var new_willingness = clamp(current_willingness + willingness_change, 0, 100)
	SaveManager.set_reply_willingness(new_willingness)
	
	print("回复意愿变化: %d -> %d (变化: %+d)" % [current_willingness, new_willingness, willingness_change])

func _apply_long_offline(_hours: float):
	"""24小时以上：心情变化；好感度增加-50~0；回复意愿随机置为70~100"""
	# 心情变化
	_change_mood_randomly()
	
	# 好感度增加-50~0
	var current_affection = SaveManager.get_affection()
	var affection_change = randi_range(-50, 0)
	var new_affection = current_affection + affection_change
	SaveManager.set_affection(new_affection)
	
	print("好感度变化: %d -> %d (变化: %+d)" % [current_affection, new_affection, affection_change])
	
	# 回复意愿随机置为70~100
	var new_willingness = randi_range(70, 100)
	SaveManager.set_reply_willingness(new_willingness)
	
	print("回复意愿重置为: %d" % new_willingness)

func _change_mood_randomly():
	"""随机改变心情，平静权重最高"""
	if mood_list.is_empty():
		print("警告: 心情列表为空，无法改变心情")
		return
	
	var current_mood = SaveManager.get_mood()
	
	# 创建加权心情列表
	var weighted_moods = []
	
	for mood in mood_list:
		var mood_name = mood.get("name_en", "calm")
		
		# 平静权重为5，其他心情权重为1
		var weight = 5 if mood_name == "calm" else 1
		
		for i in range(weight):
			weighted_moods.append(mood_name)
	
	# 从加权列表中随机选择
	var new_mood = weighted_moods[randi() % weighted_moods.size()]
	SaveManager.set_mood(new_mood)
	
	print("心情变化: %s -> %s" % [current_mood, new_mood])

func _parse_datetime(datetime_str: String) -> float:
	"""解析日期时间字符串为Unix时间戳"""
	# Godot的Time.get_datetime_string_from_system()返回格式: "2025-10-14T15:30:45"
	# 这是本地时间，我们需要转换为Unix时间戳
	
	var parts = datetime_str.split("T")
	if parts.size() != 2:
		print("警告: 日期时间格式错误: ", datetime_str)
		return Time.get_unix_time_from_system()
	
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	
	if date_parts.size() != 3 or time_parts.size() != 3:
		print("警告: 日期时间格式错误: ", datetime_str)
		return Time.get_unix_time_from_system()
	
	# 构建完整的datetime字典
	var datetime_dict = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"weekday": 0,  # 不重要，但需要提供
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2]),
		"dst": false  # 夏令时
	}
	
	# Time.get_unix_time_from_datetime_dict 使用的是UTC时间
	# 但 Time.get_datetime_string_from_system() 返回的是本地时间
	# 所以我们需要使用 Time.get_unix_time_from_datetime_string()
	# 但这个函数不存在，所以我们用另一种方法
	
	# 获取当前的时区偏移
	var current_dict = Time.get_datetime_dict_from_system()
	var current_unix = Time.get_unix_time_from_system()
	var utc_dict = Time.get_datetime_dict_from_unix_time(current_unix)
	
	# 计算时区偏移（秒）
	var timezone_offset = (current_dict.hour - utc_dict.hour) * 3600
	
	# 转换为Unix时间戳（UTC）
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime_dict)
	
	# 调整时区偏移
	unix_time -= timezone_offset
	
	return unix_time
