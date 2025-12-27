extends Node
class_name ExploreSceneEnemyManager

## 探索场景敌人管理器
## 负责敌人的生成、状态保存和加载

signal enemy_died(enemy_node: Node)

var active_enemies: Array = []
var enemy_system_data: Dictionary = {}
var current_explore_id: String = ""

var player: Node2D
var drop_system: Node
var enemy_layer: TileMapLayer
var scene_root: Node2D

# 敌人分区加载参数
var enemy_chunk_size: int = 64  # 区块大小（瓦片单位）
var active_enemy_radius_chunks: int = 3  # 活动敌人区块半径
var last_player_enemy_chunk := Vector2i(2147483647, 2147483647)

func setup(player_node: Node2D, drop_sys: Node, enemy_layer_node: TileMapLayer, root: Node2D):
	"""初始化敌人管理器"""
	player = player_node
	drop_system = drop_sys
	enemy_layer = enemy_layer_node
	scene_root = root

func update_active_enemies():
	"""更新活动敌人状态（分区加载）"""
	if not player:
		return

	var current_chunk = _get_player_enemy_chunk()
	if current_chunk == last_player_enemy_chunk:
		return

	last_player_enemy_chunk = current_chunk

	# 计算需要激活的区块范围
	var active_chunks := {}
	for dx in range(-active_enemy_radius_chunks, active_enemy_radius_chunks + 1):
		for dy in range(-active_enemy_radius_chunks, active_enemy_radius_chunks + 1):
			active_chunks[Vector2i(current_chunk.x + dx, current_chunk.y + dy)] = true

	# 激活/停用敌人
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_chunk = _get_enemy_chunk(enemy.global_position)
		var should_be_active = active_chunks.has(enemy_chunk)

		# 根据距离激活或停用敌人
		var enemy_is_active = enemy.get("is_active") if enemy.has_meta("is_active") or "is_active" in enemy else true
		if should_be_active and not enemy_is_active:
			_activate_enemy(enemy)
		elif not should_be_active and enemy_is_active:
			_deactivate_enemy(enemy)

func _get_player_enemy_chunk() -> Vector2i:
	"""获取玩家当前所在的敌人区块"""
	if player == null or enemy_layer == null:
		return last_player_enemy_chunk

	var tile_pos = enemy_layer.local_to_map(enemy_layer.to_local(player.global_position))
	return Vector2i(
		int(floor(tile_pos.x / float(enemy_chunk_size))),
		int(floor(tile_pos.y / float(enemy_chunk_size)))
	)

func _get_enemy_chunk(enemy_pos: Vector2) -> Vector2i:
	"""获取敌人所在的区块"""
	if enemy_layer == null:
		return Vector2i.ZERO

	var tile_pos = enemy_layer.local_to_map(enemy_layer.to_local(enemy_pos))
	return Vector2i(
		int(floor(tile_pos.x / float(enemy_chunk_size))),
		int(floor(tile_pos.y / float(enemy_chunk_size)))
	)

func _activate_enemy(enemy: Node):
	"""激活敌人"""
	if enemy and enemy.has_method("set_active"):
		enemy.set_active(true)
		if "is_active" in enemy:
			enemy.is_active = true

func _deactivate_enemy(enemy: Node):
	"""停用敌人"""
	if enemy and enemy.has_method("set_active"):
		enemy.set_active(false)
		if "is_active" in enemy:
			enemy.is_active = false

func set_explore_id(explore_id: String):
	"""设置当前探索场景ID"""
	current_explore_id = explore_id

func spawn_enemies_for_scene(explore_id: String):
	"""为场景生成敌人"""
	if enemy_system_data.has(explore_id):
		# 从保存的数据恢复敌人
		for entry in enemy_system_data[explore_id]:
			var pid = entry.get("id", "")
			if pid == "":
				continue
			var pos = Vector2(entry.pos[0], entry.pos[1])
			var e = _spawn_enemy_at(pos, entry.get("type", "basic"), pid)
			if e and entry.has("health"):
				e.health = int(entry.health)
	else:
		# 从地图层生成新敌人
		var points = _get_enemy_points_from_layer(enemy_layer)
		var spawned_entries := []
		
		for point in points:
			var pid = point.get("id", "")
			if pid == "":
				continue
			var e2 = _spawn_enemy_at(point.pos, point.get("type", "basic"), pid)
			if e2:
				spawned_entries.append({
					"id": pid,
					"type": point.get("type", "basic"),
					"pos": [point.pos.x, point.pos.y],
					"health": e2.health
				})
		
		enemy_system_data[explore_id] = spawned_entries
		if SaveManager:
			SaveManager.save_data.enemy_system_data = enemy_system_data.duplicate(true)

func update_enemy_state(enemy_node: Node):
	"""更新敌人状态"""
	var sid = enemy_node.get_meta("spawn_id") if enemy_node else ""
	if sid == "":
		return
	
	if not enemy_system_data.has(current_explore_id):
		enemy_system_data[current_explore_id] = []
	
	var arr = enemy_system_data[current_explore_id]
	var found = false
	
	for i in range(arr.size()):
		if arr[i].get("id", "") == sid:
			arr[i].health = enemy_node.health
			arr[i].pos = [enemy_node.global_position.x, enemy_node.global_position.y]
			found = true
			break
	
	if not found:
		arr.append({
			"id": sid,
			"type": "basic",
			"pos": [enemy_node.global_position.x, enemy_node.global_position.y],
			"health": enemy_node.health
		})
	
	enemy_system_data[current_explore_id] = arr
	if SaveManager:
		SaveManager.save_data.enemy_system_data = enemy_system_data.duplicate(true)
		SaveManager.save_game(SaveManager.current_slot)

func get_enemy_save_data() -> Dictionary:
	"""获取敌人保存数据"""
	var result := enemy_system_data.duplicate(true)
	var arr := []
	
	for enemy in active_enemies:
		var sid = enemy.get_meta("spawn_id")
		if sid == null:
			continue
		arr.append({
			"id": sid,
			"type": "basic",
			"pos": [enemy.global_position.x, enemy.global_position.y],
			"health": enemy.health
		})
	
	result[current_explore_id] = arr
	return result

func load_enemy_data(data: Dictionary):
	"""加载敌人数据"""
	enemy_system_data = data.duplicate(true)

func _spawn_enemy_at(pos: Vector2, enemy_type: String, spawn_id: String):
	"""在指定位置生成敌人"""
	var enemy_script = load("res://scripts/explore/enemy_basic.gd")
	var enemy = enemy_script.new()
	enemy.enemy_type = enemy_type
	
	scene_root.add_child(enemy)
	enemy.global_position = pos
	enemy.set_player(player)
	enemy.set_drop_system(drop_system)
	enemy.set_meta("spawn_id", spawn_id)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	
	active_enemies.append(enemy)
	return enemy

func _on_enemy_died(enemy_node: Node):
	"""敌人死亡回调"""
	var sid = enemy_node.get_meta("spawn_id") if enemy_node else ""
	if sid == "" or not SaveManager:
		return
	
	active_enemies.erase(enemy_node)
	
	if enemy_system_data.has(current_explore_id):
		var arr = enemy_system_data[current_explore_id]
		for i in range(arr.size()):
			if arr[i].get("id", "") == sid:
				arr.remove_at(i)
				break
		
		SaveManager.save_data.enemy_system_data = enemy_system_data.duplicate(true)
		SaveManager.save_game(SaveManager.current_slot)
	
	enemy_died.emit(enemy_node)

func _get_enemy_points_from_layer(layer: TileMapLayer) -> Array:
	"""从地图层获取敌人生成点"""
	var result: Array = []
	if layer == null:
		return result
	
	var cells = layer.get_used_cells()
	for cell in cells:
		var local_pos = layer.map_to_local(cell)
		var world_pos = layer.to_global(local_pos)
		var td = layer.get_cell_tile_data(cell)
		
		var etype = "basic"
		if td:
			var d = td.get_custom_data("enemy_type")
			if d is String and d != "":
				etype = d
		
		var pid = "%s_%d_%d" % [etype, int(cell.x), int(cell.y)]
		result.append({"id": pid, "type": etype, "pos": world_pos})
	
	return result

func clear_all_enemies():
	"""清除所有敌人"""
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
