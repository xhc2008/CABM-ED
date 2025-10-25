extends Node
## RAG系统测试脚本
## 用于验证记忆系统是否正常工作

func _ready():
	print("=== RAG系统测试开始 ===")
	
	# 等待一帧，确保自动加载节点都已就绪
	await get_tree().process_frame
	
	# 测试1: 检查MemoryManager是否存在
	test_memory_manager_exists()
	
	# 测试2: 检查配置是否加载
	test_config_loaded()
	
	# 测试3: 检查MemorySystem是否初始化
	test_memory_system_initialized()
	
	# 测试4: 检查C++插件状态
	test_cosine_calculator()
	
	print("=== RAG系统测试完成 ===")
	print("")
	print("提示：")
	print("1. 如果看到错误，请检查 ai_config.json 中的 embedding_model 配置")
	print("2. 如果看到 'C++插件未加载'，系统会使用GDScript实现（功能相同）")
	print("3. 要使用RAG功能，需要在对话代码中集成（参考 RAG_CHECKLIST.md）")

func test_memory_manager_exists():
	"""测试1: MemoryManager是否存在"""
	print("\n[测试1] 检查MemoryManager...")
	
	if has_node("/root/MemoryManager"):
		print("  ✓ MemoryManager 已加载")
	else:
		print("  ✗ MemoryManager 未找到")
		print("    请检查 project.godot 中的 autoload 配置")

func test_config_loaded():
	"""测试2: 配置是否加载"""
	print("\n[测试2] 检查配置...")
	
	if not has_node("/root/MemoryManager"):
		print("  ⊘ 跳过（MemoryManager不存在）")
		return
	
	var memory_mgr = get_node("/root/MemoryManager")
	
	if memory_mgr.config.is_empty():
		print("  ✗ 配置未加载")
		return
	
	print("  ✓ 配置已加载")
	
	# 检查嵌入模型配置
	if memory_mgr.config.has("embedding_model"):
		var embed = memory_mgr.config.embedding_model
		var model = embed.get("model", "")
		var base_url = embed.get("base_url", "")
		var api_key = embed.get("api_key", "")
		
		print("  嵌入模型配置详情:")
		print("    - 模型: '%s'" % model)
		print("    - URL: '%s'" % base_url)
		print("    - API密钥: %s" % ("已设置" if not api_key.is_empty() else "未设置"))
		
		if model.is_empty() or base_url.is_empty():
			print("  ⚠ 嵌入模型配置不完整（model或base_url为空）")
			print("    请在AI配置窗口的'详细配置'中配置嵌入模型")
		else:
			print("  ✓ 嵌入模型配置完整")
	else:
		print("  ⚠ 配置中没有 embedding_model 字段")

func test_memory_system_initialized():
	"""测试3: MemorySystem是否初始化"""
	print("\n[测试3] 检查MemorySystem...")
	
	if not has_node("/root/MemoryManager"):
		print("  ⊘ 跳过（MemoryManager不存在）")
		return
	
	var memory_mgr = get_node("/root/MemoryManager")
	
	if memory_mgr.is_initialized:
		print("  ✓ MemorySystem 已初始化")
		
		if memory_mgr.memory_system:
			var mem_sys = memory_mgr.memory_system
			print("    - 数据库名称: %s" % mem_sys.db_name)
			print("    - 向量维度: %d" % mem_sys.vector_dim)
			print("    - 记忆数量: %d" % mem_sys.memory_items.size())
	else:
		print("  ⚠ MemorySystem 未初始化")
		print("    等待初始化完成...")

func test_cosine_calculator():
	"""测试4: C++插件状态"""
	print("\n[测试4] 检查C++余弦计算插件...")
	
	if not has_node("/root/MemoryManager"):
		print("  ⊘ 跳过（MemoryManager不存在）")
		return
	
	var memory_mgr = get_node("/root/MemoryManager")
	
	if not memory_mgr.is_initialized:
		print("  ⊘ 跳过（MemorySystem未初始化）")
		return
	
	var mem_sys = memory_mgr.memory_system
	
	if mem_sys.cosine_calculator != null:
		print("  ✓ C++插件已加载（高性能模式）")
	else:
		print("  ℹ C++插件未加载（使用GDScript实现）")
		print("    如需高性能，请编译C++插件")
		print("    参考: addons/cosine_calculator/BUILD.md")
