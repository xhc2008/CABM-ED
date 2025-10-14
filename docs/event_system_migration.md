# 事件系统迁移指南

## 从旧的 InteractionManager 迁移到新的 EventManager

### 1. 配置自动加载

在 `project.godot` 中添加（如果还没有）：

```
[autoload]
EventHelpers="*res://scripts/event_helpers.gd"
EventManager="*res://scripts/event_manager.gd"
```

### 2. 代码替换对照表

#### 旧代码 → 新代码

**角色点击：**
```gdscript
# 旧代码
InteractionManager.try_interaction("click_character")

# 新代码
EventManager.on_character_clicked()
```

**用户发起聊天：**
```gdscript
# 旧代码
InteractionManager.try_interaction("chat")

# 新代码
EventManager.on_user_start_chat()
```

**进入场景：**
```gdscript
# 旧代码
InteractionManager.try_interaction("enter_scene", true)

# 新代码
EventManager.on_enter_scene()
```

**离开场景：**
```gdscript
# 旧代码
InteractionManager.try_interaction("leave_scene", true)

# 新代码
EventManager.on_leave_scene()
```

**对话结束：**
```gdscript
# 旧代码
# （可能没有对应的旧代码）

# 新代码
EventManager.on_chat_session_end(turn_count)
```

### 3. 信号替换

**旧信号：**
```gdscript
InteractionManager.interaction_success.connect(_on_interaction_success)
InteractionManager.interaction_failure.connect(_on_interaction_failure)
InteractionManager.willingness_changed.connect(_on_willingness_changed)
```

**新信号：**
```gdscript
EventManager.event_completed.connect(_on_event_completed)

func _on_event_completed(event_name: String, result):
	if result.success:
		# 处理成功
		print("事件成功: ", event_name)
	else:
		# 处理失败
		print("事件失败: ", event_name, " - ", result.message)
```

### 4. 辅助函数替换

**获取角色名称：**
```gdscript
# 旧代码
InteractionManager._get_character_name()

# 新代码
EventHelpers.get_character_name()
```

**修改交互意愿：**
```gdscript
# 旧代码
InteractionManager.modify_willingness(10)

# 新代码
EventHelpers.modify_willingness(10)
```

**计算成功率：**
```gdscript
# 旧代码
InteractionManager.calculate_success_chance("chat")

# 新代码
EventHelpers.calculate_success_chance(120)  # 传入基础意愿值
```

**检查冷却：**
```gdscript
# 旧代码
InteractionManager.is_on_cooldown("chat")

# 新代码
EventManager.is_on_cooldown("user_start_chat")
```

### 5. 需要查找和替换的文件

使用以下命令查找需要修改的文件：

```bash
# 查找使用 InteractionManager 的地方
grep -r "InteractionManager" --include="*.gd" .

# 查找 try_interaction 调用
grep -r "try_interaction" --include="*.gd" .

# 查找 interaction_success 信号
grep -r "interaction_success" --include="*.gd" .
```

### 6. 常见迁移场景

#### 场景 A：角色脚本中的点击处理

**旧代码：**
```gdscript
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if InteractionManager.try_interaction("click_character"):
			start_chat()
		else:
			show_rejection()
```

**新代码：**
```gdscript
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		var result = EventManager.on_character_clicked()
		if result.success:
			start_chat()
		else:
			show_rejection(result.message)
```

#### 场景 B：聊天按钮

**旧代码：**
```gdscript
func _on_chat_button_pressed():
	if InteractionManager.is_on_cooldown("chat"):
		show_message("请稍后再试")
		return
	
	if InteractionManager.try_interaction("chat"):
		open_chat_window()
```

**新代码：**
```gdscript
func _on_chat_button_pressed():
	var result = EventManager.on_user_start_chat()
	
	if result.success:
		open_chat_window()
	else:
		show_message(result.message)
```

#### 场景 C：场景切换

**旧代码：**
```gdscript
func _on_scene_changed(new_scene):
	var character_scene = SaveManager.get_character_scene()
	
	if new_scene == character_scene:
		InteractionManager.try_interaction("enter_scene", true)
	elif current_scene == character_scene:
		InteractionManager.try_interaction("leave_scene", true)
	
	current_scene = new_scene
```

**新代码：**
```gdscript
func _on_scene_changed(new_scene):
	var character_scene = SaveManager.get_character_scene()
	
	if current_scene == character_scene and new_scene != character_scene:
		EventManager.on_leave_scene()
	
	current_scene = new_scene
	
	if new_scene == character_scene:
		EventManager.on_enter_scene()
```

#### 场景 D：AI 回复判断

**新增功能（旧系统可能没有）：**
```gdscript
func process_user_message(message: String):
	# 发送用户消息
	add_message("user", message)
	
	# 判断 AI 是否回复
	var result = EventManager.on_chat_turn_end()
	
	if result.success:
		# AI 决定回复
		var ai_response = await AIService.get_response(message)
		add_message("ai", ai_response)
	else:
		# AI 决定不回复（沉默）
		add_message("system", result.message)
```

### 7. 可以删除的旧代码

迁移完成后，可以考虑删除：

1. `scripts/interaction_manager.gd` - 旧的交互管理器
2. `config/interaction_config.json` - 旧的交互配置
3. `docs/interaction_system_*.md` - 旧的文档

**注意**：删除前请确保所有引用都已更新！

### 8. 测试清单

迁移后请测试以下功能：

- [ ] 点击角色能正常触发事件
- [ ] 发起聊天能正常工作
- [ ] 场景切换时事件正确触发
- [ ] 冷却时间正常工作
- [ ] 好感度和交互意愿正确变化
- [ ] 心情和精力修正生效
- [ ] 空闲超时正常触发
- [ ] 对话结束事件正常工作
- [ ] 事件信号正确发送

### 9. 调试技巧

如果遇到问题，可以：

1. 检查自动加载顺序（EventHelpers 必须在 EventManager 之前）
2. 查看控制台输出的事件日志
3. 使用调试函数：

```gdscript
# 打印当前状态
print("好感度: ", EventHelpers.get_affection())
print("交互意愿: ", EventHelpers.get_willingness())
print("心情: ", EventHelpers.get_mood())
print("精力: ", EventHelpers.get_energy())

# 清除所有冷却
EventManager.clear_all_cooldowns()

# 检查特定事件冷却
if EventManager.is_on_cooldown("user_start_chat"):
	print("剩余冷却: ", EventManager.get_cooldown_remaining("user_start_chat"))
```

### 10. 常见问题

**Q: EventHelpers 未找到？**
A: 确保在 project.godot 中正确配置了自动加载，且 EventHelpers 在 EventManager 之前。

**Q: 事件不触发？**
A: 检查是否在冷却中，使用 `is_on_cooldown()` 和 `get_cooldown_remaining()` 调试。

**Q: 数值没有变化？**
A: 确保 SaveManager 已正确配置为自动加载，且启用了即时保存。

**Q: 如何临时禁用某个事件？**
A: 在事件函数开头直接返回失败结果：
```gdscript
func on_character_clicked() -> EventResult:
	return EventResult.new(false, "此功能暂时禁用")
```
