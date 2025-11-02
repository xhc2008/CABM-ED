extends Panel

# 升级版音乐播放器面板
# 支持场景音乐列表、播放模式、拖拽排序等功能

@onready var close_button = $MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var file_dialog = $FileDialog

# 音量调节
@onready var bgm_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / BGMVolume / HBoxContainer / Slider
@onready var bgm_volume_label = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / BGMVolume / HBoxContainer / ValueLabel
@onready var ambient_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / AmbientVolume / HBoxContainer / Slider
@onready var ambient_volume_label = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / AmbientVolume / HBoxContainer / ValueLabel

# 切换音乐选项卡的容器
var scene_list_container
var music_list_container
var play_mode_container
var edit_button
var upload_button
var delete_button
var hint_label

var audio_manager
var save_manager
var selected_scene: String = "all" # 当前选中的场景
var is_edit_mode: bool = false # 是否处于编辑模式
var is_delete_mode: bool = false # 是否处于删除模式
var bgm_files: Array = [] # 所有BGM文件
var custom_bgm_path = "user://custom_bgm/"
var bgm_config: Dictionary = {} # BGM配置
var selected_music_path: String = "" # 当前选中的音乐路径（用于删除）

func _ready():
	# 获取管理器
	audio_manager = get_node("/root/Main/AudioManager")
	save_manager = get_node("/root/SaveManager")
	
	# 获取切换音乐选项卡的节点
	var music_tab = $MarginContainer/VBoxContainer/TabContainer.get_node("切换音乐")
	var hbox = music_tab.get_node("HBoxContainer")
	scene_list_container = hbox.get_node("SceneListPanel/ScrollContainer/SceneList")
	var music_panel = hbox.get_node("MusicPanel/VBoxContainer")
	hint_label = music_panel.get_node("HintLabel")
	music_list_container = music_panel.get_node("ScrollContainer/MusicList")
	var right_panel = hbox.get_node("RightPanel/VBoxContainer")
	play_mode_container = right_panel.get_node("PlayModePanel/VBoxContainer")
	edit_button = right_panel.get_node("EditButton")
	upload_button = right_panel.get_node("UploadButton")
	delete_button = right_panel.get_node("DeleteButton")
	
	# 连接信号
	close_button.pressed.connect(_on_close_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	upload_button.pressed.connect(_on_upload_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	file_dialog.files_selected.connect(_on_files_selected)
	bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	ambient_volume_slider.value_changed.connect(_on_ambient_volume_changed)
	
	# 初始化
	hide()
	_ensure_custom_bgm_directory()
	_load_bgm_config()
	_load_music_list()
	_load_volume_settings()
	
	# 确保提示标签初始隐藏
	if hint_label:
		hint_label.hide()

func show_panel():
	"""显示面板"""
	var viewport_size = get_viewport_rect().size
	position = (viewport_size - size) / 2.0
	
	show()
	_refresh_scene_list()
	_update_ui_for_scene()  # 更新按钮显示
	_refresh_music_list()
	_load_volume_settings()

func _on_close_pressed():
	"""关闭按钮"""
	# 如果处于编辑模式，先退出编辑模式
	if is_edit_mode:
		_exit_edit_mode()
	# 如果处于删除模式，先退出
	if is_delete_mode:
		_exit_delete_mode()
	hide()

func _ensure_custom_bgm_directory():
	"""确保自定义BGM目录存在"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("custom_bgm"):
		dir.make_dir("custom_bgm")

func _load_bgm_config():
	"""从SaveManager加载BGM配置"""
	if save_manager:
		bgm_config = save_manager.get_bgm_config()
	
	# 确保"all"场景存在
	if not bgm_config.has("all"):
		bgm_config["all"] = {
			"enabled_music": [],
			"play_mode": 1 # SEQUENTIAL
		}

func _save_bgm_config():
	"""保存BGM配置到SaveManager"""
	if save_manager:
		save_manager.set_bgm_config(bgm_config)

func _load_music_list():
	"""加载音乐列表"""
	bgm_files.clear()
	
	# 加载内置BGM
	var builtin_path = "res://assets/audio/BGM/"
	_scan_directory(builtin_path, false)
	
	# 如果没有扫描到内置BGM，使用预定义列表
	if bgm_files.is_empty():
		_load_builtin_bgm_list(builtin_path)
	
	# 加载自定义BGM
	_scan_directory(custom_bgm_path, true)
	
	print("[INFO] 加载完成: 共", bgm_files.size(), "个BGM文件")
	
	# 如果"全部"场景的音乐列表为空，自动添加所有音乐
	_init_default_music_list()

func _scan_directory(path: String, is_custom: bool):
	"""扫描目录中的音频文件"""
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if ext in ["mp3", "ogg", "wav"]:
					bgm_files.append({
						"name": file_name,
						"path": path + file_name,
						"is_custom": is_custom
					})
			file_name = dir.get_next()
		dir.list_dir_end()

func _load_builtin_bgm_list(base_path: String):
	"""加载内置BGM列表（用于打包后）"""
	var builtin_bgm_files = [
		"木漏れ日の縁側.mp3"
	]
	
	for file_name in builtin_bgm_files:
		var full_path = base_path + file_name
		if ResourceLoader.exists(full_path):
			bgm_files.append({
				"name": file_name,
				"path": full_path,
				"is_custom": false
			})

func _init_default_music_list():
	"""初始化默认音乐列表（首次使用或升级后）"""
	var all_config = bgm_config.get("all", {})
	var enabled_music = all_config.get("enabled_music", [])
	
	# 如果"全部"场景的音乐列表为空，自动添加所有音乐
	if enabled_music.is_empty() and not bgm_files.is_empty():
		print("[INFO] 初始化默认音乐列表...")
		for music_data in bgm_files:
			enabled_music.append(music_data.path)
		
		all_config["enabled_music"] = enabled_music
		if not all_config.has("play_mode"):
			all_config["play_mode"] = 1 # SEQUENTIAL
		
		bgm_config["all"] = all_config
		_save_bgm_config()
		print("[INFO] 已添加", enabled_music.size(), "首音乐到默认列表")

func _refresh_scene_list():
	"""刷新场景列表"""
	# 清空现有列表
	for child in scene_list_container.get_children():
		child.queue_free()
	
	# 添加"全部"选项
	var all_button = Button.new()
	all_button.text = "全部"
	all_button.toggle_mode = true
	all_button.button_pressed = (selected_scene == "all")
	all_button.pressed.connect(_on_scene_selected.bind("all"))
	_style_scene_button(all_button, selected_scene == "all")
	scene_list_container.add_child(all_button)
	
	# 加载场景配置
	var scenes_config = _load_scenes_config()
	if scenes_config.has("scenes"):
		for scene_id in scenes_config.scenes:
			var scene_data = scenes_config.scenes[scene_id]
			var button = Button.new()
			button.text = scene_data.name
			button.toggle_mode = true
			button.button_pressed = (selected_scene == scene_id)
			button.pressed.connect(_on_scene_selected.bind(scene_id))
			_style_scene_button(button, selected_scene == scene_id)
			scene_list_container.add_child(button)

func _style_scene_button(button: Button, is_selected: bool):
	"""设置场景按钮的样式"""
	if is_selected:
		# 选中状态：蓝色
		button.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.3, 0.7, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.4, 0.8, 1.0))
	else:
		# 未选中状态：灰色
		button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		button.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))

func _load_scenes_config() -> Dictionary:
	"""加载场景配置"""
	var config_path = "res://config/scenes.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				return json.data
	return {}

func _on_scene_selected(scene_id: String):
	"""场景被选中"""
	# 如果处于编辑模式，先保存并退出
	if is_edit_mode:
		_exit_edit_mode()
	
	# 如果处于删除模式，先退出
	if is_delete_mode:
		_exit_delete_mode()
	
	selected_scene = scene_id
	_refresh_scene_list()
	_refresh_music_list()
	_update_ui_for_scene()

func _update_ui_for_scene():
	"""根据选中的场景更新UI"""
	if selected_scene == "all":
		# "全部"场景：显示上传和删除按钮，隐藏编辑按钮
		edit_button.hide()
		upload_button.show()
		delete_button.show()
	else:
		# 其他场景：只显示编辑按钮，隐藏上传和删除
		edit_button.show()
		upload_button.hide()
		delete_button.hide()

func _refresh_music_list():
	"""刷新音乐列表"""
	# 清空现有列表
	for child in music_list_container.get_children():
		child.queue_free()
	
	# 获取当前场景的配置
	var scene_config = bgm_config.get(selected_scene, {
		"enabled_music": [],
		"play_mode": 1 # SEQUENTIAL
	})
	
	var enabled_music = scene_config.get("enabled_music", [])
	
	# 检查是否使用默认设置（仅在非编辑模式下）
	if is_edit_mode:
		# 编辑模式：始终隐藏提示，显示所有音乐
		hint_label.hide()
		_show_edit_mode_list()
	else:
		# 非编辑模式
		if selected_scene != "all" and enabled_music.is_empty():
			# 场景没有音乐：只显示提示，不显示列表
			hint_label.text = "该场景未配置音乐，默认沿用全部音乐\n点击\"编辑\"按钮可为该场景单独配置音乐"
			hint_label.show()
		else:
			# 场景有音乐：隐藏提示，显示音乐列表
			hint_label.hide()
			_show_normal_mode_list(enabled_music)
	
	# 更新播放模式UI
	_update_play_mode_ui(scene_config.get("play_mode", 1))

func _show_normal_mode_list(enabled_music: Array):
	"""显示正常模式的音乐列表"""
	var current_bgm = audio_manager.get_current_bgm_path() if audio_manager else ""
	
	for music_path in enabled_music:
		# 查找对应的音乐数据
		var music_data = _find_music_by_path(music_path)
		if not music_data:
			continue
		
		var item = _create_music_item(music_data, current_bgm == music_path)
		music_list_container.add_child(item)

func _show_edit_mode_list():
	"""显示编辑模式的音乐列表"""
	var scene_config = bgm_config.get(selected_scene, {"enabled_music": []})
	var enabled_music = scene_config.get("enabled_music", [])
	
	for music_data in bgm_files:
		var item = HBoxContainer.new()
		
		# 勾选框
		var checkbox = CheckBox.new()
		checkbox.button_pressed = enabled_music.has(music_data.path)
		checkbox.toggled.connect(_on_music_toggled.bind(music_data.path))
		item.add_child(checkbox)
		
		# 音乐名称
		var label = Label.new()
		label.text = music_data.name
		if music_data.is_custom:
			label.text += " [自定义]"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(label)
		
		music_list_container.add_child(item)

func _create_music_item(music_data: Dictionary, is_playing: bool) -> Button:
	"""创建音乐项按钮"""
	var item = Button.new()
	item.text = music_data.name
	if music_data.is_custom:
		item.text += " [自定义]"
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# 在删除模式下启用切换模式
	if is_delete_mode:
		item.toggle_mode = true
		# 检查是否是当前选中的音乐
		if music_data.path == selected_music_path:
			item.button_pressed = true
			item.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # 红色表示将被删除
	elif is_playing:
		item.text = "▶ " + item.text
		item.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # 绿色表示播放中
	
	item.pressed.connect(_on_music_item_pressed.bind(music_data))
	
	return item

func _find_music_by_path(path: String) -> Dictionary:
	"""根据路径查找音乐数据"""
	for music_data in bgm_files:
		if music_data.path == path:
			return music_data
	return {}

func _on_music_item_pressed(music_data: Dictionary):
	"""音乐项被点击（非编辑模式）"""
	if is_edit_mode:
		return
	
	# 如果处于删除模式，点击音乐会选中/取消选中
	if is_delete_mode:
		# 切换选中状态
		if selected_music_path == music_data.path:
			selected_music_path = ""  # 取消选中
		else:
			selected_music_path = music_data.path  # 选中
		_refresh_music_list()
		return
	
	# 正常模式：点击音乐会播放
	if audio_manager:
		# 获取当前场景的播放列表和播放模式
		var scene_config = bgm_config.get(selected_scene, {})
		var enabled_music = scene_config.get("enabled_music", [])
		var play_mode = scene_config.get("play_mode", 1)
		
		# 如果场景没有启用音乐，使用"全部"的设置
		if selected_scene != "all" and enabled_music.is_empty():
			scene_config = bgm_config.get("all", {})
			enabled_music = scene_config.get("enabled_music", [])
			play_mode = scene_config.get("play_mode", 1)
		
		# 找到点击音乐在列表中的索引
		var start_index = enabled_music.find(music_data.path)
		if start_index == -1:
			start_index = 0
		
		# 点击音乐时，从该音乐开始播放
		# 如果是随机模式，也从该音乐开始，然后随机播放后续
		# lock_bgm = true 表示用户手动选择，场景切换时不自动改变音乐
		audio_manager.set_play_mode(play_mode)
		audio_manager.play_playlist(enabled_music, play_mode, start_index, true)
		
		# 刷新列表显示
		_refresh_music_list()

func _on_music_toggled(enabled: bool, music_path: String):
	"""编辑模式：音乐勾选状态改变"""
	var scene_config = bgm_config.get(selected_scene, {
		"enabled_music": [],
		"play_mode": 1
	})
	
	var enabled_music = scene_config.get("enabled_music", [])
	
	if enabled:
		if not enabled_music.has(music_path):
			enabled_music.append(music_path)
	else:
		enabled_music.erase(music_path)
	
	scene_config["enabled_music"] = enabled_music
	bgm_config[selected_scene] = scene_config

func _update_play_mode_ui(play_mode: int):
	"""更新播放模式UI"""
	# 清空现有按钮
	for child in play_mode_container.get_children():
		if child is Button:
			child.queue_free()
	
	# 创建播放模式按钮
	var modes = [
		{"id": 0, "text": "单曲循环"},
		{"id": 1, "text": "顺序播放"},
		{"id": 2, "text": "随机播放"}
	]
	
	for mode_data in modes:
		var button = Button.new()
		button.text = mode_data.text
		button.toggle_mode = true
		button.button_pressed = (play_mode == mode_data.id)
		button.pressed.connect(_on_play_mode_changed.bind(mode_data.id))
		
		# 设置按钮颜色，让选中状态更明显
		if play_mode == mode_data.id:
			# 选中状态：绿色
			button.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			button.add_theme_color_override("font_pressed_color", Color(0.2, 1.0, 0.2))
			button.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.3))
		else:
			# 未选中状态：默认白色
			button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		
		play_mode_container.add_child(button)

func _on_play_mode_changed(mode: int):
	"""播放模式改变"""
	var scene_config = bgm_config.get(selected_scene, {
		"enabled_music": [],
		"play_mode": 1
	})
	
	scene_config["play_mode"] = mode
	bgm_config[selected_scene] = scene_config
	
	# 立即保存并应用
	_save_bgm_config()
	if audio_manager:
		audio_manager.set_play_mode(mode)
	
	_update_play_mode_ui(mode)

func _on_edit_pressed():
	"""编辑按钮"""
	if is_edit_mode:
		_exit_edit_mode()
	else:
		_enter_edit_mode()

func _enter_edit_mode():
	"""进入编辑模式"""
	is_edit_mode = true
	edit_button.text = "完成"
	# 编辑模式下，按钮状态由场景决定，不需要额外隐藏
	_refresh_music_list()

func _exit_edit_mode():
	"""退出编辑模式"""
	is_edit_mode = false
	edit_button.text = "编辑"
	_update_ui_for_scene()
	
	# 保存配置
	_save_bgm_config()
	
	# 刷新列表
	_refresh_music_list()

func _on_upload_pressed():
	"""上传按钮"""
	file_dialog.clear_filters()
	file_dialog.add_filter("*.mp3, *.ogg, *.wav", "音频文件")
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.popup_centered(Vector2(800, 600))

func _on_files_selected(paths: PackedStringArray):
	"""文件选择完成（仅在"全部"场景使用）"""
	for path in paths:
		var dest_path = _copy_file_to_custom(path)
		if dest_path != "":
			# 自动添加到"全部"场景的音乐列表
			var all_config = bgm_config.get("all", {
				"enabled_music": [],
				"play_mode": 1
			})
			var enabled_music = all_config.get("enabled_music", [])
			if not enabled_music.has(dest_path):
				enabled_music.append(dest_path)
			all_config["enabled_music"] = enabled_music
			bgm_config["all"] = all_config
	
	_load_music_list()
	_save_bgm_config()
	_refresh_music_list()

func _copy_file_to_custom(source_path: String) -> String:
	"""复制文件到自定义目录"""
	var file_name = source_path.get_file()
	var ext = file_name.get_extension().to_lower()
	
	if not ext in ["mp3", "ogg", "wav"]:
		print("不支持的格式: ", ext)
		return ""
	
	_ensure_custom_bgm_directory()
	var dest_path = custom_bgm_path + file_name
	
	var source = FileAccess.open(source_path, FileAccess.READ)
	if not source:
		print("无法打开源文件")
		return ""
	
	var content = source.get_buffer(source.get_length())
	source.close()
	
	var dest = FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest:
		print("无法创建目标文件")
		return ""
	
	dest.store_buffer(content)
	dest.close()
	
	print("已复制音频文件: ", file_name)
	return dest_path

func _on_delete_pressed():
	"""删除按钮（仅在"全部"场景中可用）"""
	if selected_scene != "all":
		return
	
	if not is_delete_mode:
		# 进入删除模式
		is_delete_mode = true
		delete_button.text = "确认删除"
		upload_button.disabled = true  # 禁用上传按钮
		_refresh_music_list()
		print("进入删除模式，请选择要删除的音乐")
		return
	
	# 删除模式下，如果没有选中音乐，退出删除模式
	if selected_music_path.is_empty():
		_exit_delete_mode()
		print("已取消删除")
		return
	
	# 查找音乐数据
	var music_data = _find_music_by_path(selected_music_path)
	if not music_data:
		print("未找到音乐数据")
		_exit_delete_mode()
		return
	
	# 只能删除自定义音乐
	if not music_data.is_custom:
		print("无法删除内置音乐")
		selected_music_path = ""
		_refresh_music_list()
		return
	
	# 检查是否正在播放
	if audio_manager:
		var current_bgm = audio_manager.get_current_bgm_path()
		if current_bgm == selected_music_path:
			# 停止播放
			audio_manager.stop_custom_bgm()
			print("已停止播放")
	
	# 从所有场景的配置中移除该音乐
	for scene_id in bgm_config:
		var scene_config = bgm_config[scene_id]
		if scene_config.has("enabled_music"):
			var enabled_music = scene_config["enabled_music"]
			if enabled_music.has(selected_music_path):
				enabled_music.erase(selected_music_path)
	
	# 删除文件
	var file_name = selected_music_path.get_file()
	var dir = DirAccess.open(custom_bgm_path)
	if dir:
		var error = dir.remove(file_name)
		if error == OK:
			print("已删除音频文件: ", file_name)
			selected_music_path = ""  # 清除选中状态
			_load_music_list()  # 重新加载音乐列表
			_save_bgm_config()  # 保存配置
			_exit_delete_mode()  # 退出删除模式
		else:
			print("删除文件失败 (错误代码: ", error, ")")
	else:
		print("无法打开自定义BGM目录")

func _exit_delete_mode():
	"""退出删除模式"""
	is_delete_mode = false
	selected_music_path = ""
	delete_button.text = "删除音乐"
	upload_button.disabled = false
	_refresh_music_list()

func _load_volume_settings():
	"""加载音量设置"""
	if audio_manager:
		var bgm_vol = audio_manager.get_bgm_volume()
		var ambient_vol = audio_manager.get_ambient_volume()
		
		bgm_volume_slider.value = bgm_vol * 100
		ambient_volume_slider.value = ambient_vol * 100
		
		bgm_volume_label.text = str(int(bgm_vol * 100)) + "%"
		ambient_volume_label.text = str(int(ambient_vol * 100)) + "%"

func _on_bgm_volume_changed(value: float):
	"""BGM音量改变"""
	var volume = value / 100.0
	bgm_volume_label.text = str(int(value)) + "%"
	if audio_manager:
		audio_manager.set_bgm_volume(volume)

func _on_ambient_volume_changed(value: float):
	"""环境音音量改变"""
	var volume = value / 100.0
	ambient_volume_label.text = str(int(value)) + "%"
	if audio_manager:
		audio_manager.set_ambient_volume(volume)
