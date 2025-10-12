extends PanelContainer

# 存档调试面板 - 用于在手机上测试存档功能

@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var test_button: Button = $MarginContainer/VBoxContainer/TestButton
@onready var ai_test_button: Button = $MarginContainer/VBoxContainer/AITestButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

func _ready():
	test_button.pressed.connect(_on_test_pressed)
	ai_test_button.pressed.connect(_on_ai_test_pressed)
	close_button.pressed.connect(_on_close_pressed)
	_update_info()

func _on_test_pressed():
	"""测试存档功能"""
	if not has_node("/root/SaveManager"):
		info_label.text = "错误: SaveManager 未找到"
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# 测试保存
	var test_value = randi() % 1000
	save_mgr.set_affection(test_value)
	var success = save_mgr.save_game(1)
	
	# 等待一帧
	await get_tree().process_frame
	
	# 测试加载
	var load_success = save_mgr.load_game(1)
	var loaded_value = save_mgr.get_affection()
	
	# 显示结果
	_update_info()
	
	if success and load_success and loaded_value == test_value:
		info_label.text += "\n\n✓ 测试成功！\n保存值: %d\n读取值: %d" % [test_value, loaded_value]
	else:
		info_label.text += "\n\n✗ 测试失败！\n保存: %s\n加载: %s\n保存值: %d\n读取值: %d" % [
			"成功" if success else "失败",
			"成功" if load_success else "失败",
			test_value,
			loaded_value
		]

func _update_info():
	"""更新存档信息显示"""
	var info = "=== 存档调试信息 ===\n\n"
	
	# 显示存档路径
	var save_path = "user://saves/save_slot_1.json"
	info += "存档路径:\n%s\n\n" % ProjectSettings.globalize_path(save_path)
	
	# 显示 user:// 实际路径
	info += "user:// 路径:\n%s\n\n" % OS.get_user_data_dir()
	
	# 检查文件是否存在
	var exists = FileAccess.file_exists(save_path)
	info += "存档文件: %s\n\n" % ("存在" if exists else "不存在")
	
	# 如果 SaveManager 存在，显示当前数据
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		info += "当前好感度: %d\n" % save_mgr.get_affection()
		info += "当前场景: %s\n\n" % save_mgr.get_character_scene()
	
	# AI 状态检查
	info += "=== AI 状态 ===\n\n"
	
	# 检查 API 密钥
	var key_path = "user://api_keys.json"
	var has_key = FileAccess.file_exists(key_path)
	info += "API 密钥文件: %s\n" % ("存在" if has_key else "不存在")
	
	if has_key:
		var file = FileAccess.open(key_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var keys = json.data
				var api_key = keys.get("openai_api_key", "")
				if api_key.is_empty():
					info += "API 密钥: 空\n"
				else:
					info += "API 密钥: 已配置 (%d 字符)\n" % api_key.length()
	
	# 检查日志目录
	var log_dir = DirAccess.open("user://")
	if log_dir:
		var has_log_dir = log_dir.dir_exists("ai_logs")
		info += "日志目录: %s\n" % ("存在" if has_log_dir else "不存在")
		
		if has_log_dir:
			var log_path = "user://ai_logs/log.txt"
			var has_log = FileAccess.file_exists(log_path)
			info += "日志文件: %s\n" % ("存在" if has_log else "不存在")
	else:
		info += "错误: 无法访问 user:// 目录\n"
	
	# 检查 AIService
	if has_node("/root/AIService"):
		var ai_service = get_node("/root/AIService")
		info += "AIService: 已加载\n"
		info += "API 密钥状态: %s\n" % ("已配置" if not ai_service.api_key.is_empty() else "未配置")
	else:
		info += "AIService: 未找到\n"
	
	info_label.text = info

func _on_ai_test_pressed():
	"""测试 AI 功能"""
	if not has_node("/root/AIService"):
		info_label.text += "\n\n✗ AIService 未找到"
		return
	
	var ai_service = get_node("/root/AIService")
	
	if ai_service.api_key.is_empty():
		info_label.text += "\n\n✗ API 密钥未配置"
		return
	
	info_label.text += "\n\n正在测试 AI..."
	
	# 连接信号
	if not ai_service.chat_response_received.is_connected(_on_ai_response):
		ai_service.chat_response_received.connect(_on_ai_response)
	if not ai_service.chat_error.is_connected(_on_ai_error):
		ai_service.chat_error.connect(_on_ai_error)
	
	# 发送测试消息
	ai_service.start_chat("你好")

func _on_ai_response(response: String):
	"""AI 响应成功"""
	info_label.text += "\n\n✓ AI 测试成功！\n响应: " + response.substr(0, 50) + "..."

func _on_ai_error(error: String):
	"""AI 响应失败"""
	info_label.text += "\n\n✗ AI 测试失败！\n错误: " + error

func _on_close_pressed():
	queue_free()
