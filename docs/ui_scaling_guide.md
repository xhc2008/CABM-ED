# UI 自适应缩放指南

## 概述

本项目已配置为支持不同屏幕尺寸的自适应 UI，特别优化了手机屏幕显示。

## 配置说明

### 1. 项目显示设置 (project.godot)

```gdscript
[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2                      # 全屏模式
window/size/resizable=true              # 允许调整窗口大小
window/stretch/mode="canvas_items"      # 拉伸模式：缩放 UI 元素
window/stretch/aspect="expand"          # 宽高比：扩展以填充屏幕
window/handheld/orientation=1           # 手持设备方向
```

**关键设置说明：**
- `stretch/mode="canvas_items"`: 让所有 UI 元素根据屏幕大小自动缩放
- `stretch/aspect="expand"`: 确保 UI 填充整个屏幕，不留黑边
- 这些设置会让字体和 UI 组件在不同屏幕上保持合适的大小

### 2. 主题系统 (default_theme.tres)

创建了全局主题文件，定义了默认字体大小：
- 默认字体大小：16
- 按钮字体：16
- 标签字体：16
- 输入框字体：16
- 复选框字体：14

### 3. 代码改动

移除了所有脚本中的硬编码字体大小设置：
- `sidebar.gd`: 移除了所有 `add_theme_font_size_override()` 调用
- `main.gd`: 移除了失败消息标签的固定字体大小
- `chat_dialog.gd`: 保持原有设计，使用固定高度

## 工作原理

1. **自动缩放**: Godot 会根据屏幕分辨率自动缩放所有 UI 元素
2. **相对大小**: 使用主题定义的相对字体大小，而不是硬编码像素值
3. **响应式布局**: 容器节点（VBoxContainer, HBoxContainer 等）会自动调整子元素布局

## 测试建议

在不同设备上测试：
1. **桌面**: 1920x1080, 1366x768
2. **手机**: 1080x1920 (竖屏), 1920x1080 (横屏)
3. **平板**: 2048x1536

## 注意事项

- 如果需要调整整体 UI 大小，修改 `default_theme.tres` 中的 `default_font_size`
- 避免在代码中使用 `add_theme_font_size_override()`，让主题系统统一管理
- 使用 `custom_minimum_size` 而不是固定的 `size` 来设置 UI 元素尺寸
