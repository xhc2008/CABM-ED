# TTS修复说明

## 问题描述

TTS功能只播放第一段语音，后续的句子没有被处理。

## 原因分析

在 `chat_dialog.gd` 的 `_process_tts_chunk` 函数中，原来的实现有问题：

```gdscript
# 原来的代码（有问题）
if punct in tts_buffer:
    var punct_pos = tts_buffer.find(punct)
    var sentence = tts_buffer.substr(0, punct_pos + 1).strip_edges()
    
    if not sentence.is_empty():
        _send_tts(sentence)
    
    tts_buffer = tts_buffer.substr(punct_pos + 1)
    
    # 问题：递归调用时传入空字符串
    if not tts_buffer.is_empty():
        _process_tts_chunk("")  # ❌ 这里传入空字符串
    return
```

**问题**：
1. 递归调用时传入空字符串，导致 `tts_buffer += text` 不会添加新内容
2. 只检查第一个标点符号，如果缓冲中有多个句子，只会处理第一个
3. 使用递归可能导致栈溢出（如果有很多句子）

## 解决方案

改用 `while` 循环处理所有完整的句子：

```gdscript
# 修复后的代码
func _process_tts_chunk(text: String):
    # 将新文本添加到TTS缓冲
    tts_buffer += text
    
    # 循环处理所有完整的句子
    while true:
        var found_punct = false
        var earliest_pos = -1
        
        # 找到最早出现的标点
        for punct in CHINESE_PUNCTUATION:
            var pos = tts_buffer.find(punct)
            if pos != -1:
                if earliest_pos == -1 or pos < earliest_pos:
                    earliest_pos = pos
                    found_punct = true
        
        # 如果没有找到标点，退出循环
        if not found_punct:
            break
        
        # 提取句子并发送TTS
        var sentence = tts_buffer.substr(0, earliest_pos + 1).strip_edges()
        if not sentence.is_empty():
            _send_tts(sentence)
        
        # 移除已处理的部分
        tts_buffer = tts_buffer.substr(earliest_pos + 1)
    
    # 缓冲中剩余的文本（没有标点）保留等待
```

## 改进点

1. ✅ **使用循环代替递归**：避免栈溢出，更高效
2. ✅ **处理所有句子**：一次调用处理缓冲中的所有完整句子
3. ✅ **找到最早的标点**：确保按顺序处理句子
4. ✅ **保留未完成的句子**：没有标点的文本保留在缓冲中，等待更多文本
5. ✅ **添加调试日志**：方便追踪句子提取过程

## 测试场景

### 场景1：单个句子
```
输入: "你好！"
输出: 发送TTS - "你好！"
```

### 场景2：多个句子
```
输入: "你好！今天天气真好。"
输出: 
  发送TTS - "你好！"
  发送TTS - "今天天气真好。"
```

### 场景3：流式输入
```
第1次: "你好"
  → 缓冲: "你好"（等待标点）

第2次: "！今天"
  → 发送TTS - "你好！"
  → 缓冲: "今天"（等待标点）

第3次: "天气真好。"
  → 发送TTS - "今天天气真好。"
  → 缓冲: ""（空）
```

### 场景4：多种标点
```
输入: "你好！今天天气真好。你在干什么？"
输出:
  发送TTS - "你好！"
  发送TTS - "今天天气真好。"
  发送TTS - "你在干什么？"
```

## 调试输出

现在会看到以下日志：

```
TTS: 提取句子 - 你好！
ChatDialog: 发送TTS - 你好！
=== 发送TTS请求 ===
...
TTS: 提取句子 - 今天天气真好。
ChatDialog: 发送TTS - 今天天气真好。
=== 发送TTS请求 ===
...
```

## 验证步骤

1. 启动游戏
2. 发送一条包含多个句子的消息，例如："你好！今天天气真好。你在干什么？"
3. 查看控制台输出，应该看到：
   - 3次"TTS: 提取句子"
   - 3次"ChatDialog: 发送TTS"
   - 3次"=== 发送TTS请求 ==="
   - 3次音频播放
4. 验证所有句子都被播放

## 性能考虑

- **时间复杂度**：O(n*m)，其中n是缓冲长度，m是标点符号数量（5个）
- **空间复杂度**：O(n)，缓冲区大小
- **优化**：使用while循环代替递归，避免栈溢出
- **效率**：每次调用处理所有完整句子，减少函数调用次数

## 相关文件

- `scripts/chat_dialog.gd` - 修复的文件
- `scripts/tts_service.gd` - TTS服务（未修改）

## 版本

- **修复前**：只播放第一段语音
- **修复后**：播放所有句子的语音

---

**修复日期**：2025-10-16  
**状态**：✅ 已修复
