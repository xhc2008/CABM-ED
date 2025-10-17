extends Panel

@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	
	# 点击背景关闭
	gui_input.connect(_on_panel_input)

func _on_close_pressed():
	queue_free()

func _on_panel_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查是否点击在面板外
			var local_pos = event.position
			if not Rect2(Vector2.ZERO, size).has_point(local_pos):
				queue_free()
