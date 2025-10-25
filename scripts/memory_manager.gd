extends Node
## 记忆管理器 - 统一管理对话和日记的向量存储
## 自动加载节点，提供全局记忆访问接口

signal memory_system_ready

var memory_system: Node = null
var config: Dictionary = {}
var is_initialized: bool = false

# 自动保存
var auto_save_timer: Timer = null

func _ready():
	# 加载配置
	_load_config()
	
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
	"""加载记忆配置（优先从用户配置，然后从项目配置）"""
	# 先尝试从用户配置加载（UI保存的配置）
	var user_config_path = "user://ai_keys.json"
	var project_config_path = "res://config/ai_config.json"
	
	var ai_config = {}
	
	# 优先读取用户配置
	if FileAccess.file_exists(user_config_path):
		var file = FileAccess.open(user_config_path, FileAccess.READ)
		if file != null:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				ai_config = json.data
				print("从用户配置加载: user://ai_keys.json")
			file.close()
	
	# 如果用户配置没有嵌入模型，从项目配置读取
	if not ai_config.has("embedding_model") or ai_config.embedding_model.get("model", "").is_empty():
		if FileAccess.file_exists(project_config_path):
			var file = FileAccess.open(project_config_path, FileAccess.READ)
			if file != null:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var project_config = json.data
					# 合并项目配置
					if project_config.has("embedding_model"):
						ai_config["embedding_model"] = project_config.embedding_model
					if project_config.has("memory"):
						ai_config["memory"] = project_config.memory
					print("从项目配置补充: res://config/ai_config.json")
				file.close()
	
	# 如果还是没有配置，使用默认值
	if ai_config.is_empty():
		print("警告: 未找到配置文件，使用默认配置")
		config = _get_default_config()
		return
	
	# 提取记忆相关配置
	config = {}
	
	# 嵌入模型配置
	if ai_config.has("embedding_model"):
		config["embedding_model"] = ai_config.embedding_model
	else:
		config["embedding_model"] = _get_default_config().embedding_model
	
	# 记忆系统配置
	if ai_config.has("memory"):
		config["memory"] = ai_config.memory
		# 合并retrieval和storage配置
		if ai_config.memory.has("vector_db"):
			config["retrieval"] = {
				"top_k": ai_config.memory.vector_db.get("top_k", 5),
				"min_similarity": ai_config.memory.vector_db.get("min_similarity", 0.3),
				"timeout": ai_config.memory.vector_db.get("timeout", 10.0)
			}
			config["storage"] = {
				"auto_save": ai_config.memory.vector_db.get("auto_save", true),
				"save_interval": ai_config.memory.vector_db.get("save_interval", 300)
			}
	else:
		var defaults = _get_default_config()
		config["memory"] = defaults.memory
		config["retrieval"] = defaults.retrieval
		config["storage"] = defaults.storage
	
	print("记忆配置已加载")



func _get_default_config() -> Dictionary:
	"""获取默认配置"""
	return {
		"embedding_model": {
			"model": "",
			"base_url": "",
			"timeout": 30,
			"vector_dim": 1024,
			"batch_size": 64
		},
		"memory": {
			"max_memory_items": 15,
			"max_conversation_history": 10,
			"max_relationship_history": 2,
			"vector_db": {
				"enable": true,
				"top_k": 5,
				"min_similarity": 0.3,
				"timeout": 10.0,
				"auto_save": true,
				"save_interval": 300,
				"max_items": 1000
			},
			"prompts": {
				"memory_prefix": "这是唤醒的记忆，可以作为参考：\n```\n",
				"memory_suffix": "\n```\n以上是记忆而不是最近的对话，可以不使用。",
				"no_memory": ""
			},
			"storage": {
				"store_conversations": true,
				"store_summaries": true,
				"store_diaries": true,
				"summary_before_storage": false
			}
		},
		"retrieval": {
			"top_k": 5,
			"min_similarity": 0.3,
			"timeout": 10.0
		},
		"storage": {
			"auto_save": true,
			"save_interval": 300
		}
	}

func _setup_auto_save():
	"""设置自动保存定时器"""
	auto_save_timer = Timer.new()
	add_child(auto_save_timer)
	
	var interval = config.storage.get("save_interval", 300)
	auto_save_timer.wait_time = interval
	auto_save_timer.timeout.connect(_on_auto_save)
	auto_save_timer.start()
	
	print("自动保存已启用，间隔: %d 秒" % interval)

func _on_auto_save():
	"""自动保存回调"""
	if memory_system:
		memory_system.save_to_file()
		print("记忆数据已自动保存")

func add_conversation_summary(summary: String, metadata: Dictionary = {}):
	"""添加对话总结到记忆系统
	
	Args:
		summary: 对话总结文本
		metadata: 元数据（可选），如 {"mood": "happy", "affection": 75}
	"""
	if not is_initialized:
		await memory_system_ready
	
	if summary.strip_edges().is_empty():
		return
	
	var storage_config = config.get("storage", {})
	if storage_config.get("store_summaries", true):
		# 只在有实际内容时才传递 metadata
		await memory_system.add_text(summary, "conversation", metadata)
		print("对话总结已添加到向量库")

func add_diary_entry(entry: Dictionary):
	"""添加日记条目到记忆系统
	
	Args:
		entry: 日记条目 {time: String, event: String, type: String (可选)}
	"""
	if not is_initialized:
		await memory_system_ready
	
	var storage_config = config.get("storage", {})
	if storage_config.get("store_diaries", true):
		# 日记文本（add_text 会自动添加当前时间戳）
		var diary_text = entry.event
		
		# metadata 留空，因为时间已经在文本中了
		await memory_system.add_diary_entry(diary_text)
		print("日记条目已添加到向量库")

func get_relevant_memory_for_chat(context: String, exclude_timestamps: Array = []) -> String:
	"""获取与当前对话相关的记忆
	
	Args:
		context: 当前对话上下文
		exclude_timestamps: 要排除的时间戳列表（通常是短期记忆）
	
	Returns:
		格式化的记忆提示词
	"""
	if not is_initialized:
		print("记忆系统未初始化，等待就绪...")
		await memory_system_ready
	
	var retrieval_config = config.get("retrieval", {})
	var top_k = retrieval_config.get("top_k", 5)
	var min_similarity = retrieval_config.get("min_similarity", 0.3)
	var timeout = retrieval_config.get("timeout", 10.0)
	
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
