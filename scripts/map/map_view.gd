extends Control

signal map_closed
signal go_selected(scene_id: String)

var on_go_selected: Callable
var scenes_config: Dictionary = {}
var map_config: Dictionary = {}
var zoom: float = 1.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
var base_canvas_size: Vector2 = Vector2(2000, 1200)
var point_nodes: Array = [] # [{node: Button, pos: Vector2}]

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

func _ready():
	close_button.pressed.connect(_on_close)
	_load_configs()
	_build_points()
	
	# 等待一帧确保所有节点已就绪
	await get_tree().process_frame
	
	_center_initial_view()
	_apply_zoom(true)

func _on_close():
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
		# 更新基础画布大小为实际图片大小
		base_canvas_size = texture_size
		print("Background size set to: ", texture_size)

func _build_points():
	if map_config.has("points"):
		for p in map_config.points:
			var id = p.get("id", "")
			# 将基于中心的偏移量转换为绝对坐标
			var offset_x = p.get("x", 0)
			var offset_y = p.get("y", 0)
			var center_x = base_canvas_size.x / 2.0
			var center_y = base_canvas_size.y / 2.0
			var pos = Vector2(center_x + offset_x, center_y + offset_y)
			
			if id != "" and scenes_config.has(id):
				var scene_data = scenes_config[id]
				var btn = Button.new()
				btn.text = scene_data.get("name", id)
				btn.position = pos
				btn.pressed.connect(_on_point_pressed.bind(id))
				canvas.add_child(btn)
				point_nodes.append({"node": btn, "pos": pos})
			else:
				var t = p.get("type", "")
				if t == "explore" or id == "explore":
					var eb = Button.new()
					eb.text = p.get("name", "探索区")
					eb.position = pos
					eb.pressed.connect(_on_explore_point_pressed)
					canvas.add_child(eb)
					point_nodes.append({"node": eb, "pos": pos})

func _center_initial_view():
	var visible_size = get_viewport_rect().size
	var center = base_canvas_size * zoom / 2.0
	canvas_offset = center - visible_size / 2.0
	_update_canvas_position()

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
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_explore_point_pressed():
	get_tree().change_scene_to_file("res://scenes/explore_scene.tscn")

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