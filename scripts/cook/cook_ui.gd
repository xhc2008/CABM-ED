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

# 在类变量中添加选中状态
var selected_prep_slot_index: int = -1

# 火焰动画
var fire_sprite: AnimatedSprite2D = null
var fire_sprite_frames: SpriteFrames = null
# 火焰位置偏移
var fire_position_offset: Vector2 = Vector2(-55, -230)  # 默认偏移：向右0，向下20像素
# 火焰音效
var fire_audio_player: AudioStreamPlayer = null
var crack_audio_player: AudioStreamPlayer = null  # 火力变化音效

# 菜品记录
var cooked_dishes: Array[Dictionary] = []  # 存储所有做好的菜品

# 上次火力值（用于检测变化）
var last_heat_level: float = 0.0


func _ready():
	# 设置全屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 加载背景图片
	var background_node = get_node_or_null("Background")
	if background_node:
		var table_path = "res://assets/images/cook/table.png"
		if ResourceLoader.exists(table_path):
			background_node.texture = load(table_path)
	
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
	
	# 初始化火力显示 - 默认值改为0
	if heat_slider:
		heat_slider.value = 0.0
		cook_manager.heat_level = 0.0
		_update_heat_label()
	
	# 加载锅的图片
	if pan_texture:
		var pan_path = "res://assets/images/cook/pan.png"
		if ResourceLoader.exists(pan_path):
			pan_texture.texture = load(pan_path)
	
	# 创建火焰动画
	_create_fire_animation()
	
	# 创建火焰音效播放器
	_create_fire_audio()
	
	# 创建火力变化音效播放器
	_create_crack_audio()
	
	# 初始化上次火力值
	last_heat_level = 0.0
	
	# 调整准备栏布局 - 设置固定列数避免滚动条
	if prep_grid:
		prep_grid.columns = 4
	call_deferred("_update_fire_position")
	# 创建食材准备栏格子
	_create_prep_slots()
	_refresh_prep_slots()
	
	hide()

func _refresh_prep_slots():
	"""刷新食材准备栏格子"""
	if not prep_container:
		return
	
	for i in range(prep_slots.size()):
		if i < prep_container.storage.size():
			prep_slots[i].set_item(prep_container.storage[i])
		else:
			prep_slots[i].set_item(null)
	
	# 更新选中状态
	_update_prep_slots_selection()

func _update_prep_slots_selection():
	"""更新准备栏格子的选中状态"""
	for i in range(prep_slots.size()):
		var slot = prep_slots[i]
		if i == selected_prep_slot_index:
			slot.modulate = Color.YELLOW  # 选中状态用黄色高亮
		else:
			slot.modulate = Color.WHITE

func _process(delta):
	if not visible:
		return
	
	# 更新烹饪状态
	if cook_manager:
		cook_manager.update_cooking(delta)
		_update_ingredient_sprites()
		_update_fire_animation()

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
		# 移除拖拽相关的信号连接
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

func _on_prep_slot_clicked(slot_index: int, _storage_type: String):
	"""准备栏格子被点击"""
	if selected_prep_slot_index == slot_index:
		# 再次点击选中的格子，放入锅中
		_try_add_selected_ingredient_to_pan()
	else:
		# 选中该格子
		selected_prep_slot_index = slot_index
		_update_prep_slots_selection()

func _try_add_selected_ingredient_to_pan():
	"""尝试将选中的食材放入锅中"""
	if selected_prep_slot_index == -1:
		return
	
	if not prep_container:
		return
	
	var item = prep_container.storage[selected_prep_slot_index]
	if item == null:
		return
	
	# 检查是否是食材
	var item_config = items_config.get(item.item_id, {})
	if item_config.get("type") != "食材":
		return
	
	# 尝试添加到锅中
	if _add_ingredient_to_pan(item.item_id):
		# 消耗物品
		prep_container.remove_item(selected_prep_slot_index, 1)
		# 取消选中
		selected_prep_slot_index = -1
		_update_prep_slots_selection()

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

func _add_ingredient_to_pan(item_id: String) -> bool:
	"""添加食材到锅中，返回是否成功"""
	if not cook_manager or not pan_texture:
		return false
	
	# 检查最大数量
	if cook_manager.pan_ingredients.size() >= 20:
		# 可以在这里显示提示信息
		print("锅内食材已满，最多只能放入20个食材")
		return false
	
	var pan_rect = _get_pan_rect()
	cook_manager.add_ingredient_to_pan(item_id, pan_rect)
	
	# 创建食材精灵
	_create_ingredient_sprite(item_id)
	return true

func _get_pan_rect() -> Rect2:
	"""获取锅的矩形区域（相对于锅容器）"""
	if not pan_texture:
		return Rect2()
	
	# 返回相对于pan_texture的矩形，范围调小到锅的实际区域
	var margin = pan_texture.size * 0.3  # 缩小的边距
	return Rect2(margin, pan_texture.size - margin * 2)

func _create_ingredient_sprite(item_id: String):
	"""创建食材精灵"""
	if not pan_texture or not cook_manager:
		return
	
	var item_config = items_config.get(item_id, {})
	if item_config.is_empty():
		return
	
	# 创建精灵节点 - 放大食材大小
	var sprite = Control.new()
	sprite.custom_minimum_size = Vector2(80, 80) 
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
		sprite.position = last_ingredient.position - Vector2(32, 32)  # 调整居中偏移量
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
	inventory_ui.setup_other_container(prep_container, "食材准备")
	
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
		var new_heat_level = value / 100.0
		var old_heat_level = cook_manager.heat_level
		cook_manager.heat_level = new_heat_level
		_update_heat_label()
		
		# 检测火力变化（从0变为非0，或从非0变为0）
		var was_zero = (old_heat_level == 0.0)
		var is_zero = (new_heat_level == 0.0)
		if was_zero != is_zero:
			_play_crack_sound()
		
		_update_fire_animation()
		_update_fire_audio()
		
		# 更新上次火力值
		last_heat_level = new_heat_level

func _update_heat_label():
	"""更新火力标签"""
	if heat_label and heat_slider:
		var heat_percent = int(heat_slider.value)
		heat_label.text = "火力: %d%%" % heat_percent

func _on_serve_pressed():
	"""出锅按钮被点击"""
	if cook_manager.pan_ingredients.is_empty():
		return
	
	# 先移除锅中食材
	var ingredients_to_show = cook_manager.get_finished_ingredients()
	cook_manager.clear_pan()
	_clear_ingredient_sprites()
	
	# 记录菜品信息
	_record_dish(ingredients_to_show)
	
	# 显示结果
	_show_result(ingredients_to_show)

func _show_result(ingredients: Array):
	"""显示出锅结果"""
	if result_panel:
		result_panel.queue_free()
	
	# 创建结果面板
	result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(600, 400)
	
	# 获取视口尺寸
	var viewport_size = get_viewport_rect().size
	
	# 直接计算居中位置
	result_panel.position = Vector2(
		(viewport_size.x - result_panel.custom_minimum_size.x) * 0.5,
		(viewport_size.y - result_panel.custom_minimum_size.y) * 0.5
	)
	
	add_child(result_panel)

	# 内部容器使用正确的预设
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE)
	result_panel.add_child(vbox)
	
	# 标题标签
	var title_label = Label.new()
	title_label.text = "菜名："
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 可编辑的标题输入框
	var title_input = LineEdit.new()
	title_input.text = "蜜汁炖菜"
	title_input.placeholder_text = "请输入菜名"
	title_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_input)
	
	# 保存标题输入框的引用，以便在关闭时获取
	result_panel.set_meta("title_input", title_input)
	
	# 结果容器
	var result_container = Control.new()
	result_container.custom_minimum_size = Vector2(500, 300)
	result_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE)
	vbox.add_child(result_container)
	
	# 背景图片
	var bowl_bg = TextureRect.new()
	bowl_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bowl_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bowl_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bowl_path = "res://assets/images/cook/bowl.png"
	if ResourceLoader.exists(bowl_path):
		bowl_bg.texture = load(bowl_path)
	
	result_container.add_child(bowl_bg)
	
	# 等待一帧让容器尺寸更新
	await get_tree().process_frame
	
	# 获取碗的矩形区域（和锅一样的逻辑，但没有偏移）
	var bowl_rect = _get_bowl_rect(result_container)
	
	# 显示食材（随机放置在碗中）
	for ingredient in ingredients:
		var sprite = Control.new()
		sprite.custom_minimum_size = Vector2(100, 100)
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
		
		# 随机位置和角度（和放入锅一样的逻辑）
		var rand_pos = Vector2(
			randf_range(bowl_rect.position.x, bowl_rect.position.x + bowl_rect.size.x),
			randf_range(bowl_rect.position.y, bowl_rect.position.y + bowl_rect.size.y)
		)
		var rand_rot = randf() * PI * 2
		
		# 关键修改：使用中心点作为位置，而不是左上角
		sprite.position = rand_pos - Vector2(50, 50)  # 居中偏移（食材大小80x80）
		sprite.pivot_offset = Vector2(50, 50)  # 设置旋转中心为食材中心
		sprite.rotation = rand_rot
		sprite.modulate = cook_manager.get_ingredient_color(ingredient)
		result_container.add_child(sprite)
	
	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "确认"
	close_btn.pressed.connect(_on_result_closed)
	vbox.add_child(close_btn)

func _get_bowl_rect(bowl_container: Control) -> Rect2:
	"""获取碗的矩形区域（相对于碗容器）"""
	if not bowl_container:
		return Rect2()
	
	# 返回相对于碗容器的矩形，范围调小到碗的实际区域
	var margin = bowl_container.size * 0.3  # 缩小的边距
	return Rect2(margin, bowl_container.size - margin * 2)


func _on_result_closed():
	"""结果面板关闭"""
	if result_panel:
		# 获取并更新最后一道菜的菜名
		if cooked_dishes.size() > 0:
			var title_input = result_panel.get_meta("title_input", null)
			if title_input:
				var dish_name = title_input.text.strip_edges()
				if dish_name.is_empty():
					dish_name = "蜜汁炖菜"  # 默认名称
				cooked_dishes[-1]["dish_name"] = dish_name
		
		result_panel.queue_free()
		result_panel = null

func _clear_ingredient_sprites():
	"""清空食材精灵"""
	for sprite in ingredient_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	ingredient_sprites.clear()

func _on_close_pressed():
	"""关闭按钮被点击"""
	# 如果有菜品记录，保存记忆
	if cooked_dishes.size() > 0:
		_save_cook_memory()
	
	game_ended.emit()

func show_cook_ui():
	"""显示烹饪UI"""
	show()
	# 更新火焰位置（如果存在）
	if fire_sprite:
		call_deferred("_update_fire_position")
		# 根据当前火力更新火焰状态
		_update_fire_animation()
		_update_fire_audio()

func _update_fire_position():
	"""更新火焰位置"""
	if not fire_sprite or not pan_texture:
		return
	
	var pan_container = pan_texture.get_parent()
	if not pan_container:
		return
	
	# 计算火焰位置（相对于pan_container）
	# 由于pan_texture填充整个pan_container，火焰位置就是容器中心偏下
	var container_size = pan_container.size
	var base_position = Vector2(container_size.x * 0.5, container_size.y * 0.9)
	
	# 应用位置偏移
	fire_sprite.position = base_position + fire_position_offset

func hide_cook_ui():
	"""隐藏烹饪UI"""
	hide()
	# 清理
	_clear_ingredient_sprites()
	if cook_manager:
		cook_manager.clear_pan()
	# 停止火焰音效
	if fire_audio_player:
		fire_audio_player.stop()
	# 隐藏火焰动画
	if fire_sprite:
		fire_sprite.visible = false

func _create_fire_animation():
	"""创建火焰动画"""
	if not pan_texture:
		return
	
	# 获取锅容器（PanContainer）
	var pan_container = pan_texture.get_parent()
	if not pan_container:
		return
	
	# 创建SpriteFrames资源
	fire_sprite_frames = SpriteFrames.new()
	fire_sprite_frames.add_animation("fire")
	
	# 加载所有火焰帧（frame_0001.png 到 frame_0032.png）
	for i in range(1, 33):  # 1到32
		var frame_path = "res://assets/images/cook/fire/frame_%04d.png" % i
		if ResourceLoader.exists(frame_path):
			var texture = load(frame_path)
			fire_sprite_frames.add_frame("fire", texture)
	
	# 设置动画速度
	fire_sprite_frames.set_animation_speed("fire", 10.0)  # 10帧每秒
	fire_sprite_frames.set_animation_loop("fire", true)
	
	# 创建AnimatedSprite2D节点
	fire_sprite = AnimatedSprite2D.new()
	fire_sprite.sprite_frames = fire_sprite_frames
	fire_sprite.animation = "fire"
	fire_sprite.visible = false
	# 在Godot 4中，使用play()方法播放动画
	fire_sprite.play("fire")
	
	# 将火焰添加到锅容器下，放在锅的底部中心
	pan_container.add_child(fire_sprite)
	
	# 关键修改：设置z_index确保火焰在锅之下
	# 锅的z_index是0，将火焰设为-1
	fire_sprite.z_index = -1
	
	# 使用call_deferred来在下一帧更新位置
	call_deferred("_update_fire_position")

func _update_fire_animation():
	"""更新火焰动画（根据火力调整大小和可见性）"""
	if not fire_sprite or not cook_manager or not fire_sprite_frames:
		return
	
	var heat_level = cook_manager.heat_level
	
	if heat_level > 0.0:
		if not fire_sprite.visible:
			fire_sprite.visible = true
			# 确保动画在播放
			if fire_sprite.animation != "fire" or not fire_sprite.is_playing():
				fire_sprite.play("fire")
		
		# 根据火力调整大小（0.3到1.0倍）
		var fire_scale = 0.3 + (heat_level * 0.7)
		fire_sprite.scale = Vector2(fire_scale, fire_scale)
		
		# 调整动画速度（火力越大，动画越快）
		var anim_speed = 8.0 + (heat_level * 12.0)  # 8-20帧每秒
		fire_sprite_frames.set_animation_speed("fire", anim_speed)
	else:
		if fire_sprite.visible:
			fire_sprite.visible = false
			# 停止动画（可选，因为已经隐藏了）
			if fire_sprite.is_playing():
				fire_sprite.stop()

func _create_fire_audio():
	"""创建火焰音效播放器"""
	fire_audio_player = AudioStreamPlayer.new()
	add_child(fire_audio_player)
	
	# 加载火焰音效
	var audio_path = "res://assets/audio/effect/burn.mp3"
	if ResourceLoader.exists(audio_path):
		var audio_stream = load(audio_path)
		if audio_stream:
			# 设置为循环播放
			if audio_stream is AudioStreamMP3:
				audio_stream.loop = true
			elif audio_stream is AudioStreamOggVorbis:
				audio_stream.loop = true
			fire_audio_player.stream = audio_stream
	else:
		print("警告: 火焰音效文件不存在: ", audio_path)

func _update_fire_audio():
	"""更新火焰音效（根据火力播放或停止）"""
	if not fire_audio_player:
		return
	
	var heat_level = cook_manager.heat_level if cook_manager else 0.0
	
	if heat_level > 0.0:
		if not fire_audio_player.playing:
			fire_audio_player.play()
		# 根据火力调整音量（0.3到1.0）
		fire_audio_player.volume_db = linear_to_db(0.3 + (heat_level * 0.7))
	else:
		if fire_audio_player.playing:
			fire_audio_player.stop()

func _create_crack_audio():
	"""创建火力变化音效播放器"""
	crack_audio_player = AudioStreamPlayer.new()
	add_child(crack_audio_player)
	
	# 加载火力变化音效
	var audio_path = "res://assets/audio/effect/crack.mp3"
	if ResourceLoader.exists(audio_path):
		var audio_stream = load(audio_path)
		if audio_stream:
			crack_audio_player.stream = audio_stream
	else:
		print("警告: 火力变化音效文件不存在: ", audio_path)

func _play_crack_sound():
	"""播放火力变化音效"""
	if not crack_audio_player:
		return
	
	# 如果音效文件已加载，播放它
	if crack_audio_player.stream:
		crack_audio_player.play()
		print("播放火力变化音效")

func _record_dish(ingredients: Array):
	"""记录菜品信息"""
	if ingredients.is_empty():
		return
	
	# 统计食材（模糊记录，只记录类型）
	var ingredient_types = {}
	var has_cooked = false
	var has_burnt = false
	
	for ingredient in ingredients:
		var item_id = ingredient.item_id
		var item_config = items_config.get(item_id, {})
		var item_name = item_config.get("name", item_id)
		
		# 模糊记录：只记录食材名称的一部分或简化名称
		# 这里简单记录食材名称的前两个字或整个名称（如果很短）
		var simple_name = item_name
		if item_name.length() > 2:
			simple_name = item_name.substr(0, 2) + "..."
		
		if simple_name in ingredient_types:
			ingredient_types[simple_name] += 1
		else:
			ingredient_types[simple_name] = 1
		
		# 检查是否熟了或焦了
		if ingredient.state == cook_manager.IngredientState.COOKED:
			has_cooked = true
		elif ingredient.state == cook_manager.IngredientState.BURNT:
			has_burnt = true
	
	# 构建食材描述（模糊）
	var ingredients_desc = ""
	var ingredient_list = []
	for ingredient_name in ingredient_types:
		var count = ingredient_types[ingredient_name]
		if count > 1:
			ingredient_list.append("%s×%d" % [ingredient_name, count])
		else:
			ingredient_list.append(ingredient_name)
	
	if ingredient_list.size() > 0:
		ingredients_desc = "、".join(ingredient_list)
	else:
		ingredients_desc = "未知食材"
	
	# 记录菜品
	var dish = {
		"dish_name": "蜜汁炖菜",  # 默认名称，会在关闭结果面板时更新
		"ingredients": ingredients_desc,
		"is_cooked": has_cooked,
		"is_burnt": has_burnt
	}
	
	cooked_dishes.append(dish)
	print("记录菜品: ", dish)

func _save_cook_memory():
	"""保存烹饪记忆"""
	if cooked_dishes.size() == 0:
		return
	
	# 构建记忆内容
	var memory_content = "做了%d道菜：" % cooked_dishes.size()
	var dish_descriptions = []
	
	for dish in cooked_dishes:
		var desc = dish.dish_name
		var details = []
		
		if dish.has("ingredients"):
			details.append("用了" + dish.ingredients)
		
		if dish.has("is_cooked"):
			if dish.is_cooked:
				details.append("熟了")
			elif dish.has("is_burnt") and dish.is_burnt:
				details.append("焦了")
			else:
				details.append("没熟")
		
		if details.size() > 0:
			desc += "（" + "，".join(details) + "）"
		
		dish_descriptions.append(desc)
	
	memory_content += "；".join(dish_descriptions)
	
	# 保存记忆
	if has_node("/root/UnifiedMemorySaver"):
		var memory_saver = get_node("/root/UnifiedMemorySaver")
		var MemoryTypeEnum = memory_saver.MemoryType
		# 使用COOK类型
		await memory_saver.save_memory(
			memory_content,
			MemoryTypeEnum.COOK,
			null,
			"",
			{"type": "cook", "dish_count": cooked_dishes.size()}
		)
	
	# 清空记录
	cooked_dishes.clear()