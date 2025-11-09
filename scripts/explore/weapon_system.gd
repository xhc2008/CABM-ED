extends Node
class_name WeaponSystem

# 武器系统 - 处理射击、换弹、弹药消耗

signal weapon_changed(weapon_data: Dictionary)
signal ammo_changed(current_ammo: int, max_ammo: int)

var player_inventory: PlayerInventory
var current_weapon: Dictionary = {}  # {item_id: String, count: int, ammo: int}
var weapon_config: Dictionary = {}

# 射击相关
var can_shoot: bool = true
var is_reloading: bool = false
var reload_time: float = 0.0
var reload_duration: float = 3.8  # 默认换弹时间2秒
var last_shot_time: float = 0.0
var fire_rate: float = 0.1  # 默认射速
var shoot_cooldown_timer: float = 0.0

# 子弹场景
const BULLET_SCENE = preload("res://scenes/bullet.tscn")

# 音效系统
var shoot_sounds: Array = []
var reload_sound: AudioStreamPlayer2D
var empty_sound: AudioStreamPlayer2D
var current_weapon_id: String = ""

# 默认音效路径
const DEFAULT_SOUND_PATH = "res://assets/audio/explore/"

# 射击音效池大小（根据武器射速调整）
const SHOOT_SOUND_POOL_SIZE: int = 16

func _ready():
	# 创建射击音效池
	for i in range(SHOOT_SOUND_POOL_SIZE):
		var sound_player = AudioStreamPlayer2D.new()
		sound_player.bus = "SFX"
		add_child(sound_player)
		shoot_sounds.append(sound_player)
	
	# 创建换弹音效播放器
	reload_sound = AudioStreamPlayer2D.new()
	reload_sound.bus = "SFX"
	add_child(reload_sound)
	
	# 创建空仓音效播放器
	empty_sound = AudioStreamPlayer2D.new()
	empty_sound.bus = "SFX"
	add_child(empty_sound)

func setup(inventory: PlayerInventory):
	"""初始化武器系统"""
	player_inventory = inventory
	if player_inventory and player_inventory.container:
		player_inventory.container.storage_changed.connect(_on_inventory_changed)
		_update_current_weapon()

func _process(delta):
	# 更新换弹计时
	if is_reloading:
		reload_time += delta
		if reload_time >= reload_duration:
			_finish_reload()
	
	# 更新射击冷却
	if shoot_cooldown_timer > 0.0:
		shoot_cooldown_timer -= delta

func _on_inventory_changed():
	"""背包变化时更新武器"""
	_update_current_weapon()

func _update_current_weapon():
	"""更新当前武器"""
	if not player_inventory or not player_inventory.container:
		return
	
	var weapon_slot = player_inventory.container.weapon_slot
	if weapon_slot.is_empty():
		current_weapon = {}
		weapon_config = {}
		current_weapon_id = ""
		weapon_changed.emit({})
		return
	
	current_weapon = weapon_slot.duplicate()
	var item_id = current_weapon.get("item_id", "")
	
	# 只在武器真正改变时更新音效
	if item_id != current_weapon_id:
		current_weapon_id = item_id
		weapon_config = player_inventory.get_item_config(item_id)
		
		# 更新武器属性
		if not weapon_config.is_empty():
			fire_rate = weapon_config.get("fire_rate", 0.1)
			reload_duration = weapon_config.get("reload_time", 0.1)  # 可以根据武器类型调整
			
			# 更新武器音效
			_update_weapon_sounds(item_id)
	else:
		weapon_config = player_inventory.get_item_config(item_id)
	
	weapon_changed.emit(current_weapon.duplicate())
	_update_ammo_display()

func _update_weapon_sounds(weapon_id: String):
	"""根据武器ID更新音效"""
	if weapon_id.is_empty():
		return
	
	print("更新武器音效: " + weapon_id)
	
	# 加载射击音效
	var shoot_sound_path = DEFAULT_SOUND_PATH + weapon_id + "_shot.mp3"
	var shoot_stream = null
	if FileAccess.file_exists(shoot_sound_path.replace("res://", "")):
		shoot_stream = load(shoot_sound_path)
		print("成功加载射击音效: " + shoot_sound_path)
	else:
		# 如果找不到特定武器的音效，使用默认音效
		shoot_stream = load(DEFAULT_SOUND_PATH + "shot.mp3")
		print("使用默认射击音效")
	
	# 为所有射击音效播放器设置相同的音效
	for sound_player in shoot_sounds:
		sound_player.stream = shoot_stream
	
	# 加载换弹音效
	var reload_sound_path = DEFAULT_SOUND_PATH + weapon_id + "_reload.mp3"
	if FileAccess.file_exists(reload_sound_path.replace("res://", "")):
		reload_sound.stream = load(reload_sound_path)
		print("成功加载换弹音效: " + reload_sound_path)
	else:
		# 如果找不到特定武器的音效，使用默认音效
		reload_sound.stream = load(DEFAULT_SOUND_PATH + "reload.mp3")
		print("使用默认换弹音效")
	
	# 加载空仓音效
	var empty_sound_path = DEFAULT_SOUND_PATH + weapon_id + "_empty.mp3"
	if FileAccess.file_exists(empty_sound_path.replace("res://", "")):
		empty_sound.stream = load(empty_sound_path)
		print("成功加载空仓音效: " + empty_sound_path)
	else:
		# 如果找不到特定武器的音效，使用默认音效
		empty_sound.stream = load(DEFAULT_SOUND_PATH + "empty.mp3")
		print("使用默认空仓音效")

func _update_ammo_display():
	"""更新弹药显示"""
	if weapon_config.is_empty() or weapon_config.get("subtype") != "远程":
		return
	
	var current_ammo = current_weapon.get("ammo", 0)
	var max_ammo = weapon_config.get("magazine_size", 30)
	ammo_changed.emit(current_ammo, max_ammo)

func can_shoot_now() -> bool:
	"""检查是否可以射击"""
	if is_reloading:
		return false
	
	if current_weapon.is_empty():
		return false
	
	if weapon_config.is_empty():
		return false
	
	# 检查射速
	if shoot_cooldown_timer > 0.0:
		return false
	
	# 远程武器需要检查弹药
	if weapon_config.get("subtype") == "远程":
		var ammo = current_weapon.get("ammo", 0)
		if ammo <= 0:
			return false
	
	return true

func shoot(shoot_position: Vector2, direction: Vector2, player_rotation: float) -> bool:
	"""射击"""
	if not can_shoot_now():
		if current_weapon.is_empty() or weapon_config.is_empty():
			return false
		
		# 空仓音效
		if weapon_config.get("subtype") == "远程":
			var current_ammo = current_weapon.get("ammo", 0)
			if current_ammo <= 0 and not is_reloading:
				empty_sound.play()
		return false
	
	# 只有远程武器可以射击
	if weapon_config.get("subtype") != "远程":
		return false
	
	# 消耗弹药
	var ammo = current_weapon.get("ammo", 0)
	if ammo <= 0:
		empty_sound.play()
		return false
	
	current_weapon["ammo"] = ammo - 1
	
	# 更新背包中的武器数据
	if player_inventory and player_inventory.container:
		player_inventory.container.weapon_slot = current_weapon.duplicate()
		player_inventory.container.storage_changed.emit()
	
	# 更新射速计时
	shoot_cooldown_timer = fire_rate
	
	# 使用音效池播放射击音效
	_play_shoot_sound()
	
	# 创建子弹
	var bullet = BULLET_SCENE.instantiate()
	if bullet:
		get_tree().current_scene.add_child(bullet)
		bullet.setup(shoot_position, direction, player_rotation, weapon_config)
	
	_update_ammo_display()
	return true

func _play_shoot_sound():
	"""使用音效池播放射击音效"""
	if shoot_sounds.is_empty():
		return
	
	# 查找第一个不在播放的音效播放器
	var available_player = null
	for sound_player in shoot_sounds:
		if not sound_player.playing:
			available_player = sound_player
			break
	
	# 如果所有播放器都在播放，使用第一个（允许重叠）
	if not available_player:
		available_player = shoot_sounds[0]
	
	# 播放音效
	available_player.play()
	
	# 调试信息
	# var playing_count = 0
	# for sound_player in shoot_sounds:
	# 	if sound_player.playing:
	# 		playing_count += 1
	# print("播放射击音效，播放器状态: " + str(playing_count) + "/" + str(shoot_sounds.size()) + " 正在播放")

func start_reload() -> bool:
	"""开始换弹"""
	if is_reloading:
		return false
	
	if current_weapon.is_empty():
		return false
	
	if weapon_config.is_empty():
		return false
	
	# 只有远程武器需要换弹
	if weapon_config.get("subtype") != "远程":
		return false
	
	var magazine_size = weapon_config.get("magazine_size", 30)
	var current_ammo = current_weapon.get("ammo", 0)
	
	# 如果弹匣已满，不需要换弹
	if current_ammo >= magazine_size:
		return false
	
	# 检查是否有对应弹药
	var ammo_type = weapon_config.get("ammo_type", "")
	var ammo_item_id = _find_ammo_item_id(ammo_type)
	if ammo_item_id.is_empty():
		print("没有找到对应的弹药: " + ammo_type)
		return false
	
	# 检查背包中是否有足够的弹药
	if player_inventory and player_inventory.container:
		var available_ammo = player_inventory.container.count_item(ammo_item_id)
		if available_ammo <= 0:
			print("背包中没有弹药")
			return false
	
	# 开始换弹
	is_reloading = true
	reload_time = 0.0
	
	# 播放换弹音效
	reload_sound.play()
	
	return true

func _finish_reload():
	"""完成换弹"""
	is_reloading = false
	reload_time = 0.0
	
	if current_weapon.is_empty() or weapon_config.is_empty():
		return
	
	var magazine_size = weapon_config.get("magazine_size", 30)
	var current_ammo = current_weapon.get("ammo", 0)
	var needed_ammo = magazine_size - current_ammo
	
	if needed_ammo <= 0:
		return
	
	# 查找并消耗弹药
	var ammo_type = weapon_config.get("ammo_type", "")
	var ammo_item_id = _find_ammo_item_id(ammo_type)
	if ammo_item_id.is_empty():
		return
	
	# 从背包消耗弹药
	if player_inventory and player_inventory.container:
		var ammo_consumed = player_inventory.container.remove_item_by_id(ammo_item_id, needed_ammo)
		if ammo_consumed > 0:
			current_weapon["ammo"] = current_ammo + ammo_consumed
			player_inventory.container.weapon_slot = current_weapon.duplicate()
			player_inventory.container.storage_changed.emit()
			_update_ammo_display()
		else:
			print("换弹失败：无法消耗弹药")

func _find_ammo_item_id(ammo_type: String) -> String:
	"""根据弹药类型查找弹药物品ID"""
	if not player_inventory or not player_inventory.container:
		return ""
	
	var items_config = player_inventory.items_config
	for item_id in items_config:
		var item_config = items_config[item_id]
		if item_config.get("type") == "弹药" and item_config.get("caliber") == ammo_type:
			return item_id
	
	return ""

func get_current_weapon() -> Dictionary:
	"""获取当前武器数据"""
	return current_weapon.duplicate()

func get_weapon_config() -> Dictionary:
	"""获取当前武器配置"""
	return weapon_config.duplicate()

func is_weapon_equipped() -> bool:
	"""检查是否装备了武器"""
	return not current_weapon.is_empty()

func get_reload_progress() -> float:
	"""获取换弹进度（0.0-1.0）"""
	if not is_reloading:
		return 1.0
	return reload_time / reload_duration
