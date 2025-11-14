# AI 回复设置模块
# 负责：回复模式（语言表达/情景叙事）的设置

extends Node

var config_manager: Node
var response_buttons: Dictionary = {}
var response_status_label: Label
var tab_container: TabContainer

# 回复风格配置
var response_styles: Dictionary = {
	"verbal": {
		"name": "语言表达",
		"description": "简洁的对话，保持自然交流风格",
		"status": "当前: 语言表达模式"
	},
	"narrative": {
		"name": "情景叙事", 
		"description": "详细的叙述，包含动作、神态、心理活动等",
		"status": "当前: 情景叙事模式"
	},
	"story": {
		"name": "长篇叙述",
		"description": "长对话，内容更加丰富完整",
		"status": "当前: 长篇叙述模式"
	}
}

func _init(cfg_mgr: Node) -> void:
	config_manager = cfg_mgr

## 创建回复设置选项卡
func setup_response_settings_tab() -> void:
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
	title_label.text = "选择回复风格"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 按钮组
	var button_group = ButtonGroup.new()
	
	# 动态创建风格选项
	for style_key in response_styles:
		_create_style_option(style_key, response_styles[style_key], button_group, vbox)
	
	# 状态标签
	response_status_label = Label.new()
	response_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	response_status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(response_status_label)
	
	# 添加到TabContainer（在"语音设置"之后）
	tab_container.add_child(response_tab)
	# 将回复设置移到第二个位置（快速配置之后）
	tab_container.move_child(response_tab, 2)
	
	# 加载设置
	load_response_settings()

## 创建单个风格选项
func _create_style_option(style_key: String, style_data: Dictionary, button_group: ButtonGroup, parent: Control) -> void:
	# 如果不是第一个选项，添加分隔线
	if response_buttons.size() > 0:
		var separator = HSeparator.new()
		parent.add_child(separator)
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	
	# 创建复选框
	var check_button = CheckBox.new()
	check_button.text = style_data.name
	check_button.button_group = button_group
	check_button.toggled.connect(_on_response_mode_changed.bind(style_key))
	container.add_child(check_button)
	
	# 创建描述标签
	var desc_label = Label.new()
	desc_label.text = style_data.description
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.add_theme_font_size_override("font_size", 12)
	container.add_child(desc_label)
	
	parent.add_child(container)
	response_buttons[style_key] = check_button

## 加载回复设置
func load_response_settings() -> void:
	var response_mode = config_manager.load_response_mode()
	
	# 确保模式有效，否则使用默认值
	if not response_styles.has(response_mode):
		response_mode = "verbal"
	
	# 设置按钮状态
	for style_key in response_buttons:
		response_buttons[style_key].button_pressed = (style_key == response_mode)
	
	# 更新状态标签
	response_status_label.text = response_styles[response_mode].status
	response_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

## 回复模式改变
func _on_response_mode_changed(enabled: bool, mode: String) -> void:
	if not enabled:
		return
	
	# 保存设置
	if config_manager.save_response_mode(mode):
		response_status_label.text = "✓ 已切换到" + response_styles[mode].name
		response_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		response_status_label.text = "✗ 保存失败"
		response_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

## 获取当前回复风格配置
func get_current_response_style() -> Dictionary:
	var current_mode = config_manager.load_response_mode()
	if not response_styles.has(current_mode):
		current_mode = "verbal"
	return response_styles[current_mode]

## 获取所有可用风格（用于其他模块）
func get_available_styles() -> Array:
	return response_styles.keys()