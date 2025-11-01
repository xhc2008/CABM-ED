extends Node

# 背包管理器 - 自动加载单例
# 管理玩家背包和仓库数据

signal inventory_changed()
signal warehouse_changed()

const INVENTORY_SIZE = 30  # 背包格子数量
const WAREHOUSE_SIZE = 60  # 仓库格子数量

var inventory: Array = []  # 背包数据 [{item_id: String, count: int}]
var warehouse: Array = []  # 仓库数据

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
	inventory.resize(INVENTORY_SIZE)
	warehouse.resize(WAREHOUSE_SIZE)
	for i in range(INVENTORY_SIZE):
		inventory[i] = null
	for i in range(WAREHOUSE_SIZE):
		warehouse[i] = null

func get_item_config(item_id: String) -> Dictionary:
	"""获取物品配置"""
	return items_config.get(item_id, {})

func add_item_to_inventory(item_id: String, count: int = 1) -> bool:
	"""添加物品到背包"""
	return _add_item_to_storage(inventory, item_id, count, "inventory")

func add_item_to_warehouse(item_id: String, count: int = 1) -> bool:
	"""添加物品到仓库"""
	return _add_item_to_storage(warehouse, item_id, count, "warehouse")

func _add_item_to_storage(storage: Array, item_id: String, count: int, storage_name: String) -> bool:
	"""内部方法：添加物品到指定存储"""
	var item_config = get_item_config(item_id)
	if item_config.is_empty():
		print("错误: 物品ID不存在: ", item_id)
		return false
	
	var max_stack = item_config.get("max_stack", 1)
	var remaining = count
	
	# 先尝试堆叠到现有格子
	for i in range(storage.size()):
		if storage[i] != null and storage[i].item_id == item_id:
			var current_count = storage[i].count
			var can_add = min(remaining, max_stack - current_count)
			if can_add > 0:
				storage[i].count += can_add
				remaining -= can_add
				if remaining <= 0:
					_emit_storage_changed(storage_name)
					return true
	
	# 放入空格子
	for i in range(storage.size()):
		if storage[i] == null:
			var add_count = min(remaining, max_stack)
			storage[i] = {
				"item_id": item_id,
				"count": add_count
			}
			remaining -= add_count
			if remaining <= 0:
				_emit_storage_changed(storage_name)
				return true
	
	# 背包满了
	if remaining > 0:
		print("警告: 存储空间不足，剩余 ", remaining, " 个物品未添加")
		_emit_storage_changed(storage_name)
		return false
	
	return true

func remove_item(storage: Array, index: int, count: int = 1, storage_name: String = "") -> bool:
	"""从指定位置移除物品"""
	if index < 0 or index >= storage.size():
		return false
	
	if storage[index] == null:
		return false
	
	storage[index].count -= count
	if storage[index].count <= 0:
		storage[index] = null
	
	_emit_storage_changed(storage_name)
	return true

func move_item(from_storage: Array, from_index: int, to_storage: Array, to_index: int, 
			   from_name: String, to_name: String) -> bool:
	"""移动物品"""
	if from_index < 0 or from_index >= from_storage.size():
		return false
	if to_index < 0 or to_index >= to_storage.size():
		return false
	
	var from_item = from_storage[from_index]
	var to_item = to_storage[to_index]
	
	if from_item == null:
		return false
	
	# 目标格子为空，直接移动
	if to_item == null:
		to_storage[to_index] = from_item
		from_storage[from_index] = null
		_emit_storage_changed(from_name)
		_emit_storage_changed(to_name)
		return true
	
	# 目标格子有物品，检查是否可以堆叠
	if from_item.item_id == to_item.item_id:
		var item_config = get_item_config(from_item.item_id)
		var max_stack = item_config.get("max_stack", 1)
		var total = from_item.count + to_item.count
		
		if total <= max_stack:
			# 完全堆叠
			to_storage[to_index].count = total
			from_storage[from_index] = null
		else:
			# 部分堆叠
			to_storage[to_index].count = max_stack
			from_storage[from_index].count = total - max_stack
		
		_emit_storage_changed(from_name)
		_emit_storage_changed(to_name)
		return true
	
	# 不同物品，交换位置
	to_storage[to_index] = from_item
	from_storage[from_index] = to_item
	_emit_storage_changed(from_name)
	_emit_storage_changed(to_name)
	return true

func get_storage_data() -> Dictionary:
	"""获取存储数据用于保存"""
	return {
		"inventory": _serialize_storage(inventory),
		"warehouse": _serialize_storage(warehouse)
	}

func load_storage_data(data: Dictionary):
	"""从保存数据加载"""
	if data.has("inventory"):
		inventory = _deserialize_storage(data.inventory, INVENTORY_SIZE)
	if data.has("warehouse"):
		warehouse = _deserialize_storage(data.warehouse, WAREHOUSE_SIZE)
	
	inventory_changed.emit()
	warehouse_changed.emit()

func _serialize_storage(storage: Array) -> Array:
	"""序列化存储数据"""
	var result = []
	for item in storage:
		if item != null:
			result.append(item.duplicate())
		else:
			result.append(null)
	return result

func _deserialize_storage(data: Array, size: int) -> Array:
	"""反序列化存储数据"""
	var result = []
	result.resize(size)
	for i in range(size):
		if i < data.size() and data[i] != null:
			result[i] = data[i].duplicate()
		else:
			result[i] = null
	return result

func _emit_storage_changed(storage_name: String):
	"""发出存储变更信号"""
	if storage_name == "inventory":
		inventory_changed.emit()
	elif storage_name == "warehouse":
		warehouse_changed.emit()
