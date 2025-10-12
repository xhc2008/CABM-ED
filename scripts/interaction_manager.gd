extends Node

# 配置文件路径
const CONFIG_PATH = "res://config/interaction_config.json"

# 配置数据
var config: Dictionary = {}

# 冷却时间记录
var action_cooldowns: Dictionary = {}

# 信号
signal interaction_success(action_id: String)
signal interaction_failure(action_id: String, message: String)
signal willingness_changed(new_value: int)

func _ready():
	_load_config()

# 加载配置
func _load_config():
	if not FileAccess.file_exists(CONFIG_PATH):
		print("错误: 交互配置文件不存在")
		return
	
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		print("错误: 无法打开交互配置文件")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("错误: 解析交互配置文件失败")
		return
	
	config = json.data
	print("交互配置已加载")

# 计算实际成功概率
func calculate_success_chance(action_id: String) -> float:
	if not config.has("actions") or not config.actions.has(action_id):
		print("警告: 未找到动作配置: ", action_id)
		return 0.0
	
	var action = config.actions[action_id]
	var base_willingness = action.base_willingness
	
	# 获取当前交互意愿
	if not has_node("/root/SaveManager"):
		return 0.0
	var save_mgr = get_node("/root/SaveManager")
	var current_willingness = save_mgr.get_reply_willingness()
	
	# 计算实际概率: (基础意愿 + 当前意愿 - 100)%
	var actual_chance = (base_willingness + current_willingness - 100.0) / 100.0
	
	# 应用修正因子
	actual_chance += _get_mood_modifier()
	actual_chance += _get_energy_modifier()
	
	# 限制在 0-1 范围内
	actual_chance = clamp(actual_chance, 0.0, 1.0)
	
	return actual_chance

# 获取心情修正
func _get_mood_modifier() -> float:
	if not config.has("willingness_modifiers") or not config.willingness_modifiers.has("mood"):
		return 0.0
	
	if not has_node("/root/SaveManager"):
		return 0.0
	var save_mgr = get_node("/root/SaveManager")
	var mood = save_mgr.get_mood()
	var mood_modifiers = config.willingness_modifiers.mood
	
	if mood_modifiers.has(mood):
		return mood_modifiers[mood] / 100.0
	
	return 0.0

# 获取精力修正
func _get_energy_modifier() -> float:
	if not config.has("willingness_modifiers") or not config.willingness_modifiers.has("energy"):
		return 0.0
	
	if not has_node("/root/SaveManager"):
		return 0.0
	var save_mgr = get_node("/root/SaveManager")
	var energy = save_mgr.get_energy()
	var energy_state = "normal"
	
	if energy >= 80:
		energy_state = "high"
	elif energy >= 40:
		energy_state = "normal"
	elif energy >= 20:
		energy_state = "low"
	else:
		energy_state = "exhausted"
	
	var energy_modifiers = config.willingness_modifiers.energy
	if energy_modifiers.has(energy_state):
		return energy_modifiers[energy_state] / 100.0
	
	return 0.0

# 检查是否在冷却中
func is_on_cooldown(action_id: String) -> bool:
	if not action_cooldowns.has(action_id):
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time < action_cooldowns[action_id]

# 设置冷却时间
func set_cooldown(action_id: String):
	var cooldown_duration = 10  # 默认10秒
	
	if config.has("failure_cooldown"):
		if action_id == "chat" and config.failure_cooldown.has("chat"):
			cooldown_duration = config.failure_cooldown.chat
		elif config.failure_cooldown.has("other"):
			cooldown_duration = config.failure_cooldown.other
	
	var current_time = Time.get_ticks_msec() / 1000.0
	action_cooldowns[action_id] = current_time + cooldown_duration

# 尝试执行交互
func try_interaction(action_id: String, is_active_trigger: bool = false) -> bool:
	# 如果是主动触发（角色触发），检查冷却
	if is_active_trigger and is_on_cooldown(action_id):
		var remaining = get_cooldown_remaining(action_id)
		print("动作在冷却中: ", action_id, " 剩余: ", remaining, "秒")
		return false
	
	# 计算成功概率
	var success_chance = calculate_success_chance(action_id)
	
	# 随机判定
	var roll = randf()
	var success = roll < success_chance
	
	print("动作: ", action_id, " 成功率: ", success_chance * 100, "% 掷骰: ", roll, " 结果: ", "成功" if success else "失败")
	
	if success:
		_handle_success(action_id, is_active_trigger)
		return true
	else:
		_handle_failure(action_id, is_active_trigger)
		return false

# 处理成功
func _handle_success(action_id: String, is_active_trigger: bool = false):
	if not config.has("actions") or not config.actions.has(action_id):
		return
	
	var action = config.actions[action_id]
	print("交互成功: ", action.name)
	
	# 如果是主动触发（角色触发），成功后也设置冷却
	if is_active_trigger:
		_set_active_cooldown(action_id)
	
	interaction_success.emit(action_id)

# 处理失败
func _handle_failure(action_id: String, is_active_trigger: bool = false):
	if not config.has("actions") or not config.actions.has(action_id):
		return
	
	var action = config.actions[action_id]
	
	# 设置冷却
	if not is_active_trigger:
		# 只有被动触发（用户触发）失败才设置冷却
		# 主动触发（角色触发）失败不设置冷却，让角色有机会再次尝试
		set_cooldown(action_id)
	
	# 处理失败反馈
	if action.has("on_failure"):
		var failure_config = action.on_failure
		
		if failure_config.type == "message":
			var message = failure_config.text
			# 替换占位符
			var character_name = _get_character_name()
			message = message.replace("{character_name}", character_name)
			
			print("交互失败: ", action.name, " - ", message)
			interaction_failure.emit(action_id, message)
		elif failure_config.type == "none":
			print("交互失败: ", action.name, " - 无事发生")
			interaction_failure.emit(action_id, "")

# 获取角色名称
func _get_character_name() -> String:
	# 从 app_config.json 读取角色名称
	var config_path = "res://config/app_config.json"
	if not FileAccess.file_exists(config_path):
		return "角色"
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return "角色"
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return "角色"
	
	var data = json.data
	if data.has("character_name"):
		return data.character_name
	
	return "角色"

# 获取动作配置
func get_action_config(action_id: String) -> Dictionary:
	if config.has("actions") and config.actions.has(action_id):
		return config.actions[action_id]
	return {}

# 修改交互意愿
func modify_willingness(amount: int):
	if not has_node("/root/SaveManager"):
		return
	var save_mgr = get_node("/root/SaveManager")
	var current = save_mgr.get_reply_willingness()
	var new_value = clamp(current + amount, 0, 100)
	save_mgr.set_reply_willingness(new_value)
	willingness_changed.emit(new_value)
	print("交互意愿变化: ", current, " -> ", new_value)

# 设置主动触发冷却时间
func _set_active_cooldown(action_id: String):
	var cooldown_duration = 30  # 默认30秒
	
	if config.has("active_cooldown"):
		if config.active_cooldown.has(action_id):
			cooldown_duration = config.active_cooldown[action_id]
		elif config.active_cooldown.has("default"):
			cooldown_duration = config.active_cooldown.default
	
	var current_time = Time.get_ticks_msec() / 1000.0
	action_cooldowns[action_id] = current_time + cooldown_duration
	print("设置主动触发冷却: ", action_id, " 时长: ", cooldown_duration, "秒")

# 获取剩余冷却时间
func get_cooldown_remaining(action_id: String) -> float:
	if not is_on_cooldown(action_id):
		return 0.0
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return action_cooldowns[action_id] - current_time
