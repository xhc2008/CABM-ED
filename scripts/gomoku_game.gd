extends Control

signal game_ended

const BOARD_SIZE = 15
const CELL_SIZE = 40
const BOARD_MARGIN = 50

var board: Array = []
var current_player: int = 1 # 1=玩家(黑), 2=AI(白)
var game_over: bool = false
var player_first: bool = true
var game_started: bool = false
var player_name: String = "玩家"
var character_name: String = "角色"
var ai: GomokuAI = null
var ai_difficulty: int = 0 # AI难度：0=未选择(随机)，1=放水，2=随便玩玩，3=使出全力
var player_wins: int = 0 # 玩家胜场
var ai_wins: int = 0 # AI胜场
var total_moves: int = 0 # 当前局总步数
var game_in_progress: bool = false # 是否有进行中的游戏
var any_game_started: bool = false # 是否至少开始过一局游戏

# 聊天气泡相关
var ai_chat_messages: Array = [
	"让我想想...",
	"这步棋不错",
	"有意思",
	"你很厉害呢",
	"我要认真了",
	"这局很精彩",
	"继续加油",
	"好棋！",
	"⌯>ᴗo⌯ .ᐟ.ᐟ",
	"(,,>᎑<,,)",
	"(｡•ˇ‸ˇ•｡)",
	"∑(O_O；)",
	"(((╹д╹;)))",
	"(,,>᎑<,,)",
	"(*^ω^*)",
	"(∠・ω＜)⌒☆"
]

var player_chat_messages: Dictionary = {
	1: "能放点水吗",
	2: "随便玩玩就好",
	3: "使出全力吧"
}

var player_chat_tween: Tween = null
var ai_chat_tween: Tween = null
var last_move_pos: Vector2 = Vector2(-1, -1) # 最后一次落子位置

@onready var board_container: Control = $BoardContainer
@onready var back_button: Button = $BackButton
@onready var player_avatar: Panel = $PlayerAvatar
@onready var ai_avatar: Panel = $AIAvatar
@onready var ai_video: VideoStreamPlayer = $AIAvatar/AIVideo
@onready var difficulty_buttons_container: VBoxContainer = $LeftButtons/DifficultyButtons
@onready var ai_first_button: Button = $LeftButtons/AIFirstButton
@onready var player_chat_bubble: PanelContainer = $PlayerChatBubble
@onready var player_chat_label: Label = $PlayerChatBubble/Label
@onready var ai_chat_bubble: PanelContainer = $AIChatBubble
@onready var ai_chat_label: Label = $AIChatBubble/Label
@onready var player_info_label: RichTextLabel = $PlayerAvatar/PlayerInfo
@onready var ai_info_label: RichTextLabel = $AIAvatar/AIInfo

func _ready():
	# 入场动画
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	ai = GomokuAI.new()
	_init_board()
	_load_names()
	_setup_ui()
	_setup_difficulty_buttons()
	_setup_videos()
	_hide_chat_bubbles()
	back_button.pressed.connect(_on_back_pressed)
	ai_first_button.pressed.connect(_on_ai_first_pressed)
	board_container.gui_input.connect(_on_board_input)
	board_container.draw.connect(_on_board_draw)
	_draw_board()
	_update_game_info()

func _load_names():
	# 从EventHelpers获取角色名称
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		character_name = helpers.get_character_name()
	
	# 从SaveManager获取用户名
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		player_name = save_mgr.get_user_name()

func _setup_ui():
	# 设置初始UI状态
	ai_first_button.visible = true
	difficulty_buttons_container.visible = true

func _setup_difficulty_buttons():
	"""设置难度选择按钮"""
	if not difficulty_buttons_container:
		return
	
	# 创建难度按钮
	var difficulties = [
		{"text": "能放点水吗", "difficulty": 1},
		{"text": "随便玩玩就好", "difficulty": 2},
		{"text": "使出全力吧", "difficulty": 3}
	]
	
	for diff in difficulties:
		var button = Button.new()
		button.text = diff.text
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size = Vector2(160, 45)
		button.pressed.connect(_on_difficulty_selected.bind(diff.difficulty))
		difficulty_buttons_container.add_child(button)

func _setup_videos():
	"""设置角色视频"""
	if ai_video:
		var video_path = "res://assets/images/games/gomoku/1.ogv"
		if FileAccess.file_exists(video_path):
			ai_video.stream = load(video_path)
			ai_video.loop = true
			ai_video.visible = true  # 全程显示
			ai_video.play()  # 立即播放

func _hide_chat_bubbles():
	"""隐藏聊天气泡"""
	# 停止所有正在运行的tween动画
	if player_chat_tween and player_chat_tween.is_valid():
		player_chat_tween.kill()
		player_chat_tween = null
	if ai_chat_tween and ai_chat_tween.is_valid():
		ai_chat_tween.kill()
		ai_chat_tween = null
	
	if player_chat_bubble:
		player_chat_bubble.visible = false
	if ai_chat_bubble:
		ai_chat_bubble.visible = false

func _show_player_chat(message: String):
	"""显示玩家聊天气泡"""
	if not player_chat_bubble or not player_chat_label:
		return
	
	# 停止之前的动画
	if player_chat_tween and player_chat_tween.is_valid():
		player_chat_tween.kill()
	
	# 设置圆角样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 1, 0.95)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_right = 15
	style.corner_radius_bottom_left = 3
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 2)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	player_chat_bubble.add_theme_stylebox_override("panel", style)
	
	player_chat_label.text = message
	player_chat_bubble.visible = true
	player_chat_bubble.modulate.a = 0.0
	player_chat_bubble.scale = Vector2(0.8, 0.8)
	
	# 开始动画序列
	_start_player_chat_animation()

func _start_player_chat_animation():
	# 显示动画
	player_chat_tween = create_tween()
	player_chat_tween.set_parallel(true)
	player_chat_tween.tween_property(player_chat_bubble, "modulate:a", 1.0, 0.3)
	player_chat_tween.tween_property(player_chat_bubble, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# 使用回调来继续动画序列
	player_chat_tween.finished.connect(_on_player_chat_show_finished, CONNECT_ONE_SHOT)

func _on_player_chat_show_finished():
	# 创建定时器等待4秒
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_player_chat_wait_finished, CONNECT_ONE_SHOT)

func _on_player_chat_wait_finished():
	# 消失动画
	player_chat_tween = create_tween()
	player_chat_tween.set_parallel(true)
	player_chat_tween.tween_property(player_chat_bubble, "modulate:a", 0.0, 0.3)
	player_chat_tween.tween_property(player_chat_bubble, "scale", Vector2(0.8, 0.8), 0.3)
	
	# 使用回调来隐藏气泡
	player_chat_tween.finished.connect(_on_player_chat_hide_finished, CONNECT_ONE_SHOT)

func _on_player_chat_hide_finished():
	# 隐藏气泡
	if player_chat_bubble:
		player_chat_bubble.visible = false

func _show_ai_chat(message: String):
	"""显示AI聊天气泡"""
	if not ai_chat_bubble or not ai_chat_label:
		return
	
	# 停止之前的动画
	if ai_chat_tween and ai_chat_tween.is_valid():
		ai_chat_tween.kill()
	
	# 设置圆角样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 2)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	ai_chat_bubble.add_theme_stylebox_override("panel", style)
	
	ai_chat_label.text = message
	ai_chat_bubble.visible = true
	ai_chat_bubble.modulate.a = 0.0
	ai_chat_bubble.scale = Vector2(0.8, 0.8)
	
	# 开始动画序列
	_start_ai_chat_animation()

func _start_ai_chat_animation():
	# 显示动画
	ai_chat_tween = create_tween()
	ai_chat_tween.set_parallel(true)
	ai_chat_tween.tween_property(ai_chat_bubble, "modulate:a", 1.0, 0.3)
	ai_chat_tween.tween_property(ai_chat_bubble, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# 使用回调来继续动画序列
	ai_chat_tween.finished.connect(_on_ai_chat_show_finished, CONNECT_ONE_SHOT)

func _on_ai_chat_show_finished():
	# 创建定时器等待4秒
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_ai_chat_wait_finished, CONNECT_ONE_SHOT)

func _on_ai_chat_wait_finished():
	# 消失动画
	ai_chat_tween = create_tween()
	ai_chat_tween.set_parallel(true)
	ai_chat_tween.tween_property(ai_chat_bubble, "modulate:a", 0.0, 0.3)
	ai_chat_tween.tween_property(ai_chat_bubble, "scale", Vector2(0.8, 0.8), 0.3)
	
	# 使用回调来隐藏气泡
	ai_chat_tween.finished.connect(_on_ai_chat_hide_finished, CONNECT_ONE_SHOT)

func _on_ai_chat_hide_finished():
	# 隐藏气泡
	if ai_chat_bubble:
		ai_chat_bubble.visible = false

func _on_difficulty_selected(difficulty: int):
	"""选择难度"""
	ai_difficulty = difficulty
	difficulty_buttons_container.visible = false
	
	# 显示玩家聊天气泡
	var message = player_chat_messages.get(difficulty, "")
	if message:
		_show_player_chat(message)
	
	print("选择难度: ", difficulty)

func _init_board():
	board.clear()
	for i in range(BOARD_SIZE):
		var row = []
		for j in range(BOARD_SIZE):
			row.append(0)
		board.append(row)
	game_over = false
	current_player = 1
	player_first = true
	total_moves = 0
	last_move_pos = Vector2(-1, -1) # 重置最后落子位置

func _draw_board():
	if board_container:
		board_container.queue_redraw()

func _on_board_draw():
	var start_pos = Vector2(BOARD_MARGIN, BOARD_MARGIN)
	
	# 绘制棋盘线
	for i in range(BOARD_SIZE):
		var y = start_pos.y + i * CELL_SIZE
		board_container.draw_line(
			Vector2(start_pos.x, y),
			Vector2(start_pos.x + (BOARD_SIZE - 1) * CELL_SIZE, y),
			Color.BLACK, 2
		)
		
		var x = start_pos.x + i * CELL_SIZE
		board_container.draw_line(
			Vector2(x, start_pos.y),
			Vector2(x, start_pos.y + (BOARD_SIZE - 1) * CELL_SIZE),
			Color.BLACK, 2
		)
	
	# 绘制棋子
	for i in range(BOARD_SIZE):
		for j in range(BOARD_SIZE):
			if board[i][j] != 0:
				var pos = Vector2(
					start_pos.x + j * CELL_SIZE,
					start_pos.y + i * CELL_SIZE
				)
				var color = Color.BLACK if board[i][j] == 1 else Color.WHITE
				board_container.draw_circle(pos, CELL_SIZE * 0.4, color)
				if board[i][j] == 2:
					board_container.draw_arc(pos, CELL_SIZE * 0.4, 0, TAU, 32, Color.BLACK, 2)
				
				# 标记最后一次落子位置
				if i == last_move_pos.y and j == last_move_pos.x:
					var marker_color = Color.RED if board[i][j] == 1 else Color.ORANGE_RED
					board_container.draw_circle(pos, CELL_SIZE * 0.15, marker_color)

func _on_board_input(event: InputEvent):
	if game_over or current_player != 1:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 第一次点击时开始游戏
		if not game_started:
			# 如果没选择难度，随机选择
			if ai_difficulty == 0:
				ai_difficulty = randi() % 3 + 1
				print("随机难度: ", ai_difficulty)
			_start_game()
		
		var pos = event.position
		var row = int((pos.y - BOARD_MARGIN + CELL_SIZE / 2.0) / CELL_SIZE)
		var col = int((pos.x - BOARD_MARGIN + CELL_SIZE / 2.0) / CELL_SIZE)
		
		if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
			if board[row][col] == 0:
				_place_stone(row, col, 1)

func _start_game():
	game_started = true
	game_in_progress = true
	any_game_started = true
	ai_first_button.visible = false
	difficulty_buttons_container.visible = false
	
	# 视频已经在_setup_videos中设置为全程显示
	
	_update_game_info()

func _place_stone(row: int, col: int, player: int):
	board[row][col] = player
	total_moves += 1
	
	# 记录最后一次落子位置
	last_move_pos = Vector2(col, row)
	
	# 落子动画
	_play_stone_animation(row, col, player)
	
	if _check_win(row, col, player):
		game_over = true
		game_in_progress = false
		_show_winner(player)
		return
	
	if _is_board_full():
		game_over = true
		game_in_progress = false
		_show_draw()
		return
	
	current_player = 3 - current_player
	_update_game_info()
	
	if current_player == 2:
		# AI回合，延迟后再执行AI移动
		await get_tree().create_timer(0.3).timeout
		
		# 有50%概率显示聊天气泡
		if randf() < 0.5:
			var message = ai_chat_messages[randi() % ai_chat_messages.size()]
			_show_ai_chat(message)
		
		# 再等待一下让气泡显示
		await get_tree().create_timer(0.5).timeout
		_ai_move()

func _play_stone_animation(row: int, col: int, player: int):
	"""播放落子动画"""
	# 创建临时节点用于动画
	var stone_anim = ColorRect.new()
	var start_pos = Vector2(BOARD_MARGIN, BOARD_MARGIN)
	var board_pos = Vector2(
		start_pos.x + col * CELL_SIZE,
		start_pos.y + row * CELL_SIZE
	)
	
	# 相对于board_container的位置
	stone_anim.position = board_pos - Vector2(CELL_SIZE * 0.4, CELL_SIZE * 0.4)
	stone_anim.size = Vector2(CELL_SIZE * 0.8, CELL_SIZE * 0.8)
	stone_anim.color = Color.BLACK if player == 1 else Color.WHITE
	
	# 直接添加到board_container
	board_container.add_child(stone_anim)
	
	# 缩放动画
	stone_anim.scale = Vector2(0.1, 0.1)
	stone_anim.modulate.a = 0.5
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(stone_anim, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(stone_anim, "modulate:a", 1.0, 0.2)
	await tween.finished
	
	# 清理并重绘棋盘
	stone_anim.queue_free()
	_draw_board()

func _update_game_info():
	"""更新游戏信息显示"""
	# 更新头像下的信息
	if player_info_label:
		var info_parts = []
		
		# 名字和先手标记
		if player_first and game_started:
			info_parts.append("%s [先手]" % player_name)
		else:
			info_parts.append(player_name)
		
		# 比分
		info_parts.append("比分: %d" % player_wins)
		
		# 状态
		if game_started and not game_over:
			if current_player == 1:
				info_parts.append("[color=#00AA00]你的回合[/color]")
			else:
				info_parts.append("[color=#888888]等待中[/color]")
		
		player_info_label.text = "\n".join(info_parts)
	
	if ai_info_label:
		var info_parts = []
		
		# 名字和先手标记
		if not player_first and game_started:
			info_parts.append("%s [先手]" % character_name)
		else:
			info_parts.append(character_name)
		
		# 比分
		info_parts.append("比分: %d" % ai_wins)
		
		# 状态
		if game_started and not game_over:
			if current_player == 2:
				info_parts.append("[color=#FF6600]思考中[/color]")
			else:
				info_parts.append("[color=#888888]等待中[/color]")
		
		ai_info_label.text = "\n".join(info_parts)

func _ai_move():
	# 分帧执行AI计算，避免长时间阻塞
	var move = await _calculate_ai_move_deferred()
	if move and move.has("row") and move.has("col"):
		_place_stone(move.row, move.col, 2)

func _calculate_ai_move_deferred():
	# 等待一帧后执行，让UI有机会更新
	await get_tree().process_frame
	var move = ai.get_next_move(board, BOARD_SIZE, 2, 1, ai_difficulty)
	return move

func _check_win(row: int, col: int, player: int) -> bool:
	return ai._check_win(row, col, player, board, BOARD_SIZE)

func _is_board_full() -> bool:
	for i in range(BOARD_SIZE):
		for j in range(BOARD_SIZE):
			if board[i][j] == 0:
				return false
	return true

func _show_winner(player: int):
	var winner_name = player_name if player == 1 else character_name
	
	# 更新比分
	if player == 1:
		player_wins += 1
	else:
		ai_wins += 1
	
	# 播放胜利/失败动画
	_play_game_end_animation(player)
	
	_show_game_result(winner_name + " 获胜！")
	_update_game_info()
	
	# 显示"再来一局"按钮
	_show_restart_button()

func _play_game_end_animation(winner: int):
	"""播放游戏结束动画"""
	if winner == 1:
		# 玩家胜利动画
		if player_avatar:
			var tween = create_tween()
			tween.tween_property(player_avatar, "modulate", Color(1.2, 1.2, 0.8), 0.3)
			tween.tween_property(player_avatar, "modulate", Color.WHITE, 0.3)
	else:
		# AI胜利动画
		if ai_avatar:
			var tween = create_tween()
			tween.tween_property(ai_avatar, "modulate", Color(1.2, 1.2, 0.8), 0.3)
			tween.tween_property(ai_avatar, "modulate", Color.WHITE, 0.3)

func _show_restart_button():
	"""显示再来一局按钮"""
	var restart_button = Button.new()
	restart_button.text = "再来一局"
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.custom_minimum_size = Vector2(200, 60)
	restart_button.position = Vector2(get_viewport_rect().size.x / 2 - 100, 400)
	restart_button.pressed.connect(_on_restart_pressed)
	add_child(restart_button)

func _show_draw():
	_show_game_result("平局！")

func _show_game_result(message: String):
	# 创建结果提示
	var result_label = Label.new()
	result_label.text = message
	result_label.add_theme_font_size_override("font_size", 32)
	result_label.add_theme_color_override("font_color", Color.RED)
	result_label.add_theme_color_override("font_outline_color", Color.WHITE)
	result_label.add_theme_constant_override("outline_size", 4)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.position = Vector2(get_viewport_rect().size.x / 2 - 150, 300)
	result_label.size = Vector2(300, 100)
	add_child(result_label)
	
	print(message)

func _on_back_pressed():
	# 退出动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# 保存游戏记录到日记
	_save_game_to_diary()
	
	game_ended.emit()

func _save_game_to_diary():
	"""保存游戏记录到日记和记忆"""
	# 如果一局游戏都没开始，不记录
	if not any_game_started:
		return
	
	# 构建日记内容
	var diary_content = ""
	var total_games = player_wins + ai_wins
	
	if total_games == 0:
		# 一局都没完成
		if game_in_progress:
			diary_content = "我和%s玩了五子棋，但我们还没分出胜负" % player_name
		else:
			return # 没有开始游戏，不记录
	else:
		# 至少完成了一局
		var result_text = ""
		if player_wins > ai_wins:
			result_text = "我输了"
		elif player_wins < ai_wins:
			result_text = "我赢了"
		else:
			result_text = "我们打成了平手"
		
		diary_content = "我和%s玩了%d局五子棋，%s，比分%d比%d" % [player_name, total_games, result_text, ai_wins, player_wins]
	
	# 使用统一记忆保存器
	var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if unified_saver:
		await unified_saver.save_memory(
			diary_content,
			unified_saver.MemoryType.GAMES,
			null, # 使用当前时间
			"",
			{}
		)
		print("五子棋游戏记录已保存: ", diary_content)
	else:
		push_warning("UnifiedMemorySaver 未找到，游戏记录未保存")

func _on_restart_pressed():
	"""重新开始游戏"""
	# 移除"再来一局"按钮和结果标签
	for child in get_children():
		if (child is Button and child.text == "再来一局") or (child is Label and (child.text.contains("获胜") or child.text.contains("平局"))):
			child.queue_free()
	
	# 重置棋盘
	_init_board()
	_draw_board()
	
	# 重置UI
	game_started = false
	game_in_progress = false
	total_moves = 0
	ai_difficulty = 0 # 重置难度选择
	ai_first_button.visible = true
	difficulty_buttons_container.visible = true
	
	# 视频保持显示，只隐藏聊天气泡
	_hide_chat_bubbles()
	
	_update_game_info()

func _on_ai_first_pressed():
	if game_over or board[7][7] != 0:
		return
	
	# 如果没选择难度，随机选择
	if ai_difficulty == 0:
		ai_difficulty = randi() % 3 + 1
		print("随机难度: ", ai_difficulty)
	
	player_first = false
	_start_game()
	
	# 显示玩家聊天气泡
	_show_player_chat("还是你先吧")
	
	# 直接在中心落子，不触发 _place_stone 的玩家切换逻辑
	board[7][7] = 2
	total_moves = 1
	last_move_pos = Vector2(7, 7) # 记录AI先手的落子位置
	_draw_board()
	_update_game_info()
	# 不切换玩家，保持 current_player = 1，让玩家继续