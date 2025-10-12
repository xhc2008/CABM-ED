# 快速开始 - UI 自适应

## 🎯 一分钟设置

### 步骤 1: 应用主题
1. 打开 Godot 编辑器
2. 打开场景：`scripts/main.tscn`
3. 选择根节点（Control）
4. 拖拽 `default_theme.tres` 到 Inspector 的 "Theme" 属性
5. 保存（Ctrl+S）

### 步骤 2: 测试
运行项目，调整窗口大小，观察 UI 是否自动缩放。

## 📱 手机测试

导出 APK 并安装到手机，检查字体大小是否合适。

## 🔧 调整字体大小

当前字体大小已设置为 **20**（适合大多数屏幕）。

如果需要调整，编辑 `default_theme.tres`：

```gdresource
default_font_size = 20  # 当前值
```

推荐值：
- 手机：20-24
- 平板：18-22
- 桌面：16-20

## ✅ 完成的改动

- ✅ 项目配置已更新（自动缩放）
- ✅ 全局主题已创建
- ✅ 所有硬编码字体大小已移除
- ✅ 按钮固定高度已移除

## 📚 详细文档

- `UI_SCALING_CHANGES.md` - 完整改动列表
- `docs/ui_scaling_guide.md` - 技术说明
- `docs/ui_scaling_test_cn.md` - 测试指南
