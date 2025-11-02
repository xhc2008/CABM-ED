extends CharacterBody2D
class_name ExplorePlayer

@export var move_speed: float = 200.0

var joystick_direction: Vector2 = Vector2.ZERO

func _ready():
	pass

func set_joystick_direction(direction: Vector2):
	joystick_direction = direction

func _physics_process(_delta):
	var input_vector = Vector2.ZERO
	
	# 优先使用摇杆输入
	if joystick_direction.length() > 0.01:
		input_vector = joystick_direction
	else:
		# WASD 移动输入
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			input_vector.y -= 1
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			input_vector.y += 1
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			input_vector.x -= 1
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			input_vector.x += 1
		
		# 归一化输入向量，避免斜向移动过快
		input_vector = input_vector.normalized()
	
	# 设置速度
	velocity = input_vector * move_speed
	
	# 移动
	move_and_slide()
	
	# 朝向鼠标（仅在非触摸设备或没有使用摇杆时）
	if joystick_direction.length() < 0.01:
		var mouse_pos = get_global_mouse_position()
		look_at(mouse_pos)
	else:
		# 使用摇杆时朝向移动方向
		if input_vector.length() > 0.01:
			look_at(global_position + input_vector)
