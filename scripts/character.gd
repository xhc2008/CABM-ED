extends TextureButton

signal character_clicked

var current_scene: String = ""
var original_preset: Dictionary
var is_chatting: bool = false
var background_node: TextureRect
var base_background_size: Vector2  # 背景的基准大小（第一次加载时的大小）

# 聊天状态的配置
const CHAT_POSITION_RATIO = Vector2(0.5, 0.4)
const CHAT_SCALE = 0.8

func _ready():
	pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func set_background_reference(bg: TextureRect):
	background_node = bg

func _on_viewport_size_changed():
	# 窗口大小改变时，更新角色位置和缩放
	if not is_chatting and visible and original_preset.size() > 0:
		_update_position_and_scale_from_preset()

func _get_background_scale_factor() -> float:
	if not background_node or base_background_size == Vector2.ZERO:
		return 1.0
	
	# 计算背景的缩放比例（使用较小的维度以保持比例）
	var current_size = background_node.size
	var scale_x = current_size.x / base_background_size.x
	var scale_y = current_size.y / base_background_size.y
	
	# 使用较小的缩放比例，确保角色不会超出背景
	return min(scale_x, scale_y)

func _update_position_and_scale_from_preset():
	if not background_node:
		print("错误: background_node 为空")
		return
	
	if not texture_normal:
		return
	
	# 获取背景的实际大小
	var bg_size = background_node.size
	
	# 计算背景的缩放比例
	var bg_scale_factor = _get_background_scale_factor()
	
	# 应用缩放到角色（基础缩放 × 背景缩放比例）
	var final_scale = original_preset.scale * bg_scale_factor
	scale = Vector2(final_scale, final_scale)
	
	# 计算角色中心点应该在的位置（相对于背景的本地坐标）
	var char_center_pos = Vector2(
		original_preset.position.x * bg_size.x,
		original_preset.position.y * bg_size.y
	)
	
	# 计算角色左上角的位置（因为position是左上角）
	# 需要减去缩放后的图片尺寸的一半
	var texture_size = texture_normal.get_size()
	var scaled_half_size = texture_size * final_scale / 2.0
	
	position = char_center_pos - scaled_half_size
	
	print("背景大小: ", bg_size, " 缩放因子: ", bg_scale_factor, " 最终缩放: ", final_scale, " position: ", position)

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
		
		# 记录背景的基准大小（如果还没记录）
		if background_node and base_background_size == Vector2.ZERO:
			base_background_size = background_node.size
			print("记录基准背景大小: ", base_background_size)
		
		# 更新位置和缩放
		_update_position_and_scale_from_preset()
		
		visible = true
		print("角色已加载: ", image_path, " 预设位置: ", original_preset.position, " 实际位置: ", position)
	else:
		print("角色图片不存在: ", image_path)
		visible = false

func start_chat():
	if is_chatting:
		return
	
	is_chatting = true
	
	# 加载聊天图片
	var chat_image_path = "res://assets/images/character/chat/normal.png"
	if ResourceLoader.exists(chat_image_path):
		texture_normal = load(chat_image_path)
	
	# 计算背景中央位置（本地坐标）
	if not background_node:
		print("错误: start_chat 时 background_node 为空")
		return
	
	var bg_size = background_node.size
	
	# 计算背景缩放因子
	var bg_scale_factor = _get_background_scale_factor()
	var final_chat_scale = CHAT_SCALE * bg_scale_factor
	
	# 计算中心点位置
	var center_pos = Vector2(
		CHAT_POSITION_RATIO.x * bg_size.x,
		CHAT_POSITION_RATIO.y * bg_size.y
	)
	
	# 计算左上角位置（减去缩放后图片尺寸的一半）
	var texture_size = texture_normal.get_size()
	var scaled_half_size = texture_size * final_chat_scale / 2.0
	var target_pos = center_pos - scaled_half_size
	
	print("聊天目标中心: ", center_pos, " 缩放: ", final_chat_scale, " 最终position: ", target_pos)
	
	# 创建移动动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(final_chat_scale, final_chat_scale), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func end_chat():
	if not is_chatting:
		return
	
	is_chatting = false
	
	# 重新加载场景中的随机位置
	load_character_for_scene(current_scene)

func _on_pressed():
	if not is_chatting:
		character_clicked.emit()
