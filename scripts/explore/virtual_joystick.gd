extends Control
class_name VirtualJoystick

signal direction_changed(direction: Vector2)

@export var joystick_radius: float = 60.0
@export var stick_radius: float = 25.0
@export var dead_zone: float = 0.2

var is_pressed: bool = false
var touch_index: int = -1
var center_position: Vector2
var current_direction: Vector2 = Vector2.ZERO

@onready var base: Control = $Base
@onready var stick: Control = $Base/Stick

func _ready():
	center_position = base.position + base.size / 2
	stick.position = base.size / 2 - stick.size / 2
	
	# 设置透明度
	modulate.a = 0.6

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			is_pressed = true
			touch_index = event.index
			_update_stick_position(event.position)
		elif event.index == touch_index:
			_release_stick()
	
	elif event is InputEventScreenDrag:
		if is_pressed and event.index == touch_index:
			_update_stick_position(event.position)
	
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_pressed = true
			_update_stick_position(event.position)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_release_stick()
	
	elif event is InputEventMouseMotion:
		if is_pressed:
			_update_stick_position(event.position)

func _update_stick_position(touch_pos: Vector2):
	var local_pos = touch_pos - center_position
	var distance = local_pos.length()
	
	# 限制摇杆范围
	if distance > joystick_radius:
		local_pos = local_pos.normalized() * joystick_radius
		distance = joystick_radius
	
	# 更新摇杆位置
	stick.position = base.size / 2 + local_pos - stick.size / 2
	
	# 计算方向（归一化）
	var normalized_distance = distance / joystick_radius
	if normalized_distance > dead_zone:
		current_direction = local_pos.normalized() * ((normalized_distance - dead_zone) / (1.0 - dead_zone))
	else:
		current_direction = Vector2.ZERO
	
	direction_changed.emit(current_direction)

func _release_stick():
	is_pressed = false
	touch_index = -1
	
	# 摇杆回中
	var tween = create_tween()
	tween.tween_property(stick, "position", base.size / 2 - stick.size / 2, 0.1)
	
	current_direction = Vector2.ZERO
	direction_changed.emit(current_direction)

func get_direction() -> Vector2:
	return current_direction
