extends Control

@onready var background: TextureRect = $Background
@onready var sidebar = $Sidebar
@onready var character = $Background/Character
@onready var chat_dialog = $ChatDialog
@onready var action_menu = $ActionMenu
@onready var scene_menu = $SceneMenu
@onready var right_click_area = $Background/RightClickArea
@onready var debug_helper = $CharacterDebugHelper
@onready var audio_manager = $AudioManager

var current_scene: String = ""
var current_weather: String = ""
var current_time: String = "day"
var scenes_config: Dictionary = {}

# 场景区域信息
var scene_rect: Rect2 = Rect2()
var scene_scale: Vector2 = Vector2.ONE

func _ready():
	# 加载场景配置
	_load_scenes_config()
	
	# 连接侧边栏信号
	sidebar.scene_changed.connect(_on_scene_changed)
	
	# 连接角色信号
	character.character_clicked.connect(_on_character_clicked)
	character.set_background_reference(background)
	
	# 连接聊天对话框信号
	chat_dialog.chat_ended.connect(_on_chat_ended)
	
	# 连接选项菜单信号
	action_menu.action_selected.connect(_on_action_selected)
	
	# 连接场景菜单信号
	scene_menu.scene_selected.connect(_on_scene_menu_selected)
	
	# 连接右侧点击区域
	right_click_area.gui_input.connect(_on_right_area_input)
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 加载默认场景
	load_scene("livingroom", "sunny", "day")
	
	# 初始化UI布局
	await get_tree().process_frame
	_update_ui_layout()
	
	# 播放背景音乐
	audio_manager.play_background_music("livingroom", "day", "sunny")

func _load_scenes_config():
	var config_path = "res://config/scenes.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var data = json.data
			scenes_config = data.get("scenes", {})
			print("场景配置已加载: ", scenes_config.keys())
		else:
			print("解析场景配置失败")
	else:
		print("场景配置文件不存在")

func _process(_delta):
	# 持续更新场景区域信息
	_calculate_scene_rect()
	
	# 如果聊天框可见，持续更新其位置（因为高度可能在动画中变化）
	if chat_dialog.visible:
		_update_chat_dialog_layout()

func _calculate_scene_rect():
	"""计算场景图片在屏幕上的实际显示区域"""
	if background.texture == null:
		scene_rect = Rect2(Vector2.ZERO, get_viewport_rect().size)
		scene_scale = Vector2.ONE
		return
	
	var texture_size = background.texture.get_size()
	var container_size = background.size
	
	# 根据 stretch_mode = 5 (keep aspect centered) 计算实际显示区域
	var scale_x = container_size.x / texture_size.x
	var scale_y = container_size.y / texture_size.y
	var img_scale = min(scale_x, scale_y)
	
	scene_scale = Vector2(img_scale, img_scale)
	
	var scaled_size = texture_size * img_scale
	var offset = (container_size - scaled_size) / 2.0
	
	scene_rect = Rect2(offset, scaled_size)

func _on_viewport_size_changed():
	"""窗口大小变化时更新UI布局"""
	_update_ui_layout()

func _update_ui_layout():
	"""更新所有UI组件的位置和大小，使其与场景绑定"""
	_calculate_scene_rect()
	
	# 更新侧边栏 - 固定在场景左侧
	_update_sidebar_layout()
	
	# 更新聊天对话框 - 固定在场景底部
	_update_chat_dialog_layout()
	
	# 如果动作菜单可见，更新其位置
	if action_menu.visible:
		_update_action_menu_position()

func _update_sidebar_layout():
	"""更新侧边栏布局，使其与场景左侧对齐"""
	sidebar.position = scene_rect.position
	sidebar.size.y = scene_rect.size.y
	sidebar.custom_minimum_size.y = scene_rect.size.y

func _update_chat_dialog_layout():
	"""更新聊天对话框布局，使其与场景底部对齐"""
	# 使用实际size而不是custom_minimum_size，因为在动画过程中size会实时变化
	var dialog_height = chat_dialog.size.y
	
	# 计算侧边栏的实际宽度
	var sidebar_width = sidebar.size.x if sidebar.visible else 0.0
	
	# 聊天框从侧边栏右侧开始，到场景右侧结束
	var dialog_x = scene_rect.position.x + sidebar_width
	var dialog_width = scene_rect.size.x - sidebar_width
	
	# 确保聊天框不会超出场景范围
	if dialog_x + dialog_width > scene_rect.position.x + scene_rect.size.x:
		dialog_width = scene_rect.position.x + scene_rect.size.x - dialog_x
	
	# 聊天框底部对齐场景底部
	var dialog_y = scene_rect.position.y + scene_rect.size.y - dialog_height
	
	# 确保不会超出场景顶部
	if dialog_y < scene_rect.position.y:
		dialog_y = scene_rect.position.y
	
	chat_dialog.position = Vector2(dialog_x, dialog_y)
	chat_dialog.size.x = dialog_width
	chat_dialog.custom_minimum_size.x = dialog_width

func _update_action_menu_position():
	"""更新动作菜单位置，确保在场景范围内"""
	var menu_pos = action_menu.position
	
	# 确保菜单在场景范围内
	if menu_pos.x + action_menu.size.x > scene_rect.position.x + scene_rect.size.x:
		menu_pos.x = scene_rect.position.x + scene_rect.size.x - action_menu.size.x - 10
	
	if menu_pos.x < scene_rect.position.x:
		menu_pos.x = scene_rect.position.x + 10
	
	if menu_pos.y + action_menu.size.y > scene_rect.position.y + scene_rect.size.y:
		menu_pos.y = scene_rect.position.y + scene_rect.size.y - action_menu.size.y - 10
	
	if menu_pos.y < scene_rect.position.y:
		menu_pos.y = scene_rect.position.y + 10
	
	action_menu.position = menu_pos

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
	
	# 场景变化后更新UI布局
	await get_tree().process_frame
	_update_ui_layout()
	
	# 切换背景音乐
	audio_manager.play_background_music(scene_id, time_id, weather_id)

func _on_scene_changed(scene_id: String, weather_id: String, time_id: String):
	load_scene(scene_id, weather_id, time_id)

func _on_scene_menu_selected(scene_id: String):
	# 切换到选中的场景，保持当前天气和时间
	load_scene(scene_id, current_weather, current_time)
	# 更新侧边栏显示的场景
	sidebar.set_current_scene(scene_id)

func _on_character_clicked(char_position: Vector2, char_size: Vector2):
	# 角色被点击，显示选项菜单
	# 将角色位置转换为场景坐标
	var scene_char_pos = scene_rect.position + char_position
	
	# 计算菜单位置（角色右侧）
	var menu_pos = Vector2(
		scene_char_pos.x + char_size.x + 10,
		scene_char_pos.y
	)
	
	# 确保菜单不超出场景范围
	var scene_right = scene_rect.position.x + scene_rect.size.x
	var scene_bottom = scene_rect.position.y + scene_rect.size.y
	
	if menu_pos.x + action_menu.custom_minimum_size.x > scene_right:
		# 如果右侧放不下，放在左侧
		menu_pos.x = scene_char_pos.x - action_menu.custom_minimum_size.x - 10
	
	# 确保不超出场景底部
	if menu_pos.y + action_menu.size.y > scene_bottom:
		menu_pos.y = scene_bottom - action_menu.size.y - 10
	
	# 确保不超出场景顶部和左侧
	menu_pos.x = max(menu_pos.x, scene_rect.position.x + 10)
	menu_pos.y = max(menu_pos.y, scene_rect.position.y + 10)
	
	action_menu.show_menu(menu_pos)

func _on_action_selected(action: String):
	if action == "chat":
		# 开始聊天
		character.start_chat()
		chat_dialog.show_dialog()

func _on_chat_ended():
	# 聊天结束，角色返回场景
	character.end_chat()

func _on_right_area_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos = event.position
			
			# 检查是否点击在场景右侧区域（右侧1/4）
			var right_threshold = scene_rect.position.x + scene_rect.size.x * 0.75
			
			if click_pos.x >= right_threshold and scene_rect.has_point(click_pos):
				# 点击在右侧区域，显示场景切换菜单
				_show_scene_menu(click_pos)

func _show_scene_menu(at_position: Vector2):
	# 设置场景菜单
	scene_menu.setup_scenes(scenes_config, current_scene)
	
	# 计算菜单位置（点击位置左侧）
	await get_tree().process_frame  # 等待菜单大小更新
	
	var menu_pos = Vector2(
		at_position.x - scene_menu.size.x - 10,
		at_position.y
	)
	
	# 确保菜单在场景范围内
	var scene_bottom = scene_rect.position.y + scene_rect.size.y
	
	menu_pos.x = max(menu_pos.x, scene_rect.position.x + 10)
	menu_pos.y = max(menu_pos.y, scene_rect.position.y + 10)
	
	if menu_pos.y + scene_menu.size.y > scene_bottom:
		menu_pos.y = scene_bottom - scene_menu.size.y - 10
	
	scene_menu.show_menu(menu_pos)
