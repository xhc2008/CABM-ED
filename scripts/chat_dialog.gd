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
var mic_button: Button

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

# 语音录制
var is_recording: bool = false
var recording_bus_index: int = -1
var capture_effect: AudioEffectCapture
var mic_player: AudioStreamPlayer
var mic_stream: AudioStreamMicrophone
var recording_buffer: PackedVector2Array = PackedVector2Array()
var mic_icon: Texture2D
var mic_base_icon: Texture2D
var mic_wave_image: Image
var mic_wave_texture: ImageTexture
var mic_wave_bars: int = 32
var mic_wave_size: Vector2i = Vector2i(40, 40)
var mic_wave_history: Array = []

func _ensure_ui_structure():
	"""确保UI结构正确，如果场景文件中没有InputContainer则动态创建"""
	input_container = vbox.get_node_or_null("InputContainer")
	
	if input_container != null:
		input_field = input_container.get_node_or_null("InputField")
		send_button = input_container.get_node_or_null("SendButton")
		mic_button = input_container.get_node_or_null("MicButton")
		var old_history_btn = input_container.get_node_or_null("HistoryButton")
		if old_history_btn != null:
			old_history_btn.queue_free()
		
		# 如果不存在麦克风按钮，则创建并插入到发送按钮左侧
		if mic_button == null:
			mic_button = Button.new()
			mic_button.name = "MicButton"
			mic_button.custom_minimum_size = Vector2(40, 0)
			mic_button.focus_mode = Control.FOCUS_NONE
			input_container.add_child(mic_button)
			if send_button:
				var send_index = send_button.get_index()
				input_container.move_child(mic_button, max(0, send_index))
				# 设置图标
				var icon_res: Texture2D = load("res://assets/images/chat/microphone.svg")
				if icon_res:
					mic_button.icon = icon_res
				mic_button.tooltip_text = "语音输入（不可用）"
			
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
		
		# 麦克风按钮（在发送按钮左侧）
		mic_button = Button.new()
		mic_button.name = "MicButton"
		mic_button.custom_minimum_size = Vector2(40, 0)
		mic_button.focus_mode = Control.FOCUS_NONE
		var mic_icon_tex: Texture2D = load("res://assets/images/chat/microphone.svg")
		if mic_icon_tex:
			mic_button.icon = mic_icon_tex
			mic_button.tooltip_text = "语音输入（不可用）"
		
		send_button = Button.new()
		send_button.name = "SendButton"
		send_button.text = "发送"
		send_button.custom_minimum_size = Vector2(40, 0)
		input_container.add_child(mic_button)
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
		
		mic_button = Button.new()
		mic_button.name = "MicButton"
		mic_button.custom_minimum_size = Vector2(40, 0)
		mic_button.focus_mode = Control.FOCUS_NONE
		var mic_icon_tex2: Texture2D = load("res://assets/images/chat/microphone.svg")
		if mic_icon_tex2:
			mic_button.icon = mic_icon_tex2
		mic_button.tooltip_text = "语音输入（不可用）"
		
		send_button = Button.new()
		send_button.name = "SendButton"
		send_button.text = "发送"
		send_button.custom_minimum_size = Vector2(80, 0)
		input_container.add_child(mic_button)
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
		end_button.pressed.connect(_on_history_toggle_pressed)
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)
	if mic_button:
		mic_button.pressed.connect(_on_mic_button_pressed)
		mic_base_icon = load("res://assets/images/chat/microphone.svg")
		if mic_base_icon:
			mic_button.icon = mic_base_icon
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)
		input_field.text_changed.connect(_on_input_text_changed)
		_apply_android_input_workaround_to_line_edit(input_field)
	
	_load_config()
	
	# 连接 AI 服务信号
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.chat_response_received.connect(_on_ai_response)
		ai_service.chat_response_completed.connect(_on_ai_response_completed)
		ai_service.chat_error.connect(_on_ai_error)
		ai_service.stt_result.connect(_on_stt_result)
		ai_service.stt_error.connect(_on_stt_error)
	
	# 连接事件管理器信号
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.event_completed.connect(_on_event_completed)
	
	_setup_input_mode()
	
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

func _apply_android_input_workaround_to_line_edit(le: LineEdit):
	if has_node("/root/PlatformManager"):
		var pm = get_node("/root/PlatformManager")
		if pm.is_android():
			le.context_menu_enabled = false
			le.shortcut_keys_enabled = false
			if le.has_method("set_selecting_enabled"):
				le.selecting_enabled = false

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
	typing_manager.sentence_ready_for_tts.connect(_on_sentence_ready_for_tts)
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
					  send_button, end_button)

func _load_config():
	# app_config.json已废弃，不再需要加载配置
	pass

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
	_update_action_button_state()

func show_dialog(mode: String = "passive"):
	"""显示对话框
	mode: "passive" = 用户先说（输入模式）, "active" = 角色先说（回复模式）, 
		  "called" = 被呼唤来到场景（角色先说）, "called_here" = 被呼唤但已在场景（角色先说）
	"""
	# 如果已经可见，忽略重复调用
	if visible:
		print("聊天对话框已显示，忽略重复调用")
		return
	
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
	character_name_label.text = _get_character_name()
	custom_minimum_size.y = 200.0

func hide_dialog():
	# 如果已经隐藏，忽略重复调用
	if not visible:
		print("聊天对话框已隐藏，忽略重复调用")
		return
	
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
		var character_name = _get_character_name()
		_handle_empty_msg_response(character_name + "欲言又止")
		return
	
	typing_manager.end_stream()

func _on_ai_error(error_message: String):
	"""AI 错误回调"""
	print("AI 错误: ", error_message)
	
	if error_message.contains("超时"):
		var character_name = _get_character_name()
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
	_update_action_button_state()

func _update_action_button_state():
	var has_text = not input_field.text.strip_edges().is_empty()
	if has_text:
		send_button.text = "发送"
		send_button.modulate = Color(0.2, 0.5, 1.0, 0.8)
	else:
		send_button.text = "结束"
		send_button.modulate = Color(1.0, 0.2, 0.2, 0.8)
	# 更新麦克风按钮外观
	if mic_button:
		mic_button.modulate = Color(1.0, 0.2, 0.2, 1.0) if is_recording else Color(1.0, 1.0, 1.0, 1.0)

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
			# 输入模式下长时间无操作，确保UI状态正确后再结束
			if history_manager.is_history_visible:
				await history_manager.hide_history()
			elif not is_input_mode:
				# 如果不在输入模式（例如在回复模式），先恢复到输入模式
				waiting_for_continue = false
				continue_indicator.visible = false
				await ui_manager.transition_to_input_mode()
			
			await get_tree().create_timer(0.3).timeout
			_on_end_button_pressed()

func _on_send_button_pressed():
	var text = input_field.text
	if text.strip_edges().is_empty():
		_on_end_button_pressed()
	else:
		_on_input_submitted(text)

func _on_mic_button_pressed():
	if OS.get_name() == "Windows":
		print("语音输入暂不可用：请在 Windows 录音设备的高级选项将默认格式设置为单声道后再试，或暂时关闭语音输入")
		return
	if not is_recording:
		_start_recording()
	else:
		_stop_and_send_recording()

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
	
	await ui_manager.transition_to_reply_mode(_get_character_name())
	
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

func _process(_delta: float):
	if is_recording and capture_effect:
		var chunk = 1024
		while capture_effect.can_get_buffer(chunk):
			var buf = capture_effect.get_buffer(chunk)
			if buf.size() > 0:
				recording_buffer.append_array(buf)
				var lvl = _compute_rms(buf)
				mic_wave_history.append(lvl)
				if mic_wave_history.size() > mic_wave_bars:
					mic_wave_history.pop_front()
				_update_mic_wave_icon()
	elif not is_recording and mic_button and mic_base_icon:
		if mic_button.icon != mic_base_icon:
			mic_button.icon = mic_base_icon

# 替换这部分代码
func _start_recording():
	if OS.get_name() == "Windows":
		return
	# 初始化录音总线与采集器
	if recording_bus_index == -1:
		var count = AudioServer.get_bus_count()
		AudioServer.add_bus(count)
		recording_bus_index = count
		AudioServer.set_bus_name(recording_bus_index, "Record")
		
		
		var record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(recording_bus_index, record_effect, 0)
		record_effect.set_recording_active(true)
		
		
		AudioServer.set_bus_mute(recording_bus_index, true)

	# 创建麦克风播放器并开始播放
	if not mic_player:
		mic_player = AudioStreamPlayer.new()
		add_child(mic_player)
		mic_player.bus = AudioServer.get_bus_name(recording_bus_index)

	mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	
	# 重要：先设置 stream，再播放
	mic_player.play()

	recording_buffer.clear()
	is_recording = true
	if mic_button:
		mic_button.modulate = Color(1.0, 0.2, 0.2, 1.0)
	_update_action_button_state()

func _stop_and_send_recording():
	# 停止录音
	is_recording = false
	if mic_player and mic_player.playing:
		mic_player.stop()
	# 将采集到的帧转换为wav字节
	if recording_buffer.size() == 0:
		print("录音缓冲为空，可能未启用音频输入或设备没有数据")
		if mic_button:
			mic_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_update_action_button_state()
		return
	var wav_bytes = _frames_to_wav_bytes(recording_buffer, AudioServer.get_mix_rate())
	# 清空缓冲以释放内存
	recording_buffer = PackedVector2Array()

	# 保存到本地文件，方便调试与回溯
	DirAccess.make_dir_recursive_absolute("user://speech")
	var wav_path = "user://speech/last_recording.wav"
	var f = FileAccess.open(wav_path, FileAccess.WRITE)
	if f:
		f.store_buffer(wav_bytes)
		f.close()
		print("录音已保存: ", wav_path, " (", wav_bytes.size(), " 字节)")

	# 发送到STT
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.transcribe_audio(wav_bytes, "recording.wav")

	# 恢复按钮外观
	if mic_button:
		mic_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_update_action_button_state()

func _compute_rms(buf: PackedVector2Array) -> float:
	if buf.size() == 0:
		return 0.0
	var acc := 0.0
	for v in buf:
		var m = (v.x + v.y) * 0.5
		acc += m * m
	var rms = sqrt(acc / float(buf.size()))
	return clamp(rms, 0.0, 1.0)

func _ensure_mic_wave_resources():
	if mic_wave_image == null:
		mic_wave_image = Image.create(mic_wave_size.x, mic_wave_size.y, false, Image.FORMAT_RGBA8)
	if mic_wave_texture == null:
		mic_wave_texture = ImageTexture.create_from_image(mic_wave_image)

func _update_mic_wave_icon():
	if not mic_button:
		return
	if not is_recording:
		return
	_ensure_mic_wave_resources()
	mic_wave_image.fill(Color(0, 0, 0, 0))
	var w = mic_wave_size.x
	var h = mic_wave_size.y
	var bars = mic_wave_bars
	var bar_w = max(1, int(floor(float(w) / (bars * 1.5))))
	var gap = max(1, int(bar_w / 2))
	var x = 0
	var hist_size = mic_wave_history.size()
	for i in range(bars):
		var idx = max(0, hist_size - bars + i)
		var lvl = 0.0
		if idx < hist_size:
			lvl = mic_wave_history[idx]
		var bar_h = int(clamp(lvl, 0.0, 1.0) * float(h))
		var y0 = h - bar_h
		for xx in range(x, min(x + bar_w, w)):
			for yy in range(y0, h):
				mic_wave_image.set_pixel(xx, yy, Color(0.2, 0.7, 1.0, 1.0))
		x += bar_w + gap
		if x >= w:
			break
	mic_wave_texture.update(mic_wave_image)
	mic_button.icon = mic_wave_texture

func _send_button_reset():
	send_button.modulate = Color(1.0, 0.2, 0.2, 0.8)
	send_button.text = "结束" if is_recording else "发送"

func _frames_to_wav_bytes(frames: PackedVector2Array, sample_rate: int) -> PackedByteArray:
	var target_rate = 16000
	var mono_samples: Array = []
	mono_samples.resize(frames.size())
	for i in range(frames.size()):
		var f = frames[i]
		mono_samples[i] = clamp((f.x + f.y) * 0.5, -1.0, 1.0)

	var target_len = int(ceil(float(mono_samples.size()) * float(target_rate) / float(sample_rate)))
	var resampled: Array = []
	resampled.resize(target_len)
	if mono_samples.size() <= 1:
		resampled.fill(0.0)
	else:
		for t in range(target_len):
			var src_pos = float(t) * float(sample_rate) / float(target_rate)
			var i0 = int(floor(src_pos))
			var i1 = min(i0 + 1, mono_samples.size() - 1)
			var alpha = src_pos - float(i0)
			var v = mono_samples[i0] * (1.0 - alpha) + mono_samples[i1] * alpha
			resampled[t] = v

	var channels = 1
	var bits_per_sample = 16
	var byte_rate = target_rate * channels * (bits_per_sample / 8)
	var block_align = channels * (bits_per_sample / 8)
	var data_bytes = PackedByteArray()
	data_bytes.resize(resampled.size() * 2)
	var idx = 0
	for v in resampled:
		var s = int(clamp(v, -1.0, 1.0) * 32767.0)
		data_bytes[idx] = s & 0xFF
		data_bytes[idx+1] = (s >> 8) & 0xFF
		idx += 2

	var header = PackedByteArray()
	header.append_array("RIFF".to_utf8_buffer())
	var total_size = 36 + data_bytes.size()
	header.append_array(_u32le(total_size))
	header.append_array("WAVE".to_utf8_buffer())
	header.append_array("fmt ".to_utf8_buffer())
	header.append_array(_u32le(16))
	header.append_array(_u16le(1))
	header.append_array(_u16le(channels))
	header.append_array(_u32le(target_rate))
	header.append_array(_u32le(byte_rate))
	header.append_array(_u16le(block_align))
	header.append_array(_u16le(bits_per_sample))
	header.append_array("data".to_utf8_buffer())
	header.append_array(_u32le(data_bytes.size()))

	var wav = PackedByteArray()
	wav.append_array(header)
	wav.append_array(data_bytes)
	return wav

func _u16le(n: int) -> PackedByteArray:
	var a = PackedByteArray()
	a.resize(2)
	a[0] = n & 0xFF
	a[1] = (n >> 8) & 0xFF
	return a

func _u32le(n: int) -> PackedByteArray:
	var a = PackedByteArray()
	a.resize(4)
	a[0] = n & 0xFF
	a[1] = (n >> 8) & 0xFF
	a[2] = (n >> 16) & 0xFF
	a[3] = (n >> 24) & 0xFF
	return a

func _on_stt_result(text: String):
	if input_field:
		var prefix = " " if not input_field.text.is_empty() else ""
		input_field.text += prefix + text
		_update_action_button_state()
		input_field.grab_focus()

func _on_stt_error(err: String):
	print("STT 错误: ", err)
	_send_button_reset()

func _on_sentence_ready_for_tts(text: String):
	"""句子准备好进行TTS处理 - 立即发送到TTS服务
	这发生在句子从流中提取时，不等待显示完成
	这样可以在用户等待时预先进行翻译和语音合成
	"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	if tts.is_enabled and not text.is_empty():
		tts.synthesize_speech(text)
		print("ChatDialog: 发送TTS（早期处理） - ", text)

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
		print("警告: 不在等待继续状态，忽略点击")
		return
	
	# 立即设置为false，防止重复触发
	waiting_for_continue = false
	input_handler.set_waiting_for_continue(false)
	ui_manager.hide_continue_indicator()
	
	if typing_manager.has_more_sentences():
		# 有更多句子，显示下一句
		var next_sentence_hash = typing_manager.show_next_sentence()
		if next_sentence_hash != "":
			print("显示句子 hash:%s" % next_sentence_hash.substr(0,8))
			# 通知 TTS 系统用户显示了新句子
			if has_node("/root/TTSService"):
				var tts = get_node("/root/TTSService")
				tts.on_new_sentence_displayed(next_sentence_hash)
				print("已通知TTS系统显示句子 hash:%s" % next_sentence_hash.substr(0,8))
	elif typing_manager.is_receiving_stream:
		# 流还在继续，但暂时没有新句子
		# 重新设置等待状态，等待新句子到来
		print("流式接收中，暂无新句子，继续等待...")
		waiting_for_continue = true
		input_handler.set_waiting_for_continue(true)
		ui_manager.show_continue_indicator()
	else:
		# 流已结束，所有句子都显示完了
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
	"""验证场景ID是否合法（同时存在于scenes.json和当前服装的配置中）"""
	# 检查scenes.json
	var scenes_path = "res://config/scenes.json"
	if not FileAccess.file_exists(scenes_path):
		print("ChatDialog: scenes.json 不存在")
		return false
	
	var scenes_file = FileAccess.open(scenes_path, FileAccess.READ)
	var scenes_json_string = scenes_file.get_as_text()
	scenes_file.close()
	
	var scenes_json = JSON.new()
	if scenes_json.parse(scenes_json_string) != OK:
		print("ChatDialog: scenes.json 解析失败")
		return false
	
	var scenes_data = scenes_json.data
	if not scenes_data.has("scenes") or not scenes_data.scenes.has(scene_id):
		print("ChatDialog: 场景 '%s' 不在 scenes.json 中" % scene_id)
		return false
	
	# 获取当前服装ID
	var costume_id = "default"
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		costume_id = save_mgr.get_costume_id()
	
	# 检查当前服装的配置文件
	var presets_path = "res://config/character_presets/%s.json" % costume_id
	if not FileAccess.file_exists(presets_path):
		print("ChatDialog: 服装配置 %s.json 不存在" % costume_id)
		return false
	
	var file = FileAccess.open(presets_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("ChatDialog: 服装配置 %s 解析错误" % costume_id)
		return false
	
	var presets_config = json.data
	if not presets_config.has(scene_id):
		print("ChatDialog: 场景 '%s' 不在服装 %s 的配置中" % [scene_id, costume_id])
		return false
	
	# 确保是数组类型（场景配置）而不是字符串（id/name/description）
	if not presets_config[scene_id] is Array:
		print("ChatDialog: 场景 '%s' 在服装 %s 中不是有效的场景配置" % [scene_id, costume_id])
		return false
	
	if presets_config[scene_id].size() == 0:
		print("ChatDialog: 场景 '%s' 在服装 %s 中没有角色预设" % [scene_id, costume_id])
		return false
	
	print("ChatDialog: 场景 '%s' 验证通过" % scene_id)
	return true

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
	var character_name = _get_character_name()
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
	var character_name = _get_character_name()
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

func _on_history_toggle_pressed():
	history_manager.toggle_history()

func _get_character_name() -> String:
	"""获取角色名称"""
	if not has_node("/root/SaveManager"):
		return "角色"
	
	var save_mgr = get_node("/root/SaveManager")
	return save_mgr.get_character_name()
