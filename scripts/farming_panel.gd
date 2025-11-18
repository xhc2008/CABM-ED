extends Control

signal closed()

var plots: Array = []
var crops_config: Array = []
var bg: TextureRect
var ui_layer: Control

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	bg = TextureRect.new()
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_path = "res://assets/images/farming/background.png"
	if ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	add_child(bg)
	ui_layer = Control.new()
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_layer)
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "关闭"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -120
	close_btn.offset_top = 10
	close_btn.offset_right = -20
	close_btn.offset_bottom = 50
	close_btn.pressed.connect(close_farming)
	add_child(close_btn)
	_load_crops_config()
	_ensure_save_data()
	_create_plots()
	_refresh_ui()

func open_farming():
	show()

func close_farming():
	hide()
	closed.emit()

func _load_crops_config():
	crops_config = []
	var path = "res://config/crops.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var js = JSON.new()
		var txt = f.get_as_text()
		f.close()
		if js.parse(txt) == OK:
			var d = js.data
			if d.has("crops"):
				crops_config = d.crops

func _ensure_save_data():
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	if not sm.save_data.has("farming_system_data"):
		sm.save_data.farming_system_data = {"plots": []}
		for i in range(6):
			sm.save_data.farming_system_data.plots.append(null)

func _get_plot_data(idx: int):
	if not has_node("/root/SaveManager"):
		return null
	var sm = get_node("/root/SaveManager")
	var arr = sm.save_data.farming_system_data.get("plots", [])
	if idx >= 0 and idx < arr.size():
		return arr[idx]
	return null

func _set_plot_data(idx: int, data):
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	var arr = sm.save_data.farming_system_data.get("plots", [])
	if idx >= 0 and idx < arr.size():
		arr[idx] = data
		sm.save_game(sm.current_slot)

func _create_plots():
	for child in ui_layer.get_children():
		child.queue_free()
	plots.clear()
	var cols = 3
	var rows = 2
	var container_size = get_viewport().get_visible_rect().size
	var grid_w = min(720.0, container_size.x * 0.8)
	var grid_h = min(420.0, container_size.y * 0.6)
	var start_x = (container_size.x - grid_w) * 0.5
	var start_y = (container_size.y - grid_h) * 0.5
	var cell_w = grid_w / cols
	var cell_h = grid_h / rows
	for r in range(rows):
		for c in range(cols):
			var idx = r * cols + c
			var plot = Control.new()
			plot.custom_minimum_size = Vector2(cell_w, cell_h)
			plot.position = Vector2(start_x + c * cell_w, start_y + r * cell_h)
			plot.size = Vector2(cell_w, cell_h)
			var land = TextureRect.new()
			land.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			land.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			land.set_anchors_preset(Control.PRESET_CENTER)
			land.size = Vector2(cell_w * 0.8, cell_h * 0.8)
			var land_path = "res://assets/images/farming/farmland.png"
			if ResourceLoader.exists(land_path):
				land.texture = load(land_path)
			plot.add_child(land)
			var crop = TextureRect.new()
			crop.name = "CropSprite"
			crop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			crop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			crop.set_anchors_preset(Control.PRESET_CENTER)
			crop.size = Vector2(cell_w * 0.6, cell_h * 0.6)
			plot.add_child(crop)
			var btn = Button.new()
			btn.text = ""
			btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.pressed.connect(_on_plot_pressed.bind(idx))
			btn.modulate = Color(1,1,1,0)
			plot.add_child(btn)
			ui_layer.add_child(plot)
			plots.append(plot)

func _on_plot_pressed(idx: int):
	var data = _get_plot_data(idx)
	if data == null:
		_show_planting_list(idx)
	else:
		_show_planted_options(idx)

func _refresh_ui():
	for i in range(plots.size()):
		var plot = plots[i]
		var data = _get_plot_data(i)
		var crop_sprite = plot.get_node("CropSprite")
		if data == null:
			crop_sprite.texture = null
			continue
		var crop = _get_crop(data.get("crop_id", ""))
		if crop == null:
			crop_sprite.texture = null
			continue
		var stage = _calculate_stage(crop, int(data.get("planted_at_unix", 0)))
		var base = str(crop.get("stage_base", ""))
		var path = "res://assets/images/farming/" + base + str(stage) + ".png"
		if ResourceLoader.exists(path):
			crop_sprite.texture = load(path)
		else:
			crop_sprite.texture = null

func _get_crop(crop_id: String) -> Dictionary:
	for c in crops_config:
		if c.get("id", "") == crop_id:
			return c
	return {}

func _calculate_stage(crop: Dictionary, planted_at_unix: int) -> int:
	var total = int(crop.get("growth_time_seconds", 0))
	if total <= 0 or planted_at_unix <= 0:
		return 0
	var now = Time.get_unix_time_from_system()
	var elapsed = max(0, now - planted_at_unix)
	var ratio = float(elapsed) / float(total)
	var stage = clamp(int(floor(ratio * 4.0)), 0, 3)
	return stage

func _is_mature(crop: Dictionary, planted_at_unix: int) -> bool:
	var total = int(crop.get("growth_time_seconds", 0))
	if total <= 0 or planted_at_unix <= 0:
		return false
	var now = Time.get_unix_time_from_system()
	return now - planted_at_unix >= total

func _show_planting_list(idx: int):
	var panel = PanelContainer.new()
	panel.name = "PlantingPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(540, 360)
	add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title = Label.new()
	title.text = "选择作物"
	vb.add_child(title)
	var grid = GridContainer.new()
	grid.columns = 2
	vb.add_child(grid)
	for c in crops_config:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon = TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ipath = "res://assets/images/farming/" + str(c.get("icon", ""))
		if ResourceLoader.exists(ipath):
			icon.texture = load(ipath)
		icon.custom_minimum_size = Vector2(48,48)
		row.add_child(icon)
		var info = Label.new()
		var name = str(c.get("name", c.get("id", "")))
		var secs = int(c.get("growth_time_seconds", 0))
		var h = c.get("harvest", {})
		var hid = str(h.get("item_id", ""))
		var cnt = h.get("count", [1,1])
		var range_txt = str(cnt[0]) + "-" + str(cnt[1])
		info.text = name + " | 生长:" + str(secs) + "s | 收获:" + hid + " x" + range_txt
		row.add_child(info)
		var btn = Button.new()
		btn.text = "种植"
		btn.pressed.connect(_plant_crop.bind(idx, str(c.get("id", ""))))
		row.add_child(btn)
		grid.add_child(row)
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_panel.bind(panel))
	vb.add_child(close_btn)

func _close_panel(panel: Control):
	if is_instance_valid(panel):
		panel.queue_free()

func _plant_crop(idx: int, crop_id: String):
	var data = {"crop_id": crop_id, "planted_at_unix": Time.get_unix_time_from_system()}
	_set_plot_data(idx, data)
	_refresh_ui()
	for node in get_children():
		if node.name == "PlantingPanel":
			node.queue_free()

func _show_planted_options(idx: int):
	var data = _get_plot_data(idx)
	var crop = _get_crop(str(data.get("crop_id", "")))
	var panel = PanelContainer.new()
	panel.name = "PlotPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(420, 220)
	add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var name = str(crop.get("name", crop.get("id", "")))
	var secs_total = int(crop.get("growth_time_seconds", 0))
	var planted = int(data.get("planted_at_unix", 0))
	var now = Time.get_unix_time_from_system()
	var remain = max(0, secs_total - (now - planted))
	var info = Label.new()
	info.text = name + " | 剩余:" + str(remain) + "s"
	vb.add_child(info)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var remove_btn = Button.new()
	remove_btn.text = "移除"
	remove_btn.pressed.connect(_remove.bind(idx, panel))
	hb.add_child(remove_btn)
	var mature = _is_mature(crop, planted)
	if mature:
		var harvest_btn = Button.new()
		harvest_btn.text = "收获"
		harvest_btn.pressed.connect(_harvest.bind(idx, panel))
		hb.add_child(harvest_btn)
	vb.add_child(hb)

func _remove(idx: int, panel: Control):
	_set_plot_data(idx, null)
	_refresh_ui()
	if is_instance_valid(panel):
		panel.queue_free()

func _harvest(idx: int, panel: Control):
	var data = _get_plot_data(idx)
	var crop = _get_crop(str(data.get("crop_id", "")))
	var h = crop.get("harvest", {})
	var hid = str(h.get("item_id", ""))
	var cnt = h.get("count", [1,1])
	var minc = int(cnt[0])
	var maxc = int(cnt[1])
	var give = randi_range(minc, maxc)
	if has_node("/root/InventoryManager"):
		var inv = get_node("/root/InventoryManager")
		inv.add_item_to_inventory(hid, give)
	_set_plot_data(idx, null)
	_refresh_ui()
	if is_instance_valid(panel):
		panel.queue_free()