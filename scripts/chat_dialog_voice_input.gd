extends Node

# 语音输入模块
# 负责录音、音频处理和STT转换

signal recording_started()
signal recording_stopped()
signal transcription_received(text: String)
signal transcription_error(error: String)

var parent_dialog: Panel
var mic_button: Button
var input_field: LineEdit

# 录音状态
var is_recording: bool = false
var recording_bus_index: int = -1
var capture_effect: AudioEffectCapture
var mic_player: AudioStreamPlayer
var mic_stream: AudioStreamMicrophone
var recording_buffer: PackedVector2Array = PackedVector2Array()

# 可视化
var mic_base_icon: Texture2D
var mic_wave_image: Image
var mic_wave_texture: ImageTexture
var mic_wave_bars: int = 32
var mic_wave_size: Vector2i = Vector2i(40, 40)
var mic_wave_history: Array = []

# 设备兼容性
var is_voice_available: bool = false
var device_channel_count: int = 0

func setup(dialog: Panel, mic_btn: Button, input_fld: LineEdit):
	parent_dialog = dialog
	mic_button = mic_btn
	input_field = input_fld
	
	# 加载图标
	mic_base_icon = load("res://assets/images/chat/microphone.svg")
	if mic_base_icon and mic_button:
		mic_button.icon = mic_base_icon
	
	# 检查设备兼容性
	_check_device_compatibility()
	
	# 连接AI服务信号
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.stt_result.connect(_on_stt_result)
		ai_service.stt_error.connect(_on_stt_error)

func _check_device_compatibility():
	"""检查设备音频兼容性"""
	# 检查麦克风设备
	var devices = AudioServer.get_input_device_list()
	if devices.size() == 0:
		print("语音输入: 未检测到音频输入设备")
		is_voice_available = false
		if mic_button:
			mic_button.tooltip_text = "语音输入（未检测到麦克风）"
			mic_button.disabled = true
		return
	
	# 尝试获取默认设备的通道数
	var default_device = AudioServer.get_input_device()
	print("语音输入: 默认输入设备 - ", default_device)
	
	# 默认假设立体声
	device_channel_count = 2
	
	# 在 Windows 上，检查是否为单声道设备
	if OS.get_name() == "Windows":
		# Windows WASAPI 要求设备必须是单声道或立体声
		# 如果设备不支持，我们需要在录音后进行转换
		print("语音输入: Windows 平台，将在录音后进行音频格式转换")
	
	is_voice_available = true
	if mic_button:
		mic_button.tooltip_text = "语音输入"
		mic_button.disabled = false
	
	print("语音输入: 设备兼容性检查完成，可用: ", is_voice_available)

func is_available() -> bool:
	"""语音输入是否可用"""
	return is_voice_available

func set_visible(visible: bool):
	"""设置语音输入按钮可见性"""
	if mic_button:
		mic_button.visible = visible

func start_recording():
	"""开始录音"""
	if not is_voice_available:
		print("语音输入不可用")
		return
	
	if is_recording:
		print("已在录音中")
		return
	
	# 初始化录音总线
	if recording_bus_index == -1:
		var count = AudioServer.get_bus_count()
		AudioServer.add_bus(count)
		recording_bus_index = count
		AudioServer.set_bus_name(recording_bus_index, "Record")
		
		# 添加捕获效果
		capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(recording_bus_index, capture_effect, 0)
		
		# 静音此总线（避免回声）
		AudioServer.set_bus_mute(recording_bus_index, true)
	
	# 创建麦克风播放器
	if not mic_player:
		mic_player = AudioStreamPlayer.new()
		parent_dialog.add_child(mic_player)
		mic_player.bus = AudioServer.get_bus_name(recording_bus_index)
	
	# 创建麦克风流
	mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	
	# 开始播放（实际上是开始捕获）
	mic_player.play()
	
	# 清空缓冲区
	recording_buffer.clear()
	mic_wave_history.clear()
	is_recording = true
	
	# 更新按钮外观
	if mic_button:
		mic_button.modulate = Color(1.0, 0.2, 0.2, 1.0)
	
	recording_started.emit()
	print("语音输入: 开始录音")

func stop_recording():
	"""停止录音并发送到STT"""
	if not is_recording:
		return
	
	is_recording = false
	
	# 停止播放
	if mic_player and mic_player.playing:
		mic_player.stop()
	
	# 恢复按钮外观
	if mic_button:
		mic_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if mic_base_icon:
			mic_button.icon = mic_base_icon
	
	recording_stopped.emit()
	
	# 检查录音数据
	if recording_buffer.size() == 0:
		print("语音输入: 录音缓冲为空")
		transcription_error.emit("未录制到音频数据")
		return
	
	# 转换为WAV格式
	var wav_bytes = _frames_to_wav_bytes(recording_buffer, AudioServer.get_mix_rate())
	recording_buffer.clear()
	
	# 保存到本地（用于调试）
	DirAccess.make_dir_recursive_absolute("user://speech")
	var wav_path = "user://speech/last_recording.wav"
	var f = FileAccess.open(wav_path, FileAccess.WRITE)
	if f:
		f.store_buffer(wav_bytes)
		f.close()
		print("语音输入: 录音已保存 - ", wav_path, " (", wav_bytes.size(), " 字节)")
	
	# 发送到STT服务
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.transcribe_audio(wav_bytes, "recording.wav")
		print("语音输入: 已发送到STT服务")

func _process(_delta: float):
	"""处理录音数据和可视化"""
	if not is_recording or not capture_effect:
		return
	
	var chunk = 1024
	while capture_effect.can_get_buffer(chunk):
		var buf = capture_effect.get_buffer(chunk)
		if buf.size() > 0:
			recording_buffer.append_array(buf)
			
			# 计算音量用于可视化
			var lvl = _compute_rms(buf)
			mic_wave_history.append(lvl)
			if mic_wave_history.size() > mic_wave_bars:
				mic_wave_history.pop_front()
			
			_update_mic_wave_icon()

func _compute_rms(buf: PackedVector2Array) -> float:
	"""计算音频RMS值（音量）"""
	if buf.size() == 0:
		return 0.0
	
	var acc := 0.0
	for v in buf:
		var m = (v.x + v.y) * 0.5
		acc += m * m
	
	var rms = sqrt(acc / float(buf.size()))
	return clamp(rms, 0.0, 1.0)

func _ensure_mic_wave_resources():
	"""确保可视化资源已创建"""
	if mic_wave_image == null:
		mic_wave_image = Image.create(mic_wave_size.x, mic_wave_size.y, false, Image.FORMAT_RGBA8)
	if mic_wave_texture == null:
		mic_wave_texture = ImageTexture.create_from_image(mic_wave_image)

func _update_mic_wave_icon():
	"""更新麦克风按钮的波形图标"""
	if not mic_button or not is_recording:
		return
	
	_ensure_mic_wave_resources()
	
	# 清空图像
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
		
		# 绘制柱状图
		for xx in range(x, min(x + bar_w, w)):
			for yy in range(y0, h):
				mic_wave_image.set_pixel(xx, yy, Color(0.2, 0.7, 1.0, 1.0))
		
		x += bar_w + gap
		if x >= w:
			break
	
	# 更新纹理
	mic_wave_texture.update(mic_wave_image)
	mic_button.icon = mic_wave_texture

func _frames_to_wav_bytes(frames: PackedVector2Array, sample_rate: int) -> PackedByteArray:
	"""将音频帧转换为WAV格式字节数组（16kHz单声道）"""
	var target_rate = 16000
	var target_channels = 1
	
	# 转换为单声道
	var mono_samples: Array = []
	mono_samples.resize(frames.size())
	for i in range(frames.size()):
		var f = frames[i]
		# 混合左右声道
		mono_samples[i] = clamp((f.x + f.y) * 0.5, -1.0, 1.0)
	
	# 重采样到目标采样率
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
	
	# 转换为16位PCM
	var data_bytes = PackedByteArray()
	data_bytes.resize(resampled.size() * 2)
	var idx = 0
	for v in resampled:
		var s = int(clamp(float(v), -1.0, 1.0) * 32767.0)
		data_bytes[idx] = s & 0xFF
		data_bytes[idx + 1] = (s >> 8) & 0xFF
		idx += 2
	
	# 构建WAV头
	var bits_per_sample = 16
	var byte_rate = target_rate * target_channels * int(bits_per_sample / 8)
	var block_align = target_channels * int(bits_per_sample / 8)
	
	var header = PackedByteArray()
	header.append_array("RIFF".to_utf8_buffer())
	var total_size = 36 + data_bytes.size()
	header.append_array(_u32le(total_size))
	header.append_array("WAVE".to_utf8_buffer())
	header.append_array("fmt ".to_utf8_buffer())
	header.append_array(_u32le(16))  # fmt chunk size
	header.append_array(_u16le(1))   # PCM format
	header.append_array(_u16le(target_channels))
	header.append_array(_u32le(target_rate))
	header.append_array(_u32le(byte_rate))
	header.append_array(_u16le(block_align))
	header.append_array(_u16le(bits_per_sample))
	header.append_array("data".to_utf8_buffer())
	header.append_array(_u32le(data_bytes.size()))
	
	# 合并头和数据
	var wav = PackedByteArray()
	wav.append_array(header)
	wav.append_array(data_bytes)
	return wav

func _u16le(n: int) -> PackedByteArray:
	"""16位小端序"""
	var a = PackedByteArray()
	a.resize(2)
	a[0] = n & 0xFF
	a[1] = (n >> 8) & 0xFF
	return a

func _u32le(n: int) -> PackedByteArray:
	"""32位小端序"""
	var a = PackedByteArray()
	a.resize(4)
	a[0] = n & 0xFF
	a[1] = (n >> 8) & 0xFF
	a[2] = (n >> 16) & 0xFF
	a[3] = (n >> 24) & 0xFF
	return a

func _on_stt_result(text: String):
	"""STT转换成功"""
	if input_field:
		var prefix = " " if not input_field.text.is_empty() else ""
		input_field.text += prefix + text
		input_field.grab_focus()
	
	transcription_received.emit(text)
	print("语音输入: 转换成功 - ", text)

func _on_stt_error(err: String):
	"""STT转换失败"""
	transcription_error.emit(err)
	print("语音输入: STT错误 - ", err)
