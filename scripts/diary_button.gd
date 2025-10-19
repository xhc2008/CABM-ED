extends Control

signal diary_selected

# 判定区域（隐藏的点击区域）
var click_area: Control
# 选项菜单
var options_panel: Panel
var diary_button: Button

const ANIMATION_DURATION = 0.2
const ELEMENT_ID = "diary_button"  # 配置文件中的ID

var is_enabled: bool = false
var is_menu_visible: bool = false

func _ready():
	# 从配置获取大小
	var element_size = Vector2(80, 80)
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		element_size = mgr.get_element_size(ELEMENT_ID)
		mgr.register_element(ELEMENT_ID, self)
	
	# 创建隐藏的点击区域
	click_area = Control.new()
	click_area.custom_minimum_size = element_size
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.gui_input.connect(_on_click_area_input)
	add_child(click_area)
	
	# 设置自身大小
	custom_minimum_size = element_size
	
	# 创建选项面板
	_create_options_panel()
	
	visible = false

func _create_options_panel():
	"""创建选项面板"""
	options_panel = Panel.new()
	options_panel.custom_minimum_size = Vector2(120, 0)
	options_panel.visible = false
	options_panel.modulate.a = 0.0
	add_child(options_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	options_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# 日记按钮
	diary_button = Button.new()
	diary_button.text = "📖 日记"
	diary_button.pressed.connect(_on_diary_button_pressed)
	vbox.add_child(diary_button)
	
	# 等待布局更新
	await get_tree().process_frame
	
	# 设置选项面板位置（在点击区域上方）
	options_panel.position = Vector2(0, -options_panel.size.y - 10)

func enable():
	"""启用判定区域（在bedroom场景）"""
	if is_enabled:
		return
	
	is_enabled = true
	visible = true
	
	# 检查UIManager的状态，如果UI被禁用，则不启用交互
	if has_node("/root/UIManager"):
		var ui_mgr = get_node("/root/UIManager")
		if ui_mgr.is_ui_interactive():
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

func disable():
	"""禁用判定区域（离开bedroom场景）"""
	if not is_enabled:
		return
	
	is_enabled = false
	
	# 如果菜单正在显示，先隐藏
	if is_menu_visible:
		hide_menu()
	
	visible = false

func set_interactive(interactive: bool):
	"""设置交互状态（由UIManager调用）"""
	# 只有在enabled状态下才响应交互状态变化
	if not is_enabled:
		return
	
	if interactive:
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 如果菜单正在显示，先隐藏
		if is_menu_visible:
			hide_menu()

func _on_click_area_input(event: InputEvent):
	"""点击区域输入事件"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_menu_visible:
				hide_menu()
			else:
				show_menu()

func show_menu():
	"""显示选项菜单"""
	if is_menu_visible:
		return
	
	is_menu_visible = true
	options_panel.visible = true
	options_panel.pivot_offset = options_panel.size / 2.0
	options_panel.scale = Vector2(0.8, 0.8)
	
	# 展开动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(options_panel, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(options_panel, "scale", Vector2.ONE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_menu():
	"""隐藏选项菜单"""
	if not is_menu_visible:
		return
	
	is_menu_visible = false
	options_panel.pivot_offset = options_panel.size / 2.0
	
	# 收起动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(options_panel, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(options_panel, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	options_panel.visible = false

func _on_diary_button_pressed():
	"""日记按钮点击"""
	diary_selected.emit()
	hide_menu()

func _input(event):
	"""全局输入事件 - 点击外部关闭菜单"""
	if not is_menu_visible:
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查点击位置是否在菜单或点击区域内
			var local_pos = get_local_mouse_position()
			var menu_rect = Rect2(options_panel.position, options_panel.size)
			var click_rect = Rect2(Vector2.ZERO, click_area.size)
			
			if not menu_rect.has_point(local_pos) and not click_rect.has_point(local_pos):
				hide_menu()
				get_viewport().set_input_as_handled()
