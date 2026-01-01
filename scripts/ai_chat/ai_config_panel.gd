extends Panel

# AI 配置面板 - 支持快速配置和详细配置
# 该文件作为主控制器，整合各个功能模块

@onready var close_button = $MarginContainer/VBoxContainer/TitleContainer/CloseButton
@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer
@onready var memory_config = $MarginContainer/VBoxContainer/TabContainer/记忆系统

# 快速配置引用
@onready var quick_template_free = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/TemplateContainer/FreeButton
@onready var quick_template_standard = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/TemplateContainer/StandardButton
@onready var quick_template_alternate = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/TemplateContainer/AlternateButton
@onready var quick_description_label = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/DescriptionLabel
@onready var quick_key_input = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/KeyInput
@onready var quick_apply_button = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/ApplyButton
@onready var quick_status_label = $MarginContainer/VBoxContainer/TabContainer/快速配置/ScrollContainer/VBoxContainer/StatusLabel

# 详细配置引用（二级选项卡）
@onready var chat_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/对话模型/ScrollContainer/VBoxContainer/ChatModelInput
@onready var chat_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/对话模型/ScrollContainer/VBoxContainer/ChatBaseURLInput
@onready var chat_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/对话模型/ScrollContainer/VBoxContainer/ChatKeyInput
@onready var summary_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/总结模型/ScrollContainer/VBoxContainer/SummaryModelInput
@onready var summary_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/总结模型/ScrollContainer/VBoxContainer/SummaryBaseURLInput
@onready var summary_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/总结模型/ScrollContainer/VBoxContainer/SummaryKeyInput
@onready var tts_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/语音模型/ScrollContainer/VBoxContainer/TTSModelInput
@onready var tts_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/语音模型/ScrollContainer/VBoxContainer/TTSBaseURLInput
@onready var tts_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/语音模型/ScrollContainer/VBoxContainer/TTSKeyInput
@onready var embedding_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/嵌入模型/ScrollContainer/VBoxContainer/EmbeddingModelInput
@onready var embedding_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/嵌入模型/ScrollContainer/VBoxContainer/EmbeddingBaseURLInput
@onready var embedding_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/嵌入模型/ScrollContainer/VBoxContainer/EmbeddingKeyInput
@onready var view_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/视觉模型/ScrollContainer/VBoxContainer/ViewModelInput
@onready var view_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/视觉模型/ScrollContainer/VBoxContainer/ViewBaseURLInput
@onready var view_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/视觉模型/ScrollContainer/VBoxContainer/ViewKeyInput
@onready var stt_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/语音输入/ScrollContainer/VBoxContainer/STTModelInput
@onready var stt_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/语音输入/ScrollContainer/VBoxContainer/STTBaseURLInput
@onready var stt_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/语音输入/ScrollContainer/VBoxContainer/STTKeyInput
@onready var rerank_model_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/重排模型/ScrollContainer/VBoxContainer/RerankModelInput
@onready var rerank_base_url_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/重排模型/ScrollContainer/VBoxContainer/RerankBaseURLInput
@onready var rerank_key_input = $MarginContainer/VBoxContainer/TabContainer/详细配置/DetailTabs/重排模型/ScrollContainer/VBoxContainer/RerankKeyInput
@onready var detail_save_button = $MarginContainer/VBoxContainer/TabContainer/详细配置/SaveArea/DetailSaveButton
@onready var detail_status_label = $MarginContainer/VBoxContainer/TabContainer/详细配置/SaveArea/DetailStatusLabel

# 语音设置引用
@onready var voice_enable_checkbox = $MarginContainer/VBoxContainer/TabContainer/语音设置/VBoxContainer/EnableContainer/EnableCheckBox
@onready var voice_volume_slider = $MarginContainer/VBoxContainer/TabContainer/语音设置/VBoxContainer/VolumeContainer/VolumeSlider
@onready var voice_volume_label = $MarginContainer/VBoxContainer/TabContainer/语音设置/VBoxContainer/VolumeContainer/VolumeValueLabel
@onready var voice_reupload_button = $MarginContainer/VBoxContainer/TabContainer/语音设置/VBoxContainer/ReuploadButton
@onready var voice_status_label = $MarginContainer/VBoxContainer/TabContainer/语音设置/VBoxContainer/StatusLabel
@onready var voice_language_option = $MarginContainer/VBoxContainer/TabContainer/语音设置/VBoxContainer/LanguageContainer/LanguageOption

# 日志导出引用
@onready var log_export_button = $MarginContainer/VBoxContainer/TabContainer/日志导出/VBoxContainer/ExportButton
@onready var log_status_label = $MarginContainer/VBoxContainer/TabContainer/日志导出/VBoxContainer/StatusLabel

# 存档导出引用
@onready var save_export_api_key_input = $MarginContainer/VBoxContainer/TabContainer/存档导出/ScrollContainer/VBoxContainer/APIKeyInput
@onready var save_export_button = $MarginContainer/VBoxContainer/TabContainer/存档导出/ScrollContainer/VBoxContainer/ExportButton
@onready var save_export_status_label = $MarginContainer/VBoxContainer/TabContainer/存档导出/ScrollContainer/VBoxContainer/StatusLabel

# 修复记忆引用
@onready var repair_check_button = $MarginContainer/VBoxContainer/TabContainer/修复记忆/ScrollContainer/VBoxContainer/CheckButton
@onready var repair_check_status_label = $MarginContainer/VBoxContainer/TabContainer/修复记忆/ScrollContainer/VBoxContainer/CheckStatusLabel
@onready var repair_button = $MarginContainer/VBoxContainer/TabContainer/修复记忆/ScrollContainer/VBoxContainer/RepairButton
@onready var repair_progress_label = $MarginContainer/VBoxContainer/TabContainer/修复记忆/ScrollContainer/VBoxContainer/ProgressLabel
@onready var repair_progress_bar = $MarginContainer/VBoxContainer/TabContainer/修复记忆/ScrollContainer/VBoxContainer/ProgressBar
@onready var repair_log_label = $MarginContainer/VBoxContainer/TabContainer/修复记忆/ScrollContainer/VBoxContainer/LogScrollContainer/LogLabel

# 各功能模块
var config_manager: Node
var template_handler: Node
var voice_settings: Node
var log_exporter: Node
var save_exporter: Node
var memory_repair: Node
var response_settings: Node
var _last_saved_detail: Dictionary = {}

func _ready():
	# 初始化配置管理器
	config_manager = Node.new()
	config_manager.script = load("res://scripts/ai_chat/ai_config_manager.gd")
	add_child(config_manager)
	
	# 初始化模板处理器
	template_handler = load("res://scripts/ai_chat/ai_template_handler.gd").new(config_manager)
	template_handler.quick_template_free = quick_template_free
	template_handler.quick_template_standard = quick_template_standard
	template_handler.quick_template_alternate = quick_template_alternate
	template_handler.quick_description_label = quick_description_label
	add_child(template_handler)
	
	# 初始化语音设置
	voice_settings = Node.new()
	voice_settings.script = load("res://scripts/ai_chat/ai_voice_settings.gd")
	voice_settings.voice_enable_checkbox = voice_enable_checkbox
	voice_settings.voice_volume_slider = voice_volume_slider
	voice_settings.voice_volume_label = voice_volume_label
	voice_settings.voice_reupload_button = voice_reupload_button
	voice_settings.voice_status_label = voice_status_label
	voice_settings.voice_language_option = voice_language_option
	add_child(voice_settings)
	
	# 初始化日志导出器
	log_exporter = Node.new()
	log_exporter.script = load("res://scripts/ai_chat/ai_log_exporter.gd")
	log_exporter.log_status_label = log_status_label
	log_exporter.log_export_button = log_export_button
	add_child(log_exporter)
	
	# 初始化存档导出器
	save_exporter = load("res://scripts/ai_chat/ai_save_exporter.gd").new(config_manager)
	save_exporter.save_export_api_key_input = save_export_api_key_input
	save_exporter.save_export_button = save_export_button
	save_exporter.save_export_status_label = save_export_status_label
	add_child(save_exporter)
	
	# 初始化记忆修复模块
	memory_repair = Node.new()
	memory_repair.script = load("res://scripts/ai_chat/ai_memory_repair.gd")
	memory_repair.repair_check_button = repair_check_button
	memory_repair.repair_check_status_label = repair_check_status_label
	memory_repair.repair_button = repair_button
	memory_repair.repair_progress_label = repair_progress_label
	memory_repair.repair_progress_bar = repair_progress_bar
	memory_repair.repair_log_label = repair_log_label
	memory_repair.close_button = close_button
	add_child(memory_repair)
	memory_repair.init_repair_tool()
	
	# 初始化回复设置
	response_settings = load("res://scripts/ai_chat/ai_response_settings.gd").new(config_manager)
	response_settings.tab_container = tab_container
	add_child(response_settings)

	# 初始化记忆系统配置
	memory_config.initialize(config_manager)
	
	# 连接信号
	close_button.pressed.connect(_on_close_pressed)
	quick_template_free.pressed.connect(_on_template_selected.bind("free"))
	quick_template_standard.pressed.connect(_on_template_selected.bind("standard"))
	quick_template_alternate.pressed.connect(_on_template_selected.bind("alternate"))
	quick_apply_button.pressed.connect(_on_quick_apply_pressed)
	detail_save_button.pressed.connect(_on_detail_save_pressed)
	chat_model_input.text_changed.connect(_on_detail_field_changed)
	chat_base_url_input.text_changed.connect(_on_detail_field_changed)
	chat_key_input.text_changed.connect(_on_detail_field_changed)
	summary_model_input.text_changed.connect(_on_detail_field_changed)
	summary_base_url_input.text_changed.connect(_on_detail_field_changed)
	summary_key_input.text_changed.connect(_on_detail_field_changed)
	tts_model_input.text_changed.connect(_on_detail_field_changed)
	tts_base_url_input.text_changed.connect(_on_detail_field_changed)
	tts_key_input.text_changed.connect(_on_detail_field_changed)
	embedding_model_input.text_changed.connect(_on_detail_field_changed)
	embedding_base_url_input.text_changed.connect(_on_detail_field_changed)
	embedding_key_input.text_changed.connect(_on_detail_field_changed)
	view_model_input.text_changed.connect(_on_detail_field_changed)
	view_base_url_input.text_changed.connect(_on_detail_field_changed)
	view_key_input.text_changed.connect(_on_detail_field_changed)
	stt_model_input.text_changed.connect(_on_detail_field_changed)
	stt_base_url_input.text_changed.connect(_on_detail_field_changed)
	stt_key_input.text_changed.connect(_on_detail_field_changed)
	rerank_model_input.text_changed.connect(_on_detail_field_changed)
	rerank_base_url_input.text_changed.connect(_on_detail_field_changed)
	rerank_key_input.text_changed.connect(_on_detail_field_changed)
	voice_enable_checkbox.toggled.connect(voice_settings.on_voice_enable_toggled)
	voice_volume_slider.value_changed.connect(voice_settings.on_voice_volume_changed)
	voice_reupload_button.pressed.connect(voice_settings.on_voice_reupload_pressed)
	log_export_button.pressed.connect(log_exporter.on_log_export_pressed)
	save_export_button.pressed.connect(save_exporter.on_save_export_pressed)
	repair_check_button.pressed.connect(memory_repair.on_repair_check_pressed)
	repair_button.pressed.connect(memory_repair.on_repair_start_pressed)
	
	# 应用样式
	template_handler.style_template_buttons()
	voice_settings.style_voice_checkbox()
	save_exporter.style_warning_panel(self)
	
	# 创建回复设置选项卡
	response_settings.setup_response_settings_tab()


	# 加载现有配置
	config_manager.migrate_old_config()
	_load_existing_config()
	template_handler.load_selected_template()
	voice_settings.load_voice_settings()
	response_settings.load_response_settings()
	_apply_android_input_workaround()
	_last_saved_detail = _collect_detail_inputs()
	_update_detail_saved_label()

func _on_close_pressed():
	"""关闭面板"""
	queue_free()

func _apply_android_input_workaround():
	if has_node("/root/PlatformManager"):
		var pm = get_node("/root/PlatformManager")
		if pm.is_android():
			var inputs: Array = [
				quick_key_input,
				chat_model_input,
				chat_base_url_input,
				chat_key_input,
				summary_model_input,
				summary_base_url_input,
				summary_key_input,
				tts_model_input,
				tts_base_url_input,
				tts_key_input,
				embedding_model_input,
				embedding_base_url_input,
				embedding_key_input,
				view_model_input,
				view_base_url_input,
				view_key_input,
				stt_model_input,
				stt_base_url_input,
				stt_key_input,
				rerank_model_input,
				rerank_base_url_input,
				rerank_key_input,
				save_export_api_key_input
			]
			for le in inputs:
				if le and le is LineEdit:
					le.context_menu_enabled = false
					le.shortcut_keys_enabled = false
					if le.has_method("set_selecting_enabled"):
						le.selecting_enabled = false

func _on_template_selected(template: String):
	"""选择配置模板"""
	template_handler.select_template(template)

func _on_quick_apply_pressed():
	"""应用快速配置模板"""
	var api_key = quick_key_input.text.strip_edges()
	var result = template_handler.apply_quick_config(api_key)
	if result.success:
		_update_quick_status(true, result.message)
		# 同步更新详细配置页面
		_sync_to_detail_config(result.config)
		_reload_ai_service()
		_reload_tts_service()
		voice_settings.load_voice_settings()
		_last_saved_detail = _collect_detail_inputs()
		_update_detail_saved_label()
	else:
		_update_quick_status(false, result.message)

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
	var view_model = view_model_input.text.strip_edges()
	var view_base_url = view_base_url_input.text.strip_edges()
	var view_key = view_key_input.text.strip_edges()
	var stt_model = stt_model_input.text.strip_edges()
	var stt_base_url = stt_base_url_input.text.strip_edges()
	var stt_key = stt_key_input.text.strip_edges()
	var rerank_model = rerank_model_input.text.strip_edges()
	var rerank_base_url = rerank_base_url_input.text.strip_edges()
	var rerank_key = rerank_key_input.text.strip_edges()

	# 验证必填字段
	if chat_model.is_empty() or chat_base_url.is_empty() or chat_key.is_empty():
		_update_detail_status(false, "对话模型配置不完整")
		return
	
	if summary_model.is_empty() or summary_base_url.is_empty() or summary_key.is_empty():
		_update_detail_status(false, "总结模型配置不完整")
		return
	
	var config = {
		"template": "custom",
		"api_key": chat_key,
		"chat_model": {
			"model": chat_model,
			"base_url": chat_base_url,
			"api_key": chat_key
		},
		"summary_model": {
			"model": summary_model,
			"base_url": summary_base_url,
			"api_key": summary_key
		},
		"tts_model": {
			"model": tts_model,
			"base_url": tts_base_url,
			"api_key": tts_key
		},
		"embedding_model": {
			"model": embedding_model,
			"base_url": embedding_base_url,
			"api_key": embedding_key
		},
		"view_model": {
			"model": view_model,
			"base_url": view_base_url,
			"api_key": view_key
		},
		"stt_model": {
			"model": stt_model,
			"base_url": stt_base_url,
			"api_key": stt_key
		},
		"rerank_model": {
			"model": rerank_model,
			"base_url": rerank_base_url,
			"api_key": rerank_key
		}
	}
	
	if config_manager.save_config(config):
		_update_detail_status(true, "配置已保存")
		template_handler.selected_template = "custom"
		template_handler.update_template_selection()
		quick_key_input.text = chat_key
		_update_quick_status(true, "当前密钥: " + config_manager.mask_key(chat_key))
		_reload_ai_service()
		_reload_tts_service()
		voice_settings.load_voice_settings()
		_last_saved_detail = _collect_detail_inputs()
		_update_detail_saved_label()
	else:
		_update_detail_status(false, "保存失败")

func _load_existing_config():
	"""加载现有的AI配置"""
	var config = config_manager.load_config()
	
	if config.is_empty():
		return
	
	# 加载API密钥到快速配置
	if config.has("api_key"):
		quick_key_input.text = config.api_key
		_update_quick_status(true, "当前密钥: " + config_manager.mask_key(config.api_key))
	
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

	if config.has("view_model"):
		var viewc = config.view_model
		view_model_input.text = viewc.get("model", "")
		view_base_url_input.text = viewc.get("base_url", "")
		view_key_input.text = viewc.get("api_key", "")

	if config.has("stt_model"):
		var sttc = config.stt_model
		stt_model_input.text = sttc.get("model", "")
		stt_base_url_input.text = sttc.get("base_url", "")
		stt_key_input.text = sttc.get("api_key", "")

	if config.has("rerank_model"):
		var rerankc = config.rerank_model
		rerank_model_input.text = rerankc.get("model", "")
		rerank_base_url_input.text = rerankc.get("base_url", "")
		rerank_key_input.text = rerankc.get("api_key", "")

	_last_saved_detail = _collect_detail_inputs()
	_update_detail_saved_label()

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

	if config.has("view_model"):
		var viewc = config.view_model
		view_model_input.text = viewc.model
		view_base_url_input.text = viewc.base_url
		view_key_input.text = viewc.api_key

	if config.has("stt_model"):
		var sttc = config.stt_model
		stt_model_input.text = sttc.model
		stt_base_url_input.text = sttc.base_url
		stt_key_input.text = sttc.api_key

	if config.has("rerank_model"):
		var rerankc = config.rerank_model
		rerank_model_input.text = rerankc.model
		rerank_base_url_input.text = rerankc.base_url
		rerank_key_input.text = rerankc.api_key

	_last_saved_detail = _collect_detail_inputs()
	_update_detail_saved_label()

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

func _collect_detail_inputs() -> Dictionary:
	return {
		"chat_model": {"model": chat_model_input.text, "base_url": chat_base_url_input.text, "api_key": chat_key_input.text},
		"summary_model": {"model": summary_model_input.text, "base_url": summary_base_url_input.text, "api_key": summary_key_input.text},
		"tts_model": {"model": tts_model_input.text, "base_url": tts_base_url_input.text, "api_key": tts_key_input.text},
		"embedding_model": {"model": embedding_model_input.text, "base_url": embedding_base_url_input.text, "api_key": embedding_key_input.text},
		"view_model": {"model": view_model_input.text, "base_url": view_base_url_input.text, "api_key": view_key_input.text},
		"stt_model": {"model": stt_model_input.text, "base_url": stt_base_url_input.text, "api_key": stt_key_input.text},
		"rerank_model": {"model": rerank_model_input.text, "base_url": rerank_base_url_input.text, "api_key": rerank_key_input.text}
	}

func _is_detail_dirty() -> bool:
	var cur = _collect_detail_inputs()
	var s1 = JSON.stringify(cur)
	var s2 = JSON.stringify(_last_saved_detail)
	return s1 != s2

func _on_detail_field_changed(_new_text: String) -> void:
	_update_detail_dirty_state()

func _update_detail_dirty_state() -> void:
	if _is_detail_dirty():
		detail_status_label.text = "·未保存"
		detail_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_update_detail_saved_label()

func _update_detail_saved_label() -> void:
	detail_status_label.text = "·已保存"
	detail_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
