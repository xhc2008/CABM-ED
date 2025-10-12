# 交互意愿系统使用指南

## 概述

交互意愿系统控制角色对用户各种操作的响应概率。每个动作都有基础意愿值，结合当前交互意愿计算实际成功率。

## 核心机制

### 成功概率计算公式

```
实际成功率 = (基础意愿 + 当前交互意愿 - 100) / 100
```

### 示例

- 当前交互意愿：80
- 聊天基础意愿：150%
- 实际成功率：(150 + 80 - 100) / 100 = 130% → 100%（必定成功）

- 当前交互意愿：30
- 进入场景基础意愿：80%
- 实际成功率：(80 + 30 - 100) / 100 = 10%（很低概率）

## 配置文件

### 动作配置 (interaction_config.json)

```json
{
  "actions": {
    "chat": {
      "name": "聊天",
      "base_willingness": 150,
      "on_success": "start_chat",
      "on_failure": {
        "type": "message",
        "text": "{character_name}不想理你"
      }
    }
  }
}
```

### 动作类型

| 动作ID | 名称 | 基础意愿 | 失败反馈 |
|--------|------|----------|----------|
| chat | 聊天 | 150% | 显示消息 |
| enter_scene | 进入角色所在场景 | 80% | 无事发生 |
| leave_scene | 离开角色所在场景 | 40% | 无事发生 |
| click_character | 点击角色 | 120% | 显示消息 |
| gift | 送礼物 | 200% | 显示消息 |
| pat_head | 摸头 | 100% | 显示消息 |
| call_name | 呼唤名字 | 90% | 显示消息 |

### 意愿修正因子

#### 心情修正
- happy: +20%
- normal: 0%
- sad: -20%
- angry: -40%
- excited: +30%

#### 精力修正
- high (80-100): +10%
- normal (40-79): 0%
- low (20-39): -15%
- exhausted (0-19): -30%

## 使用方法

### 1. 在项目中添加 InteractionManager

在 `project.godot` 中添加自动加载：

```gdscript
[autoload]
InteractionManager="*res://scripts/interaction_manager.gd"
```

### 2. 尝试执行交互

```gdscript
# 尝试聊天
var success = InteractionManager.try_interaction("chat")
if success:
    # 开始聊天
    start_chat_dialog()
else:
    # 显示失败消息（会自动通过信号发送）
    pass

# 尝试其他动作
InteractionManager.try_interaction("enter_scene")
InteractionManager.try_interaction("click_character")
```

### 3. 监听交互事件

```gdscript
func _ready():
    InteractionManager.interaction_success.connect(_on_interaction_success)
    InteractionManager.interaction_failure.connect(_on_interaction_failure)

func _on_interaction_success(action_id: String):
    print("交互成功: ", action_id)
    
    match action_id:
        "chat", "click_character", "gift", "pat_head", "call_name":
            start_chat_dialog()
        "enter_scene", "leave_scene":
            # 可能触发随机对话
            if randf() < 0.3:  # 30%概率
                start_chat_dialog()

func _on_interaction_failure(action_id: String, message: String):
    if message != "":
        # 显示失败消息
        show_notification(message)
```

### 4. 查询成功概率

```gdscript
# 获取当前成功概率
var chance = InteractionManager.calculate_success_chance("chat")
print("聊天成功率: ", chance * 100, "%")

# 检查是否在冷却中
if InteractionManager.is_on_cooldown("chat"):
    var remaining = InteractionManager.get_cooldown_remaining("chat")
    print("冷却剩余时间: ", remaining, "秒")
```

### 5. 修改交互意愿

```gdscript
# 增加交互意愿
InteractionManager.modify_willingness(10)

# 减少交互意愿
InteractionManager.modify_willingness(-20)

# 监听意愿变化
InteractionManager.willingness_changed.connect(_on_willingness_changed)

func _on_willingness_changed(new_value: int):
    print("交互意愿现在是: ", new_value)
```

## 实际应用示例

### 在角色点击时

```gdscript
# scripts/character.gd
func _on_pressed():
    if not is_chatting:
        # 尝试交互
        var success = InteractionManager.try_interaction("click_character")
        if success:
            # 发送信号开始聊天
            character_clicked.emit(global_position, size * scale)
```

### 在场景切换时

```gdscript
# scripts/scene_menu.gd
func _on_scene_selected(scene_id: String):
    var current_scene = get_current_scene()
    
    # 检查是否有角色在当前场景
    if has_character_in_scene(current_scene):
        # 尝试离开场景交互
        InteractionManager.try_interaction("leave_scene")
    
    # 切换场景
    change_scene(scene_id)
    
    # 检查新场景是否有角色
    if has_character_in_scene(scene_id):
        # 尝试进入场景交互
        InteractionManager.try_interaction("enter_scene")
```

### 显示失败消息

```gdscript
# scripts/main.gd
func _ready():
    InteractionManager.interaction_failure.connect(_on_interaction_failure)

func _on_interaction_failure(action_id: String, message: String):
    if message != "":
        # 创建临时标签显示消息
        var label = Label.new()
        label.text = message
        label.position = Vector2(100, 100)
        add_child(label)
        
        # 3秒后消失
        await get_tree().create_timer(3.0).timeout
        label.queue_free()
```

## 冷却机制

失败后会进入冷却期，防止频繁尝试：
- 聊天类动作：30秒冷却
- 其他动作：10秒冷却

## 调试技巧

```gdscript
# 查看当前状态
print("交互意愿: ", SaveManager.get_reply_willingness())
print("心情: ", SaveManager.get_mood())
print("精力: ", SaveManager.get_energy())
print("聊天成功率: ", InteractionManager.calculate_success_chance("chat") * 100, "%")

# 临时提高成功率（测试用）
SaveManager.set_reply_willingness(100)
SaveManager.set_mood("happy")
SaveManager.set_energy(100)
```

## 扩展配置

可以在 `interaction_config.json` 中添加新的动作：

```json
{
  "actions": {
    "hug": {
      "name": "拥抱",
      "base_willingness": 80,
      "on_success": "start_chat",
      "on_failure": {
        "type": "message",
        "text": "{character_name}推开了你"
      }
    }
  }
}
```

## 注意事项

1. 成功率会被限制在 0-100% 范围内
2. 失败后会自动进入冷却期
3. 心情和精力会影响所有动作的成功率
4. 可以通过修改配置文件调整平衡性
5. 建议根据游戏进度动态调整交互意愿
