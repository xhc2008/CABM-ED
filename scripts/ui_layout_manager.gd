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

func initialize(scene_mgr: SceneManager):
	"""初始化管理器"""
	scene_manager = scene_mgr

func set_ui_references(refs: Dictionary):
	"""设置UI组件引用"""
	sidebar = refs.get("sidebar")
	chat_dialog = refs.get("chat_dialog")
	action_menu = refs.get("action_menu")
	character_diary_button = refs.get("character_diary_button")
	character_diary_viewer = refs.get("character_diary_viewer")
	costume_button = refs.get("costume_button")
	music_button = refs.get("music_button")

func update_all_layouts():
	"""更新所有UI组件的位置和大小"""
	scene_manager.calculate_scene_rect()
	
	update_sidebar_layout()
	update_chat_dialog_layout()
	update_character_diary_button_layout()
	update_character_diary_viewer_layout()
	update_costume_button_layout()
	update_music_button_layout()
	
	if action_menu and action_menu.visible:
		update_action_menu_position()

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

func update_character_diary_button_layout():
	"""更新角色日记按钮布局"""
	if not character_diary_button:
		return
	
	var scene_rect = scene_manager.scene_rect
	
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		var element_size = character_diary_button.size
		character_diary_button.position = mgr.calculate_element_position("character_diary_button", scene_rect, element_size)
	else:
		var button_x = scene_rect.position.x + 120
		var button_y = scene_rect.position.y + scene_rect.size.y - character_diary_button.size.y - 130
		character_diary_button.position = Vector2(button_x, button_y)

func update_character_diary_viewer_layout():
	"""更新角色日记查看器布局"""
	if not character_diary_viewer:
		return
	
	var scene_rect = scene_manager.scene_rect
	var viewer_x = scene_rect.position.x + (scene_rect.size.x - character_diary_viewer.size.x) / 2
	var viewer_y = scene_rect.position.y + (scene_rect.size.y - character_diary_viewer.size.y) / 2
	
	character_diary_viewer.position = Vector2(viewer_x, viewer_y)

func update_costume_button_layout():
	"""更新换装按钮布局"""
	if not costume_button:
		return
	
	var scene_rect = scene_manager.scene_rect
	
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		var element_size = costume_button.size
		costume_button.position = mgr.calculate_element_position("costume_button", scene_rect, element_size)
	else:
		var button_x = scene_rect.position.x + scene_rect.size.x - costume_button.size.x - 140
		var button_y = scene_rect.position.y + scene_rect.size.y - costume_button.size.y - 130
		costume_button.position = Vector2(button_x, button_y)

func update_music_button_layout():
	"""更新音乐按钮布局"""
	if not music_button:
		return
	
	var scene_rect = scene_manager.scene_rect
	
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		var element_size = music_button.custom_minimum_size
		music_button.position = mgr.calculate_element_position("music_button", scene_rect, element_size)
	else:
		var button_x = scene_rect.position.x + 160
		var button_y = scene_rect.position.y + scene_rect.size.y - 150
		music_button.position = Vector2(button_x, button_y)
