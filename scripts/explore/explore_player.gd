extends CharacterBody2D
class_name ExplorePlayer

@export var move_speed: float = 200.0

func _ready():
	pass

func _physics_process(_delta):
	# WASD 移动输入
	var input_vector = Vector2.ZERO
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
	
	# 朝向鼠标
	var mouse_pos = get_global_mouse_position()
	look_at(mouse_pos)
