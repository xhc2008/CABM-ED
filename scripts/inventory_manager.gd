extends Node

# 背包管理器 - 自动加载单例
# 管理玩家背包和仓库数据

const INVENTORY_SIZE = 30  # 背包格子数量
const WAREHOUSE_SIZE = 60  # 仓库格子数量

var inventory_container: StorageContainer
var warehouse_container: StorageContainer

var items_config: Dictionary = {}  # 物品配置

func _ready():
	_load_items_config()
	_initialize_storage()

func _load_items_config():
	"""加载物品配置"""
	var config_path = "res://config/items.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		print("警告: 物品配置文件不存在")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var data = json.data
		if data.has("items"):
			items_config = data.items

func _initialize_storage():
	"""初始化存储空间"""
	inventory_container = StorageContainer.new(INVENTORY_SIZE, items_config)
	warehouse_container = StorageContainer.new(WAREHOUSE_SIZE, items_config)

func get_item_config(item_id: String) -> Dictionary:
	"""获取物品配置"""
	return items_config.get(item_id, {})

func add_item_to_inventory(item_id: String, count: int = 1) -> bool:
	"""添加物品到背包"""
	return inventory_container.add_item(item_id, count)

func add_item_to_warehouse(item_id: String, count: int = 1) -> bool:
	"""添加物品到仓库"""
	return warehouse_container.add_item(item_id, count)

func get_storage_data() -> Dictionary:
	"""获取存储数据用于保存"""
	return {
		"inventory": inventory_container.get_data(),
		"warehouse": warehouse_container.get_data()
	}

func load_storage_data(data: Dictionary):
	"""从保存数据加载"""
	if data.has("inventory"):
		inventory_container.load_data(data.inventory)
	if data.has("warehouse"):
		warehouse_container.load_data(data.warehouse)
