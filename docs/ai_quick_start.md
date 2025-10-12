# AI 对话系统快速开始

## 5 分钟快速配置

### 1. 设置 API 密钥

**方法一：使用界面设置**（推荐）

1. 运行游戏
2. 在左侧控制栏找到"AI 设置"区域
3. 在"API 密钥"输入框中输入你的密钥（如 `sk-...`）
4. 点击"保存密钥"按钮
5. 看到"✓ 已保存"提示即可

**方法二：手动创建文件**

在 Windows 上，找到用户数据目录：
```
%APPDATA%\Godot\app_userdata\CABM-ED\
```

创建文件 `api_keys.json`：
```json
{
  "openai_api_key": "sk-your-api-key-here"
}
```

### 2. 运行游戏

直接运行游戏，系统会自动：
- 加载 AI 配置
- 加载 API 密钥
- 初始化记忆系统

### 3. 测试对话

1. 点击角色进入聊天
2. 输入消息，例如："你好"
3. 等待 AI 回复
4. 继续对话
5. 点击"结束"按钮

### 4. 查看结果

**查看记忆**：
- 打开存档文件（`user://saves/save_slot_1.json`）
- 查看 `ai_data.memory` 字段

**查看日志**：
- 打开 `user://ai_logs/log.txt`
- 查看完整的 API 调用记录

## 配置选项

### 修改角色名字

编辑 `config/app_config.json`：
```json
{
  "character_name": "雪狐",  // 改成你的角色名字
  "user_name": "主人"        // 改成你想要的称呼
}
```

### 修改模型

编辑 `config/ai_config.json`：
```json
{
  "chat_model": {
    "model": "gpt-4o-mini",  // 改成你的模型
    "base_url": "https://api.openai.com/v1"  // 改成你的 API 地址
  }
}
```

### 调整记忆容量

编辑 `config/ai_config.json`：
```json
{
  "memory": {
    "max_memory_items": 10,           // 短期记忆最大条目数
    "max_conversation_history": 20    // 对话历史最大条数
  }
}
```

## 工作原理

### 对话时
```
用户输入 → AI 服务 → 对话模型 → 回复显示
                ↓
         记录到对话历史
```

### 结束时
```
对话历史 → 扁平化 → 总结模型 → 生成总结
                                    ↓
                            保存到记忆和存储
                                    ↓
                            清空对话历史
```

### 记忆系统
- **短期记忆**（memory）：最多保留 N 条，超过会删除旧的
- **永久存储**（storage）：保留所有记录，永不删除
- **对话历史**：当前对话的消息，独立于记忆

## 常见问题

### Q: API 密钥放在哪里？
A: 放在 `user://api_keys.json`，路径通常是：
- Windows: `%APPDATA%\Godot\app_userdata\CABM-ED\api_keys.json`
- 或者先放在 `config/api_keys.json`，运行时会自动复制

### Q: 如何查看日志？
A: 日志在 `user://ai_logs/log.txt`，路径通常是：
- Windows: `%APPDATA%\Godot\app_userdata\CABM-ED\ai_logs\log.txt`

### Q: 记忆保存在哪里？
A: 保存在存档文件的 `ai_data` 字段：
- `user://saves/save_slot_1.json`

### Q: 对话历史和记忆有什么区别？
A: 
- **对话历史**：当前对话的完整消息，用于上下文连贯，结束对话后清空
- **记忆**：对话的总结，长期保存，用于构建"之前发生的事情"

### Q: 如何自定义系统提示词？
A: 编辑 `config/ai_config.json` 的 `chat_model.system_prompt` 字段。

可用占位符：
- `{character_name}`: 角色名字
- `{user_name}`: 用户名字
- `{current_scene}`: 当前场景
- `{current_weather}`: 当前天气
- `{memory_context}`: 记忆上下文

## 下一步

查看完整文档：`docs/ai_integration_guide.md`
