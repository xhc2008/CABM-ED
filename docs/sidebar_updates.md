# 侧边栏更新说明

## 修改内容

### 1. 移除未使用的显示项

**移除：**
- 精力（energy）
- 信任等级（trust）

**保留：**
- 好感度（affection）
- 交互意愿（reply_willingness）
- 心情（mood）

### 2. 实时更新机制

#### 之前的问题
侧边栏只在以下情况更新：
- 页面初始化时
- InteractionManager的willingness_changed信号触发时

这导致AI对话后的数据变化不能实时反映。

#### 解决方案
添加对AI服务信号的监听：

```gdscript
# 在 _ready() 中
if has_node("/root/AIService"):
    var ai_service = get_node("/root/AIService")
    ai_service.chat_fields_extracted.connect(_on_ai_fields_updated)

# 新增回调函数
func _on_ai_fields_updated(_fields: Dictionary):
    """AI字段更新时刷新显示"""
    _update_character_stats()
```

#### 工作流程
```
AI响应完成
    ↓
提取 mood, will, like 字段
    ↓
更新 SaveManager 数据
    ↓
发送 chat_fields_extracted 信号
    ↓
侧边栏接收信号 → 调用 _update_character_stats()
    ↓
从 SaveManager 读取最新数据
    ↓
更新 UI 显示
```

## 显示效果

### 好感度
- 范围：0-100
- 颜色：
  - 80+：绿色
  - 50-79：黄色
  - 30-49：橙色
  - 0-29：红色

### 交互意愿
- 范围：0-100
- 颜色：同好感度

### 心情
- 显示：中文名称（从mood_config.json读取）
- 颜色：从mood_config.json读取
- 示例：
  - "平静" - 白色
  - "开心" - 绿色
  - "难过" - 蓝色
  - "生气" - 红色

## 测试方法

### 1. 初始显示测试
1. 启动游戏
2. 查看左侧边栏
3. 确认只显示3项数据
4. 确认数据来自存档

### 2. 实时更新测试
1. 进入对话
2. 发送消息
3. 等待AI响应
4. 观察侧边栏是否立即更新
5. 检查数值变化是否正确

### 3. 多轮对话测试
1. 进行3-5轮对话
2. 每次响应后检查侧边栏
3. 确认数据持续更新
4. 确认颜色随数值变化

### 4. 持久化测试
1. 对话后退出游戏
2. 重新启动游戏
3. 检查侧边栏显示的数据
4. 应该是上次对话后的值

## 调试

### 查看更新日志
在 `_on_ai_fields_updated()` 中添加：
```gdscript
func _on_ai_fields_updated(fields: Dictionary):
    print("侧边栏收到字段更新: ", fields)
    _update_character_stats()
```

### 手动触发更新
在Godot控制台：
```gdscript
get_node("Sidebar")._update_character_stats()
```

### 检查信号连接
```gdscript
var ai = get_node("/root/AIService")
print("chat_fields_extracted 连接数: ", ai.chat_fields_extracted.get_connections().size())
```

## 注意事项

1. **信号连接时机**：在 `_ready()` 中使用 `await get_tree().process_frame` 确保自动加载节点已准备好
2. **多次连接**：不会重复连接，Godot会自动处理
3. **性能**：更新操作很轻量，不会影响性能
4. **配置文件**：心情显示依赖 `mood_config.json`，确保文件存在

## 兼容性

- 与现有的InteractionManager信号兼容
- 不影响其他功能
- 向后兼容旧存档
