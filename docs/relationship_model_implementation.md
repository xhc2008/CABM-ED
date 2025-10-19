# 关系模型实现文档

## 概述
本次更新添加了"关系模型"功能，用于对总结后的内容进行二次总结，提取和维护角色与用户之间的关系信息。

## 功能说明

### 1. 工作流程
1. 用户与角色对话
2. 对话结束时，调用**总结模型**生成对话总结
3. 总结保存到 `ai_data.memory` 数组中
4. 累计条目数 `accumulated_summary_count` +1
5. 当累计条目数达到 `max_memory_items`（默认20）时：
   - 自动调用**关系模型**
   - 将所有总结内容作为输入
   - 生成关系描述（人物特点、关系状态等）
   - 保存到 `ai_data.relationship_history` 数组
   - 清空累计条目数

### 2. 配置说明

#### ai_config.json
```json
{
  "relationship_model": {
    "model": "Qwen/Qwen3-8B",
    "base_url": "https://api.siliconflow.cn/v1",
    "max_tokens": 256,
    "temperature": 0.3,
    "top_p": 0.9,
    "timeout": 30,
    "enable_thinking": false,
    "system_prompt": "你是一个总结专家。请根据对话内容更新两人之间的关系、人物特点等，不超过50字。目前的关系：{relationship}/no_think"
  },
  "memory": {
    "max_memory_items": 20,
    "max_conversation_history": 10,
    "max_relationship_history": 2
  }
}
```

- `max_memory_items`: 触发关系模型的总结条目数阈值
- `max_relationship_history`: 保留的关系历史记录数量（默认2条）

#### 对话模型提示词更新
在 `chat_model.system_prompt` 中添加了新的占位符：
```
## 你们之间的关系：
{relationship_context}
```

### 3. 存档结构变化

#### save_data_template.json
```json
{
  "ai_data": {
    "memory": [],
    "accumulated_summary_count": 0,
    "relationship_history": []
  }
}
```

新增字段：
- `accumulated_summary_count`: 累计的总结条目数
- `relationship_history`: 关系历史记录数组

每条关系记录格式：
```json
{
  "timestamp": "2025-10-19T14:30:00",
  "content": "关系描述内容"
}
```

### 4. 代码变更

#### scripts/ai_service.gd
新增函数：
- `_call_relationship_api()`: 调用关系模型API
- `_handle_relationship_response()`: 处理关系模型响应
- `_save_relationship()`: 保存关系信息到存档

修改函数：
- `_save_memory()`: 添加累计条目数逻辑，触发关系模型调用
- `_on_request_completed()`: 添加关系模型请求类型处理

#### scripts/prompt_builder.gd
新增函数：
- `get_relationship_context()`: 获取最新的关系描述

修改函数：
- `build_system_prompt()`: 添加关系上下文占位符替换
- `get_memory_context()`: 确保字段初始化

## 使用示例

### 场景1：正常对话流程
1. 用户与角色进行20次对话（每次对话结束生成1条总结）
2. 第20次对话结束后：
   - 生成第20条总结
   - 累计条目数达到20
   - 自动调用关系模型
   - 生成关系描述："用户和角色关系逐渐亲密，角色开始信任用户"
   - 累计条目数清零

### 场景2：关系信息在对话中的应用
对话模型会收到以下上下文：
```
## 你们之间的关系：
用户和角色关系逐渐亲密，角色开始信任用户

## 之前发生的事情：
[10-19 14:30] 用户和角色一起看了电影
[10-19 15:00] 角色向用户分享了自己的过去
...
```

## 注意事项

1. **API密钥**: 关系模型使用与总结模型相同的API密钥和base_url
2. **提示词定制**: 可以修改 `relationship_model.system_prompt` 来调整关系提取的风格
3. **历史记录限制**: 默认只保留最近2条关系记录，可通过 `max_relationship_history` 调整
4. **兼容性**: 旧存档会自动添加新字段，不会影响现有数据

## 日志记录

关系模型的调用会记录在 `user://ai_logs/log.txt` 中：
- `RELATIONSHIP_REQUEST`: 请求内容
- `RELATIONSHIP_RESPONSE`: 响应内容

## 测试建议

1. 创建新存档，进行20次对话，观察关系模型是否被触发
2. 检查 `user://saves/save_slot_1.json` 中的 `relationship_history` 字段
3. 查看 `user://ai_logs/log.txt` 确认API调用成功
4. 在第21次对话时，检查对话模型是否收到关系上下文
