# res://scripts/VoiceInput.gd
# ✅ 专为 Godot 4.5.stable 优化：AudioEffectCapture + Record 总线
extends Node

signal recording_started()
signal recording_stopped()
signal transcription_received(text: String)
signal transcription_error(error: String)

var parent_dialog: Panel
var mic_button: Button
var input_field: LineEdit

# ✅ 关键：类型必须是 AudioEffectCapture
var is_recording: bool = false
var capture_bus_index: int = -1
var capture_effect: AudioEffectCapture  # 👈 正确类型！
var recording_buffer: PackedVector2Array = PackedVector2Array()

# 可视化（不变）
var mic_base_icon: Texture2D
var mic_wave_image: Image
var mic_wave_texture: ImageTexture
var mic_wave_bars: int = 32
var mic_wave_size: Vector2i = Vector2i(40, 40)
var mic_wave_history: Array = []

var is_voice_available: bool = false

func setup(dialog: Panel, mic_btn: Button, input_fld: LineEdit):
	parent_dialog = dialog
	mic_button = mic_btn
	input_field = input_fld
	
	mic_base_icon = load("res://assets/images/chat/microphone.svg")
	if mic_base_icon and mic_button:
		mic_button.icon = mic_base_icon
	
	_check_device_compatibility()
	
	if has_node("/root/AIService"):
		var ai = get_node("/root/AIService")
		if ai.has_signal("stt_result"):
			ai.stt_result.connect(_on_stt_result)
		if ai.has_signal("stt_error"):
			ai.stt_error.connect(_on_stt_error)

func _check_device_compatibility():
	var devices = AudioServer.get_input_device_list()
	is_voice_available = devices.size() > 0
	if not is_voice_available:
		if mic_button:
			mic_button.disabled = true
			mic_button.tooltip_text = "语音输入（无麦克风）"

func start_recording():
	if not is_voice_available or is_recording:
		return

	# ✅ 必须是 "Record" 总线（Godot 4.5 唯一支持录音的总线名）
	var bus_idx = AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		push_error("❌ 未找到 'Record' 总线！请在 Project Settings → Audio → Buses 中添加名为 'Record' 的总线")
		return

	capture_bus_index = bus_idx
	AudioServer.set_bus_mute(bus_idx, false)
	AudioServer.set_bus_volume_db(bus_idx, 0.0)

	# ✅ 必须是 AudioEffectCapture
	capture_effect = AudioEffectCapture.new()
	while AudioServer.get_bus_effect_count(bus_idx) > 0:
		AudioServer.remove_bus_effect(bus_idx, 0)
	AudioServer.add_bus_effect(bus_idx, capture_effect, 0)

	recording_buffer.clear()
	mic_wave_history.clear()
	is_recording = true

	if mic_button:
		mic_button.modulate = Color(1, 0.2, 0.2, 1)

	print("🎙️ 开始录音（总线: Record）")
	recording_started.emit()

func stop_recording():
	if not is_recording:
		return

	is_recording = false

	if capture_bus_index != -1:
		AudioServer.remove_bus_effect(capture_bus_index, 0)
	if mic_button:
		mic_button.modulate = Color.WHITE
		if mic_base_icon:
			mic_button.icon = mic_base_icon

	recording_stopped.emit()

	if recording_buffer.is_empty():
		transcription_error.emit("录音为空")
		return

	var wav = _frames_to_wav_bytes(recording_buffer, AudioServer.get_mix_rate())
	recording_buffer.clear()

	# 保存调试
	DirAccess.make_dir_recursive_absolute("user://speech")
	var f = FileAccess.open("user://speech/last_recording.wav", FileAccess.WRITE)
	if f:
		f.store_buffer(wav)
		f.close()
		print("💾 录音已保存 (%d 字节)" % wav.size())

	if has_node("/root/AIService"):
		get_node("/root/AIService").transcribe_audio(wav, "recording.wav")

func _process(_delta: float):
	if not is_recording or not capture_effect:
		return

	# ✅ AudioEffectCapture 支持这些方法
	var chunk = 512
	while capture_effect.can_get_buffer(chunk):
		var buf = capture_effect.get_buffer(chunk)
		if buf.size() == 0:
			break
		recording_buffer.append_array(buf)

		var lvl = _compute_rms(buf)
		mic_wave_history.append(lvl)
		if mic_wave_history.size() > mic_wave_bars:
			mic_wave_history.pop_front()
		_update_mic_wave_icon()

# --- 以下辅助函数保持不变（已适配 Stereo → Mono） ---
func _compute_rms(buf: PackedVector2Array) -> float:
	if buf.is_empty(): return 0.0
	var acc = 0.0
	for v in buf:
		var m = (v.x + v.y) * 0.5  # Stereo → Mono
		acc += m * m
	return sqrt(acc / buf.size())

func _update_mic_wave_icon():
	# （保持原样，已验证无误）
	if not mic_button or not is_recording: return
	if mic_wave_image == null:
		mic_wave_image = Image.create(mic_wave_size.x, mic_wave_size.y, false, Image.FORMAT_RGBA8)
	if mic_wave_texture == null:
		mic_wave_texture = ImageTexture.create_from_image(mic_wave_image)
	mic_wave_image.fill(Color.TRANSPARENT)
	
	var w = mic_wave_size.x; var h = mic_wave_size.y
	var bar_w = max(1, int(w / (mic_wave_bars * 1.5))); var gap = max(1, bar_w / 2)
	var x = 0
	for i in range(mic_wave_bars):
		var idx = max(0, mic_wave_history.size() - mic_wave_bars + i)
		var lvl = mic_wave_history[idx] if idx < mic_wave_history.size() else 0.0
		var bar_h = int(clamp(lvl, 0, 1) * h)
		var y0 = h - bar_h
		for xx in range(x, min(x + bar_w, w)):
			for yy in range(y0, h):
				mic_wave_image.set_pixel(xx, yy, Color(0.2, 0.7, 1.0, 1.0))
		x += bar_w + gap
		if x >= w: break
	mic_wave_texture.update(mic_wave_image)
	mic_button.icon = mic_wave_texture

func _frames_to_wav_bytes(frames: PackedVector2Array, sample_rate: int) -> PackedByteArray:
	# （保持原样，已优化）
	var mono = []
	for v in frames:
		mono.append(clamp((v.x + v.y) * 0.5, -1, 1))
	
	var target_rate = 16000
	var target_len = int(ceil(mono.size() * target_rate / sample_rate))
	var resampled = []
	if mono.size() <= 1:
		resampled = [0.0] * target_len
	else:
		for t in range(target_len):
			var pos = float(t) * sample_rate / target_rate
			var i0 = int(floor(pos)); var i1 = min(i0 + 1, mono.size() - 1)
			var alpha = pos - i0
			resampled.append(mono[i0] * (1 - alpha) + mono[i1] * alpha)
	
	var data = PackedByteArray()
	for v in resampled:
		var s = int(clamp(v, -1, 1) * 32767)
		data.append(s & 0xFF)
		data.append((s >> 8) & 0xFF)
	
	# WAV header
	var riff = "RIFF".to_utf8_buffer()
	var wave = "WAVE".to_utf8_buffer()
	var fmt = "fmt ".to_utf8_buffer()
	var data_hdr = "data".to_utf8_buffer()
	var header = riff + _u32le(36 + data.size()) + wave + fmt + _u32le(16) + _u16le(1) + _u16le(1) + _u32le(target_rate) + _u32le(target_rate * 2) + _u16le(2) + _u16le(16) + data_hdr + _u32le(data.size())
	return header + data

func _u16le(n: int) -> PackedByteArray: return PackedByteArray([n & 0xFF, (n >> 8) & 0xFF])
func _u32le(n: int) -> PackedByteArray: return PackedByteArray([n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF])

func _on_stt_result(text: String):
	if input_field:
		input_field.text += (" " if not input_field.text.is_empty() else "") + text
		input_field.grab_focus()
	transcription_received.emit(text)

func _on_stt_error(err: String):
	transcription_error.emit(err)

func _exit_tree():
	if capture_bus_index != -1 and capture_effect:
		AudioServer.remove_bus_effect(capture_bus_index, 0)