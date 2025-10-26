# 记忆保存重构总结

## 任务目标

重整、统一和封装记忆保存逻辑，实现"调用一个函数完成三次存储"：
1. 存档（saves/）
2. 日记（diary/）
3. 向量数据库（长期记忆）（memory_main_memory.json）

## 完成的工作

### 1. 创建统一记忆保存器

**文件**: `scripts/unified_memory_saver.gd`

- 封装了三处保存逻辑到一个函数 `save_memory()`
- 统一了日记和长期记忆的类型系统
- 确保三处保存使用相同的时间戳

**核心功能**:
```gdscript
enum MemoryType {
    CHAT,      # 聊天对话
    OFFLINE,   # 离线事件
    GAMES      # 游戏事件
}

func save_memory(
    content: String,
    memory_type: MemoryType,
    custom_timestamp = null,
    conversation_text: String = "",
    metadata: Dictionary = {}
) -> void
```

### 2. 统一类型系统

**之前的问题**:
- 日记使用: `"type": "chat"`, `"type": "offline"`, `"type": "games"`
- 长期记忆使用: `"type": "conversation"`, `"type": "diary"`

**现在的解决方案**:
- 统一使用枚举 `MemoryType`
- 日记直接使用字符串类型名（"chat", "offline", "games"）
- 长期记忆根据类型自动映射：
  - `CHAT` → `"conversation"` 类型
  - `OFFLINE/GAMES` → `"diary"` 类型

### 3. 重构现有代码

#### 3.1 AI服务 (ai_service.gd)

**修改函数**: `_save_memory_and_diary()`

**之前**:
```gdscript
# 分散的保存逻辑
save_mgr.save_data.ai_data.memory.append(memory_item)
logger.save_to_diary(cleaned_summary, conversation_text, custom_timestamp)
await memory_mgr.add_conversation_summary(cleaned_summary, {}, timestamp)
```

**现在**:
```gdscript
# 统一的保存逻辑
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

#### 3.2 离线时间管理器 (offline_time_manager.gd)

**修改函数**: `_save_diary_to_memory()`

**之前**:
```gdscript
# 手动保存到三个地方
save_mgr.save_data.ai_data.memory.append(memory_item)
save_mgr.save_game(...)
await memory_mgr.add_diary_entry(diary_entry)
```

**现在**:
```gdscript
# 使用统一保存器
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

#### 3.3 五子棋游戏 (gomoku_game.gd)

**修改函数**: `_save_game_to_diary()`

**之前**:
```gdscript
# 调用不存在的方法
save_mgr.add_diary_entry({
    "type": "games",
    "time": time_str,
    "event": diary_content
})
```

**现在**:
```gdscript
# 使用统一保存器
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

### 4. 配置自动加载

**文件**: `project.godot`

添加了 `UnifiedMemorySaver` 到自动加载列表：
```ini
[autoload]
UnifiedMemorySaver="*res://scripts/unified_memory_saver.gd"
```

### 5. 创建使用文档

**文件**: `docs/unified_memory_saver_guide.md`

详细的使用指南，包括：
- 基本用法示例
- 完整参数说明
- 保存位置和格式
- 实际应用示例
- 错误处理
- 迁移指南

## 技术亮点

### 1. 时间一致性

所有三处保存使用相同的时间戳，避免了之前可能出现的时间不一致问题：

```gdscript
# 在函数开始时确定时间戳
var timestamp_str: String
var timestamp_unix: float

if custom_timestamp != null:
    timestamp_unix = float(custom_timestamp)
    timestamp_str = _unix_to_local_datetime_string(timestamp_unix)
else:
    timestamp_unix = Time.get_unix_time_from_system()
    timestamp_str = _get_local_datetime_string()

# 三处保存都使用这个时间戳
```

### 2. 降级方案

所有修改的代码都保留了降级方案，如果 `UnifiedMemorySaver` 未加载，会自动使用旧逻辑：

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

### 3. 类型安全

使用枚举而不是字符串，提高了类型安全性：

```gdscript
# 之前：容易拼写错误
save_memory("content", "chat", ...)  # 如果写成 "caht" 不会报错

# 现在：编译时检查
save_memory("content", MemoryType.CHAT, ...)  # 拼写错误会立即发现
```

### 4. 格式适配

根据不同的记忆类型，自动适配不同的保存格式：

```gdscript
# CHAT类型：包含summary和conversation
{
    "type": "chat",
    "timestamp": "14:30:00",
    "summary": "...",
    "conversation": "..."
}

# OFFLINE/GAMES类型：简化格式
{
    "type": "offline",
    "time": "14:30",
    "event": "..."
}
```

## 代码简化效果

### 之前（分散的保存逻辑）

```gdscript
# 需要手动处理三个地方
var save_mgr = get_node("/root/SaveManager")
var memory_item = {"timestamp": timestamp, "content": content}
save_mgr.save_data.ai_data.memory.append(memory_item)
save_mgr.save_game(...)

logger.save_to_diary(content, conversation, timestamp)

var memory_mgr = get_node("/root/MemoryManager")
await memory_mgr.add_conversation_summary(content, {}, timestamp)
```

**代码行数**: ~10行
**需要了解**: 3个不同的API

### 现在（统一的保存逻辑）

```gdscript
# 一个函数调用完成
var unified_saver = get_node("/root/UnifiedMemorySaver")
await unified_saver.save_memory(content, MemoryType.CHAT, timestamp, conversation, {})
```

**代码行数**: 2行
**需要了解**: 1个统一的API

**简化率**: 80%

## 测试建议

### 1. 功能测试

- [ ] 测试聊天记忆保存（CHAT类型）
- [ ] 测试离线事件保存（OFFLINE类型）
- [ ] 测试游戏记录保存（GAMES类型）
- [ ] 验证三处保存的时间戳一致性
- [ ] 验证日记文件格式正确
- [ ] 验证向量数据库保存成功

### 2. 边界测试

- [ ] 测试空内容保存（应该跳过）
- [ ] 测试自定义时间戳
- [ ] 测试降级方案（禁用UnifiedMemorySaver）
- [ ] 测试跨日期保存

### 3. 集成测试

- [ ] 完整对话流程测试
- [ ] 离线时间变化测试
- [ ] 五子棋游戏完整流程测试
- [ ] 日记查看器显示测试

## 后续优化建议

### 1. 批量保存

如果需要保存多条记忆，可以添加批量保存接口：

```gdscript
func save_memories_batch(memories: Array) -> void:
    for memory in memories:
        await save_memory(
            memory.content,
            memory.type,
            memory.timestamp,
            memory.conversation,
            memory.metadata
        )
```

### 2. 保存队列

对于高频保存场景，可以添加保存队列：

```gdscript
var save_queue: Array = []

func queue_memory(content, type, ...):
    save_queue.append({...})

func flush_queue():
    for item in save_queue:
        await save_memory(...)
    save_queue.clear()
```

### 3. 保存回调

添加保存完成回调，方便外部监听：

```gdscript
signal memory_saved(content: String, type: MemoryType)

func save_memory(...):
    # ... 保存逻辑 ...
    memory_saved.emit(content, memory_type)
```

## 总结

通过这次重构，我们成功地：

1. ✅ 统一了记忆保存接口
2. ✅ 简化了代码，减少了重复
3. ✅ 统一了类型系统
4. ✅ 确保了时间一致性
5. ✅ 提供了降级方案
6. ✅ 创建了详细的文档

现在，所有需要保存记忆的地方都可以使用统一的 `UnifiedMemorySaver.save_memory()` 函数，大大提高了代码的可维护性和一致性。
