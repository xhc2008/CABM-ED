# Goto功能修复说明

## 修复的问题

### 1. 场景索引统一性
**问题**: 需要确认场景索引是从0还是从1开始

**解决方案**:
- 场景索引**统一从0开始**（编程惯例）
- `_generate_scenes_list()` 生成的列表格式：`0=客厅, 1=卧室, 2=浴室, 3=书房`
- `get_scene_id_by_index()` 接收0-based索引
- AI提示词中的格式与实现一致

**代码位置**: `scripts/prompt_builder.gd`

### 2. Goto触发时机优化
**问题**: 需要等待聊天框变为输入模式的动画结束后才结束聊天

**原因**: 
- 聊天框在回复模式和输入模式有不同的高度
- 如果在动画过程中结束聊天，可能导致UI布局问题
- 需要确保聊天框大小已还原到输入模式的高度

**解决方案**:
在 `_on_continue_clicked()` 中，当检测到有效的goto时：
1. 先调用 `await _transition_to_input_mode()` 切换到输入模式
2. 等待动画完全结束
3. 再调用 `await get_tree().process_frame` 确保UI完全更新
4. 最后调用 `_on_end_button_pressed()` 结束聊天

**代码位置**: `scripts/chat_dialog.gd` 的 `_on_continue_clicked()` 函数

## 完整流程

### Goto触发流程
1. AI在回复中包含goto字段（例如：`"goto": 1`）
2. `ai_service.gd` 在流式响应完成时提取goto字段
3. 用户点击继续，所有句子显示完毕
4. `chat_dialog.gd` 检测到有效的goto
5. 播放切换到输入模式的动画（高度从200px变为120px）
6. 等待动画结束
7. 调用结束聊天
8. `character.gd` 的 `end_chat()` 检测到goto
9. 角色移动到指定场景的随机位置

### 场景索引映射
```
scenes.json中的顺序 -> 索引
livingroom -> 0
bedroom -> 1
bathroom -> 2
studyroom -> 3
```

## 额外修复：角色场景状态保存

### 问题
角色移动到新场景后，SaveManager中的角色场景没有更新，导致：
- 侧边栏显示的位置不正确
- 重新加载时角色位置错误

### 解决方案
在以下位置添加 `SaveManager.set_character_scene()` 调用：

1. **end_chat() - goto场景变化时**
   ```gdscript
   if goto_scene != "":
       current_scene = goto_scene
       # 先更新SaveManager
       save_mgr.set_character_scene(current_scene)
       load_character_for_scene(current_scene)
   ```

2. **_reload_with_probability() - 5%概率移动到其他场景时**
   ```gdscript
   current_scene = new_scene
   # 更新SaveManager
   save_mgr.set_character_scene(current_scene)
   load_character_for_scene(current_scene)
   ```

3. **apply_enter_scene_probability() - 已有此逻辑**

### 重要性
必须在调用 `load_character_for_scene()` **之前**更新SaveManager，因为：
- `load_character_for_scene()` 开始时会检查角色是否应该在该场景
- 如果SaveManager中的场景与目标场景不匹配，角色会被隐藏

## 最新修复：忽略相同场景的goto

### 问题
由于AI生成的不稳定性，goto的内容可能就是当前场景。这会导致：
- 对话被终止（因为检测到goto字段）
- 但角色没有实际移动（因为已经在该场景）
- 用户体验不好

### 解决方案
在两个地方添加验证：

1. **chat_dialog.gd 的 `_check_and_handle_goto()`**
   ```gdscript
   // 获取目标场景
   var target_scene = prompt_builder.get_scene_id_by_index(goto_index)
   
   // 获取角色当前场景
   var character_scene = save_mgr.get_character_scene()
   
   // 如果相同，清除goto并返回false
   if target_scene == character_scene:
       ai_service.clear_goto_field()
       return false
   ```

2. **character.gd 的 `_check_goto_scene()`**
   ```gdscript
   // 使用_get_character_scene()获取角色当前场景
   var character_scene = _get_character_scene()
   
   if target_scene == character_scene:
       return ""  // 返回空字符串表示无效
   ```

### 效果
- ✅ goto到当前场景时，对话不会被终止
- ✅ 继续正常的对话流程（切换到输入模式）
- ✅ 避免不必要的场景"移动"

## 测试要点
1. ✅ 场景索引从0开始
2. ✅ Goto触发前等待动画结束
3. ✅ 聊天框高度正确还原
4. ✅ 角色正确移动到指定场景
5. ✅ 无效的goto被正确忽略
6. ✅ 当前场景的goto被正确忽略（对话不终止）
7. ✅ SaveManager中的角色场景正确更新
8. ✅ 侧边栏显示的角色位置正确
