extends Node
class_name AdventureAI

signal reply_ready(text: String)
signal error_occurred(error_message: String)

# 配置和API密钥管理
var config_loader: Node
var api_key: String = ""
var config: Dictionary = {}

# HTTP请求节点
var http_request: HTTPRequest

# 短期上下文（对话历史）
var conversation_history: Array = []
var max_history_count: int = 16  # 最多携带的上下文数量

func _ready():
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

func request_reply(prompt: String, scene_name: String = "") -> void:
	"""请求AI回复
	
	Args:
		prompt: 用户输入的提示词
		scene_name: 当前场景名称（可选）
	"""
	if api_key.is_empty():
		error_occurred.emit("API密钥未配置")
		return
	
	# 构建系统提示词（传入prompt用于知识图谱检索）
	var system_prompt = _build_system_prompt(scene_name, prompt)
	
	# 构建消息列表
	var messages = [{"role": "system", "content": system_prompt}]
	
	# 添加短期上下文（限制数量）
	var history_to_send = _get_limited_history()
	for msg in history_to_send:
		messages.append(msg)
	
	# 添加当前用户消息
	messages.append({"role": "user", "content": prompt})
	
	# 调用AI API
	_call_ai_api(messages, prompt)

func _build_system_prompt(scene_name: String, user_prompt: String = "") -> String:
	"""构建系统提示词
	
	Args:
		scene_name: 场景名称
		user_prompt: 用户输入的提示词（用于知识图谱检索）
	"""
	if not has_node("/root/SaveManager"):
		return "你是一个AI助手。"
	
	var save_mgr = get_node("/root/SaveManager")
	var prompt_builder = get_node("/root/PromptBuilder")
	
	# 获取基本信息
	var character_name = save_mgr.get_character_name()
	var user_name = save_mgr.get_user_name()
	var user_address = save_mgr.get_user_address()
	
	# 获取角色提示词
	var character_preset = prompt_builder._load_character_preset()
	var character_prompt = character_preset.get("prompt", "")
	
	# 获取场景信息
	var scene_description = ""
	var final_scene_name = scene_name
	if scene_name.is_empty():
		# 如果没有提供场景名，尝试从存档获取
		var current_scene = save_mgr.get_character_scene()
		if not current_scene.is_empty():
			scene_description = prompt_builder._get_scene_description(current_scene)
			final_scene_name = scene_description
	else:
		scene_description = scene_name
	
	# 构建场景提示词
	var scene_context = ""
	if not final_scene_name.is_empty():
		scene_context = "你正在和%s在%s进行探索。" % [user_name, final_scene_name]
	
	# 检索知识图谱（不需要语义检索）
	# 使用用户输入或场景名称作为查询
	var query_for_kg = user_prompt if not user_prompt.is_empty() else final_scene_name
	var knowledge_memory = _retrieve_knowledge_memory(query_for_kg)
	
	# 获取中期记忆条目
	var memory_context = prompt_builder.get_memory_context()
	
	# 获取关系上下文
	var relationship_context = prompt_builder.get_relationship_context()
	
	# 构建完整的系统提示词
	var system_prompt_parts = []
	
	# 身份设定
	system_prompt_parts.append("你是%s，被「%s」收养的失忆少女，现在和他生活在一起。你习惯称呼他为「%s」。%s" % [
		character_name, user_name, user_address, character_prompt
	])
	
	# 场景信息
	if not scene_context.is_empty():
		system_prompt_parts.append(scene_context)
	
	# 知识记忆
	if not knowledge_memory.is_empty():
		system_prompt_parts.append(knowledge_memory)
	
	# 中期记忆
	if not memory_context.is_empty() and memory_context != "（这是你们的第一次对话）":
		system_prompt_parts.append("最近发生的事情：\n%s" % memory_context)
	
	# 关系上下文
	if not relationship_context.is_empty() and relationship_context != "（暂无关系信息）":
		system_prompt_parts.append("你们之间的关系：\n%s" % relationship_context)
	
	# 输出要求
	system_prompt_parts.append("请以自然、生动的语言回复，不要使用JSON格式，直接输出文本。")
	
	return "\n\n".join(system_prompt_parts)

func _retrieve_knowledge_memory(query: String) -> String:
	"""检索知识图谱并返回格式化的知识记忆提示段"""
	if query.strip_edges().is_empty():
		return ""
	
	var kg_prompt = ""
	
	# 提取关键词
	var ke = preload("res://scripts/keyword_extractor.gd").new()
	var keywords = ke.extract_keywords(query, config.get("knowledge_memory", {}).get("query", {}).get("top_k", 6))
	
	if keywords.is_empty():
		return ""
	
	# 查询知识图谱
	var mg = preload("res://scripts/memory_graph.gd").new()
	var top_k = config.get("knowledge_memory", {}).get("query", {}).get("top_k", 6)
	var graph_results = mg.query_by_keywords(keywords, top_k)
	
	if graph_results.is_empty():
		return ""
	
	# 格式化为提示词段落
	var lines = []
	for r in graph_results:
		var t = r.get("T", "")
		var s = r.get("S", "")
		var p = r.get("P", "")
		var o = r.get("O", "")
		var i = r.get("I", 1)
		lines.append("[%s] %s %s %s (权重：%s)" % [t, s, p, o, str(i)])
	
	var mem_prompts = config.get("knowledge_memory", {}).get("prompts", {})
	var prefix = mem_prompts.get("memory_prefix", "\n```\n")
	var suffix = mem_prompts.get("memory_suffix", "\n```\n以上是当前输入相关的认知，可作为参考。")
	kg_prompt = prefix + "\n".join(lines) + suffix
	
	return kg_prompt

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

func _call_ai_api(messages: Array, user_prompt: String):
	"""调用AI API（非流式，非JSON）"""
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
		"stream": false  # 非流式响应
	}
	
	var json_body = JSON.stringify(body)
	
	# 存储用户消息，用于后续添加到历史
	http_request.set_meta("user_prompt", user_prompt)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		error_occurred.emit("请求失败: " + str(error))
		return

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""处理API响应"""
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("请求失败: " + str(result))
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		error_occurred.emit("API错误 (%d): %s" % [response_code, error_text])
		return
	
	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		error_occurred.emit("响应解析失败")
		return
	
	var response_data = json.data
	
	# 提取回复内容（非JSON格式，直接获取文本）
	var reply_text = ""
	if response_data.has("choices") and response_data.choices.size() > 0:
		var choice = response_data.choices[0]
		if choice.has("message") and choice.message.has("content"):
			reply_text = choice.message.content.strip_edges()
	
	if reply_text.is_empty():
		error_occurred.emit("未获取到有效回复")
		return
	
	# 添加到对话历史
	var user_prompt = http_request.get_meta("user_prompt", "")
	if not user_prompt.is_empty():
		conversation_history.append({"role": "user", "content": user_prompt})
	conversation_history.append({"role": "assistant", "content": reply_text})
	
	# 限制历史记录总数（防止无限增长，但保留所有记录用于其他用途）
	# 这里只限制用于API调用的历史，不删除原始记录
	if conversation_history.size() > max_history_count * 2:
		# 只保留最近的部分
		var keep_count = max_history_count
		conversation_history = conversation_history.slice(-keep_count)
	
	# 发送回复
	reply_ready.emit(reply_text)

func clear_history():
	"""清空对话历史"""
	conversation_history.clear()
