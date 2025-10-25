extends Node
## 记忆系统 - 向量存储和检索
## 使用C++插件进行高性能余弦相似度计算

# 记忆项结构
class MemoryItem:
	var text: String = ""
	var vector: Array = []
	var timestamp: String = ""
	var type: String = "" # "conversation" 或 "diary"
	var metadata: Dictionary = {}
	
	func _init(p_text: String = "", p_vector: Array = [], p_type: String = "conversation"):
		text = p_text
		vector = p_vector
		timestamp = _get_local_datetime_string()
		type = p_type
	
	static func _get_local_datetime_string() -> String:
		"""获取本地时间字符串（带时区转换）"""
		var unix_time = Time.get_unix_time_from_system()
		var timezone_offset = _get_timezone_offset()
		var local_dict = Time.get_datetime_dict_from_unix_time(int(unix_time + timezone_offset))
		return "%04d-%02d-%02dT%02d:%02d:%02d" % [
			local_dict.year, local_dict.month, local_dict.day,
			local_dict.hour, local_dict.minute, local_dict.second
		]
	
	static func _get_timezone_offset() -> int:
		"""获取本地时区相对于UTC的偏移（秒）"""
		var local_time = Time.get_datetime_dict_from_system()
		var unix_time = Time.get_unix_time_from_system()
		var utc_time = Time.get_datetime_dict_from_unix_time(int(unix_time))
		
		# 计算小时差
		var hour_diff = local_time.hour - utc_time.hour
		
		# 处理跨日情况
		if hour_diff > 12:
			hour_diff -= 24
		elif hour_diff < -12:
			hour_diff += 24
		
		return hour_diff * 3600
	
	func to_dict() -> Dictionary:
		return {
			"text": text,
			"vector": vector,
			"timestamp": timestamp,
			"type": type,
			"metadata": metadata
		}
	
	static func from_dict(data: Dictionary) -> MemoryItem:
		var item = MemoryItem.new()
		item.text = data.get("text", "")
		item.vector = data.get("vector", [])
		item.timestamp = data.get("timestamp", "")
		item.type = data.get("type", "conversation")
		item.metadata = data.get("metadata", {})
		return item

var memory_items: Array[MemoryItem] = []
var config: Dictionary = {}
var db_name: String = "default"
var cosine_calculator = null
var http_request: HTTPRequest = null

# 嵌入API配置
var embedding_model: String = ""
var embedding_base_url: String = ""
var embedding_timeout: float = 30.0
var vector_dim: int = 1024

# 请求队列系统
var request_queue: Array = []
var is_processing_request: bool = false

# 等待嵌入完成的信号
signal embedding_completed(vector: Array)
signal embedding_failed(error: String)

func _ready():
	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_embedding_request_completed)
	
	# 加载C++余弦计算插件
	_load_cosine_calculator()

func _load_cosine_calculator():
	"""加载C++余弦相似度计算插件"""
	if ClassDB.class_exists("CosineCalculator"):
		cosine_calculator = ClassDB.instantiate("CosineCalculator")
		print("✓ 余弦计算插件加载成功（C++高性能模式）")
	else:
		print("ℹ 余弦计算插件未编译，使用GDScript实现（性能较低但功能完整）")
		print("  提示：如需高性能，请编译C++插件：cd addons/cosine_calculator && scons")

func initialize(p_config: Dictionary, p_db_name: String = "default"):
	"""初始化记忆系统"""
	config = p_config
	db_name = p_db_name
	
	# 从配置读取嵌入模型参数
	var embed_config = config.get("embedding_model", {})
	embedding_model = embed_config.get("model", "")
	embedding_base_url = embed_config.get("base_url", "")
	embedding_timeout = embed_config.get("timeout", 30.0)
	vector_dim = embed_config.get("vector_dim", 1024)
	
	# 加载已有数据
	load_from_file()
	
	print("记忆系统初始化完成: %s" % db_name)

func add_text(text: String, item_type: String = "conversation", metadata: Dictionary = {}) -> void:
	"""添加文本到记忆系统（异步，支持队列）
	
	Args:
		text: 原始文本内容
		item_type: 类型（conversation 或 diary）
		metadata: 元数据（可选），如 {"mood": "happy", "affection": 75}
	"""
	if text.strip_edges().is_empty():
		print("警告: 尝试添加空文本")
		return
	
	# 为文本添加时间戳前缀（便于查看和检索）
	var timestamp = MemoryItem._get_local_datetime_string()
	var time_str = _format_timestamp_for_display(timestamp)
	var formatted_text = "[%s] %s" % [time_str, text]
	
	# 获取文本的向量表示（使用队列系统）
	var vector = await get_embedding(formatted_text)
	
	if vector.is_empty():
		print("警告: 获取向量失败，跳过添加")
		return
	
	# 创建记忆项
	var item = MemoryItem.new(formatted_text, vector, item_type)
	# 只在有实际内容时才设置 metadata
	if not metadata.is_empty():
		item.metadata = metadata.duplicate()
	
	memory_items.append(item)
	
	print("添加记忆: [%s] %s..." % [item_type, formatted_text.substr(0, 50)])
	
	# 立即保存到文件
	save_to_file()
	print("记忆已保存到文件: %d 条" % memory_items.size())

func add_diary_entry(diary_text: String, metadata: Dictionary = {}) -> void:
	"""添加日记条目
	
	Args:
		diary_text: 日记文本（可以已包含时间戳，也可以不包含）
		metadata: 元数据，如 {"event_type": "offline", "mood": "happy"}
	"""
	await add_text(diary_text, "diary", metadata)

func _format_timestamp_for_display(timestamp: String) -> String:
	"""格式化时间戳为显示格式 MM-DD HH:MM"""
	# timestamp 格式: "2025-10-25T10:16:45"
	var parts = timestamp.split("T")
	if parts.size() != 2:
		return timestamp
	
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	
	if date_parts.size() >= 3 and time_parts.size() >= 2:
		return "%s-%s %s:%s" % [date_parts[1], date_parts[2], time_parts[0], time_parts[1]]
	
	return timestamp

func get_embedding(text: String) -> Array:
	"""获取文本的向量表示（调用嵌入API，使用队列系统）"""
	if embedding_base_url.is_empty() or embedding_model.is_empty():
		print("警告: 嵌入模型未配置")
		return []
	
	# 从配置读取API密钥
	var api_key = ""
	if config.has("embedding_model") and config.embedding_model.has("api_key"):
		api_key = config.embedding_model.get("api_key", "")
	
	if api_key.is_empty():
		print("警告: 嵌入模型API密钥未配置")
		return []
	
	# 创建请求信息
	var request_info = {
		"text": text,
		"api_key": api_key,
		"signal_emitter": null
	}
	
	# 添加到队列
	request_queue.append(request_info)
	
	# 如果没有正在处理的请求，开始处理队列
	if not is_processing_request:
		_process_request_queue()
	
	# 等待这个请求完成
	var result = await embedding_completed
	return result

func _process_request_queue():
	"""处理请求队列"""
	if request_queue.is_empty():
		is_processing_request = false
		return
	
	is_processing_request = true
	var request_info = request_queue.pop_front()
	
	var url = embedding_base_url.trim_suffix("/") + "/embeddings"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + request_info.api_key
	]
	
	var body = JSON.stringify({
		"model": embedding_model,
		"input": request_info.text
	})
	
	print("调用嵌入API (队列中还有 %d 个请求): %s" % [request_queue.size(), request_info.text.substr(0, 30)])
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("嵌入请求失败: ", error)
		embedding_completed.emit([])
		# 继续处理下一个请求
		_process_request_queue()

func _on_embedding_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""嵌入请求完成回调"""
	if result != HTTPRequest.RESULT_SUCCESS:
		print("嵌入请求失败: ", result)
		embedding_failed.emit("请求失败")
		embedding_completed.emit([])
		# 继续处理下一个请求
		_process_request_queue()
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		print("嵌入API返回错误 %d: %s" % [response_code, error_text])
		
		# 特殊处理401错误
		if response_code == 401:
			print("  ⚠️ 认证失败！请检查：")
			print("    1. API密钥是否正确")
			print("    2. API密钥是否有权限访问嵌入模型")
			print("    3. Base URL是否正确")
		
		embedding_failed.emit("API错误: %d" % response_code)
		embedding_completed.emit([])
		# 继续处理下一个请求
		_process_request_queue()
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("解析嵌入响应失败")
		embedding_failed.emit("解析失败")
		embedding_completed.emit([])
		# 继续处理下一个请求
		_process_request_queue()
		return
	
	var response = json.data
	
	# 提取向量
	if response.has("data") and response.data.size() > 0:
		var embedding = response.data[0].get("embedding", [])
		embedding_completed.emit(embedding)
	else:
		print("嵌入响应格式错误")
		embedding_failed.emit("响应格式错误")
		embedding_completed.emit([])
	
	# 继续处理下一个请求
	_process_request_queue()

func search(query: String, top_k: int = 5, min_similarity: float = 0.3, exclude_timestamps: Array = []) -> Array:
	"""搜索相关记忆
	
	Args:
		query: 查询文本
		top_k: 返回结果数量
		min_similarity: 最小相似度阈值
		exclude_timestamps: 要排除的时间戳列表
	"""
	if memory_items.is_empty():
		return []
	
	# 获取查询向量
	var query_vector = await get_embedding(query)
	
	if query_vector.is_empty():
		print("警告: 获取查询向量失败")
		return []
	
	# 计算所有记忆的相似度
	var similarities = []
	
	for i in range(memory_items.size()):
		var item = memory_items[i]
		
		# 跳过要排除的时间戳
		if exclude_timestamps.has(item.timestamp):
			continue
		
		var similarity = _calculate_similarity(query_vector, item.vector)
		
		if similarity >= min_similarity:
			similarities.append({
				"index": i,
				"similarity": similarity,
				"item": item
			})
	
	# 按相似度排序
	similarities.sort_custom(func(a, b): return a.similarity > b.similarity)
	
	# 返回top_k个结果
	var results = []
	for i in range(min(top_k, similarities.size())):
		results.append({
			"text": similarities[i].item.text,
			"similarity": similarities[i].similarity,
			"timestamp": similarities[i].item.timestamp,
			"type": similarities[i].item.type
		})
	
	return results

func _calculate_similarity(vec1: Array, vec2: Array) -> float:
	"""计算余弦相似度"""
	if cosine_calculator != null:
		return cosine_calculator.calculate(vec1, vec2)
	else:
		return _calculate_similarity_gdscript(vec1, vec2)

func _calculate_similarity_gdscript(vec1: Array, vec2: Array) -> float:
	"""GDScript实现的余弦相似度（降级方案）"""
	if vec1.size() != vec2.size() or vec1.size() == 0:
		return 0.0
	
	var dot = 0.0
	var mag1 = 0.0
	var mag2 = 0.0
	
	for i in range(vec1.size()):
		dot += vec1[i] * vec2[i]
		mag1 += vec1[i] * vec1[i]
		mag2 += vec2[i] * vec2[i]
	
	mag1 = sqrt(mag1)
	mag2 = sqrt(mag2)
	
	if mag1 == 0.0 or mag2 == 0.0:
		return 0.0
	
	return dot / (mag1 * mag2)

func get_relevant_memory(query: String, top_k: int = 5, _timeout: float = 10.0, min_similarity: float = 0.3, exclude_timestamps: Array = []) -> String:
	"""获取相关记忆并格式化为提示词
	
	Args:
		query: 查询文本
		top_k: 返回结果数量
		_timeout: 超时时间（保留参数，暂未使用）
		min_similarity: 最小相似度阈值
		exclude_timestamps: 要排除的时间戳列表
	"""
	var results = await search(query, top_k, min_similarity, exclude_timestamps)
	
	if results.is_empty():
		return ""
	
	# 从配置读取提示词模板
	var memory_config = config.get("memory", {})
	var prompts = memory_config.get("prompts", {})
	var prefix = prompts.get("memory_prefix", "这是唤醒的记忆，可以作为参考：\n```\n")
	var suffix = prompts.get("memory_suffix", "\n```\n以上是记忆而不是最近的对话，可以不使用。")
	
	# 格式化记忆
	var memory_texts = []
	for result in results:
		memory_texts.append(result.text)
	
	var memory_prompt = prefix + "\n".join(memory_texts) + suffix
	
	print("检索到 %d 条相关记忆" % results.size())
	return memory_prompt

func save_to_file(file_path: String = "") -> void:
	"""保存记忆数据到文件（文本和向量分开存储）"""
	if file_path.is_empty():
		file_path = "user://memory_%s.json" % db_name
	
	# 分离文本和向量
	var texts = []
	var vectors = []
	var metadata_list = []
	
	for item in memory_items:
		texts.append({
			"text": item.text,
			"timestamp": item.timestamp,
			"type": item.type,
			"metadata": item.metadata
		})
		vectors.append(item.vector)
		metadata_list.append({
			"timestamp": item.timestamp,
			"type": item.type
		})
	
	var data = {
		"db_name": db_name,
		"vector_dim": vector_dim,
		"last_updated": MemoryItem._get_local_datetime_string(),
		"count": memory_items.size(),
		"texts": texts,
		"vectors": vectors
	}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		print("保存记忆失败: ", FileAccess.get_open_error())
		return
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	
	print("记忆已保存: %s (%d 条)" % [file_path, memory_items.size()])

func load_from_file(file_path: String = "") -> void:
	"""从文件加载记忆数据（支持新旧格式）"""
	if file_path.is_empty():
		file_path = "user://memory_%s.json" % db_name
	
	if not FileAccess.file_exists(file_path):
		print("记忆文件不存在，将创建新数据库")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("加载记忆失败: ", FileAccess.get_open_error())
		return
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		print("解析记忆文件失败")
		return
	
	var data = json.data
	
	db_name = data.get("db_name", db_name)
	vector_dim = data.get("vector_dim", vector_dim)
	
	memory_items.clear()
	
	# 检测格式：新格式有 texts 和 vectors 字段
	if data.has("texts") and data.has("vectors"):
		# 新格式：文本和向量分开
		var texts = data.get("texts", [])
		var vectors = data.get("vectors", [])
		
		for i in range(min(texts.size(), vectors.size())):
			var text_data = texts[i]
			var item = MemoryItem.new()
			item.text = text_data.get("text", "")
			item.vector = vectors[i]
			item.timestamp = text_data.get("timestamp", "")
			item.type = text_data.get("type", "conversation")
			item.metadata = text_data.get("metadata", {})
			memory_items.append(item)
		
		print("记忆已加载（新格式）: %d 条" % memory_items.size())
	else:
		# 旧格式：兼容处理
		for item_data in data.get("items", []):
			memory_items.append(MemoryItem.from_dict(item_data))
		
		print("记忆已加载（旧格式）: %d 条" % memory_items.size())

func clear() -> void:
	"""清空所有记忆"""
	memory_items.clear()
	print("记忆已清空")
