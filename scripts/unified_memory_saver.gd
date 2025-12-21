extends Node

## 统一记忆保存器
## 封装记忆保存逻辑，一次调用同时保存到三个地方：
## 1. 存档（saves/）
## 2. 日记（diary/）
## 3. 向量数据库（长期记忆）

enum MemoryType {
	CHAT,      # 聊天对话
	OFFLINE,   # 离线事件
	GAMES,     # 游戏事件
	COOK,      # 烹饪事件
	EXPLORE    # 探索事件
}

## 保存记忆到三个位置
## @param content: 记忆内容（总结文本）
## @param memory_type: 记忆类型（CHAT/OFFLINE/GAMES）
## @param custom_timestamp: 自定义时间戳（Unix时间戳，可选）
## @param conversation_text: 详细对话文本（仅CHAT类型需要，可选）
## @param metadata: 元数据（可选），如 {"mood": "happy", "affection": 75}
func save_memory(
	content: String,
	memory_type: MemoryType = MemoryType.CHAT,
	custom_timestamp = null,
	conversation_text: String = "",
	metadata: Dictionary = {}
) -> void:
	if content.strip_edges().is_empty():
		print("警告: 记忆内容为空，跳过保存")
		return
	
	var cleaned_content = content.strip_edges()
	
	# 确定时间戳（统一使用本地时间）
	var timestamp_str: String
	var timestamp_unix: float
	
	if custom_timestamp != null:
		timestamp_unix = float(custom_timestamp)
		timestamp_str = _unix_to_local_datetime_string(timestamp_unix)
	else:
		timestamp_unix = Time.get_unix_time_from_system()
		timestamp_str = _get_local_datetime_string()
	
	print("=== 开始保存记忆 ===")
	print("类型: %s" % _get_type_name(memory_type))
	print("时间戳: %s (Unix: %.0f)" % [timestamp_str, timestamp_unix])
	print("内容: %s..." % cleaned_content.substr(0, 50))
	
	# 1. 保存到存档（saves/）
	_save_to_archive(cleaned_content, timestamp_str)
	
	# 2. 保存到日记（diary/）
	_save_to_diary(cleaned_content, conversation_text, timestamp_str, memory_type, metadata)
	
	# 3. 保存到向量数据库（长期记忆）
	await _save_to_vector_db(cleaned_content, timestamp_str, memory_type, metadata)
	
	print("=== 记忆保存完成 ===\n")

## 1. 保存到存档（saves/）
func _save_to_archive(content: String, timestamp: String) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		push_error("SaveManager 未找到，无法保存到存档")
		return
	
	# 确保 ai_data 字段存在
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": [],
			"accumulated_summary_count": 0,
			"relationship_history": []
		}
	
	# 添加记忆条目
	var memory_item = {
		"timestamp": timestamp,
		"content": content
	}
	save_mgr.save_data.ai_data.memory.append(memory_item)
	
	# 限制记忆条目数量
	var ai_service = get_node_or_null("/root/AIService")
	var max_items = 15 # 默认值
	if ai_service and ai_service.config.has("memory"):
		max_items = ai_service.config.memory.get("max_memory_items", 15)
	
	if save_mgr.save_data.ai_data.memory.size() > max_items:
		save_mgr.save_data.ai_data.memory = save_mgr.save_data.ai_data.memory.slice(-max_items)
	
	# 保存存档
	save_mgr.save_game(save_mgr.current_slot)
	
	print("✓ 已保存到存档")

## 2. 保存到日记（diary/）
func _save_to_diary(
	content: String,
	conversation_text: String,
	timestamp: String,
	memory_type: MemoryType,
	metadata: Dictionary = {}
) -> void:
	var diary_dir = "user://diary"
	
	# 确保日记目录存在
	var dir = DirAccess.open("user://")
	if dir == null:
		push_error("无法访问 user:// 目录")
		return
	
	if not dir.dir_exists("diary"):
		var err = dir.make_dir("diary")
		if err != OK:
			push_error("无法创建 diary 目录，错误码: %d" % err)
			return
	
	# 解析时间戳（格式：YYYY-MM-DDTHH:MM:SS）
	var parts = timestamp.split("T")
	if parts.size() != 2:
		push_error("时间戳格式错误: %s" % timestamp)
		return
	
	var date_str = parts[0]  # YYYY-MM-DD
	var time_str = parts[1]  # HH:MM:SS
	
	# 构建日记文件路径
	var diary_path = diary_dir + "/" + date_str + ".jsonl"
	
	# 构建日记记录（统一使用字符串类型名）
	var type_name = _get_type_name(memory_type)
	var diary_record = {
		"type": type_name,
		"timestamp": time_str
	}
	
	# 根据类型添加不同字段
	if memory_type == MemoryType.CHAT:
		diary_record["summary"] = content
		diary_record["conversation"] = conversation_text
	elif memory_type == MemoryType.EXPLORE:
		# EXPLORE 类型使用 event 字段，并保存 display_history
		diary_record["time"] = time_str.substr(0, 5)
		diary_record["event"] = content
		diary_record.erase("timestamp")  # 移除timestamp字段
		# 保存 metadata 中的额外信息（如 display_history）
		if not metadata.is_empty():
			for key in metadata:
				diary_record[key] = metadata[key]
	else:
		# OFFLINE, GAMES, COOK 类型使用 event 字段
		# 时间格式简化为 HH:MM（前5个字符）
		diary_record["time"] = time_str.substr(0, 5)
		diary_record["event"] = content
		diary_record.erase("timestamp")  # 移除timestamp字段
	
	# 追加到日记文件
	var file = FileAccess.open(diary_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(diary_path, FileAccess.WRITE)
	else:
		file.seek_end()
	
	if file == null:
		var err = FileAccess.get_open_error()
		push_error("无法创建日记文件，错误码: %d" % err)
		return
	
	file.store_line(JSON.stringify(diary_record))
	file.close()
	
	print("✓ 已保存到日记: %s" % diary_path)

## 3. 保存到向量数据库（长期记忆）
func _save_to_vector_db(
	content: String,
	timestamp: String,
	memory_type: MemoryType,
	metadata: Dictionary
) -> void:
	var memory_mgr = get_node_or_null("/root/MemoryManager")
	if not memory_mgr:
		print("警告: MemoryManager 未找到，跳过向量数据库保存")
		return
	
	# 等待记忆系统就绪
	if not memory_mgr.is_initialized:
		await memory_mgr.memory_system_ready
	
	# 根据类型选择不同的保存方式
	if memory_type == MemoryType.CHAT:
		# 聊天类型：使用 conversation 类型
		await memory_mgr.add_conversation_summary(content, metadata, timestamp)
	else:
		# 离线和游戏类型：使用 diary 类型
		# 构建日记条目格式
		var time_str = timestamp.split("T")[1].substr(0, 5) if "T" in timestamp else ""
		var diary_entry = {
			"time": time_str,
			"event": content
		}
		await memory_mgr.add_diary_entry(diary_entry)
	
	print("✓ 已保存到向量数据库")

## 获取类型名称（字符串）
func _get_type_name(memory_type: MemoryType) -> String:
	match memory_type:
		MemoryType.CHAT:
			return "chat"
		MemoryType.OFFLINE:
			return "offline"
		MemoryType.GAMES:
			return "games"
		MemoryType.COOK:
			return "cook"
		MemoryType.EXPLORE:
			return "explore"
		_:
			return "chat"

## 获取本地时间字符串（格式：YYYY-MM-DDTHH:MM:SS）
func _get_local_datetime_string() -> String:
	var unix_time = Time.get_unix_time_from_system()
	return _unix_to_local_datetime_string(unix_time)

## 将Unix时间戳转换为本地时间字符串
func _unix_to_local_datetime_string(unix_time: float) -> String:
	var timezone_offset = _get_timezone_offset()
	var local_dict = Time.get_datetime_dict_from_unix_time(int(unix_time + timezone_offset))
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		local_dict.year, local_dict.month, local_dict.day,
		local_dict.hour, local_dict.minute, local_dict.second
	]

## 获取本地时区相对于UTC的偏移（秒）
func _get_timezone_offset() -> int:
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
