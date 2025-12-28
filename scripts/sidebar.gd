extends Panel

signal scene_changed(scene_id: String, weather_id: String, time_id: String)

@onready var scene_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SceneList
@onready var toggle_button: Button = $ToggleButton

var is_expanded: bool = false # 默认收起
var collapsed_width: float = 50.0
var expanded_width: float = 320.0

# 场景配置
var scenes = {
	"livingroom": {
		"name": "客厅",
		"times": {
			"day": "白天",
			"dusk": "黄昏",
			"night": "夜晚"
		},
		"weathers": {
			"sunny": "晴天",
			"rainy": "雨天",
			"storm": "雷雨"
		}
	}
}

var current_scene_id: String = "livingroom"
var current_time_id: String = "day"
var current_weather_id: String = ""  # 将从存档加载
var auto_time_enabled: bool = true # 默认开启自动调整时间
var clock_label: Label
var auto_checkbox: CheckBox
var time_update_timer: Timer
var time_buttons = {}
var weather_buttons = {}

# 角色数据显示标签
var affection_label: Label
var willingness_label: Label
var mood_label: Label
var character_location_label: Label

# 用户名输入框
var user_name_input: LineEdit

# 自动保存定时器
var auto_save_timer: Timer

func _ready():
	toggle_button.pressed.connect(_on_toggle_pressed)
	_load_scenes_config()
	
	# 从存档加载天气
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		var saved_weather = save_mgr.get_current_weather()
		if saved_weather != "":
			current_weather_id = saved_weather
			print("从存档加载天气: ", current_weather_id)
		else:
			current_weather_id = "sunny"  # 默认值
	else:
		current_weather_id = "sunny"  # 默认值
	
	# 如果启用了自动时间，在构建UI之前先调整时间
	if auto_time_enabled:
		var time_dict = Time.get_time_dict_from_system()
		var time_id = _get_time_period_from_hour(time_dict["hour"])
		current_time_id = time_id
		print("初始化自动时间: ", time_id)
	
	_setup_clock_and_auto()
	_build_scene_list()
	
	# 设置初始状态为收起
	custom_minimum_size.x = collapsed_width
	size.x = collapsed_width
	toggle_button.text = "▶"
	$MarginContainer.visible = false
	
	# 启动时钟更新定时器
	time_update_timer = Timer.new()
	time_update_timer.wait_time = 1.0
	time_update_timer.timeout.connect(_update_clock)
	add_child(time_update_timer)
	time_update_timer.start()
	_update_clock()
	
	# 启动自动保存定时器（每5分钟保存一次）
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 300.0 # 5分钟
	auto_save_timer.timeout.connect(_on_auto_save)
	add_child(auto_save_timer)
	auto_save_timer.start()
	
	# 立即连接SaveManager信号（不等待），确保不会错过任何信号
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.affection_changed.connect(_update_character_stats)
		save_mgr.willingness_changed.connect(_update_character_stats)
		save_mgr.mood_changed.connect(_update_character_stats)
		save_mgr.energy_changed.connect(_update_character_stats)
		# 监听角色场景变化
		if save_mgr.has_signal("character_scene_changed"):
			save_mgr.character_scene_changed.connect(_update_character_stats)
	
	# 等待自动加载节点准备好
	await get_tree().process_frame
	
	# 监听AI服务的字段提取信号以实时更新
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		ai_service.chat_fields_extracted.connect(_on_ai_fields_updated)
	
	# 强制刷新一次角色状态显示，确保启动时显示正确
	_update_character_stats()

func _setup_clock_and_auto():
	# 在场景列表顶部添加时钟和自动选项
	var header_container = VBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	
	# 电子时钟
	clock_label = Label.new()
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	header_container.add_child(clock_label)
	
	# 自动时间勾选框（隐藏）
	var auto_container = HBoxContainer.new()
	auto_container.alignment = BoxContainer.ALIGNMENT_CENTER
	auto_container.visible = false # 隐藏调试元素
	auto_checkbox = CheckBox.new()
	auto_checkbox.text = "自动调整时间"
	auto_checkbox.button_pressed = true # 默认勾选
	auto_checkbox.toggled.connect(_on_auto_time_toggled)
	auto_container.add_child(auto_checkbox)
	header_container.add_child(auto_container)
	
	# 分隔线
	var separator1 = HSeparator.new()
	header_container.add_child(separator1)
	
	# 用户名编辑（隐藏）
	var user_name_label = Label.new()
	user_name_label.text = "用户名:"
	user_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	user_name_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	user_name_label.visible = false # 隐藏调试元素
	header_container.add_child(user_name_label)
	
	user_name_input = LineEdit.new()
	user_name_input.text = _load_user_name()
	user_name_input.placeholder_text = "输入用户名"
	user_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	user_name_input.text_changed.connect(_on_user_name_changed)
	user_name_input.visible = false # 隐藏调试元素
	header_container.add_child(user_name_input)
	
	# 分隔线（隐藏）
	var separator_user = HSeparator.new()
	separator_user.visible = false # 隐藏调试元素
	header_container.add_child(separator_user)
	
	# 角色数据显示
	var stats_label = Label.new()
	stats_label.text = "角色状态"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	header_container.add_child(stats_label)
	
	# 角色位置
	character_location_label = Label.new()
	character_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_location_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	header_container.add_child(character_location_label)
	
	# 好感度
	affection_label = Label.new()
	affection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(affection_label)
	
	# 交互意愿
	willingness_label = Label.new()
	willingness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(willingness_label)
	
	# 心情
	mood_label = Label.new()
	mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(mood_label)
	
	# 更新数据显示
	_update_character_stats()
	
	# 分隔线
	var separator2 = HSeparator.new()
	header_container.add_child(separator2)
	
	# AI 设置区域
	_setup_ai_settings(header_container)
	
	# 插入到场景列表顶部
	scene_list.add_child(header_container)
	scene_list.move_child(header_container, 0)

func _update_clock():
	var time_dict = Time.get_time_dict_from_system()
	var hour = time_dict["hour"]
	var minute = time_dict["minute"]
	var second = time_dict["second"]
	
	clock_label.text = "%02d:%02d:%02d" % [hour, minute, second]
	
	# 如果启用自动时间，更新时间段
	if auto_time_enabled:
		_auto_adjust_time_period(hour)

func _auto_adjust_time_period(hour: int):
	var time_id = _get_time_period_from_hour(hour)
	
	# 更新当前时间选择
	if current_time_id != time_id:
		current_time_id = time_id
		_update_button_states()
		_emit_scene_change()

func _get_time_period_from_hour(hour: int) -> String:
	# 7:00-17:59 = 白天 (day)
	# 17:00-18:59 = 黄昏 (dusk)
	# 20:00-3:59 = 夜晚 (night)
	# 4:00-6:59 (凌晨) = 黄昏 (dusk)
	if hour >= 4 and hour < 7:
		return "dusk" # 凌晨算作黄昏
	elif hour >= 7 and hour < 17:
		return "day"
	elif hour >= 17 and hour < 19:
		return "dusk"
	else:
		return "night"

func _on_auto_time_toggled(enabled: bool):
	auto_time_enabled = enabled
	
	if enabled:
		# 立即更新一次时间
		var time_dict = Time.get_time_dict_from_system()
		_auto_adjust_time_period(time_dict["hour"])

func _load_scenes_config():
	var config_path = "res://config/scenes.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			if data.has("scenes"):
				scenes = data["scenes"]
				# 为每个场景添加通用的 times 和 weathers
				var common_times = data.get("times", {})
				var common_weathers = data.get("weathers", {})
				for scene_id in scenes:
					if not scenes[scene_id].has("times"):
						scenes[scene_id]["times"] = common_times
					if not scenes[scene_id].has("weathers"):
						scenes[scene_id]["weathers"] = common_weathers

func _build_scene_list():
	# 清空现有列表（保留时钟和自动选项）
	var children_to_remove = []
	for child in scene_list.get_children():
		# 跳过第一个子节点（时钟和自动选项容器）
		if child != scene_list.get_child(0):
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
	
	# 清空按钮引用
	time_buttons.clear()
	weather_buttons.clear()
	
	# 只显示当前场景
	if not scenes.has(current_scene_id):
		print("场景 %s 不存在" % current_scene_id)
		return
	
	var scene_data = scenes[current_scene_id]
	
	# 场景标题（隐藏）
	var scene_label = Label.new()
	scene_label.text = "当前场景: " + scene_data["name"]
	scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_label.visible = false # 隐藏调试元素
	scene_list.add_child(scene_label)
	
	# 分隔线（隐藏）
	var separator1 = HSeparator.new()
	separator1.visible = false # 隐藏调试元素
	scene_list.add_child(separator1)
	
	# 时间按钮组（隐藏）
	if scene_data.has("times"):
		var time_label = Label.new()
		time_label.text = "时间"
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.visible = false # 隐藏调试元素
		scene_list.add_child(time_label)
		
		var time_container = VBoxContainer.new()
		time_container.add_theme_constant_override("separation", 5)
		time_container.visible = false # 隐藏调试元素
		for time_id in scene_data["times"]:
			var time_name = scene_data["times"][time_id]
			var button = Button.new()
			button.text = time_name
			button.toggle_mode = true
			button.pressed.connect(_on_time_selected.bind(time_id))
			time_container.add_child(button)
			
			# 保存按钮引用
			time_buttons[time_id] = button
		scene_list.add_child(time_container)
	
	# 分隔线
	var separator2 = HSeparator.new()
	scene_list.add_child(separator2)
	
	# 已移除实验性玩法入口
	
	# 天气按钮组
	if scene_data.has("weathers"):
		var weather_label = Label.new()
		weather_label.text = "天气"
		weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_list.add_child(weather_label)
		
		var weather_container = VBoxContainer.new()
		weather_container.add_theme_constant_override("separation", 5)
		for weather_id in scene_data["weathers"]:
			var weather_name = scene_data["weathers"][weather_id]
			var button = Button.new()
			button.text = weather_name
			button.toggle_mode = true
			button.pressed.connect(_on_weather_selected.bind(weather_id))
			weather_container.add_child(button)
			
			# 保存按钮引用
			weather_buttons[weather_id] = button
		scene_list.add_child(weather_container)
	
	# 初始化按钮状态
	_update_button_states()

func set_current_scene(scene_id: String):
	"""设置当前场景并重建UI"""
	if current_scene_id != scene_id:
		current_scene_id = scene_id
		_build_scene_list()

func _on_time_selected(time_id: String):
	# 手动选择时间时，禁用自动模式
	if auto_time_enabled:
		auto_time_enabled = false
		auto_checkbox.button_pressed = false
	
	current_time_id = time_id
	_update_button_states()
	_emit_scene_change()

func _on_weather_selected(weather_id: String):
	current_weather_id = weather_id
	_update_button_states()
	_emit_scene_change()

func _update_button_states():
	# 更新时间按钮状态
	for time_id in time_buttons:
		time_buttons[time_id].button_pressed = (time_id == current_time_id)
	
	# 更新天气按钮状态
	for weather_id in weather_buttons:
		weather_buttons[weather_id].button_pressed = (weather_id == current_weather_id)

func _emit_scene_change():
	print("选择场景: %s, 天气: %s, 时间: %s" % [current_scene_id, current_weather_id, current_time_id])
	scene_changed.emit(current_scene_id, current_weather_id, current_time_id)

func _on_toggle_pressed():
	is_expanded = !is_expanded
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	if is_expanded:
		tween.tween_property(self, "custom_minimum_size:x", expanded_width, 0.3)
		tween.parallel().tween_property(self, "size:x", expanded_width, 0.3)
		toggle_button.text = "◀"
		$MarginContainer.visible = true
	else:
		tween.tween_property(self, "custom_minimum_size:x", collapsed_width, 0.3)
		tween.parallel().tween_property(self, "size:x", collapsed_width, 0.3)
		toggle_button.text = "▶"
		$MarginContainer.visible = false

func _update_character_stats(_new_value = null):
	"""更新角色数据显示"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# 角色位置
	var character_scene = save_mgr.get_character_scene()
	var scene_name = _get_scene_name(character_scene)
	var character_name = _get_character_name()
	character_location_label.text = "%s位于: %s" % [character_name, scene_name]
	print("[边栏] 更新角色位置显示: %s 位于 %s (场景ID: %s)" % [character_name, scene_name, character_scene])
	
	# 好感度
	var affection = save_mgr.get_affection()
	affection_label.text = "好感度: %d" % affection
	affection_label.add_theme_color_override("font_color", _get_stat_color(affection))
	
	# 交互意愿
	var willingness = save_mgr.get_reply_willingness()
	willingness_label.text = "交互意愿: %d" % willingness
	willingness_label.add_theme_color_override("font_color", _get_stat_color(willingness))
	
	# 心情
	var mood = save_mgr.get_mood()
	var mood_text = _get_mood_text(mood)
	mood_label.text = "心情: %s" % mood_text
	mood_label.add_theme_color_override("font_color", _get_mood_color(mood))

func _on_ai_fields_updated(_fields: Dictionary):
	"""AI字段更新时刷新显示"""
	_update_character_stats()

func _get_stat_color(value: int) -> Color:
	"""根据数值返回颜色"""
	if value >= 80:
		return Color(0.3, 1.0, 0.3) # 绿色
	elif value >= 50:
		return Color(1.0, 1.0, 0.3) # 黄色
	elif value >= 30:
		return Color(1.0, 0.7, 0.3) # 橙色
	else:
		return Color(1.0, 0.3, 0.3) # 红色

func _get_mood_text(mood: String) -> String:
	"""获取心情文本（从配置文件）"""
	var mood_config = _load_mood_config()
	if mood_config.is_empty():
		return mood
	
	for mood_data in mood_config.moods:
		if mood_data.name_en == mood:
			return mood_data.name
	
	return mood

func _get_mood_color(mood: String) -> Color:
	"""根据心情返回颜色（从配置文件）"""
	var mood_config = _load_mood_config()
	if mood_config.is_empty():
		return Color(1.0, 1.0, 1.0)
	
	for mood_data in mood_config.moods:
		if mood_data.name_en == mood:
			return Color(mood_data.color)
	
	return Color(1.0, 1.0, 1.0)

func _load_mood_config() -> Dictionary:
	"""加载心情配置"""
	var mood_config_path = "res://config/mood_config.json"
	if not FileAccess.file_exists(mood_config_path):
		return {}
	
	var file = FileAccess.open(mood_config_path, FileAccess.READ)
	if file == null:
		print("错误: 无法打开心情配置文件: ", mood_config_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	return json.data

func _get_mood_color_old(mood: String) -> Color:
	"""根据心情返回颜色（旧版本，保留作为备用）"""
	match mood:
		"happy", "excited":
			return Color(0.3, 1.0, 0.3) # 绿色
		"normal", "calm":
			return Color(1.0, 1.0, 1.0) # 白色
		"sad":
			return Color(0.5, 0.5, 1.0) # 蓝色
		"angry":
			return Color(1.0, 0.3, 0.3) # 红色
		_:
			return Color(1.0, 1.0, 1.0)

func _on_auto_save():
	"""自动保存"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.save_game()
		print("自动保存完成")

# === AI 设置相关 ===

var api_key_status: Label

func _setup_ai_settings(container: VBoxContainer):
	"""设置 AI 配置区域"""
	# AI 配置按钮
	var ai_config_button = Button.new()
	ai_config_button.text = "配置选项"
	ai_config_button.pressed.connect(_on_ai_config_pressed)
	container.add_child(ai_config_button)
	
	# 配置状态标签
	api_key_status = Label.new()
	api_key_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	api_key_status.add_theme_font_size_override("font_size", 11)
	container.add_child(api_key_status)
	
	# 加载并显示配置状态
	_load_api_key_display()
	
	# 分隔线
	var separator3 = HSeparator.new()
	container.add_child(separator3)
	
	# 存档调试按钮（隐藏）
	var debug_button = Button.new()
	debug_button.text = "存档调试"
	debug_button.pressed.connect(_on_debug_save_pressed)
	debug_button.visible = false # 隐藏调试元素
	container.add_child(debug_button)
	
	# 关于按钮
	var about_button = Button.new()
	about_button.text = "关于"
	about_button.pressed.connect(_on_about_pressed)
	container.add_child(about_button)

func _load_api_key_display():
	"""加载并显示 API 配置状态"""
	var key_path = "user://ai_keys.json"
	
	if FileAccess.file_exists(key_path):
		var file = FileAccess.open(key_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var config = json.data
			
			# 检查是否有 API 密钥（新格式不再使用 mode 字段）
			var has_api_key = false
			var api_key = ""
			
			# 优先从 chat_model 获取 API 密钥
			if config.has("chat_model") and config.chat_model.has("api_key"):
				api_key = config.chat_model.api_key
				has_api_key = not api_key.is_empty()
			# 兼容旧的 api_key 字段
			elif config.has("api_key"):
				api_key = config.api_key
				has_api_key = not api_key.is_empty()
			
			if has_api_key:
				# var masked_key = _mask_api_key(api_key)
				api_key_status.text = "✓ 已配置" #+ masked_key
				api_key_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
				return
	
	# 尝试从旧配置加载
	var old_key_path = "user://api_keys.json"
	if FileAccess.file_exists(old_key_path):
		var file = FileAccess.open(old_key_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var keys = json.data
			if keys.has("openai_api_key") and not keys.openai_api_key.is_empty():
				var masked_key = _mask_api_key(keys.openai_api_key)
				api_key_status.text = "✓ 已配置 (旧): " + masked_key
				api_key_status.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
				return
	
	api_key_status.text = "✗ 未配置"
	api_key_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _mask_api_key(key: String) -> String:
	"""遮蔽 API 密钥，只显示前后几位"""
	if key.length() <= 10:
		return "***"
	return key.substr(0, 7) + "..." + key.substr(key.length() - 4)

func _on_ai_config_pressed():
	"""打开AI配置面板"""
	# 检查是否已经存在配置面板
	for child in get_tree().root.get_children():
		if child is Panel and child.name == "AIConfigPanel":  # 根据你的实际节点名称调整
			# 如果已存在，直接显示并返回
			child.show()
			child.move_to_front()  # 确保显示在最前面
			return
	
	# 如果不存在，创建新面板
	var config_panel_scene = load("res://scenes/ai_config_panel.tscn")
	if config_panel_scene:
		var config_panel = config_panel_scene.instantiate()
		config_panel.name = "AIConfigPanel"  # 设置一个固定的名称便于识别
		get_tree().root.add_child(config_panel)
		# 面板关闭后刷新状态显示
		config_panel.tree_exited.connect(_load_api_key_display)

func _load_user_name() -> String:
	"""从存档系统加载用户名"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		return save_mgr.get_user_name()
	return "未设置"

func _on_user_name_changed(new_name: String):
	"""用户名改变时自动保存"""
	_save_user_name(new_name)

func _save_user_name(user_name: String):
	"""保存用户名到存档系统"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.set_user_name(user_name)
		print("用户名已保存到存档: ", user_name)

func _on_debug_save_pressed():
	"""打开存档调试面板"""
	var debug_panel_scene = load("res://scenes/save_debug_panel.tscn")
	if debug_panel_scene:
		var debug_panel = debug_panel_scene.instantiate()
		get_tree().root.add_child(debug_panel)

func _on_about_pressed():
	"""打开关于对话框"""
	# 检查是否已经存在关于对话框
	for child in get_tree().root.get_children():
		if child.get_script() and child.get_script().resource_path == "res://scripts/about_dialog.gd":
			# 如果已存在，切换显示状态
			if child.visible:
				child.queue_free()
			else:
				child.visible = true
			return
	
	# 如果不存在，创建新对话框
	var about_dialog_scene = load("res://scenes/about_dialog.tscn")
	if about_dialog_scene:
		var about_dialog = about_dialog_scene.instantiate()
		get_tree().root.add_child(about_dialog)

func _get_scene_name(scene_id: String) -> String:
	"""获取场景名称"""
	if scenes.has(scene_id):
		return scenes[scene_id].get("name", scene_id)
	return scene_id

func _get_character_name() -> String:
	"""获取角色名称"""
	if not has_node("/root/SaveManager"):
		return "角色"
	
	var save_mgr = get_node("/root/SaveManager")
	return save_mgr.get_character_name()

func _setup_experimental_section():
	"""设置实验性玩法部分"""
	# 标题
	var exp_label = Label.new()
	exp_label.text = "实验性玩法（没做）"
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	scene_list.add_child(exp_label)
