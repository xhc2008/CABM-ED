extends UniversalInventoryUI

# 主场景背包UI - 使用通用背包UI

var snow_fox_container: StorageContainer
var is_showing_warehouse: bool = true  # 当前显示的是仓库还是雪狐背包
var switch_button: Button

func _ready():
	super._ready()
	
	# 初始化雪狐背包容器
	_initialize_snow_fox_container()
	
	# 设置玩家背包和仓库
	setup_player_inventory(InventoryManager.inventory_container, "背包")
	setup_other_container(InventoryManager.warehouse_container, "仓库")
	
	# 创建切换按钮
	_create_switch_button()

func _initialize_snow_fox_container():
	"""初始化雪狐背包容器（带武器栏）"""
	const SNOW_FOX_SIZE = 12
	snow_fox_container = StorageContainer.new(SNOW_FOX_SIZE, InventoryManager.items_config, true)
	
	# 从存档加载雪狐背包
	if SaveManager and SaveManager.save_data.has("snow_fox_inventory"):
		snow_fox_container.load_data(SaveManager.save_data.snow_fox_inventory)
	
	# 连接存储变化信号以自动保存
	snow_fox_container.storage_changed.connect(_on_snow_fox_storage_changed)

func _create_switch_button():
	"""创建切换按钮"""
	if not container_panel:
		return
	
	# 查找或创建切换按钮
	var vbox = container_panel.get_node_or_null("VBox")
	if not vbox:
		return
	
	switch_button = vbox.get_node_or_null("SwitchButton")
	if not switch_button:
		switch_button = Button.new()
		switch_button.name = "SwitchButton"
		# 插入到标题后面
		vbox.add_child(switch_button)
		vbox.move_child(switch_button, 1)
	
	var character_name = _get_character_name()
	switch_button.text = "切换到" + character_name + "背包"
	switch_button.pressed.connect(_on_switch_button_pressed)

func _on_switch_button_pressed():
	"""切换按钮点击"""
	is_showing_warehouse = !is_showing_warehouse
	var character_name = _get_character_name()
	
	if is_showing_warehouse:
		setup_other_container(InventoryManager.warehouse_container, "仓库")
		switch_button.text = "切换到" + character_name + "背包"
	else:
		setup_other_container(snow_fox_container, character_name + "的背包")
		switch_button.text = "切换到仓库"
	
	_refresh_all_slots()

func _on_snow_fox_storage_changed():
	"""雪狐背包变化时保存"""
	if SaveManager:
		SaveManager.save_data.snow_fox_inventory = snow_fox_container.get_data()
		SaveManager.save_inventory_data()

func toggle_visibility():
	"""切换显示/隐藏"""
	if visible:
		close_inventory()
	else:
		# 重新加载雪狐背包（以防在探索模式中修改过）
		if SaveManager and SaveManager.save_data.has("snow_fox_inventory"):
			snow_fox_container.load_data(SaveManager.save_data.snow_fox_inventory)
		
		# 默认显示仓库
		is_showing_warehouse = true
		setup_other_container(InventoryManager.warehouse_container, "仓库")
		if switch_button:
			switch_button.text = "切换到"+_get_character_name()+"背包"
		
		open_with_container()

func _get_character_name() -> String:
	"""获取角色名称"""
	if not has_node("/root/SaveManager"):
		return "角色"
	
	var save_mgr = get_node("/root/SaveManager")
	return save_mgr.get_character_name()
