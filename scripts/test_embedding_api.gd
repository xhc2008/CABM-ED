extends Node
## 嵌入API测试脚本
## 用于调试401错误

func _ready():
	print("=== 嵌入API测试 ===")
	await get_tree().process_frame
	
	# 测试配置
	await test_config()
	
	# 测试API调用
	await test_api_call()

func test_config():
	"""测试配置是否正确加载"""
	print("\n[测试1] 检查配置...")
	
	if not has_node("/root/MemoryManager"):
		print("  ✗ MemoryManager未加载")
		return
	
	var memory_mgr = get_node("/root/MemoryManager")
	
	if not memory_mgr.is_initialized:
		print("  等待初始化...")
		await memory_mgr.memory_system_ready
	
	var config = memory_mgr.config
	
	if not config.has("embedding_model"):
		print("  ✗ 配置中没有embedding_model")
		return
	
	var embed = config.embedding_model
	var model = embed.get("model", "")
	var base_url = embed.get("base_url", "")
	var api_key = embed.get("api_key", "")
	
	print("  配置详情:")
	print("    模型: '%s'" % model)
	print("    URL: '%s'" % base_url)
	print("    API密钥: %s" % ("已设置 (%d字符)" % api_key.length() if not api_key.is_empty() else "未设置"))
	
	if api_key.length() > 10:
		print("    密钥前缀: %s..." % api_key.substr(0, 10))
	
	if model.is_empty() or base_url.is_empty() or api_key.is_empty():
		print("  ⚠️ 配置不完整")
	else:
		print("  ✓ 配置完整")

func test_api_call():
	"""测试实际的API调用"""
	print("\n[测试2] 测试API调用...")
	
	if not has_node("/root/MemoryManager"):
		print("  ⊘ 跳过（MemoryManager不存在）")
		return
	
	var memory_mgr = get_node("/root/MemoryManager")
	
	if not memory_mgr.is_initialized:
		await memory_mgr.memory_system_ready
	
	var mem_sys = memory_mgr.memory_system
	
	print("  调用嵌入API...")
	print("  测试文本: '这是一个测试'")
	
	var vector = await mem_sys.get_embedding("这是一个测试")
	
	if vector.is_empty():
		print("  ✗ 获取向量失败")
		print("\n  请检查上面的错误信息")
	else:
		print("  ✓ 获取向量成功")
		print("    向量维度: %d" % vector.size())
		print("    前5个值: %s" % str(vector.slice(0, 5)))

func _exit_tree():
	print("\n=== 测试完成 ===")
	print("\n如果看到401错误，请检查：")
	print("1. API密钥是否正确（在AI配置窗口重新保存）")
	print("2. API密钥是否有权限访问嵌入模型")
	print("3. Base URL是否正确（应该以/v1结尾）")
	print("4. 模型名称是否正确")
