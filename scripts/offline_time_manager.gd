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
	# 检查初始设置是否完成，如果未完成则跳过离线时间检查
	if not SaveManager.is_initial_setup_completed:
		print("初始设置未完成，跳过离线时间检查")
		return
	
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
	
	# 获取本地时间用于显示
	var timezone_offset = _get_timezone_offset()
	var last_played_local = Time.get_datetime_dict_from_unix_time(int(last_played_unix + timezone_offset))
	var current_local = Time.get_datetime_dict_from_unix_time(int(current_time + timezone_offset))
	
	print("=== 离线时间检查 ===")
	print("上次游玩时间（本地）: %04d-%02d-%02d %02d:%02d:%02d" % [
		last_played_local.year, last_played_local.month, last_played_local.day,
		last_played_local.hour, last_played_local.minute, last_played_local.second
	])
	print("当前时间（本地）: %04d-%02d-%02d %02d:%02d:%02d" % [
		current_local.year, current_local.month, current_local.day,
		current_local.hour, current_local.minute, current_local.second
	])
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
	_trigger_offline_position_change()
	pass

func _trigger_offline_position_change():
	"""触发离线位置变化（无字幕播报）"""
	# 设置标记，让主场景在加载完成后应用位置变化
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.set_meta("pending_offline_position_change", true)
		print("已标记离线位置变化待应用")

func _apply_short_offline(minutes: float):
	"""5分钟~3小时：心情变化，回复意愿随机增加-10~30，触发位置变化，生成1-2条日记"""
	# 心情变化
	_change_mood_randomly()
	
	# 回复意愿随机增加-10~30（使用统一的边界控制）
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		var change = randi_range(-10, 30)
		helpers.modify_willingness(change)
	else:
		# 降级方案：直接使用 SaveManager
		var current_willingness = SaveManager.get_reply_willingness()
		var change = randi_range(-10, 30)
		var new_willingness = clamp(current_willingness + change, 0, 150)
		SaveManager.set_reply_willingness(new_willingness)
		print("回复意愿变化: %d -> %d (变化: %+d)" % [current_willingness, new_willingness, change])
	
	# 触发位置变化
	_trigger_offline_position_change()
	
	# 生成日记（0-2条）
	var event_count = randi_range(0, 2)
	_generate_character_diary(minutes, event_count)

func _apply_medium_offline(hours: float):
	"""3小时~24小时：心情变化；好感度随机增加-20~10；回复意愿随机增加0~50；触发位置变化；生成3-5条日记"""
	# 心情变化
	_change_mood_randomly()
	
	# 使用统一的边界控制
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		
		# 好感度随机增加-20~10
		var affection_change = randi_range(-20, 10)
		helpers.modify_affection(affection_change)
		
		# 回复意愿随机增加0~50
		var willingness_change = randi_range(0, 50)
		helpers.modify_willingness(willingness_change)
	else:
		# 降级方案：直接使用 SaveManager
		var current_affection = SaveManager.get_affection()
		var affection_change = randi_range(-20, 10)
		var new_affection = clamp(current_affection + affection_change, 0, 100)
		SaveManager.set_affection(new_affection)
		print("好感度变化: %d -> %d (变化: %+d)" % [current_affection, new_affection, affection_change])
		
		var current_willingness = SaveManager.get_reply_willingness()
		var willingness_change = randi_range(0, 50)
		var new_willingness = clamp(current_willingness + willingness_change, 0, 150)
		SaveManager.set_reply_willingness(new_willingness)
		print("回复意愿变化: %d -> %d (变化: %+d)" % [current_willingness, new_willingness, willingness_change])
	
	# 触发位置变化
	_trigger_offline_position_change()
	
	# 生成日记（3-5条）
	var event_count = randi_range(3, 5)
	_generate_character_diary(hours * 60, event_count)

func _apply_long_offline(hours: float):
	"""24小时以上：心情变化；好感度增加-50~0；回复意愿随机置为70~100；触发位置变化；生成6-10条日记"""
	# 心情变化
	_change_mood_randomly()
	
	# 使用统一的边界控制
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		
		# 好感度增加-50~0
		var affection_change = randi_range(-50, 0)
		helpers.modify_affection(affection_change)
		
		# 回复意愿随机置为70~100
		var new_willingness = randi_range(70, 100)
		helpers.set_willingness_safe(new_willingness)
	else:
		# 降级方案：直接使用 SaveManager
		var current_affection = SaveManager.get_affection()
		var affection_change = randi_range(-50, 0)
		var new_affection = clamp(current_affection + affection_change, 0, 100)
		SaveManager.set_affection(new_affection)
		print("好感度变化: %d -> %d (变化: %+d)" % [current_affection, new_affection, affection_change])
		
		var new_willingness = randi_range(70, 100)
		var clamped_willingness = clamp(new_willingness, 0, 150)
		SaveManager.set_reply_willingness(clamped_willingness)
		print("回复意愿重置为: %d" % clamped_willingness)
	
	# 触发位置变化
	_trigger_offline_position_change()
	
	# 生成日记（6-10条）
	var event_count = randi_range(6, 10)
	_generate_character_diary(hours * 60, event_count)

func _change_mood_randomly():
	"""随机改变心情，根据配置文件中的权重"""
	if mood_list.is_empty():
		print("警告: 心情列表为空，无法改变心情")
		return
	
	var current_mood = SaveManager.get_mood()
	
	# 创建加权心情列表
	var weighted_moods = []
	
	for mood in mood_list:
		var mood_name = mood.get("name_en", "calm")
		var weight = mood.get("weight", 1) # 从配置文件读取权重，默认为1
		
		for i in range(weight):
			weighted_moods.append(mood_name)
	
	# 从加权列表中随机选择
	var new_mood = weighted_moods[randi() % weighted_moods.size()]
	SaveManager.set_mood(new_mood)
	
	print("心情变化: %s -> %s" % [current_mood, new_mood])

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

func _parse_datetime(datetime_str: String) -> float:
	"""解析日期时间字符串为Unix时间戳（兼容旧格式）"""
	var parts = datetime_str.split("T")
	if parts.size() != 2:
		print("警告: 日期时间格式错误: ", datetime_str)
		return Time.get_unix_time_from_system()
	
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	
	if date_parts.size() != 3 or time_parts.size() != 3:
		print("警告: 日期时间格式错误: ", datetime_str)
		return Time.get_unix_time_from_system()
	
	var datetime_dict = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"weekday": 0,
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2]),
		"dst": false
	}
	
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime_dict)
	unix_time -= _get_timezone_offset()
	
	return unix_time


func _generate_character_diary(offline_minutes: float, event_count: int):
	"""生成角色日记"""
	if event_count <= 0:
		print("事件数为0，跳过日记生成")
		return
	
	print("开始生成角色日记，离线时长: %.2f 分钟，事件数: %d" % [offline_minutes, event_count])
	
	# 获取当前时间和时区偏移
	var current_unix = Time.get_unix_time_from_system()
	var timezone_offset = _get_timezone_offset()
	
	# 计算开始和结束的 Unix 时间戳
	var start_unix = current_unix - (offline_minutes * 60)
	var end_unix = current_unix
	
	# 转换为本地时间
	var start_datetime = Time.get_datetime_dict_from_unix_time(int(start_unix + timezone_offset))
	var end_datetime = Time.get_datetime_dict_from_unix_time(int(end_unix + timezone_offset))
	
	# 格式化时间字符串
	var start_time = "%04d年%02d月%02d日%02d:%02d" % [
		start_datetime.year, start_datetime.month, start_datetime.day,
		start_datetime.hour, start_datetime.minute
	]
	var end_time = "%04d年%02d月%02d日%02d:%02d" % [
		end_datetime.year, end_datetime.month, end_datetime.day,
		end_datetime.hour, end_datetime.minute
	]
	
	print("日记时间范围（本地）: %s 到 %s" % [start_time, end_time])
	
	# 构建提示词
	var prompt_builder = get_node("/root/PromptBuilder")
	var system_prompt = prompt_builder.build_offline_diary_prompt(start_time, end_time, event_count)
	
	# 调用AI生成日记
	_call_diary_generation_api(system_prompt, start_datetime, end_datetime)

func _call_diary_generation_api(system_prompt: String, start_datetime: Dictionary, end_datetime: Dictionary):
	"""调用AI API生成日记"""
	if not has_node("/root/AIService"):
		print("错误: AIService 未加载")
		return
	
	var ai_service = get_node("/root/AIService")
	
	# 检查API密钥
	if ai_service.api_key.is_empty():
		print("错误: API密钥未配置，跳过日记生成")
		return
	
	var chat_config = ai_service.config.chat_model
	var url = chat_config.base_url + "/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + ai_service.api_key
	]
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": "请生成日记"}
	]
	
	var body = {
		"model": chat_config.model,
		"messages": messages,
		"max_tokens": 1024,
		"temperature": 1.0,
		"top_p": 0.9,
		"response_format": {"type": "json_object"}
	}
	
	var json_body = JSON.stringify(body)
	
	# 创建临时HTTP请求
	var http = HTTPRequest.new()
	add_child(http)
	
	# 存储上下文信息
	http.set_meta("start_datetime", start_datetime)
	http.set_meta("end_datetime", end_datetime)
	
	http.request_completed.connect(_on_diary_generation_completed.bind(http))
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		print("日记生成请求失败: ", error)
		http.queue_free()

func _on_diary_generation_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	"""日记生成完成回调"""
	# 获取上下文
	var start_datetime = http.get_meta("start_datetime")
	var end_datetime = http.get_meta("end_datetime")
	
	# 清理HTTP请求节点
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("日记生成请求失败: ", result)
		return
	
	if response_code != 200:
		print("日记生成API错误: ", response_code)
		print("响应: ", body.get_string_from_utf8())
		return
	
	var response_text = body.get_string_from_utf8()
	
	var json = JSON.new()
	if json.parse(response_text) != OK:
		print("日记响应解析失败")
		return
	
	var response = json.data
	if not response.has("choices") or response.choices.is_empty():
		print("日记响应格式错误")
		return
	
	var content = response.choices[0].message.content
	print("收到日记内容: ", content)
	
	# 解析日记内容
	_parse_and_save_diary(content, start_datetime, end_datetime)

func _clean_json_content(content: String) -> String:
	"""清理JSON内容，移除markdown包裹"""
	var clean = content
	if clean.contains("```json"):
		clean = clean.substr(clean.find("```json") + 7)
	elif clean.contains("```"):
		clean = clean.substr(clean.find("```") + 3)
	
	if clean.contains("```"):
		clean = clean.substr(0, clean.find("```"))
	
	return clean.strip_edges()

func _parse_and_save_diary(content: String, start_datetime: Dictionary, end_datetime: Dictionary):
	"""解析并保存日记"""
	var clean_content = _clean_json_content(content)
	
	# 解析JSON
	var json = JSON.new()
	if json.parse(clean_content) != OK:
		print("日记内容JSON解析失败: ", json.get_error_message())
		print("尝试解析的内容: ", clean_content.substr(0, 200))
		return
	
	var diary_data = json.data
	var diary_events = []
	
	# 处理两种可能的格式
	if diary_data is Array:
		# 格式1: 直接是数组 [{"time": "...", "event": "..."}, ...]
		diary_events = diary_data
	elif diary_data is Dictionary:
		# 格式2: 包装在对象中 {"diary_entries": [...]} 或其他键名
		# 尝试常见的键名
		for key in ["diary_entries", "entries", "events", "items"]:
			if diary_data.has(key) and diary_data[key] is Array:
				diary_events = diary_data[key]
				break
		
		# 如果还是没找到，尝试第一个数组值
		if diary_events.is_empty():
			for key in diary_data:
				if diary_data[key] is Array:
					diary_events = diary_data[key]
					break
	
	# 验证是否找到了数组
	if diary_events.is_empty():
		print("日记内容格式错误，无法找到事件数组")
		print("收到的数据类型: ", typeof(diary_data))
		print("数据内容: ", str(diary_data).substr(0, 200))
		return
	
	# 验证和保存每条日记
	for event in diary_events:
		if not (event is Dictionary):
			print("日记条目格式错误，跳过")
			continue
		
		if not event.has("time"):
			print("日记条目缺少time字段，跳过")
			continue
		
		# 支持多种字段名：event, content, description
		var event_text = ""
		if event.has("event"):
			event_text = event.event
		elif event.has("content"):
			event_text = event.content
		elif event.has("description"):
			event_text = event.description
		else:
			print("日记条目缺少事件描述字段，跳过")
			continue
		
		var time_str = event.time
		
		# 验证时间格式（HH:MM）
		if not _validate_time_format(time_str):
			print("时间格式错误: ", time_str)
			continue
		
		# 保存到日记文件和记忆
		_save_diary_entry(time_str, event_text, start_datetime, end_datetime)
	
	print("角色日记生成完成")

func _validate_time_format(time_str: String) -> bool:
	"""验证时间格式 MM-DD HH:MM 或 HH:MM"""
	# 支持两种格式：
	# 1. "HH:MM" (5个字符)
	# 2. "MM-DD HH:MM" (11个字符)
	
	if time_str.length() == 5:
		# 格式: HH:MM
		if time_str[2] != ":":
			return false
		
		var parts = time_str.split(":")
		if parts.size() != 2:
			return false
		
		var hour = parts[0].to_int()
		var minute = parts[1].to_int()
		
		return hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59
	
	elif time_str.length() == 11:
		# 格式: MM-DD HH:MM
		if time_str[2] != "-" or time_str[5] != " " or time_str[8] != ":":
			return false
		
		var date_part = time_str.substr(0, 5) # MM-DD
		var time_part = time_str.substr(6, 5) # HH:MM
		
		var date_parts = date_part.split("-")
		var time_parts = time_part.split(":")
		
		if date_parts.size() != 2 or time_parts.size() != 2:
			return false
		
		var month = date_parts[0].to_int()
		var day = date_parts[1].to_int()
		var hour = time_parts[0].to_int()
		var minute = time_parts[1].to_int()
		
		return month >= 1 and month <= 12 and day >= 1 and day <= 31 and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59
	
	return false

func _extract_date_from_time(time_str: String, fallback_datetime: Dictionary) -> String:
	"""从时间字符串中提取日期
	输入: "MM-DD HH:MM" 或 "HH:MM"
	输出: "YYYY-MM-DD"
	"""
	if time_str.length() == 11:
		# 格式: MM-DD HH:MM
		var date_part = time_str.substr(0, 5) # MM-DD
		var date_parts = date_part.split("-")
		if date_parts.size() == 2:
			var month = date_parts[0].to_int()
			var day = date_parts[1].to_int()
			# 使用 fallback_datetime 的年份
			return "%04d-%02d-%02d" % [fallback_datetime.year, month, day]
	
	# 如果是 HH:MM 格式或解析失败，使用 fallback_datetime
	return "%04d-%02d-%02d" % [fallback_datetime.year, fallback_datetime.month, fallback_datetime.day]

func _ensure_diary_directory() -> bool:
	"""确保日记目录存在"""
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录")
		return false
	
	if not dir.dir_exists("diary"):
		var err = dir.make_dir("diary")
		if err != OK:
			print("错误: 无法创建 diary 目录")
			return false
	
	return true

func _save_diary_entry(time_str: String, event_text: String, start_datetime: Dictionary, _end_datetime: Dictionary):
	"""保存单条日记到文件和记忆（使用统一保存器）"""
	# 从 time_str 中提取日期，如果没有日期则使用 start_datetime
	var date_str = _extract_date_from_time(time_str, start_datetime)
	
	# 构建完整的时间戳（YYYY-MM-DDTHH:MM:SS）
	var time_only = time_str
	if time_str.length() == 11:
		# 格式: MM-DD HH:MM，提取时间部分
		time_only = time_str.substr(6, 5) # HH:MM
	
	# 构建完整时间戳
	var full_timestamp = "%sT%s:00" % [date_str, time_only]
	
	# 将时间戳转换为Unix时间戳
	var parts = full_timestamp.split("T")
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	
	var datetime_dict = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"weekday": 0,
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2]),
		"dst": false
	}
	
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime_dict)
	var timezone_offset = _get_timezone_offset()
	unix_time -= timezone_offset # 转换为UTC
	
	# 使用统一记忆保存器
	var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if unified_saver:
		await unified_saver.save_memory(
			event_text,
			unified_saver.MemoryType.OFFLINE,
			unix_time, # 使用计算出的Unix时间戳
			"",
			{}
		)
		print("日记已保存: [%s] %s" % [time_str, event_text])
	else:
		# 降级方案：使用旧逻辑
		push_warning("UnifiedMemorySaver 未找到，使用旧的保存逻辑")
		_save_diary_entry_legacy(time_str, event_text, date_str)

func _save_diary_entry_legacy(time_str: String, event_text: String, date_str: String):
	"""降级方案：使用旧的日记保存逻辑"""
	if not _ensure_diary_directory():
		return
	
	var diary_dir = "user://diary"
	var diary_path = diary_dir + "/" + date_str + ".jsonl"
	
	# 构建日记记录
	var diary_record = {
		"type": "offline",
		"time": time_str,
		"event": event_text
	}
	
	# 追加到日记文件
	var file = FileAccess.open(diary_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(diary_path, FileAccess.WRITE)
	else:
		file.seek_end()
	
	if file == null:
		print("错误: 无法创建日记文件")
		return
	
	file.store_line(JSON.stringify(diary_record))
	file.close()
	
	# 保存到存档和向量数据库
	var save_mgr = get_node("/root/SaveManager")
	var ai_service = get_node("/root/AIService")
	
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": [],
			"accumulated_summary_count": 0,
			"relationship_history": []
		}
	
	var current_unix = Time.get_unix_time_from_system()
	var timezone_offset = _get_timezone_offset()
	var local_dict = Time.get_datetime_dict_from_unix_time(int(current_unix + timezone_offset))
	var current_timestamp = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		local_dict.year, local_dict.month, local_dict.day,
		local_dict.hour, local_dict.minute, local_dict.second
	]
	
	var memory_item = {
		"timestamp": current_timestamp,
		"content": event_text
	}
	save_mgr.save_data.ai_data.memory.append(memory_item)
	
	var max_items = ai_service.config.memory.max_memory_items
	if save_mgr.save_data.ai_data.memory.size() > max_items:
		save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)
	
	save_mgr.save_game(save_mgr.current_slot)
	
	if has_node("/root/MemoryManager"):
		var memory_mgr = get_node("/root/MemoryManager")
		var diary_entry = {
			"time": time_str,
			"event": event_text
		}
		await memory_mgr.add_diary_entry(diary_entry)
	
	print("日记已保存（旧逻辑）: [%s] %s" % [time_str, event_text])
