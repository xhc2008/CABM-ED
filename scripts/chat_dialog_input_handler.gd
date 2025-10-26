extends Node

# 输入处理模块
# 负责处理键盘和鼠标输入事件

signal continue_requested

var parent_dialog: Panel
var waiting_for_continue: bool = false

func _ready():
	set_process_input(true)

func _input(event):
	if not parent_dialog or not parent_dialog.visible:
		return
	
	# 在等待继续状态时，支持多种输入方式继续
	if waiting_for_continue:
		var should_continue = false
		
		# 鼠标左键点击
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				should_continue = true
		
		# 空格键或F键
		elif event is InputEventKey:
			if event.pressed and not event.echo:
				if event.keycode == KEY_SPACE or event.keycode == KEY_F:
					should_continue = true
		
		if should_continue:
			continue_requested.emit()
			get_viewport().set_input_as_handled()

func set_waiting_for_continue(waiting: bool):
	waiting_for_continue = waiting

func setup(dialog: Panel):
	parent_dialog = dialog
