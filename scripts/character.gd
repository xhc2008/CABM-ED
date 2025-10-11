extends TextureButton

signal character_clicked

var current_scene: String = ""
var original_position: Vector2
var original_scale: float
var is_chatting: bool = false

# 聊天状态的配置
const CHAT_POSITION_RATIO = Vector2(0.5, 0.4)
const CHAT_SCALE = 0.8

func _ready():
	pressed.connect(_on_pressed)

func load_character_for_scene(scene_id: String):
	current_scene = scene_id
	
	# 加载预设配置
	var config_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(config_path):
		print("角色配置文件不存在")
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("解析角色配置失败")
		return
	
	var config = json.data
	if not config.has(scene_id):
		print("场景 %s 没有角色配置" % scene_id)
		visible = false
		return
	
	var presets = config[scene_id]
	if presets.size() == 0:
		visible = false
		return
	
	# 随机选择一个预设
	var preset = presets[randi() % presets.size()]
	
	# 加载角色图片
	var image_path = "res://assets/images/character/%s/%s" % [scene_id, preset.image]
	if ResourceLoader.exists(image_path):
		texture_normal = load(image_path)
		
		# 设置位置和缩放
		var viewport_size = get_viewport_rect().size
		original_position = Vector2(
			preset.position.x * viewport_size.x,
			preset.position.y * viewport_size.y
		)
		original_scale = preset.scale
		
		position = original_position
		scale = Vector2(original_scale, original_scale)
		
		# 调整pivot以便缩放时居中
		pivot_offset = texture_normal.get_size() / 2
		
		visible = true
		print("角色已加载: ", image_path)
	else:
		print("角色图片不存在: ", image_path)
		visible = false

func start_chat():
	if is_chatting:
		return
	
	is_chatting = true
	
	# 加载聊天图片
	var chat_image_path = "res://assets/images/character/chat/normal.png"
	if ResourceLoader.exists(chat_image_path):
		texture_normal = load(chat_image_path)
	
	# 移动到屏幕中央
	var viewport_size = get_viewport_rect().size
	var target_position = Vector2(
		CHAT_POSITION_RATIO.x * viewport_size.x,
		CHAT_POSITION_RATIO.y * viewport_size.y
	)
	
	# 创建移动动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_position, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(CHAT_SCALE, CHAT_SCALE), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func end_chat():
	if not is_chatting:
		return
	
	is_chatting = false
	
	# 重新加载场景中的随机位置
	load_character_for_scene(current_scene)
	
	# 创建返回动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", original_position, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(original_scale, original_scale), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_pressed():
	if not is_chatting:
		character_clicked.emit()
