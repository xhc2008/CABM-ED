extends Panel

signal scene_selected(scene_id: String)

@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

const ANIMATION_DURATION = 0.2

var scene_buttons: Array = []

func _ready():
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

func setup_scenes(scenes_config: Dictionary, current_scene: String):
	# 清除现有按钮
	for button in scene_buttons:
		button.queue_free()
	scene_buttons.clear()
	
	# 为每个场景（除当前场景外）创建按钮
	for scene_id in scenes_config.keys():
		if scene_id == current_scene:
			continue
		
		var scene_data = scenes_config[scene_id]
		var button = Button.new()
		button.text = "🏠 " + scene_data.get("name", scene_id)
		button.pressed.connect(_on_scene_button_pressed.bind(scene_id))
		
		vbox.add_child(button)
		scene_buttons.append(button)
	
	# 更新面板大小
	await get_tree().process_frame
	custom_minimum_size = vbox.size + Vector2(20, 20)

func show_menu(at_position: Vector2):
	# 设置菜单位置
	position = at_position
	
	visible = true
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
