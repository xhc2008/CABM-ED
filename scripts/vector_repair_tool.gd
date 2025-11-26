extends Node
## 向量修复工具 - 重新生成所有损坏的向量

signal repair_progress(current: int, total: int, message: String)
signal repair_completed(success: bool, message: String)

var is_repairing: bool = false

func start_repair():
	"""开始修复向量数据"""
	if is_repairing:
		print("修复正在进行中...")
		return
	
	is_repairing = true
	print("=== 开始修复向量数据 ===")
	
	# 获取MemoryManager
	var memory_mgr = get_node_or_null("/root/MemoryManager")
	if not memory_mgr:
		_finish_repair(false, "MemoryManager未找到")
		return
	
	# 等待初始化
	if not memory_mgr.is_initialized:
		await memory_mgr.memory_system_ready
	
	var memory_system = memory_mgr.memory_system
	if not memory_system:
		_finish_repair(false, "memory_system未找到")
		return
	
	var total = memory_system.memory_items.size()
	if total == 0:
		_finish_repair(false, "没有需要修复的记忆")
		return
	
	print("共有 %d 条记忆需要检查" % total)
	repair_progress.emit(0, total, "开始检查...")
	
	# 检查并修复每条记忆
	var repaired_count = 0
	var failed_count = 0
	
	for i in range(total):
		var item = memory_system.memory_items[i]
		var text_preview = item.text.substr(0, 40)
		
		print("\n[%d/%d] 处理: %s" % [i + 1, total, text_preview])
		repair_progress.emit(i + 1, total, "处理: " + text_preview)
		
		# 检查向量是否需要修复
		if _needs_repair(memory_system.memory_items, i):
			print("  需要修复，重新获取向量...")
			
			# 重新获取向量
			var new_vector = await memory_system.get_embedding(item.text)
			
			if new_vector.is_empty():
				print("  ✗ 获取向量失败")
				failed_count += 1
			else:
				item.vector = new_vector
				repaired_count += 1
				print("  ✓ 修复成功，新向量维度: %d" % new_vector.size())
				
				# 每修复5条就保存一次，防止中途失败
				if repaired_count % 5 == 0:
					memory_system.save_to_file()
					print("  已保存进度")
		else:
			print("  向量正常，跳过")
		
		# 短暂延迟，避免API请求过快
		# await get_tree().create_timer(0.5).timeout
	
	# 最终保存
	memory_system.save_to_file()
	
	# 完成
	var message = "修复完成！\n修复: %d 条\n失败: %d 条\n跳过: %d 条" % [
		repaired_count,
		failed_count,
		total - repaired_count - failed_count
	]
	
	print("\n=== %s ===" % message)
	_finish_repair(true, message)

func _needs_repair(items: Array, index: int) -> bool:
	"""检查向量是否需要修复
	
	判断标准（需同时满足多个条件才判定为损坏）：
	1. 向量为空 -> 肯定损坏
	2. 向量与多个其他记忆的向量完全相同 -> 可能损坏
	   - 需要与至少2个不同的记忆向量完全相同
	   - 检查前50个值（更严格）
	   - 排除文本内容相似的情况
	"""
	var item = items[index]
	
	# 检查1：向量为空 -> 肯定损坏
	if item.vector.is_empty():
		return true
	
	# 检查2：向量维度异常（正常应该是1024维）
	if item.vector.size() < 100:
		return true
	
	# 检查3：向量与多个其他记忆完全相同
	var same_vector_count = 0
	var check_range = 5  # 检查前后各5条记忆
	
	for offset in range(-check_range, check_range + 1):
		if offset == 0:
			continue
		
		var other_idx = index + offset
		if other_idx < 0 or other_idx >= items.size():
			continue
		
		var other_item = items[other_idx]
		if other_item.vector.is_empty():
			continue
		
		# 检查文本是否相似（如果文本相似，向量相同是正常的）
		if _texts_are_similar(item.text, other_item.text):
			continue
		
		# 比较前50个值（更严格的检查）
		if _vectors_are_same(item.vector, other_item.vector, 50):
			same_vector_count += 1
			
			# 如果与2个以上不同的记忆向量完全相同，判定为损坏
			if same_vector_count >= 1:
				return true
	
	return false

func _texts_are_similar(text1: String, text2: String) -> bool:
	"""检查两个文本是否相似（简单的相似度判断）"""
	# 移除时间戳前缀进行比较
	var clean_text1 = _remove_timestamp(text1)
	var clean_text2 = _remove_timestamp(text2)
	
	# 如果文本完全相同
	if clean_text1 == clean_text2:
		return true
	
	# 如果文本长度相差很大，不相似
	var len_diff = abs(clean_text1.length() - clean_text2.length())
	if len_diff > max(clean_text1.length(), clean_text2.length()) * 0.5:
		return false
	
	# 简单的包含关系检查
	if clean_text1.length() > 10 and clean_text2.length() > 10:
		if clean_text1 in clean_text2 or clean_text2 in clean_text1:
			return true
	
	return false

func _remove_timestamp(text: String) -> String:
	"""移除文本开头的时间戳"""
	# 格式: [MM-DD HH:MM] 文本内容
	var regex = RegEx.new()
	regex.compile("^\\[\\d{2}-\\d{2} \\d{2}:\\d{2}\\] ")
	return regex.sub(text, "", true)

func _vectors_are_same(vec1: Array, vec2: Array, check_count: int = 50) -> bool:
	"""检查两个向量的前N个值是否完全相同
	
	使用更严格的阈值（0.00001）来判断相同
	"""
	if vec1.size() != vec2.size():
		return false
	
	var count = min(check_count, vec1.size())
	for i in range(count):
		# 使用更严格的阈值
		if abs(vec1[i] - vec2[i]) > 0.00001:
			return false
	
	return true

func _finish_repair(success: bool, message: String):
	"""完成修复"""
	is_repairing = false
	repair_completed.emit(success, message)
