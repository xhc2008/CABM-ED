# 记忆格式更新说明

## 更新内容

### 1. 所有记忆都包含时间戳 ✅

**之前：**
- conversation: `"前天的事？我似乎有些模糊..."`
- diary: `"[10-25 10:08] 我仔细整理了reeper的床铺..."`

**现在：**
- conversation: `"[10-25 10:16] 前天的事？我似乎有些模糊..."`
- diary: `"[10-25 10:08] 我仔细整理了reeper的床铺..."`

**优点：**
- 统一格式，便于查看和检索
- 时间信息直接嵌入文本，搜索时更准确
- 向量化时包含时间上下文

### 2. Metadata 元数据系统 ✅

**设计原则：**
- 默认为空（时间信息已在文本中）
- 仅在需要存储额外结构化信息时使用
- 可选功能，不影响核心功能

**可能的用途（未来扩展）：**
```json
{
  "mood": "happy",
  "affection": 75,
  "tags": ["重要", "开心"],
  "related_event_id": "event_123"
}
```

**当前实现：**
- 大多数情况下 metadata 为空 `{}`
- 保留扩展性，便于未来添加功能

## 数据结构示例

### 完整的记忆条目

```json
{
  "db_name": "main_memory",
  "vector_dim": 1024,
  "count": 3,
  "texts": [
    {
      "text": "[10-25 10:16] 前天的事？我似乎有些模糊，但你的记忆比我更清晰呢。",
      "timestamp": "2025-10-25T10:16:45",
      "type": "conversation",
      "metadata": {}
    },
    {
      "text": "[10-25 10:20] 我感到一丝不安，却也释然——或许遗忘是另一种保护。",
      "timestamp": "2025-10-25T10:20:41",
      "type": "conversation",
      "metadata": {}
    },
    {
      "text": "[10-25 10:08] 我仔细整理了reeper的床铺，把枕头拍得蓬松柔软，想象着他晚上回来能睡得更舒服。",
      "timestamp": "2025-10-25T10:21:55",
      "type": "diary",
      "metadata": {}
    }
  ],
  "vectors": [
    [0.123, 0.456, ...],  // 对应第一条 conversation
    [0.789, 0.012, ...],  // 对应第二条 conversation
    [0.345, 0.678, ...]   // 对应 diary
  ]
}
```

## Metadata 字段说明

### 当前实现
- 默认为空对象 `{}`
- 所有必要信息（时间、文本）都在主字段中
- 保留扩展性，便于未来添加功能

### 未来可能的扩展
- `mood`: 心情状态
- `affection`: 好感度
- `tags`: 标签数组
- `importance`: 重要程度
- `related_ids`: 关联事件ID

## 使用示例

### 添加 Conversation
```gdscript
var memory_mgr = get_node("/root/MemoryManager")

# 自动添加时间戳和 metadata
await memory_mgr.add_conversation_summary(
    "今天学习了 GDScript",
    {
        "mood": "happy",
        "affection": 80,
        "conversation_length": 256
    }
)
```

### 添加 Diary
```gdscript
var diary_entry = {
    "time": "10-25 14:30",
    "event": "去了图书馆看书",
    "type": "offline"
}

await memory_mgr.add_diary_entry(diary_entry)
```

### 搜索时利用 Metadata
```gdscript
var results = await memory_system.search("学习", 5, 0.3)

for result in results:
    print("文本: %s" % result.text)
    print("类型: %s" % result.type)
    
    # 访问 metadata（需要从 memory_items 获取）
    var item = memory_system.memory_items[result.index]
    if item.metadata.has("mood"):
        print("当时心情: %s" % item.metadata.mood)
    if item.metadata.has("affection"):
        print("当时好感度: %d" % item.metadata.affection)
```

## 时间格式说明

### 显示格式（文本中）
- 格式：`MM-DD HH:MM`
- 示例：`10-25 10:16`
- 用途：嵌入文本，便于阅读

### 存储格式（timestamp 字段）
- 格式：ISO 8601 `YYYY-MM-DDTHH:MM:SS`
- 示例：`2025-10-25T10:16:45`
- 用途：精确记录，便于排序和计算

### Unix 时间戳（metadata 中）
- 格式：浮点数秒数
- 示例：`1729843005.0`
- 用途：精确计算时间差

## 向后兼容

### 旧数据自动升级
- 系统会自动识别旧格式（没有时间戳的 conversation）
- 加载时正常工作
- 下次保存时自动转换为新格式

### 旧格式示例
```json
{
  "items": [
    {
      "text": "前天的事？我似乎有些模糊...",
      "vector": [...],
      "timestamp": "2025-10-25T10:16:45",
      "type": "conversation",
      "metadata": {}
    }
  ]
}
```

## 优势总结

### 1. 统一性
- 所有记忆都有时间标记
- 格式一致，易于处理

### 2. 可读性
- 文本中直接显示时间
- 便于调试和查看

### 3. 可扩展性
- Metadata 可以存储任意信息
- 不影响现有功能
- 便于未来添加新特性

### 4. 检索准确性
- 时间信息参与向量化
- 搜索时考虑时间上下文
- 更准确的语义匹配

## 注意事项

1. **时间戳自动添加**：调用 `add_text()` 时会自动添加当前时间
2. **原始文本保留**：`metadata.original_text` 保存不带时间戳的原文
3. **Metadata 可选**：不传 metadata 也能正常工作
4. **向量基于完整文本**：包含时间戳的文本用于生成向量

## 测试

运行快速测试查看新格式：
```bash
godot --headless --script scripts/quick_memory_test.gd
```

查看测试页面：
```bash
godot scenes/test_memory.tscn
```
