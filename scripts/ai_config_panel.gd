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
		},
		"embedding_model": {
			"model": "BAAI/bge-m3",
			"base_url": "https://api.siliconflow.cn/v1"
		}
	},
	"standard": {
		"name": "标准",
		"description": "支持语音，以高性价比获得更佳的体验",
		"chat_model": {
			"model": "deepseek-ai/DeepSeek-V3.2-Exp",
			"base_url": "https://api.siliconflow.cn/v1"
		},
		"summary_model": {
			"model": "deepseek-ai/DeepSeek-V3.2-Exp",
			"base_url": "https://api.siliconflow.cn/v1"
		},
		"tts_model": {
			"model": "FunAudioLLM/CosyVoice2-0.5B",
			"base_url": "https://api.siliconflow.cn"
		},
		"embedding_model": {
			"model": "BAAI/bge-m3",
			"base_url": "https://api.siliconflow.cn/v1"
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
@onready var embedding_model_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / EmbeddingModelInput
@onready var embedding_base_url_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / EmbeddingBaseURLInput
@onready var embedding_key_input = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / EmbeddingKeyInput
@onready var detail_save_button = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / DetailSaveButton
@onready var detail_status_label = $MarginContainer/VBoxContainer/TabContainer / 详细配置 / ScrollContainer / VBoxContainer / DetailStatusLabel

# 语音设置
@onready var voice_enable_checkbox = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / EnableContainer / EnableCheckBox
@onready var voice_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / VolumeContainer / VolumeSlider
@onready var voice_volume_label = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / VolumeContainer / VolumeValueLabel
@onready var voice_reupload_button = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / ReuploadButton
@onready var voice_status_label = $MarginContainer/VBoxContainer/TabContainer / 语音设置 / VBoxContainer / StatusLabel

# 日志导出
@onready var log_export_button = $MarginContainer/VBoxContainer/TabContainer / 日志导出 / VBoxContainer / ExportButton
@onready var log_status_label = $MarginContainer/VBoxContainer/TabContainer / 日志导出 / VBoxContainer / StatusLabel

# 存档导出
@onready var save_export_api_key_input = $MarginContainer/VBoxContainer/TabContainer / 存档导出 / ScrollContainer / VBoxContainer / APIKeyInput
@onready var save_export_button = $MarginContainer/VBoxContainer/TabContainer / 存档导出 / ScrollContainer / VBoxContainer / ExportButton
@onready var save_export_status_label = $MarginContainer/VBoxContainer/TabContainer / 存档导出 / ScrollContainer / VBoxContainer / StatusLabel

# 修复记忆
@onready var repair_check_button = $MarginContainer/VBoxContainer/TabContainer / 修复记忆 / ScrollContainer / VBoxContainer / CheckButton
@onready var repair_check_status_label = $MarginContainer/VBoxContainer/TabContainer / 修复记忆 / ScrollContainer / VBoxContainer / CheckStatusLabel
@onready var repair_button = $MarginContainer/VBoxContainer/TabContainer / 修复记忆 / ScrollContainer / VBoxContainer / RepairButton
@onready var repair_progress_label = $MarginContainer/VBoxContainer/TabContainer / 修复记忆 / ScrollContainer / VBoxContainer / ProgressLabel
@onready var repair_progress_bar = $MarginContainer/VBoxContainer/TabContainer / 修复记忆 / ScrollContainer / VBoxContainer / ProgressBar
@onready var repair_log_label = $MarginContainer/VBoxContainer/TabContainer / 修复记忆 / ScrollContainer / VBoxContainer / LogScrollContainer / LogLabel

var repair_tool: Node = null

# 回复设置
var response_verbal_button: CheckBox
var response_narrative_button: CheckBox
var response_status_label: Label

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	quick_template_free.pressed.connect(_on_template_selected.bind("free"))
	quick_template_standard.pressed.connect(_on_template_selected.bind("standard"))
	quick_apply_button.pressed.connect(_on_quick_apply_pressed)
	detail_save_button.pressed.connect(_on_detail_save_pressed)
	voice_enable_checkbox.toggled.connect(_on_voice_enable_toggled)
	voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	voice_reupload_button.pressed.connect(_on_voice_reupload_pressed)
	log_export_button.pressed.connect(_on_log_export_pressed)
	save_export_button.pressed.connect(_on_save_export_pressed)
	repair_check_button.pressed.connect(_on_repair_check_pressed)
	repair_button.pressed.connect(_on_repair_start_pressed)
	
	# 创建修复工具实例
	var repair_script = load("res://scripts/vector_repair_tool.gd")
	repair_tool = repair_script.new()
	add_child(repair_tool)
	repair_tool.repair_progress.connect(_on_repair_progress)
	repair_tool.repair_completed.connect(_on_repair_completed)
	
	# 创建回复设置选项卡
	_setup_response_settings_tab()
	
	# 为模板按钮添加样式
	_style_template_buttons()
	
	# 为语音启用按钮添加样式
	_style_voice_checkbox()
	
	# 为存档导出警告面板添加样式
	_style_warning_panel()
	
	# 默认选择标准模板
	_on_template_selected("standard")
	
	# 加载现有配置
	_load_existing_config()
	_load_voice_settings()
	_load_response_settings()

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

func _style_warning_panel():
	"""为存档导出警告面板添加醒目的样式"""
	var warning_panel = $MarginContainer/VBoxContainer/TabContainer / 存档导出 / ScrollContainer / VBoxContainer / WarningPanel
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.3, 0.1, 0.1, 0.8)  # 深红色背景
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(1.0, 0.2, 0.2, 1.0)  # 红色边框
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	warning_panel.add_theme_stylebox_override("panel", style_box)

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
	
	if config.has("embedding_model"):
		var embedding = config.embedding_model
		embedding_model_input.text = embedding.get("model", "")
		embedding_base_url_input.text = embedding.get("base_url", "")
		embedding_key_input.text = embedding.get("api_key", "")

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
		},
		"embedding_model": {
			"model": template.embedding_model.model,
			"base_url": template.embedding_model.base_url,
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
	var embedding_model = embedding_model_input.text.strip_edges()
	var embedding_base_url = embedding_base_url_input.text.strip_edges()
	var embedding_key = embedding_key_input.text.strip_edges()
	
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
	
	# 嵌入模型配置是可选的，但始终保存配置块（即使为空）
	config["embedding_model"] = {
		"model": embedding_model,
		"base_url": embedding_base_url,
		"api_key": embedding_key
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
	
	if config.has("embedding_model"):
		var embedding = config.embedding_model
		embedding_model_input.text = embedding.model
		embedding_base_url_input.text = embedding.base_url
		embedding_key_input.text = embedding.api_key

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

# === 日志导出相关 ===

func _on_log_export_pressed():
	"""导出日志按钮被点击"""
	_update_log_status("正在导出日志...", Color(0.3, 0.7, 1.0))
	log_export_button.disabled = true
	
	# 等待一帧以更新UI
	await get_tree().process_frame
	
	var result = _export_logs()
	
	if result.success:
		_update_log_status("✓ " + result.message, Color(0.3, 1.0, 0.3))
	else:
		_update_log_status("✗ " + result.message, Color(1.0, 0.3, 0.3))
	
	# 2秒后重新启用按钮
	await get_tree().create_timer(2.0).timeout
	log_export_button.disabled = false

func _export_logs() -> Dictionary:
	"""导出所有日志文件"""
	# 获取Documents目录
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_path.is_empty():
		return {"success": false, "message": "无法获取Documents目录"}
	
	# 创建导出目录
	var export_dir = documents_path + "/SnowFox_Logs"
	var dir = DirAccess.open(documents_path)
	if dir == null:
		return {"success": false, "message": "无法访问Documents目录"}
	
	if not dir.dir_exists("SnowFox_Logs"):
		var mkdir_result = dir.make_dir("SnowFox_Logs")
		if mkdir_result != OK:
			return {"success": false, "message": "无法创建导出目录"}
	
	# 生成时间戳
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var export_subdir = export_dir + "/" + timestamp
	
	dir = DirAccess.open(export_dir)
	if dir == null:
		return {"success": false, "message": "无法访问导出目录"}
	
	var mkdir_result2 = dir.make_dir(timestamp)
	if mkdir_result2 != OK:
		return {"success": false, "message": "无法创建时间戳子目录"}
	
	var files_exported = 0
	
	# 1. 导出AI日志
	var ai_log_result = _export_ai_logs(export_subdir)
	if ai_log_result.success:
		files_exported += ai_log_result.count
	
	# 2. 导出Godot日志
	var godot_log_result = _export_godot_logs(export_subdir)
	if godot_log_result.success:
		files_exported += godot_log_result.count
	
	# 3. 导出存档信息
	var save_result = _export_save_info(export_subdir)
	if save_result.success:
		files_exported += save_result.count
	
	# 4. 导出日记
	var diary_result = _export_diary(export_subdir)
	if diary_result.success:
		files_exported += diary_result.count
	
	if files_exported > 0:
		return {
			"success": true,
			"message": "已导出 %d 个文件" % files_exported
		}
	else:
		return {
			"success": false,
			"message": "没有找到可导出的日志文件"
		}

func _export_ai_logs(export_dir: String) -> Dictionary:
	"""导出AI日志"""
	var ai_log_path = "user://ai_logs/log.txt"
	
	if not FileAccess.file_exists(ai_log_path):
		print("AI日志文件不存在")
		return {"success": false, "count": 0}
	
	var source_file = FileAccess.open(ai_log_path, FileAccess.READ)
	if source_file == null:
		print("无法读取AI日志文件")
		return {"success": false, "count": 0}
	
	var content = source_file.get_as_text()
	source_file.close()
	
	var dest_path = export_dir + "/ai_log.txt"
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest_file == null:
		print("无法写入AI日志文件")
		return {"success": false, "count": 0}
	
	dest_file.store_string(content)
	dest_file.close()
	
	print("AI日志已导出: ", dest_path)
	return {"success": true, "count": 1}

func _export_godot_logs(export_dir: String) -> Dictionary:
	"""导出Godot日志（stdout）"""
	# Godot的日志通常在user://目录下的godot.log
	var log_paths = [
		"user://logs/godot.log",
		OS.get_user_data_dir() + "/logs/godot.log"
	]
	
	var count = 0
	
	for log_path in log_paths:
		if FileAccess.file_exists(log_path):
			var source_file = FileAccess.open(log_path, FileAccess.READ)
			if source_file == null:
				continue
			
			var content = source_file.get_as_text()
			source_file.close()
			
			var filename = log_path.get_file()
			var dest_path = export_dir + "/" + filename
			var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
			if dest_file == null:
				continue
			
			dest_file.store_string(content)
			dest_file.close()
			
			print("Godot日志已导出: ", dest_path)
			count += 1
	
	# 如果没有找到日志文件，创建一个包含当前输出的文件
	if count == 0:
		var dest_path = export_dir + "/godot_output.txt"
		var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
		if dest_file:
			dest_file.store_string("Godot日志文件未找到\n")
			dest_file.store_string("用户数据目录: " + OS.get_user_data_dir() + "\n")
			dest_file.store_string("导出时间: " + Time.get_datetime_string_from_system() + "\n")
			dest_file.close()
			count = 1
	
	return {"success": count > 0, "count": count}

func _export_save_info(export_dir: String) -> Dictionary:
	"""导出存档信息"""
	if not has_node("/root/SaveManager"):
		return {"success": false, "count": 0}
	
	var save_mgr = get_node("/root/SaveManager")
	var save_data = save_mgr.save_data
	
	var dest_path = export_dir + "/save_info.json"
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest_file == null:
		return {"success": false, "count": 0}
	
	# 导出存档数据（格式化）
	dest_file.store_string(JSON.stringify(save_data, "\t"))
	dest_file.close()
	
	print("存档信息已导出: ", dest_path)
	return {"success": true, "count": 1}

func _export_diary(export_dir: String) -> Dictionary:
	"""导出日记文件"""
	var diary_dir = "user://diary"
	
	if not DirAccess.dir_exists_absolute(diary_dir):
		print("日记目录不存在")
		return {"success": false, "count": 0}
	
	var dir = DirAccess.open(diary_dir)
	if dir == null:
		return {"success": false, "count": 0}
	
	# 创建日记子目录
	var diary_export_dir = export_dir + "/diary"
	var export_dir_access = DirAccess.open(export_dir)
	if export_dir_access == null:
		return {"success": false, "count": 0}
	
	var mkdir_err = export_dir_access.make_dir("diary")
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		return {"success": false, "count": 0}
	
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".jsonl"):
			var source_path = diary_dir + "/" + file_name
			var source_file = FileAccess.open(source_path, FileAccess.READ)
			if source_file:
				var content = source_file.get_as_text()
				source_file.close()
				
				var dest_path = diary_export_dir + "/" + file_name
				var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
				if dest_file:
					dest_file.store_string(content)
					dest_file.close()
					count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if count > 0:
		print("已导出 %d 个日记文件" % count)
	
	return {"success": count > 0, "count": count}

func _update_log_status(message: String, color: Color = Color.WHITE):
	"""更新日志导出状态标签"""
	log_status_label.text = message
	log_status_label.add_theme_color_override("font_color", color)

# === 存档导出相关 ===

func _on_save_export_pressed():
	"""存档导出按钮被点击"""
	var input_key = save_export_api_key_input.text.strip_edges()
	
	if input_key.is_empty():
		_update_save_export_status("请输入API密钥", Color(1.0, 0.3, 0.3))
		return
	
	# 验证API密钥
	if not _verify_api_key(input_key):
		_update_save_export_status("API密钥验证失败，请输入正确的密钥", Color(1.0, 0.3, 0.3))
		return
	
	# 执行导出
	_export_save_archive()

func _verify_api_key(input_key: String) -> bool:
	"""验证输入的API密钥是否匹配"""
	var keys_path = "user://ai_keys.json"
	
	if not FileAccess.file_exists(keys_path):
		return false
	
	var file = FileAccess.open(keys_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false
	
	var config = json.data
	
	# 检查 chat_model 的 api_key
	if config.has("chat_model") and config.chat_model.has("api_key"):
		if config.chat_model.api_key == input_key:
			return true
	
	# 检查快速配置的 api_key
	if config.has("api_key"):
		if config.api_key == input_key:
			return true
	
	return false

func _export_save_archive():
	"""导出存档为zip文件"""
	_update_save_export_status("正在导出存档...", Color(0.3, 0.8, 1.0))
	save_export_button.disabled = true
	
	# 生成导出文件名（带时间戳）
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var export_filename = "CABM-ED_Save_%s.zip" % timestamp
	
	# 根据平台选择不同的导出方式
	if OS.get_name() == "Android":
		# Android: 直接导出到Documents目录
		_export_save_android(export_filename)
	else:
		# PC: 使用文件对话框
		var file_dialog = FileDialog.new()
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.current_file = export_filename
		file_dialog.add_filter("*.zip", "存档文件")
		file_dialog.file_selected.connect(_on_save_export_path_selected)
		file_dialog.canceled.connect(_on_save_export_canceled)
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered(Vector2i(800, 600))

func _export_save_android(filename: String):
	"""Android平台导出存档"""
	# 请求存储权限
	var perm_helper = load("res://scripts/android_permissions.gd").new()
	add_child(perm_helper)
	
	var has_permission = await perm_helper.request_storage_permission()
	perm_helper.queue_free()
	
	if not has_permission:
		_update_save_export_status("✗ 需要存储权限才能导出", Color(1.0, 0.3, 0.3))
		save_export_button.disabled = false
		return
	
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_path.is_empty():
		documents_path = "/storage/emulated/0/Documents"
	
	var export_path = documents_path + "/CABM-ED_Saves"
	
	# 创建导出目录
	var dir = DirAccess.open(documents_path)
	if dir and not dir.dir_exists("CABM-ED_Saves"):
		dir.make_dir("CABM-ED_Saves")
	
	var full_export_path = export_path + "/" + filename
	
	# 使用Godot内置的ZIPPacker
	if _create_zip_archive(full_export_path):
		_update_save_export_status("✓ 导出成功\n" + full_export_path, Color(0.3, 1.0, 0.3))
		print("存档导出成功: ", full_export_path)
	else:
		_update_save_export_status("✗ 导出失败", Color(1.0, 0.3, 0.3))
	
	save_export_button.disabled = false

func _on_save_export_path_selected(export_path: String):
	"""用户选择了导出路径（PC平台）"""
	print("开始导出存档: ", export_path)
	
	# 使用Godot内置的ZIPPacker
	if _create_zip_archive(export_path):
		_update_save_export_status("✓ 导出成功: " + export_path, Color(0.3, 1.0, 0.3))
		print("存档导出成功")
	else:
		_update_save_export_status("✗ 导出失败", Color(1.0, 0.3, 0.3))
	
	save_export_button.disabled = false

func _create_zip_archive(zip_path: String) -> bool:
	"""使用Godot内置ZIPPacker创建存档"""
	var zip = ZIPPacker.new()
	var err = zip.open(zip_path)
	
	if err != OK:
		print("无法创建ZIP文件: ", err)
		return false
	
	# 获取user://目录
	var user_path = OS.get_user_data_dir()
	
	# 递归添加所有文件
	var success = _add_directory_to_zip(zip, user_path, "")
	
	zip.close()
	
	return success

func _add_directory_to_zip(zip: ZIPPacker, dir_path: String, zip_base_path: String) -> bool:
	"""递归添加目录到ZIP"""
	var dir = DirAccess.open(dir_path)
	if dir == null:
		print("无法打开目录: ", dir_path)
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var full_path = dir_path + "/" + file_name
		var zip_path = zip_base_path + file_name if zip_base_path.is_empty() else zip_base_path + "/" + file_name
		
		if dir.current_is_dir():
			# 递归添加子目录
			_add_directory_to_zip(zip, full_path, zip_path)
		else:
			# 添加文件
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content = file.get_buffer(file.get_length())
				file.close()
				zip.start_file(zip_path)
				zip.write_file(content)
				zip.close_file()
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return true

func _on_save_export_canceled():
	"""用户取消了导出"""
	_update_save_export_status("已取消导出", Color(0.6, 0.6, 0.6))
	save_export_button.disabled = false

func _update_save_export_status(message: String, color: Color):
	"""更新存档导出状态"""
	save_export_status_label.text = message
	save_export_status_label.add_theme_color_override("font_color", color)

# === 修复记忆相关 ===

func _on_repair_check_pressed():
	"""检查向量数据按钮被点击"""
	repair_check_button.disabled = true
	repair_check_status_label.text = "正在检查..."
	repair_check_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	
	await get_tree().process_frame
	
	# 获取MemoryManager
	var memory_mgr = get_node_or_null("/root/MemoryManager")
	if not memory_mgr:
		repair_check_status_label.text = "✗ MemoryManager未找到"
		repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		repair_check_button.disabled = false
		return
	
	# 等待初始化
	if not memory_mgr.is_initialized:
		await memory_mgr.memory_system_ready
	
	var memory_system = memory_mgr.memory_system
	if not memory_system:
		repair_check_status_label.text = "✗ memory_system未找到"
		repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		repair_check_button.disabled = false
		return
	
	var total = memory_system.memory_items.size()
	if total == 0:
		repair_check_status_label.text = "没有记忆数据"
		repair_check_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		repair_check_button.disabled = false
		return
	
	# 检查向量
	var damaged_count = 0
	var damaged_indices = []
	
	for i in range(total):
		if _needs_repair(memory_system.memory_items, i):
			damaged_count += 1
			damaged_indices.append(i)
	
	if damaged_count > 0:
		# 显示损坏的记忆索引（最多显示5个）
		var indices_text = ""
		var show_count = min(5, damaged_indices.size())
		for i in range(show_count):
			indices_text += str(damaged_indices[i] + 1)
			if i < show_count - 1:
				indices_text += ", "
		if damaged_indices.size() > 5:
			indices_text += "..."
		
		repair_check_status_label.text = "✗ 发现 %d 条可能损坏的记忆\n索引: %s" % [damaged_count, indices_text]
		repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		repair_button.disabled = false
	else:
		repair_check_status_label.text = "✓ 所有记忆数据正常\n共 %d 条记忆" % total
		repair_check_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		repair_button.disabled = true
	
	repair_check_button.disabled = false

func _needs_repair(items: Array, index: int) -> bool:
	"""检查向量是否需要修复
	
	判断标准（需同时满足多个条件才判定为损坏）：
	1. 向量为空 -> 肯定损坏
	2. 向量与多个其他记忆的向量完全相同 -> 可能损坏
	   - 需要与至少2个不同的记忆向量完全相同
	   - 检查前50个值（更严格）
	   - 排除文本内容相似的情况
	"""
	var item = items[index]
	
	# 检查1：向量为空 -> 肯定损坏
	if item.vector.is_empty():
		return true
	
	# 检查2：向量维度异常（正常应该是1024维）
	if item.vector.size() < 100:
		return true
	
	# 检查3：向量与多个其他记忆完全相同
	var same_vector_count = 0
	var check_range = 5  # 检查前后各5条记忆
	
	for offset in range(-check_range, check_range + 1):
		if offset == 0:
			continue
		
		var other_idx = index + offset
		if other_idx < 0 or other_idx >= items.size():
			continue
		
		var other_item = items[other_idx]
		if other_item.vector.is_empty():
			continue
		
		# 检查文本是否相似（如果文本相似，向量相同是正常的）
		if _texts_are_similar(item.text, other_item.text):
			continue
		
		# 比较前50个值（更严格的检查）
		if _vectors_are_same(item.vector, other_item.vector, 50):
			same_vector_count += 1
			
			# 如果与2个以上不同的记忆向量完全相同，判定为损坏
			if same_vector_count >= 2:
				return true
	
	return false

func _texts_are_similar(text1: String, text2: String) -> bool:
	"""检查两个文本是否相似（简单的相似度判断）"""
	# 移除时间戳前缀进行比较
	var clean_text1 = _remove_timestamp(text1)
	var clean_text2 = _remove_timestamp(text2)
	
	# 如果文本完全相同
	if clean_text1 == clean_text2:
		return true
	
	# 如果文本长度相差很大，不相似
	var len_diff = abs(clean_text1.length() - clean_text2.length())
	if len_diff > max(clean_text1.length(), clean_text2.length()) * 0.5:
		return false
	
	# 简单的包含关系检查
	if clean_text1.length() > 10 and clean_text2.length() > 10:
		if clean_text1 in clean_text2 or clean_text2 in clean_text1:
			return true
	
	return false

func _remove_timestamp(text: String) -> String:
	"""移除文本开头的时间戳"""
	# 格式: [MM-DD HH:MM] 文本内容
	var regex = RegEx.new()
	regex.compile("^\\[\\d{2}-\\d{2} \\d{2}:\\d{2}\\] ")
	return regex.sub(text, "", true)

func _vectors_are_same(vec1: Array, vec2: Array, check_count: int = 50) -> bool:
	"""检查两个向量的前N个值是否完全相同
	
	使用更严格的阈值（0.00001）来判断相同
	"""
	if vec1.size() != vec2.size():
		return false
	
	var count = min(check_count, vec1.size())
	for i in range(count):
		# 使用更严格的阈值
		if abs(vec1[i] - vec2[i]) > 0.00001:
			return false
	
	return true

func _on_repair_start_pressed():
	"""开始修复按钮被点击"""
	repair_button.disabled = true
	repair_check_button.disabled = true
	close_button.disabled = true
	
	repair_progress_label.text = "正在初始化..."
	repair_progress_bar.value = 0
	repair_log_label.text = "开始修复...\n"
	
	# 开始修复
	repair_tool.start_repair()

func _on_repair_progress(current: int, total: int, message: String):
	"""修复进度更新"""
	var percent = (float(current) / float(total)) * 100.0
	repair_progress_bar.value = percent
	repair_progress_label.text = "[%d/%d] %.1f%%" % [current, total, percent]
	
	# 添加到日志
	repair_log_label.text += "[%d/%d] %s\n" % [current, total, message]

func _on_repair_completed(success: bool, message: String):
	"""修复完成"""
	repair_progress_bar.value = 100
	repair_progress_label.text = "完成"
	
	if success:
		repair_log_label.text += "\n✓ " + message + "\n"
		repair_check_status_label.text = "✓ 修复完成"
		repair_check_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		repair_log_label.text += "\n✗ " + message + "\n"
		repair_check_status_label.text = "✗ 修复失败"
		repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	repair_button.disabled = false
	repair_button.text = "重新修复"
	repair_check_button.disabled = false
	close_button.disabled = false

# === 回复设置相关 ===

func _setup_response_settings_tab():
	"""创建回复设置选项卡"""
	# 创建选项卡
	var response_tab = MarginContainer.new()
	response_tab.name = "回复设置"
	response_tab.add_theme_constant_override("margin_left", 10)
	response_tab.add_theme_constant_override("margin_top", 10)
	response_tab.add_theme_constant_override("margin_right", 10)
	response_tab.add_theme_constant_override("margin_bottom", 10)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	response_tab.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.text = "选择回复模式"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 按钮组
	var button_group = ButtonGroup.new()
	
	# 语言表达模式
	var verbal_container = VBoxContainer.new()
	verbal_container.add_theme_constant_override("separation", 5)
	
	response_verbal_button = CheckBox.new()
	response_verbal_button.text = "语言表达"
	response_verbal_button.button_group = button_group
	response_verbal_button.toggled.connect(_on_response_mode_changed.bind("verbal"))
	verbal_container.add_child(response_verbal_button)
	
	var verbal_desc = Label.new()
	verbal_desc.text = "简洁的对话，保持自然交流风格"
	verbal_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	verbal_desc.add_theme_font_size_override("font_size", 12)
	verbal_container.add_child(verbal_desc)
	
	vbox.add_child(verbal_container)
	
	# 分隔线
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# 情景叙事模式
	var narrative_container = VBoxContainer.new()
	narrative_container.add_theme_constant_override("separation", 5)
	
	response_narrative_button = CheckBox.new()
	response_narrative_button.text = "情景叙事"
	response_narrative_button.button_group = button_group
	response_narrative_button.toggled.connect(_on_response_mode_changed.bind("narrative"))
	narrative_container.add_child(response_narrative_button)
	
	var narrative_desc = Label.new()
	narrative_desc.text = "详细的叙述，包含动作、神态、心理活动等"
	narrative_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	narrative_desc.add_theme_font_size_override("font_size", 12)
	narrative_container.add_child(narrative_desc)
	
	vbox.add_child(narrative_container)
	
	# 状态标签
	response_status_label = Label.new()
	response_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	response_status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(response_status_label)
	
	# 添加到TabContainer（在"语音设置"之后）
	tab_container.add_child(response_tab)
	# 将回复设置移到第二个位置（快速配置之后）
	tab_container.move_child(response_tab, 2)

func _load_response_settings():
	"""加载回复设置"""
	var config_path = "user://ai_keys.json"
	
	var response_mode = "verbal" # 默认为语言表达
	
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var config = json.data
				response_mode = config.get("response_mode", "verbal")
	
	# 设置按钮状态
	if response_mode == "narrative":
		response_narrative_button.button_pressed = true
		response_status_label.text = "当前: 情景叙事模式"
	else:
		response_verbal_button.button_pressed = true
		response_status_label.text = "当前: 语言表达模式"
	
	response_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _on_response_mode_changed(enabled: bool, mode: String):
	"""回复模式改变"""
	if not enabled:
		return
	
	# 保存设置
	if _save_response_mode(mode):
		if mode == "narrative":
			response_status_label.text = "✓ 已切换到情景叙事模式"
		else:
			response_status_label.text = "✓ 已切换到语言表达模式"
		response_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		response_status_label.text = "✗ 保存失败"
		response_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _save_response_mode(mode: String) -> bool:
	"""保存回复模式到配置文件"""
	var config_path = "user://ai_keys.json"
	
	# 读取现有配置
	var config = {}
	if FileAccess.file_exists(config_path):
		var read_file = FileAccess.open(config_path, FileAccess.READ)
		if read_file:
			var json_string = read_file.get_as_text()
			read_file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				config = json.data
	
	# 更新回复模式
	config["response_mode"] = mode
	
	# 保存配置
	var write_file = FileAccess.open(config_path, FileAccess.WRITE)
	if write_file == null:
		return false
	
	write_file.store_string(JSON.stringify(config, "\t"))
	write_file.close()
	
	print("回复模式已保存: ", mode)
	return true
