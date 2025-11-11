# AI 回复设置模块
# 负责：回复模式（语言表达/情景叙事）的设置

extends Node

var config_manager: Node
var response_verbal_button: CheckBox
var response_narrative_button: CheckBox
var response_status_label: Label
var tab_container: TabContainer

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

## 加载回复设置
func load_response_settings() -> void:
    var response_mode = config_manager.load_response_mode()
    
    # 设置按钮状态
    if response_mode == "narrative":
        response_narrative_button.button_pressed = true
        response_status_label.text = "当前: 情景叙事模式"
    else:
        response_verbal_button.button_pressed = true
        response_status_label.text = "当前: 语言表达模式"
    
    response_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

## 回复模式改变
func _on_response_mode_changed(enabled: bool, mode: String) -> void:
    if not enabled:
        return
    
    # 保存设置
    if config_manager.save_response_mode(mode):
        if mode == "narrative":
            response_status_label.text = "✓ 已切换到情景叙事模式"
        else:
            response_status_label.text = "✓ 已切换到语言表达模式"
        response_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
    else:
        response_status_label.text = "✗ 保存失败"
        response_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
