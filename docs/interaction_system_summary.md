# 交互意愿系统 - 实现总结

## 已创建的文件

### 配置文件
1. **config/interaction_config.json** - 交互意愿配置
   - 定义了7种动作类型及其基础意愿值
   - 配置了失败反馈和冷却时间
   - 包含心情、精力等修正因子

2. **config/save_data_template.json** - 存档数据模板
   - 角色数据（好感度、交互意愿、心情等）
   - 用户数据（游戏时长、聊天次数等）
   - 游戏进度和统计数据

### 脚本文件
1. **scripts/interaction_manager.gd** - 交互管理器
   - 计算成功概率
   - 处理交互判定
   - 管理冷却时间
   - 发送成功/失败信号

2. **scripts/save_manager.gd** - 存档管理器
   - 保存/加载游戏数据
   - 提供数据访问接口
   - 管理多个存档槽位

3. **scripts/interaction_test.gd** - 测试脚本
   - 快速测试各种交互
   - 调试工具

### 文档文件
1. **docs/interaction_system_guide.md** - 使用指南
2. **docs/save_system_guide.md** - 存档系统指南
3. **docs/setup_autoload.md** - 自动加载配置说明

## 核心机制

### 成功概率公式
```
实际成功率 = (基础意愿 + 当前交互意愿 - 100) / 100 + 修正因子
```

### 动作类型及基础意愿

| 动作 | 基础意愿 | 失败反馈 |
|------|----------|----------|
| 聊天 | 150% | 显示"{角色名}不想理你" |
| 点击角色 | 120% | 显示"{角色名}似乎没注意到你" |
| 送礼物 | 200% | 显示"{角色名}现在不想收礼物" |
| 摸头 | 100% | 显示"{角色名}躲开了" |
| 呼唤名字 | 90% | 显示"{角色名}没有回应" |
| 进入场景 | 80% | 无事发生 |
| 离开场景 | 40% | 无事发生 |

### 修正因子

**心情修正**:
- happy: +20%
- excited: +30%
- normal: 0%
- sad: -20%
- angry: -40%

**精力修正**:
- high (80-100): +10%
- normal (40-79): 0%
- low (20-39): -15%
- exhausted (0-19): -30%

## 使用示例

### 1. 配置自动加载
在 `project.godot` 中添加：
```ini
[autoload]
SaveManager="*res://scripts/save_manager.gd"
InteractionManager="*res://scripts/interaction_manager.gd"
```

### 2. 尝试交互
```gdscript
# 尝试聊天
var success = InteractionManager.try_interaction("chat")
if success:
    start_chat_dialog()
```

### 3. 监听事件
```gdscript
func _ready():
    InteractionManager.interaction_success.connect(_on_interaction_success)
    InteractionManager.interaction_failure.connect(_on_interaction_failure)

func _on_interaction_failure(action_id: String, message: String):
    if message != "":
        show_notification(message)  # 显示失败消息
```

### 4. 修改数据
```gdscript
# 增加好感度
SaveManager.add_affection(10)

# 修改交互意愿
InteractionManager.modify_willingness(5)

# 改变心情
SaveManager.set_mood("happy")
```

## 已集成的功能

### main.gd 中的集成
- ✅ 点击角色时触发交互判定
- ✅ 聊天时触发交互判定
- ✅ 显示失败消息
- ✅ 连接交互管理器信号

### 失败反馈
- ✅ 聊天失败显示消息
- ✅ 其他操作失败无事发生
- ✅ 失败后进入冷却期

## 测试方法

### 方法1: 使用测试脚本
1. 将 `interaction_test.gd` 附加到任意节点
2. 运行游戏
3. 按数字键测试各种功能

### 方法2: 在控制台测试
```gdscript
# 查看当前状态
print(SaveManager.get_reply_willingness())
print(InteractionManager.calculate_success_chance("chat"))

# 修改数据
SaveManager.set_reply_willingness(30)
SaveManager.set_mood("angry")

# 测试交互
InteractionManager.try_interaction("chat")
```

## 下一步扩展建议

1. **添加更多动作类型**
   - 在 `interaction_config.json` 中添加新动作
   - 配置基础意愿和失败反馈

2. **实现自动保存**
   - 定期保存游戏数据
   - 在重要操作后保存

3. **添加交互历史**
   - 记录最近的交互结果
   - 根据历史调整意愿

4. **实现好感度系统**
   - 成功交互增加好感度
   - 好感度影响交互意愿

5. **添加时间系统**
   - 根据时间段调整意愿
   - 实现疲劳系统

## 注意事项

1. 首次使用需要配置自动加载
2. 成功率会被限制在 0-100% 范围
3. 失败后会自动进入冷却期
4. 可以通过修改配置文件调整平衡性
5. 建议根据游戏进度动态调整交互意愿
