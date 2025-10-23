extends Node

# 日记数据迁移工具
# 用于将旧的日记数据迁移到新格式

func migrate_diary_data():
	"""迁移日记数据"""
	print("开始迁移日记数据...")
	
	var migrated_count = 0
	
	# 迁移角色日记（从 user://character_diary/ 到 user://diary/）
	migrated_count += _migrate_character_diary()
	
	# 为玩家日记添加type字段（user://diary/）
	migrated_count += _add_type_to_player_diary()
	
	# 删除旧的角色日记目录
	_delete_old_character_diary()
	
	print("日记数据迁移完成，共迁移 %d 条记录" % migrated_count)
	return migrated_count

func _migrate_character_diary() -> int:
	"""迁移角色日记"""
	var count = 0
	var old_dir = "user://character_diary"
	var new_dir = "user://diary"
	
	# 检查旧目录是否存在
	var dir = DirAccess.open(old_dir)
	if dir == null:
		print("未找到旧的角色日记目录")
		return 0
	
	# 确保新目录存在
	_ensure_directory(new_dir)
	
	# 遍历旧目录中的所有文件
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".jsonl"):
			var old_path = old_dir + "/" + file_name
			var new_path = new_dir + "/" + file_name
			
			# 读取旧文件
			var old_file = FileAccess.open(old_path, FileAccess.READ)
			if old_file == null:
				print("无法打开文件: ", old_path)
				file_name = dir.get_next()
				continue
			
			# 打开新文件（追加模式）
			var new_file = FileAccess.open(new_path, FileAccess.READ_WRITE)
			if new_file == null:
				new_file = FileAccess.open(new_path, FileAccess.WRITE)
			else:
				new_file.seek_end()
			
			if new_file == null:
				print("无法创建文件: ", new_path)
				old_file.close()
				file_name = dir.get_next()
				continue
			
			# 逐行读取并添加type字段
			while not old_file.eof_reached():
				var line = old_file.get_line().strip_edges()
				if line.is_empty():
					continue
				
				var json = JSON.new()
				if json.parse(line) == OK:
					var record = json.data
					# 添加type字段
					if not record.has("type"):
						record["type"] = "offline"
						new_file.store_line(JSON.stringify(record))
						count += 1
			
			old_file.close()
			new_file.close()
			
			print("已迁移文件: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return count

func _add_type_to_player_diary() -> int:
	"""为玩家日记添加type字段"""
	var count = 0
	var diary_dir = "user://diary"
	
	var dir = DirAccess.open(diary_dir)
	if dir == null:
		print("未找到日记目录")
		return 0
	
	# 遍历所有日记文件
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".jsonl"):
			var file_path = diary_dir + "/" + file_name
			
			# 读取所有记录
			var records = []
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file == null:
				file_name = dir.get_next()
				continue
			
			var needs_migration = false
			while not file.eof_reached():
				var line = file.get_line().strip_edges()
				if line.is_empty():
					continue
				
				var json = JSON.new()
				if json.parse(line) == OK:
					var record = json.data
					# 检查是否需要添加type字段
					if not record.has("type"):
						# 根据字段判断类型
						if record.has("summary") and record.has("conversation"):
							record["type"] = "chat"
						else:
							record["type"] = "offline"
						needs_migration = true
						count += 1
					records.append(record)
			
			file.close()
			
			# 如果需要迁移，重写文件
			if needs_migration:
				file = FileAccess.open(file_path, FileAccess.WRITE)
				if file == null:
					print("无法写入文件: ", file_path)
					file_name = dir.get_next()
					continue
				
				for record in records:
					file.store_line(JSON.stringify(record))
				
				file.close()
				print("已更新文件: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return count

func _ensure_directory(path: String):
	"""确保目录存在"""
	var dir = DirAccess.open("user://")
	if dir == null:
		return
	
	var dir_name = path.replace("user://", "")
	if not dir.dir_exists(dir_name):
		dir.make_dir(dir_name)

func _delete_old_character_diary():
	"""删除旧的角色日记目录"""
	var old_dir = "user://character_diary"
	var dir = DirAccess.open(old_dir)
	if dir == null:
		print("旧的角色日记目录不存在，无需删除")
		return
	
	print("开始删除旧的角色日记目录...")
	
	# 删除目录中的所有文件
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var file_path = old_dir + "/" + file_name
			var file_err = DirAccess.remove_absolute(file_path)
			if file_err == OK:
				print("已删除文件: ", file_name)
			else:
				print("删除文件失败: ", file_name, " 错误码: ", file_err)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# 删除目录本身
	var dir_err = DirAccess.remove_absolute(old_dir)
	if dir_err == OK:
		print("已删除旧的角色日记目录")
	else:
		print("删除目录失败，错误码: ", dir_err)

func check_needs_migration() -> bool:
	"""检查是否需要迁移"""
	var old_dir = "user://character_diary"
	var dir = DirAccess.open(old_dir)
	return dir != null
