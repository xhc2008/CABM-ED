extends Panel

signal scene_selected(scene_id: String)
signal character_called()

@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

const ANIMATION_DURATION = 0.2

var scene_buttons: Array = []
var call_button: Button = null

func _ready():
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

func setup_scenes(scenes_config: Dictionary, current_scene: String):
	# 清除现有按钮
	for button in scene_buttons:
		button.queue_free()
	scene_buttons.clear()
	if call_button:
		call_button.queue_free()
		call_button = null
	
	# 获取角色名称
	var character_name = _get_character_name()
	
	# 添加"呼唤角色"按钮
	call_button = Button.new()
	call_button.text = "💬 呼唤" + character_name
	call_button.pressed.connect(_on_call_button_pressed)
	vbox.add_child(call_button)
	
	# 获取当前场景的连通场景列表
	var current_scene_data = scenes_config.get(current_scene, {})
	var connected_scenes = current_scene_data.get("connect", [])
	
	# 只为连通的场景创建按钮
	for scene_id in connected_scenes:
		if not scenes_config.has(scene_id):
			continue
		
		var scene_data = scenes_config[scene_id]
		var button = Button.new()
		
		# 根据场景类型选择图标
		var icon = _get_scene_icon(scene_data.get("class", ""))
		button.text = icon + " 前往" + scene_data.get("name", scene_id)
		button.pressed.connect(_on_scene_button_pressed.bind(scene_id))
		
		vbox.add_child(button)
		scene_buttons.append(button)

func show_menu(at_position: Vector2):
	# 先显示以便计算大小
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 等待布局更新
	await get_tree().process_frame
	
	# 手动计算所需高度
	var button_count = 1 + scene_buttons.size()  # 呼唤按钮 + 场景按钮
	var button_height = 40.0  # 按钮默认高度
	var separation = 5.0  # 按钮间距
	var total_height = button_count * button_height + (button_count - 1) * separation
	
	# 设置面板大小（宽度150，高度根据按钮数量计算）
	var panel_width = 150.0
	var margin = 20.0
	custom_minimum_size = Vector2(panel_width, total_height + margin)
	size = Vector2(panel_width, total_height + margin)
	
	# 设置菜单位置
	position = at_position
	pivot_offset = size / 2.0
	
	# 展开动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_menu():
	if not visible:
		return
	
	pivot_offset = size / 2.0
	
	# 收起动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false

func _on_scene_button_pressed(scene_id: String):
	scene_selected.emit(scene_id)
	hide_menu()

func _on_call_button_pressed():
	character_called.emit()
	hide_menu()

func _get_character_name() -> String:
	"""获取角色名称"""
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		return helpers.get_character_name()
	return "角色"

func _get_scene_icon(scene_class: String) -> String:
	"""根据场景类型返回对应的图标"""
	match scene_class:
		"home":
			return "🏠"
		"outdoor":
			return "🌳"
		_:
			return "📍"

func _input(event):
	# 如果菜单可见，且点击了菜单外的区域，则隐藏菜单
	if visible and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查点击位置是否在菜单内
			var local_pos = get_local_mouse_position()
			var menu_rect = Rect2(Vector2.ZERO, size)
			if not menu_rect.has_point(local_pos):
				hide_menu()
				get_viewport().set_input_as_handled()
