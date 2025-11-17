# shop_panel.gd
extends Control

# ShopPanel - 基于UniversalInventoryUI的商店面板
# 布局：左侧玩家背包 | 中间商品交易列表 | 右侧商品详情

signal closed()

var universal_inventory: Node
var shop_manager: Node

# 商品相关节点
var offers_container: GridContainer  # 改为 GridContainer 类型
var current_offer_rows: Array = []

func _ready():
	# 自动获取 ShopManager 单例
	if has_node("/root/ShopManager"):
		shop_manager = get_node("/root/ShopManager")
	else:
		print("警告: 未找到 ShopManager 单例")
	
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
	"""创建单个商品交易行"""
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 80)
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 需求物品区域
	var requires_container = HBoxContainer.new()
	requires_container.add_theme_constant_override("separation", 5)
	
	for req in offer.get("requires", []):
		var item_slot = _create_item_slot(req.item_id, req.count)
		requires_container.add_child(item_slot)
	
	hbox.add_child(requires_container)
	
	# 箭头
	var arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(arrow_label)
	
	# 奖励物品区域
	var gives_container = HBoxContainer.new()
	gives_container.add_theme_constant_override("separation", 5)
	
	for give in offer.get("gives", []):
		var item_slot = _create_item_slot(give.item_id, give.count)
		gives_container.add_child(item_slot)
	
	hbox.add_child(gives_container)
	
	# 交易按钮
	var trade_button = Button.new()
	trade_button.text = "交易"
	trade_button.custom_minimum_size = Vector2(80, 60)
	trade_button.pressed.connect(_on_trade_pressed.bind(offer.id))
	hbox.add_child(trade_button)
	
	# 限购信息
	var limit_label = Label.new()
	var bought = offer.get("bought", 0)
	var limit = offer.get("limit", 1)
	limit_label.text = "%d/%d" % [bought, limit]
	limit_label.custom_minimum_size = Vector2(60, 0)
	limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(limit_label)
	
	return hbox

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
	
	# 禁用交互
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置固定大小
	slot.custom_minimum_size = Vector2(64, 64)
	
	return slot

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