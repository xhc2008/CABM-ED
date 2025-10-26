# ChatDialog 重构说明

## 概述

原 `chat_dialog.gd` 文件有 1147 行代码，功能复杂且难以维护。现已拆分为 5 个模块化文件。

## 文件结构

### 1. `chat_dialog.gd` (主文件，约 600 行)
**职责：** 核心逻辑协调和业务流程控制

**主要功能：**
- 对话流程管理（输入/回复模式切换）
- AI 服务集成和响应处理
- goto 字段处理和场景切换逻辑
- 配置加载和初始化
- 模块间协调

**关键方法：**
- `show_dialog()` - 显示对话框
- `hide_dialog()` - 隐藏对话框
- `_on_ai_response()` - 处理 AI 响应
- `_check_and_handle_goto()` - goto 逻辑处理
- `_on_input_submitted()` - 用户输入处理

### 2. `chat_dialog_input_handler.gd` (约 40 行)
**职责：** 输入事件处理

**主要功能：**
- 监听键盘和鼠标输入
- 支持多种继续方式：
  - 鼠标左键点击
  - 空格键 (KEY_SPACE)
  - F 键 (KEY_F)
- 管理等待继续状态

**信号：**
- `continue_requested` - 用户请求继续

### 3. `chat_dialog_typing.gd` (约 150 行)
**职责：** 打字机效果和流式输出

**主要功能：**
- 流式内容接收和缓冲
- 句子分段（按中文标点符号）
- 逐字显示动画
- TTS 语音合成触发

**信号：**
- `sentence_completed` - 单个句子显示完成
- `all_sentences_completed` - 所有句子显示完成

**关键方法：**
- `start_stream()` - 开始流式接收
- `add_stream_content()` - 添加流式内容
- `end_stream()` - 结束流式接收
- `show_next_sentence()` - 显示下一句

### 4. `chat_dialog_ui_manager.gd` (约 120 行)
**职责：** UI 动画和模式切换

**主要功能：**
- 输入模式 ↔ 回复模式平滑过渡
- 高度动画（120px ↔ 200px）
- 元素淡入淡出效果
- 继续指示器管理

**关键方法：**
- `transition_to_reply_mode()` - 切换到回复模式
- `transition_to_input_mode()` - 切换到输入模式
- `show_continue_indicator()` - 显示继续指示器
- `hide_continue_indicator()` - 隐藏继续指示器

### 5. `chat_dialog_history.gd` (约 250 行)
**职责：** 对话历史记录管理

**主要功能：**
- 历史面板创建和布局
- 对话历史显示（扁平化格式）
- 历史面板展开/收起动画
- 从 AI 服务获取对话记录

**关键方法：**
- `toggle_history()` - 切换历史显示
- `show_history()` - 显示历史面板
- `hide_history()` - 隐藏历史面板
- `_update_history_content()` - 更新历史内容

## 新增功能

### 键盘快捷键支持
在"点击屏幕继续"状态下，现在支持：
- **鼠标左键点击** - 原有功能
- **空格键 (Space)** - 新增
- **F 键** - 新增

这使得用户可以更方便地继续对话，无需移动鼠标。

## 模块间通信

```
chat_dialog.gd (主控制器)
    ├── input_handler (输入处理)
    │   └── continue_requested → _on_continue_clicked()
    │
    ├── typing_manager (打字效果)
    │   ├── sentence_completed → _on_sentence_completed()
    │   └── all_sentences_completed → _on_all_sentences_completed()
    │
    ├── ui_manager (UI 动画)
    │   ├── transition_to_reply_mode()
    │   ├── transition_to_input_mode()
    │   └── show/hide_continue_indicator()
    │
    └── history_manager (历史记录)
        └── toggle_history()
```

## 优势

1. **可维护性提升**
   - 每个模块职责单一，易于理解
   - 代码行数减少，查找问题更快

2. **可扩展性增强**
   - 新增输入方式只需修改 `input_handler`
   - 新增动画效果只需修改 `ui_manager`
   - 各模块独立，互不影响

3. **可测试性改善**
   - 每个模块可独立测试
   - 模拟信号更容易

4. **性能优化**
   - 模块按需加载
   - 减少主文件复杂度

## 向后兼容

- 保持所有原有信号和公共方法
- 场景文件无需修改
- 配置文件格式不变

## 使用示例

```gdscript
# 显示对话框（用户先说）
chat_dialog.show_dialog("passive")

# 显示对话框（角色主动）
chat_dialog.show_dialog("active")

# 隐藏对话框
chat_dialog.hide_dialog()

# 连接信号
chat_dialog.chat_ended.connect(_on_chat_ended)
```

## 注意事项

1. 所有模块文件必须放在 `res://scripts/` 目录下
2. 模块初始化顺序很重要（在 `_init_modules()` 中定义）
3. 历史管理器需要延迟初始化（使用 `call_deferred`）
