# 日记系统迁移指南

## 快速开始

如果你是新用户，无需任何操作，系统会自动使用新的日记格式。

如果你有旧的日记数据，请按照以下步骤迁移。

## 迁移步骤

### 方法1：使用迁移脚本（推荐）

1. 在Godot编辑器中打开项目
2. 打开脚本编辑器，创建一个临时脚本或在现有脚本中添加：

```gdscript
# 在游戏启动时执行一次
func _ready():
    var migration = preload("res://scripts/diary_migration.gd").new()
    var count = migration.migrate_diary_data()
    print("迁移完成，共处理 %d 条记录" % count)
```

3. 运行游戏，迁移会自动执行
4. 检查控制台输出，确认迁移成功
5. 删除临时代码

### 方法2：手动迁移

如果你想手动迁移数据：

1. 找到用户数据目录：
   - Windows: `%APPDATA%\Godot\app_userdata\[项目名]\`
   - Linux: `~/.local/share/godot/app_userdata/[项目名]/`
   - macOS: `~/Library/Application Support/Godot/app_userdata/[项目名]/`

2. 备份现有数据：
   - 复制 `diary/` 和 `character_diary/` 文件夹

3. 合并数据：
   - 将 `character_diary/` 中的所有 `.jsonl` 文件复制到 `diary/` 文件夹
   - 如果有同名文件，需要手动合并内容

4. 添加type字段：
   - 打开每个 `.jsonl` 文件
   - 为每条记录添加 `"type"` 字段：
     - 有 `summary` 和 `conversation` 字段的记录：`"type": "chat"`
     - 有 `time` 和 `event` 字段的记录：`"type": "offline"`

## 验证迁移

迁移完成后，进入游戏：

1. 进入bedroom场景
2. 点击日记入口
3. 检查是否能看到所有日记记录
4. 尝试点击带💬标记的记录，查看详情
5. 切换不同日期，确认数据完整

## 清理旧数据

确认迁移成功后，可以删除旧的数据：

1. 删除 `user://character_diary/` 目录
2. 删除以下不再使用的文件：
   - `scripts/diary_button.gd`
   - `scripts/diary_viewer.gd`

## 常见问题

### Q: 迁移后看不到旧的日记？
A: 检查控制台输出，确认迁移脚本是否成功执行。如果失败，尝试手动迁移。

### Q: 某些记录显示不正确？
A: 检查该记录的type字段是否正确。Chat类型需要有summary和conversation字段，Offline类型需要有time和event字段。

### Q: 可以回滚到旧版本吗？
A: 如果你备份了数据，可以恢复备份。但新版本不再支持旧的分离式日记系统。

### Q: 迁移会删除原始数据吗？
A: 不会。迁移脚本只会复制和转换数据，不会删除原始文件。

## 技术细节

迁移脚本会：
1. 扫描 `user://character_diary/` 目录
2. 读取每个 `.jsonl` 文件
3. 为每条记录添加 `"type": "offline"` 字段
4. 将记录追加到 `user://diary/` 对应的文件中
5. 扫描 `user://diary/` 中的现有记录
6. 为缺少type字段的记录自动判断类型并添加

## 支持

如果遇到问题，请检查：
- Godot控制台的错误信息
- 用户数据目录的文件权限
- `.jsonl` 文件的JSON格式是否正确
