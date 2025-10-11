extends Panel

signal chat_ended

@onready var end_button: Button = $MarginContainer/VBoxContainer/EndButton

func _ready():
	end_button.pressed.connect(_on_end_button_pressed)
	visible = false

func show_dialog():
	visible = true

func hide_dialog():
	visible = false

func _on_end_button_pressed():
	hide_dialog()
	chat_ended.emit()
