# 角色位置控制功能

## 功能概述
实现了AI控制角色位置的功能，以及优化了角色位置相关逻辑。

## 核心改动

### 1. 提示词构建器 (prompt_builder.gd)
- 添加了 `_generate_scenes_list()` 函数，从 scenes.json 生成场景列表
- 添加了 `get_scene_id_by_index()` 函数，根据索引获取场景ID
- 在系统提示词中添加了 `{scenes}` 占位符的替换

### 2. AI服务 (ai_service.gd)
- 在流式响应处理中提取 `goto` 字段
- 添加了 `get_goto_field()` 函数获取goto值
- 添加了 `clear_goto_field()` 函数清除goto值
- goto字段不会通过 `chat_fields_extracted` 信号发送，而是在对话结束时处理

### 3. 角色控制 (character.gd)
- 修改了 `end_chat()` 函数，检查AI是否决定了场景变化
- 添加了 `_check_goto_scene()` 函数，处理goto字段
- 添加了 `_reload_with_probability()` 函数，实现概率位置逻辑：
  - 70%概率：回到原位置
  - 25%概率：当前场景的随机位置
  - 5%概率：其他场景的随机位置
- 添加了 `_reload_same_preset()` 函数，重新加载相同预设
- 添加了 `_get_random_other_scene()` 函数，获取随机其他场景

### 4. 侧边栏 (sidebar.gd)
- 添加了 `character_location_label` 显示角色位置
- 添加了 `_get_scene_name()` 函数获取场景名称
- 添加了 `_get_character_name()` 函数获取角色名称
- 监听 `character_scene_changed` 信号以实时更新显示

### 5. 存档管理器 (save_manager.gd)
- 添加了 `character_scene_changed` 信号
- 在 `set_character_scene()` 中发出信号

## 使用说明

### AI提示词中的goto字段
在 ai_config.json 的 system_prompt 中已经包含了goto字段：
```
"goto": <int> 可选，前往的地点，必须是其中之一，**只写序号**：{scenes}。
```

### 场景索引映射
场景索引**从0开始**，按照 scenes.json 中的顺序：
- 0 = 客厅 (livingroom)
- 1 = 卧室 (bedroom)
- 2 = 浴室 (bathroom)
- 3 = 书房 (studyroom)

注意：索引从0开始是编程惯例，与AI提示词中的格式一致。

### 位置变化逻辑
1. 如果AI在回复中包含了有效的goto字段，角色会移动到指定场景的随机位置
2. 如果goto字段无效或与当前场景相同，会被忽略
3. 如果没有goto字段，按照概率决定位置

## 重要修复

### 修复1: goto触发时机
- 当接收到有效的goto后，等待聊天框变成输入状态
- 在所有句子显示完毕后，检查是否有goto字段
- 如果有有效的goto：
  1. 先切换到输入模式（播放动画）
  2. 等待动画完全结束
  3. 再结束聊天（触发角色移动）
- 这样确保聊天框大小已还原，避免UI问题

### 修复2: 角色只在所在场景显示
- 在 `load_character_for_scene()` 开始时检查角色是否应该在该场景
- 如果角色不在该场景，直接隐藏并返回
- 添加了 `_get_character_scene()` 函数从SaveManager获取角色所在场景

### 修复3: 进入场景时应用概率系统
- 添加了 `apply_enter_scene_probability()` 函数
- 用户进入角色所在场景时，应用相同的概率系统：
  - 70%概率：角色保持原位置
  - 25%概率：角色移动到当前场景的随机位置
  - 5%概率：角色移动到其他场景
- 在 `main.gd` 的 `_try_scene_interaction()` 中调用

## 测试建议
1. 测试AI是否能正确输出goto字段
2. 测试角色是否能正确移动到指定场景
3. 测试概率位置逻辑是否正常工作
4. 测试侧边栏是否正确显示角色位置
5. 测试角色是否只在所在场景显示
6. 测试用户进入场景时的概率位置变化
