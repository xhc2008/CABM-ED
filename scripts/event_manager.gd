extends Node

# 事件管理器 - 统一管理所有交互事件
# 每个事件都是一个独立的函数，包含完整的逻辑

# 事件结果结构
class EventResult:
	var success: bool = false
	var message: String = ""
	var affection_change: int = 0
	var willingness_change: int = 0
	var mood_change: String = ""
	var energy_change: int = 0
	
	func _init(p_success: bool = false, p_message: String = ""):
		success = p_success
		message = p_message

# 冷却时间管理
var cooldowns: Dictionary = {}

# 空闲计时器
var idle_timer: Timer
var idle_timeout: float = 300.0  # 5分钟

# 信号
signal event_completed(event_name: String, result: EventResult)

# 辅助函数引用
var helpers

func _ready():
	# 获取辅助函数节点
	if has_node("/root/EventHelpers"):
		helpers = get_node("/root/EventHelpers")
	
	_setup_idle_timer()

func _setup_idle_timer():
	"""设置空闲计时器"""
	idle_timer = Timer.new()
	idle_timer.wait_time = idle_timeout
	idle_timer.one_shot = false
	idle_timer.timeout.connect(on_idle_timeout)
	add_child(idle_timer)
	idle_timer.start()

func reset_idle_timer():
	"""重置空闲计时器"""
	if idle_timer:
		idle_timer.start()

# ========================================
# 事件函数
# ========================================

func on_character_clicked() -> EventResult:
	"""事件：角色被点击"""
	reset_idle_timer()
	
	# 检查冷却
	if is_on_cooldown("character_clicked"):
		return EventResult.new(false, "冷却中")
	
	# 计算成功率
	var base_willingness = 150
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		# result.affection_change = randi_range(1, 3)
		# result.willingness_change = randi_range(-5, 10)
		result.message = helpers.get_character_name() + "注意到了你"
		_set_cooldown("character_clicked", 5.0)
	else:
		result.message = helpers.get_character_name() + "似乎没注意到你"
		_set_cooldown("character_clicked", 10.0)
	
	_apply_result(result)
	event_completed.emit("character_clicked", result)
	return result

func on_user_start_chat() -> EventResult:
	"""事件：用户发起聊天"""
	reset_idle_timer()
	
	if is_on_cooldown("user_start_chat"):
		return EventResult.new(false, "冷却中")
	
	var base_willingness = 120
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		result.affection_change = randi_range(-1, 5)
		result.willingness_change = randi_range(-5, 5)
		result.message = "开始聊天"
		_set_cooldown("user_start_chat", 3.0)
	else:
		result.willingness_change = randi_range(-5, -2)
		result.message = helpers.get_character_name() + "不想理你"
		_set_cooldown("user_start_chat", 15.0)
	
	_apply_result(result)
	event_completed.emit("user_start_chat", result)
	return result

func on_enter_scene() -> EventResult:
	"""事件：进入角色所在场景"""
	reset_idle_timer()
	
	if is_on_cooldown("enter_scene"):
		return EventResult.new(false, "冷却中")
	
	var base_willingness = 50
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		result.affection_change = randi_range(0, 2)
		result.willingness_change = randi_range(5, 15)
		result.message = helpers.get_character_name() + "注意到你进来了"
		_set_cooldown("enter_scene", 10.0)
	else:
		result.message = ""
		# 失败不设置冷却
	
	_apply_result(result)
	event_completed.emit("enter_scene", result)
	return result

func on_leave_scene() -> EventResult:
	"""事件：离开角色所在场景"""
	reset_idle_timer()
	
	if is_on_cooldown("leave_scene"):
		return EventResult.new(false, "冷却中")
	
	var base_willingness = 30
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		result.willingness_change = randi_range(-10, -5)
		result.message = helpers.get_character_name() + "看着你离开"
		_set_cooldown("leave_scene", 20.0)
	else:
		result.message = ""
		# 失败不设置冷却
	
	_apply_result(result)
	event_completed.emit("leave_scene", result)
	return result

func on_chat_turn_end() -> EventResult:
	"""事件：一轮对话结束（AI回复判断点）"""
	reset_idle_timer()
	
	# 这个事件不检查冷却，每轮都可以触发
	
	var base_willingness = 150
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		# AI决定回复
		# result.affection_change = randi_range(0, 2)
		# result.willingness_change = randi_range(-5, 5)
		result.message = "决定回复"
	else:
		# AI决定不回复
		result.willingness_change = randi_range(-15, -5)
		result.message = ""
	
	_apply_result(result)
	event_completed.emit("chat_turn_end", result)
	return result

func on_chat_session_end(turn_count: int = 0) -> EventResult:
	"""事件：完整对话结束（点击"结束聊天"）"""
	reset_idle_timer()
	
	if is_on_cooldown("chat_session_end"):
		return EventResult.new(false, "冷却中")
	
	# 对话结束总是成功，根据对话轮数调整数值
	var result = EventResult.new(true, "对话结束")
	
	if turn_count > 10:
		# 长对话，大幅提升好感
		result.affection_change = randi_range(0, 10)
		result.willingness_change = randi_range(-20, 0)
	elif turn_count > 5:
		# 中等对话
		result.affection_change = randi_range(0, 6)
		result.willingness_change = randi_range(-10, 10)
	else:
		# 短对话
		result.affection_change = randi_range(0, 3)
		result.willingness_change = randi_range(-5, 5)
	
	_set_cooldown("chat_session_end", 0.0)
	
	_apply_result(result)
	event_completed.emit("chat_session_end", result)
	return result

func on_idle_timeout() -> EventResult:
	"""事件：空闲超时（长时间无操作）"""
	# 这个事件不重置空闲计时器
	
	# 长时间无操作，降低交互意愿
	var result = EventResult.new(true, "长时间无互动")
	result.willingness_change = randi_range(0, 20)
	
	_apply_result(result)
	event_completed.emit("idle_timeout", result)
	return result

# ========================================
# 冷却管理
# ========================================

func is_on_cooldown(event_name: String) -> bool:
	"""检查事件是否在冷却中"""
	if not cooldowns.has(event_name):
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time < cooldowns[event_name]

func get_cooldown_remaining(event_name: String) -> float:
	"""获取剩余冷却时间"""
	if not is_on_cooldown(event_name):
		return 0.0
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return cooldowns[event_name] - current_time

func _set_cooldown(event_name: String, duration: float):
	"""设置冷却时间"""
	var current_time = Time.get_ticks_msec() / 1000.0
	cooldowns[event_name] = current_time + duration
	print("事件冷却: %s, 时长: %.1f秒" % [event_name, duration])

func clear_cooldown(event_name: String):
	"""清除冷却（调试用）"""
	if cooldowns.has(event_name):
		cooldowns.erase(event_name)

func clear_all_cooldowns():
	"""清除所有冷却（调试用）"""
	cooldowns.clear()

# ========================================
# 内部方法
# ========================================

func _apply_result(result: EventResult):
	"""应用事件结果的数值变化"""
	if result.affection_change != 0:
		helpers.modify_affection(result.affection_change)
	
	if result.willingness_change != 0:
		helpers.modify_willingness(result.willingness_change)
	
	if not result.mood_change.is_empty():
		helpers.modify_mood(result.mood_change)
	
	if result.energy_change != 0:
		helpers.modify_energy(result.energy_change)
