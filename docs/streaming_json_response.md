# 流式JSON响应实现文档

## 概述

本文档描述了AI服务从等待完整响应改为流式JSON响应的实现方案。

## 主要修改

### 1. AI配置更新 (`config/ai_config.json`)

- 模型现在返回JSON格式，包含以下字段：
  - `mood`: 当前心情（整数，0-6）
  - `msg`: 回复消息（字符串）
  - `will`: 互动意愿增量（-10到10）
  - `like`: 好感度增量（-10到10）

### 2. AI服务 (`scripts/ai_service.gd`)

#### 新增变量
```gdscript
var http_client: HTTPClient  # 用于流式请求
var stream_buffer: String = ""  # 完整响应缓冲
var msg_buffer: String = ""  # msg字段内容缓冲
var extracted_fields: Dictionary = {}  # 其他字段
var is_streaming: bool = false
```

#### 核心功能

**流式连接处理**
- 使用 `HTTPClient` 替代 `HTTPRequest` 进行流式请求
- 在 `_process()` 中持续轮询连接状态
- 实时接收数据块

**实时msg提取**
- `_extract_msg_from_buffer()`: 从不完整的JSON中提取msg字段
- 不等待JSON完整，逐字符解析
- 处理转义字符（`\"`, `\n`, `\t`, `\\`）
- 只发送新增的内容到UI

**上下文管理**
- 对话历史保存完整JSON（`stream_buffer`）
- 发送给总结模型时只提取msg内容（`_flatten_conversation()`）

### 3. 对话界面 (`scripts/chat_dialog.gd`)

#### 新增变量
```gdscript
var display_buffer: String = ""  # 待显示内容
var displayed_text: String = ""  # 已显示内容
var is_receiving_stream: bool = false  # 流式接收状态
```

#### Buffer机制
- 接收到新内容时添加到 `display_buffer`
- 打字机效果从buffer中按速度输出
- 输出速度由 `TYPING_SPEED` 常量控制（0.05秒/字符）

#### 流式响应处理
1. `_on_ai_response()`: 接收增量内容，添加到buffer
2. `_on_typing_timer_timeout()`: 按速度从buffer输出
3. `_on_ai_response_completed()`: 流式结束，显示继续指示器

## 工作流程

### 用户发送消息
1. 用户输入 → `start_chat()`
2. 构建请求，启用 `"stream": true`
3. 使用 `HTTPClient` 建立连接

### 接收流式响应
1. `_process()` 轮询连接状态
2. `_receive_stream_chunk()` 接收数据块
3. `_process_stream_data()` 解析SSE格式
4. `_parse_stream_chunk()` 提取delta内容
5. `_extract_msg_from_buffer()` 实时提取msg字段
6. 发送 `chat_response_received` 信号

### UI显示
1. `chat_dialog` 接收增量内容
2. 添加到 `display_buffer`
3. 打字机定时器按速度输出
4. 流式结束后显示继续指示器

### 对话结束
1. 调用 `end_chat()`
2. `_flatten_conversation()` 提取所有msg内容
3. 发送给总结模型
4. 保存总结到记忆

## 关键特性

### 不完整JSON解析
- 不使用 `JSON.parse()`，因为流式期间JSON不完整
- 手动查找 `"msg"` 字段和引号
- 逐字符提取，处理转义

### Markdown代码块处理
- 自动检测并移除 ```json``` 包裹
- 支持 ```json 和 ``` 两种格式
- 在提取msg字段和解析完整JSON时都会处理

### 速度控制
- Buffer机制确保即使接收很快，输出也有最大速度
- 用户体验更好，可以看到"打字"效果

### 字段提取
- `msg`: 实时提取并显示
- `mood`, `will`, `like`: 在流式结束后从完整JSON提取
- 为后续功能预留（目前不操作）

## 注意事项

1. **转义处理**: 必须正确处理JSON转义字符
2. **边界检查**: 提取时检查字符串边界，避免越界
3. **状态管理**: 正确管理 `is_streaming` 和 `is_receiving_stream` 状态
4. **错误处理**: 连接失败、解析错误等情况的处理
5. **Markdown包裹**: AI可能用 ```json``` 包裹响应，需要自动移除
6. **缓冲区分离**: `sse_buffer` 用于SSE行解析，`json_response_buffer` 用于存储完整JSON

## 未来扩展

- 使用提取的 `mood` 字段更新角色表情
- 使用 `will` 和 `like` 更新角色状态
- 支持更多JSON字段
- 优化提取算法性能
