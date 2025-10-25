# 记忆系统测试指南

## 数据库格式变更

### 新格式特点
- **文本和向量分开存储**：便于查看和调试
- **一一对应**：texts 数组和 vectors 数组按索引对应
- **向后兼容**：自动识别并支持旧格式

### 数据结构
```json
{
  "db_name": "test_memory",
  "vector_dim": 1024,
  "last_updated": "2025-10-25T12:00:00",
  "count": 3,
  "texts": [
    {
      "text": "今天天气很好",
      "timestamp": "2025-10-25T10:30:00",
      "type": "conversation",
      "metadata": {}
    },
    {
      "text": "我去了公园散步",
      "timestamp": "2025-10-25T11:00:00",
      "type": "diary",
      "metadata": {}
    }
  ],
  "vectors": [
    [0.123, 0.456, ...],  // 对应第一条文本
    [0.789, 0.012, ...]   // 对应第二条文本
  ]
}
```

## 测试页面使用

### 启动方式

#### 方法1：从编辑器运行
1. 在 Godot 编辑器中打开 `scenes/test_memory.tscn`
2. 点击运行当前场景（F6）

#### 方法2：命令行启动
```bash
godot --script test_memory_launcher.gd
```

#### 方法3：添加到项目场景列表
在项目设置中将 `scenes/test_memory.tscn` 添加为可运行场景

### 功能说明

#### 1. 添加记忆
- 在文本框输入要添加的内容
- 选择类型（conversation 或 diary）
- 点击"添加"按钮
- 系统会自动调用嵌入 API 生成向量并保存

#### 2. 搜索记忆
- 在查询框输入搜索内容
- 设置返回结果数量（Top K）
- 点击"搜索"按钮
- 显示相似度最高的记忆条目

#### 3. 查看数据库
- 点击"查看数据库"按钮
- 显示所有记忆条目的详细信息
- 包括文本、时间、类型、向量维度等

#### 4. 清空数据库
- 点击"清空数据库"按钮
- 确认后删除所有记忆（不可撤销）

### 数据文件位置
- 测试数据库：`user://memory_test_memory.json`
- 主数据库：`user://memory_main_memory.json`

在 Windows 上，`user://` 通常对应：
```
%APPDATA%\Godot\app_userdata\[项目名]\
```

## 调试技巧

### 查看原始数据
1. 找到数据文件位置
2. 用文本编辑器打开 `.json` 文件
3. 文本部分在 `texts` 数组中，易于阅读
4. 向量部分在 `vectors` 数组中

### 验证数据一致性
```gdscript
# 在测试页面中添加验证代码
func verify_data_consistency():
    var texts_count = memory_system.memory_items.size()
    print("记忆条目数: ", texts_count)
    
    for i in range(texts_count):
        var item = memory_system.memory_items[i]
        print("条目 %d: 文本长度=%d, 向量维度=%d" % [
            i, item.text.length(), item.vector.size()
        ])
```

### 测试嵌入 API
如果添加记忆失败，检查：
1. API 密钥是否正确配置
2. Base URL 是否可访问
3. 模型名称是否正确
4. 网络连接是否正常

## 常见问题

### Q: 添加记忆时卡住不动
A: 检查嵌入 API 配置，查看控制台错误信息

### Q: 搜索结果为空
A: 
- 确认数据库中有数据
- 尝试降低相似度阈值（代码中设为 0.0）
- 检查查询文本是否与数据库内容相关

### Q: 数据文件在哪里
A: 运行以下代码查看：
```gdscript
print(ProjectSettings.globalize_path("user://"))
```

### Q: 如何迁移旧格式数据
A: 系统会自动识别旧格式并正常加载，下次保存时会自动转换为新格式

## 性能优化

### 请求队列
- 系统使用队列处理多个嵌入请求
- 避免并发请求冲突
- 控制台会显示队列进度

### 批量操作
如需批量添加记忆，建议：
```gdscript
for text in texts:
    await memory_system.add_text(text, "diary")
    await get_tree().create_timer(0.1).timeout  # 小延迟避免过载
```

## 下一步

- [ ] 添加批量导入功能
- [ ] 支持导出为 CSV/JSON
- [ ] 添加记忆统计图表
- [ ] 实现记忆去重功能
- [ ] 添加记忆编辑功能
