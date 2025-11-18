extends Control

signal game_ended

const COLS = 9
const ROWS = 10
const CELL = 54
const MARGIN = 30

var board: Array = []
var selected := Vector2i(-1, -1)
var side_to_move := 1

@onready var board_container: Control = $BoardContainer
@onready var back_button: Button = $BackButton

func _ready():
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.5)
	_init_board()
	back_button.pressed.connect(_on_back)
	board_container.gui_input.connect(_on_board_input)
	board_container.draw.connect(_on_board_draw)
	board_container.queue_redraw()

func _on_back():
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
				var pos = origin + Vector2(x * CELL, y * CELL)
				var color = Color(0.8, 0, 0) if id.begins_with("r") else Color(0.1, 0.1, 0.1)
				board_container.draw_circle(pos, CELL * 0.38, Color(1, 1, 1))
				board_container.draw_circle(pos, CELL * 0.38, color, false, 2)
				var text = letters.get(id, "")
				if font and text != "":
					var size = int(CELL * 0.6)
					var sz = font.get_string_size(text, size)
					var text_pos = pos - sz * 0.5
					board_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _on_board_input(event):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var origin = Vector2(MARGIN, MARGIN)
	var p = event.position - origin
	if p.x < -CELL * 0.5 or p.y < -CELL * 0.5:
		return
	var x = int(round(p.x / CELL))
	var y = int(round(p.y / CELL))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
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
			board[y][x] = board[selected.y][selected.x]
			board[selected.y][selected.x] = ""
			selected = Vector2i(-1, -1)
			side_to_move = 2 if side_to_move == 1 else 1
			board_container.queue_redraw()

func _piece_side(id: String) -> int:
	return 1 if id.begins_with("r") else 2

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
			return (ax + ay) == 1
		"A":
			if _piece_side(id) == 1 and not (to.x >= 3 and to.x <= 5 and to.y >= 7 and to.y <= 9):
				return false
			if _piece_side(id) == 2 and not (to.x >= 3 and to.x <= 5 and to.y >= 0 and to.y <= 2):
				return false
			return ax == 1 and ay == 1
		"B":
			if _piece_side(id) == 1 and to.y < 5:
				return false
			if _piece_side(id) == 2 and to.y > 4:
				return false
			if ax == 2 and ay == 2:
				var mx = from.x + dx / 2
				var my = from.y + dy / 2
				return board[my][mx] == ""
			return false
		"N":
			if (ax == 2 and ay == 1):
				var block := Vector2i(from.x + dx / 2, from.y)
				return board[block.y][block.x] == ""
			if (ax == 1 and ay == 2):
				var block2 := Vector2i(from.x, from.y + dy / 2)
				return board[block2.y][block2.x] == ""
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
				return count == 0
			else:
				return count == 1
		"P":
			if _piece_side(id) == 1:
				if from.y >= 5:
					if ax == 0 and dy == -1:
						return true
					return false
				else:
					if (ax + abs(dy)) == 1 and dy != 1:
						return true
					return false
			else:
				if from.y <= 4:
					if ax == 0 and dy == 1:
						return true
					return false
				else:
					if (ax + abs(dy)) == 1 and dy != -1:
						return true
					return false
	return false
