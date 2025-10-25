# 编译Debug版本

你已经成功编译了Release版本，但Godot编辑器在开发时需要Debug版本。

## 快速编译Debug版本

在 **x64 Native Tools Command Prompt for VS** 中运行：

```cmd
cd addons\cosine_calculator
scons platform=windows target=template_debug
```

编译完成后，`bin` 目录应该包含：
- `libcosine_calculator.windows.template_debug.x86_64.dll` ✅ 需要这个
- `libcosine_calculator.windows.template_release.x86_64.dll` ✅ 已有

## 验证

重启Godot，查看控制台：
- ✅ 成功：`✓ 余弦计算插件加载成功（C++高性能模式）`
- ❌ 失败：继续显示错误

## 如果不想编译Debug版本

可以临时让Godot使用Release版本（见方案2）
