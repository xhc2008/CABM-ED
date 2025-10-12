extends Panel

signal action_selected(action: String)

@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var chat_button: Button = $MarginContainer/VBoxContainer/ChatButton

const ANIMATION_DURATION = 0.2

func _ready():
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 连接按钮信号
	chat_button.pressed.connect(_on_chat_button_pressed)

func _input(event):
	# 如果菜单可见，且点击了菜单外的区域，则隐藏菜单
	if visible and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查点击位置是否在菜单内
			var local_pos = get_local_mouse_position()
			var menu_rect = Rect2(Vector2.ZERO, size)
			if not menu_rect.has_point(local_pos):
				hide_menu()
				# 接受事件，防止传递到其他节点
				get_viewport().set_input_as_handled()

func show_menu(at_position: Vector2):
	# 设置菜单位置（在角色旁边）
	position = at_position
	
	visible = true
	pivot_offset = size / 2.0
	
	# 展开动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_menu():
	pivot_offset = size / 2.0
	
	# 收起动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false

func _on_chat_button_pressed():
	action_selected.emit("chat")
	hide_menu()
