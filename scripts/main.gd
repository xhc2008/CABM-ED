extends Control

@onready var background: TextureRect = $Background
@onready var sidebar = $Sidebar
@onready var character = $Background/Character
@onready var chat_dialog = $ChatDialog
@onready var action_menu = $ActionMenu
@onready var debug_helper = $CharacterDebugHelper

var current_scene: String = ""
var current_weather: String = ""
var current_time: String = "day"

func _ready():
	# 连接侧边栏信号
	sidebar.scene_changed.connect(_on_scene_changed)
	
	# 连接角色信号
	character.character_clicked.connect(_on_character_clicked)
	character.set_background_reference(background)
	
	# 连接聊天对话框信号
	chat_dialog.chat_ended.connect(_on_chat_ended)
	
	# 连接选项菜单信号
	action_menu.action_selected.connect(_on_action_selected)
	
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
	
	# 加载角色到新场景
	character.load_character_for_scene(scene_id)

func _on_scene_changed(scene_id: String, weather_id: String, time_id: String):
	load_scene(scene_id, weather_id, time_id)

func _on_character_clicked(char_position: Vector2, char_size: Vector2):
	# 角色被点击，显示选项菜单
	# 计算菜单位置（角色右侧）
	var menu_pos = Vector2(
		char_position.x + char_size.x + 10,
		char_position.y
	)
	
	# 确保菜单不超出屏幕
	if menu_pos.x + action_menu.custom_minimum_size.x > get_viewport_rect().size.x:
		# 如果右侧放不下，放在左侧
		menu_pos.x = char_position.x - action_menu.custom_minimum_size.x - 10
	
	action_menu.show_menu(menu_pos)

func _on_action_selected(action: String):
	if action == "chat":
		# 开始聊天
		character.start_chat()
		chat_dialog.show_dialog()

func _on_chat_ended():
	# 聊天结束，角色返回场景
	character.end_chat()
