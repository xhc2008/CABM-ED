# TTS 系统重写指南

## 概述

TTS 服务已完全重写，采用以下改进的流程：

1. **同时输出和播放**：第一句话开始输出时就立即开始播放
2. **用户点击中断**：用户点击时中断旧语音，立即播放新句子的语音
3. **智能等待机制**：
   - 句子开始输出了语音还没准备好 → 准备好后立即播放
   - 已经到下一句了旧句子语音还没准备好 → 放弃旧句子，立即处理新句子

## 核心概念

### 句子ID系统

每个句子都有唯一的ID，用于追踪其生命周期：

```
句子 #0 → 句子 #1 → 句子 #2 → ...
```

### 句子状态机

每个句子有以下状态：

- **"pending"**：已创建，等待翻译/TTS请求
- **"ready"**：音频已准备好，可以播放
- **"playing"**：正在播放
- **"abandoned"**：已放弃（用户点击跳过或新句子覆盖）

状态转移图：

```
    ┌─ pending ─→ ready ─→ playing ─→ [完成]
    │                ↓
    └─→ abandoned ─→ [忽略]
```

## API 变更

### 1. 调用 TTS 合成（不变）

```gdscript
var tts = get_node("/root/TTSService")
tts.synthesize_speech("第一句话")  # 返回句子 #0
tts.synthesize_speech("第二句话")  # 返回句子 #1
```

**内部行为**：
- `synthesize_speech()` 自动分配 sentence_id
- 立即发送翻译和TTS请求（如需要）
- 语音准备好时自动播放

### 2. 用户点击时通知 TTS（新增）

```gdscript
# 当用户点击"继续"显示新句子时
var tts = get_node("/root/TTSService")
tts.on_new_sentence_displayed(next_sentence_id)
```

这个调用会：
- 立即中断旧句子的播放（如正在播放）
- 放弃所有比新句子ID更大的待播放句子
- 取消对应的TTS请求
- 尝试立即播放新句子

## 集成到 ChatDialog

### 修改点在 `_on_sentence_ready_for_tts`

**原代码**（不变）：
```gdscript
func _on_sentence_ready_for_tts(text: String):
	"""句子准备好进行TTS处理"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	if tts.is_enabled and not text.is_empty():
		tts.synthesize_speech(text)
```

**关键点**：
- 每句话出现时自动调用 `synthesize_speech()`
- 系统自动分配和追踪 sentence_id
- 不需要手动传递 sentence_id

### 修改点在 `_on_continue_clicked`

**原代码**：
```gdscript
func _on_continue_clicked():
	if not waiting_for_continue:
		return
	
	waiting_for_continue = false
	input_handler.set_waiting_for_continue(false)
	ui_manager.hide_continue_indicator()
	
	if typing_manager.has_more_sentences():
		typing_manager.show_next_sentence()  # ← 这里需要修改
	# ...
```

**新代码**：
```gdscript
func _on_continue_clicked():
	if not waiting_for_continue:
		return
	
	waiting_for_continue = false
	input_handler.set_waiting_for_continue(false)
	ui_manager.hide_continue_indicator()
	
	if typing_manager.has_more_sentences():
		var next_sentence_id = typing_manager.show_next_sentence()
		
		# 通知 TTS 系统显示新句子
		if has_node("/root/TTSService"):
			var tts = get_node("/root/TTSService")
			tts.on_new_sentence_displayed(next_sentence_id)
	# ...
```

**需要修改的地方**：
1. `typing_manager.show_next_sentence()` 需要**返回新句子的ID**
2. 调用 `tts.on_new_sentence_displayed(next_sentence_id)` 通知TTS系统

### 修改 `TypingManager` 的 `show_next_sentence()`

需要让这个方法返回下一个句子的ID：

```gdscript
# 在 chat_dialog_typing.gd 中
func show_next_sentence() -> int:
	"""显示下一个句子，返回该句子的ID"""
	if has_more_sentences():
		# 获取下一个句子
		var next_sentence = sentences[current_sentence_index]
		current_sentence_index += 1
		
		# 返回该句子的 sentence_id
		# 这需要在 sentences 中存储 sentence_id
		return next_sentence.get("sentence_id", -1)
	
	return -1
```

## 新增的"句子ID追踪"系统

TTS 服务现在需要与 typing_manager 协调，为每个句子分配唯一ID。

### 建议的集成方式

在 `_on_sentence_ready_for_tts` 中追踪ID：

```gdscript
# 在 chat_dialog.gd 的开头添加
var sentence_id_map: Dictionary = {}  # {text: sentence_id}
var next_sentence_id_to_display: int = 0

func _on_sentence_ready_for_tts(text: String):
	"""句子准备好进行TTS处理"""
	if not has_node("/root/TTSService"):
		return
	
	var tts = get_node("/root/TTSService")
	if tts.is_enabled and not text.is_empty():
		# TTS 返回句子ID
		var sentence_id = tts.synthesize_speech(text)
		sentence_id_map[text] = sentence_id
```

## 状态转移示例

### 场景 1：正常播放

```
用户看到第1句 → synthesize_speech("句子1") → 句子1: pending
                                           ↓
                    (翻译和TTS进行中)   → 句子1: ready
                                           ↓
                    用户听到句子1的语音    → 句子1: playing
                                           ↓
                    播放完成              → 句子1: [完成]
```

### 场景 2：用户点击跳过

```
用户看到第1句 → 句子1: pending → 句子1: ready
用户看到第2句 → 句子2: pending → 句子1: playing (正在播放)
用户点击跳过 → on_new_sentence_displayed(2) 调用
              → 句子1: 停止播放
              → 句子2/3/4... 的 ID > 2 的都标记为 abandoned
              → 尝试播放句子2
              ↓
              如果句子2的音频已准备好 → 立即播放
              如果句子2的音频还在等待   → 等待，准备好时播放
```

### 场景 3：快速连续点击（快速前进）

```
句子1: ready → playing
用户点击1    → on_new_sentence_displayed(2) → 句子2等待
用户点击2    → on_new_sentence_displayed(3) → 句子3等待
用户点击3    → on_new_sentence_displayed(4) → 句子4等待
用户点击4    → on_new_sentence_displayed(5) → 播放句子5

结果：ID >= 2 的待播放请求都被取消，直接播放句子5
```

## 调试建议

### 启用详细日志

TTS 服务会输出详细的日志：

```
=== 新句子 #0 (zh) ===
文本: 第一句话
=== 开始TTS请求 句子 #0 (zh) ===
TTS请求 #0 已发送
句子 #0 接收到音频数据: 12345 字节
句子 #0 状态更新为 ready
=== 开始播放句子 #0 ===
```

### 常见问题

1. **句子没有播放**
   - 检查 `sentence_state` 中的状态
   - 确保 `is_enabled` 为 true
   - 检查 voice_uri 是否已上传

2. **点击后旧音频还在播放**
   - 确保调用了 `on_new_sentence_displayed()`
   - 检查 `playing_sentence_id` 是否正确更新

3. **某些句子被跳过**
   - 这是正常的，快速前进时会放弃中间的句子
   - 可以在日志中看到 "已被放弃（当前显示 #X）"

## 清理资源

清空所有队列：

```gdscript
var tts = get_node("/root/TTSService")
tts.clear_queue()  # 取消所有请求，停止播放
```

这会：
- 取消所有进行中的HTTP请求
- 清空所有句子状态和音频数据
- 停止当前播放
- 重置所有计数器

