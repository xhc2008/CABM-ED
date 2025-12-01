extends Node

# 关键词提取器 - GDScript层包装器
# 优先使用C++ GDExtension `KeywordExtractor`（若已编译并启用），
# 否则降级到一个简单的GDScript分词实现。

var _stop_words = {}

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
	if ClassDB.class_exists("JiebaKeywordExtractor"):
		# 在尝试调用 C++ 提取器前，先确保所需的配置文件存在，避免 native 崩溃
		var req_files = [
			"res://addons/jieba/config/jieba.dict.utf8",
			"res://addons/jieba/config/hmm_model.utf8",
			"res://addons/jieba/config/idf.utf8",
			"res://addons/jieba/config/stop_words.utf8"
		]
		var ok = true
		for p in req_files:
			if not FileAccess.file_exists(p):
				ok = false
				break
		if ok:
			var inst = ClassDB.instantiate("JiebaKeywordExtractor")
			if inst:
				var kws = inst.extract_keywords(text, top_k)
				print("[JiebaKeywordExtractor C++] tokens/keywords:", kws)
				return kws
		else:
			print("Jieba 配置文件缺失，使用简单分词回退方案")
	
	# C++未加载时的简单分词回退方案
	print("C++未加载！ 使用简单分词回退方案")
	
	# 简单分词：按非字母数字字符分割
	var tokens = _simple_tokenize(text)
	
	# 过滤停用词
	var filtered = []
	for token in tokens:
		if not _stop_words.has(token):
			filtered.append(token)
	
	# 统计词频
	var freq = {}
	for token in filtered:
		if freq.has(token):
			freq[token] += 1
		else:
			freq[token] = 1
	
	# 按词频排序
	var sorted_items = []
	for token in freq:
		sorted_items.append({"token": token, "freq": freq[token]})
	
	sorted_items.sort_custom(func(a, b): return a.freq > b.freq)
	
	# 返回前top_k个
	var result = []
	for i in range(min(top_k, sorted_items.size())):
		result.append(sorted_items[i].token)
	
	return result

func _simple_tokenize(text: String) -> Array:
	# 使用简单规则分词：将非字母数字、非中文字符作为分隔符
	var cleaned = ""
	for c in text:
		var code = ord(c)
		if (code >= 0x4E00 and code <= 0x9FFF) or c.is_valid_identifier() or (c >= "0" and c <= "9"):
			cleaned += c
		else: 
			cleaned += " "
	
	var parts = cleaned.split(" ", false)
	var tokens = []
	for p in parts:
		var s = p.strip_edges()
		if s != "":
			tokens.append(s)
	return tokens
