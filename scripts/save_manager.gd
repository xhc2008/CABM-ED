extends Node

# 存档文件路径
const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "save_slot_"
const SAVE_FILE_EXTENSION = ".json"
const TEMPLATE_PATH = "res://config/save_data_template.json"

# 当前存档槽位
var current_slot: int = 1

# 当前存档数据
var save_data: Dictionary = {}

# 信号
signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(error: String)
signal load_failed(error: String)

func _ready():
	# 确保存档目录存在
	_ensure_save_directory()
	# 加载模板
	_load_template()

# 确保存档目录存在
func _ensure_save_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("创建存档目录: ", SAVE_DIR)

# 加载存档模板
func _load_template():
	if not FileAccess.file_exists(TEMPLATE_PATH):
		print("警告: 存档模板文件不存在")
		return
	
	var file = FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
	if not file:
		print("错误: 无法打开模板文件")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("错误: 解析模板文件失败")
		return
	
	save_data = json.data.duplicate(true)
	print("存档模板已加载")

# 获取存档文件路径
func _get_save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXTENSION

# 保存游戏
func save_game(slot: int = -1) -> bool:
	if slot == -1:
		slot = current_slot
	
	# 更新时间戳
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	if save_data.has("save_slots") and save_data.save_slots.has("slot_1"):
		save_data.save_slots.slot_1.timestamp.last_saved_at = timestamp
		save_data.save_slots.slot_1.timestamp.last_played_at = timestamp
	
	# 转换为JSON
	var json_string = JSON.stringify(save_data, "\t")
	
	# 写入文件
	var save_path = _get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		var error_msg = "无法创建存档文件: " + save_path
		print("错误: ", error_msg)
		save_failed.emit(error_msg)
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("游戏已保存到槽位 ", slot)
	save_completed.emit(slot)
	return true

# 加载游戏
func load_game(slot: int = -1) -> bool:
	if slot == -1:
		slot = current_slot
	
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		var error_msg = "存档文件不存在: " + save_path
		print("错误: ", error_msg)
		load_failed.emit(error_msg)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		var error_msg = "无法打开存档文件: " + save_path
		print("错误: ", error_msg)
		load_failed.emit(error_msg)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		var error_msg = "解析存档文件失败"
		print("错误: ", error_msg)
		load_failed.emit(error_msg)
		return false
	
	save_data = json.data
	current_slot = slot
	
	print("游戏已从槽位 ", slot, " 加载")
	load_completed.emit(slot)
	return true

# 检查存档是否存在
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

# 删除存档
func delete_save(slot: int) -> bool:
	var save_path = _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		print("存档不存在，无需删除")
		return false
	
	var dir = DirAccess.open(SAVE_DIR)
	var error = dir.remove(SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXTENSION)
	if error != OK:
		print("删除存档失败")
		return false
	
	print("存档已删除: 槽位 ", slot)
	return true

# 获取存档信息
func get_save_info(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {}
	
	var save_path = _get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return {}
	
	var data = json.data
	if data.has("save_slots") and data.save_slots.has("slot_1"):
		return data.save_slots.slot_1.timestamp
	
	return {}

# === 数据访问接口 ===

# 角色数据
func get_affection() -> int:
	return save_data.save_slots.slot_1.character_data.affection

func set_affection(value: int):
	save_data.save_slots.slot_1.character_data.affection = clamp(value, 0, 100)

func add_affection(amount: int):
	set_affection(get_affection() + amount)

func get_reply_willingness() -> int:
	return save_data.save_slots.slot_1.character_data.reply_willingness

func set_reply_willingness(value: int):
	save_data.save_slots.slot_1.character_data.reply_willingness = clamp(value, 0, 100)

func get_mood() -> String:
	return save_data.save_slots.slot_1.character_data.mood

func set_mood(mood: String):
	save_data.save_slots.slot_1.character_data.mood = mood

func get_energy() -> int:
	return save_data.save_slots.slot_1.character_data.energy

func set_energy(value: int):
	save_data.save_slots.slot_1.character_data.energy = clamp(value, 0, 100)

func get_trust_level() -> int:
	return save_data.save_slots.slot_1.character_data.trust_level

func set_trust_level(value: int):
	save_data.save_slots.slot_1.character_data.trust_level = clamp(value, 0, 100)

# 用户数据
func get_total_chat_count() -> int:
	return save_data.save_slots.slot_1.user_data.total_chat_count

func increment_chat_count():
	save_data.save_slots.slot_1.user_data.total_chat_count += 1

func get_total_play_time() -> int:
	return save_data.save_slots.slot_1.user_data.total_play_time

func add_play_time(seconds: int):
	save_data.save_slots.slot_1.user_data.total_play_time += seconds

# 游戏进度
func is_scene_unlocked(scene_id: String) -> bool:
	return scene_id in save_data.save_slots.slot_1.game_progress.unlocked_scenes

func unlock_scene(scene_id: String):
	if not is_scene_unlocked(scene_id):
		save_data.save_slots.slot_1.game_progress.unlocked_scenes.append(scene_id)

func get_current_scene() -> String:
	return save_data.save_slots.slot_1.game_progress.current_scene

func set_current_scene(scene_id: String):
	save_data.save_slots.slot_1.game_progress.current_scene = scene_id

# 统计数据
func increment_messages_sent():
	save_data.save_slots.slot_1.statistics.total_messages_sent += 1

func increment_messages_received():
	save_data.save_slots.slot_1.statistics.total_messages_received += 1
