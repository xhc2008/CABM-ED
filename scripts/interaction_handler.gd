extends Node
class_name InteractionHandler

# 交互处理器 - 负责处理各种交互事件（聊天、场景切换、呼唤等）

signal active_chat_triggered
signal idle_position_change_triggered
signal auto_continue_chat_triggered
signal force_end_chat_triggered

var scene_manager: SceneManager
var character
var chat_dialog
var scene_menu
var pending_chat_timer: Timer
var scene_switch_timer: Timer

func initialize(scene_mgr: SceneManager, character_node, chat_dlg, scene_mnu, parent: Node):
	"""初始化处理器"""
	scene_manager = scene_mgr
	character = character_node
	chat_dialog = chat_dlg
	scene_menu = scene_mnu
	
	# 创建计时器
	scene_switch_timer = Timer.new()
	scene_switch_timer.one_shot = true
	scene_switch_timer.timeout.connect(_on_scene_switch_timeout)
	parent.add_child(scene_switch_timer)
	
	pending_chat_timer = Timer.new()
	pending_chat_timer.one_shot = true
	parent.add_child(pending_chat_timer)

func try_scene_interaction(action_id: String):
	"""尝试场景交互（进入/离开）"""
	if not has_node("/root/EventManager"):
		return
	
	var event_mgr = get_node("/root/EventManager")
	var result
	
	if action_id == "enter_scene":
		result = event_mgr.on_enter_scene()
	elif action_id == "leave_scene":
		result = event_mgr.on_leave_scene()
	else:
		return
	
	if result.success:
		print("场景交互成功，延迟触发聊天: ", action_id)
		
		if scene_menu and scene_menu.visible:
			scene_menu.hide_menu()
		
		pending_chat_timer.wait_time = 0.5
		pending_chat_timer.timeout.connect(_on_pending_chat_timeout.bind(result.message), CONNECT_ONE_SHOT)
		pending_chat_timer.start()
	else:
		print("场景交互失败或在冷却中: ", action_id)

func _on_pending_chat_timeout(chat_mode: String):
	"""延迟聊天触发"""
	if not scene_manager.has_character_in_scene(scene_manager.current_scene):
		print("角色已不在当前场景，取消对话触发")
		return
	
	if not character.visible or character.is_chatting:
		print("角色不可见或正在聊天，取消对话触发")
		return
	
	var mode = chat_mode if chat_mode != "" else "passive"
	character.start_chat()
	chat_dialog.show_dialog(mode)
	
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").disable_all()
	
	print("延迟聊天已触发")

func cancel_pending_chat():
	"""取消待触发的聊天"""
	if pending_chat_timer and not pending_chat_timer.is_stopped():
		pending_chat_timer.stop()
		for connection in pending_chat_timer.timeout.get_connections():
			pending_chat_timer.timeout.disconnect(connection["callable"])
		print("已取消待触发的聊天")

func lock_scene_switch():
	"""锁定场景切换"""
	if scene_switch_timer:
		scene_switch_timer.start(1.0)
		print("场景切换已锁定1秒")

func _on_scene_switch_timeout():
	"""场景切换锁定超时"""
	print("场景切换锁定解除")

func is_scene_switch_locked() -> bool:
	"""检查场景切换是否被锁定"""
	return scene_switch_timer and not scene_switch_timer.is_stopped()

func trigger_active_chat():
	"""触发角色主动聊天"""
	if not character.visible or character.is_chatting:
		return
	
	if chat_dialog.visible:
		print("聊天对话框已打开，忽略主动聊天触发")
		return
	
	if not scene_manager.has_character_in_scene(scene_manager.current_scene):
		return
	
	print("触发角色主动聊天")
	
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.reset_idle_timer()
	
	character.start_chat()
	chat_dialog.show_dialog("active")
	
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").disable_all()
	
	active_chat_triggered.emit()

func trigger_idle_position_change():
	"""触发空闲时的位置变动"""
	if character.is_chatting:
		return
	
	print("触发空闲位置变动（无字幕）")
	await character.apply_position_probability_silent()
	idle_position_change_triggered.emit()

func auto_continue_chat():
	"""自动继续聊天"""
	if chat_dialog.visible and chat_dialog.waiting_for_continue:
		print("等待继续时超时，自动继续")
		chat_dialog._on_continue_clicked()
		auto_continue_chat_triggered.emit()

func force_end_chat():
	"""强制结束聊天"""
	if chat_dialog.visible:
		print("聊天空闲超时，强制结束聊天")
		force_end_chat_triggered.emit()
