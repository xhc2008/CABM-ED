extends Control
class_name InteractionPrompt

# 交互提示UI - 显示可交互物体的提示

@onready var prompt_list = $Panel/VBoxContainer/PromptList
@onready var panel = $Panel

var interactions: Array = []  # [{text: String, callback: Callable, object: Object}]
var selected_index: int = 0

signal interaction_selected(index: int)

func _ready():
	hide()

func show_interactions(interaction_list: Array):
	"""显示交互列表"""
	interactions = interaction_list
	selected_index = 0
	_update_display()
	show()

func hide_interactions():
	"""隐藏交互提示"""
	interactions.clear()
	selected_index = 0
	hide()

func _update_display():
	"""更新显示"""
	# 清空现有显示
	for child in prompt_list.get_children():
		child.queue_free()
	
	if interactions.is_empty():
		hide()
		return
	
	# 创建交互选项
	for i in range(interactions.size()):
		var interaction = interactions[i]
		var label = Label.new()
		label.text = interaction.text
		
		# 设置字体大小
		label.add_theme_font_size_override("font_size", 16)
		
		# 高亮选中项
		if i == selected_index:
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.add_theme_color_override("font_color", Color.WHITE)
		
		prompt_list.add_child(label)
	
	# 等待一帧让布局更新
	await get_tree().process_frame
	
	# 调整Panel大小以适应内容
	if panel:
		var content_size = prompt_list.get_combined_minimum_size()
		panel.custom_minimum_size = Vector2(
			max(200, content_size.x + 40),  # 最小宽度200，加上边距
			max(60, content_size.y + 40)    # 最小高度60，加上边距
		)

func _input(event: InputEvent):
	if not visible or interactions.is_empty():
		return
	
	# 鼠标滚轮选择
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_select_previous()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_select_next()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				# 检查是否点击了某个选项
				_check_click_selection(event.position)
	
	# F键确认，ESC键取消
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_F:
				_confirm_selection()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				hide_interactions()
				get_viewport().set_input_as_handled()

func _select_previous():
	"""选择上一个"""
	if interactions.is_empty():
		return
	selected_index = (selected_index - 1 + interactions.size()) % interactions.size()
	_update_display()

func _select_next():
	"""选择下一个"""
	if interactions.is_empty():
		return
	selected_index = (selected_index + 1) % interactions.size()
	_update_display()

func _check_click_selection(click_pos: Vector2):
	"""检查点击选择"""
	var labels = prompt_list.get_children()
	for i in range(labels.size()):
		var label = labels[i]
		var rect = Rect2(label.global_position, label.size)
		if rect.has_point(click_pos):
			selected_index = i
			_confirm_selection()
			return

func _confirm_selection():
	"""确认选择"""
	if selected_index >= 0 and selected_index < interactions.size():
		var interaction = interactions[selected_index]
		if interaction.has("callback") and interaction.callback.is_valid():
			interaction.callback.call()
		interaction_selected.emit(selected_index)
		hide_interactions()

func get_interaction_count() -> int:
	"""获取交互数量"""
	return interactions.size()
