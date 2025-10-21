extends Panel

signal diary_closed

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var date_selector: HBoxContainer = $MarginContainer/VBoxContainer/DateSelector
@onready var prev_date_button: Button = $MarginContainer/VBoxContainer/DateSelector/PrevButton
@onready var date_label: Label = $MarginContainer/VBoxContainer/DateSelector/DateLabel
@onready var next_date_button: Button = $MarginContainer/VBoxContainer/DateSelector/NextButton
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var content_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox

const ANIMATION_DURATION = 0.3

var available_dates: Array = [] # 可用的日期列表（降序）
var current_date_index: int = 0
var current_records: Array = [] # 当前日期的所有记录

func _ready():
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 连接信号
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if prev_date_button:
		prev_date_button.pressed.connect(_on_prev_date_pressed)
	if next_date_button:
		next_date_button.pressed.connect(_on_next_date_pressed)

func show_diary():
	"""显示日记查看器"""
	# 加载可用日期列表
	_load_available_dates()
	
	if available_dates.is_empty():
		print("没有角色日记记录")
		return
	
	# 显示最新日期
	current_date_index = 0
	_load_date_content(available_dates[0])
	
	visible = true
	pivot_offset = size / 2.0
	
	# 展开动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_diary():
	"""隐藏日记查看器"""
	pivot_offset = size / 2.0
	
	# 收起动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false

func _load_available_dates():
	"""加载所有可用的日期"""
	available_dates.clear()
	
	var diary_dir = "user://character_diary"
	var dir = DirAccess.open(diary_dir)
	if dir == null:
		print("角色日记目录不存在")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".jsonl"):
			var date_str = file_name.replace(".jsonl", "")
			available_dates.append(date_str)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# 按日期降序排序（最新的在前）
	available_dates.sort()
	available_dates.reverse()
	
	print("找到 ", available_dates.size(), " 个日期的角色日记")

func _load_date_content(date_str: String):
	"""加载指定日期的内容"""
	# 清空当前内容
	for child in content_vbox.get_children():
		child.queue_free()
	
	current_records.clear()
	
	# 更新日期标签
	if date_label:
		date_label.text = date_str
	
	# 更新按钮状态
	if prev_date_button:
		prev_date_button.disabled = (current_date_index >= available_dates.size() - 1)
	if next_date_button:
		next_date_button.disabled = (current_date_index <= 0)
	
	# 读取日记文件
	var diary_path = "user://character_diary/" + date_str + ".jsonl"
	var file = FileAccess.open(diary_path, FileAccess.READ)
	if file == null:
		print("无法打开角色日记文件: ", diary_path)
		return
	
	# 读取所有记录
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		
		var json = JSON.new()
		if json.parse(line) == OK:
			var record = json.data
			current_records.append(record)
	
	file.close()
	
	print("加载了 ", current_records.size(), " 条角色日记")
	
	# 显示所有记录
	_display_records()
	
	# 滚动到顶部
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = 0

func _display_records():
	"""显示所有日记记录"""
	# 清空当前内容
	for child in content_vbox.get_children():
		child.queue_free()
	
	# 为每条记录创建卡片
	for record in current_records:
		_add_diary_card(record)

func _add_diary_card(record: Dictionary):
	"""添加一个日记卡片"""
	var time_str = record.get("time", "")
	var event_text = record.get("event", "")
	
	# 格式化时间显示
	var display_time = _format_time_display(time_str)
	
	# 创建卡片容器
	var card_panel = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 设置样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.15, 0.5)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.3, 0.3, 0.3, 0.7)
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.content_margin_left = 15
	style_normal.content_margin_top = 15
	style_normal.content_margin_right = 15
	style_normal.content_margin_bottom = 15
	card_panel.add_theme_stylebox_override("panel", style_normal)
	
	# 创建内容容器
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 时间标签
	var time_label = Label.new()
	time_label.text = "⏰ " + display_time
	time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	time_label.custom_minimum_size.x = 700
	card_vbox.add_child(time_label)
	
	# 事件内容
	var event_label = Label.new()
	event_label.text = event_text
	event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	event_label.custom_minimum_size.x = 700
	card_vbox.add_child(event_label)
	
	card_panel.add_child(card_vbox)
	content_vbox.add_child(card_panel)

func _on_prev_date_pressed():
	"""切换到前一天"""
	if current_date_index >= available_dates.size() - 1:
		return
	
	current_date_index += 1
	_load_date_content(available_dates[current_date_index])

func _on_next_date_pressed():
	"""切换到后一天"""
	if current_date_index <= 0:
		return
	
	current_date_index -= 1
	_load_date_content(available_dates[current_date_index])

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_diary()
	await get_tree().create_timer(ANIMATION_DURATION).timeout
	diary_closed.emit()


func _format_time_display(time_str: String) -> String:
	"""格式化时间显示
	输入: "MM-DD HH:MM" 或 "HH:MM"
	输出: "MM月DD日 HH:MM" 或 "HH:MM"
	"""
	if time_str.length() == 11:
		# 格式: MM-DD HH:MM
		var parts = time_str.split(" ")
		if parts.size() == 2:
			var date_part = parts[0]  # MM-DD
			var time_part = parts[1]  # HH:MM
			
			var date_parts = date_part.split("-")
			if date_parts.size() == 2:
				var month = date_parts[0]
				var day = date_parts[1]
				return "%s月%s日 %s" % [month, day, time_part]
	
	# 如果是 HH:MM 格式或解析失败，直接返回
	return time_str
