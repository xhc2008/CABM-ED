extends Node
class_name GameStateManager

# 游戏状态管理器 - 负责游戏场景的显示/隐藏（如五子棋）

var main_scene_elements: Dictionary = {}

func set_main_scene_elements(elements: Dictionary):
	"""设置主场景元素引用"""
	main_scene_elements = elements

func hide_main_scene():
	"""隐藏主场景元素"""
	if main_scene_elements.has("sidebar"):
		main_scene_elements.sidebar.visible = false
	if main_scene_elements.has("character"):
		main_scene_elements.character.visible = false
	if main_scene_elements.has("action_menu"):
		main_scene_elements.action_menu.visible = false
	if main_scene_elements.has("scene_menu"):
		main_scene_elements.scene_menu.visible = false
	if main_scene_elements.has("character_diary_button"):
		main_scene_elements.character_diary_button.visible = false
	
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.pause_timers()

func show_main_scene():
	"""恢复主场景元素"""
	if main_scene_elements.has("sidebar"):
		main_scene_elements.sidebar.visible = true
	
	if main_scene_elements.has("character"):
		var character = main_scene_elements.character
		var current_scene = ""
		if main_scene_elements.has("current_scene"):
			current_scene = main_scene_elements.current_scene
		# 尽量使用最新的场景管理器当前场景，避免旧值
		if has_node("/root/Main"):
			var main = get_node("/root/Main")
			if main and main.scene_manager:
				current_scene = main.scene_manager.current_scene
		character.load_character_for_scene(current_scene)
	
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.resume_timers()
