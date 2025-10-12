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
