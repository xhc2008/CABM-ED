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
var ai_difficulty: int = 2 # AI难度：1=放水，2=随便玩玩，3=使出全力
var player_wins: int = 0 # 玩家胜场
var ai_wins: int = 0 # AI胜场
var total_moves: int = 0 # 当前局总步数
var game_in_progress: bool = false # 是否有进行中的游戏

@onready var board_container: Control = $BoardContainer
@onready var player_info: Panel = $LeftPanel
@onready var ai_info: Panel = $RightPanel
@onready var back_button: Button = $BackButton
@onready var start_hint: Label = $LeftPanel/StartHint
@onready var ai_first_button: Button = $RightPanel/AIFirstButton
@onready var player_name_label: Label = $LeftPanel/PlayerName
@onready var player_turn_label: Label = $LeftPanel/TurnLabel
@onready var ai_name_label: Label = $RightPanel/AIName
@onready var ai_turn_label: Label = $RightPanel/TurnLabel
@onready var difficulty_container: VBoxContainer = $DifficultyContainer
@onready var game_info_label: Label = $GameInfoLabel
@onready var player_video: VideoStreamPlayer = $LeftPanel/PlayerVideo
@onready var ai_video: VideoStreamPlayer = $RightPanel/AIVideo

func _ready():
	# 入场动画
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	ai = GomokuAI.new()
	_init_board()
	_load_character_name()
	_setup_ui()
	_setup_difficulty_buttons()
	_setup_videos()
	back_button.pressed.connect(_on_back_pressed)
	ai_first_button.pressed.connect(_on_ai_first_pressed)
	board_container.gui_input.connect(_on_board_input)
	board_container.draw.connect(_on_board_draw)
	_draw_board()
	_update_game_info()

func _load_character_name():
	# 从EventHelpers获取角色名称
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		character_name = helpers.get_character_name()

func _setup_ui():
	# 设置初始UI状态
	player_name_label.text = player_name
	ai_name_label.text = character_name
	start_hint.visible = true
	ai_first_button.visible = true
	player_turn_label.visible = false
	ai_turn_label.visible = false
	
	# 放大开始提示
	if start_hint:
		start_hint.add_theme_font_size_override("font_size", 24)
		start_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	
	# 放大"你先吧"按钮
	if ai_first_button:
		ai_first_button.add_theme_font_size_override("font_size", 22)
	
	_update_turn_display()

func _setup_difficulty_buttons():
	"""设置难度选择按钮"""
	if not difficulty_container:
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
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(180, 50)
		button.pressed.connect(_on_difficulty_selected.bind(diff.difficulty))
		difficulty_container.add_child(button)
	
	difficulty_container.visible = true

func _setup_videos():
	"""设置角色视频"""
	if player_video:
		player_video.visible = false
	if ai_video:
		var video_path = "res://assets/images/character/games/chess.mp4"
		if FileAccess.file_exists(video_path):
			# 注意：Godot 4需要使用VideoStreamTheora或其他支持的格式
			# 如果chess.mp4不是Theora格式，可能需要转换
			ai_video.stream = load(video_path)
			ai_video.loop = true
			ai_video.visible = false

func _on_difficulty_selected(difficulty: int):
	"""选择难度"""
	ai_difficulty = difficulty
	difficulty_container.visible = false
	
	# 显示选择的难度提示
	var difficulty_names = {1: "放水模式", 2: "普通模式", 3: "全力模式"}
	print("选择难度: ", difficulty_names.get(difficulty, "未知"))

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
					board_container.draw_circle(pos, CELL_SIZE * 0.4, Color.BLACK, false, 2)

func _on_board_input(event: InputEvent):
	if game_over or current_player != 1:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 第一次点击时开始游戏
		if not game_started:
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
	start_hint.visible = false
	ai_first_button.visible = false
	difficulty_container.visible = false
	player_turn_label.visible = true
	ai_turn_label.visible = true
	
	# 显示角色视频
	if ai_video and ai_video.stream:
		ai_video.visible = true
		ai_video.play()
	
	_update_turn_display()
	_update_game_info()

func _place_stone(row: int, col: int, player: int):
	board[row][col] = player
	total_moves += 1
	
	# 落子动画
	_play_stone_animation(row, col, player)
	_draw_board()
	_update_game_info()
	
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
	_update_turn_display()
	
	if current_player == 2:
		await get_tree().create_timer(0.5).timeout
		_ai_move()

func _play_stone_animation(_row: int, _col: int, _player: int):
	"""播放落子动画"""
	# 简单的缩放动画效果
	# TODO: 可以在这里添加落子的视觉效果
	pass

func _update_game_info():
	"""更新游戏信息显示"""
	if not game_info_label:
		return
	
	var info_text = ""
	if game_started:
		var first_player = "你" if player_first else character_name
		info_text = "步数: %d | 先手: %s | 比分: %d - %d" % [total_moves, first_player, player_wins, ai_wins]
	else:
		info_text = "比分: %d - %d" % [player_wins, ai_wins]
	
	game_info_label.text = info_text

func _update_turn_display():
	if not game_started:
		return
	
	if current_player == 1:
		player_turn_label.text = "● 你的回合"
		player_turn_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		ai_turn_label.text = "○ 等待中..."
		ai_turn_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		player_turn_label.text = "○ 等待中..."
		player_turn_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		ai_turn_label.text = "● 思考中..."
		ai_turn_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))

func _ai_move():
	var move = ai.get_next_move(board, BOARD_SIZE, 2, 1, ai_difficulty)
	if move:
		_place_stone(move.row, move.col, 2)

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
	_update_turn_display_game_over(player)
	_update_game_info()
	
	# 显示"再来一局"按钮
	_show_restart_button()

func _play_game_end_animation(winner: int):
	"""播放游戏结束动画"""
	if winner == 1:
		# 玩家胜利动画
		if player_info:
			var tween = create_tween()
			tween.tween_property(player_info, "modulate", Color(1.2, 1.2, 0.8), 0.3)
			tween.tween_property(player_info, "modulate", Color.WHITE, 0.3)
	else:
		# AI胜利动画
		if ai_info:
			var tween = create_tween()
			tween.tween_property(ai_info, "modulate", Color(1.2, 1.2, 0.8), 0.3)
			tween.tween_property(ai_info, "modulate", Color.WHITE, 0.3)

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
	player_turn_label.text = "平局"
	ai_turn_label.text = "平局"

func _update_turn_display_game_over(winner: int):
	if winner == 1:
		player_turn_label.text = "🎉 胜利！"
		player_turn_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		ai_turn_label.text = "失败"
		ai_turn_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		player_turn_label.text = "失败"
		player_turn_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		ai_turn_label.text = "🎉 胜利！"
		ai_turn_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))

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
	"""保存游戏记录到日记"""
	if not has_node("/root/SaveManager"):
		return
	
	# 获取用户名
	var user_name = "玩家"
	if has_node("/root/EventHelpers"):
		var config_path = "res://config/app_config.json"
		if FileAccess.file_exists(config_path):
			var file = FileAccess.open(config_path, FileAccess.READ)
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var config = json.data
				user_name = config.get("user_name", "玩家")
	
	# 构建日记内容
	var diary_content = ""
	var total_games = player_wins + ai_wins
	
	if total_games == 0:
		# 一局都没完成
		if game_in_progress:
			diary_content = "我和%s玩了五子棋，但我们还没分出胜负" % user_name
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
		
		diary_content = "我和%s玩了%d局五子棋，%s，比分%d比%d" % [user_name, total_games, result_text, ai_wins, player_wins]
	
	# 保存到日记
	var save_mgr = get_node("/root/SaveManager")
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%02d:%02d" % [current_time.hour, current_time.minute]
	
	save_mgr.add_diary_entry({
		"type": "games",
		"time": time_str,
		"event": diary_content
	})
	
	print("五子棋游戏记录已保存到日记: ", diary_content)

func _on_restart_pressed():
	"""重新开始游戏"""
	# 移除"再来一局"按钮
	for child in get_children():
		if child is Button and child.text == "再来一局":
			child.queue_free()
	
	# 重置棋盘
	_init_board()
	_draw_board()
	
	# 重置UI
	game_started = false
	game_in_progress = false
	total_moves = 0
	start_hint.visible = true
	ai_first_button.visible = true
	difficulty_container.visible = true
	player_turn_label.visible = false
	ai_turn_label.visible = false
	
	# 隐藏视频
	if ai_video:
		ai_video.stop()
		ai_video.visible = false
	
	_update_game_info()

func _on_ai_first_pressed():
	if game_over or board[7][7] != 0:
		return
	
	player_first = false
	_start_game()
	
	# 直接在中心落子，不触发 _place_stone 的玩家切换逻辑
	board[7][7] = 2
	total_moves = 1
	_draw_board()
	_update_game_info()
	# 不切换玩家，保持 current_player = 1，让玩家继续
