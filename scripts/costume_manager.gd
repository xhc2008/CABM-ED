extends Node
class_name CostumeManager

# 换装管理器 - 负责换装相关的所有逻辑

var costume_button
var character
var message_display_manager: MessageDisplayManager

func initialize(character_node, msg_mgr: MessageDisplayManager):
	"""初始化管理器"""
	character = character_node
	message_display_manager = msg_mgr

func set_costume_button(button):
	"""设置换装按钮引用"""
	costume_button = button
	if costume_button:
		costume_button.action_triggered.connect(_on_costume_action_triggered)

func update_costume_button_visibility(current_scene: String):
	"""更新换装按钮的显示状态"""
	if not costume_button:
		return
	
	var should_show = false
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		should_show = mgr.should_show_in_scene("costume_button", current_scene) and mgr.is_element_enabled("costume_button")
	else:
		should_show = (current_scene == "bathroom")
	
	if should_show:
		costume_button.enable()
	else:
		costume_button.disable()

func _on_costume_action_triggered(action: String):
	"""换装按钮动作触发"""
	if action == "costume_selector":
		open_costume_selector()

func open_costume_selector():
	"""打开换装选择器"""
	var costume_selector_script = load("res://scripts/costume_selector.gd")
	var costume_selector = Control.new()
	costume_selector.set_script(costume_selector_script)
	costume_selector.set_anchors_preset(Control.PRESET_FULL_RECT)
	costume_selector.z_index = 200
	
	costume_selector.costume_selected.connect(_on_costume_selected)
	costume_selector.close_requested.connect(_on_costume_selector_closed.bind(costume_selector))
	
	# 获取主场景并添加
	var main = get_node("/root/Main")
	if main:
		main.add_child(costume_selector)
	
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").disable_all()

func _on_costume_selected(costume_id: String):
	"""服装被选择"""
	print("选择服装: ", costume_id)
	
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.set_costume_id(costume_id)
	
	if character:
		character.reload_with_new_costume()
	
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").enable_all()
	
	if message_display_manager:
		message_display_manager.show_info_message("服装已更换")

func _on_costume_selector_closed(costume_selector: Control):
	"""换装选择器关闭"""
	print("换装选择器关闭")
	costume_selector.queue_free()
	
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").enable_all()
