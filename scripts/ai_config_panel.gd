extends Panel

# AI 配置面板 - 支持快速配置和详细配置

@onready var close_button = $MarginContainer/VBoxContainer/TitleContainer/CloseButton
@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer

# 快速配置
@onready var quick_key_input = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / VBoxContainer / KeyInput
@onready var quick_save_button = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / VBoxContainer / SaveButton
@onready var quick_status_label = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / VBoxContainer / StatusLabel

# 详细配置
@onready var chat_model_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / ChatModelInput
@onready var chat_base_url_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / ChatBaseURLInput
@onready var chat_key_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / ChatKeyInput
@onready var summary_model_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / SummaryModelInput
@onready var summary_base_url_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / SummaryBaseURLInput
@onready var summary_key_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / SummaryKeyInput
@onready var tts_model_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / TTSModelInput
@onready var tts_base_url_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / TTSBaseURLInput
@onready var tts_key_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / TTSKeyInput
@onready var detail_save_button = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / DetailSaveButton
@onready var detail_status_label = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / DetailStatusLabel

# 声音设置
@onready var voice_enable_checkbox = $MarginContainer/VBoxContainer/TabContainer / 声音设置 / VBoxContainer / EnableContainer / EnableCheckBox
@onready var voice_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 声音设置 / VBoxContainer / VolumeContainer / VolumeSlider
@onready var voice_volume_label = $MarginContainer/VBoxContainer/TabContainer / 声音设置 / VBoxContainer / VolumeContainer / VolumeValueLabel
@onready var voice_status_label = $MarginContainer/VBoxContainer/TabContainer / 声音设置 / VBoxContainer / StatusLabel

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	quick_save_button.pressed.connect(_on_quick_save_pressed)
	detail_save_button.pressed.connect(_on_detail_save_pressed)
	voice_enable_checkbox.toggled.connect(_on_voice_enable_toggled)
	voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	
	# 加载现有配置
	_load_existing_config()
	_load_voice_settings()

func _load_existing_config():
	"""加载现有的AI配置"""
	var config_path = "user://ai_keys.json"
	
	if not FileAccess.file_exists(config_path):
		# 尝试从旧的api_keys.json迁移
		_migrate_old_config()
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	
	var config = json.data
	
	# 加载到快速配置（如果是简单模式）
	if config.has("mode") and config.mode == "simple":
		if config.has("api_key"):
			quick_key_input.text = config.api_key
			_update_quick_status(true, _mask_key(config.api_key))
	
	# 加载到详细配置
	if config.has("chat_model"):
		var chat = config.chat_model
		chat_model_input.text = chat.get("model", "")
		chat_base_url_input.text = chat.get("base_url", "")
		chat_key_input.text = chat.get("api_key", "")
	
	if config.has("summary_model"):
		var summary = config.summary_model
		summary_model_input.text = summary.get("model", "")
		summary_base_url_input.text = summary.get("base_url", "")
		summary_key_input.text = summary.get("api_key", "")
	
	if config.has("tts_model"):
		var tts = config.tts_model
		tts_model_input.text = tts.get("model", "")
		tts_base_url_input.text = tts.get("base_url", "")
		tts_key_input.text = tts.get("api_key", "")

func _migrate_old_config():
	"""从旧的api_keys.json迁移配置"""
	var old_path = "user://api_keys.json"
	if not FileAccess.file_exists(old_path):
		return
	
	var file = FileAccess.open(old_path, FileAccess.READ)
	if file == null:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	
	var old_config = json.data
	if old_config.has("openai_api_key"):
		quick_key_input.text = old_config.openai_api_key
		_update_quick_status(true, _mask_key(old_config.openai_api_key))

func _on_close_pressed():
	"""关闭面板"""
	queue_free()

func _on_quick_save_pressed():
	"""保存快速配置"""
	var api_key = quick_key_input.text.strip_edges()
	
	if api_key.is_empty():
		_update_quick_status(false, "密钥不能为空")
		return
	
	# 保存简单模式配置
	var config = {
		"mode": "simple",
		"api_key": api_key
	}
	
	if _save_config(config):
		_update_quick_status(true, "已保存: " + _mask_key(api_key))
		_reload_ai_service()
		_reload_tts_service() # 重新加载TTS服务
		_load_voice_settings() # 刷新声音设置显示
	else:
		_update_quick_status(false, "保存失败")

func _on_detail_save_pressed():
	"""保存详细配置"""
	var chat_model = chat_model_input.text.strip_edges()
	var chat_base_url = chat_base_url_input.text.strip_edges()
	var chat_key = chat_key_input.text.strip_edges()
	var summary_model = summary_model_input.text.strip_edges()
	var summary_base_url = summary_base_url_input.text.strip_edges()
	var summary_key = summary_key_input.text.strip_edges()
	var tts_model = tts_model_input.text.strip_edges()
	var tts_base_url = tts_base_url_input.text.strip_edges()
	var tts_key = tts_key_input.text.strip_edges()
	
	# 验证必填字段
	if chat_model.is_empty() or chat_base_url.is_empty() or chat_key.is_empty():
		_update_detail_status(false, "对话模型配置不完整")
		return
	
	if summary_model.is_empty() or summary_base_url.is_empty() or summary_key.is_empty():
		_update_detail_status(false, "总结模型配置不完整")
		return
	
	# 保存详细模式配置
	var config = {
		"mode": "detailed",
		"chat_model": {
			"model": chat_model,
			"base_url": chat_base_url,
			"api_key": chat_key
		},
		"summary_model": {
			"model": summary_model,
			"base_url": summary_base_url,
			"api_key": summary_key
		}
	}
	
	# TTS配置是可选的
	if not tts_model.is_empty() and not tts_base_url.is_empty() and not tts_key.is_empty():
		config["tts_model"] = {
			"model": tts_model,
			"base_url": tts_base_url,
			"api_key": tts_key
		}
	
	if _save_config(config):
		_update_detail_status(true, "配置已保存")
		_reload_ai_service()
		_reload_tts_service()
	else:
		_update_detail_status(false, "保存失败")

func _save_config(config: Dictionary) -> bool:
	"""保存配置到文件"""
	var config_path = "user://ai_keys.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	
	if file == null:
		return false
	
	file.store_string(JSON.stringify(config, "\t"))
	file.close()
	
	print("AI配置已保存")
	return true

func _reload_ai_service():
	"""重新加载AI服务"""
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service._load_api_key()
		print("AI服务已重新加载配置")

func _reload_tts_service():
	"""重新加载TTS服务"""
	if has_node("/root/TTSService"):
		var tts_service = get_node("/root/TTSService")
		tts_service._load_tts_settings()
		print("TTS服务已重新加载配置")

# === 声音设置相关 ===

func _load_voice_settings():
	"""加载声音设置"""
	if not has_node("/root/TTSService"):
		voice_status_label.text = "TTS服务未加载"
		voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return
	
	var tts = get_node("/root/TTSService")
	
	voice_enable_checkbox.button_pressed = tts.is_enabled
	voice_volume_slider.value = tts.volume
	_update_voice_volume_label(tts.volume)
	
	# 连接信号（如果还没连接）
	if not tts.voice_ready.is_connected(_on_voice_ready):
		tts.voice_ready.connect(_on_voice_ready)
	if not tts.tts_error.is_connected(_on_tts_error):
		tts.tts_error.connect(_on_tts_error)
	
	# 检查配置状态
	if not tts.is_enabled:
		# 未启用
		voice_status_label.text = "TTS已禁用"
		voice_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif tts.api_key.is_empty():
		# 已启用但API密钥未配置
		voice_status_label.text = "⚠ 请先配置API密钥"
		voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif tts.voice_uri.is_empty():
		# 已启用，有密钥，但声音URI未准备好
		voice_status_label.text = "⏳ 正在准备声音..."
		voice_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	else:
		# 已启用且已就绪
		voice_status_label.text = "✓ TTS已就绪"
		voice_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _on_voice_enable_toggled(enabled: bool):
	"""启用/禁用TTS"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	tts.set_enabled(enabled)
	
	if enabled:
		voice_status_label.text = "✓ TTS已启用"
		voice_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		# 如果voice_uri为空，会自动上传
		if tts.voice_uri.is_empty():
			voice_status_label.text = "⏳ 正在上传参考音频..."
			voice_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	else:
		voice_status_label.text = "TTS已禁用"
		voice_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _on_voice_volume_changed(value: float):
	"""音量改变"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	tts.set_volume(value)
	_update_voice_volume_label(value)

func _update_voice_volume_label(value: float):
	"""更新音量显示"""
	voice_volume_label.text = "%d%%" % int(value * 100)

func _on_voice_ready(_voice_uri: String):
	"""声音准备完成"""
	voice_status_label.text = "✓ TTS已就绪"
	voice_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _on_tts_error(error_message: String):
	"""TTS错误"""
	voice_status_label.text = "✗ " + error_message
	voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	push_error("TTS错误: " + error_message)
	voice_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _mask_key(key: String) -> String:
	"""遮蔽密钥显示"""
	if key.length() <= 10:
		return "***"
	return key.substr(0, 7) + "..." + key.substr(key.length() - 4)

func _update_quick_status(success: bool, message: String):
	"""更新快速配置状态"""
	quick_status_label.text = ("✓ " if success else "✗ ") + message
	quick_status_label.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.3) if success else Color(1.0, 0.3, 0.3))

func _update_detail_status(success: bool, message: String):
	"""更新详细配置状态"""
	detail_status_label.text = ("✓ " if success else "✗ ") + message
	detail_status_label.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.3) if success else Color(1.0, 0.3, 0.3))
