extends Node

# 离线时间测试脚本
# 用于测试离线时间管理器的功能

func _ready():
	print("\n=== 离线时间测试工具 ===")
	print("使用方法:")
	print("1. 在控制台调用 test_short_offline() - 测试5分钟~3小时")
	print("2. 在控制台调用 test_medium_offline() - 测试3小时~24小时")
	print("3. 在控制台调用 test_long_offline() - 测试24小时以上")
	print("4. 在控制台调用 reset_time() - 重置为当前时间")
	print("========================\n")

func test_short_offline():
	"""测试短时间离线（1小时）"""
	print("\n=== 测试短时间离线（1小时）===")
	_print_current_state()
	
	# 设置上次游玩时间为1小时前
	var one_hour_ago = Time.get_unix_time_from_system() - 3600
	var datetime_dict = Time.get_datetime_dict_from_unix_time(one_hour_ago)
	var datetime_str = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime_dict.year, datetime_dict.month, datetime_dict.day,
		datetime_dict.hour, datetime_dict.minute, datetime_dict.second
	]
	
	SaveManager.save_data.timestamp.last_played_at = datetime_str
	print("设置上次游玩时间为: ", datetime_str)
	
	# 应用离线变化
	get_node("/root/OfflineTimeManager").check_and_apply_offline_changes()
	
	_print_current_state()
	print("=== 测试完成 ===\n")

func test_medium_offline():
	"""测试中等时间离线（12小时）"""
	print("\n=== 测试中等时间离线（12小时）===")
	_print_current_state()
	
	# 设置上次游玩时间为12小时前
	var twelve_hours_ago = Time.get_unix_time_from_system() - (3600 * 12)
	var datetime_dict = Time.get_datetime_dict_from_unix_time(twelve_hours_ago)
	var datetime_str = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime_dict.year, datetime_dict.month, datetime_dict.day,
		datetime_dict.hour, datetime_dict.minute, datetime_dict.second
	]
	
	SaveManager.save_data.timestamp.last_played_at = datetime_str
	print("设置上次游玩时间为: ", datetime_str)
	
	# 应用离线变化
	get_node("/root/OfflineTimeManager").check_and_apply_offline_changes()
	
	_print_current_state()
	print("=== 测试完成 ===\n")

func test_long_offline():
	"""测试长时间离线（3天）"""
	print("\n=== 测试长时间离线（3天）===")
	_print_current_state()
	
	# 设置上次游玩时间为3天前
	var three_days_ago = Time.get_unix_time_from_system() - (3600 * 24 * 3)
	var datetime_dict = Time.get_datetime_dict_from_unix_time(three_days_ago)
	var datetime_str = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime_dict.year, datetime_dict.month, datetime_dict.day,
		datetime_dict.hour, datetime_dict.minute, datetime_dict.second
	]
	
	SaveManager.save_data.timestamp.last_played_at = datetime_str
	print("设置上次游玩时间为: ", datetime_str)
	
	# 应用离线变化
	get_node("/root/OfflineTimeManager").check_and_apply_offline_changes()
	
	_print_current_state()
	print("=== 测试完成 ===\n")

func reset_time():
	"""重置时间为当前时间"""
	print("\n=== 重置时间 ===")
	SaveManager.save_data.timestamp.last_played_at = Time.get_datetime_string_from_system()
	print("已重置上次游玩时间为当前时间")
	SaveManager.save_game(SaveManager.current_slot)
	print("=== 重置完成 ===\n")

func _print_current_state():
	"""打印当前状态"""
	print("当前状态:")
	print("  好感度: ", SaveManager.get_affection())
	print("  回复意愿: ", SaveManager.get_reply_willingness())
	print("  心情: ", SaveManager.get_mood())
	print("  上次游玩时间: ", SaveManager.save_data.timestamp.last_played_at)
