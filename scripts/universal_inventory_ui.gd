extends Control
class_name UniversalInventoryUI

# 通用背包UI - 可在任何场景使用
# 布局：左侧玩家背包 | 中间容器（可选） | 右侧详细信息

signal closed()

var player_panel: PanelContainer
var player_grid: GridContainer
var player_title: Label

var container_panel: PanelContainer
var container_grid: GridContainer
var container_title: Label

var info_panel: PanelContainer
var info_name: Label
var info_icon: TextureRect
var info_desc: Label

var close_button: Button

var player_container: StorageContainer
var other_container: StorageContainer  # 可选的第二个容器（宝箱、仓库等）

var player_slots: Array = []
var other_slots: Array = []

var selected_slot_index: int = -1
var selected_storage_type: String = ""  # "player" 或 "other"

const SLOT_SCENE = preload("res://scenes/inventory_slot.tscn")

func _ready():
	# 获取节点引用
	_get_node_references()
	
	hide()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# 确保全屏布局
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _get_node_references():
	"""获取节点引用"""
	player_panel = get_node_or_null("Panel/HBoxContainer/PlayerPanel")
	player_grid = get_node_or_null("Panel/HBoxContainer/PlayerPanel/VBox/ScrollContainer/Grid")
	player_title = get_node_or_null("Panel/HBoxContainer/PlayerPanel/VBox/Title")
	
	container_panel = get_node_or_null("Panel/HBoxContainer/ContainerPanel")
	container_grid = get_node_or_null("Panel/HBoxContainer/ContainerPanel/VBox/ScrollContainer/Grid")
	container_title = get_node_or_null("Panel/HBoxContainer/ContainerPanel/VBox/Title")
	
	info_panel = get_node_or_null("Panel/HBoxContainer/InfoPanel")
	info_name = get_node_or_null("Panel/HBoxContainer/InfoPanel/VBox/ItemName")
	info_icon = get_node_or_null("Panel/HBoxContainer/InfoPanel/VBox/ItemIcon")
	info_desc = get_node_or_null("Panel/HBoxContainer/InfoPanel/VBox/ScrollContainer/ItemDescription")
	
	close_button = get_node_or_null("Panel/CloseButton")

func setup_player_inventory(container: StorageContainer, title: String = "背包"):
	"""设置玩家背包"""
	player_container = container
	if player_title:
		player_title.text = title
	_create_player_slots()
	
	if player_container:
		player_container.storage_changed.connect(_refresh_player_slots)

func setup_other_container(container: StorageContainer, title: String = "容器"):
	"""设置其他容器（宝箱、仓库等）"""
	other_container = container
	if container_title:
		container_title.text = title
	_create_other_slots()
	
	if other_container:
		other_container.storage_changed.connect(_refresh_other_slots)

func open_inventory_only():
	"""只打开玩家背包（无其他容器）"""
	if container_panel:
		container_panel.hide()
	_refresh_player_slots()
	_clear_selection()
	_clear_item_info()
	show()

func open_with_container():
	"""打开背包和容器"""
	if container_panel:
		container_panel.show()
	_refresh_all_slots()
	_clear_selection()
	_clear_item_info()
	show()

func close_inventory():
	"""关闭背包"""
	hide()
	_clear_selection()
	_clear_item_info()
	closed.emit()

func _create_player_slots():
	"""创建玩家背包格子"""
	if not player_grid:
		push_error("player_grid 节点未找到")
		return
	
	for child in player_grid.get_children():
		child.queue_free()
	player_slots.clear()
	
	if not player_container:
		return
	
	for i in range(player_container.size):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "player")
		slot.slot_clicked.connect(_on_slot_clicked)
		player_grid.add_child(slot)
		player_slots.append(slot)

func _create_other_slots():
	"""创建其他容器格子"""
	if not container_grid:
		push_error("container_grid 节点未找到")
		return
	
	for child in container_grid.get_children():
		child.queue_free()
	other_slots.clear()
	
	if not other_container:
		return
	
	for i in range(other_container.size):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "other")
		slot.slot_clicked.connect(_on_slot_clicked)
		container_grid.add_child(slot)
		other_slots.append(slot)

func _refresh_player_slots():
	"""刷新玩家背包格子"""
	if not player_container:
		return
	
	for i in range(player_slots.size()):
		if i < player_container.storage.size():
			player_slots[i].set_item(player_container.storage[i])

func _refresh_other_slots():
	"""刷新其他容器格子"""
	if not other_container:
		return
	
	for i in range(other_slots.size()):
		if i < other_container.storage.size():
			other_slots[i].set_item(other_container.storage[i])

func _refresh_all_slots():
	"""刷新所有格子"""
	_refresh_player_slots()
	_refresh_other_slots()

func _on_slot_clicked(slot_index: int, storage_type: String):
	"""格子被点击"""
	var container = player_container if storage_type == "player" else other_container
	if not container:
		return
	
	var clicked_item = container.storage[slot_index] if slot_index < container.storage.size() else null
	
	# 没有选中物品时
	if selected_slot_index == -1:
		if clicked_item != null:
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
			var target_container = player_container if storage_type == "player" else other_container
			var target_item = target_container.storage[slot_index] if slot_index < target_container.storage.size() else null
			if target_item != null:
				_show_item_info(target_item)
			else:
				_clear_item_info()
			
			_clear_selection()

func _move_item(from_index: int, from_type: String, to_index: int, to_type: String):
	"""移动物品"""
	if from_type == to_type:
		# 同一容器内移动
		var container = player_container if from_type == "player" else other_container
		if container:
			container.move_item_internal(from_index, to_index)
	else:
		# 跨容器移动
		var from_container = player_container if from_type == "player" else other_container
		var to_container = player_container if to_type == "player" else other_container
		if from_container and to_container:
			from_container.transfer_to(from_index, to_container, to_index)

func _select_slot(slot_index: int, storage_type: String):
	"""选中格子"""
	_clear_selection()
	selected_slot_index = slot_index
	selected_storage_type = storage_type
	
	var slots = player_slots if storage_type == "player" else other_slots
	if slot_index < slots.size():
		slots[slot_index].set_selected(true)

func _clear_selection():
	"""清除选中状态"""
	if selected_slot_index != -1:
		var slots = player_slots if selected_storage_type == "player" else other_slots
		if selected_slot_index < slots.size():
			slots[selected_slot_index].set_selected(false)
	
	selected_slot_index = -1
	selected_storage_type = ""

func _show_item_info(item_data: Dictionary):
	"""显示物品信息"""
	if not player_container or not info_name or not info_desc or not info_icon:
		return
	
	var item_config = player_container.get_item_config(item_data.item_id)
	
	info_name.text = item_config.get("name", "未知物品")
	info_desc.text = item_config.get("description", "无描述")
	
	# 显示图标
	if item_config.has("icon"):
		var icon_path = "res://assets/images/items/" + item_config.icon
		if ResourceLoader.exists(icon_path):
			info_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			info_icon.texture = load(icon_path)
		else:
			info_icon.texture = null
	else:
		info_icon.texture = null
	
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
	
	info_desc.text += details

func _clear_item_info():
	"""清空物品信息"""
	if info_name:
		info_name.text = "选择物品查看详情"
	if info_desc:
		info_desc.text = ""
	if info_icon:
		info_icon.texture = null

func _input(event: InputEvent):
	if not visible:
		return
	
	# B键或ESC键关闭背包
	if event is InputEventKey:
		if event.pressed and (event.keycode == KEY_B or event.keycode == KEY_ESCAPE):
			close_inventory()
			get_viewport().set_input_as_handled()

func _on_close_pressed():
	"""关闭按钮"""
	close_inventory()
