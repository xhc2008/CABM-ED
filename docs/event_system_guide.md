# 事件系统使用指南

## 概述

新的事件系统将所有交互事件的逻辑统一管理在 `EventManager` 中，包括：
- 成功判断
- 数值变化（好感度、交互意愿等）
- 独立的冷却时间管理
- 空闲超时检测

## 事件类型

系统支持以下7种事件：

1. **CHARACTER_CLICKED** - 角色被点击
2. **USER_START_CHAT** - 用户发起聊天
3. **ENTER_SCENE** - 进入角色所在场景
4. **LEAVE_SCENE** - 离开角色所在场景
5. **CHAT_TURN_END** - 一轮对话结束（AI回复判断点）
6. **CHAT_SESSION_END** - 完整对话结束（点击"结束聊天"）
7. **IDLE_TIMEOUT** - 一段时间没有任何操作

## 配置为自动加载

在 `project.godot` 中添加：

```
[autoload]
EventManager="*res://scripts/event_manager.gd"
```

## 使用方法

### 基本触发

```gdscript
# 触发事件
var result = EventManager.trigger_event(EventManager.EventType.CHARACTER_CLICKED)

# 检查结果
if result.success:
    print("事件成功: ", result.message)
    print("好感度变化: ", result.affection_change)
    print("交互意愿变化: ", result.willingness_change)
else:
    print("事件失败: ", result.message)
```

### 带上下文的触发

```gdscript
# 对话结束时传递对话轮数
var context = {"turn_count": 15}
var result = EventManager.trigger_event(
    EventManager.EventType.CHAT_SESSION_END,
    context
)
```

### 检查冷却状态

```gdscript
# 检查是否在冷却中
if EventManager.is_on_cooldown(EventManager.EventType.USER_START_CHAT):
    var remaining = EventManager.get_cooldown_remaining(EventManager.EventType.USER_START_CHAT)
    print("还需等待 %.1f 秒" % remaining)
```

### 监听事件信号

```gdscript
func _ready():
    # 监听事件触发
    EventManager.event_triggered.connect(_on_event_triggered)
    
    # 监听冷却开始
    EventManager.cooldown_started.connect(_on_cooldown_started)
    
    # 监听冷却结束
    EventManager.cooldown_ended.connect(_on_cooldown_ended)

func _on_event_triggered(event_type, result):
    print("事件触发: ", EventManager.get_event_type_name(event_type))
    print("结果: ", "成功" if result.success else "失败")

func _on_cooldown_started(event_type, duration):
    print("冷却开始: ", EventManager.get_event_type_name(event_type))
    print("时长: ", duration, "秒")

func _on_cooldown_ended(event_type):
    print("冷却结束: ", EventManager.get_event_type_name(event_type))
```

## 集成到现有代码

### 1. 角色点击

在角色脚本中：

```gdscript
func _on_character_clicked():
    var result = EventManager.trigger_event(EventManager.EventType.CHARACTER_CLICKED)
    
    if result.success:
        # 开始聊天或显示互动菜单
        start_chat()
    else:
        # 显示失败消息
        show_message(result.message)
```

### 2. 用户发起聊天

在聊天界面中：

```gdscript
func _on_chat_button_pressed():
    var result = EventManager.trigger_event(EventManager.EventType.USER_START_CHAT)
    
    if result.success:
        # 打开聊天窗口
        open_chat_dialog()
    else:
        # 显示角色不想聊天
        show_rejection_message(result.message)
```

### 3. 场景切换

在场景管理器中：

```gdscript
func change_scene(new_scene_id: String):
    var old_scene = current_scene_id
    var character_scene = get_character_scene()
    
    # 离开角色所在场景
    if old_scene == character_scene:
        EventManager.trigger_event(EventManager.EventType.LEAVE_SCENE)
    
    # 切换场景
    current_scene_id = new_scene_id
    
    # 进入角色所在场景
    if new_scene_id == character_scene:
        EventManager.trigger_event(EventManager.EventType.ENTER_SCENE)
```

### 4. AI对话判断

在AI服务中：

```gdscript
func should_ai_reply() -> bool:
    var result = EventManager.trigger_event(EventManager.EventType.CHAT_TURN_END)
    return result.success
```

### 5. 对话结束

在聊天界面中：

```gdscript
func _on_end_chat_pressed():
    var context = {"turn_count": message_count}
    var result = EventManager.trigger_event(
        EventManager.EventType.CHAT_SESSION_END,
        context
    )
    
    close_chat_dialog()
```

## 事件逻辑说明

### 成功概率计算

```
成功率 = (基础意愿 + 当前交互意愿 - 100) / 100 + 心情修正 + 精力修正
```

- **基础意愿**：每个事件预设的基础值
- **当前交互意愿**：从存档系统获取（0-100）
- **心情修正**：
  - happy: +20%
  - excited: +30%
  - normal: 0%
  - sad: -20%
  - angry: -40%
- **精力修正**：
  - high (80+): +10%
  - normal (40-79): 0%
  - low (20-39): -15%
  - exhausted (<20): -30%

### 数值变化

每个事件成功或失败后会自动应用：
- **好感度变化**：范围 0-100
- **交互意愿变化**：范围 0-100
- **心情变化**：可选

### 冷却时间

- 每个事件有独立的冷却时间
- 冷却期间无法再次触发该事件
- 不同事件的冷却互不影响

### 空闲超时

- 默认5分钟（300秒）无操作触发
- 任何事件触发都会重置计时器
- 超时会降低交互意愿

## 调试功能

```gdscript
# 打印所有冷却状态
EventManager.print_all_cooldowns()

# 清除特定事件冷却
EventManager.clear_cooldown(EventManager.EventType.USER_START_CHAT)

# 清除所有冷却
EventManager.clear_all_cooldowns()

# 获取事件类型名称
var name = EventManager.get_event_type_name(EventManager.EventType.CHARACTER_CLICKED)
```

## 迁移指南

### 从旧的 InteractionManager 迁移

**旧代码：**
```gdscript
InteractionManager.try_interaction("chat")
```

**新代码：**
```gdscript
EventManager.trigger_event(EventManager.EventType.USER_START_CHAT)
```

### 移除的逻辑

以下逻辑已从其他脚本移除，统一由 EventManager 管理：
- 好感度变化计算
- 交互意愿变化计算
- 成功率判断
- 冷却时间管理

### 保留的功能

SaveManager 仍然负责：
- 数据持久化
- 数据读取
- 自动保存

## 配置文件

事件配置在 `config/event_config.json` 中，可以调整：
- 基础意愿值
- 数值变化范围
- 冷却时间
- 提示消息

**注意**：心情和精力的修正逻辑在 `event_manager.gd` 脚本中实现，不在配置文件中，因为这些逻辑可能比简单的数值映射更复杂。

## 注意事项

1. EventManager 必须配置为自动加载
2. 依赖 SaveManager 自动加载节点
3. 空闲计时器会在任何事件触发时重置
4. 冷却时间是独立的，不会相互影响
5. 所有数值变化会自动保存（如果启用了即时保存）
