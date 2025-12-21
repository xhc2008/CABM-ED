extends Node2D

@onready var player = $Player
@onready var snow_fox = $SnowFox
@onready var tilemap_layers_container = $TileMapLayersContainer
@onready var interaction_prompt = $UI/InteractionPrompt
@onready var inventory_button = $UI/InventoryButton
@onready var ui_root = $UI

var mobile_ui: Control  # 移动端UI (MobileUI)
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

# 模块化管理器
var enemy_manager: ExploreSceneEnemyManager
var chunk_manager: ExploreSceneChunkManager
var scene_state: ExploreSceneState
var chat_and_info_manager: Node  # ChatAndInfoManager
var explore_chat_summary_manager: Node  # 探索聊天总结管理器

var enemy_layer
var background_layer
var frontground_layer

# 加载界面
var loading_view: Control
var death_view: Control

func _ready():
	# 初始化场景状态管理器
	scene_state = ExploreSceneState.new()
	add_child(scene_state)
	scene_state.set_state(ExploreSceneState.State.LOADING)
	
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
	
	# 初始化聊天和信息播报管理器
	var manager_script = load("res://scripts/explore/chat_and_info_manager.gd")
	chat_and_info_manager = manager_script.new()
	add_child(chat_and_info_manager)
	chat_and_info_manager.setup(ui_root, _get_character_name, _get_explore_scene_name)
	chat_and_info_manager.chat_mode_changed.connect(_on_chat_mode_changed)

	# 初始化探索聊天总结管理器
	var summary_manager_script = load("res://scripts/explore/explore_chat_summary_manager.gd")
	explore_chat_summary_manager = summary_manager_script.new()
	add_child(explore_chat_summary_manager)
	explore_chat_summary_manager.setup()

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
	
	# 场景加载完成，设置为活跃状态
	scene_state.set_state(ExploreSceneState.State.ACTIVE)

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
	
	scene_state.current_explore_id = explore_id
	if has_node("/root/SaveManager"):
		var sm2 = get_node("/root/SaveManager")
		sm2.set_meta("explore_current_id", scene_state.current_explore_id)
	
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
	
	# 初始化敌人管理器
	enemy_manager = ExploreSceneEnemyManager.new()
	add_child(enemy_manager)
	enemy_manager.setup(player, drop_system, enemy_layer, self)
	enemy_manager.set_explore_id(explore_id)
	
	# 加载敌人数据
	if SaveManager and SaveManager.save_data.has("enemy_system_data"):
		enemy_manager.load_enemy_data(SaveManager.save_data.enemy_system_data)
	
	# 生成敌人
	enemy_manager.spawn_enemies_for_scene(explore_id)

	# 初始化区块管理器
	chunk_manager = ExploreSceneChunkManager.new()
	add_child(chunk_manager)
	chunk_manager.setup(background_layer, frontground_layer, player)
	
	# 恢复检查点
	scene_state.restore_checkpoint(player, snow_fox)

	# 加载聊天历史
	_load_chat_history()

func _process(delta):
	# 如果正在退出，不处理任何逻辑
	if scene_state and scene_state.is_exiting():
		return
	
	if player and scene_state and scene_state.is_active():
		_check_nearby_chests()
		_check_nearby_map_points()
		
		# 更新区块加载
		if chunk_manager:
			chunk_manager.update_loaded_chunks()
	
	# 自动射击检查（仅在活跃状态，且未打开背包/聊天）
	var is_inventory_open := inventory_ui and inventory_ui.visible
	var in_chat_mode: bool = chat_and_info_manager != null and chat_and_info_manager.is_in_chat_mode
	if scene_state and scene_state.is_active() and (not is_inventory_open) and (not in_chat_mode):
		# PC端：鼠标左键
		if player and not player.is_mobile:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				var mouse_pos = get_viewport().get_mouse_position()
				if not _is_click_on_ui(mouse_pos):
					_handle_shoot()
		# 移动端：触摸射击区域
		elif mobile_ui and mobile_ui.is_shooting_active():
			_handle_shoot()
	
	# 更新信息播报计时
	if chat_and_info_manager:
		chat_and_info_manager.update(delta)

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
	# 立即暂停所有交互
	_pause_exploration()
	
	# 显示加载界面
	_show_loading_view("正在撤离...", "离开当前区域...")
	if loading_view:
		loading_view.set_progress(0.0)
	await get_tree().create_timer(0.1).timeout

	# 保存状态
	if loading_view:
		loading_view.set_progress(20.0)
	_save_explore_inventory_state()

	# 保存记忆
	if loading_view:
		loading_view.set_progress(35.0)
	var memory_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if memory_saver:
		var user_name := "玩家"
		var scene_name := scene_state.get_explore_display_name(scene_state.current_explore_id)
		if has_node("/root/SaveManager"):
			var smem = get_node("/root/SaveManager")
			user_name = smem.get_user_name()

		# 构建基础记忆文本
		var base_text := "我和%s在%s进行了探索，" % [user_name, scene_name]
		var tail_text := "我们顺利撤离。"
		if scene_state.last_exit_was_death:
			tail_text = "我们在战斗中倒下了。"

		# 进行聊天归档总结（如果有聊天历史）
		var conversation_history = chat_and_info_manager.get_ai_context_history() if chat_and_info_manager else []
		var summary_content := ""
		if not conversation_history.is_empty() and explore_chat_summary_manager:
			if loading_view:
				loading_view.set_status("正在清点物资...")
				loading_view.set_progress(50.0)

			# 调用总结模型生成归档内容（只获取总结部分）
			var archived_summary = await explore_chat_summary_manager.call_explore_summary_api(
				conversation_history, user_name, scene_name)

			if not archived_summary.is_empty():
				# AI总结内容直接使用，确保以逗号结尾以便连接
				summary_content = archived_summary.strip_edges()

		# 组合最终记忆内容
		var memory_content = base_text  + tail_text + summary_content

		# 获取完整的display_history
		var display_history = chat_and_info_manager.get_display_history() if chat_and_info_manager else []

		var meta := {
			"type": "explore",
			"explore_id": scene_state.current_explore_id,
			"result": "death" if scene_state.last_exit_was_death else "evacuated",
			"display_history": display_history
		}

		if loading_view:
			loading_view.set_status("总结探索经历...")
			loading_view.set_progress(70.0)

		await memory_saver.save_memory(memory_content, memory_saver.MemoryType.EXPLORE, null, "", meta)
	
	scene_state.last_exit_was_death = false
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.set_meta("open_map_on_load", true)
		sm.set_meta("map_origin", "explore")
		if sm.save_data.has("explore_checkpoint"):
			sm.save_data.erase("explore_checkpoint")
		sm.save_game(sm.current_slot)

	# 清理聊天历史文件
	_clear_chat_history()
	
	if loading_view:
		# loading_view.set_status("完成！")
		loading_view.complete()
	
	await get_tree().create_timer(0.3).timeout
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
	# 如果正在退出，不处理任何输入
	if scene_state and scene_state.is_exiting():
		return
	
	# 聊天模式下：只处理ESC键退出聊天，不拦截T键
	if chat_and_info_manager and chat_and_info_manager.is_in_chat_mode:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			chat_and_info_manager.exit_chat_mode()
			get_viewport().set_input_as_handled()
		# 不处理其他按键，让聊天框的输入框能正常接收输入
		return
	
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
			if weapon_system and player:
				weapon_system.start_reload(player.global_position)
			get_viewport().set_input_as_handled()
		
		# T键只在聊天框未打开时打开聊天框
		if event.pressed and event.keycode == KEY_T:
			if chat_and_info_manager and not chat_and_info_manager.is_in_chat_mode:
				chat_and_info_manager.enter_chat_mode()
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

func _on_player_health_changed(cur: int, max_health: int):
	player_health_bar.max_value = max_health
	player_health_bar.value = cur

func _create_hit_flash():
	hit_flash = ColorRect.new()
	hit_flash.color = Color(1, 0, 0, 0.0)
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hit_flash)

func _on_chat_mode_changed(is_in_chat: bool):
	"""聊天模式变化回调"""
	if is_in_chat:
		set_player_controls_enabled(false)
		_hide_combat_ui()
	else:
		set_player_controls_enabled(true)
		_show_combat_ui()

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
	"""更新敌人状态（委托给敌人管理器）"""
	if enemy_manager:
		enemy_manager.update_enemy_state(enemy_node)

func get_enemy_save_data() -> Dictionary:
	"""获取敌人保存数据（委托给敌人管理器）"""
	if enemy_manager:
		return enemy_manager.get_enemy_save_data()
	return {}

func _on_player_died():
	# 防止重复执行死亡逻辑
	if scene_state.is_player_dead:
		return
	
	print("玩家死亡，开始处理死亡逻辑...")
	scene_state.is_player_dead = true
	scene_state.last_exit_was_death = true
	
	# 立即暂停所有交互
	_pause_exploration()
	
	# 显示死亡界面
	_show_death_view()
	
	# 立即开始完整的保存流程（包括记忆）
	_handle_death_complete_save()
	
	# 等待玩家确认
	await _wait_for_death_view_close()
	
	# 直接返回主场景（不再调用 _open_map_from_explore，避免重复保存）
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.set_meta("open_map_on_load", true)
		sm.set_meta("map_origin", "explore")
	
	get_tree().change_scene_to_file("res://scripts/main.tscn")

func _handle_death_complete_save():
	"""异步处理死亡的完整保存逻辑（包括记忆）"""
	# 保存死亡前的掉落物
	if loading_view:
		loading_view.set_progress(20.0)
	if drop_system and InventoryManager:
		var scene_id = scene_state.current_explore_id
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
	if loading_view:
		loading_view.set_progress(40.0)
	print("保存探索状态...")
	_save_explore_inventory_state()

	# 清除检查点
	if loading_view:
		loading_view.set_progress(60.0)
	if has_node("/root/SaveManager"):
		var sm2 = get_node("/root/SaveManager")
		if sm2.save_data.has("explore_checkpoint"):
			sm2.save_data.erase("explore_checkpoint")
		sm2.save_game(sm2.current_slot)

	# 清理聊天历史文件
	_clear_chat_history()

	# 保存记忆（异步）
	if loading_view:
		loading_view.set_progress(80.0)
	var memory_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if memory_saver:
		var user_name := "玩家"
		var scene_name := scene_state.get_explore_display_name(scene_state.current_explore_id)
		if has_node("/root/SaveManager"):
			var smem = get_node("/root/SaveManager")
			user_name = smem.get_user_name()

		# 构建基础记忆文本
		var base_text := "我和%s在%s进行了探索，" % [user_name, scene_name]
		var tail_text := "我们在战斗中倒下了"

		# 进行聊天归档总结（如果有聊天历史）
		var conversation_history = chat_and_info_manager.get_ai_context_history() if chat_and_info_manager else []
		var summary_content := ""
		if not conversation_history.is_empty() and explore_chat_summary_manager:
			print("正在总结死亡前的探索经历...")

			# 调用总结模型生成归档内容（只获取总结部分）
			var archived_summary = await explore_chat_summary_manager.call_explore_summary_api(
				conversation_history, user_name, scene_name)

			if not archived_summary.is_empty():
				# AI总结内容直接使用，确保以逗号结尾以便连接
				summary_content = archived_summary.strip_edges()
				if not summary_content.is_empty() and not summary_content.ends_with("，"):
					summary_content += "，"

		# 获取完整的display_history
		var display_history = chat_and_info_manager.get_display_history() if chat_and_info_manager else []

		# 组合最终记忆内容
		var memory_content = base_text + summary_content + tail_text
		var meta := {
			"type": "explore",
			"explore_id": scene_state.current_explore_id,
			"result": "death",
			"display_history": display_history
		}

		print("开始保存死亡记忆...")
		await memory_saver.save_memory(memory_content, memory_saver.MemoryType.EXPLORE, null, "", meta)
		print("死亡记忆保存完成")
	
	print("死亡完整保存流程完成")

func _pause_exploration():
	"""暂停探索相关逻辑"""
	print("暂停探索逻辑...")
	scene_state.set_state(ExploreSceneState.State.EXITING)
	
	# 禁用玩家控制和交互
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		
		# 禁用玩家的交互检测器（这会阻止检测掉落物）
		if player.has_method("get_interaction_detector"):
			var detector = player.get_interaction_detector()
			if detector and detector.has_method("disable"):
				detector.disable()
	
	# 禁用雪狐
	if snow_fox:
		snow_fox.set_physics_process(false)
	
	# 强制隐藏所有交互提示
	if interaction_prompt:
		interaction_prompt.hide_interactions()
		interaction_prompt.set_process(false)
		interaction_prompt.set_process_input(false)
	
	# 禁用敌人
	if enemy_manager:
		for enemy in enemy_manager.active_enemies:
			if is_instance_valid(enemy):
				enemy.set_physics_process(false)
	
	# 禁用掉落物交互
	if drop_system and drop_system.has_method("disable_all_drops"):
		drop_system.disable_all_drops()

func _show_loading_view(title: String, status: String):
	"""显示加载界面"""
	if loading_view:
		loading_view.queue_free()
	
	var loading_scene = load("res://scenes/loading_view.tscn")
	loading_view = loading_scene.instantiate()
	ui_root.add_child(loading_view)
	loading_view.set_title(title)
	loading_view.set_status(status)

func _show_death_view():
	"""显示死亡界面"""
	if death_view:
		death_view.queue_free()
	
	var death_scene = load("res://scenes/death_view.tscn")
	death_view = death_scene.instantiate()
	ui_root.add_child(death_view)

func _wait_for_death_view_close() -> void:
	"""等待死亡界面关闭"""
	if not death_view:
		return
	
	if death_view.has_signal("death_view_closed"):
		await death_view.death_view_closed
	else:
		# 如果没有信号，等待按钮点击
		var return_button = death_view.get_node_or_null("Panel/VBox/ReturnButton")
		if return_button:
			await return_button.pressed

func _is_click_on_ui(click_position: Vector2) -> bool:
	"""检查点击位置是否在UI元素上"""
	for child in $UI.get_children():
		if child is Control and child.visible:
			# 排除信息播报区域（InfoFeed），不将其视为UI
			if child.name == "InfoFeed":
				continue
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
			
			# 连接射击、换弹和聊天信号
			mobile_ui.shoot_started.connect(_on_mobile_shoot_started)
			mobile_ui.shoot_stopped.connect(_on_mobile_shoot_stopped)
			mobile_ui.reload_pressed.connect(_on_mobile_reload_pressed)
			
			if mobile_ui.has_signal("chat_button_pressed"):
				mobile_ui.chat_button_pressed.connect(_on_mobile_chat_button_pressed)

func _on_mobile_shoot_started():
	"""移动端开始射击"""
	pass  # 在_process中持续射击

func _on_mobile_shoot_stopped():
	"""移动端停止射击"""
	pass

func _on_mobile_reload_pressed():
	"""移动端换弹"""
	if weapon_system and player:
		weapon_system.start_reload(player.global_position)

func _on_mobile_chat_button_pressed():
	"""移动端聊天按钮点击"""
	if chat_and_info_manager:
		if chat_and_info_manager.is_in_chat_mode:
			chat_and_info_manager.exit_chat_mode()
		else:
			chat_and_info_manager.enter_chat_mode()
		
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
	scene_state.temp_player_inventory = InventoryManager.inventory_container.get_data()
	player_inventory.container.load_data(scene_state.temp_player_inventory)
	
	# 从存档加载雪狐背包
	if SaveManager and SaveManager.save_data.has("snow_fox_inventory"):
		scene_state.temp_snow_fox_inventory = SaveManager.save_data.snow_fox_inventory.duplicate(true)
		if snow_fox:
			snow_fox.set_storage(scene_state.temp_snow_fox_inventory)
	else:
		# 初始化空背包（正确格式）
		var storage_array = []
		storage_array.resize(snow_fox.STORAGE_SIZE if snow_fox else 12)
		for i in range(storage_array.size()):
			storage_array[i] = null
		
		scene_state.temp_snow_fox_inventory = {
			"storage": storage_array,
			"weapon_slot": {}
		}
		if snow_fox:
			snow_fox.set_storage(scene_state.temp_snow_fox_inventory)
	
	# 从存档加载宝箱数据
	if SaveManager and SaveManager.save_data.has("chest_system_data"):
		chest_system.load_save_data(SaveManager.save_data.chest_system_data)

	# 从存档加载掉落物数据
	if drop_system and SaveManager and SaveManager.save_data.has("drop_system_data"):
		drop_system.load_save_data(SaveManager.save_data.drop_system_data)
	
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

func _get_explore_scene_name() -> String:
	"""获取当前探索场景的显示名称"""
	if scene_state and not scene_state.current_explore_id.is_empty():
		return scene_state.get_explore_display_name(scene_state.current_explore_id)
	return ""

func get_player_inventory() -> PlayerInventory:
	return player_inventory

func get_checkpoint_data() -> Dictionary:
	"""获取检查点数据（委托给状态管理器）"""
	var ppos = player.global_position if player else Vector2.ZERO
	var fpos = snow_fox.global_position if snow_fox else Vector2.ZERO
	return scene_state.get_checkpoint_data(ppos, fpos)

func get_field_state_data() -> Dictionary:
	"""获取场景状态数据"""
	var chest_data = {}
	var drop_data = {}
	if chest_system and chest_system.has_method("get_save_data"):
		chest_data = chest_system.get_save_data()
	if drop_system and drop_system.has_method("get_save_data"):
		drop_data = drop_system.get_save_data()
	var enemy_data = get_enemy_save_data()
	return {"chest_system_data": chest_data, "drop_system_data": drop_data, "enemy_system_data": enemy_data}

func _save_chat_history():
	"""保存聊天历史到磁盘"""
	if not chat_and_info_manager:
		return

	var save_data = {
		"conversation_history": chat_and_info_manager.get_ai_context_history(),
		"display_history": chat_and_info_manager.get_display_history()
	}

	var save_path = "user://explore_chat_history_%s.save" % scene_state.current_explore_id
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("已保存探索聊天历史: ", scene_state.current_explore_id)

func _load_chat_history():
	"""从磁盘加载聊天历史"""
	if not chat_and_info_manager:
		return

	var save_path = "user://explore_chat_history_%s.save" % scene_state.current_explore_id
	if not FileAccess.file_exists(save_path):
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_string) == OK:
			var save_data = json.data
			if save_data.has("conversation_history"):
				# 恢复AI上下文历史
				var conversation_history = save_data.conversation_history
				if chat_and_info_manager.adventure_ai:
					chat_and_info_manager.adventure_ai.conversation_history = conversation_history.duplicate()

			if save_data.has("display_history"):
				# 恢复显示历史
				var display_history = save_data.display_history
				if chat_and_info_manager.adventure_ai:
					chat_and_info_manager.adventure_ai.display_history = display_history.duplicate()

				# 恢复聊天UI显示
				chat_and_info_manager.set_chat_messages(_extract_chat_messages_from_display_history(display_history))

		print("已加载探索聊天历史: ", scene_state.current_explore_id)

func _extract_chat_messages_from_display_history(display_history: Array) -> Array[String]:
	"""从显示历史中提取聊天消息"""
	var chat_messages: Array[String] = []

	for item in display_history:
		var content = item.get("content", "")
		if not content.is_empty():
			chat_messages.append(content)

	return chat_messages

func _clear_chat_history():
	"""清除聊天历史文件"""
	var save_path = "user://explore_chat_history_%s.save" % scene_state.current_explore_id
	if FileAccess.file_exists(save_path):
		var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		if error == OK:
			print("已清除探索聊天历史文件: ", scene_state.current_explore_id)
		else:
			push_error("清除聊天历史文件失败: ", error)
