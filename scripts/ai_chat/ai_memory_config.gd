extends MarginContainer
## 记忆系统配置管理模块
## 处理记忆向量、语义检索、重排序和知识图谱的配置

# 记忆系统配置UI引用
@onready var save_vector_checkbox: CheckBox = $ScrollContainer/VBoxContainer/VectorContainer/SaveVectorCheckBox
@onready var semantic_search_checkbox: CheckBox = $ScrollContainer/VBoxContainer/VectorContainer/SemanticSearchCheckBox
@onready var rerank_checkbox: CheckBox = $ScrollContainer/VBoxContainer/VectorContainer/RerankCheckBox
@onready var save_kg_checkbox: CheckBox = $ScrollContainer/VBoxContainer/KGContainer/SaveKGCheckBox
@onready var kg_search_checkbox: CheckBox = $ScrollContainer/VBoxContainer/KGContainer/KGSearchCheckBox
@onready var save_button: Button = $ScrollContainer/VBoxContainer/SaveArea/MemorySaveButton
@onready var status_label: Label = $ScrollContainer/VBoxContainer/SaveArea/MemoryStatusLabel

var config_manager: Node

func _ready():
	# 连接信号
	save_vector_checkbox.toggled.connect(_on_save_vector_toggled)
	semantic_search_checkbox.toggled.connect(_on_semantic_search_toggled)
	save_kg_checkbox.toggled.connect(_on_save_kg_toggled)
	kg_search_checkbox.toggled.connect(_on_kg_search_toggled)
	save_button.pressed.connect(_on_save_pressed)

	# 加载现有配置
	load_memory_config()

func initialize(config_mgr: Node):
	"""初始化记忆系统配置管理器"""
	config_manager = config_mgr

func _on_save_vector_toggled(enabled: bool):
	"""保存记忆向量勾选框状态改变"""
	if not enabled:
		# 父节点关闭时，子节点也关闭
		semantic_search_checkbox.button_pressed = false
		rerank_checkbox.button_pressed = false

	# 更新子节点可用性
	semantic_search_checkbox.disabled = not enabled
	if not enabled:
		rerank_checkbox.disabled = true
	else:
		rerank_checkbox.disabled = not semantic_search_checkbox.button_pressed

func _on_semantic_search_toggled(enabled: bool):
	"""语义检索勾选框状态改变"""
	if not enabled:
		# 父节点关闭时，子节点也关闭
		rerank_checkbox.button_pressed = false

	# 更新子节点可用性
	rerank_checkbox.disabled = not enabled

func _on_save_kg_toggled(enabled: bool):
	"""保存知识图谱勾选框状态改变"""
	if not enabled:
		# 父节点关闭时，子节点也关闭
		kg_search_checkbox.button_pressed = false

	# 更新子节点可用性
	kg_search_checkbox.disabled = not enabled

func _on_kg_search_toggled(enabled: bool):
	"""图谱检索勾选框状态改变"""
	# 图谱检索没有子节点，不需要特殊处理
	pass

func _on_save_pressed():
	"""保存记忆系统配置"""
	var config = collect_memory_config()

	if config_manager.save_memory_config(config):
		_update_status(true, "配置已保存")
		# 通知记忆系统重新加载配置
		_reload_memory_system()
	else:
		_update_status(false, "保存失败")

func collect_memory_config() -> Dictionary:
	"""收集当前UI中的配置"""
	return {
		"save_memory_vectors": save_vector_checkbox.button_pressed,
		"enable_semantic_search": semantic_search_checkbox.button_pressed,
		"enable_reranking": rerank_checkbox.button_pressed,
		"save_knowledge_graph": save_kg_checkbox.button_pressed,
		"enable_kg_search": kg_search_checkbox.button_pressed
	}

func load_memory_config():
	"""加载记忆系统配置"""
	var config = config_manager.load_memory_config()

	# 设置勾选框状态
	save_vector_checkbox.button_pressed = config.get("save_memory_vectors", true)
	semantic_search_checkbox.button_pressed = config.get("enable_semantic_search", true)
	rerank_checkbox.button_pressed = config.get("enable_reranking", true)
	save_kg_checkbox.button_pressed = config.get("save_knowledge_graph", true)
	kg_search_checkbox.button_pressed = config.get("enable_kg_search", true)

	# 设置初始的禁用状态
	semantic_search_checkbox.disabled = not save_vector_checkbox.button_pressed
	rerank_checkbox.disabled = not (save_vector_checkbox.button_pressed and semantic_search_checkbox.button_pressed)
	kg_search_checkbox.disabled = not save_kg_checkbox.button_pressed

func _update_status(success: bool, message: String):
	"""更新状态标签"""
	if status_label:
		status_label.text = ("✓ " if success else "✗ ") + message
		status_label.add_theme_color_override("font_color",
			Color(0.3, 1.0, 0.3) if success else Color(1.0, 0.3, 0.3))

func _reload_memory_system():
	"""重新加载记忆系统配置"""
	var memory_manager = get_node_or_null("/root/MemoryManager")
	if memory_manager and memory_manager.memory_system:
		memory_manager.memory_system.reload_config()
		print("记忆系统配置已重新加载")
