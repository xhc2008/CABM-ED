extends TextureButton

signal character_clicked(char_position: Vector2, char_size: Vector2)

var current_scene: String = ""
var original_preset: Dictionary
var is_chatting: bool = false
var background_node: TextureRect
var is_first_load: bool = true # 标记是否是首次加载

# 聊天状态的配置
const CHAT_POSITION_RATIO = Vector2(0.5, 0.55) # 向下调整到0.5
const CHAT_SCALE = 0.7

func _ready():
	pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func set_background_reference(bg: TextureRect):
	background_node = bg

func _on_viewport_size_changed():
	# 窗口大小改变时，更新角色位置和缩放
	if not is_chatting and visible and original_preset.size() > 0:
		_update_position_and_scale_from_preset()

# 获取实际渲染的背景图片区域（考虑黑边）
func _get_actual_background_rect() -> Dictionary:
	if not background_node or not background_node.texture:
		return {"size": Vector2.ZERO, "offset": Vector2.ZERO, "scale": 1.0}
	
	var container_size = background_node.size
	var texture_size = background_node.texture.get_size()
	
	# 计算保持比例的缩放
	var scale_x = container_size.x / texture_size.x
	var scale_y = container_size.y / texture_size.y
	var bg_scale = min(scale_x, scale_y) # 保持比例，使用较小的缩放
	
	# 计算实际渲染的图片大小
	var actual_size = texture_size * bg_scale
	
	# 计算偏移（居中）
	var offset = (container_size - actual_size) / 2.0
	
	return {
		"size": actual_size,
		"offset": offset,
		"scale": bg_scale
	}

func _update_position_and_scale_from_preset():
	if not background_node:
		print("错误: background_node 为空")
		return
	
	if not texture_normal:
		return
	
	# 获取实际渲染的背景区域
	var bg_rect = _get_actual_background_rect()
	var actual_bg_size = bg_rect.size
	var bg_offset = bg_rect.offset
	var bg_scale = bg_rect.scale
	
	# 直接使用预设的缩放值，不再乘以背景缩放比例
	var final_scale = original_preset.scale
	scale = Vector2(final_scale, final_scale)
	
	# 计算角色中心点应该在的位置（在实际背景图片上）
	var char_center_in_bg = Vector2(
		original_preset.position.x * actual_bg_size.x,
		original_preset.position.y * actual_bg_size.y
	)
	
	# 加上偏移，得到相对于背景节点的位置
	var char_center_pos = char_center_in_bg + bg_offset
	
	# 计算角色左上角的位置（因为position是左上角）
	var texture_size = texture_normal.get_size()
	var scaled_half_size = texture_size * final_scale / 2.0
	
	position = char_center_pos - scaled_half_size
	
	print("实际背景大小: ", actual_bg_size, " 偏移: ", bg_offset, " 缩放: ", bg_scale, " 角色position: ", position)

func load_character_for_scene(scene_id: String):
	# 检查角色是否应该在这个场景显示
	var character_scene = _get_character_scene()
	
	# 如果角色场景为空（首次启动），初始化为当前场景
	if character_scene == "":
		print("首次启动，初始化角色场景为: ", scene_id)
		if has_node("/root/SaveManager"):
			var save_mgr = get_node("/root/SaveManager")
			# 设置标记，表示这是首次初始化
			save_mgr.set_meta("is_first_scene_init", true)
			save_mgr.set_character_scene(scene_id)
		character_scene = scene_id
	
	if character_scene != scene_id:
		# 角色不在这个场景，隐藏
		visible = false
		print("角色不在场景 %s，当前在 %s" % [scene_id, character_scene])
		return
	
	current_scene = scene_id
	
	# 加载预设配置
	var config_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(config_path):
		print("角色配置文件不存在")
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("解析角色配置失败")
		return
	
	var config = json.data
	if not config.has(scene_id):
		print("场景 %s 没有角色配置" % scene_id)
		visible = false
		return
	
	var presets = config[scene_id]
	if presets.size() == 0:
		visible = false
		return
	
	# 只在首次加载时尝试从存档恢复，之后都随机选择
	if is_first_load:
		var loaded_preset = _try_load_preset_from_save(scene_id, presets)
		if loaded_preset.size() > 0:
			original_preset = loaded_preset
			print("从存档加载角色预设")
			is_first_load = false # 标记已完成首次加载
		else:
			# 随机选择一个预设
			original_preset = presets[randi() % presets.size()]
			print("随机选择角色预设（存档无效）")
			is_first_load = false
	else:
		# 非首次加载，随机选择
		original_preset = presets[randi() % presets.size()]
		print("随机选择角色预设")
	
	# 加载角色图片
	var image_path = "res://assets/images/character/%s/%s" % [scene_id, original_preset.image]
	if ResourceLoader.exists(image_path):
		texture_normal = load(image_path)
		
		# 设置按钮大小为纹理大小，确保点击区域匹配图片
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()
		
		# 先设置为完全透明，避免在(0,0)位置闪现
		modulate.a = 0.0
		visible = true
		
		# 等待背景和场景完全准备好
		await get_tree().process_frame
		await get_tree().process_frame
		
		# 更新位置和缩放
		_update_position_and_scale_from_preset()
		
		# 保存角色场景和预设到存档
		_save_character_state()
		
		# 渐入动画
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		print("角色已加载: ", image_path, " 预设位置: ", original_preset.position, " 实际位置: ", position)
	else:
		print("角色图片不存在: ", image_path)
		visible = false

func _try_load_preset_from_save(scene_id: String, available_presets: Array) -> Dictionary:
	"""尝试从存档加载角色预设"""
	if not has_node("/root/SaveManager"):
		return {}
	
	var save_mgr = get_node("/root/SaveManager")
	var saved_scene = save_mgr.get_character_scene()
	var saved_preset = save_mgr.get_character_preset()
	
	# 如果存档中的场景与当前场景匹配，且预设有效
	if saved_scene == scene_id and saved_preset.size() > 0:
		# 验证预设是否在可用预设列表中
		for preset in available_presets:
			if preset.image == saved_preset.image:
				return saved_preset
	
	return {}

func _save_character_state():
	"""保存角色当前状态到存档（只保存预设，场景在其他地方保存）"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	# 注意：不在这里保存场景，避免循环触发
	# 场景应该在需要改变时立即保存（end_chat, _reload_with_probability等）
	save_mgr.set_character_preset(original_preset)

func start_chat():
	if is_chatting:
		return
	
	is_chatting = true
	
	# 消失动画
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	
	visible = false
	await get_tree().create_timer(0.7).timeout
	
	# 加载聊天图片（根据当前心情）
	_load_chat_image_for_mood()
	
	# 连接AI服务的字段提取信号以更新心情图片
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		if not ai_service.chat_fields_extracted.is_connected(_on_mood_changed):
			ai_service.chat_fields_extracted.connect(_on_mood_changed)
	
	# 计算背景中央位置（本地坐标）
	if not background_node:
		print("错误: start_chat 时 background_node 为空")
		return
	
	# 等待背景完全准备好
	await get_tree().process_frame
	
	# 获取实际渲染的背景区域
	var bg_rect = _get_actual_background_rect()
	var actual_bg_size = bg_rect.size
	var bg_offset = bg_rect.offset
	var bg_scale = bg_rect.scale
	
	# 调试信息
	print("聊天开始 - 背景信息:")
	if background_node.texture:
		print("  背景纹理大小: ", background_node.texture.get_size())
	else:
		print("  背景纹理大小: 无纹理")
	print("  背景容器大小: ", background_node.size)
	print("  实际渲染大小: ", actual_bg_size)
	print("  偏移: ", bg_offset)
	print("  缩放: ", bg_scale)
	
	# 检查背景区域是否有效
	if actual_bg_size.x <= 0 or actual_bg_size.y <= 0:
		print("警告: 背景区域无效，使用默认值")
		actual_bg_size = background_node.size
		bg_offset = Vector2.ZERO
		bg_scale = 1.0
	
	# 直接使用聊天缩放值，不再乘以背景缩放比例
	var final_chat_scale = CHAT_SCALE
	
	# 计算中心点位置（在实际背景图片上）
	var center_in_bg = Vector2(
		CHAT_POSITION_RATIO.x * actual_bg_size.x,
		CHAT_POSITION_RATIO.y * actual_bg_size.y
	)
	
	# 加上偏移
	var center_pos = center_in_bg + bg_offset
	
	# 计算左上角位置（减去缩放后图片尺寸的一半）
	var texture_size = texture_normal.get_size()
	var scaled_half_size = texture_size * final_chat_scale / 2.0
	var target_pos = center_pos - scaled_half_size
	
	print("聊天目标中心: ", center_pos, " 缩放: ", final_chat_scale, " 最终position: ", target_pos)
	
	# 设置位置并显示
	position = target_pos
	scale = Vector2(final_chat_scale, final_chat_scale)
	modulate.a = 0.0
	visible = true
	
	# 淡入动画
	var appear_tween = create_tween()
	appear_tween.tween_property(self, "modulate:a", 1.0, 0.3)

func end_chat():
	if not is_chatting:
		return
	
	is_chatting = false
	
	# 断开AI服务信号
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		if ai_service.chat_fields_extracted.is_connected(_on_mood_changed):
			ai_service.chat_fields_extracted.disconnect(_on_mood_changed)
	
	# 淡出动画
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	
	visible = false
	await get_tree().create_timer(0.3).timeout
	
	# 检查是否有AI决定的场景变化
	var goto_scene = _check_goto_scene()
	
	if goto_scene != "":
		# AI决定了场景变化，移动到新场景（同时更新scene和preset）
		print("AI决定移动到场景: ", goto_scene)
		_move_to_scene(goto_scene)
		# SaveManager会触发character_scene_changed信号
		# main.gd会监听这个信号并调用load_character_for_scene
		# 同时main.gd会显示字幕提示
	else:
		# 没有AI决定的场景变化，使用概率决定位置（有字幕）
		apply_position_probability(true) # 标记为聊天结束调用

func _check_goto_scene() -> String:
	"""检查AI是否决定了场景变化"""
	if not has_node("/root/AIService"):
		return ""
	
	var ai_service = get_node("/root/AIService")
	var goto_index = ai_service.get_goto_field()
	
	if goto_index < 0:
		return ""
	
	# 清除goto字段
	ai_service.clear_goto_field()
	
	# 获取场景ID
	var prompt_builder = get_node("/root/PromptBuilder")
	var target_scene = prompt_builder.get_scene_id_by_index(goto_index)
	
	if target_scene == "":
		print("无效的goto索引: ", goto_index)
		return ""
	
	# 验证场景是否合法
	if not _is_valid_scene(target_scene):
		print("AI选择的场景 '%s' 不合法，忽略" % target_scene)
		return ""
	
	# 检查是否是角色当前所在的场景（从SaveManager获取）
	var character_scene = _get_character_scene()
	if target_scene == character_scene:
		print("goto场景与角色当前场景相同，忽略: ", target_scene)
		return ""
	
	return target_scene

func _reload_with_probability():
	"""聊天结束后根据概率决定角色位置（复用统一的概率系统）"""
	apply_position_probability(true) # 标记为聊天结束调用

func _reload_same_preset():
	"""重新加载相同的预设位置"""
	if original_preset.size() == 0:
		load_character_for_scene(current_scene)
		return
	
	# 加载角色图片
	var image_path = "res://assets/images/character/%s/%s" % [current_scene, original_preset.image]
	if ResourceLoader.exists(image_path):
		texture_normal = load(image_path)
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()
		
		modulate.a = 0.0
		visible = true
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		_update_position_and_scale_from_preset()
		_save_character_state()
		
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		print("角色已回到原位置")
	else:
		load_character_for_scene(current_scene)

func _get_random_other_scene() -> String:
	"""根据权重获取一个随机的其他场景"""
	var presets_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(presets_path):
		return ""
	
	var file = FileAccess.open(presets_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return ""
	
	var presets_config = json.data
	
	# 加载场景权重配置
	var scenes_path = "res://config/scenes.json"
	if not FileAccess.file_exists(scenes_path):
		# 如果没有场景配置，使用旧的均匀随机方式
		var available_scenes = []
		for scene_id in presets_config:
			if scene_id != current_scene and presets_config[scene_id].size() > 0:
				available_scenes.append(scene_id)
		if available_scenes.is_empty():
			return ""
		return available_scenes[randi() % available_scenes.size()]
	
	var scenes_file = FileAccess.open(scenes_path, FileAccess.READ)
	var scenes_json_string = scenes_file.get_as_text()
	scenes_file.close()
	
	var scenes_json = JSON.new()
	if scenes_json.parse(scenes_json_string) != OK:
		return ""
	
	var scenes_config = scenes_json.data
	if not scenes_config.has("scenes"):
		return ""
	
	# 收集可用场景及其权重
	var weighted_scenes = []
	var total_weight = 0
	
	for scene_id in presets_config:
		if scene_id != current_scene and presets_config[scene_id].size() > 0:
			var weight = 1 # 默认权重
			if scenes_config.scenes.has(scene_id) and scenes_config.scenes[scene_id].has("weight"):
				weight = scenes_config.scenes[scene_id].weight
			
			weighted_scenes.append({"id": scene_id, "weight": weight})
			total_weight += weight
	
	if weighted_scenes.is_empty() or total_weight <= 0:
		return ""
	
	# 根据权重随机选择
	var rand_value = randf() * total_weight
	var accumulated_weight = 0
	
	for scene_data in weighted_scenes:
		accumulated_weight += scene_data.weight
		if rand_value <= accumulated_weight:
			return scene_data.id
	
	# 兜底返回最后一个
	return weighted_scenes[-1].id

func _get_character_scene() -> String:
	"""获取角色当前所在场景"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		return save_mgr.get_character_scene()
	return current_scene

func apply_position_probability(from_chat_end: bool = false, show_notification: bool = true) -> bool:
	"""应用概率系统决定角色位置
	
	参数：
	- from_chat_end: 是否从聊天结束调用（影响动画行为）
	
	返回值：
	- true: 角色仍在当前场景（保持原位或移动到当前场景随机位置）
	- false: 角色移动到其他场景
	"""
	var rand_value = randf()
	
	if rand_value < 0.7:
		# 70%概率：保持原位置
		print("角色保持原位置")
		if from_chat_end:
			# 聊天结束：角色已隐藏，需要重新加载并淡入
			_reload_same_preset()
		# 否则：角色已可见，不做任何操作
		return true
	elif rand_value < 0.95:
		# 25%概率：当前场景的随机位置
		print("角色移动到当前场景的随机位置")
		var character_scene = _get_character_scene()
		if character_scene == current_scene:
			if not from_chat_end:
				# 进入场景/空闲超时：角色已可见，需要先淡出
				var fade_out = create_tween()
				fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
				await fade_out.finished
			# 聊天结束：角色已隐藏，直接重新加载
			# 重新加载到随机位置（会自动淡入）
			load_character_for_scene(current_scene)
		return true
	else:
		# 5%概率：移动到其他场景
		print("角色移动到其他场景")
		var new_scene = _get_random_other_scene()
		if new_scene != "":
			if not from_chat_end:
				# 进入场景/空闲超时：角色已可见，需要先淡出
				var fade_out = create_tween()
				fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
				await fade_out.finished
			# 聊天结束：角色已隐藏，不需要淡出
			
			# 更新角色场景和预设
			_move_to_scene(new_scene, show_notification)
			
			# 角色移动到其他场景，会被隐藏
			# SaveManager会触发信号，main.gd会调用load_character_for_scene
			return false
		else:
			# 如果没有其他场景，保持原位置
			print("没有其他场景可移动，保持原位置")
			if from_chat_end:
				# 聊天结束：角色已隐藏，需要重新加载并淡入
				_reload_same_preset()
			# 否则：角色已可见，不做任何操作
			return true

func apply_position_probability_silent() -> bool:
	"""静默应用概率系统（角色不在当前场景或在当前场景但需要静默处理）
	
	返回值：
	- true: 角色仍在原场景
	- false: 角色移动到其他场景
	"""
	var rand_value = randf()
	var character_scene = _get_character_scene()
	var in_current_scene = (character_scene == current_scene)
	
	if rand_value < 0.7:
		# 70%概率：保持原位置
		print("角色保持在场景: ", character_scene)
		return true
	elif rand_value < 0.95:
		# 25%概率：当前场景的随机位置
		print("角色在场景 %s 移动到随机位置" % character_scene)
		if in_current_scene and visible:
			# 角色在当前场景且可见：先淡出再重新加载
			var fade_out = create_tween()
			fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
			await fade_out.finished
			load_character_for_scene(character_scene)
		else:
			# 角色不在当前场景：只更新预设
			_update_preset_for_scene(character_scene)
		return true
	else:
		# 5%概率：移动到其他场景
		var new_scene = _get_random_other_scene()
		if new_scene != "":
			print("角色从 %s 移动到 %s" % [character_scene, new_scene])
			if in_current_scene and visible:
				# 角色在当前场景且可见：先淡出
				var fade_out = create_tween()
				fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
				await fade_out.finished
			_move_to_scene(new_scene, false) # 空闲超时不显示通知
			return false
		else:
			print("没有其他场景可移动，保持在场景: ", character_scene)
			return true

func _move_to_scene(new_scene: String, show_notification: bool = true):
	"""移动角色到新场景（更新场景和预设）
	
	参数：
	- new_scene: 目标场景ID
	- show_notification: 是否显示字幕通知
	"""
	if not has_node("/root/SaveManager"):
		return
	
	# 验证目标场景是否合法
	if not _is_valid_scene(new_scene):
		print("错误: 尝试移动到不合法的场景 '%s'" % new_scene)
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# 设置通知标记（main.gd会读取这个标记）
	save_mgr.set_meta("show_move_notification", show_notification)
	
	# 更新场景
	save_mgr.set_character_scene(new_scene)
	
	# 为新场景生成随机预设
	_update_preset_for_scene(new_scene)

func _is_valid_scene(scene_id: String) -> bool:
	"""验证场景ID是否合法（存在于character_presets.json中且有预设）"""
	var config_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(config_path):
		return false
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false
	
	var config = json.data
	return config.has(scene_id) and config[scene_id].size() > 0

func _update_preset_for_scene(scene_id: String):
	"""为指定场景更新随机预设"""
	var config_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(config_path):
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	
	var config = json.data
	if not config.has(scene_id) or config[scene_id].size() == 0:
		return
	
	var presets = config[scene_id]
	var new_preset = presets[randi() % presets.size()]
	
	# 保存新预设
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.set_character_preset(new_preset)
		print("已更新场景 %s 的预设" % scene_id)

func _on_pressed():
	if not is_chatting:
		# 发送角色的全局位置和大小
		var global_pos = global_position
		var char_size = size * scale
		character_clicked.emit(global_pos, char_size)

func _load_chat_image_for_mood():
	"""根据当前心情加载聊天图片"""
	if not has_node("/root/SaveManager"):
		_load_default_chat_image()
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var mood_name_en = save_mgr.get_mood()
	
	# 从mood_config.json获取图片文件名
	var image_filename = _get_mood_image_filename(mood_name_en)
	if image_filename.is_empty():
		_load_default_chat_image()
		return
	
	var chat_image_path = "res://assets/images/character/chat/" + image_filename
	if ResourceLoader.exists(chat_image_path):
		texture_normal = load(chat_image_path)
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()
		print("加载心情图片: ", chat_image_path)
	else:
		print("心情图片不存在: ", chat_image_path, " 使用默认图片")
		_load_default_chat_image()

func _load_default_chat_image():
	"""加载默认聊天图片"""
	var chat_image_path = "res://assets/images/character/chat/normal.png"
	if ResourceLoader.exists(chat_image_path):
		texture_normal = load(chat_image_path)
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()

func _get_mood_image_filename(mood_name_en: String) -> String:
	"""根据心情英文名获取图片文件名"""
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
		if mood.name_en == mood_name_en:
			return mood.image
	
	return ""

func _on_mood_changed(fields: Dictionary):
	"""心情变化时切换图片"""
	if not is_chatting:
		return
	
	if not fields.has("mood"):
		return
	
	# 获取新心情的英文名（确保是整数类型）
	var mood_id = int(fields.mood)
	var mood_name_en = _get_mood_name_en_by_id(mood_id)
	if mood_name_en.is_empty():
		return
	
	# 获取图片文件名
	var image_filename = _get_mood_image_filename(mood_name_en)
	if image_filename.is_empty():
		return
	
	# 加载新图片
	var chat_image_path = "res://assets/images/character/chat/" + image_filename
	if ResourceLoader.exists(chat_image_path):
		texture_normal = load(chat_image_path)
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()
		print("切换心情图片: ", chat_image_path)
	else:
		print("心情图片不存在: ", chat_image_path)

func _get_mood_name_en_by_id(mood_id: int) -> String:
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
