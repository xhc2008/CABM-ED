# AI Service 快速参考

## 使用方法（完全向后兼容）

### 获取 AI Service 实例

```gdscript
var ai_service = get_node("/root/AIService")
```

### 开始对话

```gdscript
# 用户主动对话
ai_service.start_chat("你好", "user_initiated")

# 角色主动对话
ai_service.start_chat("", "character_initiated")
```

### 结束对话

```gdscript
ai_service.end_chat()
```

### 访问对话历史

```gdscript
# 获取当前对话
var conversation = ai_service.current_conversation

# 手动添加到历史
ai_service.add_to_history("user", "用户消息")
ai_service.add_to_history("assistant", "AI回复")
```

### 访问配置和密钥

```gdscript
# 获取 API 密钥
var api_key = ai_service.api_key

# 获取配置
var config = ai_service.config
var chat_model = config.chat_model.model
var base_url = config.chat_model.base_url
```

### 处理 goto 字段

```gdscript
# 获取 goto 字段
var goto_index = ai_service.get_goto_field()
if goto_index >= 0:
    # 处理场景跳转
    pass

# 清除 goto 字段
ai_service.clear_goto_field()
```

### 连接信号

```gdscript
func _ready():
    var ai_service = get_node("/root/AIService")
    
    # 接收流式响应
    ai_service.chat_response_received.connect(_on_ai_response)
    
    # 响应完成
    ai_service.chat_response_completed.connect(_on_response_completed)
    
    # 字段提取完成
    ai_service.chat_fields_extracted.connect(_on_fields_extracted)
    
    # 错误处理
    ai_service.chat_error.connect(_on_ai_error)
    
    # 总结完成
    ai_service.summary_completed.connect(_on_summary_completed)

func _on_ai_response(response: String):
    print("收到响应: ", response)

func _on_response_completed():
    print("响应完成")

func _on_fields_extracted(fields: Dictionary):
    print("提取的字段: ", fields)

func _on_ai_error(error_message: String):
    print("错误: ", error_message)

func _on_summary_completed(summary: String):
    print("总结: ", summary)
```

## 内部模块（不建议直接访问）

虽然可以访问，但不建议直接使用内部模块：

```gdscript
# ❌ 不推荐
ai_service.config_loader.api_key
ai_service.http_client_module.start_stream_request()
ai_service.response_parser.reset()
ai_service.logger.log_api_call()

# ✅ 推荐：使用公共接口
ai_service.api_key
ai_service.start_chat()
# 日志自动记录，无需手动调用
```

## 常见问题

### Q: 如何检查 API 密钥是否配置？

```gdscript
if ai_service.api_key.is_empty():
    print("API 密钥未配置")
else:
    print("API 密钥已配置")
```

### Q: 如何获取对话轮数？

```gdscript
var turn_count = 0
for msg in ai_service.current_conversation:
    if msg.role == "user":
        turn_count += 1
print("对话轮数: ", turn_count)
```

### Q: 如何检查是否正在对话中？

```gdscript
if ai_service.is_chatting:
    print("正在对话中...")
else:
    print("空闲状态")
```

### Q: 重构后需要修改我的代码吗？

**不需要！** 所有公共接口保持完全兼容。如果你的代码之前能工作，重构后也能正常工作。

### Q: 如果遇到问题怎么办？

1. 检查控制台是否有错误信息
2. 查看日志文件：`user://ai_logs/log.txt`
3. 运行测试脚本：`scripts/test_ai_service.gd`
4. 查看文档：`docs/ai_service_refactoring.md`

## 性能提示

- 流式响应会实时发送 `chat_response_received` 信号
- `mood` 字段会在解析到时立即应用（实时更新）
- 其他字段（`will`, `like`, `goto`）在响应完成后统一应用
- 日志记录是异步的，不会阻塞主线程

## 调试技巧

### 启用详细日志

所有 API 调用都会自动记录到 `user://ai_logs/log.txt`，包括：
- 请求参数
- 响应内容
- 错误信息

### 查看日记

对话总结会保存到 `user://diary/YYYY-MM-DD.jsonl`，每天一个文件。

### 测试模块

运行 `scripts/test_ai_service.gd` 可以快速验证所有模块是否正常工作。
