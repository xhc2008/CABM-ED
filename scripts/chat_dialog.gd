extends Panel

signal chat_ended

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var character_name_label: Label = $MarginContainer/VBoxContainer/CharacterNameLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var end_button: Button = $MarginContainer/VBoxContainer/EndButton
@onready var continue_indicator: Label = $ContinueIndicator

# 这些节点可能不存在，需要动态创建
var input_container: HBoxContainer
var input_field: LineEdit
var send_button: Button

var app_config: Dictionary = {}
var is_input_mode: bool = true
var current_message: String = ""
var typing_timer: Timer
var char_index: int = 0
var waiting_for_continue: bool = false
var is_animating: bool = false # 标记是否正在进行高度动画

# 流式输出相关
var display_buffer: String = ""  # 待显示的内容缓冲
var displayed_text: String = ""  # 已显示的内容
var is_receiving_stream: bool = false  # 是否正在接收流式数据

const INPUT_HEIGHT = 120.0
const REPLY_HEIGHT = 200.0
const ANIMATION_DURATION = 0.3
const TYPING_SPEED = 0.05 # 每个字符的显示间隔（最大输出速度）

func _ensure_ui_structure():
	"""确保UI结构正确，如果场景文件中没有InputContainer则动态创建"""
	# 尝试获取现有的 InputContainer
	input_container = vbox.get_node_or_null("InputContainer")
	
	if input_container != null:
		# InputContainer 已存在，获取子节点
		input_field = input_container.get_node_or_null("InputField")
		send_button = input_container.get_node_or_null("SendButton")
		print("使用现有的 InputContainer 结构")
		return
	
	# 检查是否有旧的 InputField（直接在 VBox 下）
	var old_input_field = vbox.get_node_or_null("InputField")
	if old_input_field != null:
		# 需要重构：将InputField移到新的InputContainer中
		print("检测到旧的UI结构，正在重构...")
		
		# 创建InputContainer
		input_container = HBoxContainer.new()
		input_container.name = "InputContainer"
		input_container.add_theme_constant_override("separation", 8)
		
		# 从VBox中移除旧的InputField
		vbox.remove_child(old_input_field)
		
		# 将InputField添加到InputContainer
		input_container.add_child(old_input_field)
		old_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# 创建SendButton
		send_button = Button.new()
		send_button.name = "SendButton"
		send_button.text = "发送"
		send_button.custom_minimum_size = Vector2(80, 0)
		input_container.add_child(send_button)
		
		# 将InputContainer添加到VBox中（在EndButton之前）
		if end_button:
			var end_btn_index = end_button.get_index()
			vbox.add_child(input_container)
			vbox.move_child(input_container, end_btn_index)
		else:
			vbox.add_child(input_container)
		
		# 更新引用
		input_field = old_input_field
		
		print("UI重构完成")
	else:
		# 完全没有输入相关节点，创建全新的
		print("创建全新的输入UI结构...")
		
		# 创建InputContainer
		input_container = HBoxContainer.new()
		input_container.name = "InputContainer"
		input_container.add_theme_constant_override("separation", 8)
		
		# 创建InputField
		input_field = LineEdit.new()
		input_field.name = "InputField"
		input_field.placeholder_text = "输入消息..."
		input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input_container.add_child(input_field)
		
		# 创建SendButton
		send_button = Button.new()
		send_button.name = "SendButton"
		send_button.text = "发送"
		send_button.custom_minimum_size = Vector2(80, 0)
		input_container.add_child(send_button)
		
		# 将InputContainer添加到VBox中（在EndButton之前）
		if end_button:
			var end_btn_index = end_button.get_index()
			vbox.add_child(input_container)
			vbox.move_child(input_container, end_btn_index)
		else:
			vbox.add_child(input_container)
		
		print("输入UI创建完成")

func _ready():
	# 如果节点不存在，动态创建
	_ensure_ui_structure()
	
	if end_button:
		end_button.pressed.connect(_on_end_button_pressed)
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)
	
	# 创建打字机效果的计时器
	typing_timer = Timer.new()
	typing_timer.one_shot = false
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(typing_timer)
	
	# 加载配置
	_load_config()
	
	# 连接 AI 服务信号
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.chat_response_received.connect(_on_ai_response)
		ai_service.chat_response_completed.connect(_on_ai_response_completed)
		ai_service.chat_error.connect(_on_ai_error)
	
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
	input_container.visible = true
	input_field.visible = true
	send_button.visible = true
	continue_indicator.visible = false
	end_button.visible = true # 输入模式下显示结束按钮
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	input_field.modulate.a = 1.0 # 确保透明度重置
	input_container.modulate.a = 1.0 # 确保透明度重置
	custom_minimum_size.y = INPUT_HEIGHT

func _setup_reply_mode():
	is_input_mode = false
	character_name_label.visible = true
	message_label.visible = true
	input_container.visible = false
	end_button.visible = false # 回复模式下隐藏结束按钮
	character_name_label.modulate.a = 1.0 # 确保透明度重置
	message_label.modulate.a = 1.0 # 确保透明度重置
	character_name_label.text = app_config.get("character_name", "角色")
	custom_minimum_size.y = REPLY_HEIGHT

func show_dialog(mode: String = "passive"):
	"""
	显示对话框
	mode: "passive" = 用户先说（输入模式）, "active" = 角色先说（回复模式）
	"""
	visible = true
	pivot_offset = size / 2.0
	
	# 根据模式设置初始状态
	if mode == "active":
		# 角色主动说话，直接进入回复模式
		_setup_reply_mode()
		message_label.text = ""  # 清空消息
	else:
		# 用户先说话，进入输入模式
		_setup_input_mode()
	
	# 展开动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# 根据模式执行后续操作
	if mode == "active":
		# 角色主动模式：调用AI生成第一句话
		if has_node("/root/AIService"):
			var ai_service = get_node("/root/AIService")
			ai_service.start_chat("", "character_initiated")
		else:
			# 如果 AI 服务不可用，使用预设回复
			var replies = app_config.get("preset_replies", ["你好！"])
			var active_reply = replies[randi() % replies.size()]
			_start_typing_effect(active_reply)
	else:
		# 被动模式：聚焦输入框
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
	# 结束聊天时调用总结
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.end_chat()
	
	hide_dialog()
	await get_tree().create_timer(0.3).timeout
	chat_ended.emit()

func _on_ai_response(response: String):
	"""AI 响应回调 - 接收流式增量内容"""
	if not is_receiving_stream:
		# 第一次接收，开始流式显示
		is_receiving_stream = true
		display_buffer = ""
		displayed_text = ""
		message_label.text = ""
		typing_timer.start(TYPING_SPEED)
	
	# 将新内容添加到buffer
	display_buffer += response

func _on_ai_response_completed():
	"""AI 流式响应完成回调"""
	is_receiving_stream = false
	# 如果buffer已全部显示，立即显示继续指示器
	if displayed_text.length() >= display_buffer.length():
		typing_timer.stop()
		_show_continue_indicator()

func _on_ai_error(error_message: String):
	"""AI 错误回调"""
	print("AI 错误: ", error_message)
	is_receiving_stream = false
	# 显示错误消息
	_start_typing_effect("抱歉，我现在有点累了，稍后再聊吧...")

func _on_send_button_pressed():
	_on_input_submitted(input_field.text)

func _on_input_submitted(text: String):
	if text.strip_edges().is_empty():
		return
	
	print("用户输入: ", text)
	
	# 切换到回复模式
	await _transition_to_reply_mode()
	
	# 判断角色是否愿意回复（与start_chat事件相同的判定机制）
	var will_reply = _check_reply_willingness()
	
	if not will_reply:
		# 角色不愿意回复，显示"……"
		_handle_reply_refusal(text)
		return
	
	# 调用 AI 服务（用户主动触发）
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.start_chat(text, "user_initiated")
	else:
		# 如果 AI 服务不可用，使用预设回复
		var replies = app_config.get("preset_replies", ["你好！"])
		var reply = replies[randi() % replies.size()]
		_start_typing_effect(reply)

func _transition_to_reply_mode():
	# 第一步：输入容器和结束按钮淡出
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(input_container, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_tween.tween_property(end_button, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_tween.finished
	
	# 第二步：隐藏输入容器和结束按钮
	input_container.visible = false
	end_button.visible = false
	
	# 第三步：准备回复UI元素（但保持透明）
	is_input_mode = false
	character_name_label.visible = true
	message_label.visible = true
	character_name_label.text = app_config.get("character_name", "角色")
	message_label.text = "" # 清除之前的内容
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
	# 第一步：回复内容淡出
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(character_name_label, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_tween.tween_property(message_label, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_tween.finished
	
	# 第二步：隐藏回复UI元素
	character_name_label.visible = false
	message_label.visible = false
	
	# 第三步：准备输入容器和结束按钮（但保持透明）
	is_input_mode = true
	waiting_for_continue = false
	continue_indicator.visible = false
	input_container.visible = true
	end_button.visible = true
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	input_container.modulate.a = 0.0
	end_button.modulate.a = 0.0
	
	# 第四步：高度变化和输入容器、结束按钮淡入同时进行
	is_animating = true
	var combined_tween = create_tween()
	combined_tween.set_parallel(true)
	# 同时动画 custom_minimum_size 和 size
	combined_tween.tween_property(self, "custom_minimum_size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(self, "size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(input_container, "modulate:a", 1.0, ANIMATION_DURATION)
	combined_tween.tween_property(end_button, "modulate:a", 1.0, ANIMATION_DURATION)
	
	# 等待动画完成
	await combined_tween.finished
	is_animating = false
	
	input_field.grab_focus()

func _start_typing_effect(text: String):
	"""启动打字机效果（用于非流式模式）"""
	current_message = text
	char_index = 0
	message_label.text = ""
	is_receiving_stream = false
	display_buffer = text
	displayed_text = ""
	typing_timer.start(TYPING_SPEED)

func _on_typing_timer_timeout():
	"""打字机效果定时器 - 支持流式buffer"""
	if displayed_text.length() < display_buffer.length():
		# buffer中还有未显示的内容，继续显示
		var next_char = display_buffer[displayed_text.length()]
		displayed_text += next_char
		message_label.text = displayed_text
	elif is_receiving_stream:
		# 正在接收流式数据，但buffer已显示完，等待更多数据
		pass
	else:
		# 所有内容已显示完毕
		typing_timer.stop()
		is_receiving_stream = false
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


# 检查角色是否愿意回复（与start_chat事件相同的判定机制）
func _check_reply_willingness() -> bool:
	if not has_node("/root/InteractionManager"):
		return true  # 如果没有交互管理器，默认愿意回复
	
	var interaction_mgr = get_node("/root/InteractionManager")
	
	# 使用与start_chat相同的判定逻辑
	var success_chance = interaction_mgr.calculate_success_chance("chat")
	var roll = randf()
	var success = roll < success_chance
	
	print("回复意愿判定 - 成功率: ", success_chance * 100, "% 掷骰: ", roll, " 结果: ", "愿意回复" if success else "不愿意回复")
	
	return success

# 处理角色拒绝回复的情况
func _handle_reply_refusal(user_message: String):
	# 显示"……"作为角色的回复
	_start_typing_effect("……")
	
	# 等待打字效果完成
	while typing_timer.time_left > 0 or displayed_text.length() < display_buffer.length():
		await get_tree().process_frame
	
	# 在对话框下方显示红色提示文字
	await _show_refusal_message()
	
	# 将"……"作为历史记录添加到AI服务
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		# 添加用户消息和角色的"……"回复到历史记录
		ai_service.add_to_history("user", user_message)
		ai_service.add_to_history("assistant", "……")
	
	# 修改属性值
	_apply_refusal_effects()

# 显示拒绝回复的提示消息
func _show_refusal_message():
	var character_name = app_config.get("character_name", "角色")
	var refusal_text = character_name + "似乎不太想继续这个话题"
	
	# 在message_label下方创建一个临时的红色提示标签
	var refusal_label = Label.new()
	refusal_label.name = "RefusalLabel"
	refusal_label.text = refusal_text
	refusal_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # 红色
	refusal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refusal_label.modulate.a = 0.0
	
	# 添加到VBox中（在message_label之后）
	var message_index = message_label.get_index()
	vbox.add_child(refusal_label)
	vbox.move_child(refusal_label, message_index + 1)
	
	# 淡入动画
	var fade_in = create_tween()
	fade_in.tween_property(refusal_label, "modulate:a", 1.0, 0.3)
	await fade_in.finished
	
	# 等待2秒
	await get_tree().create_timer(2.0).timeout
	
	# 淡出动画
	var fade_out = create_tween()
	fade_out.tween_property(refusal_label, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	
	# 移除标签
	refusal_label.queue_free()

# 应用拒绝回复的属性变化
func _apply_refusal_effects():
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# 回复意愿随机增加 -20~10（负值就是减少）
	var willingness_change = randi_range(-20, 10)
	var current_willingness = save_mgr.get_reply_willingness()
	var new_willingness = clamp(current_willingness + willingness_change, 0, 100)
	save_mgr.set_reply_willingness(new_willingness)
	print("拒绝回复 - 回复意愿变化: ", current_willingness, " -> ", new_willingness, " (", willingness_change, ")")
	
	# 好感度随机增加 -5~0
	var affection_change = randi_range(-5, 0)
	var current_affection = save_mgr.get_affection()
	var new_affection = clamp(current_affection + affection_change, 0, 100)
	save_mgr.set_affection(new_affection)
	print("拒绝回复 - 好感度变化: ", current_affection, " -> ", new_affection, " (", affection_change, ")")
	
	# 心情不变
	print("拒绝回复 - 心情保持不变")
