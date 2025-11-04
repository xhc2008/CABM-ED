extends Control
class_name ExploreInventoryUI

# 探索模式背包UI

@onready var player_inventory_grid = $Panel/HBoxContainer/PlayerInventoryPanel/ScrollContainer/InventoryGrid
@onready var storage_panel = $Panel/HBoxContainer/StoragePanel
@onready var storage_grid = $Panel/HBoxContainer/StoragePanel/ScrollContainer/StorageGrid
@onready var item_info_panel = $Panel/HBoxContainer/ItemInfoPanel
@onready var item_name_label = $Panel/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemName
@onready var item_icon = $Panel/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemIcon
@onready var item_desc_label = $Panel/HBoxContainer/ItemInfoPanel/VBoxContainer/ScrollContainer/ItemDescription
@onready var close_button = $Panel/CloseButton
@onready var storage_title = $Panel/HBoxContainer/StoragePanel/Title

var player_inventory: Node  # PlayerInventory
var chest_system: Node  # ChestSystem

var player_slots: Array = []
var storage_slots: Array = []

var selected_slot_index: int = -1
var selected_storage_type: String = ""  # "player" 或 "storage"

var current_storage: Array = []  # 当前打开的存储（如宝箱）
var storage_mode: String = ""  # "chest" 等

const SLOT_SCENE = preload("res://scenes/inventory_slot.tscn")

func _ready():
	hide()
	# 强制设置为全屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_anchor(SIDE_LEFT, 0.0)
	set_anchor(SIDE_TOP, 0.0)
	set_anchor(SIDE_RIGHT, 1.0)
	set_anchor(SIDE_BOTTOM, 1.0)
	set_offset(SIDE_LEFT, 0.0)
	set_offset(SIDE_TOP, 0.0)
	set_offset(SIDE_RIGHT, 0.0)
	set_offset(SIDE_BOTTOM, 0.0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(p_inventory: Node, c_system: Node):
	"""初始化"""
	player_inventory = p_inventory
	chest_system = c_system
	_create_player_slots()
	_connect_signals()

func _create_player_slots():
	"""创建玩家背包格子"""
	# 清空现有格子
	for child in player_inventory_grid.get_children():
		child.queue_free()
	player_slots.clear()
	
	# 创建背包格子
	var inventory_size = 30  # PlayerInventory.INVENTORY_SIZE
	for i in range(inventory_size):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "player")
		slot.slot_clicked.connect(_on_slot_clicked)
		player_inventory_grid.add_child(slot)
		player_slots.append(slot)

func _create_storage_slots(slot_count: int):
	"""创建存储格子"""
	# 清空现有格子
	for child in storage_grid.get_children():
		child.queue_free()
	storage_slots.clear()
	
	# 创建存储格子
	for i in range(slot_count):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "storage")
		slot.slot_clicked.connect(_on_slot_clicked)
		storage_grid.add_child(slot)
		storage_slots.append(slot)

func _connect_signals():
	"""连接信号"""
	if player_inventory:
		player_inventory.inventory_changed.connect(_on_player_inventory_changed)

func open_player_inventory():
	"""打开玩家背包（无存储）"""
	storage_mode = ""
	current_storage.clear()
	if storage_panel:
		storage_panel.hide()
	_refresh_player_slots()
	_clear_selection()
	_clear_item_info()
	show()
	_disable_player_controls()

func open_chest(chest_storage: Array):
	"""打开宝箱"""
	storage_mode = "chest"
	current_storage = chest_storage
	if storage_title:
		storage_title.text = "宝箱"
	if storage_panel:
		storage_panel.show()
	_create_storage_slots(chest_storage.size())
	_refresh_all_slots()
	_clear_selection()
	_clear_item_info()
	show()
	_disable_player_controls()

func _refresh_player_slots():
	"""刷新玩家背包格子"""
	if not player_inventory:
		return
	
	for i in range(player_slots.size()):
		if i < player_inventory.inventory.size():
			player_slots[i].set_item(player_inventory.inventory[i])

func _refresh_storage_slots():
	"""刷新存储格子"""
	for i in range(storage_slots.size()):
		if i < current_storage.size():
			storage_slots[i].set_item(current_storage[i])

func _refresh_all_slots():
	"""刷新所有格子"""
	_refresh_player_slots()
	_refresh_storage_slots()

func _on_player_inventory_changed():
	"""玩家背包变化"""
	_refresh_player_slots()

func _on_slot_clicked(slot_index: int, storage_type: String):
	"""格子被点击"""
	var storage = player_inventory.inventory if storage_type == "player" else current_storage
	var clicked_item = storage[slot_index] if slot_index < storage.size() else null
	
	# 没有选中物品时
	if selected_slot_index == -1:
		if clicked_item != null:
			# 选中该物品
			_select_slot(slot_index, storage_type)
			_show_item_info(clicked_item)
	else:
		# 已有选中物品时
		if selected_slot_index == slot_index and selected_storage_type == storage_type:
			# 点击同一个格子，取消选中
			_clear_selection()
		else:
			# 移动物品
			_move_item(selected_slot_index, selected_storage_type, slot_index, storage_type)
			
			# 移动后显示目标格子的物品信息
			var target_storage = player_inventory.inventory if storage_type == "player" else current_storage
			var target_item = target_storage[slot_index] if slot_index < target_storage.size() else null
			if target_item != null:
				_show_item_info(target_item)
			else:
				_clear_item_info()
			
			_clear_selection()

func _move_item(from_index: int, from_type: String, to_index: int, to_type: String):
	"""移动物品"""
	if from_type == "player" and to_type == "player":
		# 背包内移动
		player_inventory.move_item(from_index, to_index)
	elif from_type == "player" and to_type == "storage":
		# 从背包到存储
		player_inventory.transfer_to_storage(from_index, current_storage, to_index)
		_refresh_storage_slots()
	elif from_type == "storage" and to_type == "player":
		# 从存储到背包
		player_inventory.transfer_from_storage(current_storage, from_index, to_index)
		_refresh_storage_slots()
	elif from_type == "storage" and to_type == "storage":
		# 存储内移动
		var temp = current_storage[from_index]
		current_storage[from_index] = current_storage[to_index]
		current_storage[to_index] = temp
		_refresh_storage_slots()

func _select_slot(slot_index: int, storage_type: String):
	"""选中格子"""
	_clear_selection()
	selected_slot_index = slot_index
	selected_storage_type = storage_type
	
	var slots = player_slots if storage_type == "player" else storage_slots
	if slot_index < slots.size():
		slots[slot_index].set_selected(true)

func _clear_selection():
	"""清除选中状态"""
	if selected_slot_index != -1:
		var slots = player_slots if selected_storage_type == "player" else storage_slots
		if selected_slot_index < slots.size():
			slots[selected_slot_index].set_selected(false)
	
	selected_slot_index = -1
	selected_storage_type = ""

func _show_item_info(item_data: Dictionary):
	"""显示物品信息"""
	if not player_inventory:
		return
	
	var item_config = player_inventory.get_item_config(item_data.item_id)
	
	item_name_label.text = item_config.get("name", "未知物品")
	item_desc_label.text = item_config.get("description", "无描述")
	
	# 显示图标
	if item_config.has("icon"):
		var icon_path = "res://assets/images/items/" + item_config.icon
		if ResourceLoader.exists(icon_path):
			item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	
	item_desc_label.text += details

func _clear_item_info():
	"""清空物品信息"""
	item_name_label.text = "选择物品查看详情"
	item_desc_label.text = ""
	item_icon.texture = null

func _input(event: InputEvent):
	if not visible:
		return
	
	# B键或ESC键关闭背包
	if event is InputEventKey:
		if event.pressed and (event.keycode == KEY_B or event.keycode == KEY_ESCAPE):
			close_inventory()
			get_viewport().set_input_as_handled()

func close_inventory():
	"""关闭背包"""
	hide()
	_clear_selection()
	_clear_item_info()
	_enable_player_controls()

func _on_close_button_pressed():
	"""关闭按钮"""
	close_inventory()

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
