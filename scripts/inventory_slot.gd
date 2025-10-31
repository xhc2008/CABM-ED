extends Panel

# 物品格子组件

signal slot_clicked(slot_index: int, storage_type: String)

@onready var icon_texture = $Icon
@onready var count_label = $CountLabel

var slot_index: int = 0
var storage_type: String = ""  # "inventory" 或 "warehouse"
var item_data: Dictionary = {}  # {item_id: String, count: int}
var is_selected: bool = false

func _ready():
	gui_input.connect(_on_gui_input)
	update_display()

func setup(index: int, type: String):
	"""初始化格子"""
	slot_index = index
	storage_type = type

func set_item(data):
	"""设置物品数据"""
	item_data = data if data != null else {}
	update_display()

func update_display():
	"""更新显示"""
	if not is_node_ready():
		return
	
	if item_data.is_empty():
		# 空格子
		icon_texture.texture = null
		count_label.text = ""
		modulate = Color.WHITE
	else:
		# 有物品
		var item_config = InventoryManager.get_item_config(item_data.item_id)
		if item_config.has("icon"):
			var icon_path = "res://assets/images/items/" + item_config.icon
			if ResourceLoader.exists(icon_path):
				icon_texture.texture = load(icon_path)
			else:
				icon_texture.texture = null
		
		# 显示数量
		if item_data.count > 1:
			count_label.text = str(int(item_data.count))
		else:
			count_label.text = ""
		
		modulate = Color.WHITE
	
	# 更新选中状态
	if is_selected:
		modulate = Color(1.5, 1.5, 0.8)  # 高亮
	else:
		modulate = Color.WHITE

func set_selected(selected: bool):
	"""设置选中状态"""
	is_selected = selected
	update_display()

func _on_gui_input(event: InputEvent):
	"""处理输入"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index, storage_type)
