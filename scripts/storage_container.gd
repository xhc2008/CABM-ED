extends RefCounted
class_name StorageContainer

# 通用存储容器类 - 处理背包、仓库、宝箱等所有存储逻辑

signal storage_changed()

var storage: Array = []  # [{item_id: String, count: int}]
var size: int = 0
var items_config: Dictionary = {}
var weapon_slot: Dictionary = {}  # 武器栏 {item_id: String, count: int, ammo: int}
var has_weapon_slot: bool = false  # 是否有武器栏

func _init(container_size: int, config: Dictionary = {}, enable_weapon_slot: bool = false):
	size = container_size
	items_config = config
	has_weapon_slot = enable_weapon_slot
	storage.resize(size)
	for i in range(size):
		storage[i] = null
	if has_weapon_slot:
		weapon_slot = {}
		
func has_item(item_id: String) -> bool:
	"""检查容器中是否有指定物品"""
	# 检查武器栏
	if has_weapon_slot and not weapon_slot.is_empty() and weapon_slot.item_id == item_id:
		return true
	
	# 检查普通格子
	for item in storage:
		if item != null and item.item_id == item_id:
			return true
	
	return false

func set_items_config(config: Dictionary):
	"""设置物品配置"""
	items_config = config

func get_item_config(item_id: String) -> Dictionary:
	"""获取物品配置"""
	return items_config.get(item_id, {})

func add_item(item_id: String, count: int = 1) -> bool:
	"""添加物品"""
	# 确保数量是整数
	count = int(count)
	if count <= 0:
		return false
	
	var item_config = get_item_config(item_id)
	if item_config.is_empty():
		push_error("物品ID不存在: " + item_id)
		return false
	
	var max_stack = int(item_config.get("max_stack", 1))
	var remaining = count
	
	# 如果是武器且有武器栏，优先放入武器栏
	if has_weapon_slot and item_config.get("type") == "武器":
		if weapon_slot.is_empty():
			# 远程武器初始化时没有弹药，需要手动装弹
			var ammo = 0
			if item_config.get("subtype") == "远程":
				ammo = 0  # 初始弹药为0
			weapon_slot = {"item_id": item_id, "count": 1, "ammo": ammo}
			remaining -= 1
			if remaining <= 0:
				storage_changed.emit()
				return true
	
	# 先尝试堆叠到现有格子
	for i in range(storage.size()):
		if storage[i] != null and storage[i].item_id == item_id:
			var current_count = int(storage[i].count)
			var can_add = int(min(remaining, max_stack - current_count))
			if can_add > 0:
				storage[i].count = int(current_count + can_add)
				remaining -= can_add
				if remaining <= 0:
					storage_changed.emit()
					return true
	
	# 放入空格子
	for i in range(storage.size()):
		if storage[i] == null:
			var add_count = int(min(remaining, max_stack))
			storage[i] = {"item_id": item_id, "count": add_count}
			remaining -= add_count
			if remaining <= 0:
				storage_changed.emit()
				return true
	
	# 空间不足
	if remaining > 0:
		push_warning("存储空间不足，剩余 " + str(remaining) + " 个物品未添加")
		storage_changed.emit()
		return false
	
	return true

func remove_item(index: int, count: int = 1) -> bool:
	"""移除物品"""
	# 确保数量是整数
	count = int(count)
	if count <= 0:
		return false
	
	if index < 0 or index >= storage.size() or storage[index] == null:
		return false
	
	storage[index].count = int(storage[index].count) - count
	if storage[index].count <= 0:
		storage[index] = null
	
	storage_changed.emit()
	return true

func remove_item_by_id(item_id: String, count: int = 1) -> int:
	"""根据物品ID移除物品，返回实际移除的数量"""
	# 确保数量是整数
	count = int(count)
	if count <= 0:
		return 0
	
	var remaining = count
	
	# 查找并移除物品
	for i in range(storage.size()):
		if storage[i] != null and storage[i].item_id == item_id:
			var current_count = int(storage[i].count)
			var to_remove = min(remaining, current_count)
			storage[i].count = current_count - to_remove
			remaining -= to_remove
			
			if storage[i].count <= 0:
				storage[i] = null
			
			if remaining <= 0:
				storage_changed.emit()
				return count
	
	storage_changed.emit()
	return count - remaining

func move_item_internal(from_index: int, to_index: int) -> bool:
	"""容器内移动物品"""
	if from_index < 0 or from_index >= storage.size():
		return false
	if to_index < 0 or to_index >= storage.size():
		return false
	
	var from_item = storage[from_index]
	var to_item = storage[to_index]
	
	if from_item == null:
		return false
	
	# 目标格子为空，直接移动
	if to_item == null:
		storage[to_index] = from_item
		storage[from_index] = null
		storage_changed.emit()
		return true
	
	# 目标格子有物品，检查是否可以堆叠
	if from_item.item_id == to_item.item_id:
		var item_config = get_item_config(from_item.item_id)
		var max_stack = int(item_config.get("max_stack", 1))
		var total = int(from_item.count) + int(to_item.count)
		
		if total <= max_stack:
			storage[to_index].count = total
			storage[from_index] = null
		else:
			storage[to_index].count = max_stack
			storage[from_index].count = total - max_stack
		
		storage_changed.emit()
		return true
	
	# 不同物品，交换位置
	storage[to_index] = from_item
	storage[from_index] = to_item
	storage_changed.emit()
	return true

func transfer_to(from_index: int, target_container: StorageContainer, to_index: int) -> bool:
	"""转移物品到另一个容器"""
	if from_index < 0 or from_index >= storage.size():
		return false
	if to_index < 0 or to_index >= target_container.storage.size():
		return false
	
	var from_item = storage[from_index]
	var to_item = target_container.storage[to_index]
	
	if from_item == null:
		return false
	
	# 目标格子为空，直接移动
	if to_item == null:
		target_container.storage[to_index] = from_item
		storage[from_index] = null
		storage_changed.emit()
		target_container.storage_changed.emit()
		return true
	
	# 目标格子有物品，检查是否可以堆叠
	if from_item.item_id == to_item.item_id:
		var item_config = get_item_config(from_item.item_id)
		var max_stack = int(item_config.get("max_stack", 1))
		var total = int(from_item.count) + int(to_item.count)
		
		if total <= max_stack:
			target_container.storage[to_index].count = total
			storage[from_index] = null
		else:
			target_container.storage[to_index].count = max_stack
			storage[from_index].count = total - max_stack
		
		storage_changed.emit()
		target_container.storage_changed.emit()
		return true
	
	# 不同物品，交换位置
	target_container.storage[to_index] = from_item
	storage[from_index] = to_item
	storage_changed.emit()
	target_container.storage_changed.emit()
	return true

func get_data() -> Dictionary:
	"""获取存储数据用于保存"""
	var result = []
	for item in storage:
		if item != null:
			result.append(item.duplicate())
		else:
			result.append(null)
	
	var data = {"storage": result}
	if has_weapon_slot:
		var weapon_data = weapon_slot.duplicate() if not weapon_slot.is_empty() else {}
		# 确保ammo字段存在
		if not weapon_data.is_empty() and not weapon_data.has("ammo"):
			weapon_data["ammo"] = 0
		data["weapon_slot"] = weapon_data
	return data

func load_data(data):
	"""从保存数据加载"""
	# 兼容旧格式（Array）和新格式（Dictionary）
	var storage_data = []
	if data is Array:
		storage_data = data
	elif data is Dictionary:
		storage_data = data.get("storage", [])
		if has_weapon_slot and data.has("weapon_slot"):
			weapon_slot = data.weapon_slot.duplicate() if data.weapon_slot is Dictionary else {}
			# 确保ammo字段存在（兼容旧存档）
			if not weapon_slot.is_empty() and not weapon_slot.has("ammo"):
				weapon_slot["ammo"] = 0
	
	storage.resize(size)
	for i in range(size):
		if i < storage_data.size() and storage_data[i] != null:
			storage[i] = storage_data[i].duplicate()
			# 确保加载的数量是整数
			if storage[i].has("count"):
				storage[i].count = int(storage[i].count)
		else:
			storage[i] = null
	storage_changed.emit()

func split_item(from_index: int, to_index: int, split_count: int) -> bool:
	"""分离物品到另一个格子"""
	# 确保数量是整数
	split_count = int(split_count)
	if split_count <= 0:
		return false
	
	if from_index < 0 or from_index >= storage.size():
		return false
	if to_index < 0 or to_index >= storage.size():
		return false
	
	var from_item = storage[from_index]
	if from_item == null:
		return false
	
	var from_count = int(from_item.count)
	if split_count >= from_count:
		return false
	
	# 目标格子必须为空
	if storage[to_index] != null:
		return false
	
	# 执行分离
	storage[from_index].count = from_count - split_count
	storage[to_index] = {
		"item_id": from_item.item_id,
		"count": split_count
	}
	
	storage_changed.emit()
	return true
