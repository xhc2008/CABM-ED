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

func get_next_move(board: Array, ai_side: int, difficulty: int) -> Dictionary:
    var moves = _generate_all_moves(board, ai_side)
    if moves.size() == 0:
        return {}
    if difficulty <= 1:
        return moves[randi() % moves.size()]
    if difficulty == 2:
        moves.sort_custom(func(a, b):
            var ta = board[a.to.y][a.to.x]
            var tb = board[b.to.y][b.to.x]
            var va = _capture_value(ta)
            var vb = _capture_value(tb)
            if va == vb:
                return _center_score(a.to) > _center_score(b.to)
            return va > vb
        )
        return moves[0]
    var best = moves[0]
    var best_score = -INF
    for m in moves:
        var nb = _simulate(board, m.from, m.to)
        var s = _evaluate_board(nb, ai_side)
        if s > best_score:
            best_score = s
            best = m
    return best

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

func _center_score(to: Vector2i) -> float:
    var cx = 4.0
    var cy = 4.5
    return 100.0 - (abs(to.x - cx) + abs(to.y - cy))

func _simulate(board: Array, from: Vector2i, to: Vector2i) -> Array:
    var b = []
    for r in range(ROWS):
        b.append(board[r].duplicate())
    b[to.y][to.x] = b[from.y][from.x]
    b[from.y][from.x] = ""
    return b

func _evaluate_board(b: Array, ai_side: int) -> int:
    var s = 0
    for y in range(ROWS):
        for x in range(COLS):
            var id = b[y][x]
            if id == "":
                continue
            var v = piece_values.get(id.substr(1, 1), 0)
            if _piece_side(id) == ai_side:
                s += v
            else:
                s -= v
    return s

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