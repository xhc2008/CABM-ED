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
const MESSAGES_PER_PAGE = 20

var available_dates: Array = [] # 可用的日期列表（降序）
var current_date_index: int = 0
var current_messages: Array = [] # 当前日期的所有消息
var displayed_message_count: int = 0 # 已显示的消息数量

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
	
	# 连接滚动事件
	if scroll_container:
		scroll_container.get_v_scroll_bar().scrolling.connect(_on_scroll_changed)

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
	
	current_messages.clear()
	displayed_message_count = 0
	
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
	
	# 读取所有对话记录
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		
		var json = JSON.new()
		if json.parse(line) == OK:
			var record = json.data
			current_messages.append(record)
	
	file.close()
	
	# 反转消息顺序（最新的在最下面）
	current_messages.reverse()
	
	print("加载了 ", current_messages.size(), " 条对话记录")
	
	# 显示第一页
	_display_more_messages()
	
	# 滚动到底部
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _display_more_messages():
	"""显示更多消息（分页加载）"""
	var messages_to_show = min(MESSAGES_PER_PAGE, current_messages.size() - displayed_message_count)
	
	if messages_to_show <= 0:
		return
	
	for i in range(messages_to_show):
		var record = current_messages[displayed_message_count + i]
		_add_conversation_block(record)
	
	displayed_message_count += messages_to_show
	print("已显示 ", displayed_message_count, " / ", current_messages.size(), " 条记录")

func _add_conversation_block(record: Dictionary):
	"""添加一个对话块到界面"""
	var timestamp = record.get("timestamp", "")
	var messages = record.get("messages", [])
	
	# 创建对话块容器 - 使用 PanelContainer 而不是 Panel
	var block_container = PanelContainer.new()
	block_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 添加轻微的背景色以区分不同的对话块
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.3)  # 半透明深色背景
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.3, 0.3, 0.3, 0.5)  # 边框
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	style_box.content_margin_left = 15
	style_box.content_margin_top = 15
	style_box.content_margin_right = 15
	style_box.content_margin_bottom = 15
	block_container.add_theme_stylebox_override("panel", style_box)
	
	var block_vbox = VBoxContainer.new()
	block_vbox.add_theme_constant_override("separation", 8)
	block_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_container.add_child(block_vbox)
	
	# 添加时间戳
	var time_label = Label.new()
	time_label.text = "⏰ " + timestamp
	time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	block_vbox.add_child(time_label)
	
	# 添加分隔线
	var separator = HSeparator.new()
	block_vbox.add_child(separator)
	
	# 添加每句对话（每句话单独一行）
	for msg in messages:
		var speaker = msg.get("speaker", "")
		var content = msg.get("content", "")
		
		# 创建一个容器来包含说话者和内容
		var msg_container = VBoxContainer.new()
		msg_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg_container.add_theme_constant_override("separation", 2)
		
		# 说话者标签（灰色）
		var speaker_label = Label.new()
		speaker_label.text = speaker
		speaker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		msg_container.add_child(speaker_label)
		
		# 内容标签（正常大小，自动换行）
		var content_label = Label.new()
		content_label.text = content
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		content_label.custom_minimum_size.x = 500
		msg_container.add_child(content_label)
		
		block_vbox.add_child(msg_container)
	
	# 添加到内容容器（在顶部插入，因为我们要从旧到新显示）
	content_vbox.add_child(block_container)
	content_vbox.move_child(block_container, 0)

func _on_scroll_changed():
	"""滚动条变化时检查是否需要加载更多"""
	if scroll_container == null:
		return
	
	var v_scroll = scroll_container.get_v_scroll_bar()
	
	# 如果滚动到顶部，加载更多旧消息
	if v_scroll.value <= 10 and displayed_message_count < current_messages.size():
		var old_scroll_height = v_scroll.max_value
		_display_more_messages()
		
		# 等待布局更新
		await get_tree().process_frame
		
		# 保持滚动位置（补偿新增内容的高度）
		var new_scroll_height = v_scroll.max_value
		var height_diff = new_scroll_height - old_scroll_height
		scroll_container.scroll_vertical = int(v_scroll.value + height_diff)

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
