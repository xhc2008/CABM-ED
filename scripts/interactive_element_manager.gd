extends Node

# 可交互元素管理器 - 统一管理所有可交互组件的配置
# 自动加载单例

var config: Dictionary = {}
var registered_elements: Dictionary = {}  # element_id -> node

func _ready():
	_load_config()

func _load_config():
	"""加载配置文件"""
	var config_path = "res://config/interactive_elements.json"
	if not FileAccess.file_exists(config_path):
		push_error("可交互元素配置文件不存在: " + config_path)
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		config = json.data
		print("可交互元素配置已加载")
	else:
		push_error("可交互元素配置解析失败")

func register_element(element_id: String, node: Node):
	"""注册一个可交互元素"""
	if not config.has("elements") or not config.elements.has(element_id):
		push_warning("元素ID未在配置中找到: " + element_id)
		return
	
	registered_elements[element_id] = node
	print("可交互元素已注册: ", element_id)

func get_element_config(element_id: String) -> Dictionary:
	"""获取元素配置"""
	if config.has("elements") and config.elements.has(element_id):
		return config.elements[element_id]
	return {}

func get_element_size(element_id: String) -> Vector2:
	"""获取元素大小"""
	var element_config = get_element_config(element_id)
	if element_config.has("size"):
		return Vector2(
			element_config.size.get("width", 80),
			element_config.size.get("height", 80)
		)
	return Vector2(80, 80)

func calculate_element_position(element_id: String, scene_rect: Rect2, element_size: Vector2) -> Vector2:
	"""计算元素位置"""
	var element_config = get_element_config(element_id)
	if not element_config.has("position"):
		return Vector2.ZERO
	
	var pos_config = element_config.position
	var anchor = pos_config.get("anchor", "bottom_left")
	var offset_x = pos_config.get("offset_x", 0)
	var offset_y = pos_config.get("offset_y", 0)
	
	var base_pos = Vector2.ZERO
	
	# 根据锚点计算基础位置
	match anchor:
		"top_left":
			base_pos = scene_rect.position
		"top_right":
			base_pos = Vector2(
				scene_rect.position.x + scene_rect.size.x - element_size.x,
				scene_rect.position.y
			)
		"bottom_left":
			base_pos = Vector2(
				scene_rect.position.x,
				scene_rect.position.y + scene_rect.size.y - element_size.y
			)
		"bottom_right":
			base_pos = Vector2(
				scene_rect.position.x + scene_rect.size.x - element_size.x,
				scene_rect.position.y + scene_rect.size.y - element_size.y
			)
		"center":
			base_pos = Vector2(
				scene_rect.position.x + (scene_rect.size.x - element_size.x) / 2,
				scene_rect.position.y + (scene_rect.size.y - element_size.y) / 2
			)
		"left_center":
			base_pos = Vector2(
				scene_rect.position.x,
				scene_rect.position.y + (scene_rect.size.y - element_size.y) / 2
			)
		"right_center":
			base_pos = Vector2(
				scene_rect.position.x + scene_rect.size.x - element_size.x,
				scene_rect.position.y + (scene_rect.size.y - element_size.y) / 2
			)
	
	# 应用偏移
	return base_pos + Vector2(offset_x, offset_y)

func should_show_in_scene(element_id: String, scene_id: String) -> bool:
	"""检查元素是否应该在指定场景显示"""
	var element_config = get_element_config(element_id)
	if not element_config.has("scenes"):
		return true  # 没有配置scenes则在所有场景显示
	
	var scenes = element_config.scenes
	if scenes.is_empty():
		return true  # 空数组表示在所有场景显示
	
	return scene_id in scenes

func is_element_enabled(element_id: String) -> bool:
	"""检查元素是否启用"""
	var element_config = get_element_config(element_id)
	return element_config.get("enabled", true)

func get_all_element_ids() -> Array:
	"""获取所有元素ID"""
	if config.has("elements"):
		return config.elements.keys()
	return []
