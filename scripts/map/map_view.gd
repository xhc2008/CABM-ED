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

@onready var scroll: ScrollContainer = $Root/Scroll
@onready var canvas: Control = $Root/Scroll/Canvas
@onready var close_button: Button = $Root/CloseButton

func _ready():
 close_button.pressed.connect(_on_close)
 _load_configs()
 _build_points()
 _center_initial_view()

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
   _apply_zoom(true)

func _build_points():
 if map_config.has("points"):
  for p in map_config.points:
   var id = p.get("id", "")
   var pos = Vector2(p.get("x", 0), p.get("y", 0))
   if id != "" and scenes_config.has(id):
    var scene_data = scenes_config[id]
    var btn = Button.new()
    btn.text = scene_data.get("name", id)
    btn.position = pos * zoom
    btn.pressed.connect(_on_point_pressed.bind(id))
    canvas.add_child(btn)
    point_nodes.append({"node": btn, "pos": pos})
   else:
    var t = p.get("type", "")
    if t == "explore" or id == "explore":
     var eb = Button.new()
     eb.text = p.get("name", "探索区")
     eb.position = pos * zoom
     eb.pressed.connect(_on_explore_point_pressed)
     canvas.add_child(eb)
     point_nodes.append({"node": eb, "pos": pos})

func _center_initial_view():
 var size = canvas.custom_minimum_size
 var vp = scroll.size
 var center = Vector2(size.x/2.0, size.y/2.0)
 var offset = center - vp/2.0
 scroll.scroll_horizontal = int(max(0.0, offset.x))
 scroll.scroll_vertical = int(max(0.0, offset.y))

func _on_point_pressed(scene_id: String):
 var data = scenes_config.get(scene_id, {})
 var cls = data.get("class", "")
 var go = true
 if on_go_selected and on_go_selected.is_valid():
  on_go_selected.call(scene_id)
  return
 if cls == "outdoor":
  get_tree().change_scene_to_file("res://scenes/explore_scene.tscn")
 else:
  if has_node("/root/SaveManager"):
   var sm = get_node("/root/SaveManager")
   sm.set_character_scene(scene_id)
  get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_explore_point_pressed():
 get_tree().change_scene_to_file("res://scenes/explore_scene.tscn")

func _input(event: InputEvent):
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
   _change_zoom(1.1)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
   _change_zoom(1.0/1.1)
 elif event is InputEventMagnifyGesture:
  _change_zoom(event.factor)
 elif event is InputEventPanGesture:
  _pan_by(event.delta)

func _change_zoom(factor: float):
 var old_zoom = zoom
 zoom = clamp(zoom * factor, MIN_ZOOM, MAX_ZOOM)
 if abs(zoom - old_zoom) < 0.001:
  return
 var old_size = canvas.custom_minimum_size
 _apply_zoom()
 var new_size = canvas.custom_minimum_size
 var global_mouse = get_global_mouse_position()
 var local_focus = global_mouse - scroll.global_position
 local_focus.x = clamp(local_focus.x, 0.0, scroll.size.x)
 local_focus.y = clamp(local_focus.y, 0.0, scroll.size.y)
 var hx = float(scroll.scroll_horizontal)
 var hy = float(scroll.scroll_vertical)
 var fx = (hx + local_focus.x) / max(1.0, old_size.x)
 var fy = (hy + local_focus.y) / max(1.0, old_size.y)
 scroll.scroll_horizontal = int(fx * new_size.x - local_focus.x)
 scroll.scroll_vertical = int(fy * new_size.y - local_focus.y)
 _clamp_scroll()

func _apply_zoom(initial: bool = false):
 canvas.custom_minimum_size = base_canvas_size * zoom
 # 背景图填充由锚定自动处理
 # 更新点位位置以匹配缩放
 for entry in point_nodes:
  var n = entry.node
  var p = entry.pos
  n.position = p * zoom
 _clamp_scroll()

func _pan_by(delta: Vector2):
 var nx = float(scroll.scroll_horizontal) - delta.x
 var ny = float(scroll.scroll_vertical) - delta.y
 scroll.scroll_horizontal = int(nx)
 scroll.scroll_vertical = int(ny)
 _clamp_scroll()

func _clamp_scroll():
 var max_x = max(0.0, canvas.custom_minimum_size.x - scroll.size.x)
 var max_y = max(0.0, canvas.custom_minimum_size.y - scroll.size.y)
 scroll.scroll_horizontal = int(clamp(float(scroll.scroll_horizontal), 0.0, max_x))
 scroll.scroll_vertical = int(clamp(float(scroll.scroll_vertical), 0.0, max_y))