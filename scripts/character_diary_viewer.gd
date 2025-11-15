extends Panel
signal diary_closed
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var search_container: HBoxContainer = $MarginContainer/VBoxContainer/SearchContainer
@onready var search_input: LineEdit = $MarginContainer/VBoxContainer/SearchContainer/SearchInput
@onready var search_button: Button = $MarginContainer/VBoxContainer/SearchContainer/SearchButton
@onready var clear_search_button: Button = $MarginContainer/VBoxContainer/SearchContainer/ClearSearchButton
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
var view_mode: String = "list" # "list" = 列表视图, "detail" = 详情视图, "search" = 搜索结果视图
var current_detail_record: Dictionary = {} # 当前查看的详细记录
var back_button_container: HBoxContainer = null # 返回按钮容器
var saved_scroll_position: int = 0 # 保存的滚动位置（用于从详情返回列表时恢复）
var search_results: Array = [] # 搜索结果列表
var current_search_keyword: String = "" # 当前搜索关键词

var CHINESE_PUNCTUATION = ["。", "！", "？", "；"]
var current_playing_sentences: Array[String] = [] # 当前正在播放的句子列表
var current_sentence_index: int = 0 # 当前播放的句子索引
var audio_player: AudioStreamPlayer = null # 音频播放器
var is_playing_audio: bool = false # 是否正在播放音频

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
	if search_button:
		search_button.pressed.connect(_on_search_button_pressed)
	if clear_search_button:
		clear_search_button.pressed.connect(_on_clear_search_pressed)
	if search_input:
		search_input.text_submitted.connect(_on_search_submitted)
	
	# 创建音频播放器
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.finished.connect(_on_audio_finished)
	
	# 连接窗口关闭信号
	diary_closed.connect(_on_diary_closed)

# 新增函数：处理日记窗口关闭
func _on_diary_closed():
	"""日记窗口关闭时中断播放"""
	stop_audio_playback()

func stop_audio_playback():
	"""停止所有音频播放"""
	if audio_player and audio_player.playing:
		audio_player.stop()
	current_playing_sentences.clear()
	current_sentence_index = 0
	is_playing_audio = false
	# 重置所有播放按钮样式
	_update_all_play_buttons()

# 新增函数：分句
func split_sentences(text: String) -> Array[String]:
	var sentences: Array[String] = []
	var current_sentence = ""
	
	for i in range(text.length()):
		var char1 = text[i]
		current_sentence += char1
		
		if char1 in CHINESE_PUNCTUATION:
			sentences.append(current_sentence.strip_edges())
			current_sentence = ""
	
	# 添加最后一句（如果有）
	if not current_sentence.is_empty():
		sentences.append(current_sentence.strip_edges())
	
	return sentences

# 新增函数：计算句子哈希
func compute_sentence_hash(text: String) -> String:
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(text.to_utf8_buffer())
	var hash_bytes = hashing_context.finish()
	return hash_bytes.hex_encode()

# 新增函数：获取音频文件路径
func get_audio_file(sentence_hash: String) -> String:
	return "user://speech/" + sentence_hash + ".mp3"

# 新增函数：播放角色对话
func play_character_speech(content: String):
	"""播放角色的对话语音"""
	# 停止当前播放
	stop_audio_playback()
	
	# 分句
	var sentences = split_sentences(content)
	if sentences.is_empty():
		return
	
	# 过滤掉空句子
	current_playing_sentences = []
	for sentence in sentences:
		if not sentence.strip_edges().is_empty():
			current_playing_sentences.append(sentence)
	
	if current_playing_sentences.is_empty():
		return
	
	# 开始播放第一句
	current_sentence_index = 0
	is_playing_audio = true
	_play_next_sentence()

# 新增函数：播放下一句
func _play_next_sentence():
	"""播放下一句语音"""
	if current_sentence_index >= current_playing_sentences.size() or not is_playing_audio:
		# 播放完成
		is_playing_audio = false
		return
	
	var sentence = current_playing_sentences[current_sentence_index]
	var sentence_hash = compute_sentence_hash(sentence)
	var audio_path = get_audio_file(sentence_hash)
	
	# 检查文件是否存在
	if not FileAccess.file_exists(audio_path):
		# 文件不存在，跳过这句
		print("音频文件不存在: ", audio_path)
		current_sentence_index += 1
		_play_next_sentence()
		return
	
	# 加载并播放音频
	var file = FileAccess.open(audio_path, FileAccess.READ)
	if file:
		var audio_stream = AudioStreamMP3.new()
		audio_stream.data = file.get_buffer(file.get_length())
		audio_player.stream = audio_stream
		audio_player.play()
		print("正在播放: ", sentence)
	else:
		# 文件读取失败，跳过这句
		print("无法读取音频文件: ", audio_path)
		current_sentence_index += 1
		_play_next_sentence()

func _on_audio_finished():
	"""一句音频播放完成"""
	current_sentence_index += 1
	if current_sentence_index >= current_playing_sentences.size():
		# 播放完成，重置所有按钮
		stop_audio_playback()
	else:
		# 播放下一句
		_play_next_sentence()

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
	current_search_keyword = ""
	if search_input:
		search_input.text = ""
	if search_container:
		search_container.visible = true
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
	if not has_node("/root/SaveManager"):
		return "角色"
	
	var save_mgr = get_node("/root/SaveManager")
	return save_mgr.get_character_name()

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

# --- 通用辅助函数 ---
func _get_icon_and_content_for_record(record: Dictionary) -> Dictionary:
	"""
	根据记录类型，返回图标和内容文本的字典。
	适用于 cook, games, offline 类型。
	"""
	var record_type = record.get("type", "offline")
	var time_str = record.get("time", "")
	var event_text = record.get("event", "")

	var icon = ""
	var content_text = event_text # 默认内容为 event

	match record_type:
		"games":
			icon = "🎮"
		"cook":
			icon = "🍳"
			# 如果 cook 类型有 details 字段，优先使用
			var details = record.get("details", "")
			if not details.is_empty():
				content_text = details
		"offline":
			icon = "⏰"
		_:
			icon = "❓" # 未知类型图标

	return {
		"icon": icon,
		"display_time": _format_time_display(time_str),
		"content_text": content_text
	}

func _create_panel_style() -> StyleBoxFlat:
	"""创建一个通用的卡片面板样式"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 15
	style.content_margin_top = 15
	style.content_margin_right = 15
	style.content_margin_bottom = 15
	return style

func _add_diary_card(record: Dictionary):
	"""添加一个日记卡片"""
	var record_type = record.get("type", "offline") # 默认为offline类型

	# 创建卡片容器
	var card_panel = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.add_theme_stylebox_override("panel", _create_panel_style())

	# 创建内容容器
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # 内容区域忽略鼠标事件

	if record_type == "chat":
		# chat类型：显示总结，可点击查看详情
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
		click_area.gui_input.connect(_on_card_gui_input.bind(record, card_panel, _create_panel_style(), click_area))

		# 鼠标悬停效果（仅桌面端）
		click_area.mouse_entered.connect(func():
			if not is_dragging:
				var style_hover = _create_panel_style().duplicate()
				style_hover.bg_color = Color(0.2, 0.2, 0.25, 0.7)
				style_hover.border_color = Color(0.4, 0.4, 0.5, 0.9)
				card_panel.add_theme_stylebox_override("panel", style_hover)
		)
		click_area.mouse_exited.connect(func():
			card_panel.add_theme_stylebox_override("panel", _create_panel_style())
		)
	else:
		# cook, games, offline 类型：不可点击，使用通用函数
		var data = _get_icon_and_content_for_record(record)
		# 时间标签
		var time_label = Label.new()
		time_label.text = data.icon + " " + data.display_time
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		time_label.custom_minimum_size.x = 700
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(time_label)
		# 内容标签
		var content_label = Label.new()
		content_label.text = data.content_text
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		content_label.custom_minimum_size.x = 700
		content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(content_label)
		card_panel.add_child(card_vbox)
		card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # 整个卡片不可点击

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

	var record_type = current_detail_record.get("type", "offline")

	# 处理不同类型的详情视图
	if record_type == "chat":
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

				# 使用新的带播放按钮的布局
				var speech_line = _create_speech_with_play_button(speaker, content)
				content_vbox.add_child(speech_line)

	# 滚动到顶部
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = 0

# 新增函数：创建带播放按钮的对话内容（保持上下布局）
func _create_speech_with_play_button(speaker: String, content: String) -> Control:
	"""创建带播放按钮的对话行（保持上下布局）"""
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 2)

	# 第一行：说话者 + 播放按钮
	var speaker_hbox = HBoxContainer.new()
	speaker_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_hbox.add_theme_constant_override("separation", 10)
	
	# 说话者标签
	var speaker_label = Label.new()
	speaker_label.text = speaker
	speaker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_hbox.add_child(speaker_label)
	
	# 播放按钮（只有角色对话才有）
	var is_character = speaker == _get_character_name()
	if is_character:
		var play_button = Button.new()
		play_button.text = "🔊"  # 未播放状态
		play_button.flat = true  # 扁平样式
		play_button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		play_button.add_theme_font_size_override("font_size", 18)
		play_button.custom_minimum_size = Vector2(30, 30)  # 小一些的按钮
		play_button.focus_mode = Control.FOCUS_NONE  # 无焦点框
		play_button.pressed.connect(_on_play_button_pressed.bind(content, play_button))
		speaker_hbox.add_child(play_button)
	
	# 添加弹性空间，让播放按钮靠左
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_hbox.add_child(spacer)
	
	container.add_child(speaker_hbox)

	# 第二行：内容标签
	var content_label = Label.new()
	content_label.text = content
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.custom_minimum_size.x = 500
	content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(content_label)
	
	return container

# 新增函数：播放按钮点击处理
func _on_play_button_pressed(content: String, button: Button):
	"""播放按钮点击事件"""
	if not is_playing_audio:
		# 开始播放
		play_character_speech(content)
		# 更新按钮样式为播放中
		button.text = "⏹️"  # 播放中状态
		button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		# 停止播放
		stop_audio_playback()
		# 恢复按钮样式
		_reset_play_button_style(button)

# 新增函数：重置播放按钮样式
func _reset_play_button_style(button: Button):
	"""重置播放按钮为默认样式"""
	button.text = "🔊"
	button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

# 新增函数：更新所有播放按钮状态
func _update_all_play_buttons():
	"""更新所有播放按钮的状态（停止播放时调用）"""
	for child in content_vbox.get_children():
		_find_and_reset_play_buttons(child)

# 新增函数：递归查找并重置播放按钮
func _find_and_reset_play_buttons(node: Node):
	"""递归查找并重置所有播放按钮"""
	if node is Button and node.text == "⏹️":
		_reset_play_button_style(node)
	
	for child in node.get_children():
		_find_and_reset_play_buttons(child)

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

func _on_search_button_pressed():
	"""搜索按钮点击"""
	if search_input:
		_perform_search(search_input.text)

func _on_search_submitted(text: String):
	"""搜索框回车提交"""
	_perform_search(text)

func _on_clear_search_pressed():
	"""清除搜索"""
	if search_input:
		search_input.text = ""
	current_search_keyword = ""
	view_mode = "list"
	# 恢复日期选择器
	if date_selector:
		date_selector.visible = true
	# 重新加载当前日期内容
	if not available_dates.is_empty():
		_load_date_content(available_dates[current_date_index])

func _perform_search(keyword: String):
	"""执行搜索"""
	keyword = keyword.strip_edges()
	if keyword.is_empty():
		return
	current_search_keyword = keyword
	view_mode = "search"
	search_results.clear()

	# 隐藏日期选择器
	if date_selector:
		date_selector.visible = false
	if back_button_container:
		back_button_container.visible = false

	# 搜索所有日期的日记
	for date_str in available_dates:
		var diary_path = "user://diary/" + date_str + ".jsonl"
		var file = FileAccess.open(diary_path, FileAccess.READ)
		if file == null:
			continue

		# 读取所有记录
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line.is_empty():
				continue
			var json = JSON.new()
			if json.parse(line) == OK:
				var record = json.data
				# 检查记录是否包含关键词
				if _record_contains_keyword(record, keyword):
					# 添加日期信息到记录
					var search_result = record.duplicate()
					search_result["_date"] = date_str
					search_results.append(search_result)
		file.close()

	# 显示搜索结果
	_display_search_results()

func _record_contains_keyword(record: Dictionary, keyword: String) -> bool:
	"""检查记录是否包含关键词（不区分大小写）"""
	var keyword_lower = keyword.to_lower()
	var record_type = record.get("type", "offline")

	if record_type == "chat":
		# 搜索总结和对话内容
		var summary = record.get("summary", "").to_lower()
		var conversation = record.get("conversation", "").to_lower()
		return keyword_lower in summary or keyword_lower in conversation
	elif record_type == "cook":
		# 搜索事件内容和详情
		var event = record.get("event", "").to_lower()
		var details = record.get("details", "").to_lower()
		return keyword_lower in event or keyword_lower in details
	else:
		# 搜索事件内容 (games, offline)
		var event = record.get("event", "").to_lower()
		return keyword_lower in event

func _display_search_results():
	"""显示搜索结果"""
	# 清空当前内容
	for child in content_vbox.get_children():
		child.queue_free()

	if search_results.is_empty():
		# 显示无结果提示
		var no_result_label = Label.new()
		no_result_label.text = "未找到包含 \"%s\" 的日记记录" % current_search_keyword
		no_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		content_vbox.add_child(no_result_label)
	else:
		# 显示结果数量
		var result_count_label = Label.new()
		result_count_label.text = "找到 %d 条包含 \"%s\" 的记录" % [search_results.size(), current_search_keyword]
		result_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_count_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		content_vbox.add_child(result_count_label)

		# 添加分隔线
		var separator = HSeparator.new()
		content_vbox.add_child(separator)

		# 显示所有搜索结果（按日期降序）
		for result in search_results:
			_add_search_result_card(result)

	# 滚动到顶部
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = 0

func _add_search_result_card(record: Dictionary):
	"""添加搜索结果卡片（带日期标签）"""
	var date_str = record.get("_date", "")
	var record_type = record.get("type", "offline")

	# 创建卡片容器
	var card_panel = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.add_theme_stylebox_override("panel", _create_panel_style())

	# 创建内容容器
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # 内容区域忽略鼠标事件

	# 添加日期标签
	var date_label_widget = Label.new()
	date_label_widget.text = "📅 " + date_str
	date_label_widget.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	date_label_widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	date_label_widget.custom_minimum_size.x = 700
	date_label_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(date_label_widget)

	if record_type == "chat":
		# chat类型：显示总结，可点击查看详情
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
		# 总结内容（截断显示，并高亮关键词）
		var summary_label = RichTextLabel.new()
		summary_label.bbcode_enabled = true
		var display_summary = summary
		if summary.length() > 150:
			display_summary = summary.substr(0, 150) + "..."
		summary_label.text = _highlight_keyword(display_summary, current_search_keyword)
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_label.fit_content = true
		summary_label.scroll_active = false
		summary_label.custom_minimum_size.x = 700
		summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(summary_label)
		card_panel.add_child(card_vbox)

		# 使用Control代替Button，手动处理触摸事件
		var click_area = Control.new()
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		click_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_panel.add_child(click_area)

		# 手动处理触摸/点击事件
		click_area.gui_input.connect(_on_card_gui_input.bind(record, card_panel, _create_panel_style(), click_area))

		# 鼠标悬停效果
		click_area.mouse_entered.connect(func():
			if not is_dragging:
				var style_hover = _create_panel_style().duplicate()
				style_hover.bg_color = Color(0.2, 0.2, 0.25, 0.7)
				style_hover.border_color = Color(0.4, 0.4, 0.5, 0.9)
				card_panel.add_theme_stylebox_override("panel", style_hover)
		)
		click_area.mouse_exited.connect(func():
			card_panel.add_theme_stylebox_override("panel", _create_panel_style())
		)
	else:
		# cook, games, offline 类型：不可点击，使用通用函数处理内容和高亮
		var data = _get_icon_and_content_for_record(record)
		# 时间标签
		var time_label = Label.new()
		time_label.text = data.icon + " " + data.display_time
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		time_label.custom_minimum_size.x = 700
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(time_label)
		# 内容标签（使用 RichTextLabel 高亮关键词）
		var content_label = RichTextLabel.new()
		content_label.bbcode_enabled = true
		content_label.text = _highlight_keyword(data.content_text, current_search_keyword)
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.fit_content = true
		content_label.scroll_active = false
		content_label.custom_minimum_size.x = 700
		content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(content_label)
		card_panel.add_child(card_vbox)
		card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # 整个卡片不可点击

	content_vbox.add_child(card_panel)

func _highlight_keyword(text: String, keyword: String) -> String:
	"""高亮显示关键词（使用BBCode）"""
	if keyword.is_empty():
		return text
	# 不区分大小写地查找并替换
	var result = text
	var keyword_lower = keyword.to_lower()
	var text_lower = text.to_lower()
	var start_pos = 0
	while true:
		var pos = text_lower.find(keyword_lower, start_pos)
		if pos == -1:
			break
		# 获取原文中的实际文本（保持大小写）
		var original_keyword = text.substr(pos, keyword.length())
		var before = text.substr(0, pos)
		var after = text.substr(pos + keyword.length())
		# 使用黄色高亮
		result = before + "[color=yellow]" + original_keyword + "[/color]" + after
		text = result
		text_lower = text.to_lower()
		start_pos = pos + "[color=yellow]".length() + keyword.length() + "[/color]".length()
	return result

func _format_time_display(time_str: String) -> String:
	"""格式化offline, games, cook 类型时间显示
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
