extends Node

signal image_selected(path: String)
signal image_cleared()

var parent_dialog: Panel
var pic_button: Button
var input_field: LineEdit

var selected_image_path: String = ""
var file_dialog: FileDialog = null

# 图标路径
const ICON_NORMAL = "res://assets/images/chat/image.png"
const ICON_UPLOADING = "res://assets/images/chat/image_upload.png"

func setup(dialog: Panel, pic_btn: Button, input_fld: LineEdit):
	parent_dialog = dialog
	pic_button = pic_btn
	input_field = input_fld
	
	if pic_button:
		pic_button.pressed.connect(_on_pic_button_pressed)
		_update_button_icon()  # 设置初始图标

func _on_pic_button_pressed():
	if has_selected_image():
		# 如果有图片被挂起，点击则清除
		clear_selected_image()
	else:
		# 否则打开文件选择
		_open_image_selection()

func _open_image_selection():
	if has_node("/root/PlatformManager") and get_node("/root/PlatformManager").is_android():
		_open_album_viewer()
		return
	
	if file_dialog == null:
		file_dialog = FileDialog.new()
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.filters = PackedStringArray(["*.png;*.jpg;*.jpeg;*.webp"]) 
		file_dialog.ok_button_text = "选择"
		file_dialog.cancel_button_text = "取消"
		parent_dialog.add_child(file_dialog)
		file_dialog.file_selected.connect(_on_file_selected)
	
	file_dialog.popup_centered(Vector2(900, 600))

func _on_file_selected(path: String):
	selected_image_path = path
	_update_button_icon()
	image_selected.emit(path)

func has_selected_image() -> bool:
	return not selected_image_path.is_empty()

func get_selected_image_path() -> String:
	return selected_image_path

func clear_selected_image():
	selected_image_path = ""
	_update_button_icon()
	image_cleared.emit()

func _update_button_icon():
	if not pic_button:
		return
	
	var icon_texture: Texture2D
	
	if has_selected_image():
		# 有图片被挂起的状态
		icon_texture = load(ICON_UPLOADING)
	else:
		# 正常状态
		icon_texture = load(ICON_NORMAL)
	
	if icon_texture:
		# 直接设置按钮的纹理过滤为 NEAREST
		pic_button.icon = icon_texture
		pic_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func hide_for_history():
	if pic_button:
		pic_button.visible = false

func show_after_history():
	if pic_button:
		pic_button.visible = true

func _open_album_viewer():
	var viewer = preload("res://scripts/ui/album_viewer.gd").new()
	add_child(viewer)
	viewer.album_selected.connect(_on_file_selected)
	viewer.popup_album()

func describe_selected_image() -> String:
	if selected_image_path.is_empty():
		return ""
	
	var svc = preload("res://scripts/ai_chat/ai_view_service.gd").new()
	add_child(svc)
	var desc = await svc.describe_image(selected_image_path)
	svc.queue_free()
	return desc
