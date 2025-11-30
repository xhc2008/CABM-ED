extends Node

# 关键词提取器 - GDScript层包装器
# 优先使用C++ GDExtension `KeywordExtractor`（若已编译并启用），
# 否则降级到一个简单的GDScript分词 + 停用词过滤实现。

var _stop_words = null
var _ai_loader = null
var _pending_requests = {}

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

func _init_ai_loader():
	# 尝试实例化 ai_config_loader（如果存在），用于读取 api_key 和模型配置
	var loader_path = "res://scripts/ai_chat/ai_config_loader.gd"
	if ResourceLoader.exists(loader_path):
		var loader_script = load(loader_path)
		var loader = loader_script.new()
		# 把 loader 挂到场景根节点，避免当前脚本未加入树时 add_child 导致问题
		if Engine.has_singleton("SceneTree") and get_tree() != null and get_tree().get_root() != null:
			get_tree().get_root().add_child(loader)
		else:
			add_child(loader)
		# load_all 会尝试读取 user:// 配置并填充 api_key 与 config
		if loader.has_method("load_all"):
			loader.load_all()
		_ai_loader = loader

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
			print("Jieba 配置文件缺失，跳过 C++ 提取器，改用 LLM/本地后备")
	print("C++未加载！ 使用降级实现（本地分词 + 可选LLM增强）")

	# 尝试初始化 AI loader（惰性）
	if _ai_loader == null:
		_init_ai_loader()

	# 优先尝试使用 LLM（同步等待），如果失败再使用本地简单后备

	# 读取可能存在的缓存
	var cache_path = "user://keyword_cache.json"
	var cache = {}
	if FileAccess.file_exists(cache_path):
		var fcache = FileAccess.open(cache_path, FileAccess.READ)
		if fcache:
			var jp = JSON.new()
			if jp.parse(fcache.get_as_text()) == OK:
				cache = jp.data
			fcache.close()

	var cache_key = text.substr(0, 200)
	if cache.has(cache_key):
		var cached = cache[cache_key]
		if typeof(cached) == TYPE_ARRAY and not cached.is_empty():
			return cached.slice(0, min(top_k, cached.size()))

	# 加载配置与 api_key
	var config = null
	var api_key = ""
	if _ai_loader != null:
		config = _ai_loader.config if _ai_loader.config != null else null
		api_key = _ai_loader.api_key if _ai_loader.api_key != null else ""
	else:
		var cfg_path = "res://config/ai_config.json"
		if FileAccess.file_exists(cfg_path):
			var f = FileAccess.open(cfg_path, FileAccess.READ)
			if f:
				var js = JSON.new()
				if js.parse(f.get_as_text()) == OK:
					config = js.data
				f.close()

	# 检查场景树是否可用（关键修复）
	var scene_tree_available = get_tree() != null and get_tree().get_root() != null

	# 期望 keyword 配置位于 summary_model.keyword（兼容你之前加入的位置）
	if config != null and config.has("summary_model") and config.summary_model.has("keyword") and api_key != "":
		var keyword_conf = config.summary_model.keyword
		var model = config.summary_model.get("model", "")
		var base_url = config.summary_model.get("base_url", "")
		if _ai_loader != null and _ai_loader.config.has("summary_model"):
			model = _ai_loader.config.summary_model.get("model", model)
			base_url = _ai_loader.config.summary_model.get("base_url", base_url)

		if not model.is_empty() and not base_url.is_empty() and scene_tree_available:
			# 构建请求体
			var system_prompt = keyword_conf.get("system_prompt")
			var user_content = text

			var messages = [
				{"role": "system", "content": system_prompt},
				{"role": "user", "content": user_content}
			]

			var url = base_url + "/chat/completions"
			var headers = ["Content-Type: application/json", "Authorization: Bearer " + api_key]

			var body = {
				"model": model,
				"messages": messages,
				"max_tokens": int(keyword_conf.get("max_tokens", 256)),
				"temperature": float(keyword_conf.get("temperature", 0.0)),
				"top_p": float(keyword_conf.get("top_p", 0.7))
			}

			var json_body = JSON.stringify(body)

			var req = HTTPRequest.new()
			# Ensure HTTPRequest is added to the active scene tree root to avoid ERR_UNCONFIGURED
			add_child(req)
			var err = req.request(url, headers, HTTPClient.METHOD_POST, json_body)
			if err != OK:
				push_error("Keyword LLM 请求失败: %s" % str(err))
				req.queue_free()
			else:
				# 同步等待结果（优先使用 LLM）
				var res = await req.request_completed
				# res: [result, response_code, headers, response_body]
				if res.size() >= 4:
					var result = int(res[0])
					var response_code = int(res[1])
					var response_body = res[3]
					if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
						var response_text = response_body.get_string_from_utf8()
						var parsed = []
						var j = JSON.new()
						if j.parse(response_text) == OK:
							var data = j.data
							if data.has("choices") and not data.choices.is_empty():
								var msg = data.choices[0].get("message", null)
								var content = ""
								if msg and typeof(msg) == TYPE_DICTIONARY and msg.has("content"):
									content = str(msg.content)
								else:
									content = str(data.choices[0].get("text", ""))
								parsed = _parse_keywords_from_text(content)
							else:
								parsed = _normalize_parsed_keyword_blob(data)
						else:
							parsed = _parse_keywords_from_text(response_text)

						# 缓存并返回
						if parsed and parsed.size() > 0:
							cache[cache_key] = parsed
							var wf = FileAccess.open(cache_path, FileAccess.WRITE)
							if wf:
								wf.store_string(JSON.stringify(cache, "\t"))
								wf.close()
							req.queue_free()
							return parsed.slice(0, min(top_k, parsed.size()))
				req.queue_free()
		else:
			if not scene_tree_available:
				print("KeywordExtractor: 场景树不可用，跳过 LLM 请求，使用本地后备")
			elif model.is_empty() or base_url.is_empty():
				print("KeywordExtractor: 模型配置不完整，跳过 LLM 请求，使用本地后备")

	# 最简单安全的本地后备：随机抽取若干个连续2字符片段（不保证为"词"），避免复杂分词逻辑
	var cleaned = ""
	for c in text:
		var code = ord(c)
		if (code >= 0x4E00 and code <= 0x9FFF) or c.is_valid_identifier() or (c >= "0" and c <= "9"):
			cleaned += c
	if cleaned.length() < 2:
		return []

	var subs = []
	for i in range(cleaned.length() - 1):
		subs.append(cleaned.substr(i, 2))

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var picks = []
	var attempts = 0
	while picks.size() < top_k and attempts < subs.size() * 2:
		var idx = rng.randi_range(0, subs.size() - 1)
		var v = subs[idx]
		if not picks.has(v):
			picks.append(v)
		attempts += 1

	return picks

func _start_keyword_request(text: String, top_k: int, model: String, base_url: String, api_key: String, keyword_conf: Dictionary) -> void:
	# 构建 system prompt
	var system_prompt = keyword_conf.get("system_prompt")

	var user_content = text

	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_content}
	]

	var url = base_url + "/chat/completions"
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + api_key]

	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": int(keyword_conf.get("max_tokens", 256)),
		"temperature": float(keyword_conf.get("temperature", 0.0)),
		"top_p": float(keyword_conf.get("top_p", 0.7)),
		"response_format": {"type": "json_object"},
	}

	var json_body = JSON.stringify(body)

	var req = HTTPRequest.new()
	# Ensure HTTPRequest is added to the active scene tree root to avoid ERR_UNCONFIGURED
	if get_tree() != null and get_tree().get_root() != null:
		get_tree().get_root().add_child(req)
	else:
		add_child(req)
	req.request_completed.connect(self._on_keyword_request_completed)
	req.set_meta("request_type", "keyword")
	req.set_meta("original_text", text.substr(0, 200))
	req.set_meta("top_k", top_k)
	# store in pending so we can correlate if needed
	_pending_requests[req.get_instance_id()] = true

	var err = req.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		push_error("Keyword LLM 请求失败: %s" % str(err))
		req.queue_free()
		_pending_requests.erase(req.get_instance_id())

func _on_keyword_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	# Find the HTTPRequest child representing this keyword request
	var req_node = null
	for child in get_children():
		if child is HTTPRequest and child.has_meta("request_type") and child.get_meta("request_type") == "keyword":
			req_node = child
			break

	if req_node == null:
		return

	var req_id = req_node.get_instance_id()
	_pending_requests.erase(req_id)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("Keyword LLM 请求失败: result=%s" % str(result))
		req_node.queue_free()
		return

	var response_text = body.get_string_from_utf8()

	if response_code != 200:
		print("Keyword LLM 返回错误码 %d: %s" % [response_code, response_text])
		req_node.queue_free()
		return

	# 解析响应：支持多种情况（完整 API JSON / 直接 content 字符串 / fenced code / 裸数组 / CSV）
	var parsed_keywords = []

	# 先尝试将整体 body 解析为 JSON（完整 API 响应）
	var j = JSON.new()
	if j.parse(response_text) == OK:
		var data = j.data
		# 如果是标准 choices 结构
		if data.has("choices") and not data.choices.is_empty():
			var msg = data.choices[0].get("message", null)
			var content = ""
			if msg and typeof(msg) == TYPE_DICTIONARY and msg.has("content"):
				content = str(msg.content)
			else:
				# 有些实现直接在 choices[0].text
				content = str(data.choices[0].get("text", ""))
			parsed_keywords = _parse_keywords_from_text(content)
		else:
			# 直接是关键词数组或对象
			parsed_keywords = _normalize_parsed_keyword_blob(data)
	else:
		# 不是完整 JSON，尝试从文本中抽取
		parsed_keywords = _parse_keywords_from_text(response_text)

	print("[KeywordExtractor][LLM] parsed:", parsed_keywords)

	# 将结果写入缓存（以便下次快速使用）
	var cache_path = "user://keyword_cache.json"
	var cache = {}
	if FileAccess.file_exists(cache_path):
		var f = FileAccess.open(cache_path, FileAccess.READ)
		if f:
			var jp = JSON.new()
			if jp.parse(f.get_as_text()) == OK:
				cache = jp.data
			f.close()

	# 简单缓存策略：使用最前 200 字作为 key
	var key = req_node.get_meta("original_text") if req_node.has_meta("original_text") else ""
	cache[key] = parsed_keywords

	var wf = FileAccess.open(cache_path, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(cache, "\t"))
		wf.close()

	if req_node:
		req_node.queue_free()

func _parse_keywords_from_text(txt: String) -> Array:
	# 去掉三引号围栏（```json ... ```）
	var s = txt.strip_edges()
	# 处理 ```code fences```
	var fence_start = s.find("```")
	if fence_start != -1:
		var fence_end = s.rfind("```")
		if fence_end > fence_start:
			s = s.substr(fence_start + 3, fence_end - fence_start - 3).strip_edges()

	# 如果以 json 对象开始，尝试解析为 JSON
	var j = JSON.new()
	if j.parse(s) == OK:
		return _normalize_parsed_keyword_blob(j.data)

	# 如果文本包含显式的 JSON 片段（如包含 [ ... ]），尝试抽取第一个方括号对
	var lb = s.find("[")
	var rb = s.find("]", lb)
	if lb != -1 and rb != -1 and rb > lb:
		var arrtxt = s.substr(lb, rb - lb + 1)
		var j2 = JSON.new()
		if j2.parse(arrtxt) == OK:
			return _normalize_parsed_keyword_blob(j2.data)

	# 最后尝试按换行或逗号分割纯文本
	var parts = []
	if s.find("\n") != -1:
		parts = s.split("\n")
	else:
		parts = s.split(",")

	var out = []
	for p in parts:
		var t = p.strip_edges()
		if t != "":
			# 可能包含编号或序号，去掉前导数字和标点
			t = t.subst("^\\s*\\d+\\s*[:.)\\-]*\\s*", "")
			out.append(t)

	return out

func _normalize_parsed_keyword_blob(blob) -> Array:
	# 支持多种返回结构：数组、{"keywords": [...]}, {"data": [...]}, 逗号分割字符串等
	if typeof(blob) == TYPE_ARRAY:
		var out_a = []
		for v in blob:
			out_a.append(str(v))
			if out_a.size() >= 100:
				break
		return out_a
	elif typeof(blob) == TYPE_DICTIONARY:
		if blob.has("keywords") and typeof(blob.keywords) == TYPE_ARRAY:
			return _normalize_parsed_keyword_blob(blob.keywords)
		if blob.has("data") and typeof(blob.data) == TYPE_ARRAY:
			return _normalize_parsed_keyword_blob(blob.data)
		# 如果有 text 字段，尝试解析
		if blob.has("text") and typeof(blob.text) == TYPE_STRING:
			return _parse_keywords_from_text(str(blob.text))
		# 其他字典：把键名作为候选
		var keys = []
		for k in blob.keys():
			keys.append(str(k))
		return keys
	elif typeof(blob) == TYPE_STRING:
		# 逗号/换行分割
		return _parse_keywords_from_text(str(blob))

	return []

func _simple_tokenize(text: String) -> Array:
	# 使用正则把非字母数字（含中文）作为分隔符。
	# 保留中文字符（\u4e00-\u9fff）和字母数字、下划线。
	var cleaned = ""
	for i in text:
		var c = i
		var code = ord(c)
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
