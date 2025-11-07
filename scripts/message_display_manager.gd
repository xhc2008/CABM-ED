extends Node
class_name MessageDisplayManager

# 消息显示管理器 - 负责各种提示消息的显示

var message_label: Label
var message_tween: Tween
var scene_manager: SceneManager

func initialize(scene_mgr: SceneManager, parent: Node):
	"""初始化管理器"""
	scene_manager = scene_mgr
	
	# 创建消息标签
	message_label = Label.new()
	message_label.visible = false
	message_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.z_index = 100
	parent.add_child(message_label)

func show_failure_message(message: String):
	"""显示失败消息（红色）"""
	_show_message(message, Color(1, 0.3, 0.3))

func show_info_message(message: String):
	"""显示信息消息（蓝色）"""
	_show_message(message, Color(0.5, 0.8, 1.0))

func _show_message(message: String, color: Color):
	"""显示消息（通用函数）"""
	if message_label == null:
		return
	
	if message_tween != null and message_tween.is_valid():
		message_tween.kill()
	
	message_label.text = message
	message_label.add_theme_color_override("font_color", color)
	
	var scene_rect = scene_manager.scene_rect
	var label_pos = Vector2(
		scene_rect.position.x + scene_rect.size.x / 2,
		scene_rect.position.y + scene_rect.size.y * 0.3
	)
	
	message_label.position = label_pos
	message_label.size = Vector2.ZERO
	
	await message_label.get_tree().process_frame
	message_label.position.x -= message_label.size.x / 2
	
	message_label.modulate.a = 0.0
	message_label.visible = true
	
	message_tween = message_label.create_tween()
	message_tween.tween_property(message_label, "modulate:a", 1.0, 0.3)
	message_tween.tween_interval(2.0)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
	
	await message_tween.finished
	message_label.visible = false
	message_tween = null
