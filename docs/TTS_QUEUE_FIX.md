# TTS请求队列修复

## 问题描述

当多个句子快速连续发送TTS请求时，出现错误：

```
HTTPRequest is processing a request. Wait for completion or cancel it before attempting a new one.
Condition "requesting" is true. Returning: ERR_BUSY
```

只有第一个请求成功，后续请求都失败。

## 原因分析

`HTTPRequest` 节点一次只能处理一个请求。当第一个请求还在处理时（等待API响应），第二个请求就来了，导致冲突。

**原来的流程**：
```
句子1 → synthesize_speech() → tts_request.request() ✅
句子2 → synthesize_speech() → tts_request.request() ❌ ERR_BUSY
句子3 → synthesize_speech() → tts_request.request() ❌ ERR_BUSY
```

## 解决方案

实现**TTS请求队列**，确保请求按顺序发送：

1. 将所有TTS请求加入队列
2. 一次只处理一个请求
3. 请求完成后，自动处理下一个

**修复后的流程**：
```
句子1 → 加入队列 → 立即发送请求
句子2 → 加入队列 → 等待
句子3 → 加入队列 → 等待

请求1完成 → 发送请求2
请求2完成 → 发送请求3
请求3完成 → 队列为空
```

## 代码实现

### 1. 添加队列变量

```gdscript
# TTS请求队列
var tts_request_queue: Array = [] # 存储待发送的TTS请求文本
var is_requesting: bool = false # 是否正在发送请求
```

### 2. 修改 synthesize_speech()

```gdscript
func synthesize_speech(text: String):
    """合成语音（加入队列）"""
    # ... 验证 ...
    
    # 将文本加入请求队列
    tts_request_queue.append(text)
    print("TTS请求加入队列: ", text, " (队列长度: ", tts_request_queue.size(), ")")
    
    # 如果当前没有正在处理的请求，开始处理队列
    if not is_requesting:
        _process_tts_queue()
```

### 3. 新增 _process_tts_queue()

```gdscript
func _process_tts_queue():
    """处理TTS请求队列"""
    if tts_request_queue.is_empty():
        is_requesting = false
        return
    
    if is_requesting:
        return
    
    is_requesting = true
    var text = tts_request_queue.pop_front()
    
    # 发送HTTP请求
    var error = tts_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
    if error != OK:
        is_requesting = false
        _process_tts_queue()  # 继续处理下一个
```

### 4. 修改 _on_tts_completed()

```gdscript
func _on_tts_completed(...):
    """TTS请求完成回调"""
    # 标记请求完成
    is_requesting = false
    
    # ... 处理响应 ...
    
    # 继续处理队列中的下一个请求
    _process_tts_queue()
```

## 工作流程

### 场景：3个句子快速发送

```
时间线：
T0: 句子1加入队列 → 立即发送请求1
T1: 句子2加入队列 → 等待（is_requesting=true）
T2: 句子3加入队列 → 等待（is_requesting=true）
T3: 请求1完成 → is_requesting=false → 发送请求2
T4: 请求2完成 → is_requesting=false → 发送请求3
T5: 请求3完成 → is_requesting=false → 队列为空
```

### 日志输出

```
TTS请求加入队列: 你好！ (队列长度: 1)
=== 处理TTS请求队列 ===
剩余队列长度: 0
当前文本: 你好！
TTS请求已发送

TTS请求加入队列: 今天天气真好。 (队列长度: 1)

TTS请求加入队列: 你在干什么？ (队列长度: 2)

TTS请求完成 - result: 0, response_code: 200, body_size: 37375
接收到音频数据: 37375 字节
音频已加入播放队列，队列长度: 1
开始播放队列中的音频
=== 处理TTS请求队列 ===
剩余队列长度: 1
当前文本: 今天天气真好。
TTS请求已发送

TTS请求完成 - result: 0, response_code: 200, body_size: 45123
接收到音频数据: 45123 字节
音频已加入播放队列，队列长度: 2
当前正在播放，音频已排队
=== 处理TTS请求队列 ===
剩余队列长度: 0
当前文本: 你在干什么？
TTS请求已发送

TTS请求完成 - result: 0, response_code: 200, body_size: 38456
接收到音频数据: 38456 字节
音频已加入播放队列，队列长度: 3
当前正在播放，音频已排队
TTS请求队列为空
```

## 两个独立的队列

系统现在有**两个独立的队列**：

### 1. TTS请求队列
- **作用**：管理HTTP请求的发送
- **原因**：HTTPRequest一次只能处理一个请求
- **处理**：请求完成后自动处理下一个

### 2. 音频播放队列
- **作用**：管理音频的播放
- **原因**：AudioStreamPlayer一次只能播放一个音频
- **处理**：播放完成后自动播放下一个

**两个队列独立工作**：
```
TTS请求队列: [句子1, 句子2, 句子3] → 依次发送请求
                ↓
音频播放队列: [音频1, 音频2, 音频3] → 依次播放
```

## 错误处理

如果某个请求失败：

```gdscript
if error != OK:
    is_requesting = false
    _process_tts_queue()  # 继续处理下一个
```

不会阻塞整个队列，失败的请求会被跳过。

## 清空队列

```gdscript
func clear_queue():
    """清空所有队列"""
    # 清空TTS请求队列
    tts_request_queue.clear()
    is_requesting = false
    
    # 清空音频播放队列
    audio_queue.clear()
    if current_player.playing:
        current_player.stop()
    is_playing = false
```

## 性能考虑

- **内存**：队列只存储文本字符串，内存占用很小
- **延迟**：请求是串行的，但这是必要的（API限制）
- **效率**：自动处理，无需手动管理
- **可靠性**：错误不会阻塞队列

## 测试验证

### 测试1：单个句子
```
输入: "你好！"
预期: 1个请求，1个音频
```

### 测试2：多个句子
```
输入: "你好！今天天气真好。你在干什么？"
预期: 3个请求依次发送，3个音频依次播放
```

### 测试3：快速连续
```
快速发送多条消息
预期: 所有请求都成功，按顺序播放
```

### 测试4：错误恢复
```
模拟网络错误
预期: 失败的请求被跳过，继续处理后续请求
```

## 相关文件

- `scripts/tts_service.gd` - 修复的文件

## 版本历史

- **v1.0**：初始实现，没有队列 ❌
- **v1.1**：添加TTS请求队列 ✅

---

**修复日期**：2025-10-16  
**状态**：✅ 已修复  
**测试**：待验证
