extends CharacterBody2D
class_name BasicEnemy

signal died

var enemy_type: String = "basic"
var max_health: int = 60
var health: int = 60
var move_speed: float = 120.0
var attack_range: float = 48.0
var attack_damage: int = 12
var follow_range: float = 240.0
var fov_angle: float = deg_to_rad(90)
var state: String = "idle"
var player: ExplorePlayer
var drop_system: Node
var health_bar: ColorRect
var health_label: Label
var sprite: Sprite2D
var last_turn_time: float = 0.0
var attack_cooldown: float = 1.2
var last_attack_time: float = -999.0
var facing: Vector2 = Vector2.RIGHT
var drop_table: Array = []
var is_active: bool = true  # 是否处于活动状态（分区加载用）

# 新增的游荡逻辑变量
var idle_timer: float = 0.0
var current_idle_action: String = ""
var idle_target_rotation: float = 0.0
var idle_move_speed: float = 0.0
var idle_move_duration: float = 0.0
var idle_move_time: float = 0.0

func _ready():
	_load_config()

	# 设置图层在前景之上
	z_index = 1

	var shape = CircleShape2D.new()
	shape.radius = 18.0
	var cs = CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	set_collision_layer(0)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	sprite = Sprite2D.new()
	sprite.centered = true
	var tex_path = "res://assets/images/explore/enemies/basic.png"
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	# 创建自定义血条节点
	health_bar = ColorRect.new()
	health_bar.size = Vector2(40, 4)
	health_bar.position = Vector2(-20, -28)
	health_bar.color = Color(1, 0, 0)  # 红色

	# 添加背景
	var health_bg = ColorRect.new()
	health_bg.size = Vector2(40, 4)
	health_bg.position = Vector2(-20, -28)
	health_bg.color = Color(0.3, 0.3, 0.3)  # 深灰色背景
	add_child(health_bg)
	add_child(health_bar)

	randomize()

func set_active(active: bool):
	"""设置敌人是否处于活动状态"""
	is_active = active
	set_physics_process(active)
	set_process(active)

	# 隐藏/显示血条
	if health_bar:
		health_bar.visible = active
	if health_bar and health_bar.get_parent() and health_bar.get_parent().has_method("get_child"):
		# 找到血条背景并同步显示
		for child in get_children():
			if child is ColorRect and child != health_bar and child.color == Color(0.3, 0.3, 0.3):
				child.visible = active
				break

func set_player(p: ExplorePlayer):
	player = p

func set_drop_system(ds: Node):
	drop_system = ds

func _physics_process(delta):
	if not player or not is_instance_valid(player):
		return
	var to_player = player.global_position - global_position
	if to_player.length() > 0.01:
		facing = to_player.normalized() if state == "chase" else facing
	if _in_detection(to_player):
		state = "chase"
		_move_towards(player.global_position, delta)
		if to_player.length() <= attack_range:
			_attack_if_ready()
	else:
		_idle_behavior(delta)
	# 只在物理空间有效时移动
	if get_world_2d() and get_world_2d().direct_space_state:
		move_and_slide()

func _in_detection(to_player: Vector2) -> bool:
	var dist = to_player.length()
	var angle_ok = abs(facing.angle_to(to_player.normalized())) <= fov_angle * 0.5
	if angle_ok:
		return dist <= follow_range
	return dist <= 48.0

func _move_towards(target: Vector2, delta: float):
	var dir = (target - global_position).normalized()
	velocity = dir * move_speed
	sprite.rotation = dir.angle()

func _idle_behavior(delta: float):
	if current_idle_action == "":
		# 选择新的行为
		_choose_new_idle_action()
		return
	
	if current_idle_action == "pause":
		idle_timer -= delta
		if idle_timer <= 0:
			current_idle_action = ""
			velocity = Vector2.ZERO
	
	elif current_idle_action == "move":
		idle_move_time += delta
		
		# 平滑转向
		var current_angle = sprite.rotation
		var target_angle = idle_target_rotation
		
		# 计算最短的旋转方向
		var angle_diff = fmod(target_angle - current_angle + PI, PI * 2) - PI
		var rotation_step = sign(angle_diff) * delta * 2.0  # 调整旋转速度
		
		if abs(angle_diff) > abs(rotation_step):
			sprite.rotation += rotation_step
		else:
			sprite.rotation = target_angle
			# 转向完成后开始移动
			facing = Vector2(cos(idle_target_rotation), sin(idle_target_rotation))
			velocity = facing * idle_move_speed
		
		# 移动时间结束
		if idle_move_time >= idle_move_duration:
			current_idle_action = ""
			velocity = Vector2.ZERO

func _choose_new_idle_action():
	var actions = ["pause", "move"]
	current_idle_action = actions[randi() % actions.size()]
	
	match current_idle_action:
		"pause":
			# 停顿1~5秒
			idle_timer = randf_range(0.5, 5.0)
			velocity = Vector2.ZERO
		
		"move":
			# 随机方向
			idle_target_rotation = randf_range(-PI, PI)
			# 随机速度（基础速度的30%~70%）
			idle_move_speed = move_speed * randf_range(0.3, 0.7)
			# 随机移动持续时间（0.5~3秒）
			idle_move_duration = randf_range(0.5, 4.0)
			idle_move_time = 0.0

func _attack_if_ready():
	# 检查玩家是否有效且存活
	if not player or not is_instance_valid(player) or player.health <= 0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_attack_time < attack_cooldown:
		return
	last_attack_time = now
	var dir = (player.global_position - global_position).normalized()
	var _col1 = move_and_collide(dir * 32.0)
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
	var _col2 = move_and_collide(-dir * 24.0)

func take_damage(amount: int):
	health = max(0, health - int(amount))
	
	# 更新血条宽度
	var health_ratio = float(health) / float(max_health)
	health_bar.size.x = 40 * health_ratio
	
	if get_tree().current_scene and get_tree().current_scene.has_method("show_damage_number"):
		get_tree().current_scene.show_damage_number(amount, global_position)
	if get_tree().current_scene and get_tree().current_scene.has_method("update_enemy_state"):
		get_tree().current_scene.update_enemy_state(self)
	if health <= 0:
		_die()

func _die():
	died.emit()
	if drop_system:
		for d in drop_table:
			var chance = float(d.get("chance", 1.0))
			if randf() <= chance:
				var cmin = int(d.get("min", 1))
				var cmax = int(d.get("max", 1))
				var cnt = randi_range(cmin, cmax)
				drop_system.create_drop(d.get("item_id", "credit"), cnt, drop_system.current_scene_id, global_position)
	queue_free()

func _load_config():
	var path = "res://config/enemies.json"
	if not FileAccess.file_exists(path):
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var js = f.get_as_text()
	f.close()
	var j = JSON.new()
	if j.parse(js) != OK:
		return
	var data = j.data
	if not data.has("enemies"):
		return
	var cfg = data.enemies.get(enemy_type, {})
	if cfg.is_empty():
		return
	max_health = int(cfg.get("max_health", max_health))
	health = max_health
	move_speed = float(cfg.get("move_speed", move_speed))
	attack_range = float(cfg.get("attack_range", attack_range))
	follow_range = float(cfg.get("follow_range", follow_range))
	attack_damage = int(cfg.get("attack_damage", attack_damage))
	var fov_deg = float(cfg.get("fov_angle_deg", rad_to_deg(fov_angle)))
	fov_angle = deg_to_rad(fov_deg)
	drop_table = cfg.get("drops", [])
