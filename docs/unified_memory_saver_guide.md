# 统一记忆保存器使用指南

## 概述

`UnifiedMemorySaver` 是一个统一的记忆保存管理器，封装了记忆保存逻辑，一次调用即可同时保存到三个地方：

1. **存档（saves/）** - 短期记忆，保存在存档文件中
2. **日记（diary/）** - 按日期分类的详细记录
3. **向量数据库（长期记忆）** - RAG系统，用于智能检索

## 核心优势

- **统一接口**：一个函数调用完成三处保存
- **类型统一**：日记和长期记忆使用相同的类型系统
- **时间一致**：三处保存使用相同的时间戳
- **简化代码**：减少重复代码，提高可维护性

## 记忆类型

```gdscript
enum MemoryType {
    CHAT,      # 聊天对话
    OFFLINE,   # 离线事件
    GAMES      # 游戏事件
}
```

## 基本用法

### 1. 保存聊天记忆

```gdscript
var unified_saver = get_node("/root/UnifiedMemorySaver")

# 保存对话总结
await unified_saver.save_memory(
    "今天和用户聊了很多有趣的话题",  # 总结内容
    unified_saver.MemoryType.CHAT,     # 类型：聊天
    null,                               # 时间戳（null=当前时间）
    "用户：你好\n角色：你好啊",        # 详细对话（可选）
    {"mood": "happy"}                   # 元数据（可选）
)
```

### 2. 保存离线事件

```gdscript
var unified_saver = get_node("/root/UnifiedMemorySaver")

# 保存离线期间发生的事件
await unified_saver.save_memory(
    "我去了图书馆看书",                # 事件内容
    unified_saver.MemoryType.OFFLINE,  # 类型：离线
    custom_timestamp,                   # 自定义时间戳（Unix时间）
    "",                                 # 对话文本（离线事件不需要）
    {}                                  # 元数据（可选）
)
```

### 3. 保存游戏记录

```gdscript
var unified_saver = get_node("/root/UnifiedMemorySaver")

# 保存游戏结果
await unified_saver.save_memory(
    "我和用户玩了3局五子棋，我赢了，比分2比1",  # 游戏记录
    unified_saver.MemoryType.GAMES,                # 类型：游戏
    null,                                           # 使用当前时间
    "",                                             # 对话文本（不需要）
    {}                                              # 元数据（可选）
)
```

## 完整参数说明

```gdscript
func save_memory(
    content: String,              # 必需：记忆内容（总结文本）
    memory_type: MemoryType,      # 必需：记忆类型
    custom_timestamp = null,      # 可选：自定义时间戳（Unix时间戳）
    conversation_text: String,    # 可选：详细对话文本（仅CHAT类型需要）
    metadata: Dictionary          # 可选：元数据（如心情、好感度等）
) -> void
```

### 参数详解

- **content**: 记忆的核心内容
  - CHAT类型：对话总结
  - OFFLINE类型：事件描述
  - GAMES类型：游戏结果描述

- **memory_type**: 记忆类型，影响保存格式
  - `MemoryType.CHAT`: 聊天对话，会保存详细对话文本
  - `MemoryType.OFFLINE`: 离线事件，简化格式
  - `MemoryType.GAMES`: 游戏事件，简化格式

- **custom_timestamp**: 自定义时间戳
  - `null`: 使用当前时间（推荐）
  - Unix时间戳（float）: 用于断点恢复或历史记录

- **conversation_text**: 详细对话文本
  - 仅CHAT类型需要
  - 格式：`"用户：消息1\n角色：回复1\n用户：消息2\n角色：回复2"`

- **metadata**: 元数据字典
  - 可选的上下文信息
  - 例如：`{"mood": "happy", "affection": 75}`

## 保存位置和格式

### 1. 存档（saves/save_slot_X.json）

```json
{
  "ai_data": {
    "memory": [
      {
        "timestamp": "2025-10-26T14:30:00",
        "content": "今天和用户聊了很多有趣的话题"
      }
    ]
  }
}
```

### 2. 日记（diary/YYYY-MM-DD.jsonl）

#### CHAT类型
```json
{"type":"chat","timestamp":"14:30:00","summary":"今天和用户聊了很多有趣的话题","conversation":"用户：你好\n角色：你好啊"}
```

#### OFFLINE/GAMES类型
```json
{"type":"offline","time":"14:30","event":"我去了图书馆看书"}
{"type":"games","time":"15:45","event":"我和用户玩了3局五子棋，我赢了"}
```

### 3. 向量数据库（memory_main_memory.json）

```json
{
  "memories": [
    {
      "id": "uuid-xxx",
      "text": "今天和用户聊了很多有趣的话题",
      "type": "conversation",
      "timestamp": "2025-10-26T14:30:00",
      "embedding": [0.1, 0.2, ...]
    }
  ]
}
```

## 实际应用示例

### AI服务中的使用

```gdscript
# ai_service.gd
func _save_memory_and_diary(summary: String, conversation_text: String, custom_timestamp = null):
    var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
    if unified_saver:
        await unified_saver.save_memory(
            summary,
            unified_saver.MemoryType.CHAT,
            custom_timestamp,
            conversation_text,
            {}
        )
```

### 离线时间管理器中的使用

```gdscript
# offline_time_manager.gd
func _save_diary_to_memory(time_str: String, event_text: String, _date_str: String):
    var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
    if unified_saver:
        await unified_saver.save_memory(
            event_text,
            unified_saver.MemoryType.OFFLINE,
            null,
            "",
            {}
        )
```

### 游戏中的使用

```gdscript
# gomoku_game.gd
func _save_game_to_diary():
    var diary_content = "我和用户玩了3局五子棋，我赢了，比分2比1"
    
    var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
    if unified_saver:
        await unified_saver.save_memory(
            diary_content,
            unified_saver.MemoryType.GAMES,
            null,
            "",
            {}
        )
```

## 错误处理

统一记忆保存器会自动处理错误情况：

- 如果内容为空，会打印警告并跳过保存
- 如果某个保存位置失败，会打印错误但不影响其他位置
- 如果 MemoryManager 未找到，会跳过向量数据库保存

## 降级方案

如果 `UnifiedMemorySaver` 未加载，现有代码会自动降级到旧的保存逻辑：

```gdscript
var unified_saver = get_node_or_null("/root/UnifiedMemorySaver")
if unified_saver:
    # 使用新的统一保存器
    await unified_saver.save_memory(...)
else:
    # 降级到旧逻辑
    push_warning("UnifiedMemorySaver 未找到，使用旧的保存逻辑")
    # ... 旧的保存代码 ...
```

## 注意事项

1. **异步调用**：`save_memory()` 是异步函数，需要使用 `await`
2. **时间一致性**：三处保存使用相同的时间戳，确保数据一致
3. **类型选择**：根据实际场景选择正确的 MemoryType
4. **元数据可选**：metadata 参数是可选的，不需要时传空字典 `{}`

## 迁移指南

### 从旧代码迁移

**旧代码：**
```gdscript
# 分散的保存逻辑
save_mgr.save_data.ai_data.memory.append(memory_item)
logger.save_to_diary(summary, conversation_text, timestamp)
await memory_mgr.add_conversation_summary(summary, {}, timestamp)
```

**新代码：**
```gdscript
# 统一的保存逻辑
var unified_saver = get_node("/root/UnifiedMemorySaver")
await unified_saver.save_memory(
    summary,
    unified_saver.MemoryType.CHAT,
    custom_timestamp,
    conversation_text,
    {}
)
```

## 总结

统一记忆保存器简化了记忆保存流程，确保数据一致性，并提供了清晰的接口。所有需要保存记忆的地方都应该使用这个统一的接口。
