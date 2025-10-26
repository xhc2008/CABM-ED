# ChatDialog 迁移指南

## 快速开始

重构后的代码完全向后兼容，无需修改场景文件或其他调用代码。

## 文件清单

确保以下文件存在于 `res://scripts/` 目录：

- ✅ `chat_dialog.gd` (主文件，已重构)
- ✅ `chat_dialog_input_handler.gd` (新增)
- ✅ `chat_dialog_typing.gd` (新增)
- ✅ `chat_dialog_ui_manager.gd` (新增)
- ✅ `chat_dialog_history.gd` (新增)

## 新功能测试

### 测试键盘快捷键

1. 启动游戏并进入对话
2. 等待角色说话完毕，出现"点击屏幕继续"提示
3. 尝试以下操作：
   - 按 **空格键** → 应该继续到下一句
   - 按 **F 键** → 应该继续到下一句
   - **点击鼠标左键** → 应该继续到下一句（原有功能）

### 测试模块化功能

所有原有功能应该正常工作：
- ✅ 对话输入和发送
- ✅ AI 流式响应显示
- ✅ 打字机效果
- ✅ 句子分段显示
- ✅ 历史记录查看
- ✅ goto 场景切换
- ✅ TTS 语音合成
- ✅ 空闲超时处理

## 常见问题

### Q: 游戏启动时报错找不到模块文件
**A:** 确保所有 5 个文件都在 `res://scripts/` 目录下，并且文件名拼写正确。

### Q: 键盘快捷键不工作
**A:** 检查 `input_handler` 模块是否正确初始化，查看控制台是否有错误信息。

### Q: 对话显示异常
**A:** 检查 `typing_manager` 模块，确保信号连接正确。

### Q: 历史记录面板无法显示
**A:** 确保 `history_manager` 使用了 `call_deferred` 延迟初始化。

## 回滚方案

如果遇到问题需要回滚到旧版本：

1. 从版本控制系统恢复旧的 `chat_dialog.gd`
2. 删除新增的 4 个模块文件
3. 重启游戏

## 性能对比

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 主文件行数 | 1147 | ~600 |
| 文件数量 | 1 | 5 |
| 平均方法长度 | 较长 | 较短 |
| 代码复用性 | 低 | 高 |

## 开发建议

### 添加新的输入方式

编辑 `chat_dialog_input_handler.gd`：

```gdscript
# 在 _input() 方法中添加
elif event is InputEventKey:
    if event.pressed and not event.echo:
        if event.keycode == KEY_ENTER:  # 新增回车键支持
            should_continue = true
```

### 修改动画效果

编辑 `chat_dialog_ui_manager.gd`：

```gdscript
# 修改动画时长
const ANIMATION_DURATION = 0.5  # 从 0.3 改为 0.5

# 修改高度
const REPLY_HEIGHT = 250.0  # 从 200.0 改为 250.0
```

### 自定义打字速度

编辑 `chat_dialog_typing.gd`：

```gdscript
# 修改打字速度
const TYPING_SPEED = 0.03  # 从 0.05 改为 0.03（更快）
```

## 技术支持

如有问题，请查看：
- `docs/chat_dialog_refactoring.md` - 详细重构说明
- 控制台日志 - 查看运行时错误
- Godot 调试器 - 检查节点树和信号连接
