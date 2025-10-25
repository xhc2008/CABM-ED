# RAG长期记忆系统

## 概述

RAG（Retrieval-Augmented Generation）系统为AI角色提供长期记忆能力，通过向量数据库存储和检索对话总结与日记，让角色能够记住更久远的事情。

## 系统架构

```
┌─────────────────┐
│  用户输入       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  PromptBuilder          │
│  - 检索相关记忆         │
│  - 构建完整提示词       │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  MemoryManager          │
│  - 管理记忆系统         │
│  - 自动保存             │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  MemorySystem           │
│  - 向量存储             │
│  - 相似度检索           │
│  - 调用嵌入API          │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  CosineCalculator (C++) │
│  - 高性能余弦相似度计算 │
└─────────────────────────┘
```

## 配置

### 1. 嵌入模型配置

在 `config/ai_config.json` 中配置嵌入模型：

```json
{
  "embedding_model": {
    "model": "text-embedding-3-small",
    "base_url": "https://api.openai.com/v1",
    "timeout": 30,
    "vector_dim": 1024,
    "batch_size": 64
  }
}
```

### 2. 记忆系统配置

```json
{
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
  }
}
```

### 3. 提示词框架配置

在 `prompt_frameworks.chat` 中添加长期记忆字段：

```json
{
  "prompt_frameworks": {
    "chat": [
      {
        "title": "身份",
        "field": "identity"
      },
      {
        "title": "长期记忆",
        "field": "long_term_memory"
      },
      {
        "title": "之前发生的事情",
        "field": "memory"
      }
    ]
  },
  "prompt_fields": {
    "long_term_memory": "{long_term_memory}"
  }
}
```

## 使用方法

### 1. 对话时自动检索记忆

在对话流程中使用 `PromptBuilder.build_system_prompt_with_long_term_memory()`：

```gdscript
# 在 chat_dialog.gd 或 API 调用处
var prompt_builder = get_node("/root/PromptBuilder")
var user_input = "今天天气真好"

# 构建包含长期记忆的提示词
var system_prompt = await prompt_builder.build_system_prompt_with_long_term_memory(
    "user_initiated",  # 触发模式
    user_input         # 用户输入，用于检索相关记忆
)

# 使用 system_prompt 调用 API
```

### 2. 保存对话总结到向量库

对话结束后，保存总结：

```gdscript
# 在对话结束处理中
var memory_mgr = get_node("/root/MemoryManager")

# 假设你已经生成了对话总结
var summary = "用户和角色讨论了今天的天气，角色表示很喜欢晴天。"

# 保存到向量库
await memory_mgr.add_conversation_summary(summary)
```

### 3. 保存日记到向量库

离线日记生成后，保存到向量库：

```gdscript
var memory_mgr = get_node("/root/MemoryManager")

# 日记条目
var diary_entry = {
    "time": "10-25 14:30",
    "event": "下午在客厅看了一会儿书，感觉很放松。"
}

# 保存到向量库
await memory_mgr.add_diary_entry(diary_entry)
```

### 4. 手动搜索记忆

```gdscript
var memory_mgr = get_node("/root/MemoryManager")

# 搜索相关记忆
var query = "天气"
var memory_prompt = await memory_mgr.get_relevant_memory_for_chat(query)

print(memory_prompt)
# 输出：
# 这是唤醒的记忆，可以作为参考：
# ```
# 用户和角色讨论了今天的天气，角色表示很喜欢晴天。
# [10-25 14:30] 下午在客厅看了一会儿书，感觉很放松。
# ```
# 以上是记忆而不是最近的对话，可以不使用。
```

## 数据存储

### 存储位置

向量数据库保存在：
- `user://memory_main_memory.json`

### 数据结构

```json
{
  "db_name": "main_memory",
  "vector_dim": 1024,
  "last_updated": "2025-10-25T14:30:00",
  "items": [
    {
      "text": "用户和角色讨论了今天的天气...",
      "vector": [0.123, 0.456, ...],
      "timestamp": "2025-10-25T14:30:00",
      "type": "conversation",
      "metadata": {}
    }
  ]
}
```

## 性能优化

### C++余弦相似度计算

使用 `CosineCalculator` GDExtension 插件进行高性能计算：

- 相比 GDScript 实现，性能提升 10-50 倍
- 支持批量计算
- 自动降级到 GDScript 实现（如果插件未加载）

### 自动保存

- 默认每 5 分钟自动保存一次
- 退出时自动保存
- 可配置保存间隔

## 工作流程

### 对话流程

```
1. 用户输入
   ↓
2. 用户输入 → 嵌入API → 查询向量
   ↓
3. 查询向量 × 所有记忆向量 → 相似度分数
   ↓
4. 筛选 top_k 个最相关记忆
   ↓
5. 格式化为提示词
   ↓
6. 构建完整提示词（包含长期记忆）
   ↓
7. 调用对话API
   ↓
8. 对话结束 → 生成总结 → 保存到向量库
```

### 日记流程

```
1. 离线时间结束
   ↓
2. 生成日记条目
   ↓
3. 保存到日记系统
   ↓
4. 日记文本 → 嵌入API → 向量
   ↓
5. 保存到向量库
```

## 注意事项

1. **嵌入API调用是异步的**：所有涉及向量化的操作都需要 `await`
2. **向量维度必须一致**：确保所有向量使用相同的嵌入模型
3. **相似度阈值**：`min_similarity` 建议设置为 0.3-0.5
4. **记忆数量限制**：建议设置 `max_items` 避免数据库过大
5. **自动保存**：确保启用自动保存，避免数据丢失

## 调试

### 查看检索结果

```gdscript
# 在 MemorySystem 中已经有日志输出
# 检索时会打印：
# "检索到 N 条相关记忆"
```

### 查看向量库状态

```gdscript
var memory_mgr = get_node("/root/MemoryManager")
var memory_system = memory_mgr.memory_system

print("记忆数量: ", memory_system.memory_items.size())
print("向量维度: ", memory_system.vector_dim)
```

## 扩展

### 自定义记忆类型

可以添加更多记忆类型：

```gdscript
# 添加事件记忆
await memory_system.add_text("角色完成了一个重要任务", "event")

# 添加情感记忆
await memory_system.add_text("角色感到非常开心", "emotion")
```

### 自定义检索策略

可以修改 `MemorySystem.search()` 实现不同的检索策略：
- 时间衰减
- 类型过滤
- 重排序

## 参考

- `scripts/memory_system.gd` - 核心向量存储和检索
- `scripts/memory_manager.gd` - 记忆管理器
- `scripts/prompt_builder.gd` - 提示词构建
- `scripts/rag_integration_example.gd` - 集成示例
- `addons/cosine_calculator/` - C++余弦计算插件
