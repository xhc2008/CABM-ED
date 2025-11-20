extends Control

signal game_ended

const COLS = 9
const ROWS = 10
const CELL = 54
const MARGIN = 30

var board: Array = []
var selected := Vector2i(-1, -1)
var side_to_move := 1
var game_over: bool = false
var player_first: bool = true
var game_started: bool = false
var player_name: String = "玩家"
var character_name: String = "角色"
var ai_difficulty: int = 0
var player_wins: int = 0
var ai_wins: int = 0
var total_moves: int = 0
var game_in_progress: bool = false
var any_game_started: bool = false
var player_chat_tween: Tween = null
var ai_chat_tween: Tween = null
var ai: XiangqiAI = null
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var animating: bool = false
var anim_from_cell: Vector2i = Vector2i(-1, -1)
var anim_to_cell: Vector2i = Vector2i(-1, -1)
var anim_from_pos: Vector2 = Vector2.ZERO
var anim_to_pos: Vector2 = Vector2.ZERO
var anim_id: String = ""
var anim_progress: float = 0.0
var move_tween: Tween = null
var pending_captured: String = ""
var pending_is_player: bool = true

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
var check_audio_player: AudioStreamPlayer = null

func _ready():
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.5)
	ai = XiangqiAI.new()
	_init_board()
	_load_names()
	_setup_ui()
	_setup_videos()
	_setup_difficulty_buttons()
	check_audio_player = AudioStreamPlayer.new()
	add_child(check_audio_player)
	_hide_chat_bubbles()
	back_button.pressed.connect(_on_back)
	ai_first_button.pressed.connect(_on_ai_first_pressed)
	board_container.gui_input.connect(_on_board_input)
	board_container.draw.connect(_on_board_draw)
	board_container.queue_redraw()
	_update_game_info()

func _on_back():
	_save_game_to_diary()
	game_ended.emit()

func _init_board():
	board = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append("")
		board.append(row)
	board[0][0] = "bR"
	board[0][1] = "bN"
	board[0][2] = "bB"
	board[0][3] = "bA"
	board[0][4] = "bK"
	board[0][5] = "bA"
	board[0][6] = "bB"
	board[0][7] = "bN"
	board[0][8] = "bR"
	board[2][1] = "bC"
	board[2][7] = "bC"
	for i in range(COLS):
		if i % 2 == 0:
			board[3][i] = "bP"
	board[9][0] = "rR"
	board[9][1] = "rN"
	board[9][2] = "rB"
	board[9][3] = "rA"
	board[9][4] = "rK"
	board[9][5] = "rA"
	board[9][6] = "rB"
	board[9][7] = "rN"
	board[9][8] = "rR"
	board[7][1] = "rC"
	board[7][7] = "rC"
	for i in range(COLS):
		if i % 2 == 0:
			board[6][i] = "rP"
	selected = Vector2i(-1, -1)
	side_to_move = 1
	game_over = false
	game_started = false
	game_in_progress = false
	total_moves = 0

func _on_board_draw():
	var origin = Vector2(MARGIN, MARGIN)
	var size = Vector2((COLS - 1) * CELL, (ROWS - 1) * CELL)
	for r in range(ROWS):
		var y = origin.y + r * CELL
		if r == 0 or r == ROWS - 1:
			board_container.draw_line(origin + Vector2(0, y - origin.y), origin + Vector2(size.x, y - origin.y), Color(0, 0, 0), 2)
		else:
			board_container.draw_line(origin + Vector2(0, y - origin.y), origin + Vector2(size.x, y - origin.y), Color(0, 0, 0), 1)
	for c in range(COLS):
		var x = origin.x + c * CELL
		if c == 0 or c == COLS - 1:
			board_container.draw_line(origin + Vector2(x - origin.x, 0), origin + Vector2(x - origin.x, size.y), Color(0, 0, 0), 2)
		else:
			var top = origin.y
			var bottom = origin.y + size.y
			var river_top = origin.y + 4 * CELL
			var river_bottom = origin.y + 5 * CELL
			board_container.draw_line(Vector2(x, top), Vector2(x, river_top), Color(0, 0, 0), 1)
			board_container.draw_line(Vector2(x, river_bottom), Vector2(x, bottom), Color(0, 0, 0), 1)
	_draw_palace(origin)
	_draw_cross(origin)
	_draw_last_move_highlight(origin)
	_draw_pieces(origin)
	if selected.x >= 0:
		var p = origin + Vector2(selected.x * CELL, selected.y * CELL)
		board_container.draw_rect(Rect2(p + Vector2(-CELL * 0.45, -CELL * 0.45), Vector2(CELL * 0.9, CELL * 0.9)), Color(1, 0.3, 0.3, 0.6), false, 2)

func _draw_palace(origin: Vector2):
	var tl = origin + Vector2(3 * CELL, 0)
	var br = origin + Vector2(5 * CELL, 2 * CELL)
	board_container.draw_line(tl, br, Color(0, 0, 0), 1)
	board_container.draw_line(origin + Vector2(5 * CELL, 0), origin + Vector2(3 * CELL, 2 * CELL), Color(0, 0, 0), 1)
	var tl2 = origin + Vector2(3 * CELL, 7 * CELL)
	var br2 = origin + Vector2(5 * CELL, 9 * CELL)
	board_container.draw_line(tl2, br2, Color(0, 0, 0), 1)
	board_container.draw_line(origin + Vector2(5 * CELL, 7 * CELL), origin + Vector2(3 * CELL, 9 * CELL), Color(0, 0, 0), 1)

func _draw_cross(origin: Vector2):
	var points = [Vector2(1, 2), Vector2(7, 2), Vector2(0, 3), Vector2(2, 3), Vector2(4, 3), Vector2(6, 3), Vector2(8, 3), Vector2(1, 7), Vector2(7, 7), Vector2(0, 6), Vector2(2, 6), Vector2(4, 6), Vector2(6, 6), Vector2(8, 6)]
	for p in points:
		var cx = origin.x + p.x * CELL
		var cy = origin.y + p.y * CELL
		var s = 6
		board_container.draw_line(Vector2(cx - s, cy - s), Vector2(cx - s, cy - s * 2), Color(0, 0, 0), 1)
		board_container.draw_line(Vector2(cx - s, cy - s), Vector2(cx - s * 2, cy - s), Color(0, 0, 0), 1)
		board_container.draw_line(Vector2(cx + s, cy - s), Vector2(cx + s, cy - s * 2), Color(0, 0, 0), 1)
		board_container.draw_line(Vector2(cx + s, cy - s), Vector2(cx + s * 2, cy - s), Color(0, 0, 0), 1)

func _draw_pieces(origin: Vector2):
	var font = get_theme_default_font()
	var letters = {
		"rK": "帅", "bK": "将",
		"rR": "车", "bR": "车",
		"rN": "马", "bN": "马",
		"rB": "相", "bB": "象",
		"rA": "仕", "bA": "士",
		"rC": "炮", "bC": "炮",
		"rP": "兵", "bP": "卒"
	}
	for y in range(ROWS):
		for x in range(COLS):
			var id = board[y][x]
			if id != "":
				if animating and ((x == anim_from_cell.x and y == anim_from_cell.y) or (x == anim_to_cell.x and y == anim_to_cell.y)):
					continue
				var pos = origin + Vector2(x * CELL, y * CELL)
				var color = Color(0.8, 0, 0) if id.begins_with("r") else Color(0.1, 0.1, 0.1)
				board_container.draw_circle(pos, CELL * 0.38, Color(1, 1, 1))
				board_container.draw_circle(pos, CELL * 0.38, color, false, 2)
				var text = letters.get(id, "")
				if font and text != "":
					var size = int(CELL * 0.6)
					var ascent = font.get_ascent(size)
					var descent = font.get_descent(size)
					var height = ascent + descent
					var baseline_y = pos.y + height * 0.5 - descent
					var box_w = CELL * 0.76
					var text_pos = Vector2(pos.x - box_w * 0.5, baseline_y)
					board_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_w, size, color)

	if animating and anim_id != "":
		var pos = anim_from_pos.lerp(anim_to_pos, anim_progress)
		var color = Color(0.8, 0, 0) if anim_id.begins_with("r") else Color(0.1, 0.1, 0.1)
		board_container.draw_circle(pos, CELL * 0.38, Color(1, 1, 1))
		board_container.draw_circle(pos, CELL * 0.38, color, false, 2)
		var text2 = letters.get(anim_id, "")
		if font and text2 != "":
			var size2 = int(CELL * 0.6)
			var ascent2 = font.get_ascent(size2)
			var descent2 = font.get_descent(size2)
			var height2 = ascent2 + descent2
			var baseline_y2 = pos.y + height2 * 0.5 - descent2
			var box_w2 = CELL * 0.76
			var text_pos2 = Vector2(pos.x - box_w2 * 0.5, baseline_y2)
			board_container.draw_string(font, text_pos2, text2, HORIZONTAL_ALIGNMENT_CENTER, box_w2, size2, color)

func _draw_last_move_highlight(origin: Vector2):
	if last_move_from.x >= 0:
		var p_from = origin + Vector2(last_move_from.x * CELL, last_move_from.y * CELL)
		board_container.draw_rect(Rect2(p_from + Vector2(-CELL * 0.45, -CELL * 0.45), Vector2(CELL * 0.9, CELL * 0.9)), Color(1, 0.9, 0.3, 0.25), true)
	if last_move_to.x >= 0:
		var p_to = origin + Vector2(last_move_to.x * CELL, last_move_to.y * CELL)
		board_container.draw_rect(Rect2(p_to + Vector2(-CELL * 0.45, -CELL * 0.45), Vector2(CELL * 0.9, CELL * 0.9)), Color(0.3, 0.8, 1.0, 0.25), true)

func _on_board_input(event):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if animating:
		return
	var origin = Vector2(MARGIN, MARGIN)
	var p = event.position - origin
	if p.x < -CELL * 0.5 or p.y < -CELL * 0.5:
		return
	var x = int(round(p.x / CELL))
	var y = int(round(p.y / CELL))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return
	if game_over:
		return
	if side_to_move != 1:
		return
	var id = board[y][x]
	if selected.x < 0:
		if id != "" and _piece_side(id) == side_to_move:
			selected = Vector2i(x, y)
			board_container.queue_redraw()
	else:
		if x == selected.x and y == selected.y:
			selected = Vector2i(-1, -1)
			board_container.queue_redraw()
			return
		if _can_move(selected, Vector2i(x, y)):
			var captured = board[y][x]
			game_started = true
			game_in_progress = true
			ai_first_button.visible = false
			difficulty_buttons_container.visible = false
			any_game_started = true
			_start_move_animation(selected, Vector2i(x, y), board[selected.y][selected.x], captured, true)
			selected = Vector2i(-1, -1)

func _piece_side(id: String) -> int:
	return 1 if id.begins_with("r") else 2

func _process(_delta):
	if animating:
		board_container.queue_redraw()

func _start_move_animation(from: Vector2i, to: Vector2i, id: String, captured: String, is_player: bool):
	var origin = Vector2(MARGIN, MARGIN)
	animating = true
	anim_from_cell = from
	anim_to_cell = to
	anim_id = id
	anim_from_pos = origin + Vector2(from.x * CELL, from.y * CELL)
	anim_to_pos = origin + Vector2(to.x * CELL, to.y * CELL)
	anim_progress = 0.0
	pending_captured = captured
	pending_is_player = is_player
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(self, "anim_progress", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	move_tween.finished.connect(_on_move_animation_finished, CONNECT_ONE_SHOT)

func _on_move_animation_finished():
	last_move_from = anim_from_cell
	last_move_to = anim_to_cell
	if pending_is_player:
		side_to_move = 2
	else:
		side_to_move = 1
	total_moves += 1
	board[anim_to_cell.y][anim_to_cell.x] = anim_id
	board[anim_from_cell.y][anim_from_cell.x] = ""
	animating = false
	anim_id = ""
	board_container.queue_redraw()
	_after_move_update(pending_captured)
	_update_game_info()
	var delay_ai := false
	if not game_over:
		var checked_side = side_to_move
		if _is_check(checked_side):
			if pending_is_player:
				_show_player_chat("将军！")
				delay_ai = true
			else:
				_show_ai_chat("将军！")
				_play_check_voice()
	if pending_is_player and not game_over:
		if delay_ai:
			await get_tree().create_timer(0.4).timeout
		_ai_move()

func _is_check(side: int) -> bool:
	var king_pos = _find_king(side)
	if king_pos == Vector2i(-1, -1):
		return false
	for y in range(ROWS):
		for x in range(COLS):
			var piece = board[y][x]
			if piece != "" and _piece_side(piece) != side:
				if _can_move(Vector2i(x, y), king_pos):
					return true
	return false

func _find_king(side: int) -> Vector2i:
	var king_id = "rK" if side == 1 else "bK"
	for y in range(ROWS):
		for x in range(COLS):
			if board[y][x] == king_id:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _play_check_voice():
	if not check_audio_player:
		return
	var path = "res://assets/audio/voice/check.mp3"
	if ResourceLoader.exists(path):
		var stream = load(path)
		check_audio_player.stream = stream
		check_audio_player.play()

func _can_move(from: Vector2i, to: Vector2i) -> bool:
	var id = board[from.y][from.x]
	var target = board[to.y][to.x]
	if id == "":
		return false
	if target != "" and _piece_side(target) == _piece_side(id):
		return false
	var dx = to.x - from.x
	var dy = to.y - from.y
	var ax = abs(dx)
	var ay = abs(dy)
	match id.substr(1, 1):
		"K":
			if _piece_side(id) == 1 and not (to.x >= 3 and to.x <= 5 and to.y >= 7 and to.y <= 9):
				return false
			if _piece_side(id) == 2 and not (to.x >= 3 and to.x <= 5 and to.y >= 0 and to.y <= 2):
				return false
			if (ax + ay) != 1:
				return false
			var b = _simulate_move(from, to)
			if _kings_facing(b):
				return false
			return true
		"A":
			if _piece_side(id) == 1 and not (to.x >= 3 and to.x <= 5 and to.y >= 7 and to.y <= 9):
				return false
			if _piece_side(id) == 2 and not (to.x >= 3 and to.x <= 5 and to.y >= 0 and to.y <= 2):
				return false
			if not (ax == 1 and ay == 1):
				return false
			var b2 = _simulate_move(from, to)
			if _kings_facing(b2):
				return false
			return true
		"B":
			if _piece_side(id) == 1 and to.y < 5:
				return false
			if _piece_side(id) == 2 and to.y > 4:
				return false
			if ax == 2 and ay == 2:
				var mx = from.x + dx / 2
				var my = from.y + dy / 2
				if board[my][mx] != "":
					return false
				var b3 = _simulate_move(from, to)
				if _kings_facing(b3):
					return false
				return true
			return false
		"N":
			if (ax == 2 and ay == 1):
				var block := Vector2i(from.x + dx / 2, from.y)
				if board[block.y][block.x] != "":
					return false
				var b4 = _simulate_move(from, to)
				if _kings_facing(b4):
					return false
				return true
			if (ax == 1 and ay == 2):
				var block2 := Vector2i(from.x, from.y + dy / 2)
				if board[block2.y][block2.x] != "":
					return false
				var b5 = _simulate_move(from, to)
				if _kings_facing(b5):
					return false
				return true
			return false
		"R":
			if ax != 0 and ay != 0:
				return false
			var steps := 0
			if ax == 0:
				var dir = sign(dy)
				for y in range(from.y + dir, to.y, dir):
					if board[y][from.x] != "":
						return false
					steps += 1
			else:
				var dirx = sign(dx)
				for x in range(from.x + dirx, to.x, dirx):
					if board[from.y][x] != "":
						return false
					steps += 1
			var b6 = _simulate_move(from, to)
			if _kings_facing(b6):
				return false
			return true
		"C":
			if ax != 0 and ay != 0:
				return false
			var count = 0
			if ax == 0:
				var dirc = sign(dy)	
				for y in range(from.y + dirc, to.y, dirc):
					if board[y][from.x] != "":
						count += 1
			else:
				var dircx = sign(dx)
				for x in range(from.x + dircx, to.x, dircx):
					if board[from.y][x] != "":
						count += 1
			if board[to.y][to.x] == "":
				if count != 0:
					return false
				var b7 = _simulate_move(from, to)
				if _kings_facing(b7):
					return false
				return true
			else:
				if count != 1:
					return false
				var b8 = _simulate_move(from, to)
				if _kings_facing(b8):
					return false
				return true
		"P":
			if _piece_side(id) == 1:
				if from.y >= 5:
					if ax == 0 and dy == -1:
						var b9 = _simulate_move(from, to)
						if _kings_facing(b9):
							return false
						return true
					return false
				else:
					if (ax + abs(dy)) == 1 and dy != 1:
						var b10 = _simulate_move(from, to)
						if _kings_facing(b10):
							return false
						return true
					return false
			else:
				if from.y <= 4:
					if ax == 0 and dy == 1:
						var b11 = _simulate_move(from, to)
						if _kings_facing(b11):
							return false
						return true
					return false
				else:
					if (ax + abs(dy)) == 1 and dy != -1:
						var b12 = _simulate_move(from, to)
						if _kings_facing(b12):
							return false
						return true
					return false
	return false

func _simulate_move(from: Vector2i, to: Vector2i) -> Array:
	var b = []
	for r in range(ROWS):
		b.append(board[r].duplicate())
	b[to.y][to.x] = b[from.y][from.x]
	b[from.y][from.x] = ""
	return b

func _kings_facing(b: Array) -> bool:
	var rx := Vector2i(-1, -1)
	var bx := Vector2i(-1, -1)
	for y in range(ROWS):
		for x in range(COLS):
			var id = b[y][x]
			if id == "rK":
				rx = Vector2i(x, y)
			elif id == "bK":
				bx = Vector2i(x, y)
	if rx.x != bx.x:
		return false
	var dir = sign(bx.y - rx.y)
	for y in range(rx.y + dir, bx.y, dir):
		if b[y][rx.x] != "":
			return false
	return true

func _after_move_update(captured: String):
	if captured == "rK" or captured == "bK":
		game_over = true
		game_in_progress = false
		if captured == "bK":
			player_wins += 1
			_show_result_text(player_name + " 获胜！")
		else:
			ai_wins += 1
			_show_result_text(character_name + " 获胜！")
		_update_game_info()

func _ai_move():
	if game_over:
		return
	side_to_move = 2
	_update_game_info()
	await get_tree().process_frame
	var move = ai.get_next_move(board, 2, ai_difficulty)
	if move and move.has("from") and move.has("to"):
		var f: Vector2i = move.from
		var t: Vector2i = move.to
		if board[f.y][f.x] != "" and _piece_side(board[f.y][f.x]) == 2 and _can_move(f, t):
			var captured = board[t.y][t.x]
			_start_move_animation(f, t, board[f.y][f.x], captured, false)

func _load_names():
	if has_node("/root/EventHelpers"):
		var helpers = get_node("/root/EventHelpers")
		character_name = helpers.get_character_name()
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		player_name = save_mgr.get_user_name()

func _setup_ui():
	ai_first_button.visible = true
	difficulty_buttons_container.visible = true

func _setup_difficulty_buttons():
	if not difficulty_buttons_container:
		return
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

func _on_difficulty_selected(diff: int):
	ai_difficulty = diff
	_show_player_chat(_difficulty_chat_text(diff))
	difficulty_buttons_container.visible = false
	_update_game_info()

func _difficulty_chat_text(diff: int) -> String:
	if diff == 1:
		return "能放点水吗"
	if diff == 2:
		return "随便玩玩就好"
	return "使出全力吧"

func _hide_chat_bubbles():
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
	if not player_chat_bubble or not player_chat_label:
		return
	if player_chat_tween and player_chat_tween.is_valid():
		player_chat_tween.kill()
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
	_start_player_chat_animation()

func _start_player_chat_animation():
	player_chat_tween = create_tween()
	player_chat_tween.set_parallel(true)
	player_chat_tween.tween_property(player_chat_bubble, "modulate:a", 1.0, 0.3)
	player_chat_tween.tween_property(player_chat_bubble, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	player_chat_tween.finished.connect(_on_player_chat_show_finished, CONNECT_ONE_SHOT)

func _on_player_chat_show_finished():
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_player_chat_wait_finished, CONNECT_ONE_SHOT)

func _on_player_chat_wait_finished():
	player_chat_tween = create_tween()
	player_chat_tween.set_parallel(true)
	player_chat_tween.tween_property(player_chat_bubble, "modulate:a", 0.0, 0.3)
	player_chat_tween.tween_property(player_chat_bubble, "scale", Vector2(0.8, 0.8), 0.3)
	player_chat_tween.finished.connect(_on_player_chat_hide_finished, CONNECT_ONE_SHOT)

func _on_player_chat_hide_finished():
	if player_chat_bubble:
		player_chat_bubble.visible = false

func _show_ai_chat(message: String):
	if not ai_chat_bubble or not ai_chat_label:
		return
	if ai_chat_tween and ai_chat_tween.is_valid():
		ai_chat_tween.kill()
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
	_start_ai_chat_animation()

func _start_ai_chat_animation():
	ai_chat_tween = create_tween()
	ai_chat_tween.set_parallel(true)
	ai_chat_tween.tween_property(ai_chat_bubble, "modulate:a", 1.0, 0.3)
	ai_chat_tween.tween_property(ai_chat_bubble, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	ai_chat_tween.finished.connect(_on_ai_chat_show_finished, CONNECT_ONE_SHOT)

func _on_ai_chat_show_finished():
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_ai_chat_wait_finished, CONNECT_ONE_SHOT)

func _on_ai_chat_wait_finished():
	ai_chat_tween = create_tween()
	ai_chat_tween.set_parallel(true)
	ai_chat_tween.tween_property(ai_chat_bubble, "modulate:a", 0.0, 0.3)
	ai_chat_tween.tween_property(ai_chat_bubble, "scale", Vector2(0.8, 0.8), 0.3)
	ai_chat_tween.finished.connect(_on_ai_chat_hide_finished, CONNECT_ONE_SHOT)

func _on_ai_chat_hide_finished():
	if ai_chat_bubble:
		ai_chat_bubble.visible = false

func _update_game_info():
	var p = []
	p.append("[color=#333333]" + player_name + "[/color]")
	p.append("比分: " + str(player_wins))
	player_info_label.text = "\n".join(p)
	var a = []
	a.append("[color=#333333]" + character_name + "[/color]")
	a.append("比分: " + str(ai_wins))
	if game_started and not game_over:
		if side_to_move == 2:
			a.append("[color=#FF6600]思考中[/color]")
		else:
			a.append("[color=#888888]等待中[/color]")
	ai_info_label.text = "\n".join(a)

func _show_result_text(message: String):
	var result_label = Label.new()
	result_label.text = message
	result_label.add_theme_font_size_override("font_size", 32)
	result_label.add_theme_color_override("font_color", Color.RED)
	result_label.add_theme_color_override("font_outline_color", Color.WHITE)
	result_label.add_theme_constant_override("outline_size", 4)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var center_x = get_viewport_rect().size.x / 2
	result_label.position = Vector2(center_x - 150, 300)
	result_label.size = Vector2(300, 100)
	add_child(result_label)
	_show_restart_button()

func _on_ai_first_pressed():
	if game_over:
		return
	if ai_difficulty == 0:
		ai_difficulty = randi() % 3 + 1
	player_first = false
	game_started = true
	game_in_progress = true
	any_game_started = true
	ai_first_button.visible = false
	difficulty_buttons_container.visible = false
	_show_player_chat("还是你先吧")
	side_to_move = 2
	_update_game_info()
	_ai_move()

func _on_back_pressed():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	_save_game_to_diary()
	game_ended.emit()

func _save_game_to_diary():
	if not any_game_started and not game_in_progress:
		return
	var total_games = player_wins + ai_wins
	var diary_content = ""
	if total_games == 0:
		if game_in_progress:
			diary_content = "我和" + player_name + "玩了中国象棋，但我们还没分出胜负"
		else:
			return
	else:
		var result_text = ""
		if player_wins > ai_wins:
			result_text = "我输了"
		elif player_wins < ai_wins:
			result_text = "我赢了"
		else:
			result_text = "我们打成了平手"
		diary_content = "我和" + player_name + "玩了" + str(total_games) + "局中国象棋，" + result_text + "，比分" + str(ai_wins) + "比" + str(player_wins)
	var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
	if unified_saver:
		await unified_saver.save_memory(diary_content, unified_saver.MemoryType.GAMES, null, "", {})
	else:
		push_warning("UnifiedMemorySaver 未找到，游戏记录未保存")
func _show_restart_button():
	var restart_button = Button.new()
	restart_button.text = "再来一局"
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.custom_minimum_size = Vector2(200, 60)
	restart_button.position = Vector2(get_viewport_rect().size.x / 2 - 100, 400)
	restart_button.pressed.connect(_on_restart_pressed)
	add_child(restart_button)

func _on_restart_pressed():
	for child in get_children():
		if (child is Button and child.text == "再来一局") or (child is Label and (child.text.contains("获胜") or child.text.contains("平局"))):
			child.queue_free()
	_init_board()
	last_move_from = Vector2i(-1, -1)
	last_move_to = Vector2i(-1, -1)
	board_container.queue_redraw()
	game_started = false
	game_in_progress = false
	total_moves = 0
	ai_difficulty = 0
	ai_first_button.visible = true
	difficulty_buttons_container.visible = true
	_hide_chat_bubbles()
	_update_game_info()
func _setup_videos():
	if ai_video:
		var video_path = "res://assets/images/games/gomoku/1.ogv"
		if FileAccess.file_exists(video_path):
			ai_video.stream = load(video_path)
			ai_video.loop = true
			ai_video.visible = true
			ai_video.play()
