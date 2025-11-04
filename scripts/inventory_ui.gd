extends UniversalInventoryUI

# 主场景背包UI - 使用通用背包UI

func _ready():
	super._ready()
	
	# 设置玩家背包和仓库
	setup_player_inventory(InventoryManager.inventory_container, "背包")
	setup_other_container(InventoryManager.warehouse_container, "仓库")

func toggle_visibility():
	"""切换显示/隐藏"""
	if visible:
		close_inventory()
	else:
		open_with_container()
