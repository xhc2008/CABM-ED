# AI 角色对话系统集成指南

## 概述

本系统为游戏角色接入了 AI 对话能力，支持：
- 对话模型：与用户进行自然对话
- 总结模型：总结对话内容并保存到记忆
- 记忆系统：短期记忆（有限条目）+ 永久存储
- 完整日志：记录所有 API 调用

## 系统架构

### 1. 配置文件

#### `config/ai_config.json`
AI 模型配置，包含：
- `chat_model`: 对话模型配置
  - `model`: 模型名称（如 gpt-4o-mini）
  - `base_url`: API 地址
  - `system_prompt`: 系统提示词模板
  - `max_tokens`, `temperature`, `top_p`: 模型参数
- `summary_model`: 总结模型配置
- `memory`: 记忆配置
  - `max_memory_items`: 最大记忆条目数（默认 10）
  - `max_conversation_history`: 最大对话历史条数（默认 20）


#### `user://api_keys.json`
API 密钥配置（安全存储在用户目录）：
```json
{
  "openai_api_key": "sk-your-api-key-here"
}
```

**重要**: 首次使用需要手动创建此文件，或从 `config/api_keys.json` 复制。

### 2. 核心脚本

#### `scripts/ai_service.gd`
AI 服务自动加载单例，提供：
- `start_chat(user_message: String)`: 开始对话
- `end_chat()`: 结束对话并总结
- 信号：
  - `chat_response_received(response: String)`: 收到 AI 回复
  - `chat_error(error_message: String)`: 发生错误
  - `summary_completed(summary: String)`: 总结完成

### 3. 数据存储

#### 保存数据结构（`save_data_template.json`）
新增 `ai_data` 字段：
```json
{
  "ai_data": {
    "memory": [
      {
        "timestamp": "2025-10-12T14:30:00",
        "content": "用户和角色聊了关于天气的事情"
      }
    ],
    "storage": []  // 永久存储，不会被清理
  }
}
```

- `memory`: 短期记忆，超过 `max_memory_items` 会自动清理旧记录
- `storage`: 永久存储，保留所有历史记录

### 4. 日志系统

所有 API 调用都会记录到 `user://ai_logs/log.txt`，包括：
- 请求时间
- 请求类型（CHAT_REQUEST, CHAT_RESPONSE, SUMMARY_REQUEST, SUMMARY_RESPONSE）
- 完整的 messages 数组
- 响应内容

日志格式：
```
==================================================
时间: 2025-10-12 14:30:00
类型: CHAT_REQUEST
"messages": [
  {"role": "system","content": "你是小爱..."},
  {"role": "user","content": "你好"}
]
==================================================
```

## 工作流程

### 对话流程

1. **用户发起对话**
   - 用户在聊天框输入消息
   - `chat_dialog.gd` 调用 `AIService.start_chat(message)`

2. **构建提示词**
   - 系统提示词包含：
     - 角色设定
     - 当前场景和天气
     - 记忆上下文（之前发生的事情）
   - 对话历史（最近 N 条，由 `max_conversation_history` 控制）
   - 用户消息

3. **调用对话模型**
   - 发送请求到 API
   - 记录请求日志
   - 接收响应
   - 记录响应日志

4. **显示回复**
   - 通过信号 `chat_response_received` 返回
   - `chat_dialog.gd` 显示打字机效果

5. **继续对话**
   - 用户可以继续输入
   - 对话历史累积（但有上限）

### 总结流程

1. **用户结束对话**
   - 点击"结束"按钮
   - `chat_dialog.gd` 调用 `AIService.end_chat()`

2. **扁平化对话**
   - 将对话历史转换为文本格式：
   ```
   用户：你好
   小爱：你好呀！
   用户：今天天气怎么样？
   小爱：今天天气很好，阳光明媚！
   ```

3. **调用总结模型**
   - 系统提示词：要求总结对话
   - 用户消息：扁平化的对话文本
   - 记录请求和响应日志

4. **保存记忆**
   - 总结结果添加到 `memory` 和 `storage`
   - 检查 `memory` 是否超过 `max_memory_items`
   - 如果超过，保留最新的 N 条
   - 自动保存游戏

5. **清空对话历史**
   - 当前对话历史清空
   - 下次对话重新开始

## 提示词模板

### 对话模型系统提示词

```
你是{character_name}，你和用户（名字叫{user_name}）是朋友。你性格活泼开朗，喜欢和用户聊天。

当前环境：
- 场景：{current_scene}
- 天气：{current_weather}

之前发生的事情：
{memory_context}

现在，用户找你聊天。
```

占位符说明：
- `{character_name}`: 从配置读取的角色名字
- `{user_name}`: 从配置读取的用户名字
- `{current_scene}`: 从存档读取的当前场景
- `{current_weather}`: 当前天气（可扩展）
- `{memory_context}`: 从记忆构建的上下文

记忆上下文格式：
```
[14:30] 用户进入客厅
[14:35] 用户和你聊了关于天气的事情
[15:00] 用户和你聊了关于游戏的事情
```

### 总结模型系统提示词

```
你是一个总结专家。请将用户和角色的对话总结成简短的描述，格式为：用户和角色聊了关于XXX的事情。保持简洁，不超过50字。
```

## 配置步骤

### 1. 设置 API 密钥

创建 `user://api_keys.json`（Windows 路径通常是 `%APPDATA%\Godot\app_userdata\CABM-ED\api_keys.json`）：

```json
{
  "openai_api_key": "sk-your-actual-api-key"
}
```

或者在 `config/api_keys.json` 创建，首次运行时会自动复制到用户目录。

### 2. 调整 AI 配置

编辑 `config/ai_config.json`：

```json
{
  "chat_model": {
    "model": "gpt-4o-mini",  // 修改为你的模型
    "base_url": "https://api.openai.com/v1",  // 修改为你的 API 地址
    "system_prompt": "..."  // 自定义系统提示词
  },
  "character": {
    "name": "小爱",  // 修改角色名字
    "user_name": "主人"  // 修改用户称呼
  }
}
```

### 3. 测试

1. 运行游戏
2. 点击角色进入聊天
3. 输入消息测试对话
4. 结束对话查看总结
5. 检查日志文件 `user://ai_logs/log.txt`

## 扩展功能

### 添加天气系统

修改 `ai_service.gd` 的 `_build_system_prompt()` 函数：

```gdscript
func _build_system_prompt() -> String:
	var weather = _get_current_weather()  # 实现天气获取
	prompt = prompt.replace("{current_weather}", weather)
	return prompt
```

### 自定义记忆格式

修改 `_save_memory()` 函数，添加更多元数据：

```gdscript
var memory_item = {
	"timestamp": timestamp,
	"content": summary,
	"scene": save_mgr.get_character_scene(),
	"mood": save_mgr.get_mood()
}
```

### 添加情感分析

在总结后分析对话情感，更新角色状态：

```gdscript
func _handle_summary_response(response: Dictionary):
	var summary = message.content
	_save_memory(summary)
	_analyze_sentiment(summary)  # 新增情感分析

func _analyze_sentiment(summary: String):
	# 根据总结内容调整好感度、心情等
	pass
```

## 故障排查

### API 密钥错误
- 检查 `user://api_keys.json` 是否存在
- 确认密钥格式正确
- 查看控制台输出

### 无响应
- 检查网络连接
- 查看 `user://ai_logs/log.txt` 日志
- 确认 API 地址正确

### 记忆不保存
- 确认 `SaveManager` 正常工作
- 检查 `save_data_template.json` 包含 `ai_data` 字段
- 查看存档文件是否更新

## 安全注意事项

1. **API 密钥保护**
   - 永远不要将 `api_keys.json` 提交到版本控制
   - 已添加到 `.gitignore`
   - 使用 `user://` 目录存储

2. **日志隐私**
   - 日志包含完整对话内容
   - 定期清理或加密日志文件
   - 不要分享日志文件

3. **API 使用**
   - 注意 API 调用频率限制
   - 监控 token 使用量
   - 设置合理的 `max_tokens` 限制
