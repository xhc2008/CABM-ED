extends Node
class_name ChatAndInfoManager

# 聊天相关
var chat_ui: ChatUI
var chat_messages: Array[String] = []
var is_in_chat_mode: bool = false

# 分句显示相关
var current_reply_char_name: String = ""

# 消息暂存相关（等待AI响应期间用户发送的新消息）
var pending_messages: Array[String] = []
var is_ai_processing: bool = false

# 信息播报相关
var info_feed: VBoxContainer
var info_messages: Array = [] # 每条: { "text": String, "panel": Panel, "time_left": float, "fading": bool }
const INFO_MESSAGE_DURATION := 20.0

# 信号
signal chat_mode_changed(is_in_chat_mode: bool)
signal message_added(line: String)

var ui_root: Node  # 可以是 CanvasLayer 或 Control
var get_character_name_callback: Callable
var get_explore_scene_name_callback: Callable  # 获取探索场景名称的回调
var message_item_scene: PackedScene = load("res://scenes/message_item.tscn")
var adventure_ai: AdventureAI

func setup(root: Node, character_name_callback: Callable, explore_scene_name_callback: Callable = Callable()):
	"""初始化管理器
	
	Args:
		root: UI根节点
		character_name_callback: 获取角色名称的回调
		explore_scene_name_callback: 获取探索场景名称的回调（可选，仅在探索场景中使用）
	"""
	ui_root = root
	get_character_name_callback = character_name_callback
	get_explore_scene_name_callback = explore_scene_name_callback
	_create_chat_ui()
	_create_info_feed()
	adventure_ai = AdventureAI.new()
	add_child(adventure_ai)
	adventure_ai.reply_ready.connect(_on_ai_reply_ready)
	adventure_ai.sentence_ready.connect(_on_ai_sentence_ready)
	adventure_ai.all_sentences_completed.connect(_on_all_sentences_completed)
	adventure_ai.error_occurred.connect(_on_ai_error_occurred)

func _create_chat_ui():
	"""创建聊天UI"""
	if not ui_root:
		return
	var chat_scene := load("res://scenes/chat_ui.tscn")
	if chat_scene and ResourceLoader.exists("res://scenes/chat_ui.tscn"):
		chat_ui = chat_scene.instantiate()
		if chat_ui:
			ui_root.add_child(chat_ui)
			chat_ui.visible = false
			chat_ui.message_submitted.connect(_on_chat_message_submitted)
			if chat_ui.has_signal("close_requested"):
				chat_ui.close_requested.connect(_on_chat_close_requested)

func _create_info_feed():
	"""创建左下角信息播报区域"""
	if not ui_root:
		return
	
	# 创建外层容器（锚定到左下角）
	var outer_container := Control.new()
	outer_container.name = "InfoFeed"
	outer_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	outer_container.custom_minimum_size = Vector2(900, 0)
	outer_container.offset_left = 0.0
	outer_container.offset_top = -500.0  # 从底部向上500像素，给更多空间
	outer_container.offset_bottom = -98.0
	outer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	ui_root.add_child(outer_container)
	
	# 创建内部VBoxContainer用于消息布局（从底部向上排列）
	info_feed = VBoxContainer.new()
	info_feed.name = "InfoFeedInner"
	info_feed.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_feed.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_feed.alignment = BoxContainer.ALIGNMENT_END  # 底部对齐，新消息在底部
	info_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_feed.add_theme_constant_override("separation", 0)  # 消息之间的间距
	outer_container.add_child(info_feed)

func update(delta: float):
	"""每帧更新（需要在主场景的 _process 中调用）"""
	_update_info_messages(delta)

func _update_info_messages(delta: float):
	"""更新信息播报计时与淡出逻辑"""
	if info_messages.is_empty():
		return
	
	# 使用临时数组收集需要移除的索引
	var indices_to_remove := []
	
	for i in range(info_messages.size() - 1, -1, -1):
		var msg = info_messages[i]
		msg.time_left -= delta

		# 检查标签是否有效
		var label: Label = msg.panel
		if not is_instance_valid(label):
			indices_to_remove.append(i)
			continue

		if msg.time_left <= 0.0:
			if is_in_chat_mode:
				# 聊天框打开时超时：直接移除，无淡出
				label.queue_free()
				indices_to_remove.append(i)
			else:
				if not msg.fading:
					msg.fading = true
					var tween := get_tree().create_tween()

					# 确保在tween回调中安全处理
					label.modulate = Color(label.modulate.r, label.modulate.g, label.modulate.b, 1.0)

					tween.tween_property(label, "modulate:a", 0.0, 0.5)
					tween.finished.connect(_on_tween_finished.bind(label))

					# 更新数组
					info_messages[i] = msg
	
	# 从后向前移除已标记的元素
	indices_to_remove.sort()
	for j in range(indices_to_remove.size() - 1, -1, -1):
		var idx = indices_to_remove[j]
		info_messages.remove_at(idx)

func _remove_message_by_panel(label_to_remove: Label):
	"""根据标签移除消息"""
	for i in range(info_messages.size() - 1, -1, -1):
		if info_messages[i].get("panel") == label_to_remove:
			info_messages.remove_at(i)
			break

func _on_chat_message_submitted(text: String):
	"""处理聊天输入"""
	var user_name := _get_user_name()
	var player_line := "<%s> %s" % [user_name, text]
	add_chat_message(player_line)
	show_info_toast(player_line)

	if adventure_ai:
		if is_ai_processing:
			# AI正在处理中，暂存消息
			print("AI正在处理中，暂存消息: ", text)
			pending_messages.append(text)
		else:
			# 直接处理消息
			_process_user_message(text)

	exit_chat_mode()

func _process_user_message(text: String):
	"""处理用户消息（发送给AI）"""
	if not adventure_ai:
		print("警告: adventure_ai未初始化")
		return

	is_ai_processing = true
	print("开始处理用户消息: ", text)
	print("当前AI处理状态: ", is_ai_processing)

	# 添加到显示历史
	var user_name := _get_user_name()
	var user_message_line := "<%s> %s" % [user_name, text]
	adventure_ai.add_to_display_history("user", user_message_line)
	print("添加到显示历史: ", user_message_line)

	# 获取探索场景名称（如果在探索场景中）
	var explore_scene_name := ""
	if get_explore_scene_name_callback.is_valid():
		explore_scene_name = get_explore_scene_name_callback.call()

	adventure_ai.request_reply(text, explore_scene_name)

func _on_chat_close_requested():
	"""聊天UI请求关闭（点击退出按钮）"""
	exit_chat_mode()

func add_chat_message(line: String):
	"""添加聊天消息"""
	if line.is_empty():
		return
	chat_messages.append(line)
	if chat_ui:
		chat_ui.add_message(line)
	message_added.emit(line)

func broadcast_info(text: String):
	"""左下角信息播报 + 写入聊天历史"""
	var line := "<系统> " + text
	add_chat_message(line)
	show_info_toast(line)

func enter_chat_mode():
	"""进入聊天模式：禁用移动和交互，隐藏战斗与移动端UI"""
	if is_in_chat_mode:
		return
	is_in_chat_mode = true
	if chat_ui:
		chat_ui.open()
	# 隐藏信息播报的可见部分（计时继续在 _update_info_messages 中进行）
	if info_feed:
		info_feed.visible = false
	chat_mode_changed.emit(true)

func exit_chat_mode():
	"""退出聊天模式：恢复控制和UI"""
	if not is_in_chat_mode:
		return
	is_in_chat_mode = false
	if chat_ui:
		chat_ui.close()
	if info_feed:
		info_feed.visible = true
	chat_mode_changed.emit(false)

func show_info_toast(text: String):
	"""在左下角短暂显示一条信息"""
	if not info_feed:
		return
	var label := message_item_scene.instantiate() as Label
	label.text = text
	# 等待一帧让Label重新计算大小
	await get_tree().process_frame

	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	label.modulate = Color(1, 1, 1, 0.0)
	info_feed.add_child(label)
	var msg := {"text": text, "panel": label, "time_left": INFO_MESSAGE_DURATION, "fading": false}
	info_messages.append(msg)
	if not is_in_chat_mode:
		var tween := get_tree().create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.15)
	else:
		label.modulate = Color(1, 1, 1, 1.0)

func _on_ai_reply_ready(_text: String) -> void:
	"""AI回复就绪，开始逐句显示"""
	print("AI回复就绪，开始逐句显示")
	current_reply_char_name = _get_character_name()

func _on_ai_sentence_ready(sentence: String) -> void:
	"""处理单句就绪信号，逐句显示"""
	print("显示句子: ", sentence)
	var sentence_line := "<%s> %s" % [current_reply_char_name, sentence]
	add_chat_message(sentence_line)  # 每句都立即添加到聊天历史
	show_info_toast(sentence_line)

	# 添加到显示历史
	if adventure_ai:
		adventure_ai.add_to_display_history("assistant", sentence_line)

func _on_all_sentences_completed() -> void:
	"""所有句子显示完成，处理暂存消息"""
	print("AI回复完成，当前暂存消息数量: ", pending_messages.size())
	print("处理前is_ai_processing状态: ", is_ai_processing)

	# 先处理暂存的消息（如果有）
	if not pending_messages.is_empty():
		var combined_message = "\n".join(pending_messages)
		print("处理暂存消息: ", combined_message)

		# 清空暂存消息
		pending_messages.clear()

		# 发送合并后的消息（这会设置is_ai_processing = true）
		_process_user_message(combined_message)
		print("处理暂存消息后is_ai_processing状态: ", is_ai_processing)
	else:
		# 没有暂存消息，重置AI处理状态
		is_ai_processing = false
		print("无暂存消息，重置is_ai_processing为: ", is_ai_processing)

	# 重置当前回复角色名称
	current_reply_char_name = ""

	# 保存聊天历史断点（仅在没有暂存消息时，即完整回复结束后）
	if not is_ai_processing:
		_save_chat_breakpoint()

func _save_chat_breakpoint():
	"""保存聊天断点（由父场景调用）"""
	# 通知父场景保存聊天历史
	var parent = get_parent()
	if parent and parent.has_method("_save_chat_history"):
		parent._save_chat_history()

func _on_ai_error_occurred(error_message: String) -> void:
	"""处理AI错误"""
	print("AI错误发生: ", error_message)
	print("错误处理前is_ai_processing状态: ", is_ai_processing)

	# 显示错误信息
	var error_line := "<系统> AI回复出错：" + error_message
	add_chat_message(error_line)
	show_info_toast(error_line)

	# 添加到显示历史
	if adventure_ai:
		adventure_ai.add_to_display_history("system", error_line)

	# 重置当前回复角色名称
	current_reply_char_name = ""

	# 即使出错也要处理暂存消息（如果有的话）
	if not pending_messages.is_empty():
		var combined_message = "\n".join(pending_messages)
		print("AI错误后处理暂存消息: ", combined_message)
		pending_messages.clear()
		_process_user_message(combined_message)  # 这会设置is_ai_processing = true
		print("错误处理暂存消息后is_ai_processing状态: ", is_ai_processing)
	else:
		# 没有暂存消息，重置AI处理状态
		is_ai_processing = false
		print("错误处理无暂存消息，重置is_ai_processing为: ", is_ai_processing)

func _get_character_name() -> String:
	"""获取角色名称"""
	if get_character_name_callback.is_valid():
		return get_character_name_callback.call()
	return "角色"

func _get_user_name() -> String:
	"""获取用户名"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		return save_mgr.get_user_name()
	return "我"

func get_chat_messages() -> Array[String]:
	"""获取聊天消息历史"""
	return chat_messages.duplicate()

func set_chat_messages(messages: Array[String]):
	"""设置聊天消息历史"""
	chat_messages = messages.duplicate()
	if chat_ui:
		chat_ui.set_messages(chat_messages)

func get_display_history() -> Array:
	"""获取完整的显示历史（包括分句后的所有消息）"""
	if adventure_ai:
		return adventure_ai.get_display_history()
	return []

func get_ai_context_history() -> Array:
	"""获取AI上下文历史（用于AI理解的完整对话）"""
	if adventure_ai:
		return adventure_ai.conversation_history.duplicate()
	return []

func _on_tween_finished(label: Label):
	"""Tween完成回调，安全处理标签移除"""
	if is_instance_valid(label):
		label.queue_free()
	_remove_message_by_panel(label)
