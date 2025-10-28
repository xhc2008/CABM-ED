extends Control

@onready var background: TextureRect = $Background
@onready var sidebar = $Sidebar
@onready var character = $Background/Character
@onready var chat_dialog = $ChatDialog
@onready var action_menu = $ActionMenu
@onready var scene_menu = $SceneMenu
@onready var right_click_area = $Background/RightClickArea
@onready var debug_helper = $CharacterDebugHelper
@onready var audio_manager = $AudioManager
@onready var character_diary_button = $CharacterDiaryButton if has_node("CharacterDiaryButton") else null
@onready var character_diary_viewer = $CharacterDiaryViewer if has_node("CharacterDiaryViewer") else null

var current_scene: String = ""
var current_weather: String = ""
var current_time: String = "day"
var scenes_config: Dictionary = {}

# 场景区域信息
var scene_rect: Rect2 = Rect2()
var scene_scale: Vector2 = Vector2.ONE

# 失败消息标签
var failure_message_label: Label = null
var failure_message_tween: Tween = null

# 场景切换控制
var scene_switch_timer: Timer = null
var pending_chat_timer: Timer = null



func _ready():
	# 检查并迁移旧日记数据
	_check_and_migrate_diary()
	
	# 初始化管理器
	_setup_managers()
	
	# 初始化场景切换控制
	_setup_scene_switch_control()
	
	# 加载场景配置
	_load_scenes_config()
	
	# 连接侧边栏信号
	sidebar.scene_changed.connect(_on_scene_changed)
	
	# 连接角色信号
	character.character_clicked.connect(_on_character_clicked)
	character.set_background_reference(background)
	
	# 连接聊天对话框信号
	chat_dialog.chat_ended.connect(_on_chat_ended)
	
	# 连接选项菜单信号
	action_menu.action_selected.connect(_on_action_selected)
	action_menu.game_selected.connect(_on_game_selected)
	
	# 连接场景菜单信号
	scene_menu.scene_selected.connect(_on_scene_menu_selected)
	scene_menu.character_called.connect(_on_character_called)
	
	# 连接右侧点击区域
	right_click_area.gui_input.connect(_on_right_area_input)
	
	# 连接角色日记按钮和查看器
	if character_diary_button:
		character_diary_button.diary_selected.connect(_on_character_diary_selected)
	if character_diary_viewer:
		character_diary_viewer.diary_closed.connect(_on_character_diary_closed)
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 等待侧边栏初始化完成（包括自动时间调整）
	await get_tree().process_frame
	
	# 尝试从存档加载场景，否则加载默认场景
	var initial_scene = _load_initial_scene()
	# 从侧边栏获取当前的时间和天气设置（可能已经被自动时间调整过）
	var initial_weather = sidebar.current_weather_id
	var initial_time = sidebar.current_time_id
	load_scene(initial_scene, initial_weather, initial_time)
	
	# 同步 sidebar 的当前场景，避免天气/时间变化时切换到错误的场景
	sidebar.set_current_scene(initial_scene)
	
	# 初始化UI布局
	await get_tree().process_frame
	_update_ui_layout()
	
	# 检查是否有待应用的离线位置变化
	_check_pending_offline_position_change()
	
	# 播放背景音乐
	audio_manager.play_background_music(initial_scene, initial_time, initial_weather)

func _input(event):
	# 按 F12 打开存档调试面板
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_show_save_debug_panel()
	


func _load_initial_scene() -> String:
	"""从存档加载初始场景，如果没有或不合法则返回默认场景"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		var saved_scene = save_mgr.get_character_scene()
		
		# 验证场景是否合法
		if saved_scene != "" and _is_valid_scene(saved_scene):
			print("从存档加载场景: ", saved_scene)
			return saved_scene
		elif saved_scene != "":
			print("警告: 存档中的场景 '%s' 不合法，使用默认场景" % saved_scene)
			# 清除不合法的场景
			save_mgr.set_character_scene("")
	
	print("使用默认场景: livingroom")
	return "livingroom"

func _is_valid_scene(scene_id: String) -> bool:
	"""验证场景ID是否合法（同时存在于scenes.json和character_presets.json中）"""
	# 检查scenes.json
	if not scenes_config.has(scene_id):
		print("场景验证失败: '%s' 不在 scenes.json 中" % scene_id)
		return false
	
	# 检查character_presets.json
	var presets_path = "res://config/character_presets.json"
	if not FileAccess.file_exists(presets_path):
		print("场景验证失败: character_presets.json 不存在")
		return false
	
	var file = FileAccess.open(presets_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("场景验证失败: character_presets.json 解析错误")
		return false
	
	var presets_config = json.data
	if not presets_config.has(scene_id):
		print("场景验证失败: '%s' 不在 character_presets.json 中" % scene_id)
		return false
	
	if presets_config[scene_id].size() == 0:
		print("场景验证失败: '%s' 没有角色预设" % scene_id)
		return false
	
	return true

func _setup_managers():
	"""初始化各种管理器"""
	# 等待自动加载节点准备好
	await get_tree().process_frame
	
	# 连接事件管理器信号
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.event_completed.connect(_on_event_completed)
	else:
		print("警告: EventManager 未找到，请检查自动加载配置")
	
	# 连接SaveManager的角色场景变化信号
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.character_scene_changed.connect(_on_character_scene_changed)
	
	# 注册可交互UI元素到UIManager
	if has_node("/root/UIManager"):
		var ui_mgr = get_node("/root/UIManager")
		ui_mgr.register_element(right_click_area)
		if character_diary_button:
			ui_mgr.register_element(character_diary_button)
	else:
		print("警告: UIManager 未找到，请检查自动加载配置")
	
	# 创建失败消息标签
	failure_message_label = Label.new()
	failure_message_label.visible = false
	failure_message_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	failure_message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	failure_message_label.add_theme_constant_override("outline_size", 2)
	failure_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_message_label.z_index = 100
	add_child(failure_message_label)
	


func _setup_scene_switch_control():
	"""初始化场景切换控制计时器"""
	# 场景切换锁定计时器（禁用右侧点击区域）
	scene_switch_timer = Timer.new()
	scene_switch_timer.one_shot = true
	scene_switch_timer.timeout.connect(_on_scene_switch_timeout)
	add_child(scene_switch_timer)
	
	# 待触发聊天计时器
	pending_chat_timer = Timer.new()
	pending_chat_timer.one_shot = true
	add_child(pending_chat_timer)

func _load_scenes_config():
	var config_path = "res://config/scenes.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var data = json.data
			# 新格式：scenes 在 data.scenes 中
			scenes_config = data.get("scenes", {})
			print("场景配置已加载: ", scenes_config.keys())
		else:
			print("解析场景配置失败")
	else:
		print("场景配置文件不存在")

func _process(_delta):
	# 持续更新场景区域信息
	_calculate_scene_rect()
	
	# 如果聊天框可见，持续更新其位置（因为高度可能在动画中变化）
	if chat_dialog.visible:
		_update_chat_dialog_layout()

func _calculate_scene_rect():
	"""计算场景图片在屏幕上的实际显示区域"""
	if background.texture == null:
		scene_rect = Rect2(Vector2.ZERO, get_viewport_rect().size)
		scene_scale = Vector2.ONE
		return
	
	var texture_size = background.texture.get_size()
	var container_size = background.size
	
	# 根据 stretch_mode = 5 (keep aspect centered) 计算实际显示区域
	var scale_x = container_size.x / texture_size.x
	var scale_y = container_size.y / texture_size.y
	var img_scale = min(scale_x, scale_y)
	
	scene_scale = Vector2(img_scale, img_scale)
	
	var scaled_size = texture_size * img_scale
	var offset = (container_size - scaled_size) / 2.0
	
	scene_rect = Rect2(offset, scaled_size)

func _on_viewport_size_changed():
	"""窗口大小变化时更新UI布局"""
	_update_ui_layout()

func _update_ui_layout():
	"""更新所有UI组件的位置和大小，使其与场景绑定"""
	_calculate_scene_rect()
	
	# 更新侧边栏 - 固定在场景左侧
	_update_sidebar_layout()
	
	# 更新聊天对话框 - 固定在场景底部
	_update_chat_dialog_layout()
	
	# 更新角色日记按钮 - 固定在场景左下角
	_update_character_diary_button_layout()
	
	# 更新角色日记查看器 - 居中显示
	_update_character_diary_viewer_layout()
	

	
	# 如果动作菜单可见，更新其位置
	if action_menu.visible:
		_update_action_menu_position()

func _update_sidebar_layout():
	"""更新侧边栏布局，使其与场景左侧对齐"""
	sidebar.position = scene_rect.position
	sidebar.size.y = scene_rect.size.y
	sidebar.custom_minimum_size.y = scene_rect.size.y

func _update_chat_dialog_layout():
	"""更新聊天对话框布局，使其与场景底部对齐"""
	# 使用实际size而不是custom_minimum_size，因为在动画过程中size会实时变化
	var dialog_height = chat_dialog.size.y
	
	# 计算侧边栏的实际宽度
	var sidebar_width = sidebar.size.x if sidebar.visible else 0.0
	
	# 聊天框从侧边栏右侧开始，到场景右侧结束
	var dialog_x = scene_rect.position.x + sidebar_width
	var dialog_width = scene_rect.size.x - sidebar_width
	
	# 确保聊天框不会超出场景范围
	if dialog_x + dialog_width > scene_rect.position.x + scene_rect.size.x:
		dialog_width = scene_rect.position.x + scene_rect.size.x - dialog_x
	
	# 聊天框底部对齐场景底部
	var dialog_y = scene_rect.position.y + scene_rect.size.y - dialog_height
	
	# 确保不会超出场景顶部
	if dialog_y < scene_rect.position.y:
		dialog_y = scene_rect.position.y
	
	chat_dialog.position = Vector2(dialog_x, dialog_y)
	chat_dialog.size.x = dialog_width
	chat_dialog.custom_minimum_size.x = dialog_width

func _update_action_menu_position():
	"""更新动作菜单位置，确保在场景范围内"""
	var menu_pos = action_menu.position
	
	# 确保菜单在场景范围内
	if menu_pos.x + action_menu.size.x > scene_rect.position.x + scene_rect.size.x:
		menu_pos.x = scene_rect.position.x + scene_rect.size.x - action_menu.size.x - 10
	
	if menu_pos.x < scene_rect.position.x:
		menu_pos.x = scene_rect.position.x + 10
	
	if menu_pos.y + action_menu.size.y > scene_rect.position.y + scene_rect.size.y:
		menu_pos.y = scene_rect.position.y + scene_rect.size.y - action_menu.size.y - 10
	
	if menu_pos.y < scene_rect.position.y:
		menu_pos.y = scene_rect.position.y + 10
	
	action_menu.position = menu_pos

func load_scene(scene_id: String, weather_id: String, time_id: String):
	# 记录场景是否真的改变了
	var scene_changed = (current_scene != scene_id)
	
	current_scene = scene_id
	current_weather = weather_id
	current_time = time_id
	
	# 保存到 SaveManager
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.set_current_weather(weather_id)
		save_mgr.set_current_time(time_id)
	
	var image_path = "res://assets/images/%s/%s/%s.png" % [scene_id, weather_id, time_id]
	
	# 尝试加载图片
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		background.texture = texture
		print("已加载: ", image_path)
	else:
		print("图片不存在: ", image_path)
		# 显示占位符
		background.texture = null
	
	# 等待背景纹理完全加载和渲染
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 计算场景区域，确保角色加载时可以使用正确的坐标
	_calculate_scene_rect()
	
	# 只有在场景真正改变时才重新加载角色位置
	if scene_changed:
		character.load_character_for_scene(scene_id)
	
	# 场景变化后更新UI布局
	await get_tree().process_frame
	_update_ui_layout()
	
	# 更新角色日记按钮显示状态
	_update_character_diary_button_visibility()
	
	# 切换背景音乐
	audio_manager.play_background_music(scene_id, time_id, weather_id)

func _on_scene_changed(scene_id: String, weather_id: String, time_id: String):
	# 记录旧场景
	var old_scene = current_scene
	
	# 检查场景是否真的改变了
	# 只有当 current_scene 不为空且与 scene_id 不同时，才认为是场景切换
	# 如果 current_scene 为空，说明是初始化阶段，不应该切换场景
	var scene_actually_changed = (current_scene != "" and scene_id != current_scene)
	
	# 场景切换时取消待触发的聊天
	if scene_actually_changed:
		_cancel_pending_chat()
		_lock_scene_switch()
	
	# 决定目标场景：
	# - 如果场景真的改变了，使用新场景
	# - 如果场景没改变或 current_scene 为空，保持当前场景
	var target_scene = scene_id if scene_actually_changed else current_scene
	
	# 如果 target_scene 仍然为空（初始化阶段），直接返回，不做任何操作
	if target_scene == "":
		print("场景为空，忽略此次变化")
		return
	
	# 加载场景（或只更新天气/时间）
	load_scene(target_scene, weather_id, time_id)
	
	# 如果场景真的改变了，同步更新 sidebar 的场景
	if scene_actually_changed:
		sidebar.set_current_scene(target_scene)
	
	# 等待场景加载完成
	await get_tree().process_frame
	
	# 只有在场景真正改变时，才尝试触发场景交互
	if scene_actually_changed:
		# 优先级：进入 > 离开
		# 如果进入有角色的场景，触发进入事件
		if _has_character_in_scene(target_scene):
			_try_scene_interaction("enter_scene")
		# 否则，如果离开了有角色的场景，触发离开事件
		elif _has_character_in_scene(old_scene):
			_try_scene_interaction("leave_scene")

func _on_scene_menu_selected(scene_id: String):
	# 记录旧场景
	var old_scene = current_scene
	
	# 场景切换时取消待触发的聊天
	if old_scene != scene_id:
		_cancel_pending_chat()
		_lock_scene_switch()
	
	# 切换到选中的场景，保持当前天气和时间
	load_scene(scene_id, current_weather, current_time)
	# 更新侧边栏显示的场景
	sidebar.set_current_scene(scene_id)
	
	# 等待场景加载完成
	await get_tree().process_frame
	
	# 优先级：进入 > 离开
	# 如果进入有角色的场景，触发进入事件
	if _has_character_in_scene(scene_id):
		_try_scene_interaction("enter_scene")
	# 否则，如果离开了有角色的场景，触发离开事件
	elif _has_character_in_scene(old_scene):
		_try_scene_interaction("leave_scene")

func _on_character_clicked(char_position: Vector2, char_size: Vector2):
	# 尝试交互
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		var result = event_mgr.on_character_clicked()
		if not result.success:
			if result.message != "":
				_show_failure_message(result.message)
			return
	else:
		print("警告: EventManager 未找到")
	
	# 角色被点击，显示选项菜单
	# 将角色位置转换为场景坐标
	var scene_char_pos = scene_rect.position + char_position
	
	# 计算菜单位置（角色右侧）
	var menu_pos = Vector2(
		scene_char_pos.x + char_size.x + 10,
		scene_char_pos.y
	)
	
	# 确保菜单不超出场景范围
	var scene_right = scene_rect.position.x + scene_rect.size.x
	var scene_bottom = scene_rect.position.y + scene_rect.size.y
	
	if menu_pos.x + action_menu.custom_minimum_size.x > scene_right:
		# 如果右侧放不下，放在左侧
		menu_pos.x = scene_char_pos.x - action_menu.custom_minimum_size.x - 10
	
	# 确保不超出场景底部
	if menu_pos.y + action_menu.size.y > scene_bottom:
		menu_pos.y = scene_bottom - action_menu.size.y - 10
	
	# 确保不超出场景顶部和左侧
	menu_pos.x = max(menu_pos.x, scene_rect.position.x + 10)
	menu_pos.y = max(menu_pos.y, scene_rect.position.y + 10)
	
	action_menu.show_menu(menu_pos, current_scene)

func _on_action_selected(action: String):
	if action == "chat":
		# 尝试聊天交互
		if has_node("/root/EventManager"):
			var event_mgr = get_node("/root/EventManager")
			var result = event_mgr.on_user_start_chat()
			if result.success:
				# 获取聊天模式（从 result.message 中）
				var chat_mode = result.message if result.message != "" else "passive"
				# 开始聊天
				character.start_chat()
				chat_dialog.show_dialog(chat_mode)
				# 禁用所有UI交互
				if has_node("/root/UIManager"):
					get_node("/root/UIManager").disable_all()
			else:
				# 显示失败消息
				if result.message != "":
					_show_failure_message(result.message)
		else:
			# 如果管理器未加载，直接开始聊天
			character.start_chat()
			chat_dialog.show_dialog("passive")
			# 禁用所有UI交互
			if has_node("/root/UIManager"):
				get_node("/root/UIManager").disable_all()

func _on_game_selected(game_type: String):
	print("游戏选择信号接收: ", game_type)
	if game_type == "gomoku":
		_start_gomoku_game()

func _on_chat_ended():
	# 聊天结束，角色返回场景（会自动处理位置变动和字幕）
	await character.end_chat()
	
	# 重新启用所有UI交互
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").enable_all()

func _start_gomoku_game():
	print("开始加载五子棋游戏")
	# 加载五子棋场景
	var gomoku_scene = load("res://scenes/gomoku_game.tscn")
	if gomoku_scene:
		print("五子棋场景加载成功")
		var gomoku = gomoku_scene.instantiate()
		gomoku.game_ended.connect(_on_gomoku_ended)
		
		# 隐藏主场景元素
		_hide_main_scene()
		
		# 添加游戏场景
		add_child(gomoku)
		gomoku.z_index = 100
		print("五子棋游戏已添加到场景树")
	else:
		print("错误：无法加载五子棋场景")

func _hide_main_scene():
	# 隐藏主场景的交互元素
	sidebar.visible = false
	character.visible = false
	action_menu.visible = false
	scene_menu.visible = false
	if character_diary_button:
		character_diary_button.visible = false
	
	# 停止计时器
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.pause_timers()

func _show_main_scene():
	# 恢复主场景元素
	sidebar.visible = true
	_update_ui_layout()
	
	# 重新加载角色
	character.load_character_for_scene(current_scene)
	
	# 恢复计时器
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.resume_timers()

func _on_gomoku_ended():
	# 移除游戏场景
	for child in get_children():
		if child.name == "GomokuGame":
			child.queue_free()
	
	# 恢复主场景
	_show_main_scene()


func _on_character_scene_changed(new_scene: String):
	"""角色场景变化时的处理"""
	print("角色场景变化: ", new_scene)
	
	# 检查是否是首次初始化
	var is_first_init = false
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.has_meta("is_first_scene_init"):
			is_first_init = true
			save_mgr.remove_meta("is_first_scene_init")
	
	# 首次初始化不显示字幕
	if is_first_init:
		print("首次初始化场景，不显示字幕")
		character.load_character_for_scene(current_scene)
		return
	
	# 检查是否需要显示字幕通知
	var show_notification = true
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.has_meta("show_move_notification"):
			show_notification = save_mgr.get_meta("show_move_notification")
			save_mgr.remove_meta("show_move_notification")
	
	# 显示字幕提示（聊天结束时显示，空闲超时不显示）
	if show_notification:
		_show_character_move_message(new_scene)
	
	# 重新加载角色，这会根据当前用户所在场景决定角色是否可见
	# 如果用户在角色的新场景，角色会显示
	# 如果用户不在角色的新场景，角色会被隐藏
	character.load_character_for_scene(current_scene)

func _show_character_move_message(new_scene: String):
	"""显示角色移动的提示消息"""
	# 获取角色名称
	var character_name = "角色"
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		character_name = helpers.get_character_name()
	
	# 获取场景名称
	var scene_name = _get_scene_name(new_scene)
	
	# 显示信息消息
	var message = "%s去%s了" % [character_name, scene_name]
	_show_info_message(message)

func _get_scene_name(scene_id: String) -> String:
	"""获取场景名称"""
	if scenes_config.has(scene_id):
		return scenes_config[scene_id].get("name", scene_id)
	return scene_id

func _on_right_area_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查是否在场景切换锁定期间
			if scene_switch_timer and not scene_switch_timer.is_stopped():
				print("场景切换锁定中，忽略点击")
				return
			
			var click_pos = event.position
			
			# 检查是否点击在场景右侧区域（右侧1/4）
			var right_threshold = scene_rect.position.x + scene_rect.size.x * 0.75
			
			if click_pos.x >= right_threshold and scene_rect.has_point(click_pos):
				# 点击在右侧区域，显示场景切换菜单
				_show_scene_menu(click_pos)

func _show_scene_menu(at_position: Vector2):
	# 设置场景菜单
	scene_menu.setup_scenes(scenes_config, current_scene)
	
	# 计算菜单位置（点击位置左侧）
	await get_tree().process_frame # 等待菜单大小更新
	
	var menu_pos = Vector2(
		at_position.x - scene_menu.size.x - 10,
		at_position.y
	)
	
	# 确保菜单在场景范围内
	var scene_bottom = scene_rect.position.y + scene_rect.size.y
	
	menu_pos.x = max(menu_pos.x, scene_rect.position.x + 10)
	menu_pos.y = max(menu_pos.y, scene_rect.position.y + 10)
	
	if menu_pos.y + scene_menu.size.y > scene_bottom:
		menu_pos.y = scene_bottom - scene_menu.size.y - 10
	
	scene_menu.show_menu(menu_pos)

func _on_event_completed(event_name: String, result):
	"""事件完成处理"""
	if result.success:
		print("事件成功: ", event_name)
		
		# 处理空闲超时事件的特殊情况
		if event_name == "idle_timeout":
			if result.message == "active":
				# 触发主动聊天
				_trigger_active_chat()
			elif result.message == "idle_position_change":
				# 触发位置变动
				_trigger_idle_position_change()
			elif result.message == "auto_continue":
				# 等待继续时超时，自动继续
				_auto_continue_chat()
			elif result.message == "timeout_to_input":
				# 回复模式或历史模式超时，显示提示
				# chat_dialog._on_event_completed 会处理切换到输入模式和退出的逻辑
				_force_end_chat()
			elif result.message == "chat_idle_timeout":
				# 输入模式超时，显示提示并结束聊天
				_force_end_chat()
				# 调用chat_dialog的正常结束流程（包括总结模型等）
				chat_dialog._on_end_button_pressed()
	else:
		print("事件失败: ", event_name)
		# 失败消息已在各个事件调用处处理

func _trigger_active_chat():
	"""触发角色主动聊天"""
	# 检查角色是否在当前场景且可见
	if not character.visible or character.is_chatting:
		return
	
	# 检查聊天对话框是否已经打开（防止在对话中途触发主动聊天）
	if chat_dialog.visible:
		print("聊天对话框已打开，忽略主动聊天触发")
		return
	
	# 检查是否在有角色的场景
	if not _has_character_in_scene(current_scene):
		return
	
	print("触发角色主动聊天")
	
	# 重置空闲计时器
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		event_mgr.reset_idle_timer()
	
	character.start_chat()
	chat_dialog.show_dialog("active")
	# 禁用所有UI交互
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").disable_all()

func _trigger_idle_position_change():
	"""触发空闲时的位置变动（无字幕播报）"""
	# 检查角色是否正在聊天
	if character.is_chatting:
		return
	
	print("触发空闲位置变动（无字幕）")
	
	# 静默应用位置变动（不显示字幕）
	await character.apply_position_probability_silent()

func _auto_continue_chat():
	"""自动继续聊天（等待继续时超时）"""
	if chat_dialog.visible and chat_dialog.waiting_for_continue:
		print("等待继续时超时，自动继续")
		# 调用聊天框的继续点击处理
		chat_dialog._on_continue_clicked()

func _force_end_chat():
	"""强制结束聊天（由于空闲超时）并显示提示"""
	if chat_dialog.visible:
		print("聊天空闲超时，强制结束聊天")
		
		# 获取角色名称
		var character_name = "角色"
		if has_node("/root/EventHelpers"):
			var helpers = get_node("/root/EventHelpers")
			character_name = helpers.get_character_name()
		
		# 显示提示消息
		_show_failure_message(character_name + "默默离开了")
		
		# 注意：对于不同的超时情况：
		# - timeout_to_input: chat_dialog._on_event_completed 会处理切换到输入模式和退出
		# - chat_idle_timeout: 需要直接调用结束流程
		# 这里不做任何操作，让调用者决定后续流程

func _show_failure_message(message: String):
	"""显示失败消息（红色）"""
	_show_message(message, Color(1, 0.3, 0.3))

func _show_info_message(message: String):
	"""显示信息消息（蓝色）"""
	_show_message(message, Color(0.5, 0.8, 1.0))

func _show_message(message: String, color: Color):
	"""显示消息（通用函数）"""
	if failure_message_label == null:
		return
	
	# 如果有正在运行的 tween，先停止并清除
	if failure_message_tween != null and failure_message_tween.is_valid():
		failure_message_tween.kill()
	
	# 设置消息文本和颜色
	failure_message_label.text = message
	failure_message_label.add_theme_color_override("font_color", color)
	
	# 计算位置（场景中央偏上）
	var label_pos = Vector2(
		scene_rect.position.x + scene_rect.size.x / 2,
		scene_rect.position.y + scene_rect.size.y * 0.3
	)
	
	failure_message_label.position = label_pos
	failure_message_label.size = Vector2.ZERO # 自动调整大小
	
	# 居中对齐
	await get_tree().process_frame
	failure_message_label.position.x -= failure_message_label.size.x / 2
	
	# 显示动画
	failure_message_label.modulate.a = 0.0
	failure_message_label.visible = true
	
	failure_message_tween = create_tween()
	failure_message_tween.tween_property(failure_message_label, "modulate:a", 1.0, 0.3)
	failure_message_tween.tween_interval(2.0)
	failure_message_tween.tween_property(failure_message_label, "modulate:a", 0.0, 0.5)
	
	await failure_message_tween.finished
	failure_message_label.visible = false
	failure_message_tween = null

func _has_character_in_scene(scene_id: String) -> bool:
	"""检查角色是否真的在指定场景（不是配置，而是实际位置）"""
	if not has_node("/root/SaveManager"):
		return false
	
	var save_mgr = get_node("/root/SaveManager")
	var character_scene = save_mgr.get_character_scene()
	
	return character_scene == scene_id

func _try_scene_interaction(action_id: String):
	"""尝试场景交互（进入/离开）- 只触发对话，不触发位置变动"""
	if not has_node("/root/EventManager"):
		return
	
	var event_mgr = get_node("/root/EventManager")
	var result
	
	if action_id == "enter_scene":
		result = event_mgr.on_enter_scene()
	elif action_id == "leave_scene":
		result = event_mgr.on_leave_scene()
	else:
		return
	
	if result.success:
		# 成功触发，延迟触发聊天
		print("场景交互成功，延迟触发聊天: ", action_id)
		
		# 隐藏场景菜单（如果可见）
		if scene_menu.visible:
			scene_menu.hide_menu()
		
		# 使用计时器延迟触发，这样可以被取消
		pending_chat_timer.wait_time = 0.5
		pending_chat_timer.timeout.connect(_on_pending_chat_timeout.bind(result.message), CONNECT_ONE_SHOT)
		pending_chat_timer.start()
	else:
		print("场景交互失败或在冷却中: ", action_id)


func _on_pending_chat_timeout(chat_mode: String):
	"""延迟聊天触发"""
	# 再次检查角色是否还在当前场景（防止概率移动或其他原因导致的问题）
	if not _has_character_in_scene(current_scene):
		print("角色已不在当前场景，取消对话触发")
		return
	
	# 确保角色可见且不在聊天状态
	if not character.visible or character.is_chatting:
		print("角色不可见或正在聊天，取消对话触发")
		return
	
	var mode = chat_mode if chat_mode != "" else "passive"
	character.start_chat()
	chat_dialog.show_dialog(mode)
	# 禁用所有UI交互
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").disable_all()
	print("延迟聊天已触发")
func _cancel_pending_chat():
	"""取消待触发的聊天"""
	if pending_chat_timer and not pending_chat_timer.is_stopped():
		pending_chat_timer.stop()
		# 断开所有连接
		for connection in pending_chat_timer.timeout.get_connections():
			pending_chat_timer.timeout.disconnect(connection["callable"])
		print("已取消待触发的聊天")

func _lock_scene_switch():
	"""锁定场景切换（禁用右侧点击区域1秒）"""
	if scene_switch_timer:
		scene_switch_timer.start(1.0)
		print("场景切换已锁定1秒")

func _on_scene_switch_timeout():
	"""场景切换锁定超时"""
	print("场景切换锁定解除")

func _show_save_debug_panel():
	"""显示存档调试面板"""
	var debug_panel_scene = load("res://scenes/save_debug_panel.tscn")
	if debug_panel_scene:
		var debug_panel = debug_panel_scene.instantiate()
		add_child(debug_panel)



func _check_pending_offline_position_change():
	"""检查并应用待处理的离线位置变化"""
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	if save_mgr.has_meta("pending_offline_position_change"):
		print("检测到待应用的离线位置变化")
		save_mgr.remove_meta("pending_offline_position_change")
		
		# 静默应用位置变化（不显示字幕）
		await character.apply_position_probability_silent()
		print("离线位置变化已应用")

func _update_character_diary_button_layout():
	"""更新角色日记按钮布局"""
	if character_diary_button == null:
		return
	
	# 使用配置管理器计算位置
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		var element_size = character_diary_button.size
		character_diary_button.position = mgr.calculate_element_position("character_diary_button", scene_rect, element_size)
	else:
		# 降级方案：使用默认位置（在玩家日记按钮旁边）
		var button_x = scene_rect.position.x + 120
		var button_y = scene_rect.position.y + scene_rect.size.y - character_diary_button.size.y - 130
		character_diary_button.position = Vector2(button_x, button_y)

func _update_character_diary_viewer_layout():
	"""更新角色日记查看器布局（居中显示）"""
	if character_diary_viewer == null:
		return
	
	# 日记查看器居中显示在场景区域
	var viewer_x = scene_rect.position.x + (scene_rect.size.x - character_diary_viewer.size.x) / 2
	var viewer_y = scene_rect.position.y + (scene_rect.size.y - character_diary_viewer.size.y) / 2
	
	character_diary_viewer.position = Vector2(viewer_x, viewer_y)



func _update_character_diary_button_visibility():
	"""更新角色日记按钮的显示状态（根据配置决定在哪些场景显示）"""
	if character_diary_button == null:
		return
	
	# 使用配置管理器检查是否应该显示
	var should_show = false
	if has_node("/root/InteractiveElementManager"):
		var mgr = get_node("/root/InteractiveElementManager")
		should_show = mgr.should_show_in_scene("character_diary_button", current_scene) and mgr.is_element_enabled("character_diary_button")
	else:
		# 降级方案：只在bedroom显示
		should_show = (current_scene == "bedroom")
	
	if should_show:
		character_diary_button.enable()
	else:
		character_diary_button.disable()

func _on_character_diary_selected():
	"""角色日记选项被选中"""
	if character_diary_viewer:
		character_diary_viewer.show_diary()

func _on_character_diary_closed():
	"""角色日记查看器关闭事件"""
	print("角色日记查看器已关闭")

func _check_and_migrate_diary():
	"""检查并迁移旧日记数据"""
	var migration = preload("res://scripts/diary_migration.gd").new()
	
	# 检查是否需要迁移
	if migration.check_needs_migration():
		print("检测到旧的日记数据，开始自动迁移...")
		var count = migration.migrate_diary_data()
		print("日记迁移完成，共处理 %d 条记录" % count)
	else:
		print("未检测到需要迁移的旧日记数据")

func _on_character_called():
	"""呼唤角色事件"""
	print("用户呼唤角色")
	
	# 尝试呼唤交互
	if has_node("/root/EventManager"):
		var event_mgr = get_node("/root/EventManager")
		var result = event_mgr.on_character_called()
		
		if result.success:
			# 呼唤成功
			print("呼唤成功")
			
			# 检查角色是否在当前场景
			var character_scene = ""
			if has_node("/root/SaveManager"):
				var save_mgr = get_node("/root/SaveManager")
				character_scene = save_mgr.get_character_scene()
			
			if character_scene == current_scene:
				# 角色已在当前场景，直接触发对话（不包含场景名）
				_start_called_chat(true)
			else:
				# 角色不在当前场景，移动角色到当前场景（包含场景名）
				_move_character_to_current_scene()
		else:
			# 呼唤失败，显示失败消息
			if result.message != "":
				_show_failure_message(result.message)
	else:
		print("警告: EventManager 未找到")

func _start_called_chat(already_here: bool = false):
	"""开始被呼唤后的对话
	
	already_here: 角色是否已经在当前场景
	"""
	character.start_chat()
	# 根据角色是否已在场景选择不同的对话模式
	var chat_mode = "called_here" if already_here else "called"
	chat_dialog.show_dialog(chat_mode)
	# 禁用所有UI交互
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").disable_all()

func _move_character_to_current_scene():
	"""将角色移动到当前场景并触发对话"""
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		
		# 保存角色原来的场景（用于提示词）
		var old_scene = save_mgr.get_character_scene()
		save_mgr.set_meta("character_old_scene", old_scene)
		
		# 设置不显示移动通知（因为是被呼唤来的）
		save_mgr.set_meta("show_move_notification", false)
		
		# 移动角色到当前场景
		save_mgr.set_character_scene(current_scene)
		
		# 等待角色加载完成（多等待几帧确保背景和角色都准备好）
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		
		# 再次验证角色是否成功加载
		if not character.visible:
			print("警告: 角色加载后仍不可见")
		
		# 触发对话
		_start_called_chat()
