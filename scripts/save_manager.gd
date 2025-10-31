extends Node

# 保存管理器 - 自动加载单例
# 负责游戏数据的保存和加载

const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "save_slot_"
const SAVE_FILE_EXT = ".json"

var current_slot: int = 1
var save_data: Dictionary = {}
var auto_save_timer: Timer
var is_auto_save_enabled: bool = true
var auto_save_interval: float = 300.0 # 默认5分钟
var enable_instant_save: bool = true # 启用即时保存
var is_initial_setup_completed: bool = false # 初始设置是否完成

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, error: String)
signal load_failed(slot: int, error: String)
signal affection_changed(new_value: int)
signal willingness_changed(new_value: int)
signal mood_changed(new_value: String)
signal energy_changed(new_value: int)
signal character_scene_changed(new_scene: String)

func _ready():
	# 确保保存目录存在
	_ensure_save_directory()
	
	# 加载保存模板
	_load_template()
	
	# 设置自动保存定时器
	_setup_auto_save_timer()
	
	# 检查是否存在存档
	var has_save = _has_save_file()
	
	# 如果存在存档，则加载并标记初始设置已完成
	if has_save:
		load_game(current_slot)
		is_initial_setup_completed = true
	else:
		# 首次启动，不加载存档，等待初始设置完成
		print("首次启动，等待初始设置完成")
		is_initial_setup_completed = false

func _has_save_file() -> bool:
	"""检查存档文件是否存在"""
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(current_slot) + SAVE_FILE_EXT
	return FileAccess.file_exists(save_path)

func _notification(what):
	"""捕获窗口关闭事件"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 只有在初始设置完成后才保存
		if is_initial_setup_completed:
			print("检测到窗口关闭，正在保存游戏...")
			save_game(current_slot)
		# 等待保存完成后再退出
		get_tree().quit()

func _ensure_save_directory():
	"""确保保存目录存在"""
	var dir = DirAccess.open("user://")
	if dir == null:
		print("错误: 无法访问 user:// 目录")
		return
	
	print("user:// 路径: ", OS.get_user_data_dir())
	
	if not dir.dir_exists("saves"):
		var err = dir.make_dir("saves")
		if err != OK:
			print("错误: 无法创建 saves 目录，错误码: ", err)
		else:
			print("成功创建 saves 目录")

func _load_template():
	"""从模板加载默认数据结构"""
	var template_path = "res://config/save_data_template.json"
	if not FileAccess.file_exists(template_path):
		print("警告: 保存模板不存在")
		return
	
	var file = FileAccess.open(template_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var template = json.data
		# 提取slot_1作为默认数据结构
		if template.has("save_slots") and template.save_slots.has("slot_1"):
			save_data = template.save_slots.slot_1.duplicate(true)
		
		# 加载设置
		if template.has("settings"):
			var settings = template.settings
			is_auto_save_enabled = settings.get("auto_save", true)
			auto_save_interval = settings.get("auto_save_interval", 300.0)
			enable_instant_save = settings.get("instant_save", true)
	
	# 延迟加载背包数据
	call_deferred("_load_inventory_data")

func _setup_auto_save_timer():
	"""设置自动保存定时器"""
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.one_shot = false
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(auto_save_timer)
	
	if is_auto_save_enabled:
		auto_save_timer.start()

func _on_auto_save_timeout():
	"""自动保存触发"""
	# 只有在初始设置完成后才允许自动保存
	if is_initial_setup_completed:
		save_game(current_slot)
		print("自动保存完成")

func save_game(slot: int = 1, update_play_time: bool = true) -> bool:
	"""保存游戏数据
	
	参数:
		slot: 存档槽位
		update_play_time: 是否更新最后游玩时间（默认true）
	"""
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	# 保存背包数据
	if has_node("/root/InventoryManager"):
		save_data.inventory_data = get_node("/root/InventoryManager").get_storage_data()
	
	# 更新时间戳
	var now = Time.get_datetime_string_from_system()
	var now_unix = Time.get_unix_time_from_system()
	save_data.timestamp.last_saved_at = now
	if update_play_time:
		save_data.timestamp.last_played_at = now
		save_data.timestamp.last_played_at_unix = now_unix
	
	# 转换为JSON
	var json_string = JSON.stringify(save_data, "\t")
	
	# 写入文件
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var err = FileAccess.get_open_error()
		var error = "无法创建保存文件: " + save_path + " (错误码: " + str(err) + ")"
		print(error)
		print("完整路径: ", ProjectSettings.globalize_path(save_path))
		save_failed.emit(slot, error)
		return false
	
	file.store_string(json_string)
	file.close()
	
	# 验证文件是否真的保存成功
	if FileAccess.file_exists(save_path):
		print("游戏已保存到槽位 ", slot, " 路径: ", ProjectSettings.globalize_path(save_path))
		save_completed.emit(slot)
		return true
	else:
		var error = "文件保存后验证失败: " + save_path
		print(error)
		save_failed.emit(slot, error)
		return false

func load_game(slot: int = 1) -> bool:
	"""加载游戏数据"""
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	print("尝试加载存档: ", ProjectSettings.globalize_path(save_path))
	
	if not FileAccess.file_exists(save_path):
		print("存档不存在，使用默认数据: ", save_path)
		# 初始化时间戳
		var now = Time.get_datetime_string_from_system()
		var now_unix = Time.get_unix_time_from_system()
		save_data.timestamp.created_at = now
		save_data.timestamp.last_saved_at = now
		save_data.timestamp.last_played_at = now
		save_data.timestamp.last_played_at_unix = now_unix
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		var error = "无法读取保存文件: " + save_path + " (错误码: " + str(err) + ")"
		print(error)
		load_failed.emit(slot, error)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		var error = "保存文件格式错误: " + json.get_error_message()
		print(error)
		load_failed.emit(slot, error)
		return false
	
	# 深度合并存档数据和模板数据，确保存档中的值优先
	# 这样可以防止重新安装时重置已有数据
	var loaded_data = json.data
	save_data = _deep_merge(save_data, loaded_data)
	current_slot = slot
	
	# 先检查离线时间变化（使用存档中的旧时间）
	# 延迟调用以确保 OfflineTimeManager 已经加载
	call_deferred("_check_offline_time")
	
	print("游戏已从槽位 ", slot, " 加载")
	load_completed.emit(slot)
	return true

# === 角色数据访问方法 ===

func get_character_scene() -> String:
	"""获取角色当前所在场景"""
	return save_data.character_data.get("current_scene", "")

func set_character_scene(scene_id: String):
	"""设置角色当前所在场景"""
	save_data.character_data.current_scene = scene_id
	character_scene_changed.emit(scene_id)
	_auto_save()

func get_current_weather() -> String:
	"""获取当前天气"""
	return save_data.character_data.get("current_weather", "sunny")

func set_current_weather(weather_id: String):
	"""设置当前天气"""
	save_data.character_data.current_weather = weather_id
	_auto_save()

func get_current_time() -> String:
	"""获取当前时间段"""
	return save_data.character_data.get("current_time", "day")

func set_current_time(time_id: String):
	"""设置当前时间段"""
	save_data.character_data.current_time = time_id
	_auto_save()

func get_character_preset() -> Dictionary:
	"""获取角色当前预设动作"""
	return save_data.character_data.get("current_preset", {})

func set_character_preset(preset: Dictionary):
	"""设置角色当前预设动作"""
	save_data.character_data.current_preset = preset.duplicate(true)
	_auto_save()

func get_costume_id() -> String:
	"""获取当前服装ID"""
	return save_data.character_data.get("costume_id", "default")

func set_costume_id(costume_id: String):
	"""设置当前服装ID"""
	save_data.character_data.costume_id = costume_id
	_auto_save()

func get_affection() -> int:
	return save_data.character_data.get("affection", 0)

func set_affection(value: int):
	save_data.character_data.affection = value
	affection_changed.emit(value)
	_auto_save()

func get_reply_willingness() -> int:
	return save_data.character_data.get("reply_willingness", 100)

func set_reply_willingness(value: int):
	save_data.character_data.reply_willingness = clamp(value, 0, 100)
	willingness_changed.emit(value)
	_auto_save()

func get_mood() -> String:
	return save_data.character_data.get("mood", "平静")

func set_mood(value: String):
	save_data.character_data.mood = value
	mood_changed.emit(value)
	_auto_save()

func get_energy() -> int:
	return save_data.character_data.get("energy", 100)

func set_energy(value: int):
	save_data.character_data.energy = clamp(value, 0, 100)
	energy_changed.emit(value)
	_auto_save()

func get_trust_level() -> int:
	return save_data.character_data.get("trust_level", 0)

func set_trust_level(value: int):
	save_data.character_data.trust_level = value
	_auto_save()

# === 统计数据方法 ===

func increment_messages_sent():
	save_data.statistics.total_messages_sent += 1
	_auto_save()

func increment_messages_received():
	save_data.statistics.total_messages_received += 1
	_auto_save()

func update_favorite_scene(scene_id: String):
	save_data.statistics.favorite_scene = scene_id
	_auto_save()

func update_most_used_action(action: String):
	save_data.statistics.most_used_action = action
	_auto_save()

# === 用户数据方法 ===

func get_user_name() -> String:
	return save_data.user_data.get("user_name", "未设置")

func set_user_name(user_name: String):
	save_data.user_data.user_name = user_name
	_auto_save()

func get_user_address() -> String:
	return save_data.user_data.get("user_address", "你")

func set_user_address(user_address: String):
	save_data.user_data.user_address = user_address
	_auto_save()

func increment_chat_count():
	save_data.user_data.total_chat_count += 1
	_auto_save()

func add_play_time(seconds: float):
	save_data.user_data.total_play_time += seconds
	_auto_save()

# === 内部方法 ===

func _check_offline_time():
	"""检查离线时间（延迟调用）"""
	if has_node("/root/OfflineTimeManager"):
		get_node("/root/OfflineTimeManager").check_and_apply_offline_changes()
		
		# 检查完离线时间后，更新最后游玩时间并保存
		var now = Time.get_unix_time_from_system()
		save_data.timestamp.last_played_at = Time.get_datetime_string_from_system()
		save_data.timestamp.last_played_at_unix = now
		# 保存时不再更新 last_played_at（因为我们刚刚手动更新了）
		save_game(current_slot, false)

func _auto_save():
	"""数据变更时自动保存"""
	# 只有在初始设置完成后才允许自动保存
	if enable_instant_save and is_initial_setup_completed:
		save_game(current_slot)

func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	"""深度合并两个字典，overlay的值会覆盖base的值
	
	参数:
		base: 基础字典（模板数据）
		overlay: 覆盖字典（存档数据）
	返回:
		合并后的字典
	"""
	var result = base.duplicate(true)
	
	for key in overlay:
		if overlay[key] is Dictionary and result.has(key) and result[key] is Dictionary:
			# 递归合并嵌套字典
			result[key] = _deep_merge(result[key], overlay[key])
		else:
			# 直接覆盖值（存档数据优先）
			result[key] = overlay[key]
	
	return result

# === 背包数据方法 ===

func _load_inventory_data():
	"""加载背包数据到InventoryManager"""
	print("[SaveManager] 开始加载背包数据...")
	
	if not has_node("/root/InventoryManager"):
		print("[SaveManager] InventoryManager 未找到，延迟重试...")
		await get_tree().create_timer(0.1).timeout
		if not has_node("/root/InventoryManager"):
			print("[SaveManager] 错误: InventoryManager 仍未加载")
			return
	
	var inventory_mgr = get_node("/root/InventoryManager")
	print("[SaveManager] InventoryManager 已找到")
	
	# 检查是否需要初始化仓库物品
	# 1. inventory_data 字段不存在
	# 2. inventory_data 存在但仓库为空
	var needs_init = false
	
	if not save_data.has("inventory_data"):
		needs_init = true
		print("[SaveManager] inventory_data 字段不存在，需要初始化")
	else:
		# 检查仓库是否为空
		var inv_data = save_data.inventory_data
		var warehouse_empty = true
		
		if inv_data.has("warehouse") and inv_data.warehouse is Array:
			for item in inv_data.warehouse:
				if item != null:
					warehouse_empty = false
					break
		
		if warehouse_empty:
			needs_init = true
			print("[SaveManager] 仓库为空，需要初始化")
		else:
			print("[SaveManager] 仓库已有物品，跳过初始化")
	
	print("[SaveManager] 是否需要初始化: ", needs_init)
	
	if save_data.has("inventory_data"):
		print("[SaveManager] 加载现有背包数据...")
		inventory_mgr.load_storage_data(save_data.inventory_data)
	
	# 首次进入或旧版本更新时，添加初始物品到仓库
	if needs_init:
		print("[SaveManager] 开始添加初始物品...")
		_add_initial_items_to_warehouse()

func save_inventory_data():
	"""保存背包数据"""
	if has_node("/root/InventoryManager"):
		save_data.inventory_data = get_node("/root/InventoryManager").get_storage_data()
		_auto_save()

func get_inventory_data() -> Dictionary:
	"""获取背包数据"""
	return save_data.get("inventory_data", {"inventory": [], "warehouse": []})

func _add_initial_items_to_warehouse():
	"""添加初始物品到仓库"""
	print("[SaveManager] _add_initial_items_to_warehouse 被调用")
	
	if not has_node("/root/InventoryManager"):
		print("[SaveManager] 错误: InventoryManager 未找到")
		return
	
	var inventory_mgr = get_node("/root/InventoryManager")
	print("[SaveManager] InventoryManager 已获取")
	
	# 定义初始物品列表 [物品ID, 数量]
	var initial_items = [
		["note", 1],
		["CMR-951", 1],
		["5.8mm_ammo", 64],
		["VSS-SF", 1],
		["9mm_ammo", 64],
		["UMP45", 1],
		[".45_ammo", 64],
		
	]
	
	print("[SaveManager] 准备添加 ", initial_items.size(), " 种初始物品")
	
	# 添加物品到仓库
	for item_data in initial_items:
		var item_id = item_data[0]
		var count = item_data[1]
		print("[SaveManager] 尝试添加: ", item_id, " x", count)
		var success = inventory_mgr.add_item_to_warehouse(item_id, count)
		if success:
			print("[SaveManager] ✓ 已添加初始物品到仓库: ", item_id, " x", count)
		else:
			print("[SaveManager] ✗ 警告: 无法添加初始物品: ", item_id)
	
	# 保存仓库数据
	print("[SaveManager] 保存仓库数据...")
	save_inventory_data()
	print("[SaveManager] ✓ 初始物品已添加到仓库并保存")
