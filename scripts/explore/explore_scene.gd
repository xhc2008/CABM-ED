extends Node2D

@onready var player = $Player
@onready var snow_fox = $SnowFox
@onready var tilemap_layers_container = $TileMapLayersContainer
@onready var interaction_prompt = $UI/InteractionPrompt
@onready var inventory_button = $UI/InventoryButton
@onready var ui_root = $UI

var mobile_ui: Control  # 移动端UI (MobileUI)
var is_player_dead: bool = false
var inventory_ui: ExploreInventoryUI
var player_inventory: PlayerInventory
var chest_system: Node # ChestSystem
var drop_system: Node # DropSystem
var nearby_chests: Array = []
var nearby_map_points: Array = []
var current_opened_chest: Dictionary = {}

# 武器系统
var weapon_system: WeaponSystem
var weapon_ui: Control  # 武器UI
var player_health_bar: ProgressBar
var hit_flash: ColorRect
var current_explore_id: String = ""
var active_enemies: Array = []
var enemy_system_data: Dictionary = {}
var enemy_layer

var background_layer
var frontground_layer

var chunk_size_tiles: int = 64
var active_radius_chunks: int = 2
var bg_chunk_data := {}
var fg_chunk_data := {}
var loaded_chunks_bg := {}
var loaded_chunks_fg := {}
var last_player_chunk := Vector2i(2147483647, 2147483647)

# 探索模式的临时背包状态（进入时加载，退出时保存）
var temp_player_inventory = {}  # 可以是 Array 或 Dictionary
var temp_snow_fox_inventory = {}  # 可以是 Array 或 Dictionary

var last_exit_was_death: bool = false
var _map_config: Dictionary = {}

func _ready():
	# 固定分辨率和缩放模式已在项目设置中配置
	# window/size/viewport: 1280x720
	# window/stretch/mode: "viewport" - 使用固定分辨率视口
	# window/stretch/aspect: "keep" - 保持宽高比，不同屏幕直接缩放
	
	# 初始化系统
	var inventory_script = load("res://scripts/explore/player_inventory.gd")
	player_inventory = inventory_script.new()
	add_child(player_inventory)
	
	var chest_script = load("res://scripts/explore/chest_system.gd")
	chest_system = chest_script.new()
	add_child(chest_system)

	var drop_script = load("res://scripts/explore/drop_system.gd")
	drop_system = drop_script.new()
	add_child(drop_system)
	
	# 加载探索模式的背包状态
	_load_explore_inventory_state()
	
	# 初始化武器系统
	var weapon_system_script = load("res://scripts/explore/weapon_system.gd")
	weapon_system = weapon_system_script.new()
	add_child(weapon_system)
	weapon_system.setup(player_inventory)

	if drop_system:
		drop_system.setup(player_inventory.items_config)
	
	# 连接武器系统到玩家
	if player:
		player.setup_weapon_system(weapon_system)
	
	# 创建背包UI
	var inventory_ui_scene = load("res://scenes/explore_inventory_ui.tscn")
	inventory_ui = inventory_ui_scene.instantiate()
	$UI.add_child(inventory_ui)
	inventory_ui.setup(player_inventory, chest_system)
	
	# 连接背包关闭信号（只连接一次）
	if inventory_ui.closed.is_connected(_on_inventory_closed):
		inventory_ui.closed.disconnect(_on_inventory_closed)
	inventory_ui.closed.connect(_on_inventory_closed)
	
	# 创建武器UI
	_create_weapon_ui()
	
	# 确保战斗UI初始显示
	_show_combat_ui()
	
	# 设置雪狐跟随玩家
	if snow_fox and player:
		snow_fox.set_follow_target(player)
	
	# 创建移动端UI
	_create_mobile_ui()
	_create_health_ui()
	_create_hit_flash()

	_load_tilemap_for_explore_id()
	
	# 连接交互检测器信号
	if player and player.has_method("get_interaction_detector"):
		var detector = player.get_interaction_detector()
		if detector and detector.has_signal("interactions_changed"):
			detector.interactions_changed.connect(_on_interactions_changed)
	
	if inventory_button:
		inventory_button.text = "背包 (E)"
		inventory_button.custom_minimum_size = Vector2(100, 40)
		
		# 设置锚点到右上角
		inventory_button.anchor_right = 1.0
		inventory_button.anchor_top = 0.0
		inventory_button.anchor_left = 1.0
		inventory_button.anchor_bottom = 0.0
		
		# 设置边距（距离右上角20像素）
		inventory_button.offset_right = -120  # 100(按钮宽度) + 20(边距)
		inventory_button.offset_top = 20
		inventory_button.offset_left = -120
		inventory_button.offset_bottom = 60   # 20 + 40(按钮高度)
		
		inventory_button.pressed.connect(_on_inventory_button_pressed)
	# 重置死亡状态
	is_player_dead = false

func _load_tilemap_for_explore_id():
	var explore_id := ""
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.save_data.has("explore_checkpoint"):
			var cp = sm.save_data.explore_checkpoint
			if cp.has("scene_id"):
				explore_id = cp.scene_id
	if explore_id == "":
		if has_node("/root/SaveManager"):
			var sm_fallback = get_node("/root/SaveManager")
			if sm_fallback.save_data.has("explore_checkpoint"):
				sm_fallback.save_data.erase("explore_checkpoint")
				sm_fallback.save_game(sm_fallback.current_slot)
		get_tree().change_scene_to_file("res://scripts/main.tscn")
		return
	current_explore_id = explore_id
	if has_node("/root/SaveManager"):
		var sm2 = get_node("/root/SaveManager")
		sm2.set_meta("explore_current_id", current_explore_id)
	var path := "res://scenes/explore_maps/%s.tscn" % explore_id
	if not ResourceLoader.exists(path):
		if has_node("/root/SaveManager"):
			var sm_fb2 = get_node("/root/SaveManager")
			if sm_fb2.save_data.has("explore_checkpoint"):
				sm_fb2.save_data.erase("explore_checkpoint")
				sm_fb2.save_game(sm_fb2.current_slot)
		get_tree().change_scene_to_file("res://scripts/main.tscn")
		return
	var scene_res = load(path)
	if scene_res == null:
		if has_node("/root/SaveManager"):
			var sm_fb3 = get_node("/root/SaveManager")
			if sm_fb3.save_data.has("explore_checkpoint"):
				sm_fb3.save_data.erase("explore_checkpoint")
				sm_fb3.save_game(sm_fb3.current_slot)
		get_tree().change_scene_to_file("res://scripts/main.tscn")
		return
	var new_container = scene_res.instantiate()
	if new_container == null:
		if has_node("/root/SaveManager"):
			var sm_fb4 = get_node("/root/SaveManager")
			if sm_fb4.save_data.has("explore_checkpoint"):
				sm_fb4.save_data.erase("explore_checkpoint")
				sm_fb4.save_game(sm_fb4.current_slot)
		get_tree().change_scene_to_file("res://scripts/main.tscn")
		return
	if tilemap_layers_container and is_instance_valid(tilemap_layers_container):
		tilemap_layers_container.queue_free()
	new_container.name = "TileMapLayersContainer"
	add_child(new_container)
	tilemap_layers_container = new_container

	background_layer = tilemap_layers_container.get_node_or_null("Background")
	frontground_layer = tilemap_layers_container.get_node_or_null("Frontground")
	if frontground_layer == null or background_layer == null:
		for child in tilemap_layers_container.get_children():
			if child is TileMapLayer:
				if background_layer == null:
					background_layer = child
				elif frontground_layer == null:
					frontground_layer = child

	if background_layer:
		background_layer.z_index = 0
	if frontground_layer:
		frontground_layer.z_index = 1
	# 查找敌人刷新层
	enemy_layer = tilemap_layers_container.get_node_or_null("EnemyLayer")
	if enemy_layer == null:
		enemy_layer = tilemap_layers_container.get_node_or_null("enemylayer")
	if enemy_layer == null:
		for child in tilemap_layers_container.get_children():
			if child is TileMapLayer and String(child.name).to_lower().contains("enemy"):
				enemy_layer = child
				break
	if player:
		player.z_index = 2
	if snow_fox:
		snow_fox.z_index = 2
	if has_node("/root/SaveManager") and chest_system and chest_system.has_method("set_current_scene_id"):
		chest_system.set_current_scene_id(explore_id)
	if drop_system and drop_system.has_method("set_current_scene_id"):
		drop_system.set_current_scene_id(explore_id)
		drop_system.spawn_drops_for_current_scene()
	_spawn_enemies_for_scene(explore_id)

	_setup_chunk_streaming()
	_restore_checkpoint_if_available()

func _process(_delta):
	if player:
		_check_nearby_chests()
		_check_nearby_map_points()
		_update_loaded_chunks()
	
	# 自动射击检查
	if not inventory_ui or not inventory_ui.visible:
		# PC端：鼠标左键
		if player and not player.is_mobile:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				var mouse_pos = get_viewport().get_mouse_position()
				if not _is_click_on_ui(mouse_pos):
					_handle_shoot()
		# 移动端：触摸射击区域
		elif mobile_ui and mobile_ui.is_shooting_active():
			_handle_shoot()

func _check_nearby_chests():
	if not player.interaction_detector:
		return
	var layer_to_check = frontground_layer if frontground_layer != null else background_layer
	var chest_tiles = player.interaction_detector.check_tilemap_interactions(layer_to_check)
	if chest_tiles == null:
		chest_tiles = []
	var available_chests = chest_tiles
	var needs_update = false
	if available_chests.size() != nearby_chests.size():
		needs_update = true
	else:
		var fox_in_range = false
		if snow_fox:
			var distance_to_fox = player.global_position.distance_to(snow_fox.global_position)
			var fox_interaction_distance = 48.0
			fox_in_range = distance_to_fox <= fox_interaction_distance
		var had_fox_interaction = false
		for interaction in interaction_prompt.interactions:
			if interaction.get("type") == "snow_fox":
				had_fox_interaction = true
				break
		if fox_in_range != had_fox_interaction:
			needs_update = true
	nearby_chests = available_chests
	if needs_update:
		_update_interaction_prompt()

func _check_nearby_map_points():
	if not player.interaction_detector:
		return
	var layer_to_check = frontground_layer if frontground_layer != null else background_layer
	var maps = player.interaction_detector.check_map_points(layer_to_check)
	if maps == null:
		maps = []
	var changed = maps.size() != nearby_map_points.size()
	nearby_map_points = maps
	if changed:
		_update_interaction_prompt()

func _update_interaction_prompt():
	"""更新交互提示"""
	if not interaction_prompt:
		return
	
	# 收集所有可交互对象
	var interactions = []
	
	# 添加宝箱交互
	for chest in nearby_chests:
		var chest_type = chest.get("chest_type", "common_chest")
		var chest_name = chest_system.get_chest_name_by_type(chest_type)
		interactions.append({
			"text": "F: " + chest_name,
			"callback": func(): _open_chest(chest),
			"object": chest,
			"type": "chest"
		})
	
	# 添加雪狐交互（距离更近才能交互）
	if snow_fox and player:
		var distance_to_fox = player.global_position.distance_to(snow_fox.global_position)
		var fox_interaction_distance = 48.0 # 雪狐交互距离设置为50像素
		if distance_to_fox <= fox_interaction_distance:
			var character_name = _get_character_name()
			interactions.append({
				"text": "F: " + character_name,
				"callback": func(): _open_snow_fox_storage(),
				"object": snow_fox,
				"type": "snow_fox"
			})

	if not nearby_map_points.is_empty():
		interactions.append({
			"text": "F: 撤离",
			"callback": func(): _open_map_from_explore(),
			"object": null,
		"type": "map"
		})

	if player and player.interaction_detector:
		var area_interactions = player.interaction_detector.get_interactions()
		for data in area_interactions:
			interactions.append(data)
	
	if interactions.is_empty():
		interaction_prompt.hide_interactions()
	else:
		interaction_prompt.show_interactions(interactions)

func _open_chest(chest_data: Dictionary):
	"""开启宝箱"""
	# 直接从chest_data获取宝箱类型
	var chest_type = chest_data.get("chest_type", "common_chest")
	var chest_name = chest_system.get_chest_name_by_type(chest_type)
	
	print("打开宝箱 - 类型: ", chest_type, ", 名称: ", chest_name)
	
	# 获取宝箱存储（如果已打开过则返回保存的状态）
	var chest_storage = chest_system.get_chest_storage(chest_data.position, chest_type)
	current_opened_chest = {
		"position": chest_data.position,
		"storage": chest_storage,
		"chest_type": chest_type
	}
	
	# 打开背包UI显示宝箱
	if inventory_ui:
		inventory_ui.open_chest(chest_storage, chest_name, chest_data.position)
	
	# 隐藏战斗UI
	_hide_combat_ui()
	
	# 隐藏交互提示
	interaction_prompt.hide_interactions()

func _open_snow_fox_storage():
	"""打开雪狐的背包"""
	if not snow_fox:
		return
	
	# 获取雪狐的存储（支持新旧格式）
	var fox_storage_data = snow_fox.get_storage()
	
	# 打开背包UI显示雪狐背包（启用武器栏）
	if inventory_ui:
		var character_name = _get_character_name()
		inventory_ui.open_chest(fox_storage_data, character_name + "的背包", Vector2i.ZERO, true)
	
	# 隐藏战斗UI
	_hide_combat_ui()
	
	# 隐藏交互提示
	interaction_prompt.hide_interactions()

func _open_map_from_explore():
	_save_explore_inventory_state()
	var memory_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if memory_saver:
		var user_name := "玩家"
		var scene_name := _get_explore_display_name(current_explore_id)
		if has_node("/root/SaveManager"):
			var smem = get_node("/root/SaveManager")
			user_name = smem.get_user_name()
		var base_text := "我和%s在%s进行了探索，" % [user_name, scene_name]
		var tail_text := "我们顺利撤离"
		if last_exit_was_death:
			tail_text = "我们在战斗中倒下了"
		var memory_content := base_text + tail_text
		var meta := {
			"type": "explore",
			"explore_id": current_explore_id,
			"result": "death" if last_exit_was_death else "evacuated"
		}
		await memory_saver.save_memory(memory_content, memory_saver.MemoryType.EXPLORE, null, "", meta)
	last_exit_was_death = false
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.set_meta("open_map_on_load", true)
		sm.set_meta("map_origin", "explore")
		if sm.save_data.has("explore_checkpoint"):
			sm.save_data.erase("explore_checkpoint")
		sm.save_game(sm.current_slot)
	get_tree().change_scene_to_file("res://scripts/main.tscn")

func update_snow_fox_storage(storage_data):
	"""更新雪狐背包数据（从背包UI回调）"""
	if snow_fox:
		snow_fox.set_storage(storage_data)
		if SaveManager:
			SaveManager.save_data.snow_fox_inventory = storage_data.duplicate(true)
			SaveManager.save_game(SaveManager.current_slot)

func _on_inventory_closed():
	"""当背包UI关闭时调用"""
	print("explore_scene: _on_inventory_closed 被调用")
	
	# 重置当前打开的宝箱
	current_opened_chest = {}
	
	# 显示战斗UI
	_show_combat_ui()

	# 重新检查附近的交互对象
	_check_nearby_chests()
	_update_interaction_prompt()
	
	print("背包已关闭，重新显示交互提示")

func _on_interactions_changed(_interactions: Array):
	"""交互列表变化"""
	_update_interaction_prompt()

func _on_joystick_updated(vector: Vector2, _power: float = 1.0):
	"""处理摇杆输入更新"""
	if player and player.has_method("set_joystick_direction"):
		player.set_joystick_direction(vector)

func _on_inventory_button_pressed():
	"""背包按钮点击"""
	if inventory_ui:
		if inventory_ui.visible:
			inventory_ui.close_inventory()
			_show_combat_ui()
		else:
			inventory_ui.open_player_inventory()
			_hide_combat_ui()

func _input(event: InputEvent):
	# 如果背包打开，不处理其他输入
	if inventory_ui and inventory_ui.visible:
		return
	
	# E键打开/关闭背包
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_E:
			if inventory_ui:
				if inventory_ui.visible:
					inventory_ui.close_inventory()
					_show_combat_ui()
				else:
					inventory_ui.open_player_inventory()
					_hide_combat_ui()
				get_viewport().set_input_as_handled()
		
		# R键换弹
		if event.pressed and event.keycode == KEY_R:
			if weapon_system:
				weapon_system.start_reload()
			get_viewport().set_input_as_handled()
	
	# 鼠标左键射击（仅PC端）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 移动端不响应鼠标点击射击
			if player and player.is_mobile:
				return
			
			# 检查是否点击在UI元素上
			if _is_click_on_ui(event.position):
				print("点击在UI上，不执行射击")
				return
			
			# 执行射击
				_handle_shoot()
				get_viewport().set_input_as_handled()

func _create_health_ui():
	player_health_bar = ProgressBar.new()
	player_health_bar.position = Vector2(20, 20)
	player_health_bar.size = Vector2(240, 24)
	player_health_bar.min_value = 0
	player_health_bar.max_value = 100
	player_health_bar.value = 100
	ui_root.add_child(player_health_bar)
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.player_hit.connect(_on_player_hit)
		player.player_died.connect(_on_player_died)

func _on_player_health_changed(cur: int, max: int):
	player_health_bar.max_value = max
	player_health_bar.value = cur

func _create_hit_flash():
	hit_flash = ColorRect.new()
	hit_flash.color = Color(1, 0, 0, 0.0)
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hit_flash)

func _flash_screen():
	if not hit_flash:
		return
	hit_flash.color = Color(1, 0, 0, 0.0)
	var tween = hit_flash.create_tween()
	tween.tween_property(hit_flash, "color:a", 0.35, 0.08)
	tween.tween_property(hit_flash, "color:a", 0.0, 0.25)

func _on_player_hit(_damage: int):
	_flash_screen()
	show_damage_number(_damage, player.global_position)

func show_damage_number(value: int, world_pos: Vector2, color: Color = Color(1,0,0)):
	var label = Label.new()
	label.text = "-" + str(value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0,0,0))
	label.z_index = 3
	# 生成随机起始偏移
	var start_offset_x = randf_range(-40.0, 0.0)
	var start_offset_y = randf_range(-15.0, -5.0)
	
	# 设置初始位置
	label.global_position = world_pos + Vector2(start_offset_x, start_offset_y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.top_level = true
	
	add_child(label)
	
	var tween = label.create_tween()
	
	# 目标位置：主要向上，但有随机左右偏移
	var target_offset_x = randf_range(-40.0, 0.0)  # 水平随机偏移
	var target_offset_y = randf_range(-40.0, -25.0) # 垂直向上移动
	
	var target = world_pos + Vector2(target_offset_x, target_offset_y)
	
	tween.tween_property(label, "global_position", target, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	await tween.finished
	label.queue_free()

func update_enemy_state(enemy_node):
	var sid = enemy_node.get_meta("spawn_id") if enemy_node else ""
	if sid == "":
		return
	if not enemy_system_data.has(current_explore_id):
		enemy_system_data[current_explore_id] = []
	var arr = enemy_system_data[current_explore_id]
	var found = false
	for i in range(arr.size()):
		if arr[i].get("id", "") == sid:
			arr[i].health = enemy_node.health
			arr[i].pos = [enemy_node.global_position.x, enemy_node.global_position.y]
			found = true
			break
	if not found:
		arr.append({"id": sid, "type": "basic", "pos": [enemy_node.global_position.x, enemy_node.global_position.y], "health": enemy_node.health})
	enemy_system_data[current_explore_id] = arr
	if SaveManager:
		SaveManager.save_data.enemy_system_data = enemy_system_data.duplicate(true)
		SaveManager.save_game(SaveManager.current_slot)

func get_enemy_save_data() -> Dictionary:
	var result := enemy_system_data.duplicate(true)
	var arr := []
	for enemy in active_enemies:
		var sid = enemy.get_meta("spawn_id")
		if sid == null:
			continue
		arr.append({
			"id": sid,
			"type": "basic",
			"pos": [enemy.global_position.x, enemy.global_position.y],
			"health": enemy.health
		})
	result[current_explore_id] = arr
	return result

func _on_player_died():
	# 防止重复执行死亡逻辑
	if is_player_dead:
		return
	
	print("玩家死亡，开始处理死亡逻辑...")
	is_player_dead = true
	last_exit_was_death = true
	
	# 禁用玩家控制
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
	
	# 保存死亡前的掉落物
	if drop_system and InventoryManager:
		var scene_id = current_explore_id
		var pos = player.global_position if player else Vector2.ZERO
		var container = InventoryManager.inventory_container
		if container:
			print("开始掉落玩家物品...")
			if container.has_weapon_slot and not container.weapon_slot.is_empty():
				var w = container.weapon_slot
				print("掉落武器: ", w.get("item_id", ""))
				drop_system.create_drop(w.get("item_id",""), int(w.get("count",1)), scene_id, pos, w.duplicate(true))
				container.weapon_slot = {}
			for i in range(container.storage.size()):
				var item = container.storage[i]
				if item != null:
					print("掉落物品: ", item.get("item_id", ""), " x", item.get("count", 1))
					drop_system.create_drop(item.get("item_id",""), int(item.get("count",1)), scene_id, pos, item.duplicate(true))
					container.storage[i] = null
			container.storage_changed.emit()
	
	# 保存探索状态（宝箱、掉落物、敌人状态）
	print("保存探索状态...")
	_save_explore_inventory_state()
	if has_node("/root/SaveManager"):
		var sm2 = get_node("/root/SaveManager")
		if sm2.save_data.has("explore_checkpoint"):
			sm2.save_data.erase("explore_checkpoint")
	_open_map_from_explore()

func _show_death_message():
	if has_node("/root/MessageDisplayManager"):
		var mgr = get_node("/root/MessageDisplayManager")
		mgr.show_failure_message("你被击倒了")

func _is_click_on_ui(click_position: Vector2) -> bool:
	"""检查点击位置是否在UI元素上"""
	for child in $UI.get_children():
		if child is Control and child.visible:
			if child.mouse_filter != Control.MOUSE_FILTER_STOP:
				continue
			var rect = child.get_global_rect()
			if rect.has_point(click_position):
				return true
	return false

func _handle_shoot():
	"""处理射击"""
	if not player or not weapon_system:
		return

func _load_map_config():
	if _map_config.is_empty():
		var path := "res://config/map.json"
		if FileAccess.file_exists(path):
			var f = FileAccess.open(path, FileAccess.READ)
			var js = f.get_as_text()
			f.close()
			var j = JSON.new()
			if j.parse(js) == OK:
				_map_config = j.data

func _get_explore_display_name(explore_id: String) -> String:
	_load_map_config()
	if _map_config.has("world") and _map_config.world.has("points"):
		for p in _map_config.world.points:
			if p.get("id", "") == explore_id and p.get("type", "") == "explore":
				return p.get("name", explore_id)
	return explore_id
	var shoot_position = player.get_shoot_position()
	var aim_direction = player.get_aim_direction()
	var player_rotation = player.rotation
	# if player and player.is_mobile:
	# 	# 移动端按 _process 中的持续射击逻辑触发，这里避免重复
	# 	return
	weapon_system.shoot(shoot_position, aim_direction, player_rotation)

func _create_weapon_ui():
	"""创建武器UI"""
	var weapon_ui_scene = load("res://scenes/weapon_ui.tscn")
	if ResourceLoader.exists("res://scenes/weapon_ui.tscn"):
		weapon_ui = weapon_ui_scene.instantiate()
		if weapon_ui:
			$UI.add_child(weapon_ui)
			weapon_ui.setup(weapon_system)

func _spawn_enemies_for_scene(explore_id: String):
	if enemy_system_data.has(explore_id):
		for entry in enemy_system_data[explore_id]:
			var pid = entry.get("id", "")
			if pid == "":
				continue
			var pos = Vector2(entry.pos[0], entry.pos[1])
			var e = _spawn_enemy_at(pos, entry.get("type", "basic"), pid)
			if e and entry.has("health"):
				e.health = int(entry.health)
	else:
		var points = _get_enemy_points_from_layer(enemy_layer)
		var spawned_entries := []
		for point in points:
			var pid = point.get("id", "")
			if pid == "":
				continue
			var e2 = _spawn_enemy_at(point.pos, point.get("type", "basic"), pid)
			if e2:
				spawned_entries.append({"id": pid, "type": point.get("type", "basic"), "pos": [point.pos.x, point.pos.y], "health": e2.health})
		enemy_system_data[explore_id] = spawned_entries
		if SaveManager:
			SaveManager.save_data.enemy_system_data = enemy_system_data.duplicate(true)

func _get_enemy_points_from_layer(layer: TileMapLayer) -> Array:
	var result: Array = []
	if layer == null:
		return result
	var cells = layer.get_used_cells()
	for cell in cells:
		var local_pos = layer.map_to_local(cell)
		var world_pos = layer.to_global(local_pos)
		var td = layer.get_cell_tile_data(cell)
		var etype = "basic"
		if td:
			var d = td.get_custom_data("enemy_type")
			if d is String and d != "":
				etype = d
		var pid = "%s_%d_%d" % [etype, int(cell.x), int(cell.y)]
		result.append({"id": pid, "type": etype, "pos": world_pos})
	return result

func _spawn_enemy_at(pos: Vector2, enemy_type: String, spawn_id: String):
	var enemy_script = load("res://scripts/explore/enemy_basic.gd")
	var enemy = enemy_script.new()
	enemy.enemy_type = enemy_type
	add_child(enemy)
	enemy.global_position = pos
	enemy.set_player(player)
	enemy.set_drop_system(drop_system)
	enemy.set_meta("spawn_id", spawn_id)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	active_enemies.append(enemy)
	return enemy

func _on_enemy_died(enemy_node):
	var sid = enemy_node.get_meta("spawn_id") if enemy_node else ""
	if sid == "" or not SaveManager:
		return
	active_enemies.erase(enemy_node)
	if enemy_system_data.has(current_explore_id):
		var arr = enemy_system_data[current_explore_id]
		for i in range(arr.size()):
			if arr[i].get("id", "") == sid:
				arr.remove_at(i)
				break
		SaveManager.save_data.enemy_system_data = enemy_system_data.duplicate(true)
		SaveManager.save_game(SaveManager.current_slot)

func _create_mobile_ui():
	"""创建移动端UI"""
	var mobile_ui_scene = load("res://scenes/mobile_ui.tscn")
	if ResourceLoader.exists("res://scenes/mobile_ui.tscn"):
		mobile_ui = mobile_ui_scene.instantiate()
		if mobile_ui:
			$UI.add_child(mobile_ui)
			
			# 连接摇杆到玩家
			if player:
				var joystick = mobile_ui.get_joystick()
				if joystick:
					player.joystick_left = joystick
					# 连接摇杆信号
					if joystick.has_signal("updated"):
						joystick.updated.connect(_on_joystick_updated)
					elif joystick.has_signal("input_updated"):
						joystick.input_updated.connect(_on_joystick_updated)
					elif joystick.has_signal("value_changed"):
						joystick.value_changed.connect(_on_joystick_updated)
			
			# 连接射击和换弹信号
			mobile_ui.shoot_started.connect(_on_mobile_shoot_started)
			mobile_ui.shoot_stopped.connect(_on_mobile_shoot_stopped)
			mobile_ui.reload_pressed.connect(_on_mobile_reload_pressed)

func _on_mobile_shoot_started():
	"""移动端开始射击"""
	pass  # 在_process中持续射击

func _on_mobile_shoot_stopped():
	"""移动端停止射击"""
	pass

func _on_mobile_reload_pressed():
	"""移动端换弹"""
	if weapon_system:
		weapon_system.start_reload()


func set_player_controls_enabled(enabled: bool):
	"""启用/禁用玩家控制"""
	if player:
		player.set_physics_process(enabled)
		player.set_process_input(enabled)
	
	# 禁用交互提示
	if interaction_prompt:
		if not enabled:
			interaction_prompt.hide_interactions()
		interaction_prompt.set_process_input(enabled)

func _load_explore_inventory_state():
	"""加载探索模式的背包状态"""
	if not InventoryManager:
		return
	
	# 从主背包加载到探索模式的临时背包
	temp_player_inventory = InventoryManager.inventory_container.get_data()
	player_inventory.container.load_data(temp_player_inventory)
	
	# 从存档加载雪狐背包
	if SaveManager and SaveManager.save_data.has("snow_fox_inventory"):
		temp_snow_fox_inventory = SaveManager.save_data.snow_fox_inventory.duplicate(true)
		if snow_fox:
			snow_fox.set_storage(temp_snow_fox_inventory)
	else:
		# 初始化空背包（正确格式）
		var storage_array = []
		storage_array.resize(snow_fox.STORAGE_SIZE if snow_fox else 12)
		for i in range(storage_array.size()):
			storage_array[i] = null
		
		temp_snow_fox_inventory = {
			"storage": storage_array,
			"weapon_slot": {}
		}
		if snow_fox:
			snow_fox.set_storage(temp_snow_fox_inventory)
	
	# 从存档加载宝箱数据
	if SaveManager and SaveManager.save_data.has("chest_system_data"):
		chest_system.load_save_data(SaveManager.save_data.chest_system_data)

	# 从存档加载掉落物数据
	if drop_system and SaveManager and SaveManager.save_data.has("drop_system_data"):
		drop_system.load_save_data(SaveManager.save_data.drop_system_data)
	# 从存档加载敌人状态数据
	if SaveManager and SaveManager.save_data.has("enemy_system_data"):
		enemy_system_data = SaveManager.save_data.enemy_system_data.duplicate(true)
	
	print("已加载探索模式背包状态")
	player_inventory.container = InventoryManager.inventory_container

func _save_explore_inventory_state():
	"""保存探索模式的背包状态"""
	if not SaveManager:
		return
	if snow_fox:
		var fox_storage = snow_fox.get_storage()
		SaveManager.save_data.snow_fox_inventory = fox_storage.duplicate(true) if fox_storage is Dictionary else fox_storage
	if chest_system:
		SaveManager.save_data.chest_system_data = chest_system.get_save_data()
	if drop_system:
		SaveManager.save_data.drop_system_data = drop_system.get_save_data()
	# 保存敌人状态
	SaveManager.save_data.enemy_system_data = get_enemy_save_data()
	SaveManager.save_game(SaveManager.current_slot)
	print("已保存探索模式背包状态")

func _hide_combat_ui():
	"""隐藏战斗相关UI（打开背包时）"""
	print("隐藏战斗UI")
	# 隐藏武器UI
	if weapon_ui:
		weapon_ui.visible = false
	
	# 隐藏移动端UI
	if mobile_ui:
		mobile_ui.visible = false

func _show_combat_ui():
	"""显示战斗相关UI（关闭背包时）"""
	print("显示战斗UI")
	# 显示武器UI
	if weapon_ui:
		weapon_ui.visible = true
	
	# 显示移动端UI（仅移动端）
	if mobile_ui:
		mobile_ui.visible = PlatformManager.is_mobile_platform()
	_update_interaction_prompt()

func _get_character_name() -> String:
	"""获取角色名称"""
	if not has_node("/root/SaveManager"):
		return "角色"
	
	var save_mgr = get_node("/root/SaveManager")
	return save_mgr.get_character_name()

func get_player_inventory() -> PlayerInventory:
	return player_inventory

func get_checkpoint_data() -> Dictionary:
	var scene_id := current_explore_id
	var ppos = player.global_position if player else Vector2.ZERO
	var fpos = snow_fox.global_position if snow_fox else Vector2.ZERO
	return {
		"active": true,
		"scene_id": scene_id,
		"player_pos": {"x": ppos.x, "y": ppos.y},
		"snow_fox_pos": {"x": fpos.x, "y": fpos.y}
	}

func get_field_state_data() -> Dictionary:
	var chest_data = {}
	var drop_data = {}
	if chest_system and chest_system.has_method("get_save_data"):
		chest_data = chest_system.get_save_data()
	if drop_system and drop_system.has_method("get_save_data"):
		drop_data = drop_system.get_save_data()
	var enemy_data = get_enemy_save_data()
	return {"chest_system_data": chest_data, "drop_system_data": drop_data, "enemy_system_data": enemy_data}

func _restore_checkpoint_if_available():
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	if not sm.save_data.has("explore_checkpoint"):
		return
	var cp = sm.save_data.explore_checkpoint
	if not cp.get("active", false):
		return
	if player and cp.has("player_pos"):
		var p = cp.player_pos
		if p.has("x") and p.has("y"):
			player.global_position = Vector2(float(p.x), float(p.y))
	if snow_fox and cp.has("snow_fox_pos"):
		var s = cp.snow_fox_pos
		if s.has("x") and s.has("y"):
			snow_fox.global_position = Vector2(float(s.x), float(s.y))

func _save_checkpoint_immediately():
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.save_game(sm.current_slot)

func _setup_chunk_streaming():
	if background_layer:
		bg_chunk_data = _build_chunk_data_for_layer(background_layer)
		var cells_bg = background_layer.get_used_cells()
		for pos in cells_bg:
			background_layer.erase_cell(pos)
	if frontground_layer:
		fg_chunk_data = _build_chunk_data_for_layer(frontground_layer)
		var cells_fg = frontground_layer.get_used_cells()
		for pos in cells_fg:
			frontground_layer.erase_cell(pos)
	last_player_chunk = Vector2i(2147483647, 2147483647)
	_update_loaded_chunks()

func _build_chunk_data_for_layer(layer: TileMapLayer) -> Dictionary:
	var data := {}
	var cells = layer.get_used_cells()
	for pos in cells:
		var key = Vector2i(int(floor(pos.x / float(chunk_size_tiles))), int(floor(pos.y / float(chunk_size_tiles))))
		if not data.has(key):
			data[key] = []
		var source_id = layer.get_cell_source_id(pos)
		var atlas_coords = layer.get_cell_atlas_coords(pos)
		var alt = layer.get_cell_alternative_tile(pos)
		data[key].append({
			"pos": pos,
			"source": source_id,
			"atlas": atlas_coords,
			"alt": alt
		})
	return data

func _get_player_chunk() -> Vector2i:
	var base_layer = background_layer if background_layer != null else frontground_layer
	if base_layer == null or player == null:
		return last_player_chunk
	var tile_pos = base_layer.local_to_map(base_layer.to_local(player.global_position))
	return Vector2i(int(floor(tile_pos.x / float(chunk_size_tiles))), int(floor(tile_pos.y / float(chunk_size_tiles))))

func _update_loaded_chunks():
	var cur_chunk = _get_player_chunk()
	if cur_chunk == last_player_chunk:
		return
	last_player_chunk = cur_chunk
	var desired := {}
	for dx in range(-active_radius_chunks, active_radius_chunks + 1):
		for dy in range(-active_radius_chunks, active_radius_chunks + 1):
			var key = Vector2i(cur_chunk.x + dx, cur_chunk.y + dy)
			desired[key] = true
	if background_layer:
		for key in desired.keys():
			if not loaded_chunks_bg.has(key) and bg_chunk_data.has(key):
				_load_chunk_into_layer(background_layer, bg_chunk_data, key)
				loaded_chunks_bg[key] = true
		for key in loaded_chunks_bg.keys():
			if not desired.has(key):
				_unload_chunk_from_layer(background_layer, bg_chunk_data, key)
				loaded_chunks_bg.erase(key)
	if frontground_layer:
		for key in desired.keys():
			if not loaded_chunks_fg.has(key) and fg_chunk_data.has(key):
				_load_chunk_into_layer(frontground_layer, fg_chunk_data, key)
				loaded_chunks_fg[key] = true
		for key in loaded_chunks_fg.keys():
			if not desired.has(key):
				_unload_chunk_from_layer(frontground_layer, fg_chunk_data, key)
				loaded_chunks_fg.erase(key)

func _load_chunk_into_layer(layer: TileMapLayer, chunk_data: Dictionary, key: Vector2i):
	var arr = chunk_data.get(key, [])
	for item in arr:
		layer.set_cell(item.pos, item.source, item.atlas, item.alt)

func _unload_chunk_from_layer(layer: TileMapLayer, chunk_data: Dictionary, key: Vector2i):
	var arr = chunk_data.get(key, [])
	for item in arr:
		layer.erase_cell(item.pos)
