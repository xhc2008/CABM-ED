extends Node
class_name UILayoutManager

# UI布局管理器 - 负责所有UI组件的位置和大小计算

var scene_manager: SceneManager
var sidebar
var chat_dialog
var action_menu
var character_diary_button
var character_diary_viewer
var costume_button
var music_button
var cook_button

func initialize(scene_mgr: SceneManager):
	"""初始化管理器"""
	scene_manager = scene_mgr

func set_ui_references(refs: Dictionary):
	"""设置UI组件引用"""
	sidebar = refs.get("sidebar")
	chat_dialog = refs.get("chat_dialog")
	action_menu = refs.get("action_menu")
	character_diary_viewer = refs.get("character_diary_viewer")
	
	# 简化四个按钮的引用设置
	var button_names = ["character_diary_button", "costume_button", "music_button", "cook_button"]
	for button_name in button_names:
		set(button_name, refs.get(button_name))

func update_all_layouts():
	"""更新所有UI组件的位置和大小"""
	scene_manager.calculate_scene_rect()
	
	update_sidebar_layout()
	update_chat_dialog_layout()
	update_character_diary_viewer_layout()
	
	# 合并四个按钮的布局更新
	_update_button_layout("character_diary_button", character_diary_button)
	_update_button_layout("costume_button", costume_button)
	_update_button_layout("music_button", music_button)
	_update_button_layout("cook_button", cook_button)
	
	if action_menu and action_menu.visible:
		update_action_menu_position()

func _update_button_layout(button_id: String, button):
	"""统一更新按钮布局"""
	if not button:
		return
	
	var scene_rect = scene_manager.scene_rect
	
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		var element_size = button.custom_minimum_size if button.has_method("get_custom_minimum_size") else button.size
		button.position = mgr.calculate_element_position(button_id, scene_rect, element_size)

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
