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
	# 确保面板居中显示
	var viewport_size = get_viewport_rect().size
	position = (viewport_size - size) / 2.0
	
	show()
	_refresh_music_list()
	_load_volume_settings()
	# 初始化删除按钮状态
	_update_delete_button_state(null)

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
	
	# 加载内置BGM（打包后使用预定义列表）
	var builtin_path = "res://assets/audio/BGM/"
	var builtin_count_before = bgm_files.size()
	_scan_directory(builtin_path, false)
	var builtin_count_after = bgm_files.size()
	
	# 如果没有扫描到任何内置BGM，使用预定义列表
	if builtin_count_after == builtin_count_before:
		print("[INFO] 使用预定义BGM列表")
		_load_builtin_bgm_list(builtin_path)
	
	# 加载自定义BGM
	_scan_directory(custom_bgm_path, true)
	
	print("[INFO] 加载完成: 内置BGM=", builtin_count_after - builtin_count_before, ", 自定义BGM=", bgm_files.size() - builtin_count_after)
	
	_refresh_music_list()

func _scan_directory(path: String, is_custom: bool):
	"""扫描目录中的音频文件"""
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var count = 0
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
					count += 1
			file_name = dir.get_next()
		dir.list_dir_end()
		
		if not is_custom:
			print("[INFO] 扫描到 ", count, " 个内置BGM文件")
	else:
		if not is_custom:
			print("[WARN] 无法打开目录: ", path)

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
	
	# 更新删除按钮状态
	if item.button_pressed:
		_update_delete_button_state(music_data)
	else:
		_update_delete_button_state(null)
	
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

func _update_delete_button_state(music_data):
	"""更新删除按钮的启用/禁用状态"""
	if delete_button:
		if music_data and music_data.is_custom:
			delete_button.disabled = false
			delete_button.tooltip_text = "删除选中的自定义音乐"
		else:
			delete_button.disabled = true
			if music_data:
				delete_button.tooltip_text = "无法删除内置音乐"
			else:
				delete_button.tooltip_text = "请先选择要删除的音乐"

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
	
	# 检查文件名是否包含非ASCII字符
	if not file_name.is_valid_filename():
		push_warning("文件名包含无效字符: " + file_name)
		print("警告: 文件名可能包含特殊字符，建议使用英文文件名")
	
	# 检查格式支持
	if ext in ["aac", "m4a"]:
		push_warning("AAC/M4A格式不被Godot原生支持")
		print("警告: ", file_name, " 是AAC格式，可能无法播放")
		print("建议使用FFmpeg转换为OGG")
		# 仍然复制文件，但用户会看到警告
	
	# 确保目标目录存在
	_ensure_custom_bgm_directory()
	
	var dest_path = custom_bgm_path + file_name
	
	# 打开源文件
	var source = FileAccess.open(source_path, FileAccess.READ)
	if not source:
		push_error("无法打开源文件")
		print("错误代码: ", FileAccess.get_open_error())
		return
	
	# 读取文件内容
	var content = source.get_buffer(source.get_length())
	var file_size = source.get_length()
	source.close()
	
	if content.size() == 0:
		push_error("源文件为空或读取失败")
		return
	
	# 写入目标文件
	var dest = FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest:
		push_error("无法创建目标文件")
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
					print("已复制音频文件(可能无法播放): ", file_size, " bytes")
				else:
					print("已复制音频文件: ", file_size, " bytes")
			else:
				push_error("文件复制不完整")
		else:
			push_error("无法验证复制的文件")
	else:
		push_error("文件复制失败")

func _on_delete_pressed():
	"""删除按钮（仅删除自定义音乐）"""
	if not selected_music_item:
		print("未选中任何音乐")
		return
	
	# 获取按钮文本（移除可能的播放图标）
	var button_text = selected_music_item.text
	if button_text.begins_with("▶ "):
		button_text = button_text.substr(2)
	
	# 找到对应的音乐数据
	var found_music = null
	for music_data in bgm_files:
		var music_name = music_data.name
		if music_data.is_custom:
			music_name += " [自定义]"
		
		if button_text == music_name or button_text.begins_with(music_data.name):
			found_music = music_data
			break
	
	if not found_music:
		print("未找到对应的音乐文件")
		return
	
	# 检查是否为自定义音乐
	if not found_music.is_custom:
		print("无法删除内置音乐")
		_show_message("无法删除内置音乐")
		return
	
	# 检查是否正在播放，如果是则停止
	if audio_manager:
		var current_bgm = audio_manager.get_current_bgm_path()
		if current_bgm == found_music.path:
			# 停止播放
			audio_manager.stop_custom_bgm()
			print("已停止播放")
	
	# 删除文件
	var dir = DirAccess.open(custom_bgm_path)
	if dir:
		var error = dir.remove(found_music.name)
		if error == OK:
			print("已删除音频文件")
			_show_message("删除成功")
			
			# 清除选中状态
			selected_music_item = null
			
			# 重新加载列表
			_load_music_list()
		else:
			push_error("删除文件失败 (错误代码: " + str(error) + ")")
			_show_message("删除失败")
	else:
		push_error("无法打开自定义BGM目录")
		_show_message("删除失败")

func _load_builtin_bgm_list(base_path: String):
	"""加载内置BGM列表（用于打包后）"""
	# 预定义的内置BGM文件列表
	# 注意：文件名必须与实际文件完全匹配
	var builtin_bgm_files = [
		# "红线(Chinese ver_).ogg",
		"木漏れ日の縁側.mp3"
	]
	
	print("[INFO] 尝试加载预定义BGM列表...")
	var loaded_count = 0
	
	for file_name in builtin_bgm_files:
		var full_path = base_path + file_name
		# 验证文件是否存在
		if ResourceLoader.exists(full_path):
			bgm_files.append({
				"name": file_name,
				"path": full_path,
				"is_custom": false
			})
			loaded_count += 1
			print("[OK] 加载内置BGM: ", file_name)
		else:
			print("[WARN] 内置BGM不存在: ", full_path)
			# 尝试不同的路径格式
			var alt_path = full_path + ".import"
			if FileAccess.file_exists(alt_path):
				print("[INFO] 找到.import文件，资源应该存在")
				# 即使ResourceLoader找不到，也添加到列表
				bgm_files.append({
					"name": file_name,
					"path": full_path,
					"is_custom": false
				})
				loaded_count += 1
	
	print("[INFO] 预定义BGM加载完成: ", loaded_count, "/", builtin_bgm_files.size())

func _show_message(message: String):
	"""显示临时消息（可以扩展为弹窗或提示）"""
	print("[消息] ", message)
	# TODO: 可以添加UI提示标签

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
