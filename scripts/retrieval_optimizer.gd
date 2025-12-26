extends Node
## 检索优化器 - 召回前推理
## 根据用户问题和上下文生成优化后的检索查询

# 请求队列系统
class RetrievalOptimizationRequest:
	var query: String = ""
	var context: String = ""
	var completed: bool = false
	var result: Array = []

	func _init(p_query: String, p_context: String):
		query = p_query
		context = p_context

var request_queue: Array = []
var is_processing_request: bool = false
var current_request: Dictionary = {}
var http_request: HTTPRequest = null

# 配置变量
var model: String = ""
var base_url: String = ""
var api_key: String = ""
var timeout: float = 30.0
var max_tokens: int = 512
var temperature: float = 0.3
var top_p: float = 0.7
var system_prompt: String = ""

func _ready():
	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func initialize(p_model: String, p_base_url: String, p_api_key: String, p_timeout: float, p_max_tokens: int, p_temperature: float, p_top_p: float, p_system_prompt: String):
	"""初始化检索优化器"""
	model = p_model
	base_url = p_base_url
	api_key = p_api_key
	timeout = p_timeout
	max_tokens = p_max_tokens
	temperature = p_temperature
	top_p = p_top_p
	system_prompt = p_system_prompt
	print(model)
	print(base_url)
	print(api_key)

func optimize_query(query: String, context: String) -> Array:
	"""优化检索查询
	Args:
		query: 用户原始查询
		context: 扁平化上下文信息
	Returns:
		优化后的查询列表，失败时返回空数组
	"""
	if model.is_empty() or base_url.is_empty() or api_key.is_empty():
		print("检索优化器未配置")
		return []

	if system_prompt.is_empty():
		print("检索优化系统提示词未配置")
		return []

	# 创建请求对象
	var request = RetrievalOptimizationRequest.new(query, context)
	request_queue.append({"request": request, "api_key": api_key})

	# 如果没有正在处理的请求，开始处理队列
	if not is_processing_request:
		_process_request_queue()

	# 等待这个特定请求完成
	while not request.completed:
		await get_tree().process_frame

	return request.result

func _process_request_queue():
	"""处理请求队列"""
	if request_queue.is_empty():
		is_processing_request = false
		current_request = {}
		return

	is_processing_request = true
	current_request = request_queue.pop_front()
	var request = current_request.request
	var api_key = current_request.api_key

	var url = base_url.trim_suffix("/") + "/chat/completions"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	# 构建用户提示词
	var user_prompt = "用户问题: " + request.query + "\n\n上下文信息:\n" + request.context

	var body = JSON.stringify({
		"model": model,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt}
		],
		"max_tokens": max_tokens,
		"temperature": temperature,
		"top_p": top_p,
		"stream": false
	})

	print("调用检索优化API: %s" % request.query.substr(0, 30))

	http_request.timeout = timeout
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		print("检索优化请求失败: ", error)
		request.completed = true
		request.result = []
		# 继续处理下一个请求
		_process_request_queue()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""请求完成回调"""
	if current_request.is_empty():
		print("警告: 没有当前请求")
		_process_request_queue()
		return

	var request = current_request.request

	if result != HTTPRequest.RESULT_SUCCESS:
		print("检索优化请求失败: ", result)
		request.completed = true
		request.result = []
		_process_request_queue()
		return

	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		print("检索优化API返回错误 %d: %s" % [response_code, error_text])
		request.completed = true
		request.result = []
		_process_request_queue()
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		print("解析检索优化响应失败")
		request.completed = true
		request.result = []
		_process_request_queue()
		return

	var response = json.data

	# 提取优化后的查询
	var optimized_queries = []
	if response.has("choices") and response.choices.size() > 0:
		var content = response.choices[0].get("message", {}).get("content", "")

		# 解析换行分隔的查询文本
		var lines = content.split("\n", false)
		for line in lines:
			var trimmed_line = line.strip_edges()
			# 跳过空行
			if not trimmed_line.is_empty():
				optimized_queries.append(trimmed_line)

		print("检索优化成功，生成 %d 个查询" % optimized_queries.size())
		if optimized_queries.size() == 0:
			print("警告: 解析响应后没有有效的查询")

	request.completed = true
	request.result = optimized_queries

	# 继续处理下一个请求
	_process_request_queue()
