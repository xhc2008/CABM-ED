extends Panel

signal scene_changed(scene_id: String, weather_id: String)

@onready var scene_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SceneList
@onready var toggle_button: Button = $ToggleButton

var is_expanded: bool = true
var collapsed_width: float = 40.0
var expanded_width: float = 250.0

# 场景配置
var scenes = {
	"livingroom": {
		"name": "客厅",
		"weathers": {
			"sunny": "晴天",
			"rainy": "雨天",
			"storm": "雷雨"
		}
	}
}

func _ready():
	toggle_button.pressed.connect(_on_toggle_pressed)
	_build_scene_list()

func _build_scene_list():
	# 清空现有列表
	for child in scene_list.get_children():
		child.queue_free()
	
	# 为每个场景创建按钮组
	for scene_id in scenes:
		var scene_data = scenes[scene_id]
		
		# 场景标题
		var scene_label = Label.new()
		scene_label.text = scene_data["name"]
		scene_label.add_theme_font_size_override("font_size", 16)
		scene_list.add_child(scene_label)
		
		# 天气按钮
		for weather_id in scene_data["weathers"]:
			var weather_name = scene_data["weathers"][weather_id]
			var button = Button.new()
			button.text = "  " + weather_name
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_weather_selected.bind(scene_id, weather_id))
			scene_list.add_child(button)
		
		# 分隔符
		var separator = HSeparator.new()
		scene_list.add_child(separator)

func _on_weather_selected(scene_id: String, weather_id: String):
	print("选择场景: %s, 天气: %s" % [scene_id, weather_id])
	scene_changed.emit(scene_id, weather_id)

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
