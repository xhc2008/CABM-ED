# 编译 Cosine Calculator C++ 插件

## 为什么需要编译？

C++插件提供高性能的余弦相似度计算，相比GDScript实现性能提升10-50倍。

**不编译也可以使用**：系统会自动降级到GDScript实现，功能完全相同，只是速度较慢。

## 前置要求

1. **Python 3.6+**
2. **SCons** 构建工具：`pip install scons`
3. **C++ 编译器**：
   - Windows: Visual Studio 2019+ 或 MinGW
   - Linux: GCC 或 Clang
   - macOS: Xcode Command Line Tools

## 编译步骤

### Windows (推荐使用 Visual Studio)

```cmd
# 1. 打开 x64 Native Tools Command Prompt for VS 2019/2022

# 2. 进入插件目录
cd addons\cosine_calculator

# 3. 编译 Debug 版本
scons platform=windows target=template_debug

# 4. 编译 Release 版本
scons platform=windows target=template_release
```

### Linux

```bash
# 1. 进入插件目录
cd addons/cosine_calculator

# 2. 编译 Debug 版本
scons platform=linux target=template_debug

# 3. 编译 Release 版本
scons platform=linux target=template_release
```

### macOS

```bash
# 1. 进入插件目录
cd addons/cosine_calculator

# 2. 编译 Debug 版本
scons platform=macos target=template_debug

# 3. 编译 Release 版本
scons platform=macos target=template_release
```

## 验证编译结果

编译成功后，`bin` 目录应该包含编译好的库文件：

### Windows
```
bin/libcosine_calculator.windows.template_debug.x86_64.dll
bin/libcosine_calculator.windows.template_release.x86_64.dll
```

### Linux
```
bin/libcosine_calculator.linux.template_debug.x86_64.so
bin/libcosine_calculator.linux.template_release.x86_64.so
```

### macOS
```
bin/libcosine_calculator.macos.template_debug.framework/
bin/libcosine_calculator.macos.template_release.framework/
```

## 测试插件

在Godot中运行项目，查看控制台输出：

- ✅ 成功：`✓ 余弦计算插件加载成功（C++高性能模式）`
- ⚠️ 降级：`ℹ 余弦计算插件未编译，使用GDScript实现`

## 常见问题

### Q: 找不到 godot-cpp？
A: 确保项目根目录有 `godot-cpp` 子模块。如果没有：
```bash
git submodule update --init --recursive
```

### Q: 编译错误？
A: 
1. 确保使用正确的编译器（Windows需要VS的命令行工具）
2. 检查 `SConstruct` 文件中的路径配置
3. 确保 godot-cpp 已正确初始化

### Q: 不想编译可以吗？
A: 完全可以！系统会自动使用GDScript实现，功能完全相同，只是：
- 小规模数据（<100条）：影响不大
- 中规模数据（100-500条）：可能有轻微延迟
- 大规模数据（>500条）：建议编译C++插件

## 性能对比

| 记忆数量 | GDScript | C++ 插件 | 提升倍数 |
|---------|----------|----------|---------|
| 50条    | ~5ms     | ~2ms     | 2.5x    |
| 100条   | ~15ms    | ~3ms     | 5x      |
| 500条   | ~200ms   | ~10ms    | 20x     |
| 1000条  | ~800ms   | ~20ms    | 40x     |

## 更多信息

- Godot GDExtension 文档：https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/
- godot-cpp 仓库：https://github.com/godotengine/godot-cpp
