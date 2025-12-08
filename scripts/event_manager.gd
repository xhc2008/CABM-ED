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
var idle_timeout: float = 120.0 # 2分钟

# 信号
signal event_completed(event_name: String, result: EventResult)

# 辅助函数引用
var helpers

func _ready():
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.is_resources_ready():
		return
	print("EventManager _ready")
	# 获取辅助函数节点
	if has_node("/root/EventHelpers"):
		helpers = get_node("/root/EventHelpers")
	
	_setup_idle_timer()

func _setup_idle_timer():
	"""设置空闲计时器"""
	idle_timer = Timer.new()
	idle_timer.wait_time = _get_random_idle_timeout()
	idle_timer.one_shot = false
	idle_timer.timeout.connect(on_idle_timeout)
	add_child(idle_timer)
	idle_timer.start()

func _get_random_idle_timeout() -> float:
	"""获取随机的空闲超时时间（120-180秒）"""
	return randf_range(120.0, 180.0)

func reset_idle_timer():
	"""重置空闲计时器"""
	if idle_timer:
		idle_timer.wait_time = _get_random_idle_timeout()
		idle_timer.start()

func pause_timers():
	"""暂停所有计时器"""
	if idle_timer:
		idle_timer.paused = true

func resume_timers():
	"""恢复所有计时器"""
	if idle_timer:
		idle_timer.paused = false

# ========================================
# 事件函数
# ========================================

func on_character_clicked() -> EventResult:
	"""事件：角色被点击"""
	reset_idle_timer()
	
	# 检查冷却
	if is_on_cooldown("character_clicked"):
		return EventResult.new(false, helpers.get_character_name() + "似乎没注意到你")
	
	# 计算成功率
	var base_willingness = 200
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	result.message = "passive" # chat_mode
	
	if success:
		# result.affection_change = randi_range(1, 3)
		# result.willingness_change = randi_range(-5, 10)
		# _set_cooldown("character_clicked", 5.0)
		pass
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
		return EventResult.new(false, helpers.get_character_name() + "不想理你")
	
	var base_willingness = 150
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	result.message = "passive" # chat_mode
	
	if success:
		# result.affection_change = randi_range(-1, 5)
		# result.willingness_change = randi_range(-5, 5)
		# _set_cooldown("user_start_chat", 3.0)
		pass
	else:
		result.message = helpers.get_character_name() + "不想理你"
		_set_cooldown("user_start_chat", 15.0)
	
	_apply_result(result)
	event_completed.emit("user_start_chat", result)
	return result

func on_enter_scene() -> EventResult:
	"""事件：进入角色所在场景"""
	reset_idle_timer()
	
	if is_on_cooldown("enter_scene"):
		return EventResult.new(false, "")
	
	var base_willingness = 50
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	result.message = "active" # chat_mode
	
	if success:
		result.affection_change = randi_range(0, 2)
		result.willingness_change = randi_range(5, 15)
		_set_cooldown("enter_scene", 30.0)
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
		return EventResult.new(false, "")
	
	var base_willingness = 30
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	result.message = "active" # chat_mode
	
	if success:
		result.willingness_change = randi_range(-10, -5)
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
	
	var base_willingness = 170
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
		return EventResult.new(false, "")
	
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
	elif turn_count > 0:
		# 短对话
		result.affection_change = randi_range(0, 3)
		result.willingness_change = randi_range(-5, 5)
	
	_set_cooldown("chat_session_end", 0.0)
	
	_apply_result(result)
	event_completed.emit("chat_session_end", result)
	return result

func on_character_called() -> EventResult:
	"""事件：呼唤角色"""
	reset_idle_timer()
	
	if is_on_cooldown("character_called"):
		return EventResult.new(false, helpers.get_character_name() + "没有回应")
	
	# 计算成功率
	var base_willingness = 140
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		# 呼唤成功
		result.message = "called_success"
		_set_cooldown("character_called", 5.0)
	else:
		# 呼唤失败
		result.message = helpers.get_character_name() + "没有回应"
		# result.willingness_change = randi_range(-5, 5)
		_set_cooldown("character_called", 15.0)
	
	_apply_result(result)
	event_completed.emit("character_called", result)
	return result

func on_idle_timeout() -> EventResult:
	"""事件：空闲超时（长时间无操作）
	
	改进的超时检测机制：
	1. 回复模式（等待点击继续）：语音播放完毕后开始计时，超时变回输入模式
	2. 查看历史模式：超时先变回输入模式
	3. 输入模式：超时按原流程（降低好感，结束聊天）
	4. 非聊天状态：提高回复意愿，尝试触发主动聊天
	"""
	# 这个事件不重置空闲计时器，但会设置新的随机超时时间
	if idle_timer:
		idle_timer.wait_time = _get_random_idle_timeout()
	
	# 获取聊天状态
	var chat_state = _get_chat_state()
	
	var result = EventResult.new(true)
	
	if chat_state == "reply_mode":
		# 回复模式（等待点击继续）：超时变回输入模式
		result.message = "timeout_to_input"
		print("回复模式空闲超时：切换到输入模式")
	elif chat_state == "history_mode":
		# 查看历史模式：超时先变回输入模式
		result.message = "timeout_to_input"
		print("历史模式空闲超时：切换到输入模式")
	elif chat_state == "input_mode":
		# 输入模式：长时间无操作视为结束聊天，降低好感
		result.message = "chat_idle_timeout"
		result.affection_change = randi_range(-5, -2)
		result.willingness_change = randi_range(-10, -5)
		print("输入模式空闲超时：降低好感和回复意愿，结束聊天")
	elif chat_state == "chatting":
		# 聊天中但不需要用户操作（AI正在回复等）：不做任何操作
		result.message = "no_action"
		print("聊天中但不需要用户操作，空闲超时不做任何操作")
	else:
		# 非聊天状态：长时间无操作提高回复意愿，并尝试触发主动聊天或位置变动
		result.message = "idle_increase_willingness"
		result.willingness_change = randi_range(5, 15)
		print("非聊天状态空闲超时：提高回复意愿")
		
		# 尝试触发主动聊天（50%概率）
		var base_willingness = 50
		var success_chance = helpers.calculate_success_chance(base_willingness)
		if randf() < success_chance:
			result.message = "active" # 触发主动聊天
			print("空闲超时触发主动聊天")
		# 如果没有触发主动聊天，尝试触发位置变动（100%概率）
		elif randf() < 1.0:
			result.message = "idle_position_change" # 触发位置变动
			print("空闲超时触发位置变动")
	
	_apply_result(result)
	event_completed.emit("idle_timeout", result)
	return result

func _get_chat_state() -> String:
	"""获取聊天状态
	
	返回值：
	- "reply_mode": 回复模式（等待用户点击继续）
	- "history_mode": 查看历史模式
	- "input_mode": 输入模式（等待用户输入消息）
	- "chatting": 聊天中但不需要用户操作（AI正在回复、打字动画等）
	- "idle": 非聊天状态（聊天框不可见）
	"""
	# 尝试获取主场景中的聊天对话框
	var main_scene = get_tree().root.get_node_or_null("Main")
	if main_scene == null:
		return "idle"
	
	var chat_dialog = main_scene.get_node_or_null("ChatDialog")
	if chat_dialog == null:
		return "idle"
	
	if not chat_dialog.visible:
		return "idle"
	
	# 聊天框可见，检查具体状态
	# 检查是否在查看历史模式
	var history_mgr = chat_dialog.get_node_or_null("HistoryManager")
	var is_history_visible = history_mgr and history_mgr.is_history_visible
	
	# 获取状态信息用于调试
	var is_input = chat_dialog.is_input_mode
	var waiting = chat_dialog.waiting_for_continue
	
	print("EventManager._get_chat_state() - is_input_mode: %s, waiting_for_continue: %s, is_history_visible: %s" % [is_input, waiting, is_history_visible])
	
	if is_history_visible:
		# 查看历史模式
		return "history_mode"
	
	# 优先检查 is_input_mode，因为这是最明确的状态标志
	if is_input:
		# 输入模式（等待用户输入消息）
		# 即使 waiting_for_continue 为 true，只要是输入模式就应该返回 input_mode
		return "input_mode"
	elif waiting:
		# 回复模式（等待点击继续）
		return "reply_mode"
	else:
		# AI正在回复或打字动画进行中
		return "chatting"

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
