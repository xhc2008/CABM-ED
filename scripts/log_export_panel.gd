extends Panel

# 日志导出面板 - 用于导出AI日志和Godot日志

@onready var close_button = $MarginContainer/VBoxContainer/TitleContainer/CloseButton
@onready var export_button = $MarginContainer/VBoxContainer/ExportButton
@onready var status_label = $MarginContainer/VBoxContainer/StatusLabel
@onready var info_label = $MarginContainer/VBoxContainer/InfoLabel

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	export_button.pressed.connect(_on_export_pressed)
	
	# 设置说明文本
	info_label.text = "导出日志文件到 Documents/SnowFox_Logs/ 目录\n包含：AI日志、Godot日志、存档信息"
	
	_update_status("")

func _on_close_pressed():
	"""关闭面板"""
	queue_free()

func _on_export_pressed():
	"""导出日志"""
	_update_status("正在导出日志...", Color(0.3, 0.7, 1.0))
	export_button.disabled = true
	
	# 等待一帧以更新UI
	await get_tree().process_frame
	
	var result = _export_logs()
	
	if result.success:
		_update_status("✓ " + result.message, Color(0.3, 1.0, 0.3))
	else:
		_update_status("✗ " + result.message, Color(1.0, 0.3, 0.3))
	
	# 2秒后重新启用按钮
	await get_tree().create_timer(2.0).timeout
	export_button.disabled = false

func _export_logs() -> Dictionary:
	"""导出所有日志文件"""
	# 获取Documents目录
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_path.is_empty():
		return {"success": false, "message": "无法获取Documents目录"}
	
	# 创建导出目录
	var export_dir = documents_path + "/SnowFox_Logs"
	var dir = DirAccess.open(documents_path)
	if dir == null:
		return {"success": false, "message": "无法访问Documents目录"}
	
	if not dir.dir_exists("SnowFox_Logs"):
		var mkdir_result = dir.make_dir("SnowFox_Logs")
		if mkdir_result != OK:
			return {"success": false, "message": "无法创建导出目录"}
	
	# 生成时间戳
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var export_subdir = export_dir + "/" + timestamp
	
	dir = DirAccess.open(export_dir)
	if dir == null:
		return {"success": false, "message": "无法访问导出目录"}
	
	var mkdir_result2 = dir.make_dir(timestamp)
	if mkdir_result2 != OK:
		return {"success": false, "message": "无法创建时间戳子目录"}
	
	var files_exported = 0
	
	# 1. 导出AI日志
	var ai_log_result = _export_ai_logs(export_subdir)
	if ai_log_result.success:
		files_exported += ai_log_result.count
	
	# 2. 导出Godot日志
	var godot_log_result = _export_godot_logs(export_subdir)
	if godot_log_result.success:
		files_exported += godot_log_result.count
	
	# 3. 导出存档信息
	var save_result = _export_save_info(export_subdir)
	if save_result.success:
		files_exported += save_result.count
	
	# 4. 导出日记
	var diary_result = _export_diary(export_subdir)
	if diary_result.success:
		files_exported += diary_result.count
	
	if files_exported > 0:
		return {
			"success": true,
			"message": "已导出 %d 个文件到:\n%s" % [files_exported, export_subdir]
		}
	else:
		return {
			"success": false,
			"message": "没有找到可导出的日志文件"
		}

func _export_ai_logs(export_dir: String) -> Dictionary:
	"""导出AI日志"""
	var ai_log_path = "user://ai_logs/log.txt"
	
	if not FileAccess.file_exists(ai_log_path):
		print("AI日志文件不存在")
		return {"success": false, "count": 0}
	
	var source_file = FileAccess.open(ai_log_path, FileAccess.READ)
	if source_file == null:
		print("无法读取AI日志文件")
		return {"success": false, "count": 0}
	
	var content = source_file.get_as_text()
	source_file.close()
	
	var dest_path = export_dir + "/ai_log.txt"
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest_file == null:
		print("无法写入AI日志文件")
		return {"success": false, "count": 0}
	
	dest_file.store_string(content)
	dest_file.close()
	
	print("AI日志已导出: ", dest_path)
	return {"success": true, "count": 1}

func _export_godot_logs(export_dir: String) -> Dictionary:
	"""导出Godot日志（stdout）"""
	# Godot的日志通常在user://目录下的godot.log
	var log_paths = [
		"user://logs/godot.log",
		OS.get_user_data_dir() + "/logs/godot.log"
	]
	
	var count = 0
	
	for log_path in log_paths:
		if FileAccess.file_exists(log_path):
			var source_file = FileAccess.open(log_path, FileAccess.READ)
			if source_file == null:
				continue
			
			var content = source_file.get_as_text()
			source_file.close()
			
			var filename = log_path.get_file()
			var dest_path = export_dir + "/" + filename
			var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
			if dest_file == null:
				continue
			
			dest_file.store_string(content)
			dest_file.close()
			
			print("Godot日志已导出: ", dest_path)
			count += 1
	
	# 如果没有找到日志文件，创建一个包含当前输出的文件
	if count == 0:
		var dest_path = export_dir + "/godot_output.txt"
		var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
		if dest_file:
			dest_file.store_string("Godot日志文件未找到\n")
			dest_file.store_string("用户数据目录: " + OS.get_user_data_dir() + "\n")
			dest_file.store_string("导出时间: " + Time.get_datetime_string_from_system() + "\n")
			dest_file.close()
			count = 1
	
	return {"success": count > 0, "count": count}

func _export_save_info(export_dir: String) -> Dictionary:
	"""导出存档信息"""
	if not has_node("/root/SaveManager"):
		return {"success": false, "count": 0}
	
	var save_mgr = get_node("/root/SaveManager")
	var save_data = save_mgr.save_data
	
	var dest_path = export_dir + "/save_info.json"
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest_file == null:
		return {"success": false, "count": 0}
	
	# 导出存档数据（格式化）
	dest_file.store_string(JSON.stringify(save_data, "\t"))
	dest_file.close()
	
	print("存档信息已导出: ", dest_path)
	return {"success": true, "count": 1}

func _export_diary(export_dir: String) -> Dictionary:
	"""导出日记文件"""
	var diary_dir = "user://diary"
	
	if not DirAccess.dir_exists_absolute(diary_dir):
		print("日记目录不存在")
		return {"success": false, "count": 0}
	
	var dir = DirAccess.open(diary_dir)
	if dir == null:
		return {"success": false, "count": 0}
	
	# 创建日记子目录
	var diary_export_dir = export_dir + "/diary"
	var export_dir_access = DirAccess.open(export_dir)
	if export_dir_access == null:
		return {"success": false, "count": 0}
	
	var mkdir_err = export_dir_access.make_dir("diary")
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		return {"success": false, "count": 0}
	
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".jsonl"):
			var source_path = diary_dir + "/" + file_name
			var source_file = FileAccess.open(source_path, FileAccess.READ)
			if source_file:
				var content = source_file.get_as_text()
				source_file.close()
				
				var dest_path = diary_export_dir + "/" + file_name
				var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
				if dest_file:
					dest_file.store_string(content)
					dest_file.close()
					count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if count > 0:
		print("已导出 %d 个日记文件" % count)
	
	return {"success": count > 0, "count": count}

func _update_status(message: String, color: Color = Color.WHITE):
	"""更新状态标签"""
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
