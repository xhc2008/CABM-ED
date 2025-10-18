# 角色位置变动系统

## 概述

角色位置变动只在两种情况下触发：
1. **聊天结束时** - 有字幕播报
2. **空闲超时时** - 无字幕播报

**进入/离开场景不再触发位置变动**，只触发对话。

## 聊天结束时的位置变动

### 触发时机
- 用户点击"结束聊天"按钮
- 聊天空闲超时

### 两种变化方式

#### 1. AI决定的场景变化（goto字段）
```gdscript
// character.gd - end_chat()
var goto_scene = _check_goto_scene()
if goto_scene != "":
    _move_to_scene(goto_scene, true)  // show_notification = true
```

- AI在对话中设置goto字段
- 角色移动到指定场景
- **显示字幕**："角色去XX了"
- 同时更新scene和preset

#### 2. 概率触发的位置变动
```gdscript
// character.gd - end_chat()
else:
    apply_position_probability(true, true)  // from_chat_end=true, show_notification=true
```

- 70%保持原位 → 淡入显示
- 25%当前场景随机位置 → 淡入显示
- 5%其他场景 → **显示字幕**："角色去XX了"

## 空闲超时时的位置变动

### 触发时机
- 非聊天状态下长时间无操作（120-180秒）
- 30%概率触发位置变动

### 行为
```gdscript
// main.gd - _trigger_idle_position_change()
await character.apply_position_probability_silent()
```

- **无字幕播报**
- 角色可能在任何场景（不限于用户当前场景）
- 70%保持原位
- 25%当前场景随机位置 → 更新preset
- 5%其他场景 → 更新scene和preset

## 进入/离开场景

### 行为
- **只触发对话，不触发位置变动**
- 进入有角色的场景 → 可能触发主动对话（50%概率）
- 离开有角色的场景 → 可能触发离别对话（30%概率）

## 字幕显示逻辑

### 显示字幕的情况
1. 聊天结束 + AI决定场景变化
2. 聊天结束 + 概率触发移动到其他场景（5%）

### 不显示字幕的情况
1. 空闲超时触发的所有位置变动
2. 聊天结束但保持原位或当前场景随机位置

### 实现机制
```gdscript
// character.gd
func _move_to_scene(new_scene: String, show_notification: bool = true):
    save_mgr.set_meta("show_move_notification", show_notification)
    save_mgr.set_character_scene(new_scene)

// main.gd
func _on_character_scene_changed(new_scene: String):
    var show_notification = save_mgr.get_meta("show_move_notification", true)
    if show_notification:
        _show_character_move_message(new_scene)
```

## 场景切换安全机制

### 1. 取消待触发的聊天
```gdscript
// main.gd - _on_scene_changed()
if scene_actually_changed:
    _cancel_pending_chat()  // 取消0.5秒延迟的聊天
    _lock_scene_switch()    // 锁定场景切换1秒
```

### 2. 延迟聊天触发时的检查
```gdscript
// main.gd - _on_pending_chat_timeout()
if not _has_character_in_scene(current_scene):
    return  // 角色已不在当前场景
if not character.visible or character.is_chatting:
    return  // 角色不可见或正在聊天
```

### 3. 优先级：进入 > 离开
```gdscript
if _has_character_in_scene(scene_id):
    _try_scene_interaction("enter_scene")  // 优先触发进入
elif _has_character_in_scene(old_scene):
    _try_scene_interaction("leave_scene")  // 否则触发离开
```

## 数据同步

### Scene和Preset同步
所有场景变化都通过 `_move_to_scene()` 或 `_update_preset_for_scene()` 确保同步：

```gdscript
func _move_to_scene(new_scene: String, show_notification: bool = true):
    save_mgr.set_character_scene(new_scene)  // 更新scene
    _update_preset_for_scene(new_scene)      // 更新preset

func _update_preset_for_scene(scene_id: String):
    // 从配置中随机选择预设
    save_mgr.set_character_preset(new_preset)
```

## 动画行为

### 聊天结束时（from_chat_end = true）
- 角色已隐藏（visible = false）
- 70%保持原位 → `_reload_same_preset()` → 淡入
- 25%随机位置 → `load_character_for_scene()` → 淡入
- 5%其他场景 → 更新SaveManager → 保持隐藏

### 空闲超时时（from_chat_end = false）
- 角色已可见（visible = true）
- 70%保持原位 → 无动画
- 25%随机位置 → 淡出 → 淡入
- 5%其他场景 → 淡出 → 隐藏

## 总结

| 触发时机 | 位置变动 | 字幕播报 | 动画 |
|---------|---------|---------|------|
| 聊天结束（AI goto） | ✓ | ✓ | 淡入 |
| 聊天结束（概率5%其他场景） | ✓ | ✓ | 淡入 |
| 聊天结束（概率25%随机位置） | ✓ | ✗ | 淡入 |
| 聊天结束（概率70%原位） | ✗ | ✗ | 淡入 |
| 空闲超时（所有情况） | ✓ | ✗ | 淡出+淡入或无 |
| 进入场景 | ✗ | ✗ | - |
| 离开场景 | ✗ | ✗ | - |
