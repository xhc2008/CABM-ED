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

func open_chest(chest_storage: Array, container_name: String = "宝箱", chest_pos: Vector2i = Vector2i.ZERO):
	"""打开宝箱或其他容器"""
	current_chest_position = chest_pos
	
	# 创建临时容器包装数据
	current_chest_container = StorageContainer.new(chest_storage.size(), player_inventory.items_config)
	current_chest_container.storage = chest_storage
	
	# 连接存储变化信号以保存宝箱状态
	if current_chest_container.storage_changed.is_connected(_on_chest_storage_changed):
		current_chest_container.storage_changed.disconnect(_on_chest_storage_changed)
	current_chest_container.storage_changed.connect(_on_chest_storage_changed)
	
	setup_other_container(current_chest_container, container_name)
	open_with_container()
	_disable_player_controls()

func _on_inventory_closed():
	"""背包关闭时恢复玩家控制"""
	# 保存宝箱状态
	if current_chest_container and chest_system and current_chest_position != Vector2i.ZERO:
		chest_system.save_chest_storage(current_chest_position, current_chest_container.storage)
	
	_enable_player_controls()

func _on_chest_storage_changed():
	"""宝箱存储变化时自动保存"""
	if current_chest_container and chest_system and current_chest_position != Vector2i.ZERO:
		chest_system.save_chest_storage(current_chest_position, current_chest_container.storage)

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
