extends Node
class_name ChestSystem

# 宝箱系统 - 管理宝箱生成和战利品

signal chest_opened(chest_data: Dictionary)

const CHEST_STORAGE_SIZE = 12  # 宝箱格子数量

var loot_config: Dictionary = {}
var opened_chests: Dictionary = {}  # 记录已开启的宝箱 {position: bool}

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

func is_chest_opened(chest_position: Vector2i) -> bool:
	"""检查宝箱是否已开启"""
	var key = str(chest_position)
	return opened_chests.get(key, false)

func mark_chest_opened(chest_position: Vector2i):
	"""标记宝箱为已开启"""
	var key = str(chest_position)
	opened_chests[key] = true

func get_chest_type_by_tile(tile_id: int) -> String:
	"""根据tile ID获取宝箱类型"""
	if not loot_config.has("chest_types"):
		return ""
	
	for type_key in loot_config.chest_types:
		var chest_type = loot_config.chest_types[type_key]
		if chest_type.get("tile_id", -1) == tile_id:
			return chest_type.get("loot_table", "")
	
	return ""

func get_save_data() -> Dictionary:
	"""获取保存数据"""
	return {
		"opened_chests": opened_chests.duplicate()
	}

func load_save_data(data: Dictionary):
	"""加载保存数据"""
	if data.has("opened_chests"):
		opened_chests = data.opened_chests.duplicate()
