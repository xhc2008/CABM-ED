# shop_panel.gd
extends Control

# ShopPanel - 基于UniversalInventoryUI的商店面板
# 布局：左侧玩家背包 | 中间商品交易列表 | 右侧商品详情

signal closed()

var universal_inventory: Node
var shop_manager: Node
var shop_background: TextureRect = null

# 商品相关节点
var offers_container: GridContainer  # 改为 GridContainer 类型
var current_offer_rows: Array = []
var selected_shop_slot: Control = null

func _ready():
	# 自动获取 ShopManager 单例
	if has_node("/root/ShopManager"):
		shop_manager = get_node("/root/ShopManager")
	else:
		print("警告: 未找到 ShopManager 单例")

	# 商店背景
	var bg_path = "res://assets/images/shop/internal.png"
	if ResourceLoader.exists(bg_path):
		var tex = load(bg_path)
		var bg = TextureRect.new()
		bg.name = "ShopBackground"
		bg.expand = true
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.texture = tex
		add_child(bg)
		shop_background = bg
	
	# 初始化通用背包UI
	var universal_inventory_scene = preload("res://scenes/universal_inventory_ui.tscn")
	universal_inventory = universal_inventory_scene.instantiate()
	add_child(universal_inventory)
	
	# 设置背包为仅显示模式
	universal_inventory.setup_player_inventory(InventoryManager.inventory_container, "背包")
	
	# 获取商品容器 - 修正节点路径
	offers_container = universal_inventory.get_node("Panel/HBoxContainer/ContainerPanel/VBox/InventoryContainer/ScrollContainer/Grid")
	
	# 连接关闭信号
	var close_button = universal_inventory.get_node("Panel/CloseButton")
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# 隐藏初始状态
	hide()

func open_shop():
	"""打开商店"""
	if not shop_manager or not shop_manager.has_method("get_active_offers"):
		print("ShopPanel: 无法加载商品，ShopManager未设置或无效")
		return
	
	# 设置商店模式
	_setup_shop_mode()
	
	# 显示UI
	show()
	universal_inventory.show()
	universal_inventory.open_with_container()

func close_shop():
	"""关闭商店"""
	hide()
	if universal_inventory:
		universal_inventory.close_inventory()
	_clear_offer_rows()
	closed.emit()

func _setup_shop_mode():
	"""设置商店显示模式"""
	# 修改中间容器标题
	var container_title = universal_inventory.get_node("Panel/HBoxContainer/ContainerPanel/VBox/Title")
	if container_title:
		container_title.text = "商店"
	
	# 清空中间容器并设置为垂直布局
	_clear_offer_rows()
	
	# 设置单列布局显示商品
	offers_container.columns = 1
	offers_container.add_theme_constant_override("separation", 8)
	
	# 加载商品
	_load_offers()

func _load_offers():
	"""从ShopManager加载商品并显示"""
	var active_offers = shop_manager.get_active_offers()
	
	if active_offers.size() == 0:
		print("ShopPanel: 当前没有可用商品")
		return
	
	for i in range(active_offers.size()):
		var offer = active_offers[i]
		if not offer.has("name") or not offer.has("id"):
			print("ShopPanel: 无效的商品数据", offer)
			continue
		
		var row = _create_offer_row(offer)
		offers_container.add_child(row)
		current_offer_rows.append(row)

func _create_offer_row(offer: Dictionary) -> Control:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(0, 96)
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var top_line = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 10)
	top_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var requires_container = HBoxContainer.new()
	requires_container.add_theme_constant_override("separation", 5)
	var _requires = offer.get("requires", [])
	for req in _requires:
		var item_slot = _create_item_slot(req.item_id, req.count)
		requires_container.add_child(item_slot)
	if _requires.size() == 1:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(64, 64)
		requires_container.add_child(spacer)
	top_line.add_child(requires_container)

	var arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.custom_minimum_size = Vector2(40, 0)
	top_line.add_child(arrow_label)

	var gives_container = HBoxContainer.new()
	gives_container.add_theme_constant_override("separation", 5)
	for give in offer.get("gives", []):
		var item_slot = _create_item_slot(give.item_id, give.count)
		gives_container.add_child(item_slot)
	top_line.add_child(gives_container)

	vbox.add_child(top_line)

	var bottom_line = HBoxContainer.new()
	bottom_line.add_theme_constant_override("separation", 10)
	bottom_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var trade_button = Button.new()
	trade_button.text = "交易"
	trade_button.custom_minimum_size = Vector2(100, 36)
	trade_button.pressed.connect(_on_trade_pressed.bind(offer.id))
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.18, 0.55, 0.28, 0.95)
	sb_normal.border_color = Color(0.14, 0.4, 0.22, 1)
	sb_normal.border_width_left = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_bottom = 2
	sb_normal.corner_radius_top_left = 6
	sb_normal.corner_radius_top_right = 6
	sb_normal.corner_radius_bottom_left = 6
	sb_normal.corner_radius_bottom_right = 6
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.22, 0.65, 0.32, 0.95)
	sb_hover.border_color = Color(0.16, 0.45, 0.25, 1)
	sb_hover.border_width_left = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_bottom = 2
	sb_hover.corner_radius_top_left = 6
	sb_hover.corner_radius_top_right = 6
	sb_hover.corner_radius_bottom_left = 6
	sb_hover.corner_radius_bottom_right = 6
	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(0.15, 0.45, 0.24, 0.95)
	sb_pressed.border_color = Color(0.12, 0.35, 0.2, 1)
	sb_pressed.border_width_left = 2
	sb_pressed.border_width_right = 2
	sb_pressed.border_width_top = 2
	sb_pressed.border_width_bottom = 2
	sb_pressed.corner_radius_top_left = 6
	sb_pressed.corner_radius_top_right = 6
	sb_pressed.corner_radius_bottom_left = 6
	sb_pressed.corner_radius_bottom_right = 6
	trade_button.add_theme_stylebox_override("normal", sb_normal)
	trade_button.add_theme_stylebox_override("hover", sb_hover)
	trade_button.add_theme_stylebox_override("pressed", sb_pressed)
	trade_button.add_theme_color_override("font_color", Color(1, 1, 1))
	bottom_line.add_child(trade_button)

	var limit_label = Label.new()
	var bought = offer.get("bought", 0)
	var limit = offer.get("limit", 1)
	limit_label.text = "限购：%d/%d" % [bought, limit]
	if int(bought) >= int(limit):
		limit_label.add_theme_color_override("font_color", Color(1, 0, 0))
	limit_label.custom_minimum_size = Vector2(60, 0)
	limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit_label.add_theme_font_size_override("font_size", 14)
	bottom_line.add_child(limit_label)

	vbox.add_child(bottom_line)

	var item_panel = PanelContainer.new()
	item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_panel.custom_minimum_size = Vector2(0, 110)
	var item_style := StyleBoxFlat.new()
	item_style.bg_color = Color(0.1, 0.1, 0.1, 0.4)
	item_style.border_color = Color(0.45, 0.45, 0.45, 0.9)
	item_style.border_width_left = 1
	item_style.border_width_right = 1
	item_style.border_width_top = 1
	item_style.border_width_bottom = 1
	item_style.corner_radius_top_left = 6
	item_style.corner_radius_top_right = 6
	item_style.corner_radius_bottom_left = 6
	item_style.corner_radius_bottom_right = 6
	item_style.content_margin_left = 12
	item_style.content_margin_right = 12
	item_style.content_margin_top = 10
	item_style.content_margin_bottom = 10
	item_panel.add_theme_stylebox_override("panel", item_style)
	item_panel.add_child(vbox)

	return item_panel

func _create_item_slot(item_id: String, count: int) -> Control:
	"""创建物品格子（复用背包的InventorySlot）"""
	var slot_scene = preload("res://scenes/inventory_slot.tscn")
	var slot = slot_scene.instantiate()
	
	# 设置物品数据
	var item_data = {
		"item_id": item_id,
		"count": int(count)
	}
	slot.set_item(item_data)
	
	# 仅允许点击选中，不处理拖拽/双击
	if slot.has_signal("slot_clicked"):
		slot.slot_clicked.connect(_on_shop_slot_clicked.bind(slot))
	
	# 设置固定大小
	slot.custom_minimum_size = Vector2(64, 64)
	
	return slot

func _on_shop_slot_clicked(_idx: int, _type: String, slot: Control):
	if selected_shop_slot and is_instance_valid(selected_shop_slot):
		selected_shop_slot.set_selected(false)
	selected_shop_slot = slot
	if selected_shop_slot and selected_shop_slot.has_method("set_selected"):
		selected_shop_slot.set_selected(true)
	if universal_inventory and universal_inventory.has_method("_show_item_info"):
		universal_inventory._show_item_info(slot.item_data)

func _on_trade_pressed(offer_id: String):
	"""交易按钮被按下"""
	if not shop_manager or not shop_manager.has_method("trade_offer"):
		print("ShopPanel: 无法完成交易，ShopManager未设置或无效")
		return
	
	var success = shop_manager.trade_offer(offer_id)
	if success:
		print("交易成功: ", offer_id)
		# 刷新UI显示
		_refresh_offers_display()
		
		# 刷新背包显示
		if universal_inventory:
			universal_inventory._refresh_all_slots()
	else:
		print("交易失败: ", offer_id)

func _refresh_offers_display():
	"""刷新商品显示（更新限购数量等）"""
	_clear_offer_rows()
	_load_offers()

func _clear_offer_rows():
	"""清空商品行"""
	for row in current_offer_rows:
		if is_instance_valid(row):
			row.queue_free()
	current_offer_rows.clear()
	selected_shop_slot = null
	if universal_inventory and universal_inventory.has_method("_clear_item_info"):
		universal_inventory._clear_item_info()
		
	# 清空容器
	for child in offers_container.get_children():
		child.queue_free()

func _on_close_pressed():
	"""关闭按钮被按下"""
	close_shop()

func _input(event):
	"""处理输入"""
	if event.is_action_pressed("ui_cancel") and visible:
		close_shop()
