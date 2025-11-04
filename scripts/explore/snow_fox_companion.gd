extends CharacterBody2D
class_name SnowFoxCompanion

@export var follow_speed: float = 180.0
@export var min_follow_distance: float = 80.0  # 开始跟随的最小距离
@export var max_follow_distance: float = 400.0  # 传送回来的最大距离
@export var too_close_distance: float = 37.0  # 太近了需要远离
@export var escape_distance: float = 60.0  # 远离到这个距离
@export var reaction_delay: float = 0.15  # 反应延迟（秒）
@export var too_close_time_threshold: float = 2.0  # 靠太近多久后开始远离

var target: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var delayed_target_position: Vector2 = Vector2.ZERO
var time_since_target_moved: float = 0.0
var time_too_close: float = 0.0
var is_escaping: bool = false
var escape_target: Vector2 = Vector2.ZERO

# 雪狐的背包存储
const STORAGE_SIZE = 12
var storage: Array = []

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
	# 初始化存储
	storage.resize(STORAGE_SIZE)
	for i in range(STORAGE_SIZE):
		storage[i] = null
	
	# 配置导航代理
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 10.0
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = 16.0
	
	# 等待第一帧后再设置目标
	call_deferred("_setup_navigation")

func _setup_navigation():
	if target:
		delayed_target_position = target.global_position
		target_position = target.global_position

func set_follow_target(new_target: Node2D):
	target = new_target
	if target:
		delayed_target_position = target.global_position
		target_position = target.global_position

func _physics_process(delta):
	if not target:
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# 如果距离太远，直接传送过去
	if distance_to_target > max_follow_distance:
		global_position = target.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		delayed_target_position = global_position
		time_too_close = 0.0
		is_escaping = false
		return
	
	# 检测目标是否移动
	if target.global_position.distance_to(target_position) > 5.0:
		target_position = target.global_position
		time_since_target_moved = 0.0
	else:
		time_since_target_moved += delta
	
	# 延迟跟随：只有在延迟时间后才更新目标位置
	if time_since_target_moved < reaction_delay:
		delayed_target_position = delayed_target_position.lerp(target_position, delta * 3.0)
	else:
		delayed_target_position = target_position
	
	# 检测是否靠得太近
	if distance_to_target < too_close_distance:
		time_too_close += delta
		if time_too_close > too_close_time_threshold and not is_escaping:
			# 开始远离
			is_escaping = true
			var escape_direction = (global_position - target.global_position).normalized()
			escape_target = target.global_position + escape_direction * escape_distance
			navigation_agent.target_position = escape_target
	else:
		time_too_close = 0.0
		if is_escaping and distance_to_target > escape_distance * 0.8:
			is_escaping = false
	
	# 根据状态决定移动目标
	if is_escaping:
		# 远离模式
		if global_position.distance_to(escape_target) < 10.0:
			is_escaping = false
		else:
			navigation_agent.target_position = escape_target
	elif distance_to_target > min_follow_distance:
		# 跟随模式
		navigation_agent.target_position = delayed_target_position
	else:
		# 距离合适，停止移动
		velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)
		move_and_slide()
		return
	
	# 使用导航代理移动
	if navigation_agent.is_navigation_finished():
		velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)
	else:
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = (next_path_position - global_position).normalized()
		var desired_velocity = direction * follow_speed
		velocity = velocity.lerp(desired_velocity, delta * 8.0)
		
		# 朝向移动方向
		if velocity.length() > 10.0:
			rotation = velocity.angle()
	
	move_and_slide()

func get_storage() -> Array:
	"""获取雪狐的存储"""
	return storage

func set_storage(new_storage: Array):
	"""设置雪狐的存储"""
	storage = new_storage.duplicate()

func get_save_data() -> Dictionary:
	"""获取保存数据"""
	return {
		"storage": storage.duplicate()
	}

func load_save_data(data: Dictionary):
	"""加载保存数据"""
	if data.has("storage"):
		storage = data.storage.duplicate()
