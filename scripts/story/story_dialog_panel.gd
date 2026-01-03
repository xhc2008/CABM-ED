extends Control

# 故事对话面板
# 显示故事对话界面，包含树状图和对话栏

signal dialog_closed

@onready var story_info_label: TextEdit = $Panel/HBoxContainer/LeftPanel/InfoBar/InfoHBox/StoryInfoLabel
@onready var create_checkpoint_button: Button = $Panel/HBoxContainer/LeftPanel/InfoBar/InfoHBox/CreateCheckpointButton
@onready var tree_view: Control = $Panel/HBoxContainer/LeftPanel/TreeView
@onready var message_container: VBoxContainer = $Panel/HBoxContainer/RightPanel/DialogPanel/ScrollContainer/MessageContainer
@onready var message_input: TextEdit = $Panel/HBoxContainer/RightPanel/MessageInputPanel/HBoxContainer/MessageInput
@onready var send_button: Button = $Panel/HBoxContainer/RightPanel/MessageInputPanel/HBoxContainer/SendButton

# 故事数据
var current_story_id: String = ""
var current_node_id: String = ""
var story_data: Dictionary = {}
var nodes_data: Dictionary = {}

# 消息数据
var messages: Array = []

func _ready():
	"""初始化"""
	create_checkpoint_button.pressed.connect(_on_create_checkpoint_pressed)
	send_button.pressed.connect(_on_send_message_pressed)
	message_input.text_changed.connect(_on_message_input_changed)

	# 连接树状图信号
	tree_view.node_selected.connect(_on_tree_node_selected)
	tree_view.node_deselected.connect(_on_tree_node_deselected)

func initialize(story_id: String, node_id: String):
	"""初始化对话面板"""
	current_story_id = story_id
	current_node_id = node_id

	_load_story_data()
	_setup_ui()
	_initialize_tree_view()
	_initialize_dialog()

func _load_story_data():
	"""加载故事数据"""
	var story_dir = DirAccess.open("user://story")
	if not story_dir:
		print("无法打开故事目录: user://story")
		return

	story_dir.list_dir_begin()
	var file_name = story_dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var story_file_data = _load_story_file(file_name)
			if story_file_data and story_file_data.has("story_id") and story_file_data.story_id == current_story_id:
				story_data = story_file_data
				nodes_data = story_data.get("nodes", {})
				break
		file_name = story_dir.get_next()

func _load_story_file(file_name: String) -> Dictionary:
	"""加载单个故事文件"""
	var file_path = "user://story/" + file_name

	if not FileAccess.file_exists(file_path):
		print("故事文件不存在: ", file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("无法打开故事文件: ", file_path)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON解析错误: ", file_path)
		return {}

	return json.data

func _setup_ui():
	"""设置UI"""
	if story_data.is_empty():
		return

	var story_title = story_data.get("story_title", "未知故事")
	var story_summary = story_data.get("story_summary", "")

	story_info_label.text = "故事：《%s》\n简介：%s" % [story_title, story_summary]

func _initialize_tree_view():
	"""初始化树状图"""
	if nodes_data.is_empty():
		return

	# 创建故事节点数据的副本，用于添加新节点
	var extended_nodes = nodes_data.duplicate(true)

	# 在当前节点后添加一个空白节点"……"
	var current_node_data = extended_nodes.get(current_node_id, {})
	var child_nodes = current_node_data.get("child_nodes", [])

	# 生成新节点的ID
	var new_node_id = "dialog_temp_node_" + current_node_id

	# 创建新节点数据
	var new_node_data = {
		"display_text": "……",
		"full_text": "……",
		"child_nodes": []
	}
	extended_nodes[new_node_id] = new_node_data

	# 将新节点添加到当前节点的子节点列表中
	child_nodes.append(new_node_id)
	extended_nodes[current_node_id]["child_nodes"] = child_nodes

	# 重置树状图视角
	tree_view.zoom_level = 1.0
	tree_view.pan_offset = Vector2.ZERO

	# 渲染树状图
	tree_view.render_tree(story_data.get("root_node", ""), extended_nodes)

	# 禁用节点选中功能（只能查看，不能选择）
	tree_view.set_selection_disabled(true)

	# 默认选中新建的"……"节点
	tree_view.select_node(new_node_id)

func _initialize_dialog():
	"""初始化对话"""
	_clear_messages()

	# 添加初始系统消息
	_add_system_message("故事开始于节点：" + current_node_id)

	# TODO: 加载历史对话记录（如果有的话）

func _clear_messages():
	"""清空消息"""
	messages.clear()
	for child in message_container.get_children():
		child.queue_free()

func _add_system_message(text: String):
	"""添加系统消息"""
	var message_item = _create_message_item(text, "system")
	message_container.add_child(message_item)
	messages.append({"type": "system", "text": text})

	# 自动滚动到底部
	call_deferred("_scroll_to_bottom")

func _add_user_message(text: String):
	"""添加用户消息"""
	var message_item = _create_message_item(text, "user")
	message_container.add_child(message_item)
	messages.append({"type": "user", "text": text})

	call_deferred("_scroll_to_bottom")

func _add_ai_message(text: String):
	"""添加AI消息"""
	var message_item = _create_message_item(text, "ai")
	message_container.add_child(message_item)
	messages.append({"type": "ai", "text": text})

	call_deferred("_scroll_to_bottom")

func _create_message_item(text: String, type: String) -> Control:
	"""创建消息项"""
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_FILL

	var panel = Panel.new()
	var style_box = StyleBoxFlat.new()

	match type:
		"user":
			# 用户消息样式（蓝色气泡，右对齐）
			style_box.bg_color = Color(0.2, 0.6, 1.0, 0.9)  # 蓝色背景
			style_box.border_color = Color(0.1, 0.5, 0.9, 1.0)
			container.alignment = BoxContainer.ALIGNMENT_END
			style_box.corner_radius_top_left = 12
			style_box.corner_radius_top_right = 12
			style_box.corner_radius_bottom_left = 12
			style_box.corner_radius_bottom_right = 4
		"ai":
			# AI消息样式（白色气泡，左对齐）
			style_box.bg_color = Color(1.0, 1.0, 1.0, 0.9)  # 白色背景
			style_box.border_color = Color(0.8, 0.8, 0.8, 1.0)
			container.alignment = BoxContainer.ALIGNMENT_BEGIN
			style_box.corner_radius_top_left = 12
			style_box.corner_radius_top_right = 12
			style_box.corner_radius_bottom_left = 4
			style_box.corner_radius_bottom_right = 12
		"system":
			# 系统消息样式（灰色，居中）
			style_box.bg_color = Color(0.7, 0.7, 0.7, 0.8)  # 灰色背景
			style_box.border_color = Color(0.6, 0.6, 0.6, 1.0)
			container.alignment = BoxContainer.ALIGNMENT_CENTER
			style_box.corner_radius_top_left = 8
			style_box.corner_radius_top_right = 8
			style_box.corner_radius_bottom_left = 8
			style_box.corner_radius_bottom_right = 8

	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1

	panel.add_theme_stylebox_override("panel", style_box)

	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	match type:
		"user":
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色文字
		"ai":
			label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))  # 黑色文字
		"system":
			label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1.0))  # 灰色文字

	label.add_theme_font_size_override("font_size", 14)

	# 设置合适的内边距
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	margin_container.add_child(label)

	panel.add_child(margin_container)

	# 设置Panel大小
	var label_size = label.get_minimum_size()
	margin_container.custom_minimum_size = Vector2(min(label_size.x + 24, 400), label_size.y + 16)  # 最大宽度400
	# 设置最小宽度，确保气泡有合适的宽度
	var min_width = max(label_size.x + 24, 80)  # 最小宽度80像素
	var final_width = min(min_width, 400)  # 最大宽度400像素
	panel.custom_minimum_size = Vector2(final_width, label_size.y + 16)

	container.add_child(panel)

	return container

func _scroll_to_bottom():
	"""滚动到底部"""
	var scroll_container = message_container.get_parent().get_parent() as ScrollContainer
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_create_checkpoint_pressed():
	"""创建存档点按钮点击"""
	print("创建存档点功能（待实现）")
	# TODO: 实现创建存档点功能

func _on_send_message_pressed():
	"""发送消息按钮点击"""
	var message_text = message_input.text.strip_edges()
	if message_text.is_empty():
		return

	# 添加用户消息
	_add_user_message(message_text)

	# 清空输入框
	message_input.text = ""

	# TODO: 发送消息到AI并等待回复
	# 暂时添加一个占位回复
	call_deferred("_add_ai_placeholder_response", message_text)

func _add_ai_placeholder_response(user_message: String):
	"""添加AI占位回复"""
	await get_tree().create_timer(1.0).timeout  # 模拟网络延迟
	var placeholder_response = "这是对 '" + user_message + "' 的占位回复。实际对话功能待实现。"
	_add_ai_message(placeholder_response)

func _on_message_input_changed():
	"""消息输入改变"""
	# 根据文本行数自动调整输入框高度
	var line_count = message_input.get_line_count()
	var base_height = 40  # 基础高度
	var line_height = 20  # 每行高度
	var max_height = 120  # 最大高度

	var new_height = min(base_height + (line_count - 1) * line_height, max_height)

	# 获取消息输入面板并调整其高度
	var message_input_panel = message_input.get_parent().get_parent() as Panel
	if message_input_panel:
		message_input_panel.custom_minimum_size.y = new_height + 20  # 加上内边距

	# 强制更新布局
	message_input_panel.queue_redraw()

func _on_tree_node_selected(node_id: String):
	"""树状图节点选中"""
	print("树状图节点选中: ", node_id)
	# TODO: 处理节点选中逻辑，比如跳转到对应对话位置

func _on_tree_node_deselected():
	"""树状图节点取消选中"""
	print("树状图节点取消选中")
	# TODO: 处理节点取消选中逻辑

func show_panel():
	"""显示对话面板"""
	visible = true

func hide_panel():
	"""隐藏对话面板"""
	visible = false
	dialog_closed.emit()

func get_current_story_id() -> String:
	"""获取当前故事ID"""
	return current_story_id

func get_current_node_id() -> String:
	"""获取当前节点ID"""
	return current_node_id
