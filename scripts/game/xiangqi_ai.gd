extends RefCounted
class_name XiangqiAI

const COLS = 9
const ROWS = 10
const INFINITY=2147483647
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

# 缓存变量，避免重复计算
var _move_cache := {}
var _evaluation_cache := {}

func get_next_move(board: Array, ai_side: int, difficulty: int) -> Dictionary:
	# 清空缓存
	_move_cache.clear()
	_evaluation_cache.clear()
	
	var moves = _generate_all_moves(board, ai_side)
	if moves.size() == 0:
		return {}
	
	match difficulty:
		1:
			# 简单难度：完全随机
			return moves[randi() % moves.size()]
		2:
			# 中级难度：考虑吃子价值和位置价值
			return _get_intermediate_move(board, moves, ai_side)
		3:
			# 高级难度：浅层搜索
			return _get_advanced_move(board, moves, ai_side, 1)
		4, 5:
			# 专家难度：深层搜索
			var depth = difficulty - 2
			return _get_advanced_move(board, moves, ai_side, depth)
		_:
			return _get_advanced_move(board, moves, ai_side, 2)

func _get_intermediate_move(board: Array, moves: Array, ai_side: int) -> Dictionary:
	# 中级难度：考虑吃子价值和位置价值
	var scored_moves = []
	
	for move in moves:
		var score = _evaluate_move(board, move, ai_side)
		scored_moves.append({"move": move, "score": score})
	
	# 按分数降序排序
	scored_moves.sort_custom(func(a, b): return a.score > b.score)
	
	# 返回前几个最佳移动中的一个，增加随机性
	var top_count = min(5, scored_moves.size())
	var selected = randi() % top_count
	return scored_moves[selected].move

func _get_advanced_move(board: Array, moves: Array, ai_side: int, depth: int) -> Dictionary:
	# 首先检查是否有立即获胜的走法
	for move in moves:
		var new_board = _simulate(board, move.from, move.to)
		if _is_checkmate(new_board, 3 - ai_side):
			return move
	
	# 根据难度调整随机性
	var randomness = 0.0
	match depth:
		1: randomness = 0.3  # 浅层搜索更随机
		2: randomness = 0.2
		3: randomness = 0.1  # 深层搜索更精确
		_: randomness = 0.15
	
	# 引入随机性：有一定概率完全随机选择
	if randf() < randomness:
		return moves[randi() % moves.size()]
	
	# 评估所有走法
	var scored_moves = []
	var best_score = -INFINITY
	
	for move in moves:
		var new_board = _simulate(board, move.from, move.to)
		var score = _minimax(new_board, depth - 1, -INFINITY, INFINITY, false, ai_side)
		
		# 对吃子走法进行惩罚，增加变化
		var penalty = 0.0
		var target_piece = board[move.to.y][move.to.x]
		if target_piece != "":
			# 吃子走法有一定概率被惩罚，避免总是吃子
			if randf() < 0.4:
				penalty = _capture_value(target_piece) * 0.3
		
		score -= penalty
		scored_moves.append({"move": move, "score": score})
		
		if score > best_score:
			best_score = score
	
	# 按分数排序
	scored_moves.sort_custom(func(a, b): return a.score > b.score)
	
	# 根据分数分布选择走法
	return _select_move_from_scored_list(scored_moves, best_score, depth)

func _select_move_from_scored_list(scored_moves: Array, best_score: float, depth: int) -> Dictionary:
	if scored_moves.size() == 1:
		return scored_moves[0].move
	
	# 计算所有走法的平均分
	var total_score = 0.0
	for item in scored_moves:
		total_score += item.score
	var average_score = total_score / scored_moves.size()
	
	# 根据深度调整选择策略
	var selection_strategy = "top_group"
	if depth <= 1:
		# 浅层搜索时更随机
		selection_strategy = "weighted" if randf() < 0.7 else "top_group"
	else:
		# 深层搜索时偏向最佳走法，但仍有变化
		selection_strategy = "top_group" if randf() < 0.8 else "weighted"
	
	match selection_strategy:
		"top_group":
			# 选择前几个最佳走法中的一个
			var top_group_size = max(1, min(5, scored_moves.size() / 2))
			var top_moves = []
			for i in range(top_group_size):
				top_moves.append(scored_moves[i])
			return top_moves[randi() % top_moves.size()].move
		
		"weighted":
			# 基于分数的加权随机选择
			var weights = []
			var min_score = scored_moves[scored_moves.size() - 1].score
			var score_range = max(1.0, best_score - min_score)
			
			for item in scored_moves:
				# 计算相对权重，确保即使分数低也有机会被选中
				var normalized_score = (item.score - min_score) / score_range
				var weight = pow(normalized_score + 0.1, 2)  # 加0.1确保最差走法也有机会
				weights.append(weight)
			
			# 加权随机选择
			var total_weight = 0.0
			for weight in weights:
				total_weight += weight
			
			var random_value = randf() * total_weight
			var cumulative_weight = 0.0
			
			for i in range(scored_moves.size()):
				cumulative_weight += weights[i]
				if random_value <= cumulative_weight:
					return scored_moves[i].move
			
			return scored_moves[0].move
	
	# 默认返回第一个
	return scored_moves[0].move

func _minimax(board: Array, depth: int, alpha: float, beta: float, maximizing: bool, ai_side: int) -> float:
	if depth <= 0:
		return _evaluate_board_advanced(board, ai_side)
	
	# 检查缓存
	var board_hash = _hash_board(board)
	if _evaluation_cache.has(board_hash):
		var cached = _evaluation_cache[board_hash]
		if cached.depth >= depth:
			return cached.score
	
	var current_side = ai_side if maximizing else (3 - ai_side)
	var moves = _generate_all_moves(board, current_side)
	
	if moves.size() == 0:
		# 如果没有合法移动，检查是否被将死
		if _is_check(board, current_side):
			return -100000 + depth * 100 if maximizing else 100000 - depth * 100
		else:
			return 0  # 僵局
	
	# 随机打乱走法顺序，增加搜索的变化
	moves = _shuffle_array(moves)
	
	if maximizing:
		var max_eval = -INFINITY
		for move in moves:
			var new_board = _simulate(board, move.from, move.to)
			var eval_score = _minimax(new_board, depth - 1, alpha, beta, false, ai_side)
			max_eval = max(max_eval, eval_score)
			alpha = max(alpha, eval_score)
			if beta <= alpha:
				break
		
		# 缓存结果
		_evaluation_cache[board_hash] = {"score": max_eval, "depth": depth}
		return max_eval
	else:
		var min_eval = INFINITY
		for move in moves:
			var new_board = _simulate(board, move.from, move.to)
			var eval_score = _minimax(new_board, depth - 1, alpha, beta, true, ai_side)
			min_eval = min(min_eval, eval_score)
			beta = min(beta, eval_score)
			if beta <= alpha:
				break
		
		# 缓存结果
		_evaluation_cache[board_hash] = {"score": min_eval, "depth": depth}
		return min_eval

func _evaluate_move(board: Array, move: Dictionary, ai_side: int) -> float:
	var score = 0.0
	
	# 吃子价值
	var target_piece = board[move.to.y][move.to.x]
	if target_piece != "":
		var capture_score = _capture_value(target_piece)
		score += capture_score * 1.5
	
	# 位置价值变化
	var piece_id = board[move.from.y][move.from.x]
	var piece_type = piece_id.substr(1, 1)
	var current_pos_value = _get_position_value(piece_type, move.from, ai_side)
	var new_pos_value = _get_position_value(piece_type, move.to, ai_side)
	score += new_pos_value - current_pos_value
	
	# 鼓励将军
	var new_board = _simulate(board, move.from, move.to)
	if _is_check(new_board, 3 - ai_side):
		score += 300
	
	# 避免被吃
	if _is_threatened(new_board, move.to, ai_side):
		score -= _capture_value(piece_id) * 0.7
	
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
			var total_value = piece_value + position_value
			
			if _piece_side(id) == ai_side:
				score += total_value
			else:
				score -= total_value
	
	# 额外评估因素
	score += _evaluate_mobility(b, ai_side) * 3
	score += _evaluate_threats(b, ai_side) * 15
	score += _evaluate_king_safety(b, ai_side) * 25
	score += _evaluate_pawn_structure(b, ai_side) * 10
	
	return score

func _evaluate_mobility(b: Array, ai_side: int) -> float:
	var ai_moves = _generate_all_moves(b, ai_side)
	var opponent_moves = _generate_all_moves(b, 3 - ai_side)
	
	return ai_moves.size() - opponent_moves.size() * 0.9

func _evaluate_threats(b: Array, ai_side: int) -> float:
	var threat_score = 0.0
	
	# 检查是否将军
	if _is_check(b, 3 - ai_side):
		threat_score += 80
	
	# 检查是否被将军
	if _is_check(b, ai_side):
		threat_score -= 100
	
	return threat_score

func _evaluate_king_safety(b: Array, ai_side: int) -> float:
	var safety_score = 0.0
	
	# 找到将/帅的位置
	var king_pos = _find_king(b, ai_side)
	if king_pos == Vector2i(-1, -1):
		return -10000  # 将/帅被将死
	
	# 评估将/帅的保护程度
	var defender_count = 0
	for y in range(max(0, king_pos.y - 1), min(ROWS, king_pos.y + 2)):
		for x in range(max(0, king_pos.x - 1), min(COLS, king_pos.x + 2)):
			var piece = b[y][x]
			if piece != "" and _piece_side(piece) == ai_side:
				defender_count += 1
	
	safety_score = defender_count * 20
	
	# 将/帅在安全位置加分
	if ai_side == 1 and king_pos.y >= 7 and king_pos.x >= 3 and king_pos.x <= 5:
		safety_score += 30
	elif ai_side == 2 and king_pos.y <= 2 and king_pos.x >= 3 and king_pos.x <= 5:
		safety_score += 30
	
	return safety_score

func _evaluate_pawn_structure(b: Array, ai_side: int) -> float:
	var pawn_score = 0.0
	
	for y in range(ROWS):
		for x in range(COLS):
			var piece = b[y][x]
			if piece != "" and piece.substr(1, 1) == "P" and _piece_side(piece) == ai_side:
				# 过河兵加分
				if (ai_side == 1 and y <= 4) or (ai_side == 2 and y >= 5):
					pawn_score += 15
				# 相连的兵加分
				if x > 0 and b[y][x-1] == piece:
					pawn_score += 5
				if x < COLS-1 and b[y][x+1] == piece:
					pawn_score += 5
	
	return pawn_score

func _is_threatened(board: Array, pos: Vector2i, side: int) -> bool:
	for y in range(ROWS):
		for x in range(COLS):
			var piece = board[y][x]
			if piece != "" and _piece_side(piece) != side:
				if _can_move(board, Vector2i(x, y), pos):
					return true
	return false

func _is_checkmate(board: Array, side: int) -> bool:
	if not _is_check(board, side):
		return false
	
	var moves = _generate_all_moves(board, side)
	return moves.size() == 0

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

# 棋子位置价值表创建函数
func _create_king_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if x >= 3 and x <= 5 and ((y >= 7 and y <= 9) or (y >= 0 and y <= 2)):
				value = 20 - abs(x - 4) * 2 - abs(y - (8 if y > 5 else 1)) * 2
			values[y].append(value)
	return values

func _create_rook_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if x == 4:
				value += 5
			if y == 0 or y == 9:
				value += 8
			if y == 4 or y == 5:
				value += 3
			values[y].append(value)
	return values

func _create_knight_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if x >= 2 and x <= 6 and y >= 2 and y <= 7:
				value = 8 - abs(x - 4) - abs(y - 4.5) * 0.8
			if x == 0 or x == 8 or y == 0 or y == 9:
				value -= 8
			values[y].append(value)
	return values

func _create_bishop_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if (y >= 5 and y <= 9) or (y >= 0 and y <= 4):
				value = 5
			if (x == 2 or x == 6) and (y == 9 or y == 7 or y == 0 or y == 2):
				value += 3
			values[y].append(value)
	return values

func _create_advisor_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if x >= 3 and x <= 5 and ((y >= 7 and y <= 9) or (y >= 0 and y <= 2)):
				value = 10 - abs(x - 4) * 2 - abs(y - (8 if y > 5 else 1)) * 2
			values[y].append(value)
	return values

func _create_cannon_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if y == 4 or y == 5:
				value += 5
			if y == 0 or y == 9:
				value += 6
			if x == 4:
				value += 3
			values[y].append(value)
	return values

func _create_pawn_position_values() -> Array:
	var values = []
	for y in range(ROWS):
		values.append([])
		for x in range(COLS):
			var value = 0
			if (y <= 4) or (y >= 5):
				value = min(8, abs(y - 4.5) * 1.5)
			if x == 4:
				value += 2
			values[y].append(value)
	return values

# 核心游戏逻辑函数
func _generate_all_moves(board: Array, side: int) -> Array:
	var cache_key = _hash_board(board) + str(side)
	if _move_cache.has(cache_key):
		return _move_cache[cache_key].duplicate()
	
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
	
	_move_cache[cache_key] = list.duplicate()
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
			return (ax + ay) == 1 and (ax == 1 or ay == 1)
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
				var dir = 1 if dy > 0 else -1
				for y in range(from.y + dir, to.y, dir):
					if board[y][from.x] != "":
						return false
			else:
				var dirx = 1 if dx > 0 else -1
				for x in range(from.x + dirx, to.x, dirx):
					if board[from.y][x] != "":
						return false
			return true
		"C":
			if ax != 0 and ay != 0:
				return false
			var count = 0
			if ax == 0:
				var dirc = 1 if dy > 0 else -1
				for y in range(from.y + dirc, to.y, dirc):
					if board[y][from.x] != "":
						count += 1
			else:
				var dircx = 1 if dx > 0 else -1
				for x in range(from.x + dircx, to.x, dircx):
					if board[from.y][x] != "":
						count += 1
			if board[to.y][to.x] == "":
				return count == 0
			else:
				return count == 1
		"P":
			if _piece_side(id) == 1:
				if from.y >= 5:  # 未过河
					return ax == 0 and dy == -1
				else:  # 已过河
					return (ax == 0 and dy == -1) or (ax == 1 and dy == 0)
			else:
				if from.y <= 4:  # 未过河
					return ax == 0 and dy == 1
				else:  # 已过河
					return (ax == 0 and dy == 1) or (ax == 1 and dy == 0)
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
	
	if rx.x == -1 or bx.x == -1 or rx.x != bx.x:
		return false
	
	var dir = 1 if bx.y > rx.y else -1
	for y in range(rx.y + dir, bx.y, dir):
		if b[y][rx.x] != "":
			return false
	
	return true

# 辅助函数
func _hash_board(board: Array) -> String:
	var hash_str = ""
	for y in range(ROWS):
		for x in range(COLS):
			hash_str += board[y][x] + ","
	# 将 hash() 返回的整数转换为字符串
	return str(hash_str.hash())

func _shuffle_array(arr: Array) -> Array:
	var shuffled = arr.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled