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
var view_mode: String = "list" # "list" = 列表视图, "detail" = 详情视图
var current_detail_record: Dictionary = {} # 当前查看的详细记录
var back_button_container: HBoxContainer = null # 返回按钮容器
var saved_scroll_position: int = 0 # 保存的滚动位置（用于从详情返回列表时恢复）

# 触摸手势检测
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_dragging: bool = false
const DRAG_THRESHOLD: float = 10.0 # 超过这个距离视为拖动
const TAP_TIME_THRESHOLD: float = 0.3 # 点击时间阈值（秒）

func _ready():
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 自定义滚动条样式（加粗）
	_setup_scrollbar_style()
	
	# 创建返回按钮容器
	_create_back_button_container()
	
	# 连接信号
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if prev_date_button:
		prev_date_button.pressed.connect(_on_prev_date_pressed)
	if next_date_button:
		next_date_button.pressed.connect(_on_next_date_pressed)

func _setup_scrollbar_style():
	"""设置滚动条样式（加粗）"""
	if not scroll_container:
		return
	
	# 为内容添加右侧边距，避免被滚动条遮挡
	if content_vbox and content_vbox.get_parent() == scroll_container:
		# 创建 MarginContainer 包裹内容
		var content_margin = MarginContainer.new()
		content_margin.add_theme_constant_override("margin_right", 25)
		content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# 重新组织节点结构
		scroll_container.remove_child(content_vbox)
		scroll_container.add_child(content_margin)
		content_margin.add_child(content_vbox)
	
	# 获取垂直滚动条
	var v_scroll = scroll_container.get_v_scroll_bar()
	if not v_scroll:
		return
	
	# 创建滚动条滑块样式（加粗）
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.6, 0.6, 0.6, 0.8)
	grabber_style.corner_radius_top_left = 6
	grabber_style.corner_radius_top_right = 6
	grabber_style.corner_radius_bottom_left = 6
	grabber_style.corner_radius_bottom_right = 6
	
	# 滑块悬停样式
	var grabber_hover_style = StyleBoxFlat.new()
	grabber_hover_style.bg_color = Color(0.7, 0.7, 0.7, 0.9)
	grabber_hover_style.corner_radius_top_left = 6
	grabber_hover_style.corner_radius_top_right = 6
	grabber_hover_style.corner_radius_bottom_left = 6
	grabber_hover_style.corner_radius_bottom_right = 6
	
	# 滑块按下样式
	var grabber_pressed_style = StyleBoxFlat.new()
	grabber_pressed_style.bg_color = Color(0.8, 0.8, 0.8, 1.0)
	grabber_pressed_style.corner_radius_top_left = 6
	grabber_pressed_style.corner_radius_top_right = 6
	grabber_pressed_style.corner_radius_bottom_left = 6
	grabber_pressed_style.corner_radius_bottom_right = 6
	
	# 滚动条背景样式
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	scroll_style.corner_radius_top_left = 6
	scroll_style.corner_radius_top_right = 6
	scroll_style.corner_radius_bottom_left = 6
	scroll_style.corner_radius_bottom_right = 6
	
	# 应用样式
	v_scroll.add_theme_stylebox_override("grabber", grabber_style)
	v_scroll.add_theme_stylebox_override("grabber_highlight", grabber_hover_style)
	v_scroll.add_theme_stylebox_override("grabber_pressed", grabber_pressed_style)
	v_scroll.add_theme_stylebox_override("scroll", scroll_style)
	
	# 设置滚动条宽度（加粗）
	v_scroll.custom_minimum_size.x = 20

func _create_back_button_container():
	"""创建返回按钮容器（固定在ScrollContainer上方）"""
	back_button_container = HBoxContainer.new()
	back_button_container.visible = false
	back_button_container.add_theme_constant_override("separation", 10)
	
	# 创建返回按钮
	var back_button = Button.new()
	back_button.text = "← 返回列表"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(_on_back_to_list)
	back_button_container.add_child(back_button)
	
	# 插入到ScrollContainer之前
	if vbox and scroll_container:
		var scroll_index = scroll_container.get_index()
		vbox.add_child(back_button_container)
		vbox.move_child(back_button_container, scroll_index)

func show_diary():
	"""显示日记查看器"""
	# 重置视图状态
	view_mode = "list"
	if date_selector:
		date_selector.visible = true
	if back_button_container:
		back_button_container.visible = false
	
	# 更新标题为角色名称
	_update_title()
	
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

func _update_title():
	"""更新标题为角色名称"""
	if not title_label:
		return
	
	var character_name = _get_character_name()
	title_label.text = "%s的日记" % character_name

func _get_character_name() -> String:
	"""获取角色名称"""
	var config_path = "res://config/app_config.json"
	if not FileAccess.file_exists(config_path):
		return "角色"
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var config = json.data
		return config.get("character_name", "角色")
	
	return "角色"

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
	
	print("加载了 ", current_records.size(), " 条日记")
	
	# 显示所有记录
	_display_records()
	
	# 滚动到底部（一级页面默认显示最新内容）
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

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
	var record_type = record.get("type", "offline") # 默认为offline类型
	
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
	
	if record_type == "games":
		# games类型：显示游戏记录，不可点击
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var time_str = record.get("time", "")
		var event_text = record.get("event", "")
		
		# 格式化时间显示
		var display_time = _format_time_display(time_str)
		
		# 时间标签（带游戏图标）
		var time_label = Label.new()
		time_label.text = "🎮 " + display_time
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		time_label.custom_minimum_size.x = 700
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(time_label)
		
		# 事件内容
		var event_label = Label.new()
		event_label.text = event_text
		event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		event_label.custom_minimum_size.x = 700
		event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(event_label)
		
		card_panel.add_child(card_vbox)
		card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif record_type == "chat":
		# chat类型：显示总结，可点击查看详情
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var timestamp = record.get("timestamp", "")
		var summary = record.get("summary", "无总结")
		
		# 格式化时间显示（只显示到分钟）
		var display_time = _format_chat_time_display(timestamp)
		
		# 时间标签（带💬标记）
		var time_label = Label.new()
		time_label.text = "💬 " + display_time
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		time_label.custom_minimum_size.x = 700
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(time_label)
		
		# 总结内容（截断显示）
		var summary_label = Label.new()
		var display_summary = summary
		if summary.length() > 150:
			display_summary = summary.substr(0, 150) + "..."
		summary_label.text = display_summary
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		summary_label.custom_minimum_size.x = 700
		summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(summary_label)
		
		card_panel.add_child(card_vbox)
		
		# 使用Control代替Button，手动处理触摸事件以改善移动端滑动体验
		var click_area = Control.new()
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		click_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_panel.add_child(click_area)
		
		# 手动处理触摸/点击事件
		click_area.gui_input.connect(_on_card_gui_input.bind(record, card_panel, style_normal, click_area))
		
		# 鼠标悬停效果（仅桌面端）
		click_area.mouse_entered.connect(func():
			if not is_dragging:
				var style_hover = style_normal.duplicate()
				style_hover.bg_color = Color(0.2, 0.2, 0.25, 0.7)
				style_hover.border_color = Color(0.4, 0.4, 0.5, 0.9)
				card_panel.add_theme_stylebox_override("panel", style_hover)
		)
		click_area.mouse_exited.connect(func():
			card_panel.add_theme_stylebox_override("panel", style_normal)
		)
	else:
		# offline类型：显示事件，不可点击
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var time_str = record.get("time", "")
		var event_text = record.get("event", "")
		
		# 格式化时间显示
		var display_time = _format_time_display(time_str)
		
		# 时间标签
		var time_label = Label.new()
		time_label.text = "⏰ " + display_time
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		time_label.custom_minimum_size.x = 700
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(time_label)
		
		# 事件内容
		var event_label = Label.new()
		event_label.text = event_text
		event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		event_label.custom_minimum_size.x = 700
		event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(event_label)
		
		card_panel.add_child(card_vbox)
		card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	content_vbox.add_child(card_panel)

func _on_card_gui_input(event: InputEvent, record: Dictionary, card_panel: PanelContainer, style_normal: StyleBoxFlat, click_area: Control):
	"""处理卡片的触摸/点击事件，区分滑动和点击"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 记录触摸开始位置和时间
				touch_start_pos = event.global_position
				touch_start_time = Time.get_ticks_msec() / 1000.0
				is_dragging = false
				# 确保可以捕获事件
				click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				# 触摸结束，判断是点击还是拖动
				var touch_end_time = Time.get_ticks_msec() / 1000.0
				var touch_duration = touch_end_time - touch_start_time
				var touch_distance = event.global_position.distance_to(touch_start_pos)
				
				# 只有移动距离小且时间短才算点击
				if touch_distance < DRAG_THRESHOLD and touch_duration < TAP_TIME_THRESHOLD and not is_dragging:
					_on_chat_card_clicked(record)
				
				# 重置状态
				is_dragging = false
				click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# 检测是否开始拖动
			var distance = event.global_position.distance_to(touch_start_pos)
			if distance > DRAG_THRESHOLD and not is_dragging:
				is_dragging = true
				# 恢复正常样式（取消悬停效果）
				card_panel.add_theme_stylebox_override("panel", style_normal)
				# 让事件穿透，允许ScrollContainer处理滚动
				click_area.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_chat_card_clicked(record: Dictionary):
	"""点击chat卡片，显示详细对话"""
	# 保存当前滚动位置
	if scroll_container:
		saved_scroll_position = scroll_container.scroll_vertical
	
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
		
		# 创建总结容器
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
		var separator = HSeparator.new()
		content_vbox.add_child(separator)
	
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

func _on_back_to_list():
	"""返回列表视图"""
	view_mode = "list"
	
	# 显示日期选择器，隐藏返回按钮
	if date_selector:
		date_selector.visible = true
	if back_button_container:
		back_button_container.visible = false
	
	# 重新显示列表
	_display_records()
	
	# 恢复之前保存的滚动位置
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = saved_scroll_position

func _on_prev_date_pressed():
	"""切换到前一天"""
	if current_date_index >= available_dates.size() - 1:
		return
	
	# 如果在详情视图，先返回列表
	if view_mode == "detail":
		view_mode = "list"
	
	current_date_index += 1
	_load_date_content(available_dates[current_date_index])

func _on_next_date_pressed():
	"""切换到后一天"""
	if current_date_index <= 0:
		return
	
	# 如果在详情视图，先返回列表
	if view_mode == "detail":
		view_mode = "list"
	
	current_date_index -= 1
	_load_date_content(available_dates[current_date_index])

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_diary()
	await get_tree().create_timer(ANIMATION_DURATION).timeout
	diary_closed.emit()


func _format_time_display(time_str: String) -> String:
	"""格式化offline类型时间显示
	输入: "MM-DD HH:MM" 或 "HH:MM"
	输出: "HH:MM" （只显示时间到分钟）
	"""
	if time_str.length() == 11:
		# 格式: MM-DD HH:MM，只提取时间部分
		var parts = time_str.split(" ")
		if parts.size() == 2:
			return parts[1] # 返回 HH:MM
	
	# 如果是 HH:MM 格式，直接返回
	return time_str

func _format_chat_time_display(timestamp: String) -> String:
	"""格式化chat类型时间显示
	输入: "HH:MM:SS"
	输出: "HH:MM" （只显示到分钟）
	"""
	if timestamp.length() >= 5:
		# 提取前5个字符 HH:MM
		return timestamp.substr(0, 5)
	
	return timestamp
