extends Node
class_name UILayoutManager

# UI布局管理器 - 负责所有UI组件的位置和大小计算

var scene_manager: SceneManager
var sidebar
var chat_dialog
var action_menu
var character_diary_viewer

# 存储所有交互元素的字典
var interactive_elements = {}

func initialize(scene_mgr: SceneManager):
	"""初始化管理器"""
	scene_manager = scene_mgr
	_load_interactive_elements()

func set_ui_references(refs: Dictionary):
	"""设置UI组件引用"""
	sidebar = refs.get("sidebar")
	chat_dialog = refs.get("chat_dialog")
	action_menu = refs.get("action_menu")
	character_diary_viewer = refs.get("character_diary_viewer")
	
	# 动态设置交互元素引用
	for element_id in interactive_elements:
		if refs.has(element_id):
			interactive_elements[element_id].node = refs[element_id]

func _load_interactive_elements():
	"""从JSON文件加载交互元素配置"""
	var file = FileAccess.open("res://config/interactive_elements.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			var data = json.data
			if data and data.has("elements"):
				for element_id in data["elements"]:
					var element_data = data["elements"][element_id]
					interactive_elements[element_id] = {
						"data": element_data,
						"node": null
					}
		else:
			push_error("解析interactive_elements.json失败: " + json.get_error_message())
	else:
		push_error("无法打开interactive_elements.json文件")

func update_all_layouts():
	"""更新所有UI组件的位置和大小"""
	scene_manager.calculate_scene_rect()
	
	update_sidebar_layout()
	update_chat_dialog_layout()
	update_character_diary_viewer_layout()
	
	# 动态更新所有交互元素布局
	_update_all_interactive_elements_layout()
	
	if action_menu and action_menu.visible:
		update_action_menu_position()

func _update_all_interactive_elements_layout():
	"""更新所有交互元素的布局"""
	for element_id in interactive_elements:
		var element = interactive_elements[element_id]
		if element.node and element.data.get("enabled", true):
			_update_interactive_element_layout(element_id, element.node)

func _update_interactive_element_layout(element_id: String, element_node):
	"""更新单个交互元素的布局"""
	if not element_node:
		return
	
	var scene_rect = scene_manager.scene_rect
	
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		var element_size = element_node.custom_minimum_size if element_node.has_method("get_custom_minimum_size") else element_node.size
		element_node.position = mgr.calculate_element_position(element_id, scene_rect, element_size)

func update_sidebar_layout():
	"""更新侧边栏布局"""
	if not sidebar:
		return
	
	var scene_rect = scene_manager.scene_rect
	sidebar.position = scene_rect.position
	sidebar.size.y = scene_rect.size.y
	sidebar.custom_minimum_size.y = scene_rect.size.y

func update_chat_dialog_layout():
	"""更新聊天对话框布局"""
	if not chat_dialog:
		return
	
	var scene_rect = scene_manager.scene_rect
	var dialog_height = chat_dialog.size.y
	var sidebar_width = sidebar.size.x if (sidebar and sidebar.visible) else 0.0
	
	var dialog_x = scene_rect.position.x + sidebar_width
	var dialog_width = scene_rect.size.x - sidebar_width
	
	if dialog_x + dialog_width > scene_rect.position.x + scene_rect.size.x:
		dialog_width = scene_rect.position.x + scene_rect.size.x - dialog_x
	
	var dialog_y = scene_rect.position.y + scene_rect.size.y - dialog_height
	
	if dialog_y < scene_rect.position.y:
		dialog_y = scene_rect.position.y
	
	chat_dialog.position = Vector2(dialog_x, dialog_y)
	chat_dialog.size.x = dialog_width
	chat_dialog.custom_minimum_size.x = dialog_width

func update_action_menu_position():
	"""更新动作菜单位置"""
	if not action_menu:
		return
	
	var scene_rect = scene_manager.scene_rect
	var menu_pos = action_menu.position
	
	if menu_pos.x + action_menu.size.x > scene_rect.position.x + scene_rect.size.x:
		menu_pos.x = scene_rect.position.x + scene_rect.size.x - action_menu.size.x - 10
	
	if menu_pos.x < scene_rect.position.x:
		menu_pos.x = scene_rect.position.x + 10
	
	if menu_pos.y + action_menu.size.y > scene_rect.position.y + scene_rect.size.y:
		menu_pos.y = scene_rect.position.y + scene_rect.size.y - action_menu.size.y - 10
	
	if menu_pos.y < scene_rect.position.y:
		menu_pos.y = scene_rect.position.y + 10
	
	action_menu.position = menu_pos

func update_character_diary_viewer_layout():
	"""更新角色日记查看器布局"""
	if not character_diary_viewer:
		return
	
	var scene_rect = scene_manager.scene_rect
	var viewer_x = scene_rect.position.x + (scene_rect.size.x - character_diary_viewer.size.x) / 2
	var viewer_y = scene_rect.position.y + (scene_rect.size.y - character_diary_viewer.size.y) / 2
	
	character_diary_viewer.position = Vector2(viewer_x, viewer_y)

func get_interactive_elements() -> Dictionary:
	"""获取所有交互元素数据"""
	return interactive_elements.duplicate(true)

func is_element_enabled(element_id: String) -> bool:
	"""检查指定元素是否启用"""
	if interactive_elements.has(element_id):
		return interactive_elements[element_id].data.get("enabled", true)
	return false

func set_element_enabled(element_id: String, enabled: bool):
	"""设置元素启用状态"""
	if interactive_elements.has(element_id):
		interactive_elements[element_id].data["enabled"] = enabled
		
		# 立即更新布局
		var element = interactive_elements[element_id]
		if element.node:
			element.node.visible = enabled
			if enabled:
				_update_interactive_element_layout(element_id, element.node)