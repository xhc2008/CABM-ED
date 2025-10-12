# 存档系统使用指南

## 概述

存档系统用于持久化保存游戏数据，包括角色好感度、回复意愿、游戏进度等信息。

## 文件结构

- `scripts/save_manager.gd` - 存档管理器脚本
- `config/save_data_template.json` - 存档数据模板

## 存档数据结构

### 角色数据 (character_data)
- `affection` (0-100): 好感度
- `reply_willingness` (0-100): 回复意愿
- `mood` (string): 心情状态 (normal, happy, sad, angry, etc.)
- `energy` (0-100): 精力值
- `trust_level` (0-100): 信任等级

### 用户数据 (user_data)
- `total_chat_count`: 总聊天次数
- `total_play_time`: 总游戏时长（秒）
- `last_login_date`: 最后登录日期
- `consecutive_days`: 连续登录天数

### 游戏进度 (game_progress)
- `unlocked_scenes`: 已解锁的场景列表
- `unlocked_characters`: 已解锁的角色列表
- `completed_events`: 已完成的事件列表
- `current_scene`: 当前场景

### 统计数据 (statistics)
- `total_messages_sent`: 发送的消息总数
- `total_messages_received`: 接收的消息总数
- `favorite_scene`: 最喜欢的场景
- `most_used_action`: 最常用的操作

## 使用方法

### 1. 在主场景中添加 SaveManager

在 `project.godot` 中添加自动加载：

```gdscript
[autoload]
SaveManager="*res://scripts/save_manager.gd"
```

或在代码中手动添加：

```gdscript
var save_manager = preload("res://scripts/save_manager.gd").new()
add_child(save_manager)
```

### 2. 保存游戏

```gdscript
# 保存到当前槽位
SaveManager.save_game()

# 保存到指定槽位
SaveManager.save_game(1)
```

### 3. 加载游戏

```gdscript
# 从当前槽位加载
SaveManager.load_game()

# 从指定槽位加载
SaveManager.load_game(1)
```

### 4. 访问和修改数据

```gdscript
# 角色数据
var affection = SaveManager.get_affection()
SaveManager.set_affection(50)
SaveManager.add_affection(10)  # 增加10点好感度

var willingness = SaveManager.get_reply_willingness()
SaveManager.set_reply_willingness(80)

var mood = SaveManager.get_mood()
SaveManager.set_mood("happy")

# 用户数据
SaveManager.increment_chat_count()
SaveManager.add_play_time(60)  # 增加60秒游戏时长

# 游戏进度
if SaveManager.is_scene_unlocked("bedroom"):
    print("卧室已解锁")

SaveManager.unlock_scene("bedroom")
SaveManager.set_current_scene("livingroom")

# 统计数据
SaveManager.increment_messages_sent()
SaveManager.increment_messages_received()
```

### 5. 检查和管理存档

```gdscript
# 检查存档是否存在
if SaveManager.save_exists(1):
    print("槽位1有存档")

# 获取存档信息
var info = SaveManager.get_save_info(1)
print("最后保存时间: ", info.last_saved_at)

# 删除存档
SaveManager.delete_save(1)
```

### 6. 监听存档事件

```gdscript
func _ready():
    SaveManager.save_completed.connect(_on_save_completed)
    SaveManager.load_completed.connect(_on_load_completed)
    SaveManager.save_failed.connect(_on_save_failed)
    SaveManager.load_failed.connect(_on_load_failed)

func _on_save_completed(slot: int):
    print("保存成功: 槽位 ", slot)

func _on_load_completed(slot: int):
    print("加载成功: 槽位 ", slot)

func _on_save_failed(error: String):
    print("保存失败: ", error)

func _on_load_failed(error: String):
    print("加载失败: ", error)
```

## 存档文件位置

存档文件保存在：
- Windows: `%APPDATA%/Godot/app_userdata/[项目名]/saves/`
- Linux: `~/.local/share/godot/app_userdata/[项目名]/saves/`
- macOS: `~/Library/Application Support/Godot/app_userdata/[项目名]/saves/`

## 自动保存

可以在游戏中实现自动保存功能：

```gdscript
var auto_save_timer: Timer

func _ready():
    # 创建自动保存计时器
    auto_save_timer = Timer.new()
    add_child(auto_save_timer)
    auto_save_timer.wait_time = 300  # 5分钟
    auto_save_timer.timeout.connect(_on_auto_save)
    auto_save_timer.start()

func _on_auto_save():
    SaveManager.save_game()
    print("自动保存完成")
```

## 注意事项

1. 首次运行时会自动加载模板数据
2. 所有数值类型的数据都有范围限制（0-100）
3. 保存前会自动更新时间戳
4. 建议在重要操作后手动保存
5. 可以扩展模板添加更多自定义数据
