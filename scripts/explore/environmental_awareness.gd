extends Node
class_name EnvironmentalAwareness

# 环境感知构建器 - 负责构建AI提示词中的环境感知部分
# 包含场景描述、玩家状态、附近敌人、宝箱等信息

var save_manager: Node
var player: Node2D
var snow_fox: Node2D
var enemy_manager: Node
var chest_system: Node
var weapon_system: Node
var player_inventory: PlayerInventory

# 配置参数
const MAX_ENEMY_DISTANCE = 500.0  # 最大检测敌人距离
const MAX_CHEST_DISTANCE = 500.0  # 最大检测宝箱距离
const GROUP_DISTANCE_THRESHOLD = 200.0  # 敌人/宝箱聚集团体距离阈值

func _ready():
	"""初始化环境感知构建器"""
	pass

func setup(sm: Node, p: Node2D, sf: Node2D, em: Node, cs: Node, ws: Node, pi: PlayerInventory):
	"""设置依赖组件"""
	save_manager = sm
	player = p
	snow_fox = sf
	enemy_manager = em
	chest_system = cs
	weapon_system = ws
	player_inventory = pi

func build_environmental_awareness() -> String:
	"""构建完整的环境感知文本"""
	var awareness_parts = []

	# 1. 场景描述
	var scene_description = _get_scene_description()
	if not scene_description.is_empty():
		awareness_parts.append(scene_description)

	# 2. 角色武器信息
	var character_weapon_info = _get_character_weapon_info()
	if not character_weapon_info.is_empty():
		awareness_parts.append(character_weapon_info)

	# 3. 附近敌人
	var nearby_enemies = _get_nearby_enemies()
	if not nearby_enemies.is_empty():
		awareness_parts.append(nearby_enemies)

	# 4. 附近宝箱
	var nearby_chests = _get_nearby_chests()
	if not nearby_chests.is_empty():
		awareness_parts.append(nearby_chests)

	# 5. 玩家生命值
	var player_health = _get_player_health()
	if not player_health.is_empty():
		awareness_parts.append(player_health)

	# 6. 玩家武器信息
	var player_weapon_info = _get_player_weapon_info()
	if not player_weapon_info.is_empty():
		awareness_parts.append(player_weapon_info)

	# 组合所有部分
	if awareness_parts.is_empty():
		return "（暂无信息）"

	return "\n".join(awareness_parts)

func _get_scene_description() -> String:
	"""获取当前场景描述"""
	if not save_manager:
		return ""

	# 首先尝试从explore_scene获取当前场景ID（探索模式）
	var explore_scene = get_node("/root/ExploreScene")
	var current_scene = ""
	if explore_scene and explore_scene.has_method("get_current_explore_id"):
		current_scene = explore_scene.get_current_explore_id()

	# 如果没有探索场景ID，则使用存档中的场景ID（家模式）
	if current_scene.is_empty():
		current_scene = save_manager.get_character_scene()
		if current_scene.is_empty():
			return ""

	# 从map.json读取场景描述
	var map_config_path = "res://config/map.json"
	if not FileAccess.file_exists(map_config_path):
		return ""

	var file = FileAccess.open(map_config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return ""

	var map_data = json.data
	if not map_data.has("world") or not map_data.world.has("points"):
		return ""

	# 查找当前场景的描述
	for point in map_data.world.points:
		if point.get("id", "") == current_scene:
			var description = point.get("des", "")
			if not description.is_empty():
				return "当前场景：%s" % description
		# 如果是家模式，检查子场景
		elif point.get("id", "") == "home" and point.has("children"):
				for child in point.children:
					if child.get("id", "") == current_scene:
						# 子场景没有des字段，使用name作为描述
						var scene_name = child.get("name", "")
						if not scene_name.is_empty():
							return "当前场景：%s" % scene_name

	return ""

func _get_player_health() -> String:
	"""获取玩家生命值信息"""
	if not player:
		return ""

	# 直接访问属性
	var current_health = player.health if player.get("health") != null else 0
	var max_health = player.max_health if player.get("max_health") != null else 100

	if max_health <= 0:
		return ""

	# 获取玩家名称
	var player_name = "玩家"
	if save_manager and save_manager.has_method("get_user_name"):
		player_name = save_manager.get_user_name()

	var percentage = int((float(current_health) / float(max_health)) * 100)
	return "%s的生命值：%d%%" % [player_name, percentage]

func _get_character_weapon_info() -> String:
	"""获取角色武器和弹药信息"""
	if not snow_fox:
		return ""

	var weapon_info_parts = []

	# 获取雪狐的背包数据
	var fox_storage = snow_fox.get_storage() if snow_fox.has_method("get_storage") else {}
	if fox_storage.is_empty():
		return ""

	# 获取武器栏武器
	var weapon_slot = fox_storage.get("weapon_slot", {})
	if not weapon_slot.is_empty() and weapon_slot.has("item_id"):
		var weapon_id = weapon_slot.get("item_id", "")
		var weapon_config = player_inventory.get_item_config(weapon_id) if player_inventory else {}

		if not weapon_config.is_empty():
			var weapon_name = weapon_config.get("name", weapon_id)
			weapon_info_parts.append("你手上的武器：%s" % weapon_name)

			# 如果是远程武器，显示弹药信息
			if weapon_config.get("subtype") == "远程":
				var current_ammo = weapon_slot.get("ammo", 0)
				var magazine_size = weapon_config.get("magazine_size", 30)
				weapon_info_parts.append("弹匣：%d/%d" % [current_ammo, magazine_size])

				# 显示角色背包中的总弹药数
				var ammo_type = weapon_config.get("ammo_type", "")
				if not ammo_type.is_empty():
					var total_ammo = _get_total_ammo_in_fox_inventory(ammo_type, fox_storage)
					if total_ammo > 0:
						weapon_info_parts.append("剩余弹药：%d" % total_ammo)
		else:
			weapon_info_parts.append("你手上的武器：%s" % weapon_id)
	else:
		weapon_info_parts.append("你手上没有武器")

	return "\n".join(weapon_info_parts)

func _get_player_weapon_info() -> String:
	"""获取玩家武器信息（只有武器名）"""
	if not weapon_system:
		return ""

	# 获取玩家名称
	var player_name = "玩家"
	if save_manager and save_manager.has_method("get_user_name"):
		player_name = save_manager.get_user_name()

	# 获取武器栏武器
	if weapon_system.is_weapon_equipped():
		var weapon_data = weapon_system.get_current_weapon()
		var weapon_config = weapon_system.get_weapon_config()

		if not weapon_data.is_empty() and not weapon_config.is_empty():
			var weapon_name = weapon_config.get("name", weapon_data.get("item_id", "未知武器"))
			return "%s手上的武器：%s" % [player_name, weapon_name]

	return "%s手上没有武器" % player_name

func _get_total_ammo_in_inventory(ammo_type: String) -> int:
	"""获取玩家背包中指定类型弹药的总数量"""
	if not player_inventory or not player_inventory.container:
		return 0

	var total_count = 0
	var items_config = player_inventory.items_config

	# 查找匹配的弹药物品
	for item_id in items_config:
		var item_config = items_config[item_id]
		if item_config.get("type") == "弹药" and item_config.get("caliber") == ammo_type:
			total_count += player_inventory.container.count_item(item_id)

	return total_count

func _get_total_ammo_in_fox_inventory(ammo_type: String, fox_storage: Dictionary) -> int:
	"""获取雪狐背包中指定类型弹药的总数量"""
	if fox_storage.is_empty() or not fox_storage.has("storage"):
		return 0

	var total_count = 0
	var fox_inventory = fox_storage.storage
	var items_config = player_inventory.items_config if player_inventory else {}

	# 查找匹配的弹药物品
	for item_id in items_config:
		var item_config = items_config[item_id]
		if item_config.get("type") == "弹药" and item_config.get("caliber") == ammo_type:
			# 计算雪狐背包中的数量
			for slot in fox_inventory:
				if slot is Dictionary and slot.get("item_id") == item_id:
					total_count += slot.get("count", 0)

	return total_count

func _get_nearby_enemies() -> String:
	"""获取附近敌人的信息（方向+距离，智能合并）"""
	if not player or not enemy_manager:
		return ""

	var enemies = enemy_manager.active_enemies
	if enemies.is_empty():
		return "附近没有敌人"

	var enemy_groups = _group_nearby_entities(enemies, MAX_ENEMY_DISTANCE, GROUP_DISTANCE_THRESHOLD)

	if enemy_groups.is_empty():
		return "附近没有敌人"

	var enemy_descriptions = []
	for group in enemy_groups:
		var description = _describe_enemy_group(group)
		if not description.is_empty():
			enemy_descriptions.append(description)

	if enemy_descriptions.is_empty():
		return "附近没有敌人"

	return "附近敌人：\n" + "\n".join(enemy_descriptions)

func _get_nearby_chests() -> String:
	"""获取附近宝箱的信息（方向+距离，智能合并）"""
	if not player or not chest_system:
		return ""

	# 获取所有可能的宝箱位置（从地图图层）
	var chest_positions = _get_chest_positions_from_map()
	if chest_positions.is_empty():
		return "附近没有宝箱"

	var nearby_chests = []
	for chest_pos in chest_positions:
		var distance = player.global_position.distance_to(chest_pos.position)
		if distance <= MAX_CHEST_DISTANCE:
			nearby_chests.append({
				"position": chest_pos.position,
				"type": chest_pos.type,
				"distance": distance
			})

	if nearby_chests.is_empty():
		return "附近没有宝箱"

	var chest_groups = _group_nearby_entities(nearby_chests, MAX_CHEST_DISTANCE, GROUP_DISTANCE_THRESHOLD)

	if chest_groups.is_empty():
		return "附近没有宝箱"

	var chest_descriptions = []
	for group in chest_groups:
		var description = _describe_chest_group(group)
		if not description.is_empty():
			chest_descriptions.append(description)

	if chest_descriptions.is_empty():
		return "附近没有宝箱"

	return "附近宝箱：\n" + "\n".join(chest_descriptions)

func _group_nearby_entities(entities: Array, max_distance: float, group_threshold: float) -> Array:
	"""将附近的实体按距离分组，智能合并"""
	var groups = []

	for entity in entities:
		var entity_pos = entity.global_position if entity is Node2D else entity.position
		var distance = player.global_position.distance_to(entity_pos)

		if distance > max_distance:
			continue

		# 查找是否可以加入现有组
		var added_to_group = false
		for group in groups:
			if not group.is_empty():
				var group_center = group[0].global_position if group[0] is Node2D else group[0].position
				var distance_to_group = player.global_position.distance_to(group_center)

				if abs(distance - distance_to_group) <= group_threshold:
					group.append(entity)
					added_to_group = true
					break

		# 如果没有加入现有组，创建新组
		if not added_to_group:
			groups.append([entity])

	return groups

func _describe_enemy_group(enemy_group: Array) -> String:
	"""描述一组敌人"""
	if enemy_group.is_empty():
		return ""

	var enemy_count = enemy_group.size()
	var first_enemy = enemy_group[0]
	var enemy_pos = first_enemy.global_position
	var _distance = player.global_position.distance_to(enemy_pos)

	# 计算方向
	var direction = _get_direction_description(player.global_position, enemy_pos)

	# 计算平均距离
	var total_distance = 0.0
	for enemy in enemy_group:
		total_distance += player.global_position.distance_to(enemy.global_position)
	var avg_distance = total_distance / enemy_group.size()

	var distance_desc = "%dm" % int(avg_distance/32)

	return "%s方向%s处有%d个敌人" % [direction, distance_desc, enemy_count]

func _describe_chest_group(chest_group: Array) -> String:
	"""描述一组宝箱"""
	if chest_group.is_empty():
		return ""

	var chest_count = chest_group.size()
	var first_chest = chest_group[0]
	var chest_pos = first_chest.position
	var _distance = player.global_position.distance_to(chest_pos)

	# 计算方向
	var direction = _get_direction_description(player.global_position, chest_pos)

	# 计算平均距离
	var total_distance = 0.0
	for chest in chest_group:
		total_distance += player.global_position.distance_to(chest.position)
	var avg_distance = total_distance / chest_group.size()

	var distance_desc = "%dm" % int(avg_distance/32)

	# 获取宝箱类型描述
	var chest_types = []
	for chest in chest_group:
		if not chest_types.has(chest.type):
			chest_types.append(chest.type)

	var type_desc = ""
	if chest_types.size() == 1:
		type_desc = chest_system.get_chest_name_by_type(chest_types[0])
	else:
		type_desc = "箱子"

	return "%s方向%s处有%d个%s" % [direction, distance_desc, chest_count, type_desc]

func _get_direction_description(from_pos: Vector2, to_pos: Vector2) -> String:
	"""获取方向描述"""
	var direction_vector = to_pos - from_pos
	var angle = direction_vector.angle()

	# 将角度转换为方向描述
	if angle >= -PI/8 and angle < PI/8:
		return "正东"
	elif angle >= PI/8 and angle < 3*PI/8:
		return "东南"
	elif angle >= 3*PI/8 and angle < 5*PI/8:
		return "正南"
	elif angle >= 5*PI/8 and angle < 7*PI/8:
		return "西南"
	elif angle >= 7*PI/8 or angle < -7*PI/8:
		return "正西"
	elif angle >= -7*PI/8 and angle < -5*PI/8:
		return "西北"
	elif angle >= -5*PI/8 and angle < -3*PI/8:
		return "正北"
	elif angle >= -3*PI/8 and angle < -PI/8:
		return "东北"
	else:
		return "附近"

func _get_chest_positions_from_map() -> Array:
	"""从地图图层获取所有宝箱位置"""
	var chest_positions = []

	# 获取当前场景的地图图层
	if not player:
		return chest_positions

	var scene_root = player.get_parent()
	if not scene_root:
		return chest_positions

	# 直接访问tilemap_layers_container变量
	var tilemap_container = scene_root.tilemap_layers_container
	if not tilemap_container:
		return chest_positions

	# 查找所有图层
	for child in tilemap_container.get_children():
		if child is TileMapLayer:
			var layer_chests = _scan_layer_for_chests(child)
			chest_positions.append_array(layer_chests)

	return chest_positions

func _scan_layer_for_chests(layer: TileMapLayer) -> Array:
	"""扫描图层查找宝箱"""
	var chests = []

	if not layer or not chest_system:
		return chests

	var used_cells = layer.get_used_cells()
	for cell in used_cells:
		var tile_data = layer.get_cell_tile_data(cell)
		if tile_data:
			var chest_type = _get_chest_type_from_tile_data(tile_data)
			if not chest_type.is_empty():
				var local_pos = layer.map_to_local(cell)
				var world_pos = layer.to_global(local_pos)

				chests.append({
					"position": world_pos,
					"type": chest_type
				})

	return chests

func _get_chest_type_from_tile_data(tile_data: TileData) -> String:
	"""从tile数据获取宝箱类型"""
	if not tile_data:
		return ""

	# 检查是否是宝箱
	if not tile_data.get_custom_data("is_chest"):
		return ""

	# 获取宝箱类型
	var chest_type = tile_data.get_custom_data("chest_type")
	if chest_type is String and not chest_type.is_empty():
		return chest_type

	return "common_chest"  # 默认类型
