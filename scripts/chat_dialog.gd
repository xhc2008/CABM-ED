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
var history_button: Button

var app_config: Dictionary = {}
var is_input_mode: bool = true
var waiting_for_continue: bool = false

# 模块化组件
var input_handler: Node
var ui_manager: Node
var history_manager: Node
var typing_manager: Node

# goto相关
const GOTO_COOLDOWN_DURATION = 60.0
var goto_cooldown_end_time: float = 0.0
var goto_notification_label: Label = null

func _ensure_ui_structure():
	"""确保UI结构正确，如果场景文件中没有InputContainer则动态创建"""
	input_container = vbox.get_node_or_null("InputContainer")
	
	if input_container != null:
		input_field = input_container.get_node_or_null("InputField")
		send_button = input_container.get_node_or_null("SendButton")
		history_button = input_container.get_node_or_null("HistoryButton")
		
		if history_button == null:
			history_button = Button.new()
			history_button.name = "HistoryButton"
			history_button.text = "历史"
			history_button.custom_minimum_size = Vector2(60, 0)
			input_container.add_child(history_button)
			input_container.move_child(history_button, send_button.get_index())
		
		print("使用现有的 InputContainer 结构")
		return
	
	var old_input_field = vbox.get_node_or_null("InputField")
	if old_input_field != null:
		print("检测到旧的UI结构，正在重构...")
		
		input_container = HBoxContainer.new()
		input_container.name = "InputContainer"
		input_container.add_theme_constant_override("separation", 8)
		
		vbox.remove_child(old_input_field)
		
		input_container.add_child(old_input_field)
		old_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		history_button = Button.new()
		history_button.name = "HistoryButton"
		history_button.text = "历史"
		history_button.custom_minimum_size = Vector2(60, 0)
		input_container.add_child(history_button)
		
		send_button = Button.new()
		send_button.name = "SendButton"
		send_button.text = "发送"
		send_button.custom_minimum_size = Vector2(80, 0)
		input_container.add_child(send_button)
		
		if end_button:
			var end_btn_index = end_button.get_index()
			vbox.add_child(input_container)
			vbox.move_child(input_container, end_btn_index)
		else:
			vbox.add_child(input_container)
		
		input_field = old_input_field
		print("UI重构完成")
	else:
		print("创建全新的输入UI结构...")
		
		input_container = HBoxContainer.new()
		input_container.name = "InputContainer"
		input_container.add_theme_constant_override("separation", 8)
		
		input_field = LineEdit.new()
		input_field.name = "InputField"
		input_field.placeholder_text = "输入消息..."
		input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input_container.add_child(input_field)
		
		history_button = Button.new()
		history_button.name = "HistoryButton"
		history_button.text = "历史"
		history_button.custom_minimum_size = Vector2(60, 0)
		input_container.add_child(history_button)
		
		send_button = Button.new()
		send_button.name = "SendButton"
		send_button.text = "发送"
		send_button.custom_minimum_size = Vector2(80, 0)
		input_container.add_child(send_button)
		
		if end_button:
			var end_btn_index = end_button.get_index()
			vbox.add_child(input_container)
			vbox.move_child(input_container, end_btn_index)
		else:
			vbox.add_child(input_container)
		
		print("输入UI创建完成")

func _ready():
	_ensure_ui_structure()
	
	# 初始化模块
	_init_modules()
	
	# 连接信号
	if end_button:
		end_button.pressed.connect(_on_end_button_pressed)
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)
	if history_button:
		history_button.pressed.connect(_on_history_button_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)
		input_field.text_changed.connect(_on_input_text_changed)
	
	_load_config()
	
	# 连接 AI 服务信号
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.chat_response_received.connect(_on_ai_response)
		ai_service.chat_response_completed.connect(_on_ai_response_completed)
		ai_service.chat_error.connect(_on_ai_error)
	
	# 连接事件管理器信号
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.event_completed.connect(_on_event_completed)
	
	_setup_input_mode()
	
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

func _init_modules():
	# 输入处理模块
	input_handler = preload("res://scripts/chat_dialog_input_handler.gd").new()
	input_handler.name = "InputHandler"
	add_child(input_handler)
	input_handler.setup(self)
	input_handler.continue_requested.connect(_on_continue_clicked)
	
	# UI管理模块
	ui_manager = preload("res://scripts/chat_dialog_ui_manager.gd").new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	ui_manager.setup(self, character_name_label, message_label, input_container,
					 input_field, send_button, end_button, continue_indicator)
	
	# 打字机效果模块
	typing_manager = preload("res://scripts/chat_dialog_typing.gd").new()
	typing_manager.name = "TypingManager"
	add_child(typing_manager)
	typing_manager.setup(self, message_label)
	typing_manager.sentence_completed.connect(_on_sentence_completed)
	typing_manager.all_sentences_completed.connect(_on_all_sentences_completed)
	
	# 历史记录模块
	history_manager = preload("res://scripts/chat_dialog_history.gd").new()
	history_manager.name = "HistoryManager"
	add_child(history_manager)
	# 延迟初始化，等待所有UI元素准备好
	call_deferred("_init_history_manager")

func _init_history_manager():
	history_manager.setup(self, vbox, input_container, input_field,
						  send_button, end_button, history_button, app_config)

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
	end_button.visible = true
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	input_field.modulate.a = 1.0
	input_container.modulate.a = 1.0
	custom_minimum_size.y = 120.0

func show_dialog(mode: String = "passive"):
	"""显示对话框
	mode: "passive" = 用户先说（输入模式）, "active" = 角色先说（回复模式）, 
		  "called" = 被呼唤来到场景（角色先说）, "called_here" = 被呼唤但已在场景（角色先说）
	"""
	visible = true
	pivot_offset = size / 2.0
	
	if mode == "active" or mode == "called" or mode == "called_here":
		_setup_reply_mode()
		message_label.text = ""
	else:
		_setup_input_mode()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	if mode == "active" or mode == "called" or mode == "called_here":
		if has_node("/root/AIService"):
			var ai_service = get_node("/root/AIService")
			ai_service.start_chat("", mode)
		else:
			var replies = app_config.get("preset_replies", ["你好！"])
			var active_reply = replies[randi() % replies.size()]
			typing_manager.start_stream()
			typing_manager.add_stream_content(active_reply)
			typing_manager.end_stream()
	else:
		if is_input_mode:
			input_field.grab_focus()

func _setup_reply_mode():
	is_input_mode = false
	character_name_label.visible = true
	message_label.visible = true
	input_container.visible = false
	end_button.visible = false
	character_name_label.modulate.a = 1.0
	message_label.modulate.a = 1.0
	character_name_label.text = app_config.get("character_name", "角色")
	custom_minimum_size.y = 200.0

func hide_dialog():
	pivot_offset = size / 2.0
	
	typing_manager.stop()
	
	if has_node("/root/TTSService"):
		var tts = get_node("/root/TTSService")
		tts.clear_queue()
	
	if continue_indicator:
		continue_indicator.visible = false
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false
	
	waiting_for_continue = false
	_setup_input_mode()

func _on_end_button_pressed():
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		var pending_goto = ai_service.get_pending_goto()
		if pending_goto >= 0:
			print("ChatDialog: 用户主动结束聊天，恢复暂存的goto字段")
			ai_service.response_parser.extracted_fields["goto"] = pending_goto
			ai_service.clear_pending_goto()
			_hide_goto_notification()
			_set_goto_cooldown()
	
	var turn_count = 0
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		for msg in ai_service.current_conversation:
			if msg.role == "user":
				turn_count += 1
		ai_service.end_chat()
	
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.on_chat_session_end(turn_count)
	
	hide_dialog()
	await get_tree().create_timer(0.3).timeout
	chat_ended.emit()

func _on_ai_response(response: String):
	"""AI 响应回调 - 接收流式增量内容"""
	if not typing_manager.is_receiving_stream:
		typing_manager.start_stream()
	
	typing_manager.add_stream_content(response)

func _on_ai_response_completed():
	"""AI 流式响应完成回调"""
	if not typing_manager.has_content():
		var character_name = app_config.get("character_name", "角色")
		_handle_empty_msg_response(character_name + "欲言又止")
		return
	
	typing_manager.end_stream()

func _on_ai_error(error_message: String):
	"""AI 错误回调"""
	print("AI 错误: ", error_message)
	
	if error_message.contains("超时"):
		var character_name = app_config.get("character_name", "角色")
		_handle_empty_msg_response(character_name + "似乎在思考什么，但没有说出来")
	else:
		typing_manager.start_stream()
		typing_manager.add_stream_content("抱歉，我现在有点累了，稍后再聊吧...\n错误信息：" + error_message)
		typing_manager.end_stream()

func _on_input_text_changed(_new_text: String):
	"""输入框文本变化时重置空闲计时器"""
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.reset_idle_timer()

func _on_event_completed(event_name: String, result):
	"""处理事件完成信号"""
	if event_name == "idle_timeout":
		if result.message == "timeout_to_input":
			if history_manager.is_history_visible:
				await history_manager.hide_history()
			elif waiting_for_continue:
				waiting_for_continue = false
				continue_indicator.visible = false
				await ui_manager.transition_to_input_mode()
			
			await get_tree().create_timer(0.5).timeout
			_on_end_button_pressed()
		elif result.message == "chat_idle_timeout":
			_on_end_button_pressed()

func _on_send_button_pressed():
	_on_input_submitted(input_field.text)

func _on_input_submitted(text: String):
	if text.strip_edges().is_empty():
		return
	
	print("用户输入: ", text)
	
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		var pending_goto = ai_service.get_pending_goto()
		if pending_goto >= 0:
			print("ChatDialog: 用户输入消息，放弃暂存的goto字段")
			ai_service.clear_pending_goto()
			_hide_goto_notification()
	
	await ui_manager.transition_to_reply_mode(app_config.get("character_name", "角色"))
	
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		var result = event_mgr.on_chat_turn_end()
		
		if not result.success:
			_handle_reply_refusal(text, result.message)
			return
	else:
		print("警告: EventManager未找到，默认允许回复")
	
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.start_chat(text, "user_initiated")
	else:
		var replies = app_config.get("preset_replies", ["你好！"])
		var reply = replies[randi() % replies.size()]
		typing_manager.start_stream()
		typing_manager.add_stream_content(reply)
		typing_manager.end_stream()

func _on_sentence_completed():
	"""单个句子显示完成"""
	waiting_for_continue = true
	input_handler.set_waiting_for_continue(true)
	ui_manager.show_continue_indicator()
	
	# 检查TTS状态
	var tts_enabled = false
	if has_node("/root/TTSService"):
		var tts = get_node("/root/TTSService")
		tts_enabled = tts.is_enabled
	
	if not tts_enabled:
		if has_node("/root/EventManager"):
			var event_mgr = get_node("/root/EventManager")
			event_mgr.reset_idle_timer()
			print("TTS未启用，文本输出完毕，重置空闲计时器")

func _on_all_sentences_completed():
	"""所有句子显示完成"""
	waiting_for_continue = true
	input_handler.set_waiting_for_continue(true)
	ui_manager.show_continue_indicator()
	
	# 检查TTS状态
	var tts_enabled = false
	if has_node("/root/TTSService"):
		var tts = get_node("/root/TTSService")
		tts_enabled = tts.is_enabled
	
	if not tts_enabled:
		if has_node("/root/EventManager"):
			var event_mgr = get_node("/root/EventManager")
			event_mgr.reset_idle_timer()
			print("TTS未启用，所有文本输出完毕，重置空闲计时器")

func _on_continue_clicked():
	if not waiting_for_continue:
		return
	
	waiting_for_continue = false
	input_handler.set_waiting_for_continue(false)
	ui_manager.hide_continue_indicator()
	
	if typing_manager.has_more_sentences():
		typing_manager.show_next_sentence()
	elif typing_manager.is_receiving_stream:
		pass # 等待更多句子
	else:
		var goto_action = _check_and_handle_goto()
		
		if goto_action == "immediate":
			await ui_manager.transition_to_input_mode()
			await get_tree().process_frame
			_on_end_button_pressed()
		elif goto_action == "pending":
			await ui_manager.transition_to_input_mode()
		else:
			await ui_manager.transition_to_input_mode()

func _check_and_handle_goto() -> String:
	"""检查并处理goto字段"""
	if not has_node("/root/AIService"):
		return "none"
	
	var ai_service = get_node("/root/AIService")
	var goto_index = ai_service.get_goto_field()
	
	if goto_index < 0:
		return "none"
	
	if not has_node("/root/PromptBuilder") or not has_node("/root/SaveManager"):
		return "none"
	
	var prompt_builder = get_node("/root/PromptBuilder")
	var target_scene = prompt_builder.get_scene_id_by_index(goto_index)
	
	if target_scene == "":
		print("ChatDialog: 无效的goto索引: ", goto_index)
		ai_service.clear_goto_field()
		return "none"
	
	if not _is_valid_scene(target_scene):
		print("ChatDialog: goto场景 '%s' 不合法，忽略" % target_scene)
		ai_service.clear_goto_field()
		return "none"
	
	var save_mgr = get_node("/root/SaveManager")
	var character_scene = save_mgr.get_character_scene()
	
	if target_scene == character_scene:
		print("ChatDialog: goto场景与角色当前场景相同，忽略: ", target_scene)
		ai_service.clear_goto_field()
		return "none"
	
	if not has_node("/root/EventHelpers"):
		return "immediate"
	
	var helpers = get_node("/root/EventHelpers")
	var willingness = helpers.get_willingness()
	var base_willingness = 150
	var success_chance = helpers.calculate_success_chance(base_willingness)
	
	print("ChatDialog: goto字段处理 - 回复意愿: %d, 成功率: %.2f" % [willingness, success_chance])
	
	if _is_goto_on_cooldown():
		print("ChatDialog: goto在冷却中，抛弃goto字段")
		ai_service.clear_goto_field()
		ai_service.remove_goto_from_history()
		return "discarded"
	
	var rand_value = randf()
	var is_willing = rand_value < success_chance
	
	print("ChatDialog: 随机值: %.2f, 判定: %s" % [rand_value, "愿意留下" if is_willing else "想要离开"])
	
	if is_willing:
		print("ChatDialog: 角色愿意暂时留下，暂存goto字段")
		ai_service.set_pending_goto(goto_index)
		ai_service.clear_goto_field()
		_show_goto_notification(target_scene)
		return "pending"
	else:
		print("ChatDialog: 角色想要离开，立即触发场景变化")
		_set_goto_cooldown()
		return "immediate"

func _is_valid_scene(scene_id: String) -> bool:
	var config_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(config_path):
		return false
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false
	
	var config = json.data
	return config.has(scene_id) and config[scene_id].size() > 0

func _is_goto_on_cooldown() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time < goto_cooldown_end_time

func _set_goto_cooldown():
	var current_time = Time.get_ticks_msec() / 1000.0
	goto_cooldown_end_time = current_time + GOTO_COOLDOWN_DURATION
	print("ChatDialog: 设置goto冷却时间，将在 %.1f 秒后解除" % GOTO_COOLDOWN_DURATION)

func _get_scene_name(scene_id: String) -> String:
	var scenes_path = "res://config/scenes.json"
	if not FileAccess.file_exists(scenes_path):
		return scene_id
	
	var file = FileAccess.open(scenes_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return scene_id
	
	var scenes_config = json.data
	if not scenes_config.has("scenes"):
		return scene_id
	
	if scenes_config.scenes.has(scene_id) and scenes_config.scenes[scene_id].has("name"):
		return scenes_config.scenes[scene_id].name
	
	return scene_id

func _show_goto_notification(target_scene: String):
	var character_name = app_config.get("character_name", "角色")
	var scene_name = _get_scene_name(target_scene)
	var notification_text = "%s将前往%s" % [character_name, scene_name]
	
	if goto_notification_label != null:
		goto_notification_label.queue_free()
		goto_notification_label = null
	
	goto_notification_label = Label.new()
	goto_notification_label.name = "GotoNotificationLabel"
	goto_notification_label.text = notification_text
	goto_notification_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	goto_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goto_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	goto_notification_label.modulate.a = 0.0
	
	goto_notification_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	goto_notification_label.offset_left = -200
	goto_notification_label.offset_top = -30
	goto_notification_label.offset_right = -10
	goto_notification_label.offset_bottom = -10
	
	add_child(goto_notification_label)
	
	var fade_in = create_tween()
	fade_in.tween_property(goto_notification_label, "modulate:a", 0.8, 0.5)
	
	print("ChatDialog: 显示goto提示 - %s" % notification_text)

func _hide_goto_notification():
	if goto_notification_label == null:
		return
	
	var fade_out = create_tween()
	fade_out.tween_property(goto_notification_label, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	
	goto_notification_label.queue_free()
	goto_notification_label = null
	print("ChatDialog: 隐藏goto提示")

func _handle_reply_refusal(user_message: String, refusal_message: String):
	typing_manager.start_stream()
	typing_manager.add_stream_content("……")
	typing_manager.end_stream()
	
	while not typing_manager.is_showing_sentence:
		await get_tree().process_frame
	
	await _show_refusal_message(refusal_message)
	
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.add_to_history("user", user_message)
		ai_service.add_to_history("assistant", "……")

func _handle_empty_msg_response(message: String):
	typing_manager.start_stream()
	typing_manager.add_stream_content("……")
	typing_manager.end_stream()
	
	while not typing_manager.is_showing_sentence:
		await get_tree().process_frame
	
	await _show_refusal_message(message)
	
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.add_to_history("assistant", "……")

func _show_refusal_message(message: String = ""):
	var character_name = app_config.get("character_name", "角色")
	var refusal_text = message if not message.is_empty() else (character_name + "似乎不想说话")
	
	var refusal_label = Label.new()
	refusal_label.name = "RefusalLabel"
	refusal_label.text = refusal_text
	refusal_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	refusal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refusal_label.modulate.a = 0.0
	
	var message_index = message_label.get_index()
	vbox.add_child(refusal_label)
	vbox.move_child(refusal_label, message_index + 1)
	
	var fade_in = create_tween()
	fade_in.tween_property(refusal_label, "modulate:a", 1.0, 0.3)
	await fade_in.finished
	
	await get_tree().create_timer(2.0).timeout
	
	var fade_out = create_tween()
	fade_out.tween_property(refusal_label, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	
	refusal_label.queue_free()

func _on_history_button_pressed():
	history_manager.toggle_history()
