extends RefCounted
class_name XiangqiAI

const COLS = 9
const ROWS = 10

var piece_values := {
	"K": 10000,
	"R": 500,
	"N": 300,
	"B": 220,
	"A": 220,
	"C": 350,
	"P": 100
}

# 棋子位置价值表
var position_values := {
	"K": _create_king_position_values(),
	"R": _create_rook_position_values(),
	"N": _create_knight_position_values(),
	"B": _create_bishop_position_values(),
	"A": _create_advisor_position_values(),
	"C": _create_cannon_position_values(),
	"P": _create_pawn_position_values()
}

func get_next_move(board: Array, ai_side: int, difficulty: int) -> Dictionary:
	var moves = _generate_all_moves(board, ai_side)
	if moves.size() == 0:
		return {}
	
	match difficulty:
		1:
			return moves[randi() % moves.size()]
		2:
			return _get_intermediate_move(board, moves, ai_side)
		_:
			return _get_advanced_move(board, moves, ai_side, difficulty)

func _get_intermediate_move(board: Array, moves: Array, ai_side: int) -> Dictionary:
	# 中级难度：考虑吃子价值和位置价值
	moves.sort_custom(func(a, b):
		var score_a = _evaluate_move(board, a, ai_side)
		var score_b = _evaluate_move(board, b, ai_side)
		return score_a > score_b
	)
	
	# 返回前几个最佳移动中的一个，增加随机性
	var top_count = min(3, moves.size())
	return moves[randi() % top_count]

func _get_advanced_move(board: Array, moves: Array, ai_side: int, difficulty: int) -> Dictionary:
	var depth = min(2, difficulty - 2)  # 根据难度调整搜索深度
	
	var best_move = moves[0]
	var best_score = -INF
	
	for m in moves:
		var nb = _simulate(board, m.from, m.to)
		var score = _minimax(nb, depth - 1, -INF, INF, false, ai_side)
		
		# 轻微随机化以避免完全重复的游戏
		if score > best_score or (score == best_score and randi() % 4 == 0):
			best_score = score
			best_move = m
	
	return best_move

func _minimax(board: Array, depth: int, alpha: float, beta: float, maximizing: bool, ai_side: int) -> float:
	if depth == 0:
		return _evaluate_board_advanced(board, ai_side)
	
	var current_side = ai_side if maximizing else (3 - ai_side)  # 对手方
	var moves = _generate_all_moves(board, current_side)
	
	if maximizing:
		var max_eval = -INF
		for m in moves:
			var nb = _simulate(board, m.from, m.to)
			var eval_score = _minimax(nb, depth - 1, alpha, beta, false, ai_side)
			max_eval = max(max_eval, eval_score)
			alpha = max(alpha, eval_score)
			if beta <= alpha:
				break
		return max_eval
	else:
		var min_eval = INF
		for m in moves:
			var nb = _simulate(board, m.from, m.to)
			var eval_score = _minimax(nb, depth - 1, alpha, beta, true, ai_side)
			min_eval = min(min_eval, eval_score)
			beta = min(beta, eval_score)
			if beta <= alpha:
				break
		return min_eval

func _evaluate_move(board: Array, move: Dictionary, ai_side: int) -> float:
	var score = 0.0
	
	# 吃子价值
	var target_piece = board[move.to.y][move.to.x]
	if target_piece != "":
		score += _capture_value(target_piece) * 1.2
	
	# 位置价值变化
	var piece_id = board[move.from.y][move.from.x]
	var piece_type = piece_id.substr(1, 1)
	var current_pos_value = _get_position_value(piece_type, move.from, ai_side)
	var new_pos_value = _get_position_value(piece_type, move.to, ai_side)
	score += new_pos_value - current_pos_value
	
	# 鼓励将军
	var new_board = _simulate(board, move.from, move.to)
	if _is_check(new_board, 3 - ai_side):
		score += 200
	
	return score

func _evaluate_board_advanced(b: Array, ai_side: int) -> float:
	var score = 0.0
	
	# 基础棋子价值
	for y in range(ROWS):
		for x in range(COLS):
			var id = b[y][x]
			if id == "":
				continue
			var piece_value = piece_values.get(id.substr(1, 1), 0)
			var position_value = _get_position_value(id.substr(1, 1), Vector2i(x, y), _piece_side(id))
			
			if _piece_side(id) == ai_side:
				score += piece_value + position_value
			else:
				score -= piece_value + position_value
	
	# 额外评估因素
	score += _evaluate_mobility(b, ai_side) * 5
	score += _evaluate_threats(b, ai_side) * 10
	score += _evaluate_king_safety(b, ai_side) * 20
	
	return score

func _evaluate_mobility(b: Array, ai_side: int) -> float:
	var mobility = 0.0
	var ai_moves = _generate_all_moves(b, ai_side)
	var opponent_moves = _generate_all_moves(b, 3 - ai_side)
	
	mobility = ai_moves.size() - opponent_moves.size() * 0.8
	return mobility

func _evaluate_threats(b: Array, ai_side: int) -> float:
	var threat_score = 0.0
	
	# 检查是否将军
	if _is_check(b, 3 - ai_side):
		threat_score += 50
	
	# 检查是否被将军
	if _is_check(b, ai_side):
		threat_score -= 60
	
	return threat_score

func _evaluate_king_safety(b: Array, ai_side: int) -> float:
	var safety_score = 0.0
	
	# 找到将/帅的位置
	var king_pos = _find_king(b, ai_side)
	if king_pos == Vector2i(-1, -1):
		return -1000  # 将/帅被将死
	
	# 评估将/帅的保护程度
	var defender_count = 0
	for y in range(max(0, king_pos.y - 1), min(ROWS, king_pos.y + 2)):
		for x in range(max(0, king_pos.x - 1), min(COLS, king_pos.x + 2)):
			var piece = b[y][x]
			if piece != "" and _piece_side(piece) == ai_side:
				defender_count += 1
	
	safety_score = defender_count * 15
	
	return safety_score

func _is_check(b: Array, side: int) -> bool:
	var king_pos = _find_king(b, side)
	if king_pos == Vector2i(-1, -1):
		return false
	
	# 检查是否有任何对方棋子可以攻击将/帅
	for y in range(ROWS):
		for x in range(COLS):
			var piece = b[y][x]
			if piece != "" and _piece_side(piece) != side:
				if _can_move(b, Vector2i(x, y), king_pos):
					return true
	
	return false

func _find_king(b: Array, side: int) -> Vector2i:
	var king_id = "rK" if side == 1 else "bK"
	for y in range(ROWS):
		for x in range(COLS):
			if b[y][x] == king_id:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _get_position_value(piece_type: String, pos: Vector2i, side: int) -> float:
	var values = position_values.get(piece_type, [])
	if values.is_empty():
		return 0
	
	# 调整位置索引以适应红黑方
	var y = pos.y if side == 1 else ROWS - 1 - pos.y
	if y < 0 or y >= ROWS or pos.x < 0 or pos.x >= COLS:
		return 0
	
	return values[y][pos.x]

# 以下是为每种棋子创建位置价值表的函数
func _create_king_position_values() -> Array:
	# 将/帅应该待在安全的位置
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 九宫格内价值较高
			if x >= 3 and x <= 5 and ((y >= 7 and y <= 9) or (y >= 0 and y <= 2)):
				value = 10 - abs(x - 4) - abs(y - (8 if y > 5 else 1))
			values[y].append(value)
	return values

func _create_rook_position_values() -> Array:
	# 车在中心线和对方底线价值高
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 中心列价值高
			if x == 4:
				value += 3
			# 对方底线价值高
			if y == 0 or y == 9:
				value += 5
			# 河界价值稍低
			if y == 4 or y == 5:
				value -= 2
			values[y].append(value)
	return values

func _create_knight_position_values() -> Array:
	# 马在中心区域价值高，避免在边缘
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 中心区域价值高
			if x >= 2 and x <= 6 and y >= 2 and y <= 7:
				value = 6 - abs(x - 4) - abs(y - 4.5) * 0.5
			# 边缘价值低
			if x == 0 or x == 8 or y == 0 or y == 9:
				value -= 5
			values[y].append(value)
	return values

func _create_bishop_position_values() -> Array:
	# 象/相在自己阵地价值高
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 象不能过河，在自己阵地有价值
			if (y >= 5 and y <= 9) or (y >= 0 and y <= 4):
				value = 3
			# 中心象价值更高
			if (x == 2 or x == 6) and (y == 9 or y == 7 or y == 0 or y == 2):
				value += 2
			values[y].append(value)
	return values

func _create_advisor_position_values() -> Array:
	# 士/仕在九宫格中心价值高
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 九宫格内价值高
			if x >= 3 and x <= 5 and ((y >= 7 and y <= 9) or (y >= 0 and y <= 2)):
				value = 5 - abs(x - 4) - abs(y - (8 if y > 5 else 1))
			values[y].append(value)
	return values

func _create_cannon_position_values() -> Array:
	# 炮在河界和对方底线价值高
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 河界价值高
			if y == 4 or y == 5:
				value += 3
			# 对方底线价值高
			if y == 0 or y == 9:
				value += 4
			# 中心列价值高
			if x == 4:
				value += 2
			values[y].append(value)
	return values

func _create_pawn_position_values() -> Array:
	# 兵/卒过河后价值增加，接近对方将/帅价值高
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			# 过河后价值增加
			if (y <= 4) or (y >= 5):
				value = min(5, abs(y - 4.5))  # 越靠近对方底线价值越高
			# 中心兵价值更高
			if x == 4:
				value += 1
			values[y].append(value)
	return values

# 保留原有的辅助函数，它们已经足够好
func _generate_all_moves(board: Array, side: int) -> Array:
	var list := []
	for y in range(ROWS):
		for x in range(COLS):
			var id = board[y][x]
			if id == "":
				continue
			if _piece_side(id) != side:
				continue
			var from := Vector2i(x, y)
			for ty in range(ROWS):
				for tx in range(COLS):
					var to := Vector2i(tx, ty)
					if from == to:
						continue
					if _can_move(board, from, to):
						var move := {"from": from, "to": to}
						var nb = _simulate(board, from, to)
						if not _kings_facing(nb):
							list.append(move)
	return list

func _piece_side(id: String) -> int:
	return 1 if id.begins_with("r") else 2

func _can_move(board: Array, from: Vector2i, to: Vector2i) -> bool:
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
			if ax == 0:
				var dir = sign(dy)
				for y in range(from.y + dir, to.y, dir):
					if board[y][from.x] != "":
						return false
			else:
				var dirx = sign(dx)
				for x in range(from.x + dirx, to.x, dirx):
					if board[from.y][x] != "":
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

func _capture_value(id: String) -> int:
	if id == "":
		return 0
	var t = id.substr(1, 1)
	return piece_values.get(t, 0)


func _simulate(board: Array, from: Vector2i, to: Vector2i) -> Array:
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
