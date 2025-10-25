extends Node
## RAG集成示例
## 展示如何在对话流程中使用长期记忆系统

# 这个脚本展示了如何集成RAG系统到对话流程中
# 实际使用时，应该在 chat_dialog.gd 或 API 调用脚本中集成

func example_chat_with_long_term_memory(user_input: String, trigger_mode: String = "user_initiated"):
	"""示例：带长期记忆的对话流程"""
	
	# 1. 使用PromptBuilder构建包含长期记忆的提示词
	var prompt_builder = get_node("/root/PromptBuilder")
	var system_prompt = await prompt_builder.build_system_prompt_with_long_term_memory(trigger_mode, user_input)
	
	# 2. 构建完整的消息列表（包括对话历史）
	var messages = _build_messages(system_prompt, user_input)
	
	# 3. 调用API（这里只是示例，实际应该调用你的API管理器）
	# var response = await call_chat_api(messages)
	
	# 4. 对话结束后，保存总结到向量库
	# await _save_conversation_to_vector_db(user_input, response)
	
	print("对话流程完成（示例）")

func _build_messages(system_prompt: String, user_input: String) -> Array:
	"""构建消息列表"""
	var messages = []
	
	# 添加系统提示词
	messages.append({
		"role": "system",
		"content": system_prompt
	})
	
	# 添加对话历史（从SaveManager获取）
	var save_mgr = get_node("/root/SaveManager")
	var history = save_mgr.get_conversation_history()
	
	# 只取最近N轮对话
	var max_history = 10
	var start_idx = max(0, history.size() - max_history)
	
	for i in range(start_idx, history.size()):
		var turn = history[i]
		messages.append({"role": "user", "content": turn.user})
		messages.append({"role": "assistant", "content": turn.assistant})
	
	# 添加当前用户输入
	messages.append({
		"role": "user",
		"content": user_input
	})
	
	return messages

func _save_conversation_to_vector_db(user_input: String, assistant_response: String):
	"""保存对话总结到向量库"""
	
	# 1. 调用总结模型生成总结（如果配置了）
	var summary = await _generate_summary(user_input, assistant_response)
	
	# 2. 保存到向量库
	if not summary.is_empty():
		var memory_mgr = get_node("/root/MemoryManager")
		await memory_mgr.add_conversation_summary(summary)

func _generate_summary(user_input: String, assistant_response: String) -> String:
	"""生成对话总结（调用总结模型）"""
	# 这里应该调用你的总结模型API
	# 返回总结文本
	return ""

# ============================================
# 离线日记的向量化存储示例
# ============================================

func example_save_diary_to_vector_db(diary_entries: Array):
	"""示例：保存离线日记到向量库
	
	Args:
		diary_entries: 日记条目数组 [{time: String, event: String}, ...]
	"""
	var memory_mgr = get_node("/root/MemoryManager")
	
	for entry in diary_entries:
		await memory_mgr.add_diary_entry(entry)
	
	print("日记已保存到向量库: %d 条" % diary_entries.size())

# ============================================
# 手动保存和加载向量库
# ============================================

func example_manual_save():
	"""示例：手动保存向量库"""
	var memory_mgr = get_node("/root/MemoryManager")
	memory_mgr.save()
	print("向量库已手动保存")

func example_search_memory(query: String):
	"""示例：搜索记忆"""
	var memory_mgr = get_node("/root/MemoryManager")
	var memory_prompt = await memory_mgr.get_relevant_memory_for_chat(query)
	
	print("检索结果:")
	print(memory_prompt)
