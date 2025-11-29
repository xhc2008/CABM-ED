extends Node

# 关键词提取器 - GDScript层包装器
# 优先使用C++ GDExtension `KeywordExtractor`（若已编译并启用），
# 否则降级到一个简单的GDScript分词 + 停用词过滤实现。

var _stop_words = null

func _ready():
    _load_stop_words()

func _load_stop_words():
    var path = "res://addons/jieba/config/stop_words.utf8"
    _stop_words = {}
    if FileAccess.file_exists(path):
        var f = FileAccess.open(path, FileAccess.READ)
        if f:
            var content = f.get_as_text()
            f.close()
            for line in content.split("\n"):
                var t = line.strip_edges()
                if t != "":
                    _stop_words[t] = true

func extract_keywords(text: String, top_k: int = 5) -> Array:
    # 优先使用C++插件
    if ClassDB.class_exists("KeywordExtractor"):
        var inst = ClassDB.instantiate("KeywordExtractor")
        if inst:
            return inst.extract_keywords(text, top_k)

    # 降级实现：简单分词（按非字母/数字分割）并去除停用词，按频率排序
    var tokens = _simple_tokenize(text)
    if tokens.empty():
        return []

    var freq = {}
    for t in tokens:
        if t == "":
            continue
        if _stop_words.has(t):
            continue
        freq[t] = freq.get(t, 0) + 1

    var pairs = []
    for k in freq:
        pairs.append({"k": k, "v": freq[k]})

    pairs.sort_custom(func(a, b): return a.v > b.v)

    var out = []
    for i in range(min(top_k, pairs.size())):
        out.append(pairs[i].k)

    return out

func _simple_tokenize(text: String) -> Array:
    # 使用正则把非字母数字（含中文）作为分隔符。
    # 保留中文字符（\u4e00-\u9fff）和字母数字、下划线。
    var cleaned = ""
    for i in text:
        var c = i
        var code = c.ord()
        if (code >= 0x4E00 and code <= 0x9FFF) or c.is_valid_identifier() or c.is_digit():
            cleaned += c
        else:
            cleaned += " "

    var parts = cleaned.split(" ")
    var tokens = []
    for p in parts:
        var s = p.strip_edges()
        if s != "":
            tokens.append(s)
    return tokens
