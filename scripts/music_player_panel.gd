extends Panel

# 音乐播放器面板
# 包含切换音乐和音量调节功能

@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer
@onready var close_button = $MarginContainer/VBoxContainer/TopBar/CloseButton

# 切换音乐选项卡
@onready var music_list = $MarginContainer/VBoxContainer/TabContainer / 切换音乐 / ScrollContainer / MusicList
@onready var upload_button = $MarginContainer/VBoxContainer/TabContainer / 切换音乐 / BottomBar / UploadButton
@onready var delete_button = $MarginContainer/VBoxContainer/TabContainer / 切换音乐 / BottomBar / DeleteButton
@onready var file_dialog = $FileDialog

# 音量调节选项卡
@onready var bgm_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / BGMVolume / HBoxContainer / Slider
@onready var bgm_volume_label = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / BGMVolume / HBoxContainer / ValueLabel
@onready var ambient_volume_slider = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / AmbientVolume / HBoxContainer / Slider
@onready var ambient_volume_label = $MarginContainer/VBoxContainer/TabContainer / 音量调节 / VBoxContainer / AmbientVolume / HBoxContainer / ValueLabel

var audio_manager
var selected_music_item: Button = null
var bgm_files: Array = []
var custom_bgm_path = "user://custom_bgm/"

func _ready():
	# 获取音频管理器
	audio_manager = get_node("/root/Main/AudioManager")
	
	# 连接信号
	close_button.pressed.connect(_on_close_pressed)
	upload_button.pressed.connect(_on_upload_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	file_dialog.files_selected.connect(_on_files_selected)
	
	bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	ambient_volume_slider.value_changed.connect(_on_ambient_volume_changed)
	
	# 初始化
	hide()
	_ensure_custom_bgm_directory()
	_load_music_list()
	_load_volume_settings()

func show_panel():
	"""显示面板"""
	show()
	_refresh_music_list()
	_load_volume_settings()

func _on_close_pressed():
	"""关闭按钮"""
	hide()

func _ensure_custom_bgm_directory():
	"""确保自定义BGM目录存在"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("custom_bgm"):
		dir.make_dir("custom_bgm")

func _load_music_list():
	"""加载音乐列表"""
	bgm_files.clear()
	
	# 加载内置BGM
	_scan_directory("res://assets/audio/BGM/", false)
	
	# 加载自定义BGM
	_scan_directory(custom_bgm_path, true)
	
	_refresh_music_list()

func _scan_directory(path: String, is_custom: bool):
	"""扫描目录中的音频文件"""
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				# Godot原生支持: ogg, wav, mp3
				# aac需要转换或使用第三方插件
				if ext in ["mp3", "ogg", "wav", "aac", "m4a"]:
					bgm_files.append({
						"name": file_name,
						"path": path + file_name,
						"is_custom": is_custom
					})
			file_name = dir.get_next()
		dir.list_dir_end()

func _refresh_music_list():
	"""刷新音乐列表显示"""
	# 清空现有列表
	for child in music_list.get_children():
		child.queue_free()
	
	# 获取当前播放的BGM路径
	var current_bgm = ""
	if audio_manager:
		current_bgm = audio_manager.get_current_bgm_path()
	
	# 添加音乐项
	for music_data in bgm_files:
		var item = Button.new()
		item.text = music_data.name
		if music_data.is_custom:
			item.text += " [自定义]"
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.toggle_mode = true
		item.pressed.connect(_on_music_item_pressed.bind(item, music_data))
		
		# 如果是当前播放的音乐，设置为选中状态并高亮显示
		if music_data.path == current_bgm:
			item.button_pressed = true
			selected_music_item = item
			# 添加视觉高亮
			item.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # 绿色
			item.add_theme_color_override("font_pressed_color", Color(0.3, 1.0, 0.3))
			item.text = "▶ " + item.text  # 添加播放图标
		
		music_list.add_child(item)

func _on_music_item_pressed(item: Button, music_data: Dictionary):
	"""音乐项被点击"""
	# 取消其他项的选中状态和高亮
	for child in music_list.get_children():
		if child != item and child is Button:
			child.button_pressed = false
			# 移除高亮
			child.remove_theme_color_override("font_color")
			child.remove_theme_color_override("font_pressed_color")
			# 移除播放图标
			if child.text.begins_with("▶ "):
				child.text = child.text.substr(2)
	
	selected_music_item = item if item.button_pressed else null
	
	# 播放选中的音乐
	if item.button_pressed and audio_manager:
		audio_manager.play_custom_bgm(music_data.path)
		# 添加高亮
		item.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		item.add_theme_color_override("font_pressed_color", Color(0.3, 1.0, 0.3))
		# 添加播放图标
		if not item.text.begins_with("▶ "):
			item.text = "▶ " + item.text
	else:
		# 取消选中时停止自定义BGM，恢复场景音乐
		if audio_manager:
			audio_manager.stop_custom_bgm()
		# 移除高亮
		item.remove_theme_color_override("font_color")
		item.remove_theme_color_override("font_pressed_color")
		# 移除播放图标
		if item.text.begins_with("▶ "):
			item.text = item.text.substr(2)

func _on_upload_pressed():
	"""上传按钮"""
	file_dialog.clear_filters()
	file_dialog.add_filter("*.mp3, *.ogg, *.wav, *.aac, *.m4a", "音频文件")
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.popup_centered(Vector2(800, 600))

func _on_files_selected(paths: PackedStringArray):
	"""文件选择完成"""
	for path in paths:
		_copy_file_to_custom(path)
	
	_load_music_list()

func _copy_file_to_custom(source_path: String):
	"""复制文件到自定义目录（跨平台兼容）"""
	var file_name = source_path.get_file()
	var ext = file_name.get_extension().to_lower()
	
	# 检查格式支持
	if ext in ["aac", "m4a"]:
		push_warning("AAC/M4A格式不被Godot原生支持")
		print("⚠️ ", file_name, " 是AAC格式，可能无法播放")
		print("建议使用FFmpeg转换为OGG: ffmpeg -i \"", source_path, "\" -c:a libvorbis -q:a 5 output.ogg")
		# 仍然复制文件，但用户会看到警告
	
	# 确保目标目录存在
	_ensure_custom_bgm_directory()
	
	var dest_path = custom_bgm_path + file_name
	
	# 打开源文件
	var source = FileAccess.open(source_path, FileAccess.READ)
	if not source:
		push_error("❌ 无法打开源文件: " + source_path)
		print("错误代码: ", FileAccess.get_open_error())
		return
	
	# 读取文件内容
	var content = source.get_buffer(source.get_length())
	var file_size = source.get_length()
	source.close()
	
	if content.size() == 0:
		push_error("❌ 源文件为空或读取失败: " + source_path)
		return
	
	# 写入目标文件
	var dest = FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest:
		push_error("❌ 无法创建目标文件: " + dest_path)
		print("错误代码: ", FileAccess.get_open_error())
		return
	
	dest.store_buffer(content)
	dest.close()
	
	# 验证文件是否成功写入
	if FileAccess.file_exists(dest_path):
		var verify = FileAccess.open(dest_path, FileAccess.READ)
		if verify:
			var verify_size = verify.get_length()
			verify.close()
			
			if verify_size == file_size:
				if ext in ["aac", "m4a"]:
					print("⚠️ 已复制音频文件（可能无法播放）: ", file_name, " (", file_size, " bytes)")
				else:
					print("✅ 已复制音频文件: ", file_name, " (", file_size, " bytes)")
			else:
				push_error("❌ 文件复制不完整: ", file_name)
		else:
			push_error("❌ 无法验证复制的文件: ", dest_path)
	else:
		push_error("❌ 文件复制失败: ", dest_path)

func _on_delete_pressed():
	"""删除按钮"""
	if not selected_music_item:
		return
	
	# 找到对应的音乐数据
	for music_data in bgm_files:
		if selected_music_item.text.begins_with(music_data.name):
			if music_data.is_custom:
				# 删除文件
				var dir = DirAccess.open(custom_bgm_path)
				if dir:
					dir.remove(music_data.name)
					print("已删除音频文件: ", music_data.name)
					_load_music_list()
			else:
				print("无法删除内置音乐")
			break

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
