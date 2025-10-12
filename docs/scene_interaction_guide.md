# 场景交互系统使用指南

## 概述

场景交互系统会在玩家进入或离开有角色的场景时，根据交互意愿进行概率判定，成功时触发聊天。

## 工作原理

### 触发时机

1. **进入场景** (enter_scene)
   - 当玩家切换到有角色的场景时触发
   - 基础意愿：80%
   - 成功时：角色主动开始聊天

2. **离开场景** (leave_scene)
   - 当玩家从有角色的场景切换到其他场景时触发
   - 基础意愿：40%
   - 成功时：角色在离开前主动聊天

### 判定流程

```
玩家切换场景
    ↓
检查旧场景是否有角色
    ↓ 有
尝试 leave_scene 交互
    ↓ 成功
触发聊天（角色想和你说再见）
    ↓
加载新场景
    ↓
检查新场景是否有角色
    ↓ 有
尝试 enter_scene 交互
    ↓ 成功
触发聊天（角色主动打招呼）
```

## 成功概率计算

使用标准的交互意愿公式：

```
实际成功率 = (基础意愿 + 当前交互意愿 - 100)% + 修正因子
```

### 示例

**进入场景 (base_willingness: 80)**
- 交互意愿 100 → (80 + 100 - 100) = 80% 成功率
- 交互意愿 50 → (80 + 50 - 100) = 30% 成功率
- 交互意愿 30 → (80 + 30 - 100) = 10% 成功率

**离开场景 (base_willingness: 40)**
- 交互意愿 100 → (40 + 100 - 100) = 40% 成功率
- 交互意愿 80 → (40 + 80 - 100) = 20% 成功率
- 交互意愿 50 → (40 + 50 - 100) = -10% → 0% 成功率

## 实现细节

### 场景检测

系统会检查 `character_presets.json` 配置文件，判断场景是否有角色：

```gdscript
func _has_character_in_scene(scene_id: String) -> bool:
    # 读取角色配置
    # 检查场景是否有角色预设
    return config.has(scene_id) and config[scene_id].size() > 0
```

### 交互触发

```gdscript
func _try_scene_interaction(action_id: String):
    # 尝试交互判定
    var success = InteractionManager.try_interaction(action_id)
    
    if success:
        # 等待场景加载完成
        await get_tree().create_timer(0.5).timeout
        
        # 触发聊天
        character.start_chat()
        chat_dialog.show_dialog()
```

## 配置调整

### 修改触发概率

编辑 `config/interaction_config.json`:

```json
{
  "actions": {
    "enter_scene": {
      "base_willingness": 80  // 提高这个值增加触发概率
    },
    "leave_scene": {
      "base_willingness": 40  // 提高这个值增加触发概率
    }
  }
}
```

### 建议配置

**高频触发** (经常触发聊天):
```json
"enter_scene": { "base_willingness": 120 }
"leave_scene": { "base_willingness": 80 }
```

**中频触发** (默认配置):
```json
"enter_scene": { "base_willingness": 80 }
"leave_scene": { "base_willingness": 40 }
```

**低频触发** (偶尔触发):
```json
"enter_scene": { "base_willingness": 50 }
"leave_scene": { "base_willingness": 20 }
```

## 使用场景

### 1. 角色主动打招呼
玩家进入客厅，角色有概率主动说：
- "你回来啦！"
- "欢迎回来~"
- "等你好久了呢"

### 2. 角色挽留
玩家离开客厅，角色有概率说：
- "要走了吗？"
- "这么快就要离开了？"
- "再陪我一会儿嘛"

### 3. 根据心情调整
- 心情好 (happy) → 更容易触发 (+20%)
- 心情差 (angry) → 不太想说话 (-40%)

## 调试技巧

### 查看触发日志

运行游戏时观察控制台：

```
场景交互成功，触发聊天: enter_scene
动作: enter_scene 成功率: 80% 掷骰: 0.45 结果: 成功
```

或

```
场景交互失败: leave_scene
动作: leave_scene 成功率: 20% 掷骰: 0.85 结果: 失败
```

### 测试不同概率

```gdscript
# 临时提高交互意愿测试
var save_mgr = get_node("/root/SaveManager")
save_mgr.set_reply_willingness(100)
save_mgr.set_mood("happy")

# 现在切换场景，应该更容易触发
```

### 强制触发

如果想测试聊天内容，可以临时修改配置：

```json
"enter_scene": { "base_willingness": 200 }
```

这样交互意愿只要大于0就必定触发。

## 注意事项

1. **失败时无提示** - 进入/离开场景失败时不会显示消息，这是设计行为
2. **冷却时间** - 失败后会进入10秒冷却期
3. **场景加载延迟** - 成功触发后会等待0.5秒让场景完全加载
4. **角色状态检查** - 只有角色可见且未在聊天时才会触发

## 扩展建议

### 1. 添加特殊对话
根据场景类型显示不同的对话：

```gdscript
func _try_scene_interaction(action_id: String):
    var success = interaction_mgr.try_interaction(action_id)
    if success:
        # 根据场景设置特殊对话
        match current_scene:
            "livingroom":
                chat_dialog.set_greeting("欢迎来到客厅~")
            "bedroom":
                chat_dialog.set_greeting("来卧室做什么呢？")
```

### 2. 记录访问次数
统计玩家访问场景的次数，影响触发概率：

```gdscript
func _on_scene_changed(scene_id: String, ...):
    # 记录访问
    SaveManager.increment_scene_visit(scene_id)
    
    # 访问次数越多，角色越熟悉，触发概率越高
    var visits = SaveManager.get_scene_visits(scene_id)
    if visits > 10:
        # 提高交互意愿
        pass
```

### 3. 时间段影响
根据游戏内时间调整触发概率：

```gdscript
# 早上角色更活跃
if current_time == "day":
    # 提高进入场景的触发率
    pass
# 晚上角色想休息
elif current_time == "night":
    # 降低触发率
    pass
```

## 完整示例

```gdscript
# 玩家从客厅切换到卧室

# 1. 检测离开客厅（有角色）
_has_character_in_scene("livingroom") # → true

# 2. 尝试 leave_scene 交互
# 交互意愿: 80, 基础意愿: 40
# 成功率: (40 + 80 - 100) = 20%
# 掷骰: 0.15 < 0.20 → 成功！

# 3. 触发聊天
character.start_chat()
chat_dialog.show_dialog()
# 角色说："要走了吗？再陪我一会儿嘛~"

# 4. 聊天结束后，加载卧室场景

# 5. 检测进入卧室（有角色）
_has_character_in_scene("bedroom") # → true

# 6. 尝试 enter_scene 交互
# 成功率: (80 + 80 - 100) = 60%
# 掷骰: 0.75 > 0.60 → 失败
# 无事发生，正常进入场景
```

## 总结

场景交互系统为游戏增加了随机性和惊喜感：
- ✅ 角色会主动打招呼或挽留
- ✅ 概率可配置，平衡游戏体验
- ✅ 受交互意愿和心情影响
- ✅ 失败时不打扰玩家
- ✅ 增加角色的"生命力"

通过调整配置文件，可以轻松控制触发频率，打造理想的游戏体验！
