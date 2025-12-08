extends Node
class_name SceneManager

# 场景管理器 - 负责场景加载、切换和验证

signal scene_loaded(scene_id: String, weather_id: String, time_id: String)

var scenes_config: Dictionary = {}
var current_scene: String = ""
var current_weather: String = ""
var current_time: String = "day"

# 场景区域信息
var scene_rect: Rect2 = Rect2()
var scene_scale: Vector2 = Vector2.ONE

# 引用
var background: TextureRect
var character
var save_manager

func initialize(bg: TextureRect, character_node, save_mgr):
	"""初始化管理器"""
	background = bg
	character = character_node
	save_manager = save_mgr
	_load_scenes_config()

func _load_scenes_config():
	"""加载场景配置"""
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

func load_initial_scene() -> String:
	"""从存档加载初始场景，如果没有或不合法则返回默认场景"""
	if save_manager:
		var saved_scene = save_manager.get_character_scene()
		
		if saved_scene != "" and is_valid_scene(saved_scene):
			print("从存档加载场景: ", saved_scene)
			return saved_scene
		elif saved_scene != "":
			print("警告: 存档中的场景 '%s' 不合法，使用默认场景" % saved_scene)
			save_manager.set_character_scene("")
	
	print("使用默认场景: livingroom")
	return "livingroom"

func is_valid_scene(scene_id: String) -> bool:
	"""验证场景ID是否合法"""
	if not scenes_config.has(scene_id):
		print("场景验证失败: '%s' 不在 scenes.json 中" % scene_id)
		return false
	
	var costume_id = "default"
	if save_manager:
		costume_id = save_manager.get_costume_id()
	
	var presets_path = "res://config/character_presets/%s.json" % costume_id
	if not FileAccess.file_exists(presets_path):
		print("场景验证失败: character_presets.json 不存在")
		return false
	
	var file = FileAccess.open(presets_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("场景验证失败: 服装配置 %s 解析错误" % costume_id)
		return false
	
	var presets_config = json.data
	if not presets_config.has(scene_id):
		print("场景验证失败: '%s' 不在服装 %s 的配置中" % [scene_id, costume_id])
		return false
	
	if not presets_config[scene_id] is Array:
		print("场景验证失败: '%s' 在服装 %s 中不是有效的场景配置" % [scene_id, costume_id])
		return false
	
	if presets_config[scene_id].size() == 0:
		print("场景验证失败: '%s' 在服装 %s 中没有角色预设" % [scene_id, costume_id])
		return false
	
	return true

func load_scene(scene_id: String, weather_id: String, time_id: String):
	"""加载场景"""
	var scene_changed = (current_scene != scene_id)
	
	current_scene = scene_id
	current_weather = weather_id
	current_time = time_id
	
	if save_manager:
		save_manager.set_current_weather(weather_id)
		save_manager.set_current_time(time_id)
	
	var image_path = "user://resources/scenes/%s/%s/%s.png" % [scene_id, weather_id, time_id]
	
	var img = Image.new()
	var err = img.load(image_path)
	if err == OK:
		var tex = ImageTexture.create_from_image(img)
		background.texture = tex
		print("已加载: ", image_path)
	else:
		print("图片不存在: ", image_path)
		background.texture = null
	
	await background.get_tree().process_frame
	await background.get_tree().process_frame
	
	calculate_scene_rect()
	
	if scene_changed and character:
		character.load_character_for_scene(scene_id)
	
	scene_loaded.emit(scene_id, weather_id, time_id)

func calculate_scene_rect():
	"""计算场景图片在屏幕上的实际显示区域"""
	if background.texture == null:
		scene_rect = Rect2(Vector2.ZERO, background.get_viewport_rect().size)
		scene_scale = Vector2.ONE
		return
	
	var texture_size = background.texture.get_size()
	var container_size = background.size
	
	var scale_x = container_size.x / texture_size.x
	var scale_y = container_size.y / texture_size.y
	var img_scale = min(scale_x, scale_y)
	
	scene_scale = Vector2(img_scale, img_scale)
	
	var scaled_size = texture_size * img_scale
	var offset = (container_size - scaled_size) / 2.0
	
	scene_rect = Rect2(offset, scaled_size)

func get_scene_name(scene_id: String) -> String:
	"""获取场景名称"""
	if scenes_config.has(scene_id):
		return scenes_config[scene_id].get("name", scene_id)
	return scene_id

func has_character_in_scene(scene_id: String) -> bool:
	"""检查角色是否在指定场景"""
	if not save_manager:
		return false
	
	var character_scene = save_manager.get_character_scene()
	return character_scene == scene_id
