extends Panel

# AI 配置面板 - 支持快速配置和详细配置

# 配置模板
const CONFIG_TEMPLATES = {
	"free": {
		"name": "免费",
		"description": "没有语音，而且有点不太聪明的样子，但是免费",
		"chat_model": {
			"model": "Qwen/Qwen3-8B",
			"base_url": "https://api.siliconflow.cn/v1"
		},
		"summary_model": {
			"model": "Qwen/Qwen3-8B",
			"base_url": "https://api.siliconflow.cn/v1"
		},
		"tts_model": {
			"model": "",
			"base_url": "",
		}
	},
	"standard": {
		"name": "标准",
		"description": "大模型与小模型结合使用，平衡性能与价格",
		"chat_model": {
			"model": "deepseek-ai/DeepSeek-V3.2-Exp",
			"base_url": "https://api.siliconflow.cn/v1"
		},
		"summary_model": {
			"model": "Qwen/Qwen3-8B",
			"base_url": "https://api.siliconflow.cn/v1"
		},
		"tts_model": {
			"model": "FunAudioLLM/CosyVoice2-0.5B",
			"base_url": "https://api.siliconflow.cn"
		}
	}
}

@onready var close_button = $MarginContainer/VBoxContainer/TitleContainer/CloseButton
@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer

# 快速配置
@onready var quick_template_free = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / ScrollContainer / VBoxContainer / TemplateContainer / FreeButton
@onready var quick_template_standard = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / ScrollContainer / VBoxContainer / TemplateContainer / StandardButton
@onready var quick_description_label = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / ScrollContainer / VBoxContainer / DescriptionLabel
@onready var quick_key_input = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / ScrollContainer / VBoxContainer / KeyInput
@onready var quick_apply_button = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / ScrollContainer / VBoxContainer / ApplyButton
@onready var quick_status_label = $MarginContainer/VBoxContainer/TabContainer / 快速配置 / ScrollContainer / VBoxContainer / StatusLabel

var selected_template: String = "standard" # 默认选择标准模板

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

# 语音设置
@onready var voice_enable_checkbox = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / EnableContainer / EnableCheckBox
@onready var voice_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / VolumeContainer / VolumeSlider
@onready var voice_volume_label = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / VolumeContainer / VolumeValueLabel
@onready var voice_reupload_button = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / ReuploadButton
@onready var voice_status_label = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / StatusLabel

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	quick_template_free.pressed.connect(_on_template_selected.bind("free"))
	quick_template_standard.pressed.connect(_on_template_selected.bind("standard"))
	quick_apply_button.pressed.connect(_on_quick_apply_pressed)
	detail_save_button.pressed.connect(_on_detail_save_pressed)
	voice_enable_checkbox.toggled.connect(_on_voice_enable_toggled)
	voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	voice_reupload_button.pressed.connect(_on_voice_reupload_pressed)
	
	# 为模板按钮添加样式
	_style_template_buttons()
	
	# 为语音启用按钮添加样式
	_style_voice_checkbox()
	
	# 默认选择标准模板
	_on_template_selected("standard")
	
	# 加载现有配置
	_load_existing_config()
	_load_voice_settings()

func _style_template_buttons():
	"""为模板按钮添加边框样式"""
	var style_box_free = StyleBoxFlat.new()
	style_box_free.bg_color = Color(0.2, 0.2, 0.2, 0.3)
	style_box_free.border_width_left = 2
	style_box_free.border_width_top = 2
	style_box_free.border_width_right = 2
	style_box_free.border_width_bottom = 2
	style_box_free.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style_box_free.corner_radius_top_left = 5
	style_box_free.corner_radius_top_right = 5
	style_box_free.corner_radius_bottom_left = 5
	style_box_free.corner_radius_bottom_right = 5
	style_box_free.content_margin_left = 10
	style_box_free.content_margin_right = 10
	style_box_free.content_margin_top = 5
	style_box_free.content_margin_bottom = 5
	
	var style_box_free_pressed = style_box_free.duplicate()
	style_box_free_pressed.bg_color = Color(0.3, 0.5, 0.8, 0.5)
	style_box_free_pressed.border_color = Color(0.4, 0.6, 1.0, 1.0)
	
	quick_template_free.add_theme_stylebox_override("normal", style_box_free)
	quick_template_free.add_theme_stylebox_override("pressed", style_box_free_pressed)
	quick_template_free.add_theme_stylebox_override("hover", style_box_free_pressed)
	
	var style_box_standard = style_box_free.duplicate()
	var style_box_standard_pressed = style_box_free_pressed.duplicate()
	
	quick_template_standard.add_theme_stylebox_override("normal", style_box_standard)
	quick_template_standard.add_theme_stylebox_override("pressed", style_box_standard_pressed)
	quick_template_standard.add_theme_stylebox_override("hover", style_box_standard_pressed)

func _style_voice_checkbox():
	"""为语音启用复选框添加边框样式"""
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.3)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	style_box.content_margin_left = 5
	style_box.content_margin_right = 5
	style_box.content_margin_top = 5
	style_box.content_margin_bottom = 5
	
	var style_box_pressed = style_box.duplicate()
	style_box_pressed.bg_color = Color(0.3, 0.7, 0.3, 0.5)
	style_box_pressed.border_color = Color(0.4, 1.0, 0.4, 1.0)
	
	voice_enable_checkbox.add_theme_stylebox_override("normal", style_box)
	voice_enable_checkbox.add_theme_stylebox_override("pressed", style_box_pressed)
	voice_enable_checkbox.add_theme_stylebox_override("hover", style_box_pressed)

func _on_template_selected(template: String):
	"""选择配置模板"""
	selected_template = template
	_update_template_selection()

func _update_template_selection():
	"""更新模板选择的UI显示"""
	if selected_template == "custom":
		# 自定义配置：取消所有按钮选择
		quick_template_free.button_pressed = false
		quick_template_standard.button_pressed = false
		quick_description_label.text = "当前使用自定义配置"
	elif CONFIG_TEMPLATES.has(selected_template):
		# 模板配置：更新按钮状态和描述
		quick_template_free.button_pressed = (selected_template == "free")
		quick_template_standard.button_pressed = (selected_template == "standard")
		
		var template_data = CONFIG_TEMPLATES[selected_template]
		quick_description_label.text = template_data.description
	else:
		# 未知模板，默认为标准
		selected_template = "standard"
		quick_template_free.button_pressed = false
		quick_template_standard.button_pressed = true
		quick_description_label.text = CONFIG_TEMPLATES["standard"].description

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
	
	# 加载模板选择
	if config.has("template"):
		selected_template = config.template
		_update_template_selection()
	
	# 加载API密钥到快速配置
	if config.has("api_key"):
		quick_key_input.text = config.api_key
		_update_quick_status(true, "当前密钥: " + _mask_key(config.api_key))
	
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
		_update_quick_status(true, "当前密钥: " + _mask_key(old_config.openai_api_key))

func _on_close_pressed():
	"""关闭面板"""
	queue_free()

func _on_quick_apply_pressed():
	"""应用快速配置模板"""
	var api_key = quick_key_input.text.strip_edges()
	
	if api_key.is_empty():
		_update_quick_status(false, "请先输入API密钥")
		return
	
	# 获取选中的模板
	var template = CONFIG_TEMPLATES[selected_template]
	
	# 构建配置，将模板内容填入详细配置
	var config = {
		"template": selected_template, # 记录使用的模板
		"api_key": api_key,
		"chat_model": {
			"model": template.chat_model.model,
			"base_url": template.chat_model.base_url,
			"api_key": api_key
		},
		"summary_model": {
			"model": template.summary_model.model,
			"base_url": template.summary_model.base_url,
			"api_key": api_key
		},
		"tts_model": {
			"model": template.tts_model.model,
			"base_url": template.tts_model.base_url,
			"api_key": api_key
		}
	}
	
	if _save_config(config):
		_update_quick_status(true, "已应用「%s」配置" % template.name)
		# 同步更新详细配置页面（在重新加载服务之前）
		_sync_to_detail_config(config)
		_reload_ai_service()
		_reload_tts_service()
		_load_voice_settings()
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
	
	# 统一保存格式（不再区分mode）
	var config = {
		"template": "custom", # 标记为自定义配置
		"api_key": chat_key, # 保存一个通用的api_key用于快速配置显示
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
	
	# TTS配置是可选的，但始终保存配置块（即使为空）
	config["tts_model"] = {
		"model": tts_model,
		"base_url": tts_base_url,
		"api_key": tts_key
	}
	
	if _save_config(config):
		_update_detail_status(true, "配置已保存")
		# 更新快速配置页面显示为自定义
		selected_template = "custom"
		_update_template_selection()
		# 同步更新快速配置页面（在重新加载服务之前）
		quick_key_input.text = chat_key
		_update_quick_status(true, "当前密钥: " + _mask_key(chat_key))
		_reload_ai_service()
		_reload_tts_service()
		_load_voice_settings()
	else:
		_update_detail_status(false, "保存失败")

func _sync_to_detail_config(config: Dictionary):
	"""将配置同步到详细配置页面"""
	if config.has("chat_model"):
		var chat = config.chat_model
		chat_model_input.text = chat.model
		chat_base_url_input.text = chat.base_url
		chat_key_input.text = chat.api_key
	
	if config.has("summary_model"):
		var summary = config.summary_model
		summary_model_input.text = summary.model
		summary_base_url_input.text = summary.base_url
		summary_key_input.text = summary.api_key
	
	if config.has("tts_model"):
		var tts = config.tts_model
		tts_model_input.text = tts.model
		tts_base_url_input.text = tts.base_url
		tts_key_input.text = tts.api_key

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
		ai_service.reload_config()
		print("AI服务已重新加载配置")

func _reload_tts_service():
	"""重新加载TTS服务"""
	if has_node("/root/TTSService"):
		var tts_service = get_node("/root/TTSService")
		tts_service.reload_settings()
		print("TTS服务已重新加载配置")

# === 语音设置相关 ===

func _load_voice_settings():
	"""加载语音设置"""
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

func _on_voice_reupload_pressed():
	"""手动重新上传参考音频"""
	if not has_node("/root/TTSService"):
		voice_status_label.text = "✗ TTS服务未加载"
		voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return
	
	var tts = get_node("/root/TTSService")
	
	# 检查是否已启用
	if not tts.is_enabled:
		voice_status_label.text = "⚠ 请先启用TTS"
		voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		return
	
	# 检查API密钥
	if tts.api_key.is_empty():
		voice_status_label.text = "⚠ 请先配置API密钥"
		voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		return
	
	# 禁用按钮，防止重复点击
	voice_reupload_button.disabled = true
	
	# 更新状态
	voice_status_label.text = "⏳ 正在重新上传参考音频..."
	voice_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	
	# 强制重新上传
	tts.upload_reference_audio(true)
	
	# 等待一段时间后重新启用按钮
	await get_tree().create_timer(2.0).timeout
	voice_reupload_button.disabled = false

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
