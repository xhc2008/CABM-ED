extends Control

signal costume_selected(costume_id: String)
signal close_requested

var costume_list: VBoxContainer
var close_button: Button
var title_label: Label

var available_costumes: Array = []

func _ready():
	_create_ui()
	_load_costumes()

func _create_ui():
	"""创建UI"""
	# 半透明背景
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 主面板
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(600, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -panel.custom_minimum_size / 2
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# 标题
	title_label = Label.new()
	title_label.text = "选择服装"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 服装列表（滚动容器）
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	costume_list = VBoxContainer.new()
	costume_list.add_theme_constant_override("separation", 10)
	costume_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(costume_list)
	
	# 关闭按钮
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _load_costumes():
	"""加载所有可用的服装配置"""
	available_costumes.clear()
	
	var dir = DirAccess.open("res://config/character_presets")
	if not dir:
		push_error("无法打开服装配置目录")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var config_path = "res://config/character_presets/" + file_name
			var costume_data = _load_costume_config(config_path)
			if costume_data.size() > 0:
				available_costumes.append(costume_data)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# 按ID排序
	available_costumes.sort_custom(func(a, b): return a.id < b.id)
	
	# 创建UI元素
	_populate_costume_list()

func _load_costume_config(config_path: String) -> Dictionary:
	"""加载单个服装配置"""
	if not FileAccess.file_exists(config_path):
		return {}
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("解析服装配置失败: " + config_path)
		return {}
	
	var data = json.data
	if not data.has("id") or not data.has("name"):
		push_error("服装配置缺少必要字段: " + config_path)
		return {}
	
	return data

func _populate_costume_list():
	"""填充服装列表"""
	# 清空现有列表
	for child in costume_list.get_children():
		child.queue_free()
	
	# 获取当前服装ID
	var current_costume_id = _get_current_costume_id()
	
	# 为每个服装创建按钮
	for costume_data in available_costumes:
		var costume_button = _create_costume_button(costume_data, costume_data.id == current_costume_id)
		costume_list.add_child(costume_button)

func _create_costume_button(costume_data: Dictionary, is_current: bool) -> Button:
	"""创建服装按钮"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 60)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# 按钮文本
	var button_text = costume_data.name
	if costume_data.has("description") and costume_data.description != "":
		button_text += "\n" + costume_data.description
	
	if is_current:
		button_text += " [当前]"
		button.disabled = true
	
	button.text = button_text
	
	# 连接信号
	if not is_current:
		button.pressed.connect(func(): _on_costume_button_pressed(costume_data.id))
	
	return button

func _get_current_costume_id() -> String:
	"""获取当前服装ID"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		return save_mgr.get_costume_id()
	return "default"

func _on_costume_button_pressed(costume_id: String):
	"""服装按钮点击"""
	print("选择服装: ", costume_id)
	costume_selected.emit(costume_id)
	_close()

func _on_close_pressed():
	"""关闭按钮点击"""
	close_requested.emit()
	_close()

func _close():
	"""关闭界面"""
	queue_free()
