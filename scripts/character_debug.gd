extends Control

# 角色位置调试工具
# 按 F1 开启/关闭调试模式
# 在调试模式下，可以拖动角色到想要的位置
# 控制台会输出对应的配置坐标

var character: TextureButton
var background: TextureRect
var debug_label: Label

var debug_mode: bool = false
var dragging: bool = false
var drag_offset: Vector2

func _ready():
	# 获取节点引用（通过父节点）
	var parent = get_parent()
	if parent:
		background = parent.get_node("Background")
		if background:
			character = background.get_node("Character")
	
	# 创建调试标签
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.visible = false
	add_child(debug_label)
	
	# 连接角色的输入事件
	if character:
		character.gui_input.connect(_on_character_gui_input)
	else:
		print("警告: 调试工具无法找到角色节点")

func _input(event):
	# F1 切换调试模式
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		debug_mode = !debug_mode
		debug_label.visible = debug_mode
		
		if debug_mode:
			print("\n=== 角色位置调试模式已开启 ===")
			print("拖动角色到想要的位置")
			print("松开鼠标后会在控制台输出配置坐标")
			print("按 F1 关闭调试模式\n")
		else:
			print("\n=== 角色位置调试模式已关闭 ===\n")
		
		_update_debug_info()

func _on_character_gui_input(event):
	if not debug_mode:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始拖动
				dragging = true
				drag_offset = event.position
			else:
				# 结束拖动
				dragging = false
				_print_character_config()

func _process(_delta):
	if not debug_mode or not character or not background:
		return
	
	if dragging:
		# 更新角色位置
		var bg_local_pos = background.get_local_mouse_position()
		
		# 计算角色中心应该在的位置
		if character.texture_normal:
			var char_size = character.texture_normal.get_size() * character.scale
			character.position = bg_local_pos - char_size / 2.0
		
		_update_debug_info()

func _update_debug_info():
	if not debug_mode or not character or not character.texture_normal:
		return
	
	var config = _get_current_config()
	
	debug_label.text = "调试模式 (F1关闭)\n"
	debug_label.text += "拖动角色到想要的位置\n"
	debug_label.text += "---\n"
	debug_label.text += "位置: (%.2f, %.2f)\n" % [config.x, config.y]
	debug_label.text += "缩放: %.2f" % config.scale

func _get_current_config() -> Dictionary:
	if not character or not character.texture_normal or not background or not background.texture:
		return {"x": 0.0, "y": 0.0, "scale": 1.0}
	
	# 获取实际背景区域
	var bg_rect = character._get_actual_background_rect()
	var actual_bg_size = bg_rect.size
	var bg_offset = bg_rect.offset
	
	# 计算角色中心位置
	var char_size = character.texture_normal.get_size() * character.scale
	var char_center = character.position + char_size / 2.0
	
	# 减去偏移，得到在实际背景上的位置
	var pos_in_bg = char_center - bg_offset
	
	# 转换为比例
	var ratio_x = pos_in_bg.x / actual_bg_size.x if actual_bg_size.x > 0 else 0.0
	var ratio_y = pos_in_bg.y / actual_bg_size.y if actual_bg_size.y > 0 else 0.0
	
	# 计算相对于背景的缩放
	var bg_scale = bg_rect.scale
	var relative_scale = character.scale.x / bg_scale if bg_scale > 0 else 1.0
	
	return {
		"x": clamp(ratio_x, 0.0, 1.0),
		"y": clamp(ratio_y, 0.0, 1.0),
		"scale": relative_scale
	}

func _print_character_config():
	var config = _get_current_config()
	
	print("\n--- 角色配置 ---")
	print('{')
	print('  "image": "1.png",')
	print('  "scale": %.2f,' % config.scale)
	print('  "position": {')
	print('    "x": %.2f,' % config.x)
	print('    "y": %.2f' % config.y)
	print('  }')
	print('}')
	print("--- 复制上面的配置到 config/character_presets.json ---\n")
