extends CharacterBody2D
class_name ExplorePlayer

@export var move_speed: float = 200.0

# 使用 VirtualJoystick 插件
@export var joystick_left : VirtualJoystick  # 移动摇杆
@export var joystick_right : VirtualJoystick  # 可选：用于旋转的摇杆

var joystick_direction: Vector2 = Vector2.ZERO
var interaction_detector: Node  # InteractionDetector

func _ready():
	# 添加交互检测器
	var detector_script = load("res://scripts/explore/interaction_detector.gd")
	interaction_detector = detector_script.new()
	interaction_detector.detection_radius = 80.0
	add_child(interaction_detector)

func _physics_process(_delta):
	var input_vector = Vector2.ZERO
	
	# 优先使用 VirtualJoystick 插件输入
	if joystick_left and joystick_left.is_pressed:
		input_vector = joystick_left.output
		joystick_direction = input_vector
	else:
		# 备用：WASD 移动输入
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
		joystick_direction = Vector2.ZERO
	
	# 设置速度
	velocity = input_vector * move_speed
	
	# 移动
	move_and_slide()
	
	# 朝向控制
	# 优先使用右摇杆控制朝向
	if joystick_right and joystick_right.is_pressed:
		rotation = joystick_right.output.angle()
	elif joystick_direction.length() > 0.01:
		# 使用左摇杆移动方向作为朝向
		look_at(global_position + input_vector)
	else:
		# 备用：朝向鼠标（仅在非触摸设备时）
		var mouse_pos = get_global_mouse_position()
		look_at(mouse_pos)
