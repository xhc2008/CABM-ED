extends Area2D
class_name InteractionDetector

# 交互检测器 - 检测玩家周围的可交互物体

signal interactions_changed(interactions: Array)

@export var detection_radius: float = 80.0

var nearby_interactables: Array = []

func _ready():
	# 设置碰撞形状
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	
	var collision = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_body_entered(body: Node2D):
	"""物体进入检测范围"""
	if body.has_method("get_interaction_data"):
		if body not in nearby_interactables:
			nearby_interactables.append(body)
			_emit_interactions_changed()

func _on_body_exited(body: Node2D):
	"""物体离开检测范围"""
	if body in nearby_interactables:
		nearby_interactables.erase(body)
		_emit_interactions_changed()

func _on_area_entered(area: Area2D):
	"""区域进入检测范围"""
	if area.has_method("get_interaction_data"):
		if area not in nearby_interactables:
			nearby_interactables.append(area)
			_emit_interactions_changed()

func _on_area_exited(area: Area2D):
	"""区域离开检测范围"""
	if area in nearby_interactables:
		nearby_interactables.erase(area)
		_emit_interactions_changed()

func get_interactions() -> Array:
	"""获取当前可交互列表"""
	var interactions = []
	for interactable in nearby_interactables:
		if interactable.has_method("get_interaction_data"):
			var data = interactable.get_interaction_data()
			if data != null:
				interactions.append(data)
	return interactions

func _emit_interactions_changed():
	"""发出交互变化信号"""
	interactions_changed.emit(get_interactions())

func check_tilemap_interactions(tilemap_layer: TileMapLayer):
	"""检查TileMapLayer上的可交互tile"""
	if not tilemap_layer:
		return []
	
	var player_pos = global_position
	
	# 计算检测范围内的tile坐标
	var start_tile = tilemap_layer.local_to_map(tilemap_layer.to_local(player_pos - Vector2(detection_radius, detection_radius)))
	var end_tile = tilemap_layer.local_to_map(tilemap_layer.to_local(player_pos + Vector2(detection_radius, detection_radius)))
	
	var chest_tiles = []
	
	# 遍历范围内的tile
	for x in range(start_tile.x, end_tile.x + 1):
		for y in range(start_tile.y, end_tile.y + 1):
			var tile_pos = Vector2i(x, y)
			var tile_data = tilemap_layer.get_cell_tile_data(tile_pos)
			
			if tile_data and tile_data.get_custom_data("is_chest"):
				var world_pos = tilemap_layer.to_global(tilemap_layer.map_to_local(tile_pos))
				var distance = player_pos.distance_to(world_pos)
				
				if distance <= detection_radius:
					chest_tiles.append({
						"position": tile_pos,
						"world_position": world_pos,
						"distance": distance
					})
	
	return chest_tiles
