extends Control
## 记忆系统测试页面

var memory_system: Node = null
var config: Dictionary = {}

@onready var text_input = $VBoxContainer/AddSection/HBoxContainer/TextInput
@onready var type_option = $VBoxContainer/AddSection/HBoxContainer/TypeOption
@onready var add_button = $VBoxContainer/AddSection/HBoxContainer/AddButton
@onready var query_input = $VBoxContainer/SearchSection/HBoxContainer/QueryInput
@onready var top_k_spin = $VBoxContainer/SearchSection/HBoxContainer/TopKSpin
@onready var search_button = $VBoxContainer/SearchSection/HBoxContainer/SearchButton
@onready var results_text = $VBoxContainer/ResultsSection/ResultsText
@onready var status_label = $VBoxContainer/ActionsSection/StatusLabel
@onready var view_db_button = $VBoxContainer/ActionsSection/ViewDBButton
@onready var clear_button = $VBoxContainer/ActionsSection/ClearButton
@onready var save_button = $VBoxContainer/ActionsSection/SaveButton
@onready var back_button = $VBoxContainer/ActionsSection/BackButton

func _ready():
	# 连接信号
	add_button.pressed.connect(_on_add_button_pressed)
	search_button.pressed.connect(_on_search_button_pressed)
	view_db_button.pressed.connect(_on_view_db_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# 回车键快捷操作
	text_input.text_submitted.connect(func(_text): _on_add_button_pressed())
	query_input.text_submitted.connect(func(_text): _on_search_button_pressed())
	
	# 初始化记忆系统
	_initialize_memory_system()

func _input(event):
	"""处理快捷键"""
	if event is InputEventKey and event.pressed:
		# Ctrl+S 保存
		if event.keycode == KEY_S and event.ctrl_pressed:
			_on_save_button_pressed()
			accept_event()
		# Ctrl+R 刷新视图
		elif event.keycode == KEY_R and event.ctrl_pressed:
			_update_database_view()
			accept_event()
		# ESC 关闭
		elif event.keycode == KEY_ESCAPE:
			_on_back_button_pressed()
			accept_event()

func _initialize_memory_system():
	"""初始化记忆系统"""
	status_label.text = "正在初始化..."
	
	# 加载配置
	_load_config()
	
	# 创建记忆系统实例
	var memory_script = load("res://scripts/memory_system.gd")
	memory_system = memory_script.new()
	add_child(memory_system)
	
	# 使用主数据库（调试终端直接操作主数据库）
	memory_system.initialize(config, "main_memory")
	
	status_label.text = "就绪 - 已加载 %d 条记忆 [主数据库]" % memory_system.memory_items.size()
	
	# 显示当前数据库内容
	_update_database_view()
	
	# 显示当前数据库内容
	_update_database_view()

func _load_config():
	"""加载配置"""
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
			file.close()
	
	# 补充项目配置
	if not ai_config.has("embedding_model") or ai_config.embedding_model.get("model", "").is_empty():
		if FileAccess.file_exists(project_config_path):
			var file = FileAccess.open(project_config_path, FileAccess.READ)
			if file != null:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var project_config = json.data
					if project_config.has("embedding_model"):
						ai_config["embedding_model"] = project_config.embedding_model
					if project_config.has("memory"):
						ai_config["memory"] = project_config.memory
				file.close()
	
	config = ai_config

func _on_add_button_pressed():
	"""添加记忆按钮"""
	var text = text_input.text.strip_edges()
	
	if text.is_empty():
		status_label.text = "错误：文本不能为空"
		return
	
	var item_type = "conversation" if type_option.selected == 0 else "diary"
	
	status_label.text = "正在添加..."
	add_button.disabled = true
	
	# 异步添加
	await memory_system.add_text(text, item_type)
	
	add_button.disabled = false
	text_input.text = ""
	status_label.text = "添加成功 - 共 %d 条记忆" % memory_system.memory_items.size()
	
	# 更新显示
	_update_database_view()

func _on_search_button_pressed():
	"""搜索按钮"""
	var query = query_input.text.strip_edges()
	
	if query.is_empty():
		status_label.text = "错误：查询不能为空"
		return
	
	var top_k = int(top_k_spin.value)
	
	status_label.text = "正在搜索..."
	search_button.disabled = true
	results_text.text = "搜索中...\n"
	
	# 异步搜索
	var results = await memory_system.search(query, top_k, 0.0)
	
	search_button.disabled = false
	
	if results.is_empty():
		results_text.text = "未找到相关记忆"
		status_label.text = "搜索完成 - 无结果"
		return
	
	# 格式化结果
	var output = "找到 %d 条相关记忆：\n\n" % results.size()
	
	for i in range(results.size()):
		var result = results[i]
		output += "【%d】相似度: %.3f | 类型: %s\n" % [i + 1, result.similarity, result.type]
		output += "时间: %s\n" % result.timestamp
		output += "内容: %s\n" % result.text
		output += "---\n\n"
	
	results_text.text = output
	status_label.text = "搜索完成 - 找到 %d 条" % results.size()

func _on_view_db_button_pressed():
	"""查看数据库按钮"""
	_update_database_view()

func _update_database_view():
	"""更新数据库视图"""
	if memory_system.memory_items.is_empty():
		results_text.text = "数据库为空\n\n提示：这是主数据库，添加的记忆会直接保存到游戏中。"
		return
	
	var output = "=== 主数据库内容（共 %d 条）===\n\n" % memory_system.memory_items.size()
	
	# 统计信息
	var conversation_count = 0
	var diary_count = 0
	for item in memory_system.memory_items:
		if item.type == "conversation":
			conversation_count += 1
		elif item.type == "diary":
			diary_count += 1
	
	output += "📊 统计：对话 %d 条 | 日记 %d 条\n" % [conversation_count, diary_count]
	output += "📁 文件：user://memory_main_memory.json\n"
	output += "---\n\n"
	
	# 显示最近的10条
	var display_count = min(10, memory_system.memory_items.size())
	var start_index = memory_system.memory_items.size() - display_count
	
	output += "最近 %d 条记忆：\n\n" % display_count
	
	for i in range(start_index, memory_system.memory_items.size()):
		var item = memory_system.memory_items[i]
		var icon = "💬" if item.type == "conversation" else "📔"
		output += "%s【%d】%s\n" % [icon, i + 1, item.timestamp]
		output += "  %s\n" % item.text
		output += "  向量: %d 维" % item.vector.size()
		if not item.metadata.is_empty():
			output += " | 元数据: %s" % JSON.stringify(item.metadata)
		output += "\n\n"
	
	if memory_system.memory_items.size() > 10:
		output += "（仅显示最近10条，共 %d 条）\n" % memory_system.memory_items.size()
	
	results_text.text = output
	status_label.text = "主数据库：%d 条记忆" % memory_system.memory_items.size()

func _on_clear_button_pressed():
	"""清空数据库按钮"""
	# 确认对话框
	var confirm = ConfirmationDialog.new()
	add_child(confirm)
	confirm.dialog_text = "⚠️ 警告：这将清空主数据库的所有记忆！\n\n当前有 %d 条记忆\n\n此操作不可撤销，确定要继续吗？" % memory_system.memory_items.size()
	confirm.title = "清空数据库"
	confirm.confirmed.connect(_do_clear_database.bind(confirm))
	confirm.canceled.connect(func(): confirm.queue_free())
	confirm.popup_centered()

func _do_clear_database(confirm: ConfirmationDialog):
	"""执行清空数据库"""
	memory_system.clear()
	memory_system.save_to_file()
	
	results_text.text = "数据库已清空"
	status_label.text = "数据库已清空"
	
	confirm.queue_free()

func _on_save_button_pressed():
	"""保存按钮"""
	if memory_system:
		memory_system.save_to_file()
		status_label.text = "已保存 - %d 条记忆" % memory_system.memory_items.size()
		print("✓ 记忆数据已手动保存")

func _on_back_button_pressed():
	"""关闭按钮"""
	# 自动保存
	if memory_system:
		memory_system.save_to_file()
		print("✓ 记忆数据已保存")
	
	# 关闭窗口
	get_tree().quit()
