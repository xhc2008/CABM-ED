extends RefCounted
class_name GomokuAI

## 五子棋AI算法类 (升级版)
##
## 输入参数：
## - board_state: Array[Array] - 棋盘状态，二维数组，0=空位，1=玩家(黑)，2=AI(白)
## - board_size: int - 棋盘大小（默认15）
## - ai_player: int - AI玩家编号（默认2）
## - human_player: int - 人类玩家编号（默认1）
## - difficulty: int - AI难度 (1: 放水, 2: 原版, 3: 高难度, 4: 能力极限)
##
## 返回值：
## - Dictionary: {"row": int, "col": int} - AI选择的落子位置
##   如果没有可用位置则返回 null

const DEFAULT_BOARD_SIZE = 15
const EVALUATION_SCORES = {
    # 评估模式分数表
    # [活四, 冲四, 活三, 眠三, 活二, 眠二, 活一, 眠一]
    # 活四 (open four): 10000
    # 冲四 (five in a row with one side blocked): 5000
    # 活三 (open three): 1000
    # 眠三 (three blocked at one end): 100
    # 活二 (open two): 10
    # 眠二 (two blocked at one end): 1
    # 活一 (open one): 0.1 -> 使用 10
    # 眠一 (one blocked at one end): 0.01 -> 使用 1
    # 为了方便计算，所有值都乘以10
    "FIVE": 100000, # 连五
    "OPEN_FOUR": 10000,
    "FOUR": 5000,
    "OPEN_THREE": 1000,
    "SLEEPING_THREE": 100,
    "OPEN_TWO": 10,
    "SLEEPING_TWO": 1,
    "OPEN_ONE": 0,
    "SLEEPING_ONE": 0,
}

# 难度设置 - 降低深度避免卡顿
const DIFFICULTY_SETTINGS = {
    1: { "depth": 1, "eval_func": "_evaluate_board_simple", "randomness": true },
    2: { "depth": 2, "eval_func": "_evaluate_board_simple", "randomness": false },
    3: { "depth": 2, "eval_func": "_evaluate_board_advanced", "randomness": false },
}

## 获取AI的下一步落子位置
## @param board_state: 当前棋盘状态
## @param board_size: 棋盘大小
## @param ai_player: AI玩家编号
## @param human_player: 人类玩家编号
## @param difficulty: AI难度 (1-4)
## @return Dictionary 包含 row 和 col 的字典，表示落子位置
func get_next_move(board_state: Array, board_size: int = DEFAULT_BOARD_SIZE, ai_player: int = 2, human_player: int = 1, difficulty: int = 2) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var settings = DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[2])
	var best_move = null

	# --- 难度 1: 放水 ---
	if difficulty == 1:
		var available_moves = []
		for i in range(board_size):
			for j in range(board_size):
				if board_state[i][j] == 0:
					available_moves.append({"row": i, "col": j})
		if available_moves.size() > 0:
			# 随机选择一个位置，但稍微偏向中心
			var center = board_size / 2.0
			available_moves.sort_custom(func(a, b):
				var dist_a = abs(a.row - center) + abs(a.col - center)
				var dist_b = abs(b.row - center) + abs(b.col - center)
				return dist_a < dist_b # 更靠近中心的排前面
			)
			# 选择前几个最中心的随机落子
			var candidates = available_moves.slice(0, min(available_moves.size(), 5))
			if candidates.size() > 0:
				return candidates[randi() % candidates.size()]
		return {} # 没有空位

	# --- 难度 2, 3, 4: Minimax + Alpha-Beta ---
	var best_score = -99999999
	var possible_moves = _get_possible_moves(board_state, board_size)
	
	# 为了性能，对可能的移动进行排序，优先考虑中心和高分位置
	possible_moves.sort_custom(func(a, b):
		var score_a = _evaluate_position_simple(a.row, a.col, board_state, board_size, ai_player, human_player)
		var score_b = _evaluate_position_simple(b.row, b.col, board_state, board_size, ai_player, human_player)
		return score_a > score_b # 分数高的排前面
	)

	for move in possible_moves:
		# 检查是否能直接获胜
		board_state[move.row][move.col] = ai_player
		if _check_win(move.row, move.col, ai_player, board_state, board_size):
			board_state[move.row][move.col] = 0
			return move # 立即返回获胜位置
		board_state[move.row][move.col] = 0 # 恢复

		# 检查是否需要防守对手获胜
		board_state[move.row][move.col] = human_player
		if _check_win(move.row, move.col, human_player, board_state, board_size):
			board_state[move.row][move.col] = 0
			# 不立即返回，继续搜索，但给这个位置一个高优先级
			# 这个检查在 minimax 中也会进行，这里主要是优化
		else:
			board_state[move.row][move.col] = 0 # 恢复

		# 执行 Minimax 搜索
		var score = _minimax(board_state, settings.depth - 1, false, -99999999, 99999999, move.row, move.col, ai_player, human_player, settings.eval_func)
		if score > best_score:
			best_score = score
			best_move = move
		# 检查时间 - 降低超时时间避免卡顿
		if Time.get_ticks_msec() - start_time > 1000: # 1秒超时
			print("AI timeout at depth ", settings.depth, ", returning best move found so far.")
			break



	# --- 难度 2, 3, 4: 应用随机性 (仅对难度2) ---
	if settings.randomness and best_move:
		var candidate_moves = []
		var threshold = best_score * 0.9 # 选择分数在最优值90%以上的移动
		for move in possible_moves:
			board_state[move.row][move.col] = ai_player
			if _check_win(move.row, move.col, ai_player, board_state, board_size):
				board_state[move.row][move.col] = 0
				continue # 不将必胜手加入随机池
			board_state[move.row][move.col] = 0

			var score = _minimax(board_state, settings.depth - 1, false, -99999999, 99999999, move.row, move.col, ai_player, human_player, settings.eval_func)
			if score >= threshold:
				candidate_moves.append(move)
		if candidate_moves.size() > 0:
			best_move = candidate_moves[randi() % candidate_moves.size()]

	return best_move

# Minimax 主函数
func _minimax(board: Array, depth: int, is_maximizing_player: bool, alpha: int, beta: int, last_row: int, last_col: int, ai_player: int, human_player: int, eval_func_name: String) -> int:
	if depth == 0 or _check_win(last_row, last_col, ai_player if not is_maximizing_player else human_player, board, board.size()):
		if eval_func_name == "_evaluate_board_advanced":
			return _evaluate_board_advanced(board, ai_player, human_player)
		else: # "_evaluate_board_simple"
			return _evaluate_board_simple(board, ai_player, human_player)

	var current_player = ai_player if is_maximizing_player else human_player
	var opponent_player = human_player if is_maximizing_player else ai_player
	var possible_moves = _get_possible_moves(board, board.size())
	possible_moves.sort_custom(func(a, b):
		# 优先考虑中心和高分位置
		var score_a = _evaluate_position_simple(a.row, a.col, board, board.size(), ai_player, human_player)
		var score_b = _evaluate_position_simple(b.row, b.col, board, board.size(), ai_player, human_player)
		return score_a > score_b
	)

	if is_maximizing_player: # AI回合 (最大化)
		var max_eval = -99999999
		for move in possible_moves:
			board[move.row][move.col] = current_player
			var eval = _minimax(board, depth - 1, false, alpha, beta, move.row, move.col, ai_player, human_player, eval_func_name)
			board[move.row][move.col] = 0 # 恢复
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha:
				break # Alpha-Beta 剪枝
		return max_eval
	else: # 人类回合 (最小化)
		var min_eval = 99999999
		for move in possible_moves:
			board[move.row][move.col] = current_player
			var eval = _minimax(board, depth - 1, true, alpha, beta, move.row, move.col, ai_player, human_player, eval_func_name)
			board[move.row][move.col] = 0 # 恢复
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha:
				break # Alpha-Beta 剪枝
		return min_eval

# 获取可能的移动位置 (优化：只考虑有棋子附近的空位，限制数量)
func _get_possible_moves(board: Array, board_size: int) -> Array:
	var moves = []
	var visited = {} # 使用字典避免重复添加

	var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

	for r in range(board_size):
		for c in range(board_size):
			if board[r][c] != 0: # 如果当前位置有棋子
				for dir in directions:
					for dist in range(1, 3): # 检查周围2格
						var nr1 = r + dir.x * dist
						var nc1 = c + dir.y * dist
						var nr2 = r - dir.x * dist
						var nc2 = c - dir.y * dist

						if _is_valid_pos(nr1, nc1, board_size) and board[nr1][nc1] == 0:
							var key = str(nr1) + "," + str(nc1)
							if not visited.has(key):
								moves.append({"row": nr1, "col": nc1})
								visited[key] = true
						if _is_valid_pos(nr2, nc2, board_size) and board[nr2][nc2] == 0:
							var key = str(nr2) + "," + str(nc2)
							if not visited.has(key):
								moves.append({"row": nr2, "col": nc2})
								visited[key] = true
	
	# 如果棋盘很空，返回中心附近的空位
	if moves.size() == 0:
		var center = board_size / 2
		for r in range(max(0, center - 3), min(board_size, center + 4)):
			for c in range(max(0, center - 3), min(board_size, center + 4)):
				if board[r][c] == 0:
					moves.append({"row": r, "col": c})
	
	# 限制候选移动数量，避免搜索空间过大
	if moves.size() > 20:
		moves.resize(20)
	
	return moves

func _is_valid_pos(r: int, c: int, board_size: int) -> bool:
	return r >= 0 and r < board_size and c >= 0 and c < board_size

# 简单评估函数 (用于难度2)
func _evaluate_board_simple(board: Array, ai_player: int, human_player: int) -> int:
	var score = 0
	var board_size = board.size()
	for i in range(board_size):
		for j in range(board_size):
			if board[i][j] == 0:
				# 评估空位对AI和对手的价值
				score += _evaluate_position_simple(i, j, board, board_size, ai_player, human_player)
			# 也可以考虑已有棋子的分布，但简单版本主要看空位潜力
	return score

# 简单评估位置 (用于排序和难度2)
func _evaluate_position_simple(row: int, col: int, board_state: Array, board_size: int, ai_player: int, human_player: int) -> int:
	if board_state[row][col] != 0:
		return -999999 # 不是空位，分数极低

	var score = 0
	# 中心位置加分
	var center = board_size / 2.0
	var distance_to_center = abs(row - center) + abs(col - center)
	score += int((board_size - distance_to_center) * 2)

	# 检查AI的进攻分数
	board_state[row][col] = ai_player
	if _check_win(row, col, ai_player, board_state, board_size):
		board_state[row][col] = 0
		return 999999 # 必胜
	score += _count_threats(row, col, ai_player, board_state, board_size) * 100
	board_state[row][col] = 0

	# 检查防守分数
	board_state[row][col] = human_player
	if _check_win(row, col, human_player, board_state, board_size):
		board_state[row][col] = 0
		return 999998 # 必须防守
	score += _count_threats(row, col, human_player, board_state, board_size) * 80
	board_state[row][col] = 0

	return score

# 高级评估函数 (用于难度3, 4)
func _evaluate_board_advanced(board: Array, ai_player: int, human_player: int) -> int:
	var ai_score = 0
	var human_score = 0
	var board_size = board.size()

	for r in range(board_size):
		for c in range(board_size):
			if board[r][c] == ai_player:
				ai_score += _evaluate_single_position(r, c, board, ai_player, board_size)
			elif board[r][c] == human_player:
				human_score += _evaluate_single_position(r, c, board, human_player, board_size)

	return ai_score - human_score

# 评估单个棋子位置对整体局势的贡献 (高级)
func _evaluate_single_position(row: int, col: int, board: Array, player: int, board_size: int) -> int:
	var total_score = 0
	var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

	for dir in directions:
		var pattern = _get_line_pattern(row, col, dir, player, board, board_size)
		total_score += _score_pattern(pattern)
	return total_score

# 获取一条线上的棋子模式
func _get_line_pattern(row: int, col: int, dir: Vector2i, player: int, board: Array, board_size: int) -> String:
	var line = ""
	var r
	var c

	# 向负方向扫描
	var neg_line = ""
	r = row - dir.x
	c = col - dir.y
	while _is_valid_pos(r, c, board_size):
		var cell = board[r][c]
		if cell == player:
			neg_line = "1" + neg_line
		elif cell == 0:
			neg_line = "0" + neg_line
		else: # opponent
			neg_line = "X" + neg_line
		r -= dir.x
		c -= dir.y

	# 当前位置
	line = neg_line + "1"

	# 向正方向扫描
	r = row + dir.x
	c = col + dir.y
	while _is_valid_pos(r, c, board_size):
		var cell = board[r][c]
		if cell == player:
			line += "1"
		elif cell == 0:
			line += "0"
		else: # opponent
			line += "X"
		r += dir.x
		c += dir.y

	return line

# 根据模式字符串计算分数
func _score_pattern(pattern: String) -> int:
	var score = 0
	# 检查是否有连五
	if pattern.find("11111") != -1:
		score += EVALUATION_SCORES.FIVE
	# 检查活四 (011110)
	if pattern.find("011110") != -1:
		score += EVALUATION_SCORES.OPEN_FOUR
	# 检查冲四 (X11110, 01111X, 10111, 11011, 11101)
	if pattern.find("X11110") != -1 or pattern.find("01111X") != -1 or pattern.find("10111") != -1 or pattern.find("11011") != -1 or pattern.find("11101") != -1:
		score += EVALUATION_SCORES.FOUR
	# 检查活三 (01110)
	if pattern.find("01110") != -1:
		score += EVALUATION_SCORES.OPEN_THREE
	# 检查眠三 (X11100, 01110X, 00111X, 10011, 11001, 10101)
	if pattern.find("X11100") != -1 or pattern.find("01110X") != -1 or pattern.find("00111X") != -1 or pattern.find("10011") != -1 or pattern.find("11001") != -1 or pattern.find("10101") != -1:
		score += EVALUATION_SCORES.SLEEPING_THREE
	# 检查活二 (0110)
	if pattern.find("0110") != -1:
		score += EVALUATION_SCORES.OPEN_TWO * 2 # 活二通常比眠二重要
	# 检查眠二 (X1100, 0110X, 0011X, 1001)
	if pattern.find("X1100") != -1 or pattern.find("0110X") != -1 or pattern.find("0011X") != -1 or pattern.find("1001") != -1:
		score += EVALUATION_SCORES.SLEEPING_TWO

	return score

## 检查某位置是否形成五连
func _check_win(row: int, col: int, player: int, board_state: Array, board_size: int) -> bool:
	var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	for dir in directions:
		var count = 1
		count += _count_line(row, col, dir.x, dir.y, player, board_state, board_size)
		count += _count_line(row, col, -dir.x, -dir.y, player, board_state, board_size)
		if count >= 5:
			return true
	return false

## 计算某方向上连续的棋子数量
func _count_line(row: int, col: int, dx: int, dy: int, player: int, board_state: Array, board_size: int) -> int:
	var count = 0
	var r = row + dx
	var c = col + dy
	while r >= 0 and r < board_size and c >= 0 and c < board_size:
		if board_state[r][c] == player:
			count += 1
			r += dx
			c += dy
		else:
			break
	return count

## 计算某位置的威胁数（连续棋子数量） - 原版辅助函数
func _count_threats(row: int, col: int, player: int, board_state: Array, board_size: int) -> int:
	var threats = 0
	var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	for dir in directions:
		var count = 1
		count += _count_line(row, col, dir.x, dir.y, player, board_state, board_size)
		count += _count_line(row, col, -dir.x, -dir.y, player, board_state, board_size)
		if count >= 3:
			threats += count
	return threats
