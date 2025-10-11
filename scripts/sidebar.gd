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
	var separator = HSeparator.new()
	header_container.add_child(separator)
	
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
		return "dusk"  # 凌晨算作黄昏
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
	
	# 为每个场景创建按钮组
	for scene_id in scenes:
		var scene_data = scenes[scene_id]
		
		# 场景标题
		var scene_label = Label.new()
		scene_label.text = scene_data["name"]
		scene_label.add_theme_font_size_override("font_size", 16)
		scene_list.add_child(scene_label)
		
		# 时间按钮组
		if scene_data.has("times"):
			var time_label = Label.new()
			time_label.text = "  时间:"
			time_label.add_theme_font_size_override("font_size", 12)
			scene_list.add_child(time_label)
			
			var time_container = HBoxContainer.new()
			time_container.add_theme_constant_override("separation", 5)
			for time_id in scene_data["times"]:
				var time_name = scene_data["times"][time_id]
				var button = Button.new()
				button.text = time_name
				button.custom_minimum_size = Vector2(60, 30)
				button.toggle_mode = true
				button.pressed.connect(_on_time_selected.bind(time_id))
				time_container.add_child(button)
				
				# 保存按钮引用
				time_buttons[time_id] = button
			scene_list.add_child(time_container)
		
		# 天气按钮组
		if scene_data.has("weathers"):
			var weather_label = Label.new()
			weather_label.text = "  天气:"
			weather_label.add_theme_font_size_override("font_size", 12)
			scene_list.add_child(weather_label)
			
			var weather_container = HBoxContainer.new()
			weather_container.add_theme_constant_override("separation", 5)
			for weather_id in scene_data["weathers"]:
				var weather_name = scene_data["weathers"][weather_id]
				var button = Button.new()
				button.text = weather_name
				button.custom_minimum_size = Vector2(60, 30)
				button.toggle_mode = true
				button.pressed.connect(_on_weather_selected.bind(weather_id))
				weather_container.add_child(button)
				
				# 保存按钮引用
				weather_buttons[weather_id] = button
			scene_list.add_child(weather_container)
		
		# 分隔符
		var separator = HSeparator.new()
		scene_list.add_child(separator)
	
	# 初始化按钮状态
	_update_button_states()

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
