extends Node

# 输入处理模块
# 负责处理键盘和鼠标输入事件

signal continue_requested

var parent_dialog: Panel
var waiting_for_continue: bool = false
var last_continue_time: float = 0.0
const CONTINUE_COOLDOWN: float = 0.3  # 300ms防抖

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
			# 防抖：检查距离上次点击的时间
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_continue_time < CONTINUE_COOLDOWN:
				print("点击过快，忽略（距上次 %.3f 秒）" % (current_time - last_continue_time))
				get_viewport().set_input_as_handled()
				return
			
			last_continue_time = current_time
			continue_requested.emit()
			get_viewport().set_input_as_handled()

func set_waiting_for_continue(waiting: bool):
	waiting_for_continue = waiting

func setup(dialog: Panel):
	parent_dialog = dialog
