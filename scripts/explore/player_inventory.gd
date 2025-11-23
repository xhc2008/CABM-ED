extends Node
class_name PlayerInventory

# 玩家背包系统 - 探索模式专用
# 使用通用的StorageContainer

const INVENTORY_SIZE = 30  # 背包格子数量

var container: StorageContainer
var items_config: Dictionary = {}  # 物品配置

func _ready():
	_load_items_config()
	_initialize_inventory()

func _load_items_config():
	"""加载物品配置"""
	var config_path = "res://config/items.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_warning("物品配置文件不存在")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var data = json.data
		if data.has("items"):
			items_config = data.items

func _initialize_inventory():
	"""初始化背包（带武器栏）"""
	container = StorageContainer.new(INVENTORY_SIZE, items_config, true)

func get_item_config(item_id: String) -> Dictionary:
	"""获取物品配置"""
	return items_config.get(item_id, {})

func add_item(item_id: String, count: int = 1) -> bool:
	"""添加物品到背包"""
	return container.add_item(item_id, count)

func add_item_with_data(item_id: String, count: int = 1, data: Dictionary = {}) -> bool:
	var cfg = get_item_config(item_id)
	if cfg.get("type") == "武器":
		var is_remote = cfg.get("subtype") == "远程"
		var ammo_val := int(data.get("ammo", 0)) if is_remote else 0
		if container.has_weapon_slot and container.weapon_slot.is_empty():
			var w := {"item_id": item_id, "count": 1}
			if is_remote:
				w["ammo"] = ammo_val
			container.weapon_slot = w
			container.storage_changed.emit()
			return true
		else:
			var placed := false
			for i in range(container.storage.size()):
				if container.storage[i] == null:
					var w2 := {"item_id": item_id, "count": 1}
					if is_remote:
						w2["ammo"] = ammo_val
					container.storage[i] = w2
					placed = true
					break
			container.storage_changed.emit()
			return placed
	return container.add_item(item_id, count)

func get_inventory_data():
	"""获取背包数据用于保存"""
	return container.get_data()

func load_inventory_data(data):
	"""从保存数据加载"""
	container.load_data(data)
