extends Control

@onready var back_button: Button = $Container/BackButton
@onready var tutorial_text: RichTextLabel = $Container/ScrollContainer/Content/TutorialText

func _ready():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if tutorial_text:
		tutorial_text.meta_clicked.connect(_on_meta_clicked)

func _on_back_pressed():
	"""返回按钮被点击"""
	# 返回到初始设置页面
	get_tree().change_scene_to_file("res://scenes/initial_setup.tscn")

func _on_meta_clicked(meta):
	"""处理RichTextLabel中的链接点击"""
	if meta is String and meta.begins_with("http"):
		OS.shell_open(meta)
