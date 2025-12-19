extends Control
class_name MobileUI

# 移动端UI - 包含摇杆和射击/换弹控制

@onready var joystick: VirtualJoystick = $VirtualJoystick
@onready var shoot_area: Control = $ShootArea
@onready var shoot_area2: Control = $ShootArea2
@onready var reload_area: Control = $ReloadArea
@onready var chat_button: Button = $ChatButton

# 按钮背景面板引用
@onready var shoot_bg: Panel = $ShootArea/Background
@onready var shoot_bg2: Panel = $ShootArea2/Background
@onready var reload_bg: Panel = $ReloadArea/Background

# 触摸追踪
var shoot_touches: Dictionary = {}  # touch_index -> true
var reload_touch_index: int = -1

signal shoot_started()
signal shoot_stopped()
signal reload_pressed()
signal chat_button_pressed()

var is_shooting: bool = false

func _ready():
	# 只在移动设备上显示
	visible = PlatformManager.is_mobile_platform()
	
	# 存储原始样式
	_store_original_styles()
	
	# 连接聊天按钮
	if chat_button:
		chat_button.pressed.connect(_on_chat_button_pressed)

func get_joystick() -> VirtualJoystick:
	"""获取摇杆引用"""
	return joystick

func _input(event: InputEvent):
	if not visible:
		return
	
	if event is InputEventScreenTouch:
		var touch_pos = event.position
		
		if event.pressed:
			# 检查射击区域1
			if shoot_area and _is_point_in_control(touch_pos, shoot_area):
				shoot_touches[event.index] = true
				_apply_press_feedback(shoot_bg)
				if not is_shooting:
					is_shooting = true
					shoot_started.emit()
				get_viewport().set_input_as_handled()
			
			# 检查射击区域2
			elif shoot_area2 and _is_point_in_control(touch_pos, shoot_area2):
				shoot_touches[event.index] = true
				_apply_press_feedback(shoot_bg2)
				if not is_shooting:
					is_shooting = true
					shoot_started.emit()
				get_viewport().set_input_as_handled()
			
			# 检查换弹区域
			elif reload_area and _is_point_in_control(touch_pos, reload_area):
				reload_touch_index = event.index
				_apply_press_feedback(reload_bg)
				reload_pressed.emit()
				get_viewport().set_input_as_handled()
		else:
			# 释放触摸
			if shoot_touches.has(event.index):
				shoot_touches.erase(event.index)
				_apply_release_feedback(shoot_bg)
				_apply_release_feedback(shoot_bg2)
				if shoot_touches.is_empty() and is_shooting:
					is_shooting = false
					shoot_stopped.emit()
				get_viewport().set_input_as_handled()
			
			if reload_touch_index == event.index:
				reload_touch_index = -1
				_apply_release_feedback(reload_bg)
				get_viewport().set_input_as_handled()

func _is_point_in_control(point: Vector2, control: Control) -> bool:
	"""检查点是否在控件内"""
	if not control or not control.visible:
		return false
	
	var rect = control.get_global_rect()
	return rect.has_point(point)

func is_shooting_active() -> bool:
	"""是否正在射击"""
	return is_shooting

func _on_chat_button_pressed():
	"""聊天按钮点击（移动端）"""
	chat_button_pressed.emit()

# 点击反馈相关
var original_styles: Dictionary = {}

func _store_original_styles():
	"""存储原始样式"""
	if shoot_bg:
		original_styles["shoot"] = shoot_bg.get_theme_stylebox("panel").duplicate()
	if shoot_bg2:
		original_styles["shoot2"] = shoot_bg2.get_theme_stylebox("panel").duplicate()
	if reload_bg:
		original_styles["reload"] = reload_bg.get_theme_stylebox("panel").duplicate()

func _apply_press_feedback(panel: Panel):
	"""应用按下反馈效果"""
	if not panel:
		return
	
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var pressed_style = style.duplicate()
		pressed_style.bg_color = Color(0.7, 0.7, 0.7, 0.5)  # 更亮
		panel.add_theme_stylebox_override("panel", pressed_style)
		
		# 缩放动画
		var tween = create_tween()
		tween.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.1)

func _apply_release_feedback(panel: Panel):
	"""应用释放反馈效果"""
	if not panel:
		return
	
	# 恢复原始样式
	var key = ""
	if panel == shoot_bg:
		key = "shoot"
	elif panel == shoot_bg2:
		key = "shoot2"
	elif panel == reload_bg:
		key = "reload"
	
	if key in original_styles:
		panel.add_theme_stylebox_override("panel", original_styles[key].duplicate())
	
	# 恢复缩放
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)
