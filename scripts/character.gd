extends TextureButton

signal character_clicked(char_position: Vector2, char_size: Vector2)

var current_scene: String = ""
var original_preset: Dictionary
var is_chatting: bool = false
var background_node: TextureRect

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
	
	# 应用缩放到角色（基础缩放 × 背景缩放比例）
	var final_scale = original_preset.scale * bg_scale
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
	
	# 随机选择一个预设
	original_preset = presets[randi() % presets.size()]
	
	# 加载角色图片
	var image_path = "res://assets/images/character/%s/%s" % [scene_id, original_preset.image]
	if ResourceLoader.exists(image_path):
		texture_normal = load(image_path)
		
		# 设置按钮大小为纹理大小，确保点击区域匹配图片
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()
		
		# 更新位置和缩放
		_update_position_and_scale_from_preset()
		
		# 渐入动画
		modulate.a = 0.0
		visible = true
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		print("角色已加载: ", image_path, " 预设位置: ", original_preset.position, " 实际位置: ", position)
	else:
		print("角色图片不存在: ", image_path)
		visible = false

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
	
	# 加载聊天图片
	var chat_image_path = "res://assets/images/character/chat/normal.png"
	if ResourceLoader.exists(chat_image_path):
		texture_normal = load(chat_image_path)
		# 更新按钮大小
		custom_minimum_size = texture_normal.get_size()
		size = texture_normal.get_size()
	
	# 计算背景中央位置（本地坐标）
	if not background_node:
		print("错误: start_chat 时 background_node 为空")
		return
	
	# 获取实际渲染的背景区域
	var bg_rect = _get_actual_background_rect()
	var actual_bg_size = bg_rect.size
	var bg_offset = bg_rect.offset
	var bg_scale = bg_rect.scale
	
	# 计算背景缩放因子
	var final_chat_scale = CHAT_SCALE * bg_scale
	
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
	
	# 淡出动画
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	
	visible = false
	await get_tree().create_timer(0.3).timeout
	
	# 重新加载场景中的随机位置
	modulate.a = 1.0
	load_character_for_scene(current_scene)

func _on_pressed():
	if not is_chatting:
		# 发送角色的全局位置和大小
		var global_pos = global_position
		var char_size = size * scale
		character_clicked.emit(global_pos, char_size)
