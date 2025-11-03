extends Panel

# 存档导出面板

@onready var api_key_input: LineEdit = $MarginContainer/VBoxContainer/APIKeyInput
@onready var export_button: Button = $MarginContainer/VBoxContainer/ExportButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

func _ready():
	# 居中显示
	position = (get_viewport_rect().size - size) / 2
	
	# 设置输入框
	api_key_input.placeholder_text = "输入对话模型（或快速配置）的API密钥"
	api_key_input.secret = true
	
	# 连接信号
	export_button.pressed.connect(_on_export_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# 设置状态标签
	status_label.text = "⚠️ 存档将包含包括API密钥在内的一切信息"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

func _on_export_pressed():
	var input_key = api_key_input.text.strip_edges()
	
	if input_key.is_empty():
		_show_status("请输入API密钥", Color(1.0, 0.3, 0.3))
		return
	
	# 验证API密钥
	if not _verify_api_key(input_key):
		_show_status("API密钥验证失败，请输入正确的密钥", Color(1.0, 0.3, 0.3))
		return
	
	# 执行导出
	_export_save(input_key)

func _verify_api_key(input_key: String) -> bool:
	"""验证输入的API密钥是否匹配"""
	var keys_path = "user://ai_keys.json"
	
	if not FileAccess.file_exists(keys_path):
		return false
	
	var file = FileAccess.open(keys_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false
	
	var config = json.data
	
	# 检查 chat_model 的 api_key
	if config.has("chat_model") and config.chat_model.has("api_key"):
		if config.chat_model.api_key == input_key:
			return true
	
	# 检查快速配置的 api_key
	if config.has("api_key"):
		if config.api_key == input_key:
			return true
	
	return false

func _export_save(_api_key: String):
	"""导出存档为zip文件"""
	_show_status("正在导出存档...", Color(0.3, 0.8, 1.0))
	
	# 获取user://目录的实际路径
	var user_path = OS.get_user_data_dir()
	
	# 生成导出文件名（带时间戳）
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var export_filename = "CABM-ED_Save_%s.zip" % timestamp
	
	# 使用文件对话框让用户选择保存位置
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_file = export_filename
	file_dialog.add_filter("*.zip", "存档文件")
	file_dialog.file_selected.connect(_on_export_path_selected.bind(user_path))
	get_tree().root.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_export_path_selected(export_path: String, user_path: String):
	"""用户选择了导出路径"""
	# 使用7z命令打包user目录
	var command = "7z"
	var args = ["a", "-tzip", export_path, user_path + "/*"]
	
	# 尝试执行7z命令
	var output = []
	var exit_code = OS.execute(command, args, output)
	
	if exit_code == 0:
		_show_status("✓ 导出成功: " + export_path, Color(0.3, 1.0, 0.3))
		print("存档导出成功: ", export_path)
	else:
		# 如果7z不可用，尝试使用PowerShell的Compress-Archive
		_export_with_powershell(export_path, user_path)

func _export_with_powershell(export_path: String, user_path: String):
	"""使用PowerShell导出"""
	var ps_command = 'Compress-Archive -Path "%s\\*" -DestinationPath "%s" -Force' % [user_path, export_path]
	var args = ["-Command", ps_command]
	
	var output = []
	var exit_code = OS.execute("powershell", args, output)
	
	if exit_code == 0:
		_show_status("✓ 导出成功: " + export_path, Color(0.3, 1.0, 0.3))
		print("存档导出成功: ", export_path)
	else:
		_show_status("✗ 导出失败，请确保安装了7z或PowerShell", Color(1.0, 0.3, 0.3))
		print("导出失败，输出: ", output)

func _show_status(message: String, color: Color):
	"""显示状态信息"""
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)

func _on_close_pressed():
	queue_free()
