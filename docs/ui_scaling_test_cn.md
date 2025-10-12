# UI 自适应测试说明

## 已完成的改动

### 1. 项目配置更新
✅ 在 `project.godot` 中添加了显示缩放配置
- 拉伸模式设置为 `canvas_items`（自动缩放 UI）
- 宽高比设置为 `expand`（填充整个屏幕）
- 支持手持设备方向

### 2. 创建全局主题
✅ 创建了 `default_theme.tres` 文件
- 定义了统一的字体大小
- 所有 UI 组件使用相对大小

### 3. 代码优化
✅ 移除了所有硬编码的字体大小
- `sidebar.gd`: 时钟、标签、按钮等
- `main.gd`: 失败消息标签

## 如何测试

### 在 Godot 编辑器中测试

1. **打开项目**
   - 在 Godot 中打开项目

2. **应用主题**（重要！）
   - 打开 `scripts/main.tscn` 场景
   - 选择根节点（Control 节点）
   - 在 Inspector 面板找到 "Theme" 属性
   - 将 `default_theme.tres` 拖拽到 Theme 属性中
   - 保存场景

3. **测试不同分辨率**
   - 运行项目
   - 调整窗口大小，观察 UI 是否自动缩放
   - 或在编辑器中：项目 → 项目设置 → 显示 → 窗口，修改测试分辨率

### 在手机上测试

1. **导出 APK**
   - 项目 → 导出
   - 选择 Android 平台
   - 导出并安装到手机

2. **检查项目**
   - 字体大小是否合适
   - UI 元素是否清晰可见
   - 按钮是否容易点击

## 预期效果

- ✅ 桌面大屏幕：UI 正常显示，字体清晰
- ✅ 手机小屏幕：UI 自动缩放，字体不会太小
- ✅ 不同分辨率：UI 保持一致的视觉比例

## 如果字体还是太小

可以调整 `default_theme.tres` 中的字体大小：

```gdresource
default_font_size = 20  # 从 16 增加到 20

Button/font_sizes/font_size = 20
Label/font_sizes/font_size = 20
LineEdit/font_sizes/font_size = 20
CheckBox/font_sizes/font_size = 18
```

## 故障排除

**问题：UI 没有自动缩放**
- 确认 `project.godot` 中的 `[display]` 配置已正确添加
- 重启 Godot 编辑器

**问题：字体还是固定大小**
- 确认主题文件已应用到主场景
- 检查是否有其他脚本覆盖了字体设置

**问题：手机上 UI 太大或太小**
- 调整 `default_theme.tres` 中的 `default_font_size`
- 或修改 `project.godot` 中的基础分辨率
