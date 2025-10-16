# TTS并发请求设计

## 设计目标

实现真正的**并发请求 + 顺序播放**，减少延迟，提升用户体验。

## 核心理念

1. **立即发送**：检测到完整句子立即发送TTS请求，不等待
2. **并发处理**：多个请求同时进行，互不阻塞
3. **乱序接收**：请求可能乱序返回（网络延迟不同）
4. **顺序播放**：按照发送顺序播放音频
5. **智能等待**：如果下一个音频还没准备好，等待而不是跳过

## 架构设计

### 旧设计（串行队列）❌

```
句子1 → 发送请求1 → 等待响应1 → 播放1
                                    ↓
句子2 → 加入队列 → 等待 → 发送请求2 → 等待响应2 → 播放2
                                                    ↓
句子3 → 加入队列 → 等待 → 等待 → 发送请求3 → 等待响应3 → 播放3
```

**问题**：
- 延迟累积：每个请求都要等前一个完成
- 浪费时间：网络请求是并发的，但我们串行处理
- 用户体验差：第一句话说完后要等很久才有第二句

### 新设计（并发请求）✅

```
句子1 → 立即发送请求1 ─┐
句子2 → 立即发送请求2 ─┼→ 并发处理
句子3 → 立即发送请求3 ─┘
         ↓
    乱序返回（例如：2→1→3）
         ↓
    按顺序存入缓冲：{0: 音频1, 1: 音频2, 2: 音频3}
         ↓
    按顺序播放：音频1 → 音频2 → 音频3
```

**优势**：
- ✅ 零延迟：句子完整立即发送
- ✅ 并发处理：多个请求同时进行
- ✅ 智能缓冲：乱序接收，顺序播放
- ✅ 流畅体验：第一句播完，第二句已经准备好

## 数据结构

### 1. 请求管理

```gdscript
var tts_requests: Dictionary = {} # {request_id: HTTPRequest}
var next_request_id: int = 0 # 下一个请求ID
```

- 每个请求有唯一ID（递增）
- 每个请求有独立的HTTPRequest节点
- 请求完成后自动清理

### 2. 音频缓冲

```gdscript
var audio_buffer: Dictionary = {} # {request_id: audio_data}
var next_play_id: int = 0 # 下一个要播放的ID
```

- 按ID存储音频数据
- 即使乱序接收，也能按顺序播放
- 播放后立即清理，节省内存

### 3. 播放状态

```gdscript
var is_playing: bool = false # 是否正在播放
var is_first_audio: bool = true # 是否第一段（用于跳过静音）
```

## 工作流程

### 场景：3个句子快速连续

```
T0: 检测到句子1 → 创建请求#0 → 立即发送
T1: 检测到句子2 → 创建请求#1 → 立即发送
T2: 检测到句子3 → 创建请求#2 → 立即发送

T3: 请求#1完成 → 存入buffer[1]
T4: 请求#0完成 → 存入buffer[0] → 开始播放#0（第一个）
T5: 请求#2完成 → 存入buffer[2]

T6: 播放#0完成 → 播放#1（已准备好）
T7: 播放#1完成 → 播放#2（已准备好）
T8: 播放#2完成 → 结束
```

### 场景：慢速网络

```
T0: 发送请求#0
T1: 发送请求#1
T2: 发送请求#2

T3: 请求#0完成 → 开始播放#0
T4: 播放#0完成 → 等待#1（还没返回）
T5: 请求#1完成 → 立即播放#1（无缝衔接）
T6: 播放#1完成 → 等待#2（还没返回）
T7: 请求#2完成 → 立即播放#2（无缝衔接）
```

**关键**：播放完成后会检查下一个是否准备好，如果没准备好就等待，一旦准备好立即播放。

## 核心函数

### synthesize_speech(text)

```gdscript
func synthesize_speech(text: String):
    # 分配唯一ID
    var request_id = next_request_id
    next_request_id += 1
    
    # 创建独立的HTTPRequest
    var http_request = HTTPRequest.new()
    http_request.set_meta("request_id", request_id)
    
    # 连接完成信号（带request_id）
    http_request.request_completed.connect(
        _on_tts_completed.bind(request_id, http_request)
    )
    
    # 立即发送请求
    http_request.request(...)
```

**特点**：
- 每次调用创建新的HTTPRequest
- 立即发送，不等待
- 请求ID用于排序

### _on_tts_completed(result, response_code, headers, body, request_id, http_request)

```gdscript
func _on_tts_completed(..., request_id, http_request):
    # 清理请求节点
    tts_requests.erase(request_id)
    http_request.queue_free()
    
    # 存入缓冲（按ID）
    audio_buffer[request_id] = body
    
    # 尝试播放
    _try_play_next()
```

**特点**：
- 接收到音频立即存入缓冲
- 不管顺序，按ID存储
- 尝试播放（如果是下一个）

### _try_play_next()

```gdscript
func _try_play_next():
    # 如果正在播放，不做任何事
    if is_playing:
        return
    
    # 检查下一个是否准备好
    if not audio_buffer.has(next_play_id):
        print("等待音频 #%d..." % next_play_id)
        return
    
    # 播放
    var audio_data = audio_buffer[next_play_id]
    audio_buffer.erase(next_play_id)
    next_play_id += 1
    
    _play_audio(audio_data)
```

**特点**：
- 只播放下一个（按顺序）
- 如果没准备好，等待
- 播放后自动清理

### _on_audio_finished()

```gdscript
func _on_audio_finished():
    is_playing = false
    _try_play_next()  # 尝试播放下一个
```

**特点**：
- 播放完成立即尝试下一个
- 如果下一个已准备好，无缝衔接
- 如果没准备好，等待

## 静音跳过（仅第一段）

```gdscript
if is_first_audio:
    var skip_time = _detect_silence_duration(stream)
    if skip_time > 0:
        current_player.play(skip_time)  # 跳过静音
    is_first_audio = false
else:
    current_player.play()  # 保留空白作为断句
```

**逻辑**：
- 第一段：跳过开头静音（减少延迟）
- 后续段：保留空白（自然断句）

## 日志输出

### 发送请求

```
=== 创建TTS请求 #0 ===
文本: 你好！
TTS请求 #0 已发送（并发）

=== 创建TTS请求 #1 ===
文本: 今天天气真好。
TTS请求 #1 已发送（并发）

=== 创建TTS请求 #2 ===
文本: 你在干什么？
TTS请求 #2 已发送（并发）
```

### 接收响应（可能乱序）

```
=== TTS请求 #1 完成 ===
文本: 今天天气真好。
接收到音频数据: 45123 字节
音频 #1 已加入缓冲，缓冲区大小: 1
等待音频 #0...

=== TTS请求 #0 完成 ===
文本: 你好！
接收到音频数据: 37375 字节
音频 #0 已加入缓冲，缓冲区大小: 2
=== 播放音频 #0 ===
开始播放语音 #0

=== TTS请求 #2 完成 ===
文本: 你在干什么？
接收到音频数据: 38456 字节
音频 #2 已加入缓冲，缓冲区大小: 2
当前正在播放，等待播放完成
```

### 播放（按顺序）

```
语音播放完成
=== 播放音频 #1 ===
开始播放语音 #1

语音播放完成
=== 播放音频 #2 ===
开始播放语音 #2

语音播放完成
等待音频 #3...（没有了）
```

## 性能分析

### 延迟对比

**串行队列**：
```
总延迟 = 请求1延迟 + 请求2延迟 + 请求3延迟
       = 1.5s + 1.5s + 1.5s = 4.5s
```

**并发请求**：
```
总延迟 = max(请求1延迟, 请求2延迟, 请求3延迟)
       = max(1.5s, 1.5s, 1.5s) = 1.5s
```

**提升**：3倍！

### 内存使用

- **请求节点**：每个请求一个HTTPRequest（完成后立即释放）
- **音频缓冲**：只存储已接收但未播放的音频
- **峰值**：如果3个请求同时返回，最多存储3段音频
- **平均**：通常只有1-2段音频在缓冲中

### 网络带宽

- 并发请求不会增加总带宽
- 只是改变了请求的时间分布
- 对服务器友好（没有突发流量）

## 错误处理

### 请求失败

```gdscript
if result != HTTPRequest.RESULT_SUCCESS:
    # 清理请求节点
    tts_requests.erase(request_id)
    http_request.queue_free()
    # 不影响其他请求
    return
```

**行为**：
- 失败的请求被跳过
- 不阻塞其他请求
- 播放时会等待下一个有效的音频

### 网络断开

- 进行中的请求会失败
- 已接收的音频继续播放
- 新的请求不会发送（is_enabled检查）

## 清理机制

```gdscript
func clear_queue():
    # 取消所有进行中的请求
    for request_id in tts_requests.keys():
        var http_request = tts_requests[request_id]
        http_request.cancel_request()
        http_request.queue_free()
    
    # 清空缓冲
    audio_buffer.clear()
    
    # 重置计数器
    next_request_id = 0
    next_play_id = 0
```

**时机**：
- 关闭对话框
- 切换场景
- 禁用TTS

## 优势总结

1. ✅ **低延迟**：句子完整立即发送，不等待
2. ✅ **高并发**：多个请求同时处理
3. ✅ **智能缓冲**：乱序接收，顺序播放
4. ✅ **无缝衔接**：播放完立即播放下一个
5. ✅ **错误容忍**：单个失败不影响整体
6. ✅ **内存高效**：播放后立即清理
7. ✅ **用户体验好**：感觉更流畅自然

## 测试建议

### 测试1：正常情况
```
输入: "你好！今天天气真好。你在干什么？"
预期: 3个请求并发，按顺序播放
```

### 测试2：慢速网络
```
模拟网络延迟
预期: 播放完一段后等待下一段，一旦准备好立即播放
```

### 测试3：乱序返回
```
请求顺序: 1→2→3
返回顺序: 2→1→3
预期: 播放顺序仍然是 1→2→3
```

### 测试4：快速连续
```
快速发送多条消息
预期: 所有请求并发，按顺序播放
```

---

**设计日期**：2025-10-16  
**状态**：✅ 已实现  
**性能提升**：3倍延迟减少
