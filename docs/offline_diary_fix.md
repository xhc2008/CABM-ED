# 离线日记重复保存问题修复

## 问题描述

在重构记忆保存逻辑时，发现 `offline_time_manager.gd` 中的离线日记被重复保存了两次，而且两次保存的时间戳不一致。

### 问题原因

**旧的逻辑流程**:
```
_save_diary_entry(time_str, event_text, ...)
  ├─ 手动保存到日记文件（使用 time_str）
  └─ 调用 _save_diary_to_memory(time_str, event_text, ...)
      └─ 使用统一保存器再次保存（使用当前时间 null）
```

这导致：
1. 日记文件中有两条相同的记录
2. 第一条使用 AI 生成的时间（如 "14:30"）
3. 第二条使用当前实际时间（如 "15:45"）

## 修复方案

### 1. 重构 `_save_diary_entry()` 函数

**修复后的逻辑**:
```
_save_diary_entry(time_str, event_text, ...)
  ├─ 解析 time_str，构建完整时间戳
  ├─ 转换为 Unix 时间戳
  └─ 调用统一保存器一次性完成三处保存
```

**关键改进**:
- 只调用一次统一保存器
- 使用 AI 生成的时间而不是当前时间
- 确保三处保存的时间戳一致

### 2. 时间戳处理

```gdscript
func _save_diary_entry(time_str: String, event_text: String, start_datetime: Dictionary, _end_datetime: Dictionary):
    # 从 time_str 中提取日期
    var date_str = _extract_date_from_time(time_str, start_datetime)
    
    # 提取时间部分（HH:MM）
    var time_only = time_str
    if time_str.length() == 11:
        # 格式: MM-DD HH:MM，提取时间部分
        time_only = time_str.substr(6, 5)  # HH:MM
    
    # 构建完整时间戳（YYYY-MM-DDTHH:MM:SS）
    var full_timestamp = "%sT%s:00" % [date_str, time_only]
    
    # 转换为Unix时间戳
    var unix_time = _convert_to_unix_time(full_timestamp)
    
    # 使用统一保存器（只调用一次）
    await unified_saver.save_memory(
        event_text,
        unified_saver.MemoryType.OFFLINE,
        unix_time,  # 使用AI生成的时间
        "",
        {}
    )
```

### 3. 删除旧函数

删除了 `_save_diary_to_memory()` 函数，因为它的功能已经被统一保存器完全替代。

### 4. 添加降级方案

添加了 `_save_diary_entry_legacy()` 函数作为降级方案：

```gdscript
func _save_diary_entry_legacy(time_str: String, event_text: String, date_str: String):
    """降级方案：使用旧的日记保存逻辑"""
    # 手动保存到日记文件
    # 手动保存到存档
    # 手动保存到向量数据库
```

## 修复效果

### 修复前

**日记文件 (2025-10-26.jsonl)**:
```json
{"type":"offline","time":"14:30","event":"我去了图书馆看书"}
{"type":"offline","time":"15:45","event":"我去了图书馆看书"}
```
❌ 重复保存，时间不一致

### 修复后

**日记文件 (2025-10-26.jsonl)**:
```json
{"type":"offline","time":"14:30","event":"我去了图书馆看书"}
```
✅ 只保存一次，时间正确

## 时间一致性验证

修复后，三处保存的时间戳完全一致：

### 1. 存档 (saves/save_slot_1.json)
```json
{
  "ai_data": {
    "memory": [
      {
        "timestamp": "2025-10-26T14:30:00",
        "content": "我去了图书馆看书"
      }
    ]
  }
}
```

### 2. 日记 (diary/2025-10-26.jsonl)
```json
{"type":"offline","time":"14:30","event":"我去了图书馆看书"}
```

### 3. 向量数据库 (memory_main_memory.json)
```json
{
  "memories": [
    {
      "id": "uuid-xxx",
      "text": "我去了图书馆看书",
      "type": "diary",
      "timestamp": "2025-10-26T14:30:00",
      "embedding": [...]
    }
  ]
}
```

✅ 所有三处的时间都是 `14:30`（AI生成的时间）

## 测试建议

### 1. 基本功能测试

```gdscript
# 测试离线日记保存
# 1. 设置离线时间超过3小时
# 2. 重新启动游戏
# 3. 检查日记文件
# 4. 验证没有重复记录
```

### 2. 时间一致性测试

```gdscript
# 验证三处保存的时间戳一致
# 1. 保存一条离线日记
# 2. 检查 saves/save_slot_1.json 中的 timestamp
# 3. 检查 diary/YYYY-MM-DD.jsonl 中的 time
# 4. 检查 memory_main_memory.json 中的 timestamp
# 5. 确认三者时间一致
```

### 3. 边界测试

```gdscript
# 测试不同的时间格式
# 1. HH:MM 格式（5个字符）
# 2. MM-DD HH:MM 格式（11个字符）
# 3. 跨日期的情况
```

## 相关文件

- `scripts/offline_time_manager.gd` - 主要修改文件
- `scripts/unified_memory_saver.gd` - 统一保存器
- `docs/unified_memory_saver_guide.md` - 使用指南

## 总结

通过这次修复：

1. ✅ 消除了重复保存问题
2. ✅ 确保了时间一致性
3. ✅ 简化了代码逻辑
4. ✅ 保留了降级方案

现在离线日记的保存逻辑更加清晰和可靠。
