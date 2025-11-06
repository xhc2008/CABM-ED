extends UniversalInventoryUI
class_name ExploreInventoryUI

# 探索模式背包UI - 使用通用背包UI

var player_inventory: PlayerInventory
var chest_system: Node
var current_chest_container: StorageContainer
var current_chest_position: Vector2i  # 当前打开的宝箱位置

func setup(p_inventory: PlayerInventory, c_system: Node):
	"""初始化"""
	player_inventory = p_inventory
	chest_system = c_system
	
	# 设置玩家背包
	setup_player_inventory(player_inventory.container, "背包")
	
	# 连接关闭信号以恢复玩家控制
	closed.connect(_on_inventory_closed)

func open_player_inventory():
	"""打开玩家背包（无存储）"""
	open_inventory_only()
	_disable_player_controls()

func open_chest(chest_storage, container_name: String = "宝箱", chest_pos: Vector2i = Vector2i.ZERO, enable_weapon_slot: bool = false):
	"""打开宝箱或其他容器
	
	参数:
		chest_storage: Array 或 Dictionary 格式的存储数据
		container_name: 容器名称
		chest_pos: 宝箱位置（用于保存）
		enable_weapon_slot: 是否启用武器栏（雪狐背包需要）
	"""
	current_chest_position = chest_pos
	
	# 解析存储数据
	var storage_array = []
	var weapon_slot_data = {}
	
	if chest_storage is Array:
		storage_array = chest_storage
	elif chest_storage is Dictionary:
		storage_array = chest_storage.get("storage", [])
		weapon_slot_data = chest_storage.get("weapon_slot", {})
	
	# 创建临时容器包装数据
	current_chest_container = StorageContainer.new(storage_array.size(), player_inventory.items_config, enable_weapon_slot)
	current_chest_container.storage = storage_array
	if enable_weapon_slot:
		current_chest_container.weapon_slot = weapon_slot_data
	
	# 连接存储变化信号以保存状态
	if current_chest_container.storage_changed.is_connected(_on_chest_storage_changed):
		current_chest_container.storage_changed.disconnect(_on_chest_storage_changed)
	current_chest_container.storage_changed.connect(_on_chest_storage_changed)
	
	setup_other_container(current_chest_container, container_name)
	open_with_container()
	_disable_player_controls()

func _on_inventory_closed():
	"""背包关闭时恢复玩家控制"""
	# 保存容器状态（支持武器栏）
	if current_chest_container and chest_system and current_chest_position != Vector2i.ZERO:
		# 保存普通格子
		chest_system.save_chest_storage(current_chest_position, current_chest_container.storage)
	
	# 如果是雪狐背包，需要保存完整数据（包括武器栏）
	if current_chest_container and current_chest_container.has_weapon_slot and current_chest_position == Vector2i.ZERO:
		_save_snow_fox_storage()
	
	_enable_player_controls()

func _on_chest_storage_changed():
	"""容器存储变化时自动保存"""
	if current_chest_container and chest_system and current_chest_position != Vector2i.ZERO:
		# 保存宝箱
		chest_system.save_chest_storage(current_chest_position, current_chest_container.storage)
	elif current_chest_container and current_chest_container.has_weapon_slot and current_chest_position == Vector2i.ZERO:
		# 保存雪狐背包
		_save_snow_fox_storage()

func _save_snow_fox_storage():
	"""保存雪狐背包到探索场景"""
	var explore_scene = get_tree().current_scene
	if explore_scene and explore_scene.has_method("update_snow_fox_storage"):
		var storage_data = {
			"storage": current_chest_container.storage.duplicate(true),
			"weapon_slot": current_chest_container.weapon_slot.duplicate() if not current_chest_container.weapon_slot.is_empty() else {}
		}
		explore_scene.update_snow_fox_storage(storage_data)

func _disable_player_controls():
	"""禁用玩家控制"""
	var explore_scene = get_tree().current_scene
	if explore_scene and explore_scene.has_method("set_player_controls_enabled"):
		explore_scene.set_player_controls_enabled(false)

func _enable_player_controls():
	"""启用玩家控制"""
	var explore_scene = get_tree().current_scene
	if explore_scene and explore_scene.has_method("set_player_controls_enabled"):
		explore_scene.set_player_controls_enabled(true)
