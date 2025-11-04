extends Control
class_name VirtualJoystick

signal direction_changed(direction: Vector2)

@export var joystick_radius: float = 100.0  # 增大摇杆半径
@export var stick_radius: float = 40.0      # 增大摇杆手柄半径
@export var dead_zone: float = 0.1          # 减小死区
@export var touch_area_multiplier: float = 2.0  # 触摸区域倍数

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
	
	# 增大触摸区域
	custom_minimum_size = Vector2(joystick_radius * 2 * touch_area_multiplier, joystick_radius * 2 * touch_area_multiplier)

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and _is_in_touch_area(event.position):
			is_pressed = true
			touch_index = event.index
			_update_stick_position(event.position)
		elif event.index == touch_index:
			_release_stick()
	
	elif event is InputEventScreenDrag:
		if is_pressed and event.index == touch_index:
			_update_stick_position(event.position)
	
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _is_in_touch_area(event.position):
			is_pressed = true
			_update_stick_position(event.position)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_release_stick()
	
	elif event is InputEventMouseMotion:
		if is_pressed:
			_update_stick_position(event.position)

# 检查是否在触摸区域内
func _is_in_touch_area(touch_pos: Vector2) -> bool:
	var local_pos = touch_pos - global_position
	var distance = local_pos.length()
	return distance <= joystick_radius * touch_area_multiplier

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
	
	# 改进的死区处理
	if normalized_distance > dead_zone:
		# 应用平滑曲线，让摇杆响应更自然
		var t = (normalized_distance - dead_zone) / (1.0 - dead_zone)
		current_direction = local_pos.normalized() * t
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

# 添加一个方法来获取原始向量（未应用死区）
func get_raw_direction() -> Vector2:
	if is_pressed:
		var stick_pos = stick.position + stick.size / 2 - base.size / 2
		return stick_pos.normalized()
	return Vector2.ZERO