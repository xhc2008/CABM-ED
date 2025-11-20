extends Control

signal map_closed
signal go_selected(scene_id: String)
var current_explore_id: String = ""
var on_go_selected: Callable
var scenes_config: Dictionary = {}
var map_config: Dictionary = {}
var zoom: float = 1.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
var base_canvas_size: Vector2 = Vector2(2000, 1200)
var point_nodes: Array = [] # [{node: Button, pos: Vector2}]

var current_level: String = "world"
var current_base_id: String = ""
var current_base_data: Dictionary = {}
var force_world_mode: bool = false

# 拖动相关变量
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var canvas_offset: Vector2 = Vector2.ZERO

# 触摸缩放相关变量
var touch_zoom_start_distance: float = 0.0
var touch_zoom_start_zoom: float = 1.0
var touch_ids: Array = [] # 存储当前触摸点的ID
var touch_positions: Dictionary = {} # 存储每个触摸点的位置 {index: position}

@onready var canvas: Control = $Root/Canvas
@onready var close_button: Button = $Root/CloseButton
@onready var background_image: TextureRect = $Root/Canvas/BackgroundImage
@onready var backdrop: ColorRect = $Backdrop
@onready var sidebar_panel: Panel = $Root/Sidebar
@onready var sidebar_title: Label = $Root/Sidebar/VBox/Title
@onready var sidebar_description: RichTextLabel = $Root/Sidebar/VBox/Description
@onready var enter_button: Button = $Root/Sidebar/VBox/EnterButton
var coord_label: Label

func _ready():
	close_button.pressed.connect(_on_close)
	_load_configs()
	_init_background_for_world()
	_build_world_points()
	
	# 等待一帧确保所有节点已就绪
	await get_tree().process_frame
	
	_center_initial_view()
	_apply_zoom(true)
	enter_button.pressed.connect(_on_enter_explore)
	backdrop.gui_input.connect(_on_backdrop_input)
	_init_sidebar_style()
	coord_label = Label.new()
	coord_label.name = "CoordLabel"
	coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 设置文字样式
	coord_label.add_theme_color_override("font_color", Color.WHITE)
	coord_label.add_theme_font_size_override("font_size", 20)
	# 设置半透明背景
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	coord_label.add_theme_stylebox_override("normal", bg_style)
	# 先设置居中，然后移动到顶部
	coord_label.set_anchors_preset(Control.PRESET_CENTER)
	coord_label.offset_top = -350.0  # 向上移动200像素到顶部
	coord_label.offset_bottom = -320.0  # 保持高度30像素
	coord_label.offset_left = -100.0  # 宽度200像素
	coord_label.offset_right = 100.0
	# 内边距
	coord_label.add_theme_constant_override("content_margin_top", 8)
	coord_label.add_theme_constant_override("content_margin_bottom", 8)
	coord_label.add_theme_constant_override("content_margin_left", 16)
	coord_label.add_theme_constant_override("content_margin_right", 16)
	$Root.add_child(coord_label)

func _on_close():
	if current_level == "base":
		_switch_to_world(true)
		return
	map_closed.emit()
	queue_free()

func _load_configs():
	var scene_path = "res://config/scenes.json"
	if FileAccess.file_exists(scene_path):
		var f = FileAccess.open(scene_path, FileAccess.READ)
		var js = f.get_as_text()
		f.close()
		var j = JSON.new()
		if j.parse(js) == OK:
			var d = j.data
			scenes_config = d.get("scenes", {})
	var map_path = "res://config/map.json"
	if FileAccess.file_exists(map_path):
		var f2 = FileAccess.open(map_path, FileAccess.READ)
		var js2 = f2.get_as_text()
		f2.close()
		var j2 = JSON.new()
		if j2.parse(js2) == OK:
			map_config = j2.data
		if map_config.has("size"):
			var s = map_config.size
			base_canvas_size = Vector2(s[0], s[1])
	
	# 设置背景图片大小
	if background_image.texture:
		var texture_size = background_image.texture.get_size()
		background_image.size = texture_size
		base_canvas_size = texture_size
		print("Background size set to: ", texture_size)

func _init_background_for_world():
	if map_config.has("world") and map_config.world.has("image"):
		var path = map_config.world.image
		if ResourceLoader.exists(path):
			background_image.texture = load(path)
			if background_image.texture:
				var ts = background_image.texture.get_size()
				background_image.size = ts
				base_canvas_size = ts

func _clear_points():
	for entry in point_nodes:
		var n = entry.node
		if is_instance_valid(n):
			n.queue_free()
	point_nodes.clear()

func _build_world_points():
	_clear_points()
	if map_config.has("world") and map_config.world.has("points"):
		for p in map_config.world.points:
			var id = p.get("id", "")
			var offset_x = p.get("x", 0)
			var offset_y = p.get("y", 0)
			var center_x = base_canvas_size.x / 2.0
			var center_y = base_canvas_size.y / 2.0
			var pos = Vector2(center_x + offset_x, center_y + offset_y)
			var t = p.get("type", "")
			if t == "base":
				var btn = Button.new()
				btn.text = p.get("name", id)
				btn.position = pos
				btn.pressed.connect(_on_base_pressed.bind(id))
				canvas.add_child(btn)
				point_nodes.append({"node": btn, "pos": pos, "id": id, "type": "base"})
			elif t == "explore":
				var eb = Button.new()
				eb.text = p.get("name", "探索区")
				eb.position = pos
				# 修改：传递探索点ID
				eb.pressed.connect(_on_explore_point_pressed.bind(id))
				canvas.add_child(eb)
				point_nodes.append({"node": eb, "pos": pos, "id": id, "type": "explore"})

func _build_base_points(base_id: String):
	_clear_points()
	if not map_config.has("world"):
		return
	for p in map_config.world.points:
		if p.get("id") == base_id and p.get("type") == "base":
			current_base_data = p
			break
	if current_base_data.is_empty():
		return
	if current_base_data.has("image"):
		var path = current_base_data.image
		if ResourceLoader.exists(path):
			background_image.texture = load(path)
			if background_image.texture:
				var ts = background_image.texture.get_size()
				background_image.size = ts
				base_canvas_size = ts
	var children = current_base_data.get("children", [])
	var center_x = base_canvas_size.x / 2.0
	var center_y = base_canvas_size.y / 2.0
	for c in children:
		var cid = c.get("id", "")
		var offset_x = c.get("x", 0)
		var offset_y = c.get("y", 0)
		var pos = Vector2(center_x + offset_x, center_y + offset_y)
		var btn = Button.new()
		var title = c.get("name", cid)
		if scenes_config.has(cid):
			title = scenes_config[cid].get("name", title)
		btn.text = title
		btn.position = pos
		btn.pressed.connect(_on_point_pressed.bind(cid))
		canvas.add_child(btn)
		point_nodes.append({"node": btn, "pos": pos, "id": cid, "type": "scene"})
	close_button.text = "世界地图"
	current_level = "base"
	current_base_id = base_id

func _switch_to_base(center_on_child: bool):
	var base_id = current_base_id
	if base_id == "":
		base_id = _last_clicked_base_id
	if base_id == "":
		return
	_build_base_points(base_id)
	sidebar_panel.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var center_x = base_canvas_size.x / 2.0
	var center_y = base_canvas_size.y / 2.0
	if center_on_child and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var cid = sm.get_character_scene()
		var pos: Vector2 = Vector2.ZERO
		for c in current_base_data.get("children", []):
			if c.get("id") == cid:
				pos = Vector2(center_x + c.get("x", 0), center_y + c.get("y", 0))
				break
		if pos != Vector2.ZERO:
			_center_on_point(pos)
		else:
			_center_on_point(Vector2(center_x, center_y))
	else:
		_center_on_point(Vector2(center_x, center_y))
	_apply_zoom(true)

var _last_clicked_base_id: String = ""

func _on_base_pressed(base_id: String):
	_last_clicked_base_id = base_id
	current_base_id = base_id
	_switch_to_base(false)

func _center_initial_view():
	if force_world_mode:
		return
	var visible_size = get_viewport_rect().size
	var center = base_canvas_size * zoom / 2.0
	canvas_offset = center - visible_size / 2.0
	_update_canvas_position()
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.has_meta("map_origin"):
			var origin = sm.get_meta("map_origin")
			sm.remove_meta("map_origin")
			if origin == "explore":
				var pos = _get_world_point_pos("explore")
				if pos != Vector2.ZERO:
					_center_on_point(pos)
				return
		var cur_scene = sm.get_character_scene()
		var base_id = _find_base_for_scene(cur_scene)
		if base_id != "":
			current_base_id = base_id
			_switch_to_base(false)

func _update_canvas_position():
	canvas.position = -canvas_offset
	_clamp_canvas_position()

func _clamp_canvas_position():
	var visible_size = get_viewport_rect().size
	var max_x = max(0.0, base_canvas_size.x * zoom - visible_size.x)
	var max_y = max(0.0, base_canvas_size.y * zoom - visible_size.y)
	canvas_offset.x = clamp(canvas_offset.x, 0.0, max_x)
	canvas_offset.y = clamp(canvas_offset.y, 0.0, max_y)
	canvas.position = -canvas_offset

func _on_point_pressed(scene_id: String):
	if on_go_selected and on_go_selected.is_valid():
		on_go_selected.call(scene_id)
		return
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.set_character_scene(scene_id)
	get_tree().change_scene_to_file("res://scripts/main.tscn")

func _on_explore_point_pressed(explore_id: String):
	if not map_config.has("world"):
		return
	var explore_data: Dictionary = {}
	for p in map_config.world.points:
		if p.get("id") == explore_id and p.get("type") == "explore":
			explore_data = p
			break
	if explore_data.is_empty():
		return
	sidebar_title.text = explore_data.get("name", "探索区")
	var intro = explore_data.get("intro", "")
	sidebar_description.text = intro
	# 修改：存储当前选中的探索点ID
	current_explore_id = explore_id
	_show_sidebar()

func _on_enter_explore():
	get_tree().change_scene_to_file("res://scenes/explore_scene.tscn")

func _on_backdrop_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sidebar_panel.visible:
			var local = sidebar_panel.get_local_mouse_position()
			var rect = Rect2(Vector2.ZERO, sidebar_panel.size)
			if not rect.has_point(local):
				_hide_sidebar()

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始拖动
				is_dragging = true
				drag_start_pos = event.global_position
			else:
				# 结束拖动
				is_dragging = false
				if sidebar_panel.visible:
					var local = sidebar_panel.get_local_mouse_position()
					var rect = Rect2(Vector2.ZERO, sidebar_panel.size)
					if not rect.has_point(local):
						_hide_sidebar()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_change_zoom(1.1, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_change_zoom(1.0/1.1, get_global_mouse_position())
	elif event is InputEventMagnifyGesture:
		_change_zoom(event.factor, get_global_mouse_position())
	elif event is InputEventMouseMotion and is_dragging:
		# 拖动地图
		var drag_delta = drag_start_pos - event.global_position
		canvas_offset += drag_delta
		drag_start_pos = event.global_position
		_update_canvas_position()
	
	# 处理触摸输入
	_handle_touch_input(event)

func _handle_touch_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed:
			# 触摸开始，记录触摸点
			if not touch_ids.has(event.index):
				touch_ids.append(event.index)
			touch_positions[event.index] = event.position
		else:
			# 触摸结束，移除触摸点
			if touch_ids.has(event.index):
				touch_ids.erase(event.index)
			if touch_positions.has(event.index):
				touch_positions.erase(event.index)
		
		# 当有两个触摸点时，记录初始距离用于缩放
		if touch_ids.size() == 2:
			var touch_points = _get_touch_points()
			if touch_points.size() == 2:
				touch_zoom_start_distance = touch_points[0].distance_to(touch_points[1])
				touch_zoom_start_zoom = zoom
		elif touch_ids.size() < 2:
			# 少于两个触摸点，重置缩放状态
			touch_zoom_start_distance = 0.0
	
	elif event is InputEventScreenDrag:
		# 更新触摸点位置
		touch_positions[event.index] = event.position
		
		# 单指拖动
		if touch_ids.size() == 1:
			if is_dragging:
				var drag_delta = drag_start_pos - event.position
				canvas_offset += drag_delta
				drag_start_pos = event.position
				_update_canvas_position()
			else:
				# 开始拖动
				is_dragging = true
				drag_start_pos = event.position
		
		# 双指缩放
		elif touch_ids.size() == 2:
			var touch_points = _get_touch_points()
			if touch_points.size() == 2 and touch_zoom_start_distance > 0:
				var current_distance = touch_points[0].distance_to(touch_points[1])
				var zoom_factor = current_distance / touch_zoom_start_distance
				var new_zoom = clamp(touch_zoom_start_zoom * zoom_factor, MIN_ZOOM, MAX_ZOOM)
				
				# 计算双指中心点作为缩放焦点
				var focus_point = (touch_points[0] + touch_points[1]) / 2.0
				_change_zoom(new_zoom / zoom, focus_point)

func _get_touch_points() -> Array:
	var points = []
	for touch_id in touch_ids:
		if touch_positions.has(touch_id):
			points.append(touch_positions[touch_id])
	return points

func _change_zoom(factor: float, focus_point: Vector2):
	var old_zoom = zoom
	zoom = clamp(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if abs(zoom - old_zoom) < 0.001:
		return
	
	# 保存焦点在视图中的相对位置
	var local_focus = focus_point - global_position
	var focus_canvas_x = canvas_offset.x + local_focus.x
	var focus_canvas_y = canvas_offset.y + local_focus.y
	
	# 计算焦点在画布内容上的位置比例
	var fx = focus_canvas_x / (base_canvas_size.x * old_zoom)
	var fy = focus_canvas_y / (base_canvas_size.y * old_zoom)
	
	# 应用缩放
	_apply_zoom()
	
	# 调整偏移量以保持焦点位置不变
	canvas_offset.x = fx * base_canvas_size.x * zoom - local_focus.x
	canvas_offset.y = fy * base_canvas_size.y * zoom - local_focus.y
	
	_update_canvas_position()

func _apply_zoom(initial: bool = false):
	# 使用scale来实现缩放
	canvas.scale = Vector2(zoom, zoom)
	
	# 更新点位位置（由于使用scale，位置会自动缩放）
	for entry in point_nodes:
		var n = entry.node
		var base_pos = entry.pos
		n.position = base_pos  # 位置会自动被canvas的scale影响

	_update_canvas_position()

func _process(_delta):
	if coord_label:
		var p = get_global_mouse_position() - global_position
		var content = canvas_offset + p
		var base_pos = content / zoom
		var center = base_canvas_size / 2.0
		var rel = base_pos - center
		coord_label.text = str(int(rel.x)) + ", " + str(int(rel.y))

func _init_sidebar_style():
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sidebar_panel.custom_minimum_size = Vector2(320, 400)
	sidebar_panel.add_theme_stylebox_override("panel", sb)

func _show_sidebar():
	sidebar_panel.visible = true
	sidebar_panel.modulate.a = 0.0
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(sidebar_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hide_sidebar():
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(sidebar_panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	sidebar_panel.visible = false

func _get_world_point_pos(id: String) -> Vector2:
	if not map_config.has("world"):
		return Vector2.ZERO
	var center_x = base_canvas_size.x / 2.0
	var center_y = base_canvas_size.y / 2.0
	for p in map_config.world.points:
		if p.get("id") == id:
			return Vector2(center_x + p.get("x", 0), center_y + p.get("y", 0))
	return Vector2.ZERO
func _switch_to_world(center_on_base: bool):
	_init_background_for_world()
	_build_world_points()
	current_level = "world"
	current_base_id = ""
	force_world_mode = true
	close_button.text = "关闭"
	sidebar_panel.visible = false
	if center_on_base and current_base_data and current_base_data.has("x") and current_base_data.has("y"):
		var visible_size = get_viewport_rect().size
		var center_x = base_canvas_size.x / 2.0
		var center_y = base_canvas_size.y / 2.0
		var pos = Vector2(center_x + current_base_data.x, center_y + current_base_data.y)
		_center_on_point(pos)
	else:
		var visible_size2 = get_viewport_rect().size
		var center2 = base_canvas_size * zoom / 2.0
		canvas_offset = center2 - visible_size2 / 2.0
		_update_canvas_position()
	_apply_zoom(true)

func _center_on_point(pos: Vector2):
	var visible_size = get_viewport_rect().size
	var target = pos * zoom - visible_size / 2.0
	canvas_offset = target
	_update_canvas_position()

func _find_base_for_scene(scene_id: String) -> String:
	if not map_config.has("world"):
		return ""
	for p in map_config.world.points:
		if p.get("type") == "base":
			var children = p.get("children", [])
			for c in children:
				if c.get("id") == scene_id:
					current_base_data = p
					return p.get("id")
	return ""