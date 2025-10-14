# 事件系统使用指南

## 概述

新的事件系统将所有交互事件统一管理，分为两个脚本：
- **event_manager.gd** - 事件处理函数（每个事件一个函数）
- **event_helpers.gd** - 辅助函数（成功率计算、数值修改等）

## 配置为自动加载

在 `project.godot` 中添加：

```
[autoload]
EventHelpers="*res://scripts/event_helpers.gd"
EventManager="*res://scripts/event_manager.gd"
```

**注意**：EventHelpers 必须在 EventManager 之前加载。

## 支持的事件

1. **on_character_clicked()** - 角色被点击
2. **on_user_start_chat()** - 用户发起聊天
3. **on_enter_scene()** - 进入角色所在场景
4. **on_leave_scene()** - 离开角色所在场景
5. **on_chat_turn_end()** - 一轮对话结束（AI回复判断点）
6. **on_chat_session_end(turn_count)** - 完整对话结束
7. **on_idle_timeout()** - 空闲超时（自动触发）

## 使用方法

### 1. 角色被点击

```gdscript
func _on_character_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var result = EventManager.on_character_clicked()
		
		if result.success:
			# 开始聊天或显示互动菜单
			start_chat()
		else:
			# 显示失败消息
			show_message(result.message)
```

### 2. 用户发起聊天

```gdscript
func _on_chat_button_pressed():
	var result = EventManager.on_user_start_chat()
	
	if result.success:
		# 打开聊天窗口
		open_chat_dialog()
	else:
		# 显示拒绝消息
		show_rejection_message(result.message)
```

### 3. 场景切换

```gdscript
func change_scene(new_scene_id: String):
	var old_scene = current_scene_id
	var character_scene = get_character_scene()
	
	# 离开角色所在场景
	if old_scene == character_scene and new_scene_id != character_scene:
		EventManager.on_leave_scene()
	
	# 切换场景
	current_scene_id = new_scene_id
	
	# 进入角色所在场景
	if new_scene_id == character_scene and old_scene != character_scene:
		EventManager.on_enter_scene()
```

### 4. AI对话判断

```gdscript
func should_ai_reply() -> bool:
	var result = EventManager.on_chat_turn_end()
	return result.success
```

### 5. 对话结束

```gdscript
func _on_end_chat_pressed():
	var turn_count = message_history.size()
	var result = EventManager.on_chat_session_end(turn_count)
	
	close_chat_dialog()
	print(result.message)
```

### 6. 监听事件完成

```gdscript
func _ready():
	EventManager.event_completed.connect(_on_event_completed)

func _on_event_completed(event_name: String, result):
	print("事件完成: ", event_name)
	print("成功: ", result.success)
	print("消息: ", result.message)
	print("好感度变化: ", result.affection_change)
	print("交互意愿变化: ", result.willingness_change)
```

## 事件结果结构

每个事件函数返回 `EventResult` 对象：

```gdscript
class EventResult:
	var success: bool              # 是否成功
	var message: String            # 提示消息
	var affection_change: int      # 好感度变化
	var willingness_change: int    # 交互意愿变化
	var mood_change: String        # 心情变化
	var energy_change: int         # 精力变化
```

## 辅助函数

EventHelpers 提供以下辅助函数：

### 计算相关
- `calculate_success_chance(base_willingness)` - 计算成功概率
- `get_mood_modifier()` - 获取心情修正值
- `get_energy_modifier()` - 获取精力修正值

### 数值修改
- `modify_affection(change)` - 修改好感度
- `modify_willingness(change)` - 修改交互意愿
- `modify_mood(new_mood)` - 修改心情
- `modify_energy(change)` - 修改精力

### 信息获取
- `get_character_name()` - 获取角色名称
- `get_affection()` - 获取当前好感度
- `get_willingness()` - 获取当前交互意愿
- `get_mood()` - 获取当前心情
- `get_energy()` - 获取当前精力

## 冷却管理

```gdscript
# 检查冷却
if EventManager.is_on_cooldown("user_start_chat"):
	var remaining = EventManager.get_cooldown_remaining("user_start_chat")
	print("还需等待 %.1f 秒" % remaining)

# 清除冷却（调试用）
EventManager.clear_cooldown("user_start_chat")
EventManager.clear_all_cooldowns()
```

## 成功率计算公式

```
成功率 = (基础意愿 + 当前交互意愿 - 100) / 100 + 心情修正 + 精力修正
```

### 心情修正
- happy: +20%
- excited: +30%
- normal: 0%
- sad: -20%
- angry: -40%

### 精力修正
- high (80+): +10%
- normal (40-79): 0%
- low (20-39): -15%
- exhausted (<20): -30%

## 修改事件逻辑

所有事件逻辑都在 `event_manager.gd` 中，直接修改对应的函数即可：

```gdscript
func on_character_clicked() -> EventResult:
	reset_idle_timer()
	
	if is_on_cooldown("character_clicked"):
		return EventResult.new(false, "冷却中")
	
	var base_willingness = 150  # 修改基础意愿
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		result.affection_change = randi_range(1, 3)  # 修改数值范围
		result.willingness_change = randi_range(5, 10)
		result.message = "角色注意到了你"
		_set_cooldown("character_clicked", 5.0)  # 修改冷却时间
	else:
		result.message = helpers.get_character_name() + "似乎没注意到你"
		_set_cooldown("character_clicked", 10.0)
	
	_apply_result(result)
	event_completed.emit("character_clicked", result)
	return result
```

## 添加新事件

1. 在 `event_manager.gd` 中添加新函数：

```gdscript
func on_gift_given(gift_value: int) -> EventResult:
	"""事件：送礼物"""
	reset_idle_timer()
	
	if is_on_cooldown("gift_given"):
		return EventResult.new(false, "冷却中")
	
	# 根据礼物价值调整成功率
	var base_willingness = 100 + gift_value
	var success_chance = helpers.calculate_success_chance(base_willingness)
	var success = randf() < success_chance
	
	var result = EventResult.new(success)
	
	if success:
		result.affection_change = randi_range(5, 10)
		result.willingness_change = randi_range(10, 20)
		result.message = helpers.get_character_name() + "很喜欢这个礼物"
		_set_cooldown("gift_given", 60.0)
	else:
		result.message = helpers.get_character_name() + "现在不想收礼物"
		_set_cooldown("gift_given", 30.0)
	
	_apply_result(result)
	event_completed.emit("gift_given", result)
	return result
```

2. 在需要的地方调用：

```gdscript
func _on_gift_button_pressed():
	var result = EventManager.on_gift_given(50)
	show_message(result.message)
```

## 注意事项

1. EventHelpers 必须在 EventManager 之前加载
2. 依赖 SaveManager 自动加载节点
3. 空闲计时器会在大部分事件触发时重置（除了 on_idle_timeout）
4. 每个事件有独立的冷却时间
5. 数值变化会自动应用并保存
6. on_chat_turn_end 不检查冷却，每轮都可以触发
