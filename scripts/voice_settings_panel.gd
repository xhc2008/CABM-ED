extends Panel

# 语音设置面板

@onready var close_button = $MarginContainer/VBoxContainer/TitleContainer/CloseButton
@onready var enable_checkbox = $MarginContainer/VBoxContainer/EnableContainer/EnableCheckBox
@onready var volume_slider = $MarginContainer/VBoxContainer/VolumeContainer/VolumeSlider
@onready var volume_value_label = $MarginContainer/VBoxContainer/VolumeContainer/VolumeValueLabel
@onready var status_label = $MarginContainer/VBoxContainer/StatusLabel

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	enable_checkbox.toggled.connect(_on_enable_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	# 加载当前设置
	_load_settings()

func _load_settings():
	"""加载当前TTS设置"""
	if not has_node("/root/TTSService"):
		status_label.text = "TTS服务未加载"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return
	
	var tts = get_node("/root/TTSService")
	
	enable_checkbox.button_pressed = tts.is_enabled
	volume_slider.value = tts.volume
	_update_volume_label(tts.volume)
	
	# 检查配置状态
	if tts.api_key.is_empty():
		status_label.text = "⚠ 请在AI配置中设置TTS密钥"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif tts.voice_uri.is_empty():
		status_label.text = "⏳ 正在准备TTS..."
		status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		# 连接voice_ready信号
		if not tts.voice_ready.is_connected(_on_voice_ready):
			tts.voice_ready.connect(_on_voice_ready)
	else:
		status_label.text = "✓ TTS已准备好"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _on_close_pressed():
	"""关闭面板"""
	queue_free()

func _on_enable_toggled(enabled: bool):
	"""启用/禁用TTS"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	tts.set_enabled(enabled)
	
	if enabled:
		status_label.text = "✓ TTS已启用"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "TTS已禁用"
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _on_volume_changed(value: float):
	"""音量改变"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	tts.set_volume(value)
	_update_volume_label(value)

func _update_volume_label(value: float):
	"""更新音量显示"""
	volume_value_label.text = "%d%%" % int(value * 100)

func _on_voice_ready(_voice_uri: String):
	"""声音准备完成"""
	status_label.text = "✓ TTS已准备好"
	status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
