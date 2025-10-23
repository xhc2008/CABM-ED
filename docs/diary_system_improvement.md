# 日记系统改进说明

## 改进概述

本次改进将"玩家日记"和"角色日记"合并为统一的日记系统，简化了用户界面和数据管理。

## 主要变更

### 1. 数据存储统一

**之前：**
- 玩家日记：`user://diary/YYYY-MM-DD.jsonl`
- 角色日记：`user://character_diary/YYYY-MM-DD.jsonl`

**现在：**
- 统一存储：`user://diary/YYYY-MM-DD.jsonl`
- 每条记录添加 `type` 字段区分类型：
  - `"type": "chat"` - 对话记录（包含总结和完整对话）
  - `"type": "offline"` - 离线事件记录

### 2. 记录格式

#### Chat类型记录
```json
{
  "type": "chat",
  "timestamp": "14:30:25",
  "summary": "对话总结内容",
  "conversation": "完整对话内容"
}
```

#### Offline类型记录
```json
{
  "type": "offline",
  "time": "14:30",
  "event": "事件描述"
}
```

### 3. 用户界面改进

**入口：**
- 保持原来的角色日记入口（bedroom场景）
- 移除了玩家日记入口（studyroom场景）

**列表视图：**
- 显示所有类型的记录
- Chat类型记录显示 💬 标记，可点击查看详情
- Offline类型记录显示 ⏰ 标记，仅显示事件内容

**详情视图：**
- 仅Chat类型记录可进入详情视图
- 显示对话总结和完整对话内容
- 提供返回按钮返回列表

## 文件变更

### 修改的文件

1. **scripts/character_diary_viewer.gd**
   - 更新数据加载路径为 `user://diary/`
   - 添加type字段支持
   - 实现Chat类型记录的详情查看功能
   - 添加返回按钮和视图切换逻辑

2. **scripts/ai_logger.gd**
   - 在保存对话记录时添加 `"type": "chat"` 字段

3. **scripts/offline_time_manager.gd**
   - 更新日记目录为 `user://diary/`
   - 在保存离线事件时添加 `"type": "offline"` 字段

4. **scripts/main.gd**
   - 移除diary_button和diary_viewer相关代码
   - 保留character_diary_button和character_diary_viewer

5. **config/interactive_elements.json**
   - 移除diary_button配置
   - 保留character_diary_button配置

### 删除的文件

以下文件不再使用，可以删除：
- `scripts/diary_button.gd`
- `scripts/diary_viewer.gd`
- `scenes/diary_button.tscn`（如果存在）
- `scenes/diary_viewer.tscn`（如果存在）

### 新增的文件

1. **scripts/diary_migration.gd**
   - 数据迁移工具
   - 将旧的角色日记迁移到新目录
   - 为现有记录添加type字段

## 数据迁移

如果你有现有的日记数据，可以使用迁移工具：

```gdscript
# 在游戏中执行一次
var migration = preload("res://scripts/diary_migration.gd").new()
migration.migrate_diary_data()
```

迁移工具会：
1. 将 `user://character_diary/` 中的记录迁移到 `user://diary/`
2. 为所有记录添加适当的 `type` 字段
3. 保留原有数据不变

## 兼容性说明

- 旧的日记数据不会自动删除
- 迁移后可以手动删除 `user://character_diary/` 目录
- 没有type字段的记录会被视为offline类型

## 测试建议

1. 测试对话记录保存（Chat类型）
2. 测试离线事件生成（Offline类型）
3. 测试列表视图显示
4. 测试Chat记录的详情查看
5. 测试日期切换功能
6. 测试返回按钮功能

## 注意事项

- 确保在使用前运行数据迁移（如果有旧数据）
- Chat类型记录的conversation字段格式为：`说话者：内容\n说话者：内容`
- 时间格式支持 `HH:MM` 和 `MM-DD HH:MM` 两种
