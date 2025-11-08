extends Control
class_name CookUI

# 烹饪UI - 全屏烹饪界面

signal game_ended()

var cook_manager
var items_config: Dictionary = {}

# UI节点
@onready var pan_texture: TextureRect = $PanContainer/PanTexture
@onready var prep_panel: PanelContainer = $PrepPanel
@onready var prep_grid: GridContainer = $PrepPanel/VBox/ScrollContainer/Grid
@onready var add_ingredient_button: Button = $PrepPanel/VBox/AddIngredientButton
@onready var control_panel: PanelContainer = $ControlPanel
@onready var heat_slider: HSlider = $ControlPanel/VBox/HeatSlider
@onready var heat_label: Label = $ControlPanel/VBox/HeatLabel
@onready var serve_button: Button = $ControlPanel/VBox/ServeButton
@onready var close_button: Button = $ControlPanel/VBox/CloseButton

# 食材准备栏相关
var prep_slots: Array = []
var prep_container: StorageContainer
var inventory_ui: UniversalInventoryUI = null

# 背包UI场景
const INVENTORY_UI_SCENE = preload("res://scenes/universal_inventory_ui.tscn")
const SLOT_SCENE = preload("res://scenes/inventory_slot.tscn")

# 锅中食材显示
var ingredient_sprites: Array[Control] = []

# 出锅结果显示
var result_panel: PanelContainer = null

# 防止清理时的循环触发
var is_cleaning: bool = false

func _ready():
	# 设置全屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 获取物品配置
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		items_config = inv_mgr.items_config
		prep_container = inv_mgr.cook_prep_container
		prep_container.storage_changed.connect(_on_prep_container_changed)
	
	# 初始化烹饪管理器
	var CookManagerClass = load("res://scripts/cook/cook_manager.gd")
	cook_manager = CookManagerClass.new(items_config)
	
	# 连接信号
	if add_ingredient_button:
		add_ingredient_button.pressed.connect(_on_add_ingredient_pressed)
	if heat_slider:
		heat_slider.value_changed.connect(_on_heat_changed)
	if serve_button:
		serve_button.pressed.connect(_on_serve_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# 初始化火力显示
	if heat_slider:
		heat_slider.value = cook_manager.heat_level * 100.0
		_update_heat_label()
	
	# 加载锅的图片
	if pan_texture:
		var pan_path = "res://assets/images/cook/pan.png"
		if ResourceLoader.exists(pan_path):
			pan_texture.texture = load(pan_path)
	
	# 创建食材准备栏格子
	_create_prep_slots()
	_refresh_prep_slots()
	
	hide()

func _process(delta):
	if not visible:
		return
	
	# 更新烹饪状态
	if cook_manager:
		cook_manager.update_cooking(delta)
		_update_ingredient_sprites()

func _create_prep_slots():
	"""创建食材准备栏格子"""
	if not prep_grid or not prep_container:
		return
	
	# 清空现有格子
	for child in prep_grid.get_children():
		child.queue_free()
	prep_slots.clear()
	
	# 创建格子
	for i in range(prep_container.size):
		var slot = SLOT_SCENE.instantiate()
		slot.setup(i, "prep")
		slot.slot_clicked.connect(_on_prep_slot_clicked)
		slot.drag_started.connect(_on_prep_drag_started)
		slot.drag_ended.connect(_on_prep_drag_ended)
		prep_grid.add_child(slot)
		prep_slots.append(slot)

func _on_prep_container_changed():
	"""准备栏容器变化时的处理"""
	# 如果正在清理，跳过
	if is_cleaning:
		return
	
	# 清理非食材物品
	_cleanup_non_ingredient_items()
	# 刷新显示
	_refresh_prep_slots()

func _cleanup_non_ingredient_items():
	"""清理准备栏中的非食材物品，将它们移回背包"""
	if not prep_container or not has_node("/root/InventoryManager"):
		return
	
	# 设置清理标志，防止循环触发
	is_cleaning = true
	
	var inv_mgr = get_node("/root/InventoryManager")
	var items_to_remove = []
	
	# 检查每个格子
	for i in range(prep_container.storage.size()):
		var item = prep_container.storage[i]
		if item != null:
			var item_config = items_config.get(item.item_id, {})
			if item_config.get("type") != "食材":
				# 不是食材，移回背包
				var count = item.count
				var item_id = item.item_id
				if inv_mgr.inventory_container.add_item(item_id, count):
					# 成功移回背包，从准备栏移除
					items_to_remove.append(i)
	
	# 移除非食材物品
	for index in items_to_remove:
		prep_container.storage[index] = null
	
	# 清除清理标志
	is_cleaning = false

func _refresh_prep_slots():
	"""刷新食材准备栏格子"""
	if not prep_container:
		return
	
	for i in range(prep_slots.size()):
		if i < prep_container.storage.size():
			prep_slots[i].set_item(prep_container.storage[i])
		else:
			prep_slots[i].set_item(null)

func _on_prep_slot_clicked(_slot_index: int, _storage_type: String):
	"""准备栏格子被点击"""
	# 可以添加选中逻辑
	pass

func _on_prep_drag_started(_slot_index: int, _storage_type: String):
	"""开始拖拽准备栏物品"""
	# 可以添加拖拽预览
	pass

func _on_prep_drag_ended(slot_index: int, _storage_type: String):
	"""结束拖拽准备栏物品"""
	if not prep_container:
		return
	
	# 检查是否拖拽到锅中
	var mouse_pos = get_global_mouse_position()
	var pan_global_rect = Rect2(pan_texture.global_position, pan_texture.size)
	
	if pan_global_rect.has_point(mouse_pos):
		# 添加到锅中
		var item = prep_container.storage[slot_index]
		if item != null:
			# 检查是否是食材
			var item_config = items_config.get(item.item_id, {})
			if item_config.get("type") == "食材":
				_add_ingredient_to_pan(item.item_id)
				# 消耗物品
				prep_container.remove_item(slot_index, 1)

func _add_ingredient_to_pan(item_id: String):
	"""添加食材到锅中"""
	if not cook_manager or not pan_texture:
		return
	
	var pan_rect = _get_pan_rect()
	cook_manager.add_ingredient_to_pan(item_id, pan_rect)
	
	# 创建食材精灵
	_create_ingredient_sprite(item_id)

func _get_pan_rect() -> Rect2:
	"""获取锅的矩形区域（相对于锅容器）"""
	if not pan_texture:
		return Rect2()
	
	# 返回相对于pan_texture的矩形
	return Rect2(Vector2(0, 0), pan_texture.size)

func _create_ingredient_sprite(item_id: String):
	"""创建食材精灵"""
	if not pan_texture or not cook_manager:
		return
	
	var item_config = items_config.get(item_id, {})
	if item_config.is_empty():
		return
	
	# 创建精灵节点
	var sprite = Control.new()
	sprite.custom_minimum_size = Vector2(32, 32)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 加载图标
	if item_config.has("icon"):
		var icon_path = "res://assets/images/items/" + item_config.icon
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
	
	sprite.add_child(icon)
	pan_texture.add_child(sprite)
	
	# 设置位置（使用最后一个食材的位置，相对于锅）
	if cook_manager.pan_ingredients.size() > 0:
		var last_ingredient = cook_manager.pan_ingredients[-1]
		sprite.position = last_ingredient.position - Vector2(16, 16)
		sprite.rotation = last_ingredient.rotation
	
	ingredient_sprites.append(sprite)

func _update_ingredient_sprites():
	"""更新食材精灵的颜色"""
	if not cook_manager:
		return
	
	for i in range(min(ingredient_sprites.size(), cook_manager.pan_ingredients.size())):
		var sprite = ingredient_sprites[i]
		var ingredient = cook_manager.pan_ingredients[i]
		var color = cook_manager.get_ingredient_color(ingredient)
		sprite.modulate = color

func _on_add_ingredient_pressed():
	"""添加食材按钮被点击"""
	_open_inventory_for_prep()

func _open_inventory_for_prep():
	"""打开背包UI，用于添加食材到准备栏"""
	if inventory_ui != null:
		return
	
	if not has_node("/root/InventoryManager"):
		return
	
	var inv_mgr = get_node("/root/InventoryManager")
	
	# 创建背包UI
	inventory_ui = INVENTORY_UI_SCENE.instantiate()
	add_child(inventory_ui)
	
	# 设置玩家背包和准备栏
	inventory_ui.setup_player_inventory(inv_mgr.inventory_container, "背包")
	inventory_ui.setup_other_container(prep_container, "食材准备栏")
	
	# 打开背包UI
	inventory_ui.open_with_container()
	
	# 连接关闭信号
	inventory_ui.closed.connect(_on_inventory_closed)
	
	# 修改转移逻辑：只允许食材类型
	_override_inventory_transfer_logic()

func _on_inventory_closed():
	"""背包UI关闭"""
	if inventory_ui:
		inventory_ui.queue_free()
		inventory_ui = null

func _override_inventory_transfer_logic():
	"""覆盖背包UI的转移逻辑，只允许食材类型"""
	if not inventory_ui:
		return
	
	# 我们需要拦截转移到准备栏的操作
	# 由于UniversalInventoryUI没有直接的支持，我们需要通过修改容器来实现
	# 在转移时检查物品类型
	# 注意：这个功能需要在UniversalInventoryUI中添加支持，或者我们创建一个包装器
	# 暂时先允许所有物品，但可以在准备栏中过滤显示

func _on_heat_changed(value: float):
	"""火力值改变"""
	if cook_manager:
		cook_manager.heat_level = value / 100.0
		_update_heat_label()

func _update_heat_label():
	"""更新火力标签"""
	if heat_label and heat_slider:
		var heat_percent = int(heat_slider.value)
		heat_label.text = "火力: %d%%" % heat_percent

func _on_serve_pressed():
	"""出锅按钮被点击"""
	if cook_manager.pan_ingredients.is_empty():
		return
	
	# 显示结果
	_show_result()

func _show_result():
	"""显示出锅结果"""
	if result_panel:
		result_panel.queue_free()
	
	# 创建结果面板
	result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(600, 400)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(result_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.text = "出锅结果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 结果容器（使用bowl.png作为背景）
	var result_container = Control.new()
	result_container.custom_minimum_size = Vector2(500, 300)
	result_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 背景图片
	var bowl_bg = TextureRect.new()
	bowl_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bowl_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bowl_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bowl_path = "res://assets/images/cook/bowl.png"
	if ResourceLoader.exists(bowl_path):
		bowl_bg.texture = load(bowl_path)
	
	result_container.add_child(bowl_bg)
	vbox.add_child(result_container)
	
	# 等待一帧让容器尺寸更新
	await get_tree().process_frame
	
	# 显示食材
	var ingredients = cook_manager.get_finished_ingredients()
	for ingredient in ingredients:
		var sprite = Control.new()
		sprite.custom_minimum_size = Vector2(32, 32)
		sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var item_config = items_config.get(ingredient.item_id, {})
		if item_config.has("icon"):
			var icon_path = "res://assets/images/items/" + item_config.icon
			if ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
		
		sprite.add_child(icon)
		
		# 将位置映射到result_container中（相对位置）
		# ingredient.position是相对于锅的位置，需要映射到碗的尺寸
		var pan_size = pan_texture.size if pan_texture else Vector2(500, 400)
		var bowl_size = result_container.size
		var scale_x = bowl_size.x / pan_size.x
		var scale_y = bowl_size.y / pan_size.y
		var mapped_pos = Vector2(
			ingredient.position.x * scale_x,
			ingredient.position.y * scale_y
		)
		
		sprite.position = mapped_pos - Vector2(16, 16)  # 居中
		sprite.rotation = ingredient.rotation
		sprite.modulate = cook_manager.get_ingredient_color(ingredient)
		result_container.add_child(sprite)
	
	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_result_closed)
	vbox.add_child(close_btn)

func _on_result_closed():
	"""结果面板关闭"""
	if result_panel:
		result_panel.queue_free()
		result_panel = null
	
	# 清空锅
	if cook_manager:
		cook_manager.clear_pan()
		_clear_ingredient_sprites()

func _clear_ingredient_sprites():
	"""清空食材精灵"""
	for sprite in ingredient_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	ingredient_sprites.clear()

func _on_close_pressed():
	"""关闭按钮被点击"""
	game_ended.emit()

func show_cook_ui():
	"""显示烹饪UI"""
	show()

func hide_cook_ui():
	"""隐藏烹饪UI"""
	hide()
	# 清理
	_clear_ingredient_sprites()
	if cook_manager:
		cook_manager.clear_pan()

