# AI Service 重构说明

## 概述

原 `ai_service.gd` 文件（1360行）已被拆分为多个模块化文件，提高代码可维护性和可读性。

## 文件结构

### 1. `scripts/ai_service.gd` (主服务)
- **职责**: 核心协调逻辑，对话管理，API 调用协调
- **行数**: ~550行
- **主要功能**:
  - 对话会话管理 (`start_chat`, `end_chat`)
  - 协调各子模块工作
  - 处理总结、称呼、关系模型的调用
  - 对外提供统一接口

### 2. `scripts/ai_http_client.gd` (HTTP 客户端)
- **职责**: 处理流式和非流式 HTTP 请求
- **行数**: ~100行
- **主要功能**:
  - 流式 HTTP 连接管理
  - SSE (Server-Sent Events) 数据接收
  - 超时控制
  - 错误处理

### 3. `scripts/ai_config_loader.gd` (配置加载器)
- **职责**: 加载和管理 AI 配置和 API 密钥
- **行数**: ~120行
- **主要功能**:
  - 加载 `ai_config.json`
  - 加载 API 密钥（支持新旧格式）
  - 配置验证和错误处理

### 4. `scripts/ai_response_parser.gd` (响应解析器)
- **职责**: 解析流式响应和提取字段
- **行数**: ~200行
- **主要功能**:
  - SSE 格式解析
  - 实时提取 `msg` 字段
  - 实时提取 `mood` 字段
  - 完整响应解析（提取 `will`, `like`, `goto` 字段）

### 5. `scripts/ai_logger.gd` (日志记录器)
- **职责**: 记录 API 调用、响应和错误
- **行数**: ~150行
- **主要功能**:
  - API 请求日志
  - API 响应日志
  - 错误日志
  - 日记保存

## 模块间通信

```
ai_service.gd (主服务)
    ├── ai_config_loader.gd (配置)
    ├── ai_http_client.gd (HTTP 客户端)
    │   └── 信号: stream_chunk_received, stream_completed, stream_error
    ├── ai_response_parser.gd (响应解析)
    │   └── 信号: content_received, mood_extracted
    └── ai_logger.gd (日志)
```

## 公共接口（保持不变）

以下接口保持与原版本完全兼容：

### 方法
- `start_chat(user_message: String, trigger_mode: String)`
- `end_chat()`
- `add_to_history(role: String, content: String)`
- `get_goto_field() -> int`
- `clear_goto_field()`

### 属性（只读）
- `current_conversation: Array` - 当前对话历史
- `api_key: String` - API 密钥（通过 getter 访问 config_loader.api_key）
- `config: Dictionary` - AI 配置（通过 getter 访问 config_loader.config）

## 信号（保持不变）

- `chat_response_received(response: String)`
- `chat_response_completed()`
- `chat_fields_extracted(fields: Dictionary)`
- `chat_error(error_message: String)`
- `summary_completed(summary: String)`

## 优势

1. **可维护性**: 每个模块职责单一，易于理解和修改
2. **可测试性**: 各模块可独立测试
3. **可扩展性**: 新增功能时只需修改相关模块
4. **代码复用**: 子模块可在其他地方复用
5. **向后兼容**: 对外接口完全保持不变

## 迁移说明

无需任何迁移工作！所有使用 `AIService` 的代码（如 `chat_dialog.gd`）无需修改，可直接使用。

## 测试建议

1. 测试对话功能（用户主动、角色主动）
2. 测试流式响应和字段提取
3. 测试总结、称呼、关系模型调用
4. 测试错误处理和超时机制
5. 检查日志文件是否正常生成
