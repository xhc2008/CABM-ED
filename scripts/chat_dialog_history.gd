extends Node

# 历史记录模块
# 负责对话历史的显示和管理

const HISTORY_HEIGHT = 400.0
const ANIMATION_DURATION = 0.3

var parent_dialog: Panel
var vbox: VBoxContainer
var input_container: HBoxContainer
var input_field: LineEdit
var send_button: Button
var end_button: Button
var history_button: Button

var history_panel: Panel
var history_scroll: ScrollContainer
var history_vbox: VBoxContainer
var is_history_visible: bool = false
var is_animating: bool = false

func setup(dialog: Panel, main_vbox: VBoxContainer, input_cont: HBoxContainer,
		   input_fld: LineEdit, send_btn: Button, end_btn: Button, hist_btn: Button):
	parent_dialog = dialog
	vbox = main_vbox
	input_container = input_cont
	input_field = input_fld
	send_button = send_btn
	end_button = end_btn
	history_button = hist_btn
	
	_create_history_panel()

func _create_history_panel():
	history_panel = Panel.new()
	history_panel.name = "HistoryPanel"
	history_panel.visible = false
	history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var input_index = input_container.get_index()
	vbox.add_child(history_panel)
	vbox.move_child(history_panel, input_index)
	
	var history_margin = MarginContainer.new()
	history_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	history_margin.add_theme_constant_override("margin_left", 10)
	history_margin.add_theme_constant_override("margin_top", 10)
	history_margin.add_theme_constant_override("margin_right", 10)
	history_margin.add_theme_constant_override("margin_bottom", 10)
	history_panel.add_child(history_margin)
	
	var history_main_vbox = VBoxContainer.new()
	history_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_main_vbox.add_theme_constant_override("separation", 8)
	history_margin.add_child(history_main_vbox)
	
	var history_title = Label.new()
	history_title.text = "对话历史"
	history_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_main_vbox.add_child(history_title)
	
	var separator = HSeparator.new()
	history_main_vbox.add_child(separator)
	
	history_scroll = ScrollContainer.new()
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_scroll.custom_minimum_size.y = 250
	history_main_vbox.add_child(history_scroll)
	
	history_vbox = VBoxContainer.new()
	history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_vbox.add_theme_constant_override("separation", 5)
	history_scroll.add_child(history_vbox)

func toggle_history():
	if is_history_visible:
		hide_history()
	else:
		show_history()

func show_history():
	if is_animating:
		return
	
	_update_history_content()
	
	var fade_out_tween = parent_dialog.create_tween()
	fade_out_tween.set_parallel(true)
	fade_out_tween.tween_property(input_field, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_out_tween.tween_property(send_button, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_out_tween.tween_property(end_button, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_out_tween.tween_property(history_button, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_out_tween.finished
	
	input_field.visible = false
	send_button.visible = false
	end_button.visible = false
	
	history_button.text = "返回"
	
	history_panel.visible = true
	history_panel.modulate.a = 0.0
	
	is_animating = true
	is_history_visible = true
	
	var expand_tween = parent_dialog.create_tween()
	expand_tween.set_parallel(true)
	expand_tween.tween_property(parent_dialog, "custom_minimum_size:y", HISTORY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	expand_tween.tween_property(parent_dialog, "size:y", HISTORY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	expand_tween.tween_property(history_panel, "modulate:a", 1.0, ANIMATION_DURATION)
	
	await expand_tween.finished
	
	history_button.modulate.a = 0.0
	var button_fade_in = parent_dialog.create_tween()
	button_fade_in.tween_property(history_button, "modulate:a", 1.0, ANIMATION_DURATION * 0.5)
	await button_fade_in.finished
	
	is_animating = false
	
	await parent_dialog.get_tree().process_frame
	history_scroll.scroll_vertical = int(history_scroll.get_v_scroll_bar().max_value)

func hide_history():
	if is_animating:
		return
	
	is_animating = true
	is_history_visible = false
	
	var button_fade_out = parent_dialog.create_tween()
	button_fade_out.tween_property(history_button, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await button_fade_out.finished
	
	var fade_out_tween = parent_dialog.create_tween()
	fade_out_tween.tween_property(history_panel, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_out_tween.finished
	
	history_panel.visible = false
	
	var collapse_tween = parent_dialog.create_tween()
	collapse_tween.set_parallel(true)
	collapse_tween.tween_property(parent_dialog, "custom_minimum_size:y", 120.0, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	collapse_tween.tween_property(parent_dialog, "size:y", 120.0, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await collapse_tween.finished
	
	history_button.text = "历史"
	
	input_field.visible = true
	send_button.visible = true
	end_button.visible = true
	input_field.modulate.a = 0.0
	send_button.modulate.a = 0.0
	end_button.modulate.a = 0.0
	history_button.modulate.a = 0.0
	
	var fade_in_tween = parent_dialog.create_tween()
	fade_in_tween.set_parallel(true)
	fade_in_tween.tween_property(input_field, "modulate:a", 1.0, ANIMATION_DURATION * 0.5)
	fade_in_tween.tween_property(send_button, "modulate:a", 1.0, ANIMATION_DURATION * 0.5)
	fade_in_tween.tween_property(end_button, "modulate:a", 1.0, ANIMATION_DURATION * 0.5)
	fade_in_tween.tween_property(history_button, "modulate:a", 1.0, ANIMATION_DURATION * 0.5)
	
	await fade_in_tween.finished
	is_animating = false

func _update_history_content():
	for child in history_vbox.get_children():
		child.queue_free()
	
	if not parent_dialog.has_node("/root/AIService"):
		var empty_label = Label.new()
		empty_label.text = "暂无对话历史"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		history_vbox.add_child(empty_label)
		return
	
	var ai_service = parent_dialog.get_node("/root/AIService")
	var conversation = ai_service.current_conversation
	
	if conversation.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无对话历史"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		history_vbox.add_child(empty_label)
		return
	
	var save_mgr = parent_dialog.get_node("/root/SaveManager")
	var character_name = save_mgr.get_character_name() if save_mgr else "角色"
	var user_name = save_mgr.get_user_name() if save_mgr else "用户"
	
	for msg in conversation:
		var history_item = Label.new()
		history_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var speaker_name = ""
		var content = msg.content
		
		if msg.role == "user":
			speaker_name = user_name
		elif msg.role == "assistant":
			speaker_name = character_name
			var clean_content = content
			if clean_content.contains("```json"):
				var json_start = clean_content.find("```json") + 7
				clean_content = clean_content.substr(json_start)
			elif clean_content.contains("```"):
				var json_start = clean_content.find("```") + 3
				clean_content = clean_content.substr(json_start)
			
			if clean_content.contains("```"):
				var json_end = clean_content.find("```")
				clean_content = clean_content.substr(0, json_end)
			
			clean_content = clean_content.strip_edges()
			
			var json = JSON.new()
			if json.parse(clean_content) == OK:
				var data = json.data
				if data.has("msg"):
					content = data.msg
		else:
			continue
		
		history_item.text = "%s：%s" % [speaker_name, content]
		history_vbox.add_child(history_item)
