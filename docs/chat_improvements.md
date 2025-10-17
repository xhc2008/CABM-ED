# 聊天系统改进文档

## 改进概述

本次改进主要针对聊天输出方式、语音播放机制和超时检测进行了优化。

## 1. 分段流式输出

### 改进内容
- **按中文标点分割**：使用中文标点符号（。！？；…）作为句子分隔符
- **逐句显示**：每句话显示完毕后，等待用户点击继续
- **清空聊天框**：点击继续后清空当前句子，开始显示下一句
- **打字机效果**：每句话都有独立的打字机动画效果

### 实现细节
```gdscript
# 新增变量
var sentence_buffer: String = ""  # 完整句子缓冲
var sentence_queue: Array = []  # 待显示的句子队列
var current_sentence_index: int = 0  # 当前显示的句子索引
var is_showing_sentence: bool = false  # 是否正在显示句子
```

### 工作流程
1. AI流式响应到达 → 添加到`sentence_buffer`
2. 检测到中文标点 → 提取完整句子到`sentence_queue`
3. 显示第一句 → 打字机效果 → 显示继续指示器
4. 用户点击 → 清空消息框 → 显示下一句
5. 所有句子显示完毕 → 切换回输入模式

## 2. 语音播放改进

### 改进内容
- **即时播放**：每句话开始输出时，立即播放该句的语音
- **全局去除静音**：所有句子的语音都应用去除静音机制（不仅限于第一句）
- **统一管理**：文本分段和语音分段使用相同的逻辑

### 实现细节
```gdscript
# chat_dialog.gd
func _show_next_sentence():
    # 清空消息标签
    message_label.text = ""
    # 立即发送TTS
    _send_tts(sentence)
    # 开始打字机效果
    typing_timer.start(TYPING_SPEED)
```

```gdscript
# tts_service.gd
func _try_play_next():
    # 所有音频都跳过开头的静音
    var skip_time = _detect_silence_duration(stream)
    if skip_time > 0:
        current_player.play(skip_time)
    else:
        current_player.play()
```

### 语音播放完毕通知
- TTS服务在语音播放完毕后通知聊天对话框
- 聊天对话框重置空闲计时器（从语音播放完毕开始计时）

## 3. 超时检测机制改进

### 改进内容
- **分状态处理**：区分回复模式、历史模式、输入模式、非聊天状态
- **精确计时**：
  - 如果TTS启用：从语音播放完毕开始计时
  - 如果TTS未启用：从文本输出完毕开始计时
- **输入重置**：用户正在输入时自动重置计时器
- **自动退出**：回复模式和历史模式超时后，先切换到输入模式，然后自动退出聊天

### 状态定义

| 状态 | 说明 | 超时行为 |
|------|------|----------|
| `reply_mode` | 等待用户点击继续（角色回复完成） | 切换到输入模式 → 自动退出聊天 |
| `history_mode` | 查看历史记录 | 切换到输入模式 → 自动退出聊天 |
| `input_mode` | 等待用户输入消息 | 降低好感，结束聊天 |
| `chatting` | AI正在回复或打字动画进行中 | 不做任何操作 |
| `idle` | 非聊天状态（聊天框不可见） | 提高回复意愿，尝试触发主动聊天 |

### 实现细节

#### 状态检测
```gdscript
# event_manager.gd
func _get_chat_state() -> String:
    if chat_dialog.is_history_visible:
        return "history_mode"
    elif chat_dialog.waiting_for_continue:
        return "reply_mode"
    elif chat_dialog.is_input_mode:
        return "input_mode"
    else:
        return "chatting"
```

#### 计时器重置时机
1. **用户输入时**：`input_field.text_changed` 信号触发
2. **句子显示完成时**：
   - 如果TTS启用：等待语音播放完毕后重置
   - 如果TTS未启用：文本输出完毕立即重置
3. **语音播放完毕时**：TTS服务通知聊天对话框（仅当TTS启用时）

#### 超时处理
```gdscript
# chat_dialog.gd
func _on_event_completed(event_name: String, result):
    if event_name == "idle_timeout":
        if result.message == "timeout_to_input":
            # 切换到输入模式，然后自动退出
            if is_history_visible:
                await _hide_history()
            elif waiting_for_continue:
                await _transition_to_input_mode()
            
            # 切换到输入模式后，自动退出聊天
            await get_tree().create_timer(0.5).timeout
            _on_end_button_pressed()
        elif result.message == "chat_idle_timeout":
            # 结束聊天
            _on_end_button_pressed()
```

## 4. 代码结构优化

### 移除的代码
- 删除了旧的`_process_tts_chunk()`函数（TTS处理逻辑已整合到句子提取中）
- 删除了`is_first_audio`标记（所有音频统一处理）

### 新增的函数
- `_extract_sentences_from_buffer()`：从缓冲中提取完整句子
- `_show_next_sentence()`：显示下一句话
- `_show_sentence_continue_indicator()`：显示句子继续指示器
- `_on_input_text_changed()`：输入框文本变化处理
- `_on_event_completed()`：事件完成处理
- `_notify_voice_finished()`：语音播放完毕通知

## 5. 用户体验改进

### 优点
1. **更自然的对话节奏**：逐句显示，避免长篇文字一次性出现
2. **更好的语音同步**：文本和语音同步播放，体验更流畅
3. **更智能的超时处理**：根据不同状态采取不同的超时策略
4. **更友好的交互**：用户输入时自动重置计时器，避免误触超时

### 注意事项
1. 如果AI响应中没有标点符号，句子会在流式响应完成后一次性显示
2. 语音播放是异步的，可能会比文字显示慢一些
3. 超时时间是随机的（120-180秒），避免过于机械
4. 回复模式和历史模式超时后会先切换到输入模式（0.5秒），然后自动退出聊天
5. TTS未启用时，以文本输出完毕作为计时器开始；TTS启用时，以语音播放完毕作为计时器开始

## 6. 测试建议

### 测试场景
1. **正常对话**：发送消息，观察逐句显示效果
2. **长回复**：触发包含多个句子的回复，测试分段显示
3. **语音同步**：启用TTS，测试语音和文字的同步性
4. **超时测试**：
   - 在回复模式下等待超时（应切换到输入模式）
   - 在输入模式下等待超时（应结束聊天）
   - 在输入时等待（应不会超时）
5. **历史记录**：打开历史记录后等待超时（应切换到输入模式）

### 调试输出
代码中包含了详细的调试输出，可以通过控制台观察：
- 句子提取过程
- 语音播放状态
- 超时检测状态
- 计时器重置事件

## 7. 未来改进方向

1. **可配置的分段策略**：允许用户选择是否启用分段显示
2. **更智能的静音检测**：使用音频分析算法精确检测静音
3. **语音播放进度显示**：显示当前语音播放进度
4. **快速跳过**：允许用户快速跳过所有句子
5. **自动继续选项**：添加自动继续下一句的选项（无需点击）
