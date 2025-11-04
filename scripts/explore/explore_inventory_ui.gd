extends UniversalInventoryUI
class_name ExploreInventoryUI

# 探索模式背包UI - 使用通用背包UI

var player_inventory: PlayerInventory
var chest_system: Node
var current_chest_container: StorageContainer

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

func open_chest(chest_storage: Array, container_name: String = "宝箱"):
	"""打开宝箱或其他容器"""
	# 创建临时容器包装数据
	current_chest_container = StorageContainer.new(chest_storage.size(), player_inventory.items_config)
	current_chest_container.storage = chest_storage
	
	setup_other_container(current_chest_container, container_name)
	open_with_container()
	_disable_player_controls()

func _on_inventory_closed():
	"""背包关闭时恢复玩家控制"""
	_enable_player_controls()

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
