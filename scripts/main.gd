extends Control

@onready var background: TextureRect = $Background
@onready var sidebar = $Sidebar

var current_scene: String = ""
var current_weather: String = ""
var current_time: String = "day"

func _ready():
	# 连接侧边栏信号
	sidebar.scene_changed.connect(_on_scene_changed)
	
	# 加载默认场景
	load_scene("livingroom", "sunny", "day")

func load_scene(scene_id: String, weather_id: String, time_id: String):
	current_scene = scene_id
	current_weather = weather_id
	current_time = time_id
	
	var image_path = "res://assets/images/%s/%s/%s.png" % [scene_id, weather_id, time_id]
	
	# 尝试加载图片
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		background.texture = texture
		print("已加载: ", image_path)
	else:
		print("图片不存在: ", image_path)
		# 显示占位符
		background.texture = null

func _on_scene_changed(scene_id: String, weather_id: String):
	load_scene(scene_id, weather_id, current_time)
