extends CharacterBody2D
class_name ExplorePlayer

@export var move_speed: float = 200.0
@export var max_health: int = 100
var health: int = 100
signal health_changed(current: int, max: int)
signal player_hit(damage: int)
signal player_died()

# 使用 VirtualJoystick 插件
@export var joystick_left : VirtualJoystick  # 移动摇杆
@export var joystick_right : VirtualJoystick  # 可选：用于旋转的摇杆

var joystick_direction: Vector2 = Vector2.ZERO
var interaction_detector: Node  # InteractionDetector

# 武器系统
var weapon_system: Node  # WeaponSystem
var aim_direction: Vector2 = Vector2.RIGHT  # 瞄准方向
var is_mobile: bool = false  # 是否为移动设备

# 瞄准辅助线
var aim_line: Line2D
var aim_line_length: float = 200.0

func _ready():
	# 添加交互检测器
	var detector_script = load("res://scripts/explore/interaction_detector.gd")
	interaction_detector = detector_script.new()
	interaction_detector.detection_radius = 80.0
	add_child(interaction_detector)

	health = max_health
	
	# 检测是否为移动设备
	_detect_platform()
	
	# 创建瞄准辅助线
	_create_aim_line()
	
	# 初始化武器系统（由explore_scene设置）
	# weapon_system将在explore_scene中设置

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
	
	# 瞄准和朝向控制
	_update_aim_direction()
	
	# 更新瞄准辅助线
	_update_aim_line()

func take_damage(amount: int):
	if health <= 0:
		return
	amount = int(max(0, amount))
	if amount <= 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	player_hit.emit(amount)
	if health <= 0:
		player_died.emit()

func _update_aim_direction():
	"""更新瞄准方向"""
	if is_mobile:
		# 移动设备：使用右摇杆控制瞄准
		if joystick_right and joystick_right.is_pressed:
			var joystick_output = joystick_right.output
			if joystick_output.length() > 0.1:
				aim_direction = joystick_output.normalized()
				rotation = aim_direction.angle()
		elif joystick_direction.length() > 0.01:
			# 如果没有右摇杆输入，使用移动方向作为朝向
			aim_direction = joystick_direction.normalized()
			rotation = aim_direction.angle()
	else:
		# 电脑：朝向鼠标
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		
		# 确保方向向量有效
		if direction_to_mouse.length() > 0.01:
			aim_direction = direction_to_mouse
			rotation = aim_direction.angle()

func _detect_platform():
	"""检测平台类型"""
	# 使用统一的平台管理器
	is_mobile = PlatformManager.is_mobile_platform()
	
	# 如果检测到触摸输入，也认为是移动设备
	if Input.get_connected_joypads().size() > 0:
		is_mobile = true

func _create_aim_line():
	"""创建瞄准辅助线"""
	aim_line = Line2D.new()
	aim_line.width = 2.0
	aim_line.default_color = Color(1.0, 0.1, 0.0, 0.25)
	aim_line.z_index = 1
	
	# 关键：设置使用全局坐标
	aim_line.top_level = true
	aim_line.global_position = Vector2.ZERO
	
	aim_line.add_point(Vector2.ZERO)
	aim_line.add_point(Vector2.ZERO)
	add_child(aim_line)

func _update_aim_line():
	"""更新瞄准辅助线"""
	if not aim_line:
		return
	
	# 只在有武器时显示
	var show_line = false
	if weapon_system and weapon_system.has_method("is_weapon_equipped"):
		show_line = weapon_system.is_weapon_equipped()
	
	aim_line.visible = show_line
	
	if show_line:
		aim_line.clear_points()
		
		# 关键：使用全局坐标计算
		var start_pos = global_position
		var end_pos = start_pos + aim_direction * aim_line_length
		
		aim_line.add_point(start_pos)
		aim_line.add_point(end_pos)

func setup_weapon_system(weapon_sys: Node):
	"""设置武器系统"""
	weapon_system = weapon_sys

func get_aim_direction() -> Vector2:
	"""获取瞄准方向"""
	return aim_direction

func get_shoot_position() -> Vector2:
	"""获取射击位置（角色前方）"""
	return global_position + aim_direction * 20.0  # 在角色前方20像素处

func get_interaction_detector() -> Node:
	"""获取交互检测器"""
	return interaction_detector
