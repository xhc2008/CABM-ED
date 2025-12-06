extends Node
class_name DropSystem

signal drop_created(drop_id: String)
signal drop_removed(drop_id: String)

var current_scene_id: String = ""
var drops_by_scene: Dictionary = {}
var items_config: Dictionary = {}
var nodes_by_id: Dictionary = {}

# 掉落物随机偏移的范围（像素）
var drop_random_offset_radius: float = 20.0

func setup(config: Dictionary):
	items_config = config

func set_current_scene_id(id: String):
	current_scene_id = id

func create_drop(item_id: String, count: int, scene_id: String, world_pos: Vector2, data: Dictionary = {}):
	# 在原始位置周围添加随机偏移
	var random_offset = Vector2(
		randf_range(-drop_random_offset_radius, drop_random_offset_radius),
		randf_range(-drop_random_offset_radius, drop_random_offset_radius)
	)
	var final_pos = world_pos + random_offset
	
	var entry = {
		"id": _make_id(item_id),
		"item_id": item_id,
		"count": int(count),
		"pos": [final_pos.x, final_pos.y],
		"data": data.duplicate(true)
	}
	if not drops_by_scene.has(scene_id):
		drops_by_scene[scene_id] = []
	drops_by_scene[scene_id].append(entry)
	_drop_spawn_if_current(entry)
	drop_created.emit(entry.id)

# 可选：如果你想要更精确控制随机范围的方法
func create_drop_with_custom_offset(item_id: String, count: int, scene_id: String, world_pos: Vector2, offset_radius: float = 20.0, data: Dictionary = {}):
	var random_offset = Vector2(
		randf_range(-offset_radius, offset_radius),
		randf_range(-offset_radius, offset_radius)
	)
	var final_pos = world_pos + random_offset
	
	var entry = {
		"id": _make_id(item_id),
		"item_id": item_id,
		"count": int(count),
		"pos": [final_pos.x, final_pos.y],
		"data": data.duplicate(true)
	}
	if not drops_by_scene.has(scene_id):
		drops_by_scene[scene_id] = []
	drops_by_scene[scene_id].append(entry)
	_drop_spawn_if_current(entry)
	drop_created.emit(entry.id)

func _drop_spawn_if_current(entry: Dictionary):
	if current_scene_id == "":
		return
	var scene = get_tree().current_scene
	if not scene:
		return
	var pos = Vector2(entry.pos[0], entry.pos[1])
	var node := DropItem.new()
	var inst_data = entry.get("data", {}) if entry is Dictionary else {}
	node.setup(entry.id, entry.item_id, int(entry.count), items_config, inst_data)
	node.global_position = pos
	node.picked_up.connect(_on_drop_picked)
	scene.add_child(node)
	nodes_by_id[entry.id] = node

func spawn_drops_for_current_scene():
	var scene_id = current_scene_id
	if scene_id == "":
		return
	var arr = drops_by_scene.get(scene_id, [])
	for entry in arr:
		if entry is Dictionary:
			if not nodes_by_id.has(entry.id):
				_drop_spawn_if_current(entry)

func _on_drop_picked(id: String):
	_remove_drop(id)

func _remove_drop(id: String):
	for key in drops_by_scene.keys():
		var arr = drops_by_scene[key]
		for i in range(arr.size()):
			if arr[i] is Dictionary and arr[i].get("id", "") == id:
				arr.remove_at(i)
				break
	if nodes_by_id.has(id):
		var node = nodes_by_id[id]
		if node and is_instance_valid(node):
			node.queue_free()
		nodes_by_id.erase(id)
	drop_removed.emit(id)

func get_save_data() -> Dictionary:
	return {"drops_by_scene": drops_by_scene.duplicate(true)}

func load_save_data(data: Dictionary):
	if data.has("drops_by_scene"):
		drops_by_scene = data.drops_by_scene.duplicate(true)

func _make_id(item_id: String) -> String:
	return str(Time.get_unix_time_from_system()) + "_" + item_id + "_" + str(randi())

func disable_all_drops():
	"""禁用所有掉落物的交互（用于死亡或撤离时）"""
	for node in nodes_by_id.values():
		if node and is_instance_valid(node):
			# DropItem 本身就是 Area2D，直接禁用
			if node is Area2D:
				node.set_deferred("monitoring", false)
				node.set_deferred("monitorable", false)
			# 禁用掉落物的处理
			node.set_process(false)
			node.set_physics_process(false)
