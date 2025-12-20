extends Node

# 探索场景专用聊天总结管理器
# 用于生成探索场景的聊天归档总结

var config_loader: Node
var api_key: String = ""
var config: Dictionary = {}

# HTTP请求节点
var http_request: HTTPRequest

func _init():
	pass

func setup():
	"""初始化管理器"""
	# 初始化配置加载器
	config_loader = preload("res://scripts/ai_chat/ai_config_loader.gd").new()
	add_child(config_loader)
	config_loader.load_all()

	# 获取配置和API密钥
	api_key = config_loader.api_key
	config = config_loader.config

	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func call_explore_summary_api(conversation_history: Array, user_name: String, explore_scene_name: String) -> String:
	"""调用探索场景总结API

	Args:
		conversation_history: 对话历史数组
		user_name: 用户名
		explore_scene_name: 探索场景名称

	Returns:
		总结文本，如果失败则返回空字符串
	"""
	if not config.has("summary_model") or api_key.is_empty():
		push_error("探索总结管理器: 配置不完整")
		return ""

	var summary_config = config.summary_model
	var model = summary_config.model
	var base_url = summary_config.base_url

	if model.is_empty() or base_url.is_empty():
		push_error("探索总结模型配置不完整")
		return ""

	# 扁平化对话历史
	var flattened_conversation = _flatten_conversation_history(conversation_history)

	# 构建系统提示词
	var system_prompt = "你是一个总结专家。请以第一人称视角，用简洁的语言总结这段探索场景中的对话内容。总结应该反映探索、战斗和互动的主要内容，不要超过150字。直接给出总结内容，不要包含多余的提示。"

	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": flattened_conversation}
	]

	var url = base_url + "/chat/completions"
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + api_key]

	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": 1024,
		"temperature": 0.3,
		"top_p": 0.7,
        "enable_thinking":false,
		"stream": false
	}

	var json_body = JSON.stringify(body)

	# 存储请求信息
	http_request.set_meta("request_type", "explore_summary")
	http_request.set_meta("user_name", user_name)
	http_request.set_meta("explore_scene_name", explore_scene_name)
	http_request.set_meta("messages", messages)

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("探索总结请求失败: " + str(error))
		return ""

	# 等待响应
	var result = await http_request.request_completed
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		push_error("探索总结请求失败: " + str(result[0]))
		return ""

	var response_code = result[1]
	var response_body = result[3]

	if response_code != 200:
		var error_text = response_body.get_string_from_utf8()
		push_error("探索总结API错误 (%d): %s" % [response_code, error_text])
		return ""

	var response_text = response_body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		push_error("探索总结响应解析失败: " + response_text)
		return ""

	var response_data = json.data
	var summary = ""

	if response_data.has("choices") and response_data.choices.size() > 0:
		var choice = response_data.choices[0]
		if choice.has("message") and choice.message.has("content"):
			summary = choice.message.content.strip_edges()

	# 返回总结内容（如果成功）或空字符串（如果失败）
	return summary

func _flatten_conversation_history(conversation_history: Array) -> String:
	"""将对话历史扁平化为文本格式

	Args:
		conversation_history: 对话历史数组，每个元素包含role和content

	Returns:
		扁平化的对话文本
	"""
	var flattened = []

	for msg in conversation_history:
		var role = msg.get("role", "")
		var content = msg.get("content", "")

		if role == "user":
			flattened.append("用户: " + content)
		elif role == "assistant":
			flattened.append("AI: " + content)

	return "\n".join(flattened)

func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	"""处理请求完成信号"""
	# 这个方法主要用于异步请求，但我们使用await所以这里不需要处理
	pass
