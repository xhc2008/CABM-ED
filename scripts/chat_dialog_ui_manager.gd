extends Node

# UI管理模块
# 负责UI模式切换和动画效果

const INPUT_HEIGHT = 120.0
const REPLY_HEIGHT = 200.0
const HISTORY_HEIGHT = 400.0
const ANIMATION_DURATION = 0.3

var parent_dialog: Panel
var character_name_label: Label
var message_label: Label
var input_container: HBoxContainer
var input_field: LineEdit
var send_button: Button
var end_button: Button
var continue_indicator: Label

var is_animating: bool = false

func setup(dialog: Panel, char_label: Label, msg_label: Label, 
		   input_cont: HBoxContainer, input_fld: LineEdit, 
		   send_btn: Button, end_btn: Button, continue_ind: Label):
	parent_dialog = dialog
	character_name_label = char_label
	message_label = msg_label
	input_container = input_cont
	input_field = input_fld
	send_button = send_btn
	end_button = end_btn
	continue_indicator = continue_ind

func transition_to_reply_mode(character_name: String):
	# 第一步：设置状态标志
	parent_dialog.is_input_mode = false
	
	# 第二步：输入容器和结束按钮淡出
	var fade_tween = parent_dialog.create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(input_container, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_tween.tween_property(end_button, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_tween.finished
	
	# 第三步：隐藏输入容器和结束按钮
	input_container.visible = false
	end_button.visible = false
	
	# 第四步：准备回复UI元素（但保持透明）
	character_name_label.visible = true
	message_label.visible = true
	character_name_label.text = character_name
	message_label.text = ""
	character_name_label.modulate.a = 0.0
	message_label.modulate.a = 0.0
	
	# 第五步：高度变化和内容淡入同时进行
	is_animating = true
	var combined_tween = parent_dialog.create_tween()
	combined_tween.set_parallel(true)
	combined_tween.tween_property(parent_dialog, "custom_minimum_size:y", REPLY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(parent_dialog, "size:y", REPLY_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(character_name_label, "modulate:a", 1.0, ANIMATION_DURATION)
	combined_tween.tween_property(message_label, "modulate:a", 1.0, ANIMATION_DURATION)
	await combined_tween.finished
	is_animating = false

func transition_to_input_mode():
	# 第一步：设置状态标志
	parent_dialog.is_input_mode = true
	parent_dialog.waiting_for_continue = false
	
	# 第二步：回复内容淡出
	var fade_tween = parent_dialog.create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(character_name_label, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	fade_tween.tween_property(message_label, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
	await fade_tween.finished
	
	# 第三步：隐藏回复UI元素
	character_name_label.visible = false
	message_label.visible = false
	
	# 第四步：准备输入容器和结束按钮（但保持透明）
	continue_indicator.visible = false
	input_container.visible = true
	end_button.visible = true
	input_field.text = ""
	input_field.placeholder_text = "输入消息..."
	input_container.modulate.a = 0.0
	end_button.modulate.a = 0.0
	
	# 第五步：高度变化和输入容器、结束按钮淡入同时进行
	is_animating = true
	var combined_tween = parent_dialog.create_tween()
	combined_tween.set_parallel(true)
	combined_tween.tween_property(parent_dialog, "custom_minimum_size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(parent_dialog, "size:y", INPUT_HEIGHT, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	combined_tween.tween_property(input_container, "modulate:a", 1.0, ANIMATION_DURATION)
	combined_tween.tween_property(end_button, "modulate:a", 1.0, ANIMATION_DURATION)
	
	await combined_tween.finished
	is_animating = false
	
	input_field.grab_focus()

func show_continue_indicator():
	continue_indicator.visible = true
	continue_indicator.modulate.a = 0.0
	
	var fade_tween = parent_dialog.create_tween()
	fade_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.3)
	await fade_tween.finished
	
	_start_indicator_blink()

func hide_continue_indicator():
	continue_indicator.visible = false

func _start_indicator_blink():
	var blink_tween = parent_dialog.create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.6)
	blink_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.6)
