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
var current_records: Array = [] # 当前日期的所有记录（包含总结和详细对话）
var view_mode: String = "summary" # "summary" = 总结列表, "detail" = 详细对话
var current_detail_record: Dictionary = {} # 当前查看的详细记录
var back_button_container: HBoxContainer = null # 返回按钮容器（固定位置）

func _ready():
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 创建返回按钮容器（在ScrollContainer之前）
	_create_back_button_container()
	
	# 连接信号
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if prev_date_button:
		prev_date_button.pressed.connect(_on_prev_date_pressed)
	if next_date_button:
		next_date_button.pressed.connect(_on_next_date_pressed)
	
	# 连接滚动事件
	if scroll_container:
		scroll_container.get_v_scroll_bar().scrolling.connect(_on_scroll_changed)

func _create_back_button_container():
	"""创建返回按钮容器（固定在ScrollContainer上方）"""
	back_button_container = HBoxContainer.new()
	back_button_container.visible = false
	back_button_container.add_theme_constant_override("separation", 10)
	
	# 创建返回按钮
	var back_button = Button.new()
	back_button.text = "← 返回总结列表"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(_on_back_to_summary)
	back_button_container.add_child(back_button)
	
	# 插入到ScrollContainer之前
	if vbox and scroll_container:
		var scroll_index = scroll_container.get_index()
		vbox.add_child(back_button_container)
		vbox.move_child(back_button_container, scroll_index)

func show_diary():
	"""显示日记查看器"""
	# 加载可用日期列表
	_load_available_dates()
	
	if available_dates.is_empty():
		print("没有日记记录")
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
	
	var diary_dir = "user://diary"
	var dir = DirAccess.open(diary_dir)
	if dir == null:
		print("日记目录不存在")
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
	
	print("找到 ", available_dates.size(), " 个日期的日记")

func _load_date_content(date_str: String):
	"""加载指定日期的内容"""
	# 清空当前内容
	for child in content_vbox.get_children():
		child.queue_free()
	
	current_records.clear()
	view_mode = "summary"
	
	# 更新日期标签
	if date_label:
		date_label.text = date_str
	
	# 更新按钮状态
	if prev_date_button:
		prev_date_button.disabled = (current_date_index >= available_dates.size() - 1)
	if next_date_button:
		next_date_button.disabled = (current_date_index <= 0)
	
	# 读取日记文件
	var diary_path = "user://diary/" + date_str + ".jsonl"
	var file = FileAccess.open(diary_path, FileAccess.READ)
	if file == null:
		print("无法打开日记文件: ", diary_path)
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
	
	# 不反转顺序，保持文件中的顺序（最新的在最下面）
	
	print("加载了 ", current_records.size(), " 条记录")
	
	# 显示总结列表
	_display_summary_list()
	
	# 滚动到底部（显示最新的记录）
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _display_summary_list():
	"""显示总结列表"""
	view_mode = "summary"
	
	# 显示日期选择器，隐藏返回按钮
	if date_selector:
		date_selector.visible = true
	if back_button_container:
		back_button_container.visible = false
	
	# 清空当前内容
	for child in content_vbox.get_children():
		child.queue_free()
	
	# 为每条记录创建总结卡片
	for record in current_records:
		_add_summary_card(record)

func _add_summary_card(record: Dictionary):
	"""添加一个总结卡片"""
	var timestamp = record.get("timestamp", "")
	var summary = record.get("summary", "无总结")
	
	# 创建卡片容器（可点击）
	var card_button = Button.new()
	card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_button.custom_minimum_size.y = 80
	card_button.flat = false
	
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
	card_button.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.2, 0.25, 0.7)
	style_hover.border_color = Color(0.4, 0.4, 0.5, 0.9)
	card_button.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.25, 0.25, 0.3, 0.8)
	card_button.add_theme_stylebox_override("pressed", style_pressed)
	
	# 创建内容容器
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_button.add_child(card_vbox)
	
	# 时间标签
	var time_label = Label.new()
	time_label.text = "⏰ " + timestamp
	time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(time_label)
	
	# 总结内容（截断显示）
	var summary_label = Label.new()
	var display_summary = summary
	if summary.length() > 100:
		display_summary = summary.substr(0, 100) + "..."
	summary_label.text = display_summary
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(summary_label)
	
	# 点击事件
	card_button.pressed.connect(_on_summary_card_clicked.bind(record))
	
	content_vbox.add_child(card_button)

func _on_summary_card_clicked(record: Dictionary):
	"""点击总结卡片，显示详细对话"""
	current_detail_record = record
	_display_detail_view()

func _display_detail_view():
	"""显示详细对话视图"""
	view_mode = "detail"
	
	# 隐藏日期选择器，显示返回按钮
	if date_selector:
		date_selector.visible = false
	if back_button_container:
		back_button_container.visible = true
	
	# 清空当前内容
	for child in content_vbox.get_children():
		child.queue_free()
	
	# 显示总结
	var summary = current_detail_record.get("summary", "")
	if not summary.is_empty():
		# 创建总结标题
		var summary_title = Label.new()
		summary_title.text = "📝 对话总结"
		summary_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		content_vbox.add_child(summary_title)
		
		# 创建总结容器（使用MarginContainer来控制宽度）
		var summary_margin = MarginContainer.new()
		summary_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_margin.add_theme_constant_override("margin_left", 15)
		summary_margin.add_theme_constant_override("margin_top", 10)
		summary_margin.add_theme_constant_override("margin_right", 15)
		summary_margin.add_theme_constant_override("margin_bottom", 10)
		
		# 创建总结面板
		var summary_panel = PanelContainer.new()
		summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var summary_style = StyleBoxFlat.new()
		summary_style.bg_color = Color(0.2, 0.25, 0.3, 0.5)
		summary_style.border_width_left = 3
		summary_style.border_width_top = 3
		summary_style.border_width_right = 3
		summary_style.border_width_bottom = 3
		summary_style.border_color = Color(0.4, 0.5, 0.6, 0.7)
		summary_style.corner_radius_top_left = 5
		summary_style.corner_radius_top_right = 5
		summary_style.corner_radius_bottom_left = 5
		summary_style.corner_radius_bottom_right = 5
		summary_style.content_margin_left = 15
		summary_style.content_margin_top = 15
		summary_style.content_margin_right = 15
		summary_style.content_margin_bottom = 15
		summary_panel.add_theme_stylebox_override("panel", summary_style)
		
		# 创建总结标签
		var summary_label = Label.new()
		summary_label.text = summary
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.custom_minimum_size.x = 500
		summary_panel.add_child(summary_label)
		
		summary_margin.add_child(summary_panel)
		content_vbox.add_child(summary_margin)
		
		# 添加分隔线
		var separator2 = HSeparator.new()
		content_vbox.add_child(separator2)
	
	# 显示详细对话
	var conversation = current_detail_record.get("conversation", "")
	if not conversation.is_empty():
		var detail_title = Label.new()
		detail_title.text = "💬 详细对话"
		detail_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		content_vbox.add_child(detail_title)
		
		# 解析对话文本（格式：说话者：内容）
		var lines = conversation.split("\n")
		for line in lines:
			if line.strip_edges().is_empty():
				continue
			
			var parts = line.split("：", false, 1)
			if parts.size() < 2:
				continue
			
			var speaker = parts[0].strip_edges()
			var content = parts[1].strip_edges()
			
			# 创建消息容器
			var msg_container = VBoxContainer.new()
			msg_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			msg_container.add_theme_constant_override("separation", 2)
			
			# 说话者标签
			var speaker_label = Label.new()
			speaker_label.text = speaker
			speaker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			msg_container.add_child(speaker_label)
			
			# 内容标签
			var content_label = Label.new()
			content_label.text = content
			content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content_label.custom_minimum_size.x = 500
			msg_container.add_child(content_label)
			
			content_vbox.add_child(msg_container)
	
	# 滚动到顶部
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = 0

func _on_back_to_summary():
	"""返回总结列表"""
	_display_summary_list()
	
	# 滚动到底部（显示最新的记录）
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _on_scroll_changed():
	"""滚动条变化时检查是否需要加载更多"""
	# 总结列表模式不需要分页加载
	pass

func _on_prev_date_pressed():
	"""切换到前一天"""
	if current_date_index >= available_dates.size() - 1:
		return
	
	# 如果在详细视图，先返回总结列表
	if view_mode == "detail":
		view_mode = "summary"
	
	current_date_index += 1
	_load_date_content(available_dates[current_date_index])

func _on_next_date_pressed():
	"""切换到后一天"""
	if current_date_index <= 0:
		return
	
	# 如果在详细视图，先返回总结列表
	if view_mode == "detail":
		view_mode = "summary"
	
	current_date_index -= 1
	_load_date_content(available_dates[current_date_index])

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_diary()
	await get_tree().create_timer(ANIMATION_DURATION).timeout
	diary_closed.emit()
