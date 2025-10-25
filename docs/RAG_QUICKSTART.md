# RAG系统快速开始

## 1. 配置嵌入模型

在 `config/ai_config.json` 中配置你的嵌入模型API：

```json
{
  "embedding_model": {
    "model": "text-embedding-3-small",
    "base_url": "https://api.openai.com/v1",
    "timeout": 30,
    "vector_dim": 1024
  }
}
```

## 2. 启用记忆系统

确保 `memory.vector_db.enable` 为 `true`：

```json
{
  "memory": {
    "vector_db": {
      "enable": true,
      "top_k": 5,
      "min_similarity": 0.3
    }
  }
}
```

## 3. 集成到对话流程

### 方式一：修改现有对话代码

找到你的对话API调用处（可能在 `chat_dialog.gd` 或类似文件），修改提示词构建：

```gdscript
# 原来的代码：
# var system_prompt = prompt_builder.build_system_prompt(trigger_mode)

# 改为：
var system_prompt = await prompt_builder.build_system_prompt_with_long_term_memory(
    trigger_mode,
    user_input  # 用户的输入文本
)
```

### 方式二：在对话结束时保存总结

找到对话结束处理的地方，添加：

```gdscript
# 假设你已经调用总结模型生成了 summary
var memory_mgr = get_node("/root/MemoryManager")
await memory_mgr.add_conversation_summary(summary)
```

## 4. 保存日记到向量库

在离线日记生成后，添加：

```gdscript
var memory_mgr = get_node("/root/MemoryManager")

for entry in diary_entries:
    await memory_mgr.add_diary_entry(entry)
```

## 5. 测试

运行游戏，进行几轮对话，然后：

1. 检查向量库文件是否生成：`user://memory_main_memory.json`
2. 查看控制台日志，应该看到：
   - "记忆系统初始化完成"
   - "添加记忆: [conversation] ..."
   - "检索到 N 条相关记忆"

## 常见问题

### Q: 看到"GDExtension dynamic library not found"错误？
A: 
- 这是C++插件的错误，不影响RAG功能
- 系统会自动使用GDScript实现
- 如需高性能，参考 `addons/cosine_calculator/BUILD.md` 编译插件
- 如果已编译，确保 `src/.gdignore` 文件存在

### Q: 嵌入API调用失败？
A: 检查 `base_url` 和 `model` 配置是否正确，确保API可访问。

### Q: 没有检索到记忆？
A: 
- 确保已经保存了一些对话总结或日记
- 降低 `min_similarity` 阈值（如 0.2）
- 检查向量维度是否一致

### Q: 性能问题？
A: 
- 编译C++插件可提升10-50倍性能（可选）
- 限制 `max_items` 数量
- 增加 `min_similarity` 阈值减少检索结果

## 下一步

- 阅读完整文档：`docs/RAG_SYSTEM.md`
- 查看集成示例：`scripts/rag_integration_example.gd`
- 自定义记忆提示词模板
- 调整检索参数优化效果
