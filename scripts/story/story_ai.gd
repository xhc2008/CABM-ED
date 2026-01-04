extends Node
class_name StoryAI

signal reply_ready(text: String)
signal sentence_ready(sentence: String)
signal all_sentences_completed()
signal error_occurred(error_message: String)

# 配置和API密钥管理
var config_loader: Node
var api_key: String = ""
var config: Dictionary = {}

# 短期上下文（对话历史）- 用于AI API上下文
var conversation_history: Array = []
var max_history_count: int = 20  # 故事模式携带20条上下文

# 显示历史（分句后的消息）- 保留完整记录，但限制大小防止内存泄漏
var display_history: Array = []
const MAX_DISPLAY_HISTORY_SIZE: int = 1000  # 最大显示历史条数

# 句子分割相关
const CHINESE_PUNCTUATION = ["。", "！", "？", "；","……"]
var sentence_queue: Array = []
var current_sentence_index: int = 0
var is_displaying: bool = false

# HTTP请求节点
var http_request: HTTPRequest

# 日志记录器
var logger: Node

func _ready():
	# 初始化配置加载器
	config_loader = preload("res://scripts/ai_chat/ai_config_loader.gd").new()
	add_child(config_loader)
	config_loader.load_all()

	# 获取配置和API密钥
	api_key = config_loader.api_key
	config = config_loader.config

	# 初始化日志记录器
	logger = preload("res://scripts/ai_chat/ai_logger.gd").new()
	add_child(logger)

	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func request_reply(prompt: String, story_context: Dictionary = {}):
	"""请求AI回复（异步）

	Args:
		prompt: 用户输入的提示词
		story_context: 故事上下文，包含故事相关信息
	"""
	if api_key.is_empty():
		error_occurred.emit("API密钥未配置")
		return

	# 重置句子显示状态
	sentence_queue.clear()
	current_sentence_index = 0
	is_displaying = false

	# 异步处理请求
	_handle_request_async(prompt, story_context)

func _handle_request_async(prompt: String, story_context: Dictionary):
	"""异步处理请求"""
	# 构建系统提示词
	var system_prompt = _build_system_prompt(story_context)

	# 构建消息列表
	var messages = [{"role": "system", "content": system_prompt}]

	# 添加短期上下文（限制数量）
	var history_to_send = _get_limited_history()
	for msg in history_to_send:
		messages.append(msg)

	# 添加当前用户消息
	messages.append({"role": "user", "content": prompt})

	# 记录请求日志
	logger.log_api_request("STORY_AI_REQUEST", {"messages": messages}, JSON.stringify({"messages": messages}))

	# 调用AI API（异步）
	await _call_ai_api_async(messages, prompt)

func _build_system_prompt(story_context: Dictionary) -> String:
	"""构建系统提示词

	Args:
		story_context: 故事上下文，包含：
			- story_summary: 故事简介
			- character_preset: 人物设定
			- experienced_chapters: 经历的故事章节
			- current_node_content: 当前节点内容
			- story_id: 故事ID
			- node_id: 节点ID
	"""

	var save_mgr = get_node("/root/SaveManager")

	# 获取基本信息
	var character_name = save_mgr.get_character_name()
	var user_name = save_mgr.get_user_name()
	var user_address = save_mgr.get_user_address()

	var prompt_parts = []

	# 1. 基础提示词（身份设定）
	var base_prompt = """你是{character_name}，你是人类，女，白色中短发，淡蓝色眼睛。
"""

	base_prompt = base_prompt.format({
		"character_name": character_name,
		"user_name": user_name,
		"user_address": user_address
	})
	prompt_parts.append(base_prompt)

	# 2. 人物设定
	var character_preset = story_context.get("character_preset", "")
	if not character_preset.is_empty():
		prompt_parts.append("## 人物设定\n" + character_preset)

	# 3. 故事简介
	var story_summary = story_context.get("story_summary", "")
	if not story_summary.is_empty():
		prompt_parts.append("## 故事简介\n" + story_summary)

	# 4. 经历的故事章节
	var experienced_chapters = story_context.get("experienced_chapters", [])
	if not experienced_chapters.is_empty():
		var chapters_text = "## 经历的故事章节\n"
		for i in range(experienced_chapters.size()):
			var chapter = experienced_chapters[i]
			chapters_text += chapter.get("display_text") + "\n"
		prompt_parts.append(chapters_text)

	# 5. 当前节点内容（作为故事起点）
	var current_node_content = story_context.get("current_node_content", "")
	if not current_node_content.is_empty():
		prompt_parts.append("## 当前故事节点\n" + current_node_content)

	return "\n\n".join(prompt_parts)

func _get_limited_history() -> Array:
	"""获取限制数量的短期上下文（超出部分不携带但不要删除）"""
	var history_to_send = []
	var start_index = max(0, conversation_history.size() - max_history_count)

	for i in range(start_index, conversation_history.size()):
		history_to_send.append({
			"role": conversation_history[i].role,
			"content": conversation_history[i].content
		})

	return history_to_send

func _call_ai_api_async(messages: Array, user_prompt: String):
	"""异步调用AI API（非流式，非JSON）"""
	var chat_config = config.chat_model
	var url = chat_config.base_url + "/chat/completions"

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	var body = {
		"model": chat_config.model,
		"messages": messages,
		"max_tokens": int(chat_config.max_tokens),
		"temperature": float(chat_config.temperature),
		"top_p": float(chat_config.top_p),
		"stream": false,  # 非流式响应
		"enable_thinking": false
	}

	var json_body = JSON.stringify(body)

	# 存储用户消息和请求信息，用于后续处理
	http_request.set_meta("user_prompt", user_prompt)
	http_request.set_meta("messages", messages)
	http_request.set_meta("request_body", body)

	# 设置请求超时
	http_request.timeout = 30.0  # 30秒超时

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		error_occurred.emit("请求失败: " + str(error))
		return

	# 创建超时计时器
	var timeout_timer = Timer.new()
	add_child(timeout_timer)
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_request_timeout.bind(timeout_timer))
	timeout_timer.start(30.0)  # 30秒超时

	# 等待请求完成（异步）
	await http_request.request_completed

	# 如果请求完成，停止超时计时器
	if timeout_timer.time_left > 0:
		timeout_timer.stop()
	timeout_timer.queue_free()

func _on_request_timeout(timer: Timer):
	"""请求超时处理"""
	# 取消HTTP请求
	http_request.cancel_request()

	# 记录超时日志
	logger.log_error("STORY_AI_TIMEOUT", "API请求超时", "")

	# 发出错误信号
	error_occurred.emit("请求超时，请检查网络连接或稍后重试")

	# 清理计时器
	if timer:
		timer.queue_free()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""处理API响应"""
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("请求失败: " + str(result))
		return

	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var request_body = http_request.get_meta("request_body", {})
		logger.log_api_error(response_code, error_text, request_body)
		error_occurred.emit("API错误 (%d): %s" % [response_code, error_text])
		return

	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		error_occurred.emit("响应解析失败")
		return

	var response_data = json.data

	# 提取回复内容
	var reply_text = ""
	if response_data.has("choices") and response_data.choices.size() > 0:
		var choice = response_data.choices[0]
		if choice.has("message") and choice.message.has("content"):
			reply_text = choice.message.content.strip_edges()

	if reply_text.is_empty():
		error_occurred.emit("未获取到有效回复")
		return

	# 记录响应日志
	var messages = http_request.get_meta("messages", [])
	logger.log_api_call("STORY_AI_RESPONSE", messages, reply_text)

	# 添加到AI上下文历史（完整的对话）
	var user_prompt = http_request.get_meta("user_prompt", "")
	if not user_prompt.is_empty():
		conversation_history.append({"role": "user", "content": user_prompt})
	conversation_history.append({"role": "assistant", "content": reply_text})

	# 限制AI上下文历史记录总数
	if conversation_history.size() > max_history_count * 2:
		# 只保留最近的部分
		var keep_count = max_history_count
		conversation_history = conversation_history.slice(-keep_count)

	# 发送完整回复（用于后台保存）
	reply_ready.emit(reply_text)

	# 分割句子并开始逐句显示
	_split_and_display_sentences(reply_text)

func _split_and_display_sentences(text: String):
	"""分割文本为句子并逐句显示"""
	# 分割句子
	sentence_queue = _split_text_to_sentences(text)
	current_sentence_index = 0
	is_displaying = true

	if sentence_queue.is_empty():
		all_sentences_completed.emit()
		return

	# 立即显示第一句
	await _display_next_sentence(true)

	# 逐句显示后续句子
	while current_sentence_index < sentence_queue.size():
		await _display_next_sentence(false)
	is_displaying = false
	all_sentences_completed.emit()

func _split_text_to_sentences(text: String) -> Array:
	"""将文本按标点符号分割为句子"""
	var sentences = []
	var current_sentence = ""
	var in_parentheses = false
	var in_quotes = false

	for i in range(text.length()):
		var achar = text[i]

		# 处理括号和引号
		if achar == "(" or achar == "（":
			in_parentheses = true
		elif achar == ")" or achar == "）":
			in_parentheses = false
		elif achar == "\"" or achar == "'" or achar == "「" or achar == "『":
			in_quotes = !in_quotes

		current_sentence += achar

		# 检查是否是句子结束标点（不在括号或引号内）
		if achar in CHINESE_PUNCTUATION and not in_parentheses and not in_quotes:
			# 检查下一个字符是否也是标点
			if i + 1 < text.length():
				var next_char = text[i + 1]
				if next_char in CHINESE_PUNCTUATION:
					continue

			# 提取完整句子
			var sentence = current_sentence.strip_edges()
			if not sentence.is_empty():
				sentence = sentence.trim_suffix("。")
				sentences.append(sentence)
			current_sentence = ""

	# 处理最后剩余的文本
	if not current_sentence.strip_edges().is_empty():
		sentences.append(current_sentence.strip_edges())

	return sentences

func _display_next_sentence(is_first: bool):
	"""显示下一句句子"""
	if current_sentence_index >= sentence_queue.size():
		return

	var sentence = sentence_queue[current_sentence_index]
	current_sentence_index += 1

	# 如果不是第一句，根据句子长度计算延迟时间
	if not is_first:
		# 根据句子长度计算延迟：每10个字符约0.8秒，最少0.3秒，最多2秒
		var delay = clamp(sentence.length() * 0.8, 0.3, 2.0)
		await get_tree().create_timer(delay).timeout

	# 发送句子就绪信号
	sentence_ready.emit(sentence)

func add_to_display_history(role: String, content: String):
	"""添加到显示历史（分句后的消息记录）"""
	display_history.append({"role": role, "content": content})

	# 限制显示历史大小，防止内存泄漏
	if display_history.size() > MAX_DISPLAY_HISTORY_SIZE:
		# 保留最新的80%历史记录
		var keep_count = int(MAX_DISPLAY_HISTORY_SIZE * 0.8)
		display_history = display_history.slice(-keep_count)
		print("显示历史超出限制，已清理旧记录，当前大小: ", display_history.size())

func get_display_history() -> Array:
	"""获取显示历史"""
	return display_history.duplicate()

func clear_history():
	"""清空所有对话历史"""
	conversation_history.clear()
	display_history.clear()

func set_story_context(story_context: Dictionary):
	"""设置故事上下文（可用于更新提示词中的故事信息）"""
	# 这里可以存储故事上下文，用于后续的提示词构建
	pass
