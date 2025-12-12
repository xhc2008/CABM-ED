extends Window

signal album_selected(path: String)

var grid: GridContainer
var scroll: ScrollContainer

func _ready():
	title = "选择图片"
	size = Vector2i(900, 600)
	borderless = false
	unresizable = false  # 改为 unresizable
	_scroll_and_grid()
	_load_album_images()

func popup_album():
	popup_centered()

func _scroll_and_grid():
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

func _load_album_images():
	var base_dir = _get_album_dir()
	var files = _list_images(base_dir)
	for i in range(min(files.size(), 100)):
		var path = files[i]
		var btn = TextureButton.new()
		# 修改展开模式 - 使用正确的属性
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(160, 160)
		var img = Image.new()
		var err = img.load_from_file(path)
		if err == OK:
			var thumb = img.duplicate()
			thumb.resize(160, 160, Image.INTERPOLATE_LANCZOS)
			var tex = ImageTexture.create_from_image(thumb)
			btn.texture_normal = tex
		btn.pressed.connect(func():
			album_selected.emit(path)
			queue_free()
		)
		grid.add_child(btn)

func _get_album_dir() -> String:
	var pm = get_node_or_null("/root/PlatformManager")
	if pm and pm.is_android():
		return "/storage/emulated/0/DCIM/Camera"
	var pics = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics.is_empty():
		return "."
	return pics

func _list_images(dir_path: String) -> Array:
	var res: Array = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return res
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower = fname.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
				res.append(dir_path + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	res.sort() 
	res.reverse() 
	return res
	