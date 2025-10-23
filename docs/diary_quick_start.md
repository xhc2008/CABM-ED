# 日记系统快速开始

## 新用户

无需任何配置，系统已经准备就绪！

### 如何使用

1. **进入bedroom场景**
2. **点击日记入口**（左下角）
3. **查看日记列表**
   - 💬 对话记录 - 点击查看详情
   - ⏰ 离线事件 - 直接显示内容
4. **切换日期**（使用前一天/后一天按钮）

## 现有用户（有旧数据）

### 一次性迁移

在游戏启动时执行一次：

```gdscript
func _ready():
    var migration = preload("res://scripts/diary_migration.gd").new()
    migration.migrate_diary_data()
```

### 验证迁移

1. 进入bedroom场景
2. 打开日记
3. 检查是否能看到所有记录
4. 尝试点击💬记录查看详情

## 记录类型

### 💬 Chat（对话记录）
- 自动保存：结束对话时
- 内容：对话总结 + 完整对话
- 操作：点击查看详情

### ⏰ Offline（离线事件）
- 自动生成：玩家离线时
- 内容：角色的活动记录
- 操作：直接显示，不可点击

## 数据位置

所有日记统一存储在：`user://diary/YYYY-MM-DD.jsonl`

## 常见问题

**Q: 看不到旧的日记？**
A: 运行迁移脚本，详见 `docs/diary_migration_guide.md`

**Q: 如何区分不同类型的记录？**
A: 💬 = 对话记录（可点击），⏰ = 离线事件（仅显示）

**Q: 可以删除旧文件吗？**
A: 确认迁移成功后，可以删除 `user://character_diary/` 目录

## 更多信息

- 详细说明：`docs/diary_system_improvement.md`
- 迁移指南：`docs/diary_migration_guide.md`
- 变更总结：`DIARY_SYSTEM_CHANGES.md`
