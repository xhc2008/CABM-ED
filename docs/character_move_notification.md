# 角色移动提示功能

## 功能描述
当角色通过goto移动到新场景后，显示一个提示消息告知用户。

## 实现细节

### 1. 消息显示函数
**位置**: `scripts/main.gd`

创建了三个函数：
- `_show_message(message, color)` - 通用消息显示函数
- `_show_failure_message(message)` - 显示失败消息（红色）
- `_show_info_message(message)` - 显示信息消息（蓝色）

```gdscript
func _show_info_message(message: String):
    """显示信息消息（蓝色）"""
    _show_message(message, Color(0.5, 0.8, 1.0))
```

### 2. 检查goto场景变化
**位置**: `scripts/main.gd` 的 `_on_chat_ended()`

在对话结束时检查是否有goto场景变化：

```gdscript
func _on_chat_ended():
    # 检查是否有goto场景变化
    var goto_scene = _check_character_goto()
    
    # 聊天结束，角色返回场景
    character.end_chat()
    
    # 如果有goto场景变化，显示提示消息
    if goto_scene != "":
        _show_character_move_message(goto_scene)
```

### 3. 检查goto的辅助函数
```gdscript
func _check_character_goto() -> String:
    """检查角色是否有goto场景变化"""
    # 1. 获取goto_index
    # 2. 转换为场景ID
    # 3. 检查是否与当前场景相同
    # 4. 返回目标场景（如果有效）
```

### 4. 显示移动消息
```gdscript
func _show_character_move_message(new_scene: String):
    """显示角色移动的提示消息"""
    var character_name = helpers.get_character_name()
    var scene_name = _get_scene_name(new_scene)
    var message = "%s去%s了" % [character_name, scene_name]
    _show_info_message(message)
```

## 消息格式
- **内容**: "{角色名}去{场景名}了"
- **颜色**: 蓝色 (0.5, 0.8, 1.0)
- **位置**: 场景中央偏上
- **动画**: 淡入 → 停留2秒 → 淡出

## 触发条件
只在以下情况显示消息：
- ✅ AI在对话中输出了有效的goto字段
- ✅ goto的目标场景不是当前场景
- ✅ 对话正常结束

不会在以下情况显示：
- ❌ 首次加载游戏
- ❌ 用户切换场景
- ❌ 概率触发的场景变化（5%移动到其他场景）
- ❌ goto到当前场景（被忽略）

## 为什么在对话结束时处理？
1. **逻辑清晰**: 只有对话结束时的goto才需要提示
2. **避免误报**: 不会在首次加载、用户切换场景时显示
3. **时机准确**: 在角色实际移动时显示，用户体验更好

## 与失败消息的区别
| 特性 | 失败消息 | 信息消息 |
|------|---------|---------|
| 颜色 | 红色 | 蓝色 |
| 用途 | 错误、失败 | 信息、提示 |
| 示例 | "角色不想理你" | "角色去卧室了" |

## 测试要点
1. ✅ AI输出goto后，对话结束时显示消息
2. ✅ 消息内容正确（角色名+场景名）
3. ✅ 消息颜色为蓝色
4. ✅ goto到当前场景时不显示消息
5. ✅ 首次加载时不显示消息
6. ✅ 用户切换场景时不显示消息
