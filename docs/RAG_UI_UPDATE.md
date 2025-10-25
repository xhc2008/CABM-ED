# RAG系统UI更新说明

## 更新内容

已在AI配置窗口的"详细配置"选项卡中添加嵌入模型配置界面。

## 新增配置项

在TTS模型配置下方，新增了"嵌入模型配置（用于长期记忆RAG）"部分，包含：

1. **模型名称** - 嵌入模型的名称
   - 示例：`text-embedding-3-small`
   - 用途：将文本转换为向量

2. **Base URL** - API端点地址
   - 示例：`https://api.openai.com/v1`
   - 支持OpenAI兼容的API

3. **API 密钥** - 访问API的密钥
   - 格式：`sk-...`
   - 可以与对话模型使用相同的密钥（如果是同一平台）

## 使用方法

### 1. 打开AI配置窗口

在游戏中打开AI配置面板（通常在设置或侧边栏中）

### 2. 切换到"详细配置"选项卡

点击顶部的"详细配置"标签页

### 3. 滚动到嵌入模型配置部分

在TTS模型配置下方可以看到"嵌入模型配置（用于长期记忆RAG）"

### 4. 填写配置信息

#### 使用OpenAI
```
模型名称: text-embedding-3-small
Base URL: https://api.openai.com/v1
API 密钥: sk-your-openai-key
```

#### 使用硅基流动
```
模型名称: BAAI/bge-large-zh-v1.5
Base URL: https://api.siliconflow.cn/v1
API 密钥: sk-your-siliconflow-key
```

#### 使用其他兼容平台
只要支持OpenAI的embeddings API格式即可

### 5. 保存配置

点击"保存详细配置"按钮

## 配置文件

配置会保存到 `user://ai_keys.json`，格式如下：

```json
{
  "chat_model": { ... },
  "summary_model": { ... },
  "tts_model": { ... },
  "embedding_model": {
    "model": "text-embedding-3-small",
    "base_url": "https://api.openai.com/v1",
    "api_key": "sk-..."
  }
}
```

## 注意事项

1. **嵌入模型是可选的**
   - 如果不配置，RAG系统将无法工作
   - 但不影响基本对话功能

2. **API密钥可以共用**
   - 如果使用同一平台（如都用OpenAI），可以使用相同的API密钥
   - 不同平台需要分别配置

3. **向量维度**
   - 不同模型的向量维度不同
   - 更换模型后需要清空旧的向量数据库
   - 向量数据库位置：`user://memory_main_memory.json`

4. **成本考虑**
   - 嵌入API通常比对话API便宜很多
   - 每次对话会调用1-2次嵌入API
   - 建议使用较小的模型（如text-embedding-3-small）

## 推荐配置

### 预算充足
```
模型: text-embedding-3-large
平台: OpenAI
向量维度: 3072
优点: 效果最好
```

### 平衡选择（推荐）
```
模型: text-embedding-3-small
平台: OpenAI
向量维度: 1536
优点: 性价比高，效果好
```

### 预算有限
```
模型: BAAI/bge-large-zh-v1.5
平台: 硅基流动
向量维度: 1024
优点: 便宜，中文效果好
```

## 验证配置

保存配置后，查看控制台输出：

- ✅ 成功：`记忆系统初始化完成`
- ❌ 失败：`警告: 嵌入模型未配置`

## 相关文档

- [RAG系统完整文档](RAG_SYSTEM.md)
- [快速开始指南](RAG_QUICKSTART.md)
- [实现总结](../RAG_IMPLEMENTATION_SUMMARY.md)
