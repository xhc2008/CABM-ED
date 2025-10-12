extends Node

# 测试交互意愿系统的脚本
# 将此脚本附加到任意节点上，按数字键测试不同功能

func _ready():
	print("=== 交互意愿系统测试 ===")
	print("按键说明:")
	print("1 - 测试聊天交互")
	print("2 - 测试点击角色")
	print("3 - 测试进入场景")
	print("4 - 查看当前状态")
	print("5 - 增加交互意愿 (+10)")
	print("6 - 减少交互意愿 (-10)")
	print("7 - 设置好心情")
	print("8 - 设置坏心情")
	print("9 - 重置所有数据")
	print("0 - 显示所有动作成功率")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_test_chat()
			KEY_2:
				_test_click_character()
			KEY_3:
				_test_enter_scene()
			KEY_4:
				_show_current_status()
			KEY_5:
				_modify_willingness(10)
			KEY_6:
				_modify_willingness(-10)
			KEY_7:
				_set_mood("happy")
			KEY_8:
				_set_mood("angry")
			KEY_9:
				_reset_data()
			KEY_0:
				_show_all_chances()

func _test_chat():
	if not has_node("/root/InteractionManager"):
		print("错误: InteractionManager 未找到")
		return
	
	var interaction_mgr = get_node("/root/InteractionManager")
	print("\n--- 测试聊天 ---")
	var chance = interaction_mgr.calculate_success_chance("chat")
	print("成功率: ", chance * 100, "%")
	
	var success = interaction_mgr.try_interaction("chat")
	if success:
		print("✓ 聊天成功！")
	else:
		print("✗ 聊天失败")

func _test_click_character():
	if not has_node("/root/InteractionManager"):
		print("错误: InteractionManager 未找到")
		return
	
	var interaction_mgr = get_node("/root/InteractionManager")
	print("\n--- 测试点击角色 ---")
	var chance = interaction_mgr.calculate_success_chance("click_character")
	print("成功率: ", chance * 100, "%")
	
	var success = interaction_mgr.try_interaction("click_character")
	if success:
		print("✓ 点击成功！")
	else:
		print("✗ 点击失败")

func _test_enter_scene():
	if not has_node("/root/InteractionManager"):
		print("错误: InteractionManager 未找到")
		return
	
	var interaction_mgr = get_node("/root/InteractionManager")
	print("\n--- 测试进入场景 ---")
	var chance = interaction_mgr.calculate_success_chance("enter_scene")
	print("成功率: ", chance * 100, "%")
	
	var success = interaction_mgr.try_interaction("enter_scene")
	if success:
		print("✓ 进入成功！")
	else:
		print("✗ 进入失败")

func _show_current_status():
	if not has_node("/root/SaveManager"):
		print("错误: SaveManager 未找到")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	print("\n=== 当前状态 ===")
	print("交互意愿: ", save_mgr.get_reply_willingness())
	print("好感度: ", save_mgr.get_affection())
	print("心情: ", save_mgr.get_mood())
	print("精力: ", save_mgr.get_energy())
	print("信任等级: ", save_mgr.get_trust_level())

func _modify_willingness(amount: int):
	if not has_node("/root/SaveManager") or not has_node("/root/InteractionManager"):
		print("错误: 管理器未找到")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var interaction_mgr = get_node("/root/InteractionManager")
	var old_value = save_mgr.get_reply_willingness()
	interaction_mgr.modify_willingness(amount)
	var new_value = save_mgr.get_reply_willingness()
	print("\n交互意愿: ", old_value, " -> ", new_value)

func _set_mood(mood: String):
	if not has_node("/root/SaveManager"):
		print("错误: SaveManager 未找到")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	save_mgr.set_mood(mood)
	print("\n心情设置为: ", mood)
	_show_all_chances()

func _reset_data():
	if not has_node("/root/SaveManager"):
		print("错误: SaveManager 未找到")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	print("\n=== 重置数据 ===")
	save_mgr.set_reply_willingness(50)
	save_mgr.set_affection(0)
	save_mgr.set_mood("normal")
	save_mgr.set_energy(100)
	save_mgr.set_trust_level(0)
	print("所有数据已重置")
	_show_current_status()

func _show_all_chances():
	if not has_node("/root/InteractionManager"):
		print("错误: InteractionManager 未找到")
		return
	
	var interaction_mgr = get_node("/root/InteractionManager")
	print("\n=== 所有动作成功率 ===")
	var actions = ["chat", "click_character", "enter_scene", "leave_scene", "gift", "pat_head", "call_name"]
	
	for action_id in actions:
		var chance = interaction_mgr.calculate_success_chance(action_id)
		var action_config = interaction_mgr.get_action_config(action_id)
		var action_name = action_config.get("name", action_id)
		print("%s: %.1f%%" % [action_name, chance * 100])
