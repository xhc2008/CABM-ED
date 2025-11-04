extends Node2D

@onready var player = $Player
@onready var snow_fox = $SnowFox
@onready var joystick = $UI/VirtualJoystick
@onready var tilemap_layer = $TileMapLayer
@onready var interaction_prompt = $UI/InteractionPrompt
@onready var inventory_button = $UI/InventoryButton

var inventory_ui: ExploreInventoryUI
var player_inventory: PlayerInventory
var chest_system: Node  # ChestSystem
var nearby_chests: Array = []
var current_opened_chest: Dictionary = {}

func _ready():
	# 初始化系统
	var inventory_script = load("res://scripts/explore/player_inventory.gd")
	player_inventory = inventory_script.new()
	add_child(player_inventory)
	
	var chest_script = load("res://scripts/explore/chest_system.gd")
	chest_system = chest_script.new()
	add_child(chest_system)
	
	# 创建背包UI
	var inventory_ui_scene = load("res://scenes/explore_inventory_ui.tscn")
	inventory_ui = inventory_ui_scene.instantiate()
	$UI.add_child(inventory_ui)
	inventory_ui.setup(player_inventory, chest_system)
	
	# 设置雪狐跟随玩家
	if snow_fox and player:
		snow_fox.set_follow_target(player)
	
	# 连接摇杆信号
	if joystick and player:
		joystick.direction_changed.connect(_on_joystick_direction_changed)
	
	# 连接交互检测器信号
	if player and player.interaction_detector:
		player.interaction_detector.interactions_changed.connect(_on_interactions_changed)
	
	# 连接背包按钮
	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_button_pressed)

func _process(_delta):
	# 检查TileMapLayer上的宝箱
	if player and tilemap_layer:
		_check_nearby_chests()

func _check_nearby_chests():
	"""检查附近的宝箱"""
	if not player.interaction_detector:
		return
	
	var chest_tiles = player.interaction_detector.check_tilemap_interactions(tilemap_layer)
	if chest_tiles == null:
		chest_tiles = []
	
	# 过滤已开启的宝箱
	var available_chests = []
	for chest in chest_tiles:
		if not chest_system.is_chest_opened(chest.position):
			available_chests.append(chest)
	
	# 检查是否需要更新交互提示
	var needs_update = false
	if available_chests.size() != nearby_chests.size():
		needs_update = true
	else:
		# 检查雪狐距离是否变化（进入或离开交互范围）
		var fox_in_range = false
		if snow_fox:
			var distance_to_fox = player.global_position.distance_to(snow_fox.global_position)
			var fox_interaction_distance = 48.0  # 雪狐交互距离
			fox_in_range = distance_to_fox <= fox_interaction_distance
		
		# 如果雪狐状态变化，需要更新
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
		var fox_interaction_distance = 48.0  # 雪狐交互距离设置为50像素
		if distance_to_fox <= fox_interaction_distance:
			interactions.append({
				"text": "F: 雪狐",
				"callback": func(): _open_snow_fox_storage(),
				"object": snow_fox,
				"type": "snow_fox"
			})
	
	if interactions.is_empty():
		interaction_prompt.hide_interactions()
	else:
		interaction_prompt.show_interactions(interactions)

func _open_chest(chest_data: Dictionary):
	"""开启宝箱"""
	if chest_system.is_chest_opened(chest_data.position):
		return
	
	# 直接从chest_data获取宝箱类型
	var chest_type = chest_data.get("chest_type", "common_chest")
	var chest_name = chest_system.get_chest_name_by_type(chest_type)
	
	print("打开宝箱 - 类型: ", chest_type, ", 名称: ", chest_name)
	
	# 生成战利品
	var loot = chest_system.generate_chest_loot(chest_type)
	current_opened_chest = {
		"position": chest_data.position,
		"storage": loot
	}
	
	# 标记为已开启
	chest_system.mark_chest_opened(chest_data.position)
	
	# 打开背包UI显示宝箱
	if inventory_ui:
		inventory_ui.open_chest(loot, chest_name)
	
	# 隐藏交互提示
	interaction_prompt.hide_interactions()
	
	# 从附近宝箱列表移除
	nearby_chests.erase(chest_data)

func _open_snow_fox_storage():
	"""打开雪狐的背包"""
	if not snow_fox:
		return
	
	# 获取或初始化雪狐的存储
	var fox_storage = snow_fox.get_storage()
	
	# 打开背包UI显示雪狐背包
	if inventory_ui:
		inventory_ui.open_chest(fox_storage, "雪狐的背包")
	
	# 隐藏交互提示
	interaction_prompt.hide_interactions()

func _on_interactions_changed(_interactions: Array):
	"""交互列表变化"""
	# 这里可以处理其他类型的交互物体
	pass

func _on_joystick_direction_changed(direction: Vector2):
	if player:
		player.set_joystick_direction(direction)

func _on_inventory_button_pressed():
	"""背包按钮点击"""
	if inventory_ui:
		if inventory_ui.visible:
			inventory_ui.close_inventory()
		else:
			inventory_ui.open_player_inventory()

func _input(event: InputEvent):
	# 如果背包打开，不处理其他输入
	if inventory_ui and inventory_ui.visible:
		return
	
	# B键打开/关闭背包
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_B:
			if inventory_ui:
				inventory_ui.open_player_inventory()
				get_viewport().set_input_as_handled()

func _on_exit_button_pressed():
	# 返回主场景
	get_tree().change_scene_to_file("res://scripts/main.tscn")

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
