extends CharacterBody2D
class_name SnowFoxCompanion

@export var follow_speed: float = 180.0
@export var min_follow_distance: float = 90.0  # 开始跟随的最小距离
@export var max_follow_distance: float = 400.0  # 传送回来的最大距离
@export var too_close_distance: float = 37.0  # 太近了需要远离
@export var escape_distance: float = 60.0  # 远离到这个距离
@export var reaction_delay: float = 0.15  # 反应延迟（秒）
@export var too_close_time_threshold: float = 2.0  # 靠太近多久后开始远离
@export var attack_detect_radius: float = 360.0
@export var attack_cooldown: float = 0.1
@export var pickup_radius: float = 28.0

var target: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var delayed_target_position: Vector2 = Vector2.ZERO
var time_since_target_moved: float = 0.0
var time_too_close: float = 0.0
var is_escaping: bool = false
var escape_target: Vector2 = Vector2.ZERO
var last_attack_time: float = -999.0
var navigation_initialized: bool = false
var items_config: Dictionary = {}
const BULLET_SCENE = preload("res://scenes/bullet.tscn")
var current_enemy_target: Node2D = null
var shoot_player: AudioStreamPlayer2D
var current_weapon_id: String = ""

# 雪狐的背包存储
const STORAGE_SIZE = 12
var storage: Dictionary = {}  # 使用字典格式 {storage: Array, weapon_slot: Dictionary}

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
	# 初始化存储（新格式）
	var storage_array = []
	storage_array.resize(STORAGE_SIZE)
	for i in range(STORAGE_SIZE):
		storage_array[i] = null
	storage = {
		"storage": storage_array,
		"weapon_slot": {}
	}
	if InventoryManager:
		items_config = InventoryManager.items_config
	else:
		var config_path = "res://config/items.json"
		if FileAccess.file_exists(config_path):
			var f = FileAccess.open(config_path, FileAccess.READ)
			if f:
				var js = f.get_as_text()
				f.close()
				var json = JSON.new()
				if json.parse(js) == OK and json.data.has("items"):
					items_config = json.data.items
	
	# 配置导航代理
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 10.0
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = 16.0
	
	# 等待第一帧后再设置目标
	call_deferred("_setup_navigation")
	delayed_target_position = global_position
	target_position = global_position
	shoot_player = AudioStreamPlayer2D.new()
	shoot_player.bus = "SFX"
	add_child(shoot_player)

func _setup_navigation():
	if target:
		delayed_target_position = target.global_position
		target_position = target.global_position
	navigation_initialized = true

func set_follow_target(new_target: Node2D):
	target = new_target
	if target:
		delayed_target_position = target.global_position
		target_position = target.global_position
		navigation_initialized = true

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
		if navigation_initialized and delayed_target_position != Vector2.ZERO:
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
		var space_state = get_world_2d().direct_space_state
		var look_end = global_position + direction * 20.0
		var ray = PhysicsRayQueryParameters2D.create(global_position, look_end)
		ray.collision_mask = 1
		var hit = space_state.intersect_ray(ray)
		if hit:
			var perp = Vector2(-direction.y, direction.x)
			direction = (direction + perp * (0.8 if randf() < 0.5 else -0.8)).normalized()
			desired_velocity = direction * follow_speed
		velocity = velocity.lerp(desired_velocity, delta * 8.0)
		
		# 朝向逻辑
		if current_enemy_target != null:
			rotation = (current_enemy_target.global_position - global_position).angle()
		elif velocity.length() > 10.0:
			rotation = velocity.angle()
	
	move_and_slide()
	_update_auto_pickup()
	_try_auto_attack()

func get_storage():
	"""获取雪狐的存储"""
	return storage

func set_storage(new_storage):
	"""设置雪狐的存储"""
	# 兼容旧格式（Array）和新格式（Dictionary）
	if new_storage is Array:
		# 旧格式，转换为新格式
		storage = {
			"storage": new_storage.duplicate(),
			"weapon_slot": {}
		}
	elif new_storage is Dictionary:
		storage = new_storage.duplicate(true)
	else:
		# 初始化空存储
		var storage_array = []
		storage_array.resize(STORAGE_SIZE)
		for i in range(STORAGE_SIZE):
			storage_array[i] = null
		storage = {
			"storage": storage_array,
			"weapon_slot": {}
		}

func get_save_data() -> Dictionary:
	"""获取保存数据"""
	return storage.duplicate(true)

func load_save_data(data: Dictionary):
	"""加载保存数据"""
	set_storage(data)

func _get_weapon_config() -> Dictionary:
	if storage.has("weapon_slot") and storage.weapon_slot is Dictionary and not storage.weapon_slot.is_empty():
		var wid = storage.weapon_slot.get("item_id", "")
		return items_config.get(wid, {})
	return {}

func _find_ammo_item_id(caliber: String) -> String:
	for item_id in items_config.keys():
		var cfg = items_config[item_id]
		if cfg.get("type") == "弹药" and String(cfg.get("caliber", "")) == caliber:
			return item_id
	return ""

func _count_item_in_storage(item_id: String) -> int:
	var total := 0
	if storage.has("storage"):
		for item in storage.storage:
			if item != null and item.get("item_id") == item_id:
				total += int(item.get("count", 0))
	return total

func _remove_item_from_storage(item_id: String, count: int) -> int:
	var remaining := int(count)
	if storage.has("storage"):
		for i in range(storage.storage.size()):
			var it = storage.storage[i]
			if it != null and it.get("item_id") == item_id:
				var cur := int(it.get("count", 0))
				var take = min(remaining, cur)
				storage.storage[i].count = cur - take
				remaining -= take
				if storage.storage[i].count <= 0:
					storage.storage[i] = null
				if remaining <= 0:
					break
	return int(count) - remaining

func _add_item_to_storage(item_id: String, count: int, data: Dictionary = {}) -> bool:
	var cfg = items_config.get(item_id, {})
	if cfg.is_empty():
		return false
	var max_stack := int(cfg.get("max_stack", 1))
	var remaining := int(count)
	if cfg.get("type") == "武器":
		if storage.has("weapon_slot") and (storage.weapon_slot is Dictionary) and storage.weapon_slot.is_empty():
			var w := {"item_id": item_id, "count": 1}
			if cfg.get("subtype") == "远程":
				w["ammo"] = int(data.get("ammo", 0))
			storage.weapon_slot = w
			return true
			
	for i in range(storage.storage.size()):
		var it = storage.storage[i]
		if it != null and it.get("item_id") == item_id:
			var cur := int(it.get("count", 0))
			var can_add = min(remaining, max_stack - cur)
			if can_add > 0:
				storage.storage[i].count = cur + can_add
				remaining -= can_add
				if remaining <= 0:
					return true
	for i in range(storage.storage.size()):
		if storage.storage[i] == null:
			var add_cnt = min(remaining, max_stack)
			storage.storage[i] = {"item_id": item_id, "count": add_cnt}
			remaining -= add_cnt
			if remaining <= 0:
				return true
	return remaining <= 0

func _auto_reload_weapon(cfg: Dictionary):
	if cfg.is_empty():
		return
	var mag := int(cfg.get("magazine_size", 30))
	var cur := int(storage.weapon_slot.get("ammo", 0))
	var need := mag - cur
	if need <= 0:
		return
	var ammo_id := _find_ammo_item_id(String(cfg.get("ammo_type", "")))
	if ammo_id == "":
		return
	var available := _count_item_in_storage(ammo_id)
	var take = min(need, available)
	if take <= 0:
		return
	var removed := _remove_item_from_storage(ammo_id, take)
	if removed > 0:
		storage.weapon_slot["ammo"] = cur + removed

func _line_of_sight_to(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(global_position, pos)
	ray.collision_mask = 1
	var hit = space_state.intersect_ray(ray)
	return hit == null or hit.is_empty()

func _find_shootable_enemy() -> Node2D:
	return null
	# 存在问题，暂不启用
	var space_state = get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = attack_detect_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0, global_position)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.collision_mask = 1
	params.exclude = [self]
	var res = space_state.intersect_shape(params, 32)
	for r in res:
		var n: Object = r.collider
		if n is Node2D:
			var pos := (n as Node2D).global_position
			if _line_of_sight_to(pos):
				current_enemy_target = n as Node2D
				return current_enemy_target
	current_enemy_target = null
	return null

func _try_auto_attack():
	var weapon = storage.get("weapon_slot", {})
	if weapon is Dictionary and weapon.is_empty():
		return
	var cfg := _get_weapon_config()
	if cfg.is_empty():
		return
	if String(cfg.get("subtype", "")) != "远程":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_attack_time < attack_cooldown:
		return
	var target_enemy := _find_shootable_enemy()
	if target_enemy == null:
		return
	if int(weapon.get("ammo", 0)) <= 0:
		_auto_reload_weapon(cfg)
		if int(storage.weapon_slot.get("ammo", 0)) <= 0:
			return
	var dir := (target_enemy.global_position - global_position).normalized()
	storage.weapon_slot["ammo"] = int(storage.weapon_slot.get("ammo", 0)) - 1
	var bullet = BULLET_SCENE.instantiate()
	if bullet:
		get_tree().current_scene.add_child(bullet)
		bullet.z_index = 3
		bullet.setup(global_position, dir, rotation, cfg, self)
	_ensure_weapon_sound()
	if shoot_player and shoot_player.stream:
		shoot_player.play()
	last_attack_time = now

func _ensure_weapon_sound():
	if not storage.has("weapon_slot") or storage.weapon_slot.is_empty():
		return
	var wid := String(storage.weapon_slot.get("item_id", ""))
	if wid == "":
		return
	if wid != current_weapon_id:
		var path := "res://assets/audio/explore/%s_shot.mp3" % wid
		if ResourceLoader.exists(path):
			shoot_player.stream = load(path)
		current_weapon_id = wid

func _update_auto_pickup():
	var space_state = get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = pickup_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0, global_position)
	params.collide_with_areas = true
	var res = space_state.intersect_shape(params, 32)
	for r in res:
		var a: Object = r.collider
		if a is DropItem:
			var d := a as DropItem
			var ok := _add_item_to_storage(d.item_id, int(d.count), d.item_data)
			if ok:
				d.picked_up.emit(d.drop_id)
				d.queue_free()
