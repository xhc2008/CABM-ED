extends Node

signal image_selected(path: String)
signal image_cleared()

var parent_dialog: Panel
var pic_button: Button
var input_field: LineEdit

var selected_image_path: String = ""

const ICON_NORMAL = "res://assets/images/chat/image.png"
const ICON_UPLOADING = "res://assets/images/chat/image_upload.png"

func setup(dialog: Panel, pic_btn: Button, input_fld: LineEdit):
	parent_dialog = dialog
	pic_button = pic_btn
	input_field = input_fld
	if pic_button:
		pic_button.pressed.connect(_on_pic_button_pressed)
		_update_button_icon()

func _on_pic_button_pressed():
	if has_selected_image():
		clear_selected_image()
	else:
		_show_file_dialog()

func _show_file_dialog():
	var file_dialog = FileDialog.new()
	file_dialog.name = "ImagePickerDialog"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp; *.PNG, *.JPG, *.JPEG, *.WEBP", "Images (*.png, *.jpg, *.jpeg, *.webp)")
	file_dialog.use_native_dialog = true  # 关键：启用系统原生选择器

	# Desktop only
	if not OS.has_feature("android"):
		var pics_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if not pics_dir.is_empty():
			file_dialog.current_dir = pics_dir

	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(file_dialog.queue_free)
	get_tree().root.add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	print("📂 Selected: " + path)

	# ⚠️ Android: content:// URI 必须立即同步处理！
	if OS.has_feature("android") and path.begins_with("content://"):
		_process_selected_image_now(path)
	else:
		_process_selected_image_async(path)

# ✅ 同步立即复制 content:// URI（Godot 4.0-4.2 关键！）
func _process_selected_image_now(uri: String):
	var final_path = _copy_content_uri_immediately(uri)
	if final_path.is_empty():
		push_error("❌ Failed to copy URI: " + uri)
		clear_selected_image()
		return

	selected_image_path = final_path
	_update_button_icon()
	image_selected.emit(final_path)
	print("✅ Image ready: " + final_path)

func _copy_content_uri_immediately(uri: String) -> String:
	var temp_path = "user://tmp/selected_image_" + str(Time.get_unix_time_from_system()) + ".jpg"

	# 创建 tmp 目录
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("tmp"):
		dir.make_dir("tmp")

	# 打开 content:// URI（系统已授临时权限）
	var src = FileAccess.open(uri, FileAccess.READ)
	if not src:
		var err = FileAccess.get_open_error()
		print("❌ Open URI failed. Error code:", err)
		return ""

	var dst = FileAccess.open(temp_path, FileAccess.WRITE)
	if not dst:
		src.close()
		print("❌ Cannot write to", temp_path)
		return ""

	# 一次性读完（小图安全）
	var data = src.get_buffer(src.get_length())
	src.close()

	if data.is_empty():
		dst.close()
		DirAccess.remove_absolute(temp_path)
		return ""

	dst.store_buffer(data)
	dst.close()

	# 验证非空
	if FileAccess.file_exists(temp_path):
		var f = FileAccess.open(temp_path, FileAccess.READ)
		if f:
			var size = f.get_length()
			f.close()
			if size > 0:
				return temp_path

	DirAccess.remove_absolute(temp_path)
	return ""

# 异步处理普通路径（file:// 或绝对路径）
func _process_selected_image_async(path: String):
	var final_path = await _resolve_normal_path(path)
	if final_path.is_empty():
		clear_selected_image()
		return
	selected_image_path = final_path
	_update_button_icon()
	image_selected.emit(final_path)

func _resolve_normal_path(path: String) -> String:
	if path.begins_with("file://"):
		path = path.replace("file://", "")
	if FileAccess.file_exists(path):
		return path
	push_error("File not found: " + path)
	return ""

# ——— 公共接口 ———
func has_selected_image() -> bool:
	return not selected_image_path.is_empty()

func get_selected_image_path() -> String:
	return selected_image_path

func clear_selected_image():
	selected_image_path = ""
	_update_button_icon()
	image_cleared.emit()

func _update_button_icon():
	if not pic_button: return
	var tex = load(ICON_UPLOADING if has_selected_image() else ICON_NORMAL)
	if tex:
		pic_button.icon = tex
		pic_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func hide_for_history():
	if pic_button: pic_button.visible = false

func show_after_history():
	if pic_button: pic_button.visible = true

func describe_selected_image() -> String:
	if selected_image_path.is_empty(): return ""
	var svc = load("res://scripts/ai_chat/ai_view_service.gd").instantiate()
	add_child(svc)
	var desc = await svc.describe_image(selected_image_path)
	svc.queue_free()
	return desc