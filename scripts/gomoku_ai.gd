extends RefCounted
class_name GomokuAI

## 五子棋AI算法类 (优化版)
##
## 输入参数：
## - board_state: Array[Array] - 棋盘状态，二维数组，0=空位，1=玩家(黑)，2=AI(白)
## - board_size: int - 棋盘大小（默认15）
## - ai_player: int - AI玩家编号（默认2）
## - human_player: int - 人类玩家编号（默认1）
## - difficulty: int - AI难度 (1: 放水, 2: 中等, 3: 困难)
##
## 返回值：
## - Dictionary: {"row": int, "col": int} - AI选择的落子位置
##   如果没有可用位置则返回空字典

const DEFAULT_BOARD_SIZE = 15

# 更精确的评估分数表
const EVALUATION_SCORES = {
    "FIVE": 1000000,        # 连五
    "OPEN_FOUR": 10000,     # 活四
    "FOUR": 5000,           # 冲四
    "OPEN_THREE": 2000,     # 活三
    "SLEEPING_THREE": 300,  # 眠三
    "OPEN_TWO": 100,        # 活二
    "SLEEPING_TWO": 10,     # 眠二
    "OPEN_ONE": 1,          # 活一
}

# 优化难度设置
const DIFFICULTY_SETTINGS = {
    1: { "depth": 1, "search_width": 8, "eval_func": "_evaluate_board_simple", "randomness": true },
    2: { "depth": 2, "search_width": 12, "eval_func": "_evaluate_board_advanced", "randomness": false },
    3: { "depth": 3, "search_width": 16, "eval_func": "_evaluate_board_advanced", "randomness": false },
}

## 获取AI的下一步落子位置
## @param board_state: 当前棋盘状态
## @param board_size: 棋盘大小
## @param ai_player: AI玩家编号
## @param human_player: 人类玩家编号
## @param difficulty: AI难度 (1-3)
## @return Dictionary 包含 row 和 col 的字典，表示落子位置
func get_next_move(board_state: Array, board_size: int = DEFAULT_BOARD_SIZE, ai_player: int = 2, human_player: int = 1, difficulty: int = 2) -> Dictionary:
    var start_time = Time.get_ticks_msec()
    var settings = DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[2])
    
    # --- 难度 1: 放水 ---
    if difficulty == 1:
        return _get_easy_move(board_state, board_size)
    
    # --- 难度 2, 3: 优化搜索 ---
    var best_move = null
    var best_score = -99999999
    
    # 首先生成候选移动
    var candidate_moves = _get_smart_candidate_moves(board_state, board_size, ai_player, human_player, settings.search_width)
    
    # 快速检查必胜和必防位置
    var urgent_move = _check_urgent_moves(board_state, board_size, ai_player, human_player, candidate_moves)
    if urgent_move:
        return urgent_move
    
    # 对候选移动进行排序
    candidate_moves.sort_custom(func(a, b):
        var score_a = _evaluate_move_potential(a.row, a.col, board_state, board_size, ai_player, human_player)
        var score_b = _evaluate_move_potential(b.row, b.col, board_state, board_size, ai_player, human_player)
        return score_a > score_b
    )
    
    # 限制搜索宽度
    if candidate_moves.size() > settings.search_width:
        candidate_moves = candidate_moves.slice(0, settings.search_width)
    
    # 执行搜索
    for move in candidate_moves:
        board_state[move.row][move.col] = ai_player
        
        var score
        if settings.depth > 1:
            score = _minimax(board_state, settings.depth - 1, false, -99999999, 99999999, 
                           move.row, move.col, ai_player, human_player, settings.eval_func)
        else:
            # 深度为1时直接评估
            if settings.eval_func == "_evaluate_board_advanced":
                score = _evaluate_board_advanced(board_state, ai_player, human_player)
            else:
                score = _evaluate_board_simple(board_state, ai_player, human_player)
        
        board_state[move.row][move.col] = 0
        
        if score > best_score:
            best_score = score
            best_move = move
        
        # 超时检查
        if Time.get_ticks_msec() - start_time > 4000: # 4秒超时
            print("AI timeout, returning best move found so far.")
            break
    
    # 应用随机性（仅难度1，但这里难度1已单独处理）
    if settings.randomness and best_move and candidate_moves.size() > 1:
        var top_candidates = candidate_moves.slice(0, min(3, candidate_moves.size()))
        if top_candidates.size() > 0:
            best_move = top_candidates[randi() % top_candidates.size()]
    
    return best_move if best_move else _get_fallback_move(board_state, board_size)

## 简单难度移动选择
## 偏向中心区域，随机性较强
func _get_easy_move(board_state: Array, board_size: int) -> Dictionary:
    var available_moves = []
    for i in range(board_size):
        for j in range(board_size):
            if board_state[i][j] == 0:
                available_moves.append({"row": i, "col": j})
    
    if available_moves.size() == 0:
        return {}
    
    # 偏向中心区域
    var center = board_size / 2.0
    available_moves.sort_custom(func(a, b):
        var dist_a = abs(a.row - center) + abs(a.col - center)
        var dist_b = abs(b.row - center) + abs(b.col - center)
        return dist_a < dist_b
    )
    
    # 从前1/3中随机选择
    var candidate_count = max(1, available_moves.size() / 3)
    var candidates = available_moves.slice(0, candidate_count)
    return candidates[randi() % candidates.size()]

## 检查紧急移动（必胜或必防）
## 优先处理连五、活四等关键棋型
func _check_urgent_moves(board_state: Array, board_size: int, ai_player: int, human_player: int, candidate_moves: Array) -> Dictionary:
    # 检查AI能否直接获胜
    for move in candidate_moves:
        board_state[move.row][move.col] = ai_player
        if _check_win(move.row, move.col, ai_player, board_state, board_size):
            board_state[move.row][move.col] = 0
            return move
        board_state[move.row][move.col] = 0
    
    # 检查是否需要防守对手的必胜棋
    for move in candidate_moves:
        board_state[move.row][move.col] = human_player
        if _check_win(move.row, move.col, human_player, board_state, board_size):
            board_state[move.row][move.col] = 0
            return move
        board_state[move.row][move.col] = 0
    
    # 检查活四、冲四等关键棋型
    for move in candidate_moves:
        var ai_threat = _evaluate_move_threat(move.row, move.col, board_state, board_size, ai_player)
        var human_threat = _evaluate_move_threat(move.row, move.col, board_state, board_size, human_player)
        
        if ai_threat >= EVALUATION_SCORES.OPEN_FOUR:
            return move  # AI有活四威胁
        if human_threat >= EVALUATION_SCORES.OPEN_FOUR:
            return move  # 对手有活四威胁，必须防守
    
    return {}

## 智能候选移动生成
## 评估棋盘上所有空位的潜力，选择最有价值的位置进行搜索
func _get_smart_candidate_moves(board_state: Array, board_size: int, ai_player: int, human_player: int, max_moves: int) -> Array:
    var moves = []
    var scores = {}
    # var visited = {}
    
    # 遍历整个棋盘，评估每个空位
    for r in range(board_size):
        for c in range(board_size):
            if board_state[r][c] == 0:
                var key = str(r) + "," + str(c)
                var score = _evaluate_move_potential(r, c, board_state, board_size, ai_player, human_player)
                scores[key] = score
                moves.append({"row": r, "col": c, "score": score})
    
    # 按分数排序
    moves.sort_custom(func(a, b): return a.score > b.score)
    
    # 限制返回数量
    if moves.size() > max_moves:
        moves = moves.slice(0, max_moves)
    
    # 移除分数字段，只返回位置
    var result = []
    for move in moves:
        result.append({"row": move.row, "col": move.col})
    
    return result

## 评估移动潜力（用于排序）
## 综合考虑位置价值、进攻和防守潜力
func _evaluate_move_potential(row: int, col: int, board_state: Array, board_size: int, ai_player: int, human_player: int) -> int:
    if board_state[row][col] != 0:
        return -999999
    
    var score = 0
    
    # 中心位置偏好
    var center = board_size / 2.0
    var distance_to_center = abs(row - center) + abs(col - center)
    score += int((board_size - distance_to_center) * 5)
    
    # 进攻价值
    var ai_threat = _evaluate_move_threat(row, col, board_state, board_size, ai_player)
    score += ai_threat
    
    # 防守价值（稍低权重，鼓励进攻）
    var human_threat = _evaluate_move_threat(row, col, board_state, board_size, human_player)
    score += int(human_threat * 0.8)
    
    return score

## 评估移动的威胁程度
## 通过模拟落子并分析形成的棋型来评估
func _evaluate_move_threat(row: int, col: int, board_state: Array, board_size: int, player: int) -> int:
    board_state[row][col] = player
    
    var threat_score = 0
    var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
    
    for dir in directions:
        var pattern = _get_line_pattern(row, col, dir, player, board_state, board_size)
        threat_score += _score_pattern(pattern)
    
    board_state[row][col] = 0
    return threat_score

## 备用移动选择（当所有搜索失败时）
## 简单的中心优先策略，确保总有合法移动
func _get_fallback_move(board_state: Array, board_size: int) -> Dictionary:
    # 简单的中心优先策略
    var center = board_size / 2
    for distance in range(0, board_size):
        for r in range(max(0, center - distance), min(board_size, center + distance + 1)):
            for c in range(max(0, center - distance), min(board_size, center + distance + 1)):
                if board_state[r][c] == 0:
                    return {"row": r, "col": c}
    return {}

## Minimax算法主函数
## 使用Alpha-Beta剪枝优化搜索效率
func _minimax(board: Array, depth: int, is_maximizing_player: bool, alpha: int, beta: int, 
             last_row: int, last_col: int, ai_player: int, human_player: int, eval_func_name: String) -> int:
    # 终止条件：达到深度或游戏结束
    if depth == 0 or _check_win(last_row, last_col, ai_player if not is_maximizing_player else human_player, board, board.size()):
        if eval_func_name == "_evaluate_board_advanced":
            return _evaluate_board_advanced(board, ai_player, human_player)
        else:
            return _evaluate_board_simple(board, ai_player, human_player)

    var current_player = ai_player if is_maximizing_player else human_player
    var possible_moves = _get_smart_candidate_moves(board, board.size(), ai_player, human_player, 12)

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

## 简单评估函数
## 快速评估棋盘状态，用于低难度或深度较浅的搜索
func _evaluate_board_simple(board: Array, ai_player: int, human_player: int) -> int:
    var score = 0
    var board_size = board.size()
    
    # 检查AI和玩家的连子情况
    for i in range(board_size):
        for j in range(board_size):
            if board[i][j] == ai_player:
                score += _evaluate_single_position(i, j, board, ai_player, board_size)
            elif board[i][j] == human_player:
                score -= _evaluate_single_position(i, j, board, human_player, board_size)
    
    return score

## 高级评估函数
## 综合考虑更多棋型和局势因素，用于高难度AI
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

## 评估单个棋子位置对整体局势的贡献
func _evaluate_single_position(row: int, col: int, board: Array, player: int, board_size: int) -> int:
    var total_score = 0
    var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

    for dir in directions:
        var pattern = _get_line_pattern(row, col, dir, player, board, board_size)
        total_score += _score_pattern(pattern)
    return total_score

## 获取一条线上的棋子模式
## 返回表示该方向上棋子分布的字符串
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

## 根据模式字符串计算分数
## 识别各种棋型并赋予相应分数
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
        score += EVALUATION_SCORES.OPEN_TWO
    # 检查眠二 (X1100, 0110X, 0011X, 1001)
    if pattern.find("X1100") != -1 or pattern.find("0110X") != -1 or pattern.find("0011X") != -1 or pattern.find("1001") != -1:
        score += EVALUATION_SCORES.SLEEPING_TWO
    # 检查活一 (010)
    if pattern.find("010") != -1:
        score += EVALUATION_SCORES.OPEN_ONE

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

## 检查坐标是否在棋盘范围内
func _is_valid_pos(r: int, c: int, board_size: int) -> bool:
    return r >= 0 and r < board_size and c >= 0 and c < board_size