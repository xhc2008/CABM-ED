extends Control

# 背包UI管理器

@onready var inventory_grid = $Panel/HBoxContainer/InventoryPanel/ScrollContainer/InventoryGrid
@onready var warehouse_grid = $Panel/HBoxContainer/WarehousePanel/ScrollContainer/WarehouseGrid
@onready var item_info_panel = $Panel/HBoxContainer/ItemInfoPanel
@onready var item_name_label = $Panel/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemName
@onready var item_icon = $Panel/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemIcon
@onready var item_desc_label = $Panel/HBoxContainer/ItemInfoPanel/VBoxContainer/ScrollContainer/ItemDescription
@onready var close_button = $Panel/CloseButton

var inventory_slots: Array = []
var warehouse_slots: Array = []

var selected_slot_index: int = -1
var selected_storage_type: String = ""

const SLOT_SCENE = preload("res://scenes/inventory_slot.tscn")

func _ready():
	hide()
	_create_slots()
	_connect_signals()
	_refresh_all_slots()

func _create_slots():
	"""创建所有格子"""
	# 创建背包格子
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "inventory")
		slot.slot_clicked.connect(_on_slot_clicked)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
	
	# 创建仓库格子
	for i in range(InventoryManager.WAREHOUSE_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "warehouse")
		slot.slot_clicked.connect(_on_slot_clicked)
		warehouse_grid.add_child(slot)
		warehouse_slots.append(slot)

func _connect_signals():
	"""连接信号"""
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	InventoryManager.warehouse_changed.connect(_on_warehouse_changed)

func _refresh_all_slots():
	"""刷新所有格子显示"""
	for i in range(inventory_slots.size()):
		inventory_slots[i].set_item(InventoryManager.inventory[i])
	
	for i in range(warehouse_slots.size()):
		warehouse_slots[i].set_item(InventoryManager.warehouse[i])

func _on_inventory_changed():
	"""背包数据变化"""
	for i in range(inventory_slots.size()):
		inventory_slots[i].set_item(InventoryManager.inventory[i])

func _on_warehouse_changed():
	"""仓库数据变化"""
	for i in range(warehouse_slots.size()):
		warehouse_slots[i].set_item(InventoryManager.warehouse[i])

func _on_slot_clicked(slot_index: int, storage_type: String):
	"""格子被点击"""
	var storage = InventoryManager.inventory if storage_type == "inventory" else InventoryManager.warehouse
	var clicked_item = storage[slot_index]
	
	# 没有选中物品时
	if selected_slot_index == -1:
		if clicked_item != null:
			# 选中该物品
			_select_slot(slot_index, storage_type)
			_show_item_info(clicked_item)
		else:
			# 点击空格子，高亮但不选中
			_clear_selection()
	else:
		# 已有选中物品时
		if selected_slot_index == slot_index and selected_storage_type == storage_type:
			# 点击同一个格子，取消选中
			_clear_selection()
		else:
			# 移动物品
			var from_storage = InventoryManager.inventory if selected_storage_type == "inventory" else InventoryManager.warehouse
			var to_storage = storage
			
			InventoryManager.move_item(
				from_storage, selected_slot_index,
				to_storage, slot_index,
				selected_storage_type, storage_type
			)
			
			# 移动后显示目标格子的物品信息
			var target_item = to_storage[slot_index]
			if target_item != null:
				_show_item_info(target_item)
			else:
				_clear_item_info()
			
			_clear_selection()

func _select_slot(slot_index: int, storage_type: String):
	"""选中格子"""
	_clear_selection()
	selected_slot_index = slot_index
	selected_storage_type = storage_type
	
	var slots = inventory_slots if storage_type == "inventory" else warehouse_slots
	slots[slot_index].set_selected(true)

func _clear_selection():
	"""清除选中状态"""
	if selected_slot_index != -1:
		var slots = inventory_slots if selected_storage_type == "inventory" else warehouse_slots
		if selected_slot_index < slots.size():
			slots[selected_slot_index].set_selected(false)
	
	selected_slot_index = -1
	selected_storage_type = ""

func _show_item_info(item_data: Dictionary):
	"""显示物品信息"""
	if not item_name_label or not item_desc_label or not item_icon:
		return
	
	var item_config = InventoryManager.get_item_config(item_data.item_id)
	
	item_name_label.text = item_config.get("name", "未知物品")
	item_desc_label.text = item_config.get("description", "无描述")
	
	# 显示图标
	if item_config.has("icon"):
		var icon_path = "res://assets/images/items/" + item_config.icon
		if ResourceLoader.exists(icon_path):
			item_icon.texture = load(icon_path)
		else:
			item_icon.texture = null
	
	# 显示详细属性
	var details = "\n\n属性\n"
	details += "类型: " + item_config.get("type", "未知") + "\n"
	details += "数量: " + str(item_data.count) + "\n"
	
	if item_config.has("weight"):
		details += "重量: " + str(item_config.weight) + "\n"
	if item_config.has("max_stack"):
		details += "最大堆叠: " + str(item_config.max_stack) + "\n"
	
	# 武器属性
	if item_config.get("type") == "weapon":
		if item_config.has("damage"):
			details += "伤害: " + str(item_config.damage) + "\n"
		if item_config.has("fire_rate"):
			details += "射速: " + str(item_config.fire_rate) + "\n"
	
	# 医疗属性
	if item_config.get("type") == "medical":
		if item_config.has("heal_amount"):
			details += "恢复量: " + str(item_config.heal_amount) + "\n"
	
	item_desc_label.text += details

func _clear_item_info():
	"""清空物品信息"""
	if item_name_label:
		item_name_label.text = "选择物品查看详情"
	if item_desc_label:
		item_desc_label.text = ""
	if item_icon:
		item_icon.texture = null

func toggle_visibility():
	"""切换显示/隐藏"""
	visible = !visible
	if visible:
		_refresh_all_slots()
		_clear_selection()
		_clear_item_info()

func _on_close_button_pressed():
	"""关闭按钮"""
	hide()
