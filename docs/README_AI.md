# AI 对话系统

本项目已集成 AI 对话功能，角色可以通过 OpenAI API（或兼容接口）进行智能对话。

## 快速开始

### 1. 配置 API 密钥

**方法一：使用界面设置**（最简单）

1. 运行游戏
2. 在左侧控制栏找到"AI 设置"区域
3. 输入你的 API 密钥（如 `sk-...`）
4. 点击"保存密钥"
5. 看到"✓ 已保存"提示即可

**方法二：手动创建文件**

Windows 路径：`%APPDATA%\Godot\app_userdata\CABM-ED\api_keys.json`

创建文件内容：
```json
{
  "openai_api_key": "sk-your-api-key-here"
}
```

### 2. 运行游戏

直接运行，系统会自动加载配置。

### 3. 开始对话

1. 点击角色进入聊天
2. 输入消息
3. 等待 AI 回复
4. 点击"结束"按钮会自动总结对话

## 功能特性

✅ **智能对话**：基于 GPT 模型的自然对话  
✅ **记忆系统**：记住之前的对话内容  
✅ **自动总结**：对话结束后自动生成摘要  
✅ **完整日志**：记录所有 API 调用详情  
✅ **双层存储**：短期记忆 + 永久存储  

## 配置说明

### AI 配置文件：`config/ai_config.json`

```json
{
  "chat_model": {
    "model": "gpt-4o-mini",
    "base_url": "https://api.openai.com/v1",
    "max_tokens": 512,
    "temperature": 0.8
  },
  "summary_model": {
    "model": "gpt-4o-mini",
    "max_tokens": 256,
    "temperature": 0.3
  },
  "memory": {
    "max_memory_items": 10,
    "max_conversation_history": 20
  }
}
```

### 可配置项

- **模型设置**：修改 `model` 和 `base_url` 使用不同的 API
- **角色名字**：在 `config/app_config.json` 修改 `character_name` 和 `user_name`
- **记忆容量**：调整 `max_memory_items`（短期记忆条数）
- **对话历史**：调整 `max_conversation_history`（对话上下文长度）
- **系统提示词**：自定义 `system_prompt` 改变角色性格

## 数据存储

### 存档结构

存档文件（`user://saves/save_slot_1.json`）新增 `ai_data` 字段：

```json
{
  "ai_data": {
    "memory": [
      {
        "timestamp": "2025-10-12T14:30:00",
        "content": "用户和角色聊了关于天气的事情"
      }
    ],
    "storage": []
  }
}
```

- **memory**：短期记忆，超过上限会自动清理
- **storage**：永久存储，保留所有历史

### 日志文件

完整的 API 调用日志保存在：`user://ai_logs/log.txt`

包含：
- 请求时间和类型
- 完整的 messages 数组
- AI 响应内容

## 工作流程

### 对话流程

```
用户输入消息
    ↓
构建系统提示词（包含角色设定、场景、记忆）
    ↓
添加对话历史（最近 N 条）
    ↓
调用对话模型 API
    ↓
显示 AI 回复（打字机效果）
    ↓
继续对话...
```

### 总结流程

```
用户点击"结束"
    ↓
扁平化对话历史
    ↓
调用总结模型 API
    ↓
生成对话摘要
    ↓
保存到 memory 和 storage
    ↓
检查并清理超出上限的记忆
    ↓
清空当前对话历史
```

## 系统提示词

### 对话模型

```
你是{character_name}，你和用户（名字叫{user_name}）是朋友。
你性格活泼开朗，喜欢和用户聊天。

当前环境：
- 场景：{current_scene}
- 天气：{current_weather}

之前发生的事情：
{memory_context}

现在，用户找你聊天。
```

### 总结模型

```
你是一个总结专家。请将用户和角色的对话总结成简短的描述，
格式为：用户和角色聊了关于XXX的事情。保持简洁，不超过50字。
```

## 常见问题

### Q: 如何使用其他 API（如 Azure、Claude）？

A: 修改 `config/ai_config.json` 的 `base_url` 和 `model`：

```json
{
  "chat_model": {
    "model": "your-model-name",
    "base_url": "https://your-api-endpoint.com/v1"
  }
}
```

### Q: 如何查看日志？

A: 打开 `%APPDATA%\Godot\app_userdata\CABM-ED\ai_logs\log.txt`

### Q: 记忆不保存怎么办？

A: 检查：
1. `config/save_data_template.json` 是否包含 `ai_data` 字段
2. 存档文件是否正常更新
3. 控制台是否有错误信息

### Q: API 调用失败？

A: 检查：
1. API 密钥是否正确
2. 网络连接是否正常
3. API 地址是否正确
4. 查看日志文件了解详细错误

## 安全提示

⚠️ **重要**：
- 永远不要将 `api_keys.json` 提交到版本控制
- 已添加到 `.gitignore`
- 日志文件包含完整对话，注意隐私保护

## 详细文档

- 📖 [快速开始指南](docs/ai_quick_start.md)
- 📖 [完整集成指南](docs/ai_integration_guide.md)

## 技术栈

- **语言**：GDScript
- **引擎**：Godot 4.5
- **API**：OpenAI Compatible API
- **存储**：JSON 格式存档

## 文件结构

```
├── config/
│   ├── ai_config.json          # AI 配置
│   └── api_keys.json.example   # API 密钥示例
├── scripts/
│   ├── ai_service.gd           # AI 服务（自动加载）
│   ├── chat_dialog.gd          # 聊天对话框（已集成 AI）
│   └── save_manager.gd         # 存档管理（已扩展）
└── docs/
    ├── ai_quick_start.md       # 快速开始
    └── ai_integration_guide.md # 完整指南
```

## 许可

本 AI 集成模块遵循项目主许可证。
