# Bug 修复：聊天框内容残留

## 问题描述
在回复完成后，聊天框的内容没有被清除，导致下次回复时，上一次的内容会短暂显示。

## 问题原因
在 `_transition_to_reply_mode()` 函数中，切换到回复模式时，只是将 `message_label` 设置为可见并调整透明度，但没有清空其 `text` 属性。

## 修复方案
在 `scripts/chat_dialog.gd` 的 `_transition_to_reply_mode()` 函数中，添加清空文本的代码：

```gdscript
# 第三步：准备回复UI元素（但保持透明）
is_input_mode = false
character_name_label.visible = true
message_label.visible = true
character_name_label.text = app_config.get("character_name", "角色")
message_label.text = ""  # ✅ 清除之前的内容
character_name_label.modulate.a = 0.0
message_label.modulate.a = 0.0
```

## 修复位置
文件：`scripts/chat_dialog.gd`
函数：`_transition_to_reply_mode()`
行数：约 160 行

## 测试步骤
1. 运行项目
2. 点击角色，选择"聊天"
3. 输入消息并发送
4. 等待回复完成
5. 点击继续，再次输入消息
6. 观察新回复时，不应该看到上一次的内容

## 状态
✅ 已修复
