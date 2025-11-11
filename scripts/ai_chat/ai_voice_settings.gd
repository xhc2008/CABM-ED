# AI 语音设置模块
# 负责：TTS相关功能

extends Node

# UI引用
var voice_enable_checkbox: CheckBox
var voice_volume_slider: HSlider
var voice_volume_label: Label
var voice_reupload_button: Button
var voice_status_label: Label

## 加载语音设置
func load_voice_settings() -> void:
    if not has_node("/root/TTSService"):
        voice_status_label.text = "TTS服务未加载"
        voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
        return
    
    var tts = get_node("/root/TTSService")
    
    voice_enable_checkbox.button_pressed = tts.is_enabled
    voice_volume_slider.value = tts.volume
    update_voice_volume_label(tts.volume)
    
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

## 启用/禁用TTS
func on_voice_enable_toggled(enabled: bool) -> void:
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

## 音量改变
func on_voice_volume_changed(value: float) -> void:
    if not has_node("/root/TTSService"):
        return
    
    var tts = get_node("/root/TTSService")
    tts.set_volume(value)
    update_voice_volume_label(value)

## 更新音量显示
func update_voice_volume_label(value: float) -> void:
    voice_volume_label.text = "%d%%" % int(value * 100)

## 声音准备完成
func _on_voice_ready(_voice_uri: String) -> void:
    voice_status_label.text = "✓ TTS已就绪"
    voice_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

## TTS错误
func _on_tts_error(error_message: String) -> void:
    voice_status_label.text = "✗ " + error_message
    voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    push_error("TTS错误: " + error_message)

## 手动重新上传参考音频
func on_voice_reupload_pressed() -> void:
    if not has_node("/root/TTSService"):
        voice_status_label.text = "✗ TTS服务未加载"
        voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
        return
    
    var tts = get_node("/root/TTSService")
    
    # 检查是否已启用
    if not tts.is_enabled:
        voice_status_label.text = "⚠ 请先启用TTS"
        voice_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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

## 样式化语音启用复选框
func style_voice_checkbox() -> void:
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
