extends Node
class_name PlayerInventory

# 玩家背包系统 - 探索模式专用
# 与主场景的背包/仓库系统分离

signal inventory_changed()

const INVENTORY_SIZE = 30  # 背包格子数量

var inventory: Array = []  # 背包数据 [{item_id: String, count: int}]
var items_config: Dictionary = {}  # 物品配置

func _ready():
	_load_items_config()
	_initialize_inventory()

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

func _initialize_inventory():
	"""初始化背包"""
	inventory.resize(INVENTORY_SIZE)
	for i in range(INVENTORY_SIZE):
		inventory[i] = null

func get_item_config(item_id: String) -> Dictionary:
	"""获取物品配置"""
	return items_config.get(item_id, {})

func add_item(item_id: String, count: int = 1) -> bool:
	"""添加物品到背包"""
	var item_config = get_item_config(item_id)
	if item_config.is_empty():
		print("错误: 物品ID不存在: ", item_id)
		return false
	
	var max_stack = item_config.get("max_stack", 1)
	var remaining = count
	
	# 先尝试堆叠到现有格子
	for i in range(inventory.size()):
		if inventory[i] != null and inventory[i].item_id == item_id:
			var current_count = inventory[i].count
			var can_add = min(remaining, max_stack - current_count)
			if can_add > 0:
				inventory[i].count += can_add
				remaining -= can_add
				if remaining <= 0:
					inventory_changed.emit()
					return true
	
	# 放入空格子
	for i in range(inventory.size()):
		if inventory[i] == null:
			var add_count = min(remaining, max_stack)
			inventory[i] = {
				"item_id": item_id,
				"count": add_count
			}
			remaining -= add_count
			if remaining <= 0:
				inventory_changed.emit()
				return true
	
	# 背包满了
	if remaining > 0:
		print("警告: 背包空间不足，剩余 ", remaining, " 个物品未添加")
		inventory_changed.emit()
		return false
	
	return true

func remove_item(index: int, count: int = 1) -> bool:
	"""从指定位置移除物品"""
	if index < 0 or index >= inventory.size():
		return false
	
	if inventory[index] == null:
		return false
	
	inventory[index].count -= count
	if inventory[index].count <= 0:
		inventory[index] = null
	
	inventory_changed.emit()
	return true

func move_item(from_index: int, to_index: int) -> bool:
	"""移动物品（背包内）"""
	if from_index < 0 or from_index >= inventory.size():
		return false
	if to_index < 0 or to_index >= inventory.size():
		return false
	
	var from_item = inventory[from_index]
	var to_item = inventory[to_index]
	
	if from_item == null:
		return false
	
	# 目标格子为空，直接移动
	if to_item == null:
		inventory[to_index] = from_item
		inventory[from_index] = null
		inventory_changed.emit()
		return true
	
	# 目标格子有物品，检查是否可以堆叠
	if from_item.item_id == to_item.item_id:
		var item_config = get_item_config(from_item.item_id)
		var max_stack = item_config.get("max_stack", 1)
		var total = from_item.count + to_item.count
		
		if total <= max_stack:
			# 完全堆叠
			inventory[to_index].count = total
			inventory[from_index] = null
		else:
			# 部分堆叠
			inventory[to_index].count = max_stack
			inventory[from_index].count = total - max_stack
		
		inventory_changed.emit()
		return true
	
	# 不同物品，交换位置
	inventory[to_index] = from_item
	inventory[from_index] = to_item
	inventory_changed.emit()
	return true

func transfer_to_storage(from_index: int, storage: Array, to_index: int) -> bool:
	"""从背包转移到其他存储（如宝箱）"""
	if from_index < 0 or from_index >= inventory.size():
		return false
	if to_index < 0 or to_index >= storage.size():
		return false
	
	var from_item = inventory[from_index]
	var to_item = storage[to_index]
	
	if from_item == null:
		return false
	
	# 目标格子为空，直接移动
	if to_item == null:
		storage[to_index] = from_item
		inventory[from_index] = null
		inventory_changed.emit()
		return true
	
	# 目标格子有物品，检查是否可以堆叠
	if from_item.item_id == to_item.item_id:
		var item_config = get_item_config(from_item.item_id)
		var max_stack = item_config.get("max_stack", 1)
		var total = from_item.count + to_item.count
		
		if total <= max_stack:
			storage[to_index].count = total
			inventory[from_index] = null
		else:
			storage[to_index].count = max_stack
			inventory[from_index].count = total - max_stack
		
		inventory_changed.emit()
		return true
	
	# 不同物品，交换位置
	storage[to_index] = from_item
	inventory[from_index] = to_item
	inventory_changed.emit()
	return true

func transfer_from_storage(storage: Array, from_index: int, to_index: int) -> bool:
	"""从其他存储转移到背包"""
	if from_index < 0 or from_index >= storage.size():
		return false
	if to_index < 0 or to_index >= inventory.size():
		return false
	
	var from_item = storage[from_index]
	var to_item = inventory[to_index]
	
	if from_item == null:
		return false
	
	# 目标格子为空，直接移动
	if to_item == null:
		inventory[to_index] = from_item
		storage[from_index] = null
		inventory_changed.emit()
		return true
	
	# 目标格子有物品，检查是否可以堆叠
	if from_item.item_id == to_item.item_id:
		var item_config = get_item_config(from_item.item_id)
		var max_stack = item_config.get("max_stack", 1)
		var total = from_item.count + to_item.count
		
		if total <= max_stack:
			inventory[to_index].count = total
			storage[from_index] = null
		else:
			inventory[to_index].count = max_stack
			storage[from_index].count = total - max_stack
		
		inventory_changed.emit()
		return true
	
	# 不同物品，交换位置
	inventory[to_index] = from_item
	storage[from_index] = to_item
	inventory_changed.emit()
	return true

func get_inventory_data() -> Array:
	"""获取背包数据用于保存"""
	var result = []
	for item in inventory:
		if item != null:
			result.append(item.duplicate())
		else:
			result.append(null)
	return result

func load_inventory_data(data: Array):
	"""从保存数据加载"""
	inventory.resize(INVENTORY_SIZE)
	for i in range(INVENTORY_SIZE):
		if i < data.size() and data[i] != null:
			inventory[i] = data[i].duplicate()
		else:
			inventory[i] = null
	inventory_changed.emit()
