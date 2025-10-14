extends Node

# 事件辅助函数 - 提供通用的计算和判断功能
# 包括成功率计算、修正值获取、角色信息等

# === 成功率计算 ===

func calculate_success_chance(base_willingness: int) -> float:
	"""计算事件成功概率"""
	if not has_node("/root/SaveManager"):
		return 0.0
	
	var save_mgr = get_node("/root/SaveManager")
	var current_willingness = save_mgr.get_reply_willingness()
	
	# 基础公式: (base_willingness + current_willingness - 100) / 100
	var chance = (base_willingness + current_willingness - 100.0) / 100.0
	
	# 应用修正
	chance += get_mood_modifier()
	chance += get_energy_modifier()
	
	# 限制在 0-1 范围
	return clamp(chance, 0.0, 1.0)

# === 修正值获取 ===

func get_mood_modifier() -> float:
	"""获取心情修正值"""
	if not has_node("/root/SaveManager"):
		return 0.0
	
	var save_mgr = get_node("/root/SaveManager")
	var mood = save_mgr.get_mood()
	
	# 心情修正映射
	var mood_modifiers = {
		"happy": 0.20,
		"normal": 0.0,
		"sad": - 0.20,
		"angry": - 0.40,
		"excited": 0.30
	}
	
	return mood_modifiers.get(mood, 0.0)

func get_energy_modifier() -> float:
	"""获取精力修正值"""
	if not has_node("/root/SaveManager"):
		return 0.0
	
	var save_mgr = get_node("/root/SaveManager")
	var energy = save_mgr.get_energy()
	
	# 根据精力值返回修正
	if energy >= 80:
		return 0.10
	elif energy >= 40:
		return 0.0
	elif energy >= 20:
		return -0.15
	else:
		return -0.30

# === 数值修改 ===

func modify_affection(change: int):
	"""修改好感度"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var current = save_mgr.get_affection()
	var new_value = clamp(current + change, 0, 100)
	save_mgr.set_affection(new_value)
	
	if change != 0:
		print("好感度变化: %d -> %d (%+d)" % [current, new_value, change])

func modify_willingness(change: int):
	"""修改交互意愿"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var current = save_mgr.get_reply_willingness()
	var new_value = clamp(current + change, 0, 100)
	save_mgr.set_reply_willingness(new_value)
	
	if change != 0:
		print("交互意愿变化: %d -> %d (%+d)" % [current, new_value, change])

func modify_mood(new_mood: String):
	"""修改心情"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	save_mgr.set_mood(new_mood)
	print("心情变化: ", new_mood)

func modify_energy(change: int):
	"""修改精力"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var current = save_mgr.get_energy()
	var new_value = clamp(current + change, 0, 100)
	save_mgr.set_energy(new_value)
	
	if change != 0:
		print("精力变化: %d -> %d (%+d)" % [current, new_value, change])

# === 信息获取 ===

func get_character_name() -> String:
	"""获取角色名称"""
	var config_path = "res://config/app_config.json"
	if not FileAccess.file_exists(config_path):
		return "角色"
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return "角色"
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return "角色"
	
	var data = json.data
	return data.get("character_name", "角色")

func get_affection() -> int:
	"""获取当前好感度"""
	if not has_node("/root/SaveManager"):
		return 0
	return get_node("/root/SaveManager").get_affection()

func get_willingness() -> int:
	"""获取当前交互意愿"""
	if not has_node("/root/SaveManager"):
		return 0
	return get_node("/root/SaveManager").get_reply_willingness()

func get_mood() -> String:
	"""获取当前心情"""
	if not has_node("/root/SaveManager"):
		return "normal"
	return get_node("/root/SaveManager").get_mood()

func get_energy() -> int:
	"""获取当前精力"""
	if not has_node("/root/SaveManager"):
		return 0
	return get_node("/root/SaveManager").get_energy()
