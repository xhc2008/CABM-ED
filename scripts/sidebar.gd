extends Panel

signal scene_changed(scene_id: String, weather_id: String, time_id: String)

@onready var scene_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SceneList
@onready var toggle_button: Button = $ToggleButton

var is_expanded: bool = true
var collapsed_width: float = 40.0
var expanded_width: float = 250.0

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
var current_weather_id: String = "sunny"
var auto_time_enabled: bool = false
var clock_label: Label
var auto_checkbox: CheckBox
var time_update_timer: Timer
var time_buttons = {}
var weather_buttons = {}

# 角色数据显示标签
var affection_label: Label
var willingness_label: Label
var mood_label: Label
var energy_label: Label
var trust_label: Label

# 自动保存定时器
var auto_save_timer: Timer

func _ready():
	toggle_button.pressed.connect(_on_toggle_pressed)
	_load_scenes_config()
	_setup_clock_and_auto()
	_build_scene_list()
	
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
	
	# 等待自动加载节点准备好
	await get_tree().process_frame
	
	# 监听数据变化
	if has_node("/root/InteractionManager"):
		var interaction_mgr = get_node("/root/InteractionManager")
		interaction_mgr.willingness_changed.connect(_update_character_stats)

func _setup_clock_and_auto():
	# 在场景列表顶部添加时钟和自动选项
	var header_container = VBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	
	# 电子时钟
	clock_label = Label.new()
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	header_container.add_child(clock_label)
	
	# 自动时间勾选框
	var auto_container = HBoxContainer.new()
	auto_container.alignment = BoxContainer.ALIGNMENT_CENTER
	auto_checkbox = CheckBox.new()
	auto_checkbox.text = "自动调整时间"
	auto_checkbox.toggled.connect(_on_auto_time_toggled)
	auto_container.add_child(auto_checkbox)
	header_container.add_child(auto_container)
	
	# 分隔线
	var separator1 = HSeparator.new()
	header_container.add_child(separator1)
	
	# 角色数据显示
	var stats_label = Label.new()
	stats_label.text = "角色状态"
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	header_container.add_child(stats_label)
	
	# 好感度
	affection_label = Label.new()
	affection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	affection_label.add_theme_font_size_override("font_size", 12)
	header_container.add_child(affection_label)
	
	# 交互意愿
	willingness_label = Label.new()
	willingness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	willingness_label.add_theme_font_size_override("font_size", 12)
	header_container.add_child(willingness_label)
	
	# 心情
	mood_label = Label.new()
	mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_label.add_theme_font_size_override("font_size", 12)
	header_container.add_child(mood_label)
	
	# 精力
	energy_label = Label.new()
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 12)
	header_container.add_child(energy_label)
	
	# 信任等级
	trust_label = Label.new()
	trust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trust_label.add_theme_font_size_override("font_size", 12)
	header_container.add_child(trust_label)
	
	# 更新数据显示
	_update_character_stats()
	
	# 分隔线
	var separator2 = HSeparator.new()
	header_container.add_child(separator2)
	
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
	# 18:00-19:59 = 黄昏 (dusk)
	# 20:00-3:59 = 夜晚 (night)
	# 4:00-6:59 (凌晨) = 黄昏 (dusk)
	if hour >= 4 and hour < 7:
		return "dusk" # 凌晨算作黄昏
	elif hour >= 7 and hour < 18:
		return "day"
	elif hour >= 18 and hour < 20:
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
	
	# 场景标题
	var scene_label = Label.new()
	scene_label.text = "当前场景: " + scene_data["name"]
	scene_label.add_theme_font_size_override("font_size", 16)
	scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_list.add_child(scene_label)
	
	# 分隔线
	var separator1 = HSeparator.new()
	scene_list.add_child(separator1)
	
	# 时间按钮组
	if scene_data.has("times"):
		var time_label = Label.new()
		time_label.text = "时间"
		time_label.add_theme_font_size_override("font_size", 14)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_list.add_child(time_label)
		
		var time_container = VBoxContainer.new()
		time_container.add_theme_constant_override("separation", 5)
		for time_id in scene_data["times"]:
			var time_name = scene_data["times"][time_id]
			var button = Button.new()
			button.text = time_name
			button.custom_minimum_size = Vector2(0, 35)
			button.toggle_mode = true
			button.pressed.connect(_on_time_selected.bind(time_id))
			time_container.add_child(button)
			
			# 保存按钮引用
			time_buttons[time_id] = button
		scene_list.add_child(time_container)
	
	# 分隔线
	var separator2 = HSeparator.new()
	scene_list.add_child(separator2)
	
	# 天气按钮组
	if scene_data.has("weathers"):
		var weather_label = Label.new()
		weather_label.text = "天气"
		weather_label.add_theme_font_size_override("font_size", 14)
		weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_list.add_child(weather_label)
		
		var weather_container = VBoxContainer.new()
		weather_container.add_theme_constant_override("separation", 5)
		for weather_id in scene_data["weathers"]:
			var weather_name = scene_data["weathers"][weather_id]
			var button = Button.new()
			button.text = weather_name
			button.custom_minimum_size = Vector2(0, 35)
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
	
	# 精力
	var energy = save_mgr.get_energy()
	energy_label.text = "精力: %d" % energy
	energy_label.add_theme_color_override("font_color", _get_stat_color(energy))
	
	# 信任等级
	var trust = save_mgr.get_trust_level()
	trust_label.text = "信任: %d" % trust
	trust_label.add_theme_color_override("font_color", _get_stat_color(trust))

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
	"""获取心情文本"""
	match mood:
		"happy": return "开心"
		"excited": return "兴奋"
		"normal": return "普通"
		"sad": return "难过"
		"angry": return "生气"
		_: return mood

func _get_mood_color(mood: String) -> Color:
	"""根据心情返回颜色"""
	match mood:
		"happy", "excited":
			return Color(0.3, 1.0, 0.3) # 绿色
		"normal":
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
