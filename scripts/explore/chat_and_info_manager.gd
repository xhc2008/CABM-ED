extends Node
class_name ChatAndInfoManager

# 聊天相关
var chat_ui: ChatUI
var chat_messages: Array[String] = []
var is_in_chat_mode: bool = false

# 信息播报相关
var info_feed: VBoxContainer
var info_messages: Array = [] # 每条: { "text": String, "panel": Panel, "time_left": float, "fading": bool }
const INFO_MESSAGE_DURATION := 4.0

# 信号
signal chat_mode_changed(is_in_chat_mode: bool)
signal message_added(line: String)

var ui_root: Node  # 可以是 CanvasLayer 或 Control
var get_character_name_callback: Callable

func setup(root: Node, character_name_callback: Callable):
	"""初始化管理器"""
	ui_root = root
	get_character_name_callback = character_name_callback
	_create_chat_ui()
	_create_info_feed()

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
	outer_container.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	outer_container.anchor_top = 1.0
	outer_container.anchor_bottom = 1.0
	outer_container.offset_left = 20.0
	outer_container.offset_right = 20.0
	outer_container.offset_top = -500.0  # 从底部向上500像素，给更多空间
	outer_container.offset_bottom = -20.0
	ui_root.add_child(outer_container)
	
	# 创建内部VBoxContainer用于消息布局（从底部向上排列）
	info_feed = VBoxContainer.new()
	info_feed.name = "InfoFeedInner"
	info_feed.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_feed.alignment = BoxContainer.ALIGNMENT_END  # 底部对齐，新消息在底部
	info_feed.add_theme_constant_override("separation", 4)  # 消息之间的间距
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
		
		# 检查面板是否有效
		var panel: Panel = msg.panel
		if not is_instance_valid(panel):
			indices_to_remove.append(i)
			continue
		
		if msg.time_left <= 0.0:
			if is_in_chat_mode:
				# 聊天框打开时超时：直接移除，无淡出
				panel.queue_free()
				indices_to_remove.append(i)
			else:
				if not msg.fading:
					msg.fading = true
					var tween := get_tree().create_tween()
					
					# 确保在tween回调中安全处理
					panel.modulate = Color(panel.modulate.r, panel.modulate.g, panel.modulate.b, 1.0)
					
					tween.tween_property(panel, "modulate:a", 0.0, 0.5)
					tween.finished.connect(
						func():
							# 再次检查有效性
							if is_instance_valid(panel):
								panel.queue_free()
							# 从数组中移除
							_remove_message_by_panel(panel)
					)
					
					# 更新数组
					info_messages[i] = msg
	
	# 从后向前移除已标记的元素
	indices_to_remove.sort()
	for j in range(indices_to_remove.size() - 1, -1, -1):
		var idx = indices_to_remove[j]
		info_messages.remove_at(idx)

func _remove_message_by_panel(panel_to_remove: Panel):
	"""根据面板移除消息"""
	for i in range(info_messages.size() - 1, -1, -1):
		if info_messages[i].get("panel") == panel_to_remove:
			info_messages.remove_at(i)
			break

func _on_chat_message_submitted(text: String):
	"""处理聊天输入（暂时直接用固定AI回复）"""
	# 玩家消息
	var player_line := "<我> " + text
	add_chat_message(player_line)
	
	# 角色（AI）固定回复
	var char_name := _get_character_name()
	var reply := "<%s> 这是一个测试回复，用于验证聊天功能。" % char_name
	add_chat_message(reply)
	
	# 同时做一次信息播报
	broadcast_info(reply)

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
	
	var panel := Panel.new()
	# 使用容器布局模式，让VBoxContainer自动排列
	# panel.layout_mode = 2  # LAYOUT_MODE_CONTAINER
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 不扩展，居中
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 根据内容调整高度
	panel.custom_minimum_size = Vector2(900, 0)  # 固定宽度900px，高度由内容决定
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	# style.corner_radius_top_left = 4
	# style.corner_radius_top_right = 4
	# style.corner_radius_bottom_right = 4
	# style.corner_radius_bottom_left = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate = Color(1, 1, 1, 0.0)
	
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# label.layout_mode = 2  # LAYOUT_MODE_CONTAINER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 根据内容调整高度
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # 顶部对齐，支持多行
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 设置标签的宽度，让它知道在哪里换行（900 - 16边距）
	label.custom_minimum_size = Vector2(884, 0)
	panel.add_child(label)
	
	info_feed.add_child(panel)
	
	var msg := {
		"text": text,
		"panel": panel,
		"time_left": INFO_MESSAGE_DURATION,
		"fading": false
	}
	info_messages.append(msg)
	
	# 仅在非聊天模式下使用淡入
	if not is_in_chat_mode:
		var tween := get_tree().create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	else:
		panel.modulate = Color(1, 1, 1, 1.0)

func _get_character_name() -> String:
	"""获取角色名称"""
	if get_character_name_callback.is_valid():
		return get_character_name_callback.call()
	return "角色"

func get_chat_messages() -> Array[String]:
	"""获取聊天消息历史"""
	return chat_messages.duplicate()

func set_chat_messages(messages: Array[String]):
	"""设置聊天消息历史"""
	chat_messages = messages.duplicate()
	if chat_ui:
		chat_ui.set_messages(chat_messages)
