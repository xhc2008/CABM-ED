extends Panel

signal chat_ended

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var character_name_label: Label = $MarginContainer/VBoxContainer/CharacterNameLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var input_field: LineEdit = $MarginContainer/VBoxContainer/InputField
@onready var end_button: Button = $MarginContainer/VBoxContainer/EndButton

var app_config: Dictionary = {}
var is_input_mode: bool = true
var current_message: String = ""
var typing_timer: Timer
var char_index: int = 0

const INPUT_HEIGHT = 80.0
const REPLY_HEIGHT = 200.0
const ANIMATION_DURATION = 0.3
const TYPING_SPEED = 0.05  # 每个字符的显示间隔

func _ready():
	end_button.pressed.connect(_on_end_button_pressed)
	input_field.text_submitted.connect(_on_input_submitted)
	
	# 创建打字机效果的计时器
	typing_timer = Timer.new()
	typing_timer.one_shot = false
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(typing_timer)
	
	# 加载配置
	_load_config()
	
	# 初始化为输入模式
	_setup_input_mode()
	
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

func _load_config():
	var config_path = "res://config/app_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			app_config = json.data
			print("应用配置已加载")
		else:
			print("解析应用配置失败")
			_set_default_config()
	else:
		print("应用配置文件不存在，使用默认配置")
		_set_default_config()

func _set_default_config():
	app_config = {
		"user_name": "用户",
		"character_name": "小助手",
		"preset_replies": ["你好！", "我在听呢", "有趣！"]
	}

func _setup_input_mode():
	is_input_mode = true
	character_name_label.visible = false
	message_label.visible = false
	input_field.visible = true
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	custom_minimum_size.y = INPUT_HEIGHT

func _setup_reply_mode():
	is_input_mode = false
	character_name_label.visible = true
	message_label.visible = true
	input_field.visible = false
	character_name_label.text = app_config.get("character_name", "角色")
	custom_minimum_size.y = REPLY_HEIGHT

func show_dialog():
	visible = true
	pivot_offset = size / 2.0
	
	# 展开动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 聚焦输入框
	await tween.finished
	if is_input_mode:
		input_field.grab_focus()

func hide_dialog():
	pivot_offset = size / 2.0
	
	# 收起动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false
	
	# 重置为输入模式
	_setup_input_mode()

func _on_end_button_pressed():
	hide_dialog()
	await get_tree().create_timer(0.3).timeout
	chat_ended.emit()

func _on_input_submitted(text: String):
	if text.strip_edges().is_empty():
		return
	
	print("用户输入: ", text)
	
	# 切换到回复模式
	_transition_to_reply_mode()
	
	# 获取随机回复
	var replies = app_config.get("preset_replies", ["你好！"])
	var reply = replies[randi() % replies.size()]
	
	# 开始流式输出
	_start_typing_effect(reply)

func _transition_to_reply_mode():
	# 状态切换动画
	var tween = create_tween()
	tween.tween_property(self, "custom_minimum_size:y", REPLY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	_setup_reply_mode()

func _transition_to_input_mode():
	# 状态切换动画
	var tween = create_tween()
	tween.tween_property(self, "custom_minimum_size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	_setup_input_mode()
	input_field.grab_focus()

func _start_typing_effect(text: String):
	current_message = text
	char_index = 0
	message_label.text = ""
	typing_timer.start(TYPING_SPEED)

func _on_typing_timer_timeout():
	if char_index < current_message.length():
		message_label.text += current_message[char_index]
		char_index += 1
	else:
		typing_timer.stop()
		# 打字完成后，等待一段时间再切换回输入模式
		await get_tree().create_timer(1.5).timeout
		_transition_to_input_mode()
