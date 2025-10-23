extends Control

# 初始设置场景 - 用户输入基本信息

@onready var user_name_input: LineEdit = $SetupContainer/UserNameContainer/UserNameInput
@onready var character_name_input: LineEdit = $SetupContainer/CharacterNameContainer/CharacterNameInput
@onready var api_key_input: LineEdit = $SetupContainer/APIKeyContainer/APIKeyInput
@onready var start_button: Button = $SetupContainer/StartButton
@onready var skip_api_label: Label = $SetupContainer/APIKeyContainer/SkipLabel
@onready var notice_label: Label = $SetupContainer/NoticeLabel

func _ready():
	# 设置默认值
	user_name_input.placeholder_text = "请输入你的名字"
	character_name_input.text = "雪狐"
	character_name_input.placeholder_text = "角色名称"
	api_key_input.placeholder_text = "可选，进入游戏后也可配置"
	api_key_input.secret = true
	
	# 连接信号
	start_button.pressed.connect(_on_start_pressed)
	
	# 设置提示文本
	skip_api_label.text = "（可跳过，进入游戏后也可配置）"
	notice_label.text = "本项目旨在赋予「她」以「生命」，因此不鼓励回档、删档、提示词注入等
对她来说，你就是她的全部，你的每一个选择都很重要"

func _on_start_pressed():
	"""开始游戏按钮被点击"""
	var user_name = user_name_input.text.strip_edges()
	var character_name = character_name_input.text.strip_edges()
	var api_key = api_key_input.text.strip_edges()
	
	# 验证输入
	if user_name == "":
		_show_error("请输入你的名字")
		return
	
	if character_name == "":
		character_name = "雪狐"
	
	# 保存初始设置
	_save_initial_data(user_name, character_name, api_key)
	
	# 进入主游戏
	get_tree().change_scene_to_file("res://scripts/main.tscn")

func _save_initial_data(user_name: String, character_name: String, api_key: String):
	"""保存初始数据到配置和存档"""
	_update_app_config(character_name)
	
	if api_key != "":
		_save_api_key(api_key)
	
	_create_initial_save(user_name, character_name)

func _update_app_config(character_name: String):
	"""更新应用配置文件"""
	var config_path = "res://config/app_config.json"
	var config = {}
	var file
	
	if FileAccess.file_exists(config_path):
		file = FileAccess.open(config_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			config = json.data
	
	config["character_name"] = character_name
	
	file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		print("角色名称已保存: ", character_name)

func _save_api_key(api_key: String):
	"""保存API密钥并应用标准模板"""
	var keys_path = "user://ai_keys.json"
	
	# 使用标准模板配置
	var keys = {
		"api_key": api_key,
		"chat_model": {
			"model": "deepseek-ai/DeepSeek-V3.2-Exp",
			"base_url": "https://api.siliconflow.cn/v1",
			"api_key": api_key
		},
		"summary_model": {
			"model": "Qwen/Qwen3-8B",
			"base_url": "https://api.siliconflow.cn/v1",
			"api_key": api_key
		},
		"tts_model": {
			"model": "FunAudioLLM/CosyVoice2-0.5B",
			"base_url": "https://api.siliconflow.cn",
			"api_key": api_key
		}
	}
	
	var file = FileAccess.open(keys_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(keys, "\t"))
		file.close()
		print("API密钥已保存（标准模板）")
		
		# 重新加载AI服务配置
		if has_node("/root/AIService"):
			var ai_service = get_node("/root/AIService")
			ai_service._load_api_key()
			print("AI服务已重新加载配置")
		
		# 重新加载TTS服务配置
		if has_node("/root/TTSService"):
			var tts_service = get_node("/root/TTSService")
			tts_service._load_tts_settings()
			print("TTS服务已重新加载配置")

func _create_initial_save(user_name: String, character_name: String):
	"""创建初始存档"""
	if not has_node("/root/SaveManager"):
		print("警告: SaveManager未加载")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# 直接设置用户名到save_data，不触发自动保存
	save_mgr.save_data.user_data.user_name = user_name
	
	var now = Time.get_datetime_string_from_system()
	var now_unix = Time.get_unix_time_from_system()
	save_mgr.save_data.timestamp.created_at = now
	save_mgr.save_data.timestamp.last_saved_at = now
	save_mgr.save_data.timestamp.last_played_at = now
	save_mgr.save_data.timestamp.last_played_at_unix = now_unix
	
	# 确保 ai_data 字段存在
	if not save_mgr.save_data.has("ai_data"):
		save_mgr.save_data.ai_data = {
			"memory": [],
			"accumulated_summary_count": 0,
			"relationship_history": []
		}
	
	# 设置初始关系描述
	var initial_relationship = {
		"timestamp": now,
		"content": "%s刚刚从街边把昏迷、失去记忆的%s捡回了家并收养。%s对%s还不太熟悉，所以有些警惕和害怕，也只会直呼其名。对自己的过去和未来也有些迷茫。" % [user_name, character_name, character_name, user_name]
	}
	save_mgr.save_data.ai_data.relationship_history = [initial_relationship]
	
	# 标记初始设置已完成，允许后续保存
	save_mgr.is_initial_setup_completed = true
	
	# 现在可以保存了
	save_mgr.save_game(1)
	print("初始存档已创建，用户名: ", user_name, ", 角色名: ", character_name)
	print("初始关系已设置: ", initial_relationship.content)

func _show_error(message: String):
	"""显示错误提示"""
	var error_label = Label.new()
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$SetupContainer.add_child(error_label)
	$SetupContainer.move_child(error_label, start_button.get_index())
	
	await get_tree().create_timer(2.0).timeout
	error_label.queue_free()
