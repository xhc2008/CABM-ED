extends Node
class_name ChestSystem

# 宝箱系统 - 管理宝箱生成和战利品

signal chest_opened(chest_data: Dictionary)

const CHEST_STORAGE_SIZE = 12  # 宝箱格子数量

var loot_config: Dictionary = {}
var opened_chests: Dictionary = {}
var current_scene_id: String = ""

func _ready():
	_load_loot_config()

func _load_loot_config():
	"""加载战利品配置"""
	var config_path = "res://config/chest_loot.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		print("警告: 宝箱配置文件不存在")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		loot_config = json.data

func generate_chest_loot(chest_type: String) -> Array:
	"""生成宝箱战利品"""
	var storage = []
	storage.resize(CHEST_STORAGE_SIZE)
	for i in range(CHEST_STORAGE_SIZE):
		storage[i] = null
	
	if not loot_config.has("loot_tables"):
		return storage
	
	var loot_table = loot_config.loot_tables.get(chest_type, {})
	if loot_table.is_empty():
		print("警告: 未找到战利品表: ", chest_type)
		return storage
	
	var items = loot_table.get("items", [])
	var slot_index = 0
	
	for item_entry in items:
		# 根据概率决定是否生成该物品
		if randf() <= item_entry.probability:
			if slot_index >= CHEST_STORAGE_SIZE:
				break
			
			var count = randi_range(item_entry.min_count, item_entry.max_count)
			storage[slot_index] = {
				"item_id": item_entry.item_id,
				"count": count
			}
			slot_index += 1
	
	return storage

func get_chest_storage(chest_position: Vector2i, chest_type: String) -> Array:
	var key_scene = (current_scene_id + ":" if current_scene_id != "" else "") + str(chest_position)
	var key_legacy = str(chest_position)
	if opened_chests.has(key_scene) and opened_chests[key_scene].has("storage"):
		return opened_chests[key_scene].storage.duplicate(true)
	elif opened_chests.has(key_legacy) and opened_chests[key_legacy].has("storage"):
		return opened_chests[key_legacy].storage.duplicate(true)
	else:
		var storage = generate_chest_loot(chest_type)
		opened_chests[key_scene] = {
			"opened": true,
			"storage": storage.duplicate(true)
		}
		return storage

func save_chest_storage(chest_position: Vector2i, storage: Array):
	var key = (current_scene_id + ":" if current_scene_id != "" else "") + str(chest_position)
	if not opened_chests.has(key):
		opened_chests[key] = {}
	opened_chests[key].opened = true
	opened_chests[key].storage = storage.duplicate(true)

func is_chest_opened(chest_position: Vector2i) -> bool:
	var key_scene = (current_scene_id + ":" if current_scene_id != "" else "") + str(chest_position)
	if opened_chests.has(key_scene):
		return opened_chests[key_scene].get("opened", false)
	var key_legacy = str(chest_position)
	return opened_chests.has(key_legacy) and opened_chests[key_legacy].get("opened", false)

func get_chest_type_by_tile(tile_id: int) -> String:
	"""根据tile ID获取宝箱类型"""
	if not loot_config.has("chest_types"):
		return ""
	
	for type_key in loot_config.chest_types:
		var chest_type = loot_config.chest_types[type_key]
		if chest_type.get("tile_id", -1) == tile_id:
			return chest_type.get("loot_table", "")
	
	return ""

func get_chest_name_by_tile(tile_id: int) -> String:
	"""根据tile ID获取宝箱名称"""
	if not loot_config.has("chest_types"):
		return "宝箱"
	
	for type_key in loot_config.chest_types:
		var chest_type = loot_config.chest_types[type_key]
		if chest_type.get("tile_id", -1) == tile_id:
			return chest_type.get("name", "宝箱")
	
	return "宝箱"

func get_chest_name_by_type(chest_type: String) -> String:
	"""根据宝箱类型获取宝箱名称"""
	if not loot_config.has("loot_tables"):
		return "宝箱"
	
	var loot_table = loot_config.loot_tables.get(chest_type, {})
	return loot_table.get("name", "宝箱")

func get_save_data() -> Dictionary:
	"""获取保存数据"""
	return {
		"opened_chests": opened_chests.duplicate(true)
	}

func load_save_data(data: Dictionary):
	"""加载保存数据"""
	if data.has("opened_chests"):
		opened_chests = data.opened_chests.duplicate(true)

func set_current_scene_id(id: String):
	current_scene_id = id
