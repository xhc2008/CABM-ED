extends Panel

signal chat_ended

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var character_name_label: Label = $MarginContainer/VBoxContainer/CharacterNameLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var input_field: LineEdit = $MarginContainer/VBoxContainer/InputField
@onready var end_button: Button = $MarginContainer/VBoxContainer/EndButton
@onready var continue_indicator: Label = $ContinueIndicator

var app_config: Dictionary = {}
var is_input_mode: bool = true
var current_message: String = ""
var typing_timer: Timer
var char_index: int = 0
var waiting_for_continue: bool = false
var is_animating: bool = false  # 标记是否正在进行高度动画

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

func _input(event):
	# 在等待继续状态时，点击任意位置继续
	if waiting_for_continue and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_continue_clicked()

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
	waiting_for_continue = false
	character_name_label.visible = false
	message_label.visible = false
	input_field.visible = true
	continue_indicator.visible = false
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	input_field.modulate.a = 1.0  # 确保透明度重置
	custom_minimum_size.y = INPUT_HEIGHT

func _setup_reply_mode():
	is_input_mode = false
	character_name_label.visible = true
	message_label.visible = true
	input_field.visible = false
	character_name_label.modulate.a = 1.0  # 确保透明度重置
	message_label.modulate.a = 1.0  # 确保透明度重置
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
	
	# 获取随机回复
	var replies = app_config.get("preset_replies", ["你好！"])
	var reply = replies[randi() % replies.size()]
	
	# 切换到回复模式
	await _transition_to_reply_mode()
	
	# 开始流式输出
	_start_typing_effect(reply)

func _transition_to_reply_mode():
	# 第一步：输入框淡出
	var fade_tween = create_tween()
	fade_tween.tween_property(input_field, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_tween.finished
	
	# 第二步：隐藏输入框
	input_field.visible = false
	
	# 第三步：准备回复UI元素（但保持透明）
	is_input_mode = false
	character_name_label.visible = true
	message_label.visible = true
	character_name_label.text = app_config.get("character_name", "角色")
	character_name_label.modulate.a = 0.0
	message_label.modulate.a = 0.0
	
	# 第四步：高度变化和内容淡入同时进行
	is_animating = true
	var combined_tween = create_tween()
	combined_tween.set_parallel(true)
	# 同时动画 custom_minimum_size 和 size
	combined_tween.tween_property(self, "custom_minimum_size:y", REPLY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(self, "size:y", REPLY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(character_name_label, "modulate:a", 1.0, ANIMATION_DURATION)
	combined_tween.tween_property(message_label, "modulate:a", 1.0, ANIMATION_DURATION)
	await combined_tween.finished
	is_animating = false

func _transition_to_input_mode():
	print("=== 开始转换到输入模式 ===")
	print("当前高度: ", custom_minimum_size.y)
	print("当前size: ", size)
	
	# 第一步：回复内容淡出
	print("步骤1: 开始淡出回复内容")
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(character_name_label, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_tween.tween_property(message_label, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_tween.finished
	print("步骤1: 淡出完成")
	
	# 第二步：隐藏回复UI元素
	character_name_label.visible = false
	message_label.visible = false
	print("步骤2: 隐藏回复UI")
	
	# 第三步：准备输入框（但保持透明）
	is_input_mode = true
	waiting_for_continue = false
	continue_indicator.visible = false
	input_field.visible = true
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	input_field.modulate.a = 0.0
	print("步骤3: 准备输入框")
	
	# 第四步：高度变化和输入框淡入同时进行
	print("步骤4: 开始高度动画，从 size.y=", size.y, " 到 ", INPUT_HEIGHT)
	is_animating = true
	var combined_tween = create_tween()
	combined_tween.set_parallel(true)
	# 同时动画 custom_minimum_size 和 size
	combined_tween.tween_property(self, "custom_minimum_size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(self, "size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(input_field, "modulate:a", 1.0, ANIMATION_DURATION)
	
	# 等待动画完成
	await combined_tween.finished
	is_animating = false
	print("步骤4: 动画完成")
	print("最终 custom_minimum_size.y: ", custom_minimum_size.y)
	print("最终 size.y: ", size.y)
	print("=== 转换完成 ===")
	
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
		# 打字完成后，显示继续指示器并等待用户点击
		_show_continue_indicator()

func _show_continue_indicator():
	waiting_for_continue = true
	continue_indicator.visible = true
	continue_indicator.modulate.a = 0.0
	
	# 淡入动画
	var fade_tween = create_tween()
	fade_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.3)
	
	# 循环闪烁动画
	await fade_tween.finished
	_start_indicator_blink()

func _start_indicator_blink():
	var blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.6)
	blink_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.6)

func _on_continue_clicked():
	if not waiting_for_continue:
		return
	
	waiting_for_continue = false
	
	# 隐藏指示器
	continue_indicator.visible = false
	
	# 切换回输入模式
	await _transition_to_input_mode()
