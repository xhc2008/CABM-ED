extends Control

# 故事模式面板
# 管理故事列表和树状图显示

@onready var close_button: Button = $Panel/VBoxContainer/TitleBar/CloseButton
@onready var story_list_container: VBoxContainer = $Panel/VBoxContainer/HSplitContainer/StoryListPanel/VBoxContainer/ScrollContainer/StoryListContainer
@onready var tree_view_container: Control = $Panel/VBoxContainer/HSplitContainer/TreeViewPanel/VBoxContainer/TreeViewContainer

# 故事数据
var stories_data: Dictionary = {}
var current_story_id: String = ""
var story_buttons: Array[Button] = []

# 树状图相关
var tree_nodes: Array = []
var node_positions: Dictionary = {}
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_threshold: float = 5.0  # 拖拽阈值，鼠标需要移动5像素才开始拖拽

# 触摸缩放相关
var touch_zoom_active: bool = false
var initial_touch_distance: float = 0.0
var initial_zoom_level: float = 1.0
var touch_positions: Dictionary = {}  # 存储触摸点位置

const NODE_SIZE = Vector2(200, 60)
const NODE_SPACING_X = 250
const NODE_SPACING_Y = 80

signal story_mode_closed

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	_load_stories()
	_refresh_story_list()

func _input(event):
	"""处理输入事件，用于树状图的缩放和移动"""
	if not visible:
		return

	# 检查是否在树状图区域内（用于鼠标事件）
	var tree_view_rect = Rect2(tree_view_container.global_position, tree_view_container.size)
	var mouse_pos = get_viewport().get_mouse_position()

	# 处理触摸事件（移动设备）
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
		return
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)
		return

	# 处理鼠标事件
	if not tree_view_rect.has_point(mouse_pos):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始可能的拖拽
				is_dragging = false
				drag_start_pos = get_viewport().get_mouse_position()
				last_mouse_pos = drag_start_pos
			else:
				# 结束拖拽
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_tree_view(0.1, mouse_pos)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_tree_view(-0.1, mouse_pos)

	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_LEFT:
			var current_mouse_pos = get_viewport().get_mouse_position()
			if not is_dragging:
				# 检查是否超过拖拽阈值
				var distance = (current_mouse_pos - drag_start_pos).length()
				if distance > drag_threshold:
					is_dragging = true
					last_mouse_pos = current_mouse_pos
			else:
				# 执行拖拽
				var delta = current_mouse_pos - last_mouse_pos
				pan_offset += delta
				last_mouse_pos = current_mouse_pos
				_redraw_tree()

func _zoom_tree_view(delta_zoom: float, zoom_center: Vector2 = Vector2.ZERO):
	"""缩放树状图"""
	var old_zoom = zoom_level
	zoom_level = clamp(zoom_level + delta_zoom, 0.1, 3.0)

	# 如果提供了缩放中心点，调整偏移量使缩放基于该点
	if zoom_center != Vector2.ZERO:
		var container_rect = Rect2(tree_view_container.global_position, tree_view_container.size)
		if container_rect.has_point(zoom_center):
			# 将屏幕坐标转换为相对于容器的本地坐标
			var local_center = zoom_center - tree_view_container.global_position
			# 计算该点对应的世界坐标（在旧缩放级别下）
			var world_center = (local_center - pan_offset) / old_zoom
			# 重新计算偏移量，使该世界点在新的缩放级别下仍然在相同屏幕位置
			pan_offset = local_center - world_center * zoom_level

	_apply_transform()

func show_panel():
	"""显示故事模式面板"""
	visible = true
	_refresh_story_list()

func hide_panel():
	"""隐藏故事模式面板"""
	visible = false

func _on_close_pressed():
	"""关闭按钮点击"""
	hide_panel()
	story_mode_closed.emit()

func _load_stories():
	"""加载所有故事文件"""
	stories_data.clear()

	var story_dir = DirAccess.open("user://story")
	if not story_dir:
		print("无法打开故事目录: user://story")
		return

	story_dir.list_dir_begin()
	var file_name = story_dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var story_data = _load_story_file(file_name)
			if story_data and story_data.has("story_id"):
				stories_data[story_data.story_id] = story_data
		file_name = story_dir.get_next()

	print("已加载 %d 个故事" % stories_data.size())

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

func _refresh_story_list():
	"""刷新故事列表"""
	# 清空现有按钮
	for button in story_buttons:
		button.queue_free()
	story_buttons.clear()

	# 创建故事按钮
	for story_id in stories_data:
		var story_data = stories_data[story_id]
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 80)
		button.size_flags_horizontal = Control.SIZE_FILL

		# 设置按钮文本 - 使用RichTextLabel来支持BBCode
		var title = story_data.get("story_title", "未知标题")
		var summary = story_data.get("story_summary", "")
		var last_played = story_data.get("last_played_at", "")

		# 清空按钮默认文本
		button.text = ""

		# 使用RichTextLabel来支持BBCode格式
		var rich_text = RichTextLabel.new()
		rich_text.bbcode_enabled = true
		rich_text.fit_content = true
		rich_text.size_flags_horizontal = Control.SIZE_FILL
		rich_text.size_flags_vertical = Control.SIZE_FILL
		rich_text.scroll_active = false
		rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# 设置RichTextLabel填充整个按钮
		rich_text.anchor_right = 1.0
		rich_text.anchor_bottom = 1.0
		rich_text.offset_left = 8
		rich_text.offset_top = 4
		rich_text.offset_right = -8
		rich_text.offset_bottom = -4
		rich_text.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件，让按钮能接收点击

		# 设置字体大小和颜色
		rich_text.add_theme_font_size_override("normal_font_size", 14)
		rich_text.add_theme_font_size_override("bold_font_size", 16)
		rich_text.add_theme_font_size_override("italics_font_size", 12)
		rich_text.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))

		var button_text = "[b]%s[/b]\n%s\n[i]最后游玩: %s[/i]" % [title, summary, last_played]
		rich_text.text = button_text

		button.add_child(rich_text)
		button.add_theme_font_size_override("font_size", 14)
		# 设置按钮对齐
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

		# 设置按钮样式
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.3, 0.5, 0.9, 0.8)
		style_normal.border_color = Color(0.8, 0.8, 1.0, 1.0)
		style_normal.border_width_left = 1
		style_normal.border_width_right = 1
		style_normal.border_width_top = 1
		style_normal.border_width_bottom = 1
		style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
		style_normal.shadow_size = 2

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.4, 0.6, 1.0, 0.9)
		style_hover.border_color = Color(1.0, 1.0, 1.0, 1.0)
		style_hover.border_width_left = 1
		style_hover.border_width_right = 1
		style_hover.border_width_top = 1
		style_hover.border_width_bottom = 1
		style_hover.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style_hover.shadow_size = 3

		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.2, 0.4, 0.8, 0.9)
		style_pressed.border_color = Color(0.6, 0.6, 1.0, 1.0)
		style_pressed.border_width_left = 1
		style_pressed.border_width_right = 1
		style_pressed.border_width_top = 1
		style_pressed.border_width_bottom = 1
		style_pressed.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
		style_pressed.shadow_size = 1

		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 1.0, 1.0))

		# 连接信号
		button.pressed.connect(_on_story_selected.bind(story_id))

		story_list_container.add_child(button)
		story_buttons.append(button)

func _on_story_selected(story_id: String):
	"""故事被选中"""
	current_story_id = story_id
	_render_story_tree()

func _render_story_tree():
	"""渲染故事树状图"""
	if not current_story_id or not stories_data.has(current_story_id):
		return

	var story_data = stories_data[current_story_id]
	if not story_data.has("nodes") or not story_data.has("root_node"):
		return

	tree_nodes.clear()
	node_positions.clear()

	# 获取容器尺寸
	var container_size = tree_view_container.size
	var start_pos = Vector2(container_size.x * 0.1, container_size.y * 0.5)  # 从容器左侧10%位置开始，垂直居中

	# 计算节点位置
	_calculate_node_positions(story_data.root_node, story_data.nodes, start_pos)

	# 重绘树状图
	_redraw_tree()

func _calculate_node_positions(node_id: String, nodes: Dictionary, position: Vector2, depth: int = 0):
	"""计算节点位置"""
	if not nodes.has(node_id):
		return

	var node_data = nodes[node_id]
	tree_nodes.append({"id": node_id, "data": node_data, "depth": depth})

	# 设置节点位置
	node_positions[node_id] = position

	# 处理子节点
	var child_nodes = node_data.get("child_nodes", [])
	if child_nodes.size() > 0:
		var child_y = position.y - (child_nodes.size() - 1) * NODE_SPACING_Y / 2.0
		for child_id in child_nodes:
			_calculate_node_positions(child_id, nodes, Vector2(position.x + NODE_SPACING_X, child_y), depth + 1)
			child_y += NODE_SPACING_Y

func _redraw_tree():
	"""重绘树状图"""
	# 清空现有节点
	for child in tree_view_container.get_children():
		child.queue_free()

	if tree_nodes.is_empty():
		return

	# 绘制连线
	_draw_connections()

	# 绘制节点
	_draw_nodes()

	# 应用缩放和移动变换
	_apply_transform()

func _draw_connections():
	"""绘制节点间的连线"""
	for node_info in tree_nodes:
		var node_id = node_info.id
		var node_data = node_info.data
		var start_pos = node_positions[node_id] + NODE_SIZE / 2

		var child_nodes = node_data.get("child_nodes", [])
		for child_id in child_nodes:
			if node_positions.has(child_id):
				var end_pos = node_positions[child_id] + NODE_SIZE / 2
				_draw_line(start_pos, end_pos)

func _draw_line(start_pos: Vector2, end_pos: Vector2):
	"""绘制一条连线"""
	var line = Line2D.new()
	line.points = [start_pos, end_pos]
	line.width = 3.0  # 稍微加粗
	line.default_color = Color(0.9, 0.9, 1.0, 0.9)  # 更亮的颜色
	line.set_meta("original_points", [start_pos, end_pos])  # 保存原始点
	tree_view_container.add_child(line)

func _draw_nodes():
	"""绘制节点"""
	for node_info in tree_nodes:
		var node_id = node_info.id
		var node_data = node_info.data
		var position = node_positions[node_id]

		var node_panel = Panel.new()
		node_panel.custom_minimum_size = NODE_SIZE
		node_panel.position = position
		node_panel.set_meta("original_position", position)  # 保存原始位置

		var label = Label.new()
		label.text = node_data.get("display_text", "")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_FILL
		label.size_flags_vertical = Control.SIZE_FILL
		label.custom_minimum_size = NODE_SIZE - Vector2(10, 10)  # 调整边距确保文本居中
		label.add_theme_font_size_override("font_size", 14)
		label.clip_text = false  # 允许文本超出边界以便换行

		# 设置标签在Panel中的居中位置
		label.anchor_left = 0.5
		label.anchor_top = 0.5
		label.anchor_right = 0.5
		label.anchor_bottom = 0.5
		label.offset_left = -NODE_SIZE.x / 2 + 5
		label.offset_top = -NODE_SIZE.y / 2 + 5
		label.offset_right = NODE_SIZE.x / 2 - 5
		label.offset_bottom = NODE_SIZE.y / 2 - 5

		node_panel.add_child(label)

		# 设置样式 - 使用更明亮的颜色
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.4, 0.6, 1.0, 0.6)  # 更亮的蓝色背景
		style_box.border_color = Color(1.0, 1.0, 1.0, 1.0)  # 白色边框
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)  # 添加阴影
		style_box.shadow_size = 4
		node_panel.add_theme_stylebox_override("panel", style_box)

		# 设置标签颜色
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))  # 深色文字

		# 添加点击事件（暂时不显示详细内容）
		node_panel.gui_input.connect(_on_node_clicked.bind(node_id))

		tree_view_container.add_child(node_panel)

func _apply_transform():
	"""应用缩放和移动变换"""
	# 直接使用pan_offset和zoom_level进行变换
	for child in tree_view_container.get_children():
		if child is Line2D:
			# 处理连线
			var original_points = child.get_meta("original_points", child.points)
			var transformed_points = []
			for point in original_points:
				var transformed_point = point * zoom_level + pan_offset
				transformed_points.append(transformed_point)
			child.points = transformed_points
		else:
			# 处理节点
			var original_pos = child.get_meta("original_position", child.position)
			child.position = original_pos * zoom_level + pan_offset
			child.scale = Vector2(zoom_level, zoom_level)

func _handle_touch_event(event: InputEventScreenTouch):
	"""处理触摸事件"""
	var touch_index = event.index

	if event.pressed:
		# 记录触摸点位置
		touch_positions[touch_index] = event.position

		# 如果有两个触摸点，开始缩放
		if touch_positions.size() == 2:
			touch_zoom_active = true
			var touch_points = touch_positions.values()
			initial_touch_distance = touch_points[0].distance_to(touch_points[1])
			initial_zoom_level = zoom_level
	else:
		# 移除触摸点
		touch_positions.erase(touch_index)

		# 如果少于两个触摸点，结束缩放
		if touch_positions.size() < 2:
			touch_zoom_active = false

func _handle_drag_event(event: InputEventScreenDrag):
	"""处理拖拽事件"""
	var touch_index = event.index

	# 更新触摸点位置
	touch_positions[touch_index] = event.position

	# 只有当前正好有两个触摸点时才进行缩放
	if touch_positions.size() == 2:
		var touch_points = touch_positions.values()
		var touch_center = (touch_points[0] + touch_points[1]) / 2.0

		# 确保缩放模式已激活
		if not touch_zoom_active:
			touch_zoom_active = true
			initial_touch_distance = touch_points[0].distance_to(touch_points[1])
			initial_zoom_level = zoom_level

		# 计算缩放
		var current_distance = touch_points[0].distance_to(touch_points[1])

		if initial_touch_distance > 0:
			var old_zoom = zoom_level
			var zoom_factor = current_distance / initial_touch_distance
			zoom_level = clamp(initial_zoom_level * zoom_factor, 0.1, 3.0)

			# 调整偏移量使缩放基于触摸中心点
			var container_rect = Rect2(tree_view_container.global_position, tree_view_container.size)
			if container_rect.has_point(touch_center):
				var local_center = touch_center - tree_view_container.global_position
				# 计算触摸中心对应的世界坐标（在旧缩放级别下）
				var world_center = (local_center - pan_offset) / old_zoom
				# 重新计算偏移量，使该世界点在新的缩放级别下仍然在相同屏幕位置
				pan_offset = local_center - world_center * zoom_level

			_apply_transform()
	elif touch_positions.size() == 1:
		# 单指拖拽（移动视图）- 确保缩放模式未激活
		touch_zoom_active = false
		var delta = event.relative
		pan_offset += delta
		_redraw_tree()

func _on_node_clicked(event: InputEvent, node_id: String):
	"""节点点击事件处理（暂时不显示详细内容）"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("节点被点击: ", node_id)
		# 暂时只打印信息，未来可以显示详细内容
