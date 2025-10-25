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

func _ready():
	_init_board()
	_load_character_name()
	_setup_ui()
	back_button.pressed.connect(_on_back_pressed)
	ai_first_button.pressed.connect(_on_ai_first_pressed)
	board_container.gui_input.connect(_on_board_input)
	board_container.draw.connect(_on_board_draw)
	_draw_board()

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
	_update_turn_display()

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
	start_hint.visible = false
	ai_first_button.visible = false
	player_turn_label.visible = true
	ai_turn_label.visible = true
	_update_turn_display()

func _place_stone(row: int, col: int, player: int):
	board[row][col] = player
	_draw_board()
	
	if _check_win(row, col, player):
		game_over = true
		_show_winner(player)
		return
	
	if _is_board_full():
		game_over = true
		_show_draw()
		return
	
	current_player = 3 - current_player
	_update_turn_display()
	
	if current_player == 2:
		await get_tree().create_timer(0.5).timeout
		_ai_move()

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
	var move = _get_ai_move(board)
	if move:
		_place_stone(move.row, move.col, 2)

func _get_ai_move(board_state: Array) -> Dictionary:
	# 简单AI：寻找最佳位置
	var best_score = -999999
	var best_move = null
	
	for i in range(BOARD_SIZE):
		for j in range(BOARD_SIZE):
			if board_state[i][j] == 0:
				var score = _evaluate_position(i, j, board_state)
				if score > best_score:
					best_score = score
					best_move = {"row": i, "col": j}
	
	return best_move

func _evaluate_position(row: int, col: int, board_state: Array) -> int:
	var score = 0
	
	# 中心位置加分（越靠近中心越好）
	var center = BOARD_SIZE / 2.0
	var distance_to_center = abs(row - center) + abs(col - center)
	score += int((BOARD_SIZE - distance_to_center) * 2)
	
	# 检查AI的进攻分数
	board_state[row][col] = 2
	if _check_win(row, col, 2):
		board_state[row][col] = 0
		return 100000 # 必胜
	score += _count_threats(row, col, 2, board_state) * 100
	board_state[row][col] = 0
	
	# 检查防守分数
	board_state[row][col] = 1
	if _check_win(row, col, 1):
		board_state[row][col] = 0
		return 50000 # 必须防守
	score += _count_threats(row, col, 1, board_state) * 80
	board_state[row][col] = 0
	
	return score

func _count_threats(row: int, col: int, player: int, board_state: Array) -> int:
	var threats = 0
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]
	
	for dir in directions:
		var count = 1
		count += _count_line(row, col, dir.x, dir.y, player, board_state)
		count += _count_line(row, col, -dir.x, -dir.y, player, board_state)
		
		if count >= 3:
			threats += count
	
	return threats

func _count_line(row: int, col: int, dx: int, dy: int, player: int, board_state: Array) -> int:
	var count = 0
	var r = row + dx
	var c = col + dy
	
	while r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE:
		if board_state[r][c] == player:
			count += 1
			r += dx
			c += dy
		else:
			break
	
	return count

func _check_win(row: int, col: int, player: int) -> bool:
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]
	
	for dir in directions:
		var count = 1
		count += _count_line(row, col, dir.x, dir.y, player, board)
		count += _count_line(row, col, -dir.x, -dir.y, player, board)
		
		if count >= 5:
			return true
	
	return false

func _is_board_full() -> bool:
	for i in range(BOARD_SIZE):
		for j in range(BOARD_SIZE):
			if board[i][j] == 0:
				return false
	return true

func _show_winner(player: int):
	var winner_name = player_name if player == 1 else character_name
	_show_game_result(winner_name + " 获胜！")
	_update_turn_display_game_over(player)

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
	game_ended.emit()

func _on_ai_first_pressed():
	if game_over or board[7][7] != 0:
		return
	
	player_first = false
	_start_game()
	
	# 直接在中心落子，不触发 _place_stone 的玩家切换逻辑
	board[7][7] = 2
	_draw_board()
	# 不切换玩家，保持 current_player = 1，让玩家继续
