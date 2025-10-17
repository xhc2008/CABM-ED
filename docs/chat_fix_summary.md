# 聊天系统修复说明

## 修复的问题

### 1. 超时后自动退出机制和提示
**问题1**：回复模式和历史模式超时后，只是切换到输入模式，但没有自动退出聊天
**问题2**：回复模式和历史模式超时退出时，没有显示"xxx默默离开了"的提示

**修复**：
- 回复模式超时 → 显示"xxx默默离开了" → 切换到输入模式（0.5秒过渡） → 自动退出聊天
- 历史模式超时 → 显示"xxx默默离开了" → 切换到输入模式（0.5秒过渡） → 自动退出聊天
- 输入模式超时 → 显示"xxx默默离开了" → 直接退出聊天

**代码位置**：
- `scripts/chat_dialog.gd` - `_on_event_completed()` - 处理切换和退出逻辑
- `scripts/main.gd` - `_on_event_completed()` 和 `_force_end_chat()` - 显示提示消息

```gdscript
# chat_dialog.gd
if result.message == "timeout_to_input":
    # 切换到输入模式，然后自动退出
    if is_history_visible:
        await _hide_history()
    elif waiting_for_continue:
        await _transition_to_input_mode()
    
    # 切换到输入模式后，自动退出聊天
    await get_tree().create_timer(0.5).timeout
    _on_end_button_pressed()

# main.gd
func _force_end_chat():
    """强制结束聊天（由于空闲超时）并显示提示"""
    if chat_dialog.visible:
        # 获取角色名称并显示提示消息
        var character_name = helpers.get_character_name()
        _show_failure_message(character_name + "默默离开了")

func _on_event_completed(event_name: String, result):
    if event_name == "idle_timeout":
        if result.message == "timeout_to_input":
            # 回复模式或历史模式超时，显示提示
            _force_end_chat()
        elif result.message == "chat_idle_timeout":
            # 输入模式超时，显示提示并结束聊天
            _force_end_chat()
            chat_dialog._on_end_button_pressed()
```

### 2. TTS未启用时的计时器机制
**问题**：计时器总是等待语音播放完毕才开始，但如果TTS未启用，语音永远不会播放完毕

**修复**：
- **TTS启用时**：以语音播放完毕作为计时器开始
- **TTS未启用时**：以文本输出完毕作为计时器开始

**代码位置**：`scripts/chat_dialog.gd` - `_show_sentence_continue_indicator()` 和 `_show_continue_indicator()`

```gdscript
# 检查TTS是否启用
var tts_enabled = false
if has_node("/root/TTSService"):
    var tts = get_node("/root/TTSService")
    tts_enabled = tts.is_enabled

if not tts_enabled:
    # TTS未启用，立即重置计时器
    if has_node("/root/EventManager"):
        var event_mgr = get_node("/root/EventManager")
        event_mgr.reset_idle_timer()
        print("TTS未启用，文本输出完毕，重置空闲计时器")
```

### 3. 代码清理
**问题**：未使用的变量 `found_punct_char` 导致警告

**修复**：删除未使用的变量

## 测试建议

### 测试场景1：TTS启用时的超时
1. 启用TTS
2. 发送消息，等待角色回复
3. 等待语音播放完毕后开始计时
4. 超时后应该：切换到输入模式 → 0.5秒后自动退出

### 测试场景2：TTS未启用时的超时
1. 禁用TTS
2. 发送消息，等待角色回复
3. 文本输出完毕后立即开始计时
4. 超时后应该：切换到输入模式 → 0.5秒后自动退出

### 测试场景3：历史模式超时
1. 打开历史记录
2. 等待超时
3. 应该：关闭历史 → 切换到输入模式 → 0.5秒后自动退出

### 测试场景4：输入模式超时
1. 在输入模式下等待
2. 超时后应该：直接退出聊天（降低好感）

## 修改的文件

1. `scripts/chat_dialog.gd` - 主要修复
2. `scripts/event_manager.gd` - 恢复正常超时时间（120-180秒）
3. `docs/chat_improvements.md` - 更新文档

## 注意事项

- 超时时间为120-180秒（随机）
- 回复模式和历史模式超时会有0.5秒的过渡动画
- TTS状态检测在每次显示继续指示器时进行
- 语音播放完毕的通知由TTS服务发送
- 所有超时退出都会显示"xxx默默离开了"的提示（共用`_force_end_chat()`函数）
- `timeout_to_input`由chat_dialog处理退出逻辑，`chat_idle_timeout`由main.gd调用退出
