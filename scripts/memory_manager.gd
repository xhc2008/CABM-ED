extends Node
## 记忆管理器 - 统一管理对话和日记的向量存储
## 加载策略：
## - 嵌入和重排序模型：从用户配置加载 api_key, base_url, model
## - 其他所有配置：从项目配置加载

signal memory_system_ready

var memory_system: Node = null
var config: Dictionary = {}
var is_initialized: bool = false

# 自动保存
var auto_save_timer: Timer = null

func _ready():
	# 等待保存管理器就绪
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.is_resources_ready():
		print("记忆管理器等待资源加载")
		return
	# 加载配置
	_load_config()

	# 如果配置加载失败，不继续初始化
	if config.is_empty() or not config.has("embedding_model"):
		print("记忆管理器初始化失败：配置不完整")
		return

	# 创建记忆系统实例
	var memory_script = load("res://scripts/memory_system.gd")
	memory_system = memory_script.new()
	add_child(memory_system)

	# 初始化记忆系统
	memory_system.initialize(config, "main_memory")
	is_initialized = true

	# 设置自动保存
	if config.get("storage", {}).get("auto_save", true):
		_setup_auto_save()

	memory_system_ready.emit()
	print("记忆管理器已就绪")

func _load_config():
	"""加载记忆配置"""
	# 1. 先加载项目配置中的记忆相关配置
	var project_config = _load_project_config()
	
	# 2. 加载用户配置中的嵌入和重排序模型配置
	var user_config = _load_user_config()
	
	# 3. 合并配置（项目配置为基础，用户配置覆盖特定字段）
	config = _merge_configs(project_config, user_config)
	
	print("记忆配置加载完成")
	_log_memory_config()

func _load_project_config() -> Dictionary:
	"""从项目配置文件加载记忆相关配置"""
	var config_path = "res://config/ai_config.json"
	var result = {}
	
	if not FileAccess.file_exists(config_path):
		print("警告: AI 项目配置文件不存在")
		return result
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		print("警告: 无法打开项目配置文件")
		return result
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("警告: 项目配置解析失败")
		return result
	
	var project_config = json.data
	
	# 提取记忆相关配置
	if project_config.has("memory"):
		result["memory"] = project_config.memory

	# 复制summary_model配置
	if project_config.has("summary_model"):
		result["summary_model"] = project_config.summary_model
		
		# 从 memory 配置中提取子配置
		var memory_config = project_config.memory
		
		# 存储配置
		result["storage"] = {
			"store_summaries": memory_config.get("store_summaries", true),
			"store_diaries": memory_config.get("store_diaries", true),
			"auto_save": memory_config.get("auto_save", true),
			"save_interval": memory_config.get("save_interval", 300)
		}
		
		# 检索配置
		if memory_config.has("vector_db"):
			var vector_db = memory_config.vector_db
			result["retrieval"] = {
				"top_k": vector_db.get("top_k", 5),
				"min_similarity": vector_db.get("min_similarity", 0.3),
				"timeout": vector_db.get("timeout", 10.0)
			}
	
	# 嵌入模型的其他配置（非 api_key/base_url/model）
	if project_config.has("embedding_model"):
		var embed_config = project_config.embedding_model
		result["embedding_model_config"] = {}
		
		# 复制除了 api_key/base_url/model 之外的所有字段
		for key in embed_config:
			if key not in ["api_key", "base_url", "model"]:
				result["embedding_model_config"][key] = embed_config[key]
	
	# 重排序模型的其他配置
	if project_config.has("rerank_model"):
		var rerank_config = project_config.rerank_model
		result["rerank_model_config"] = {}

		for key in rerank_config:
			if key not in ["api_key", "base_url", "model"]:
				result["rerank_model_config"][key] = rerank_config[key]

	# 总结模型的其他配置
	if project_config.has("summary_model"):
		var summary_config = project_config.summary_model
		result["summary_model_config"] = {}

		for key in summary_config:
			if key not in ["api_key", "base_url", "model"]:
				result["summary_model_config"][key] = summary_config[key]

	print("项目配置加载成功")
	return result

func _load_user_config() -> Dictionary:
	"""从用户配置文件加载嵌入和重排序模型的 api_key/base_url/model"""
	var config_path = "user://ai_keys.json"
	var result = {}
	
	if not FileAccess.file_exists(config_path):
		print("警告: AI 用户配置文件不存在")
		return result
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		print("警告: 无法打开用户配置文件")
		return result
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("警告: 用户配置解析失败")
		return result
	
	var user_config = json.data
	
	# 只提取嵌入模型和重排序模型的 api_key/base_url/model
	if user_config.has("embedding_model"):
		result["embedding_model"] = {
			"api_key": user_config.embedding_model.get("api_key", ""),
			"base_url": user_config.embedding_model.get("base_url", ""),
			"model": user_config.embedding_model.get("model", "")
		}
	
	if user_config.has("rerank_model"):
		result["rerank_model"] = {
			"api_key": user_config.rerank_model.get("api_key", ""),
			"base_url": user_config.rerank_model.get("base_url", ""),
			"model": user_config.rerank_model.get("model", "")
		}

	if user_config.has("summary_model"):
		result["summary_model"] = {
			"api_key": user_config.summary_model.get("api_key", ""),
			"base_url": user_config.summary_model.get("base_url", ""),
			"model": user_config.summary_model.get("model", "")
		}

	print("用户配置加载成功")
	return result

func _merge_configs(project_config: Dictionary, user_config: Dictionary) -> Dictionary:
	"""合并项目配置和用户配置"""
	var merged = {}
	
	# 1. 先复制项目配置中的所有内容
	merged = project_config.duplicate(true)
	
	# 2. 合并嵌入模型配置
	if user_config.has("embedding_model"):
		var user_embed = user_config.embedding_model
		var project_embed = project_config.get("embedding_model_config", {})
		
		merged["embedding_model"] = {}
		# 用户配置的字段优先
		if user_embed.has("model") and not user_embed.model.is_empty():
			merged["embedding_model"]["model"] = user_embed.model
		if user_embed.has("base_url") and not user_embed.base_url.is_empty():
			merged["embedding_model"]["base_url"] = user_embed.base_url
		if user_embed.has("api_key") and not user_embed.api_key.is_empty():
			merged["embedding_model"]["api_key"] = user_embed.api_key
		
		# 添加项目配置中的其他字段
		for key in project_embed:
			merged["embedding_model"][key] = project_embed[key]
	
	# 3. 合并重排序模型配置（如果有）
	if user_config.has("rerank_model"):
		var user_rerank = user_config.rerank_model
		var project_rerank = project_config.get("rerank_model_config", {})
		
		merged["rerank_model"] = {}
		# 用户配置的字段优先
		if user_rerank.has("model") and not user_rerank.model.is_empty():
			merged["rerank_model"]["model"] = user_rerank.model
		if user_rerank.has("base_url") and not user_rerank.base_url.is_empty():
			merged["rerank_model"]["base_url"] = user_rerank.base_url
		if user_rerank.has("api_key") and not user_rerank.api_key.is_empty():
			merged["rerank_model"]["api_key"] = user_rerank.api_key
		
		# 添加项目配置中的其他字段
		for key in project_rerank:
			merged["rerank_model"][key] = project_rerank[key]

	# 4. 合并总结模型配置（用于检索优化）
	if user_config.has("summary_model"):
		var user_summary = user_config.summary_model

		# summary_model 已经从项目配置复制过来了，现在只需要覆盖用户配置的字段
		if user_summary.has("model") and not user_summary.model.is_empty():
			merged["summary_model"]["model"] = user_summary.model
		if user_summary.has("base_url") and not user_summary.base_url.is_empty():
			merged["summary_model"]["base_url"] = user_summary.base_url
		if user_summary.has("api_key") and not user_summary.api_key.is_empty():
			merged["summary_model"]["api_key"] = user_summary.api_key

	return merged

func _log_memory_config():
	"""打印记忆配置摘要"""
	if config.has("embedding_model"):
		var embed = config.embedding_model
		print("嵌入模型: " + str(embed.get("model", "未设置")))
		if embed.has("base_url"):
			print("  Base URL: " + str(embed.base_url))
	
	if config.has("rerank_model"):
		print("重排序模型: 已配置")
	else:
		print("重排序模型: 未配置")

	if config.has("summary_model"):
		var summary = config.summary_model
		print("总结模型: " + str(summary.get("model", "未设置")))
		if summary.has("base_url"):
			print("  Base URL: " + str(summary.base_url))
	else:
		print("总结模型: 未配置")
	
	if config.has("storage"):
		var storage = config.storage
		print("存储配置:")
		print("  保存总结: " + str(storage.get("store_summaries", true)))
		print("  保存日记: " + str(storage.get("store_diaries", true)))
		print("  自动保存: " + str(storage.get("auto_save", true)))

# 以下方法保持不变...
func _setup_auto_save():
	"""设置自动保存定时器"""
	auto_save_timer = Timer.new()
	add_child(auto_save_timer)
	
	var interval = config.get("storage", {}).get("save_interval", 300)
	auto_save_timer.wait_time = interval
	auto_save_timer.timeout.connect(_on_auto_save)
	auto_save_timer.start()
	
	print("自动保存已启用，间隔: %d 秒" % interval)

func _on_auto_save():
	"""自动保存回调"""
	if memory_system:
		memory_system.save_to_file()
		print("记忆数据已自动保存")

func add_conversation_summary(summary: String, metadata: Dictionary = {}, custom_timestamp: String = ""):
	"""添加对话总结到记忆系统"""
	if not is_initialized:
		await memory_system_ready
	
	if summary.strip_edges().is_empty():
		return
	
	var storage_config = config.get("storage", {})
	if storage_config.get("store_summaries", true):
		await memory_system.add_text(summary, "conversation", metadata, custom_timestamp)
		print("对话总结已添加到向量库")

func add_diary_entry(entry: Dictionary):
	"""添加日记条目到记忆系统"""
	if not is_initialized:
		await memory_system_ready
	
	var storage_config = config.get("storage", {})
	if storage_config.get("store_diaries", true):
		var diary_text = entry.event
		await memory_system.add_diary_entry(diary_text)
		print("日记条目已添加到向量库")

func get_relevant_memory_for_chat(context: String, exclude_timestamps: Array = []) -> String:
	"""获取与当前对话相关的记忆"""
	if not is_initialized:
		print("记忆系统未初始化，等待就绪...")
		await memory_system_ready
	
	var retrieval_config = config.get("retrieval", {})
	var top_k = retrieval_config.get("top_k")
	var min_similarity = retrieval_config.get("min_similarity")
	var timeout = retrieval_config.get("timeout")
	
	print("开始检索记忆：top_k=%d, min_similarity=%.2f, 排除=%d条" % [top_k, min_similarity, exclude_timestamps.size()])
	var result = await memory_system.get_relevant_memory(context, top_k, timeout, min_similarity, exclude_timestamps)
	print("记忆检索完成，结果长度: %d" % result.length())
	
	return result

func save():
	"""手动保存记忆数据"""
	if memory_system:
		memory_system.save_to_file()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 退出前保存
		if memory_system:
			memory_system.save_to_file()
			print("退出前保存记忆数据")
