extends Area2D
class_name Bullet

# 子弹系统 - 处理子弹物理和碰撞检测（防止隧道效应）

var speed: float = 1000.0  # 子弹速度
var direction: Vector2 = Vector2.ZERO
var damage: int = 0
var max_distance: float = 2000.0  # 最大射程
var traveled_distance: float = 0.0

# 上一帧的位置（用于防止隧道效应）
var last_position: Vector2 = Vector2.ZERO

# 碰撞检测
var collision_shape: CollisionShape2D
var sprite: Sprite2D

# 子弹击中效果
const SPARK_SCENE = preload("res://scenes/spark_effect.tscn")

func _ready():
	collision_shape = $CollisionShape2D
	sprite = $Sprite2D
	
	# 设置碰撞层
	collision_layer = 0
	collision_mask = 1  # 只与地形碰撞
	
	# 如果碰撞形状没有设置，创建一个
	if not collision_shape.shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 2.0
		collision_shape.shape = circle_shape
	
	# 创建简单的子弹图形
	if sprite:
		var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.YELLOW)
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture
		sprite.scale = Vector2(1, 1)
	
	# 连接碰撞信号
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func setup(start_pos: Vector2, dir: Vector2, _player_rot: float, weapon_cfg: Dictionary):
	"""初始化子弹"""
	global_position = start_pos
	last_position = start_pos
	direction = dir.normalized()
	
	# 设置子弹属性
	damage = weapon_cfg.get("damage", 10)
	speed = 2000.0  # 更快的速度
	
	# 设置旋转
	rotation = direction.angle()
	
	# 设置生命周期（根据射程）
	max_distance = 2000.0
	
	# 设置子弹外观为更细长的形状
	if sprite:
		sprite.scale = Vector2(3.0, 0.5)  # 细长的子弹

func _physics_process(delta):
	var movement = direction * speed * delta
	var new_position = global_position + movement
	var move_distance = movement.length()

	var space_state = get_world_2d().direct_space_state
	var ray_terrain = PhysicsRayQueryParameters2D.create(last_position, new_position)
	ray_terrain.collision_mask = 1
	ray_terrain.exclude = [self]
	var hit_terrain = space_state.intersect_ray(ray_terrain)
	var hit_enemy_point: Vector2 = Vector2.ZERO
	var enemy_collider: Object = null
	var steps = int(ceil(move_distance / 8.0))
	for i in range(steps + 1):
		var t = float(i) / float(max(1, steps))
		var p = last_position.lerp(new_position, t)
		var point_q = PhysicsPointQueryParameters2D.new()
		point_q.position = p
		point_q.collision_mask = 2
		point_q.collide_with_areas = true
		point_q.collide_with_bodies = true
		var res = space_state.intersect_point(point_q)
		if not res.is_empty():
			enemy_collider = res[0].collider
			hit_enemy_point = p
			break
	if enemy_collider != null:
		if enemy_collider.has_method("take_damage"):
			enemy_collider.take_damage(damage)
		_create_hit_effect(hit_enemy_point, -direction)
		queue_free()
		return
	if hit_terrain:
		_on_hit(hit_terrain.position, hit_terrain.normal)
		queue_free()
		return
	
	# 更新位置
	global_position = new_position
	last_position = new_position
	traveled_distance += move_distance
	
	# 检查射程
	if traveled_distance >= max_distance:
		queue_free()

func _on_body_entered(body: Node2D):
	"""碰撞检测"""
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# 创建击中效果
	_create_hit_effect(global_position, -direction)
	queue_free()

func _on_area_entered(_area: Area2D):
	"""区域碰撞检测"""
	# 可以处理特殊区域
	pass

func _on_hit(hit_position: Vector2, hit_normal: Vector2):
	"""击中物体"""
	# 创建击中效果
	_create_hit_effect(hit_position, hit_normal)
	
	# 检查是否击中可伤害对象
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = hit_position
	query.collision_mask = 2  # 假设敌人层为2
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage)

func _create_hit_effect(hit_pos: Vector2, normal: Vector2):
	"""创建击中效果（火花动画）"""
	# 加载火花动画场景
	var spark_scene = load("res://scenes/spark_effect.tscn")
	if spark_scene:
		var spark = spark_scene.instantiate()
		if spark:
			get_tree().current_scene.add_child(spark)
			spark.global_position = hit_pos
			spark.rotation = normal.angle() + PI / 2
