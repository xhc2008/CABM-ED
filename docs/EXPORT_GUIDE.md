# 导出指南

## Windows 导出

### 方案 A：带 DLL 分发（推荐）

1. 在 Godot 编辑器中导出 Windows 版本
2. 导出后会生成 `CABM-ED.exe`
3. **重要**：需要保持目录结构！运行 `copy_dll_for_windows.bat` 自动创建
4. 最终分发包结构：
   ```
   dist/
   ├── CABM-ED.exe
   └── addons/
       └── cosine_calculator/
           └── bin/
               └── libcosine_calculator.windows.template_release.x86_64.dll
   ```
5. **分发整个 dist 文件夹**，不要只分发 exe！

### 方案 B：不使用 C++ 插件

如果不想分发 DLL，可以禁用 C++ 插件：

1. 删除或重命名 `addons/cosine_calculator/cosine_calculator.gdextension`
2. 系统会自动使用 GDScript 实现
3. 性能会稍慢，但功能完全相同

**性能对比：**
- 小规模（<100条记忆）：几乎无差异
- 中规模（100-500条）：GDScript 慢 5-10 倍
- 大规模（>500条）：GDScript 慢 20-50 倍

## Android 导出

### 1. 编译 Android 库（可选但推荐）

参考 `addons/cosine_calculator/BUILD_ANDROID.md`

```cmd
# 设置 NDK 路径
set ANDROID_NDK_ROOT=C:\android-ndk-r27d

# 编译
cd addons\cosine_calculator
scons platform=android target=template_release arch=arm64
```

### 2. 在 Godot 中导出

1. **项目 → 导出**
2. 选择 **Android** 预设
3. 配置检查：
   - ✓ `architectures/arm64-v8a` 已勾选
   - ✓ `package/unique_name` 已设置
   - ✓ `package/signed` 已启用
4. 点击 **导出项目**

### 3. 测试

```cmd
# 安装到设备
adb install CABM-ED.apk

# 查看日志
adb logcat | findstr "godot"
```

## Linux 导出

1. 在 Godot 编辑器中导出 Linux 版本
2. 如果使用 C++ 插件，需要编译 Linux 版本：
   ```bash
   cd addons/cosine_calculator
   scons platform=linux target=template_release arch=x86_64
   ```
3. 导出的 `.x86_64` 文件已包含所有资源

## iOS 导出

iOS 需要：
1. macOS 系统
2. Xcode
3. 编译 iOS 版本的插件：
   ```bash
   cd addons/cosine_calculator
   scons platform=ios target=template_release arch=arm64
   ```

## Web 导出

**注意**：GDExtension C++ 插件不支持 Web 导出。

Web 导出会自动使用 GDScript 实现，无需额外配置。

## 常见问题

### Q: Windows 导出后运行报错找不到 DLL？
A: DLL 必须保持在 `addons/cosine_calculator/bin/` 目录结构中，不能直接放在 exe 旁边！
   运行 `copy_dll_for_windows.bat` 自动创建正确的目录结构。

### Q: Android APK 安装后崩溃？
A: 
1. 检查是否编译了 Android 版本的库
2. 查看 logcat 日志：`adb logcat | findstr "godot"`
3. 如果没有编译库，系统应该自动降级到 GDScript

### Q: 能否将 DLL 嵌入到 exe？
A: Godot 的 GDExtension 不支持将 DLL 嵌入到 exe。必须分发 DLL 或禁用插件。

### Q: 不同平台需要重新编译吗？
A: 是的，每个平台需要单独编译：
- Windows → `.dll`
- Linux → `.so`
- macOS → `.framework`
- Android → `.so` (ARM)
- iOS → `.framework` (ARM)

## 推荐工作流

### 开发阶段
- 使用 GDScript 实现（无需编译）
- 快速迭代和测试

### 发布阶段
- 编译目标平台的 C++ 插件
- 进行性能测试
- 如果性能足够，可以不使用 C++ 插件

## 自动化脚本

创建一个批处理脚本来自动复制 DLL：

```cmd
@echo off
echo 复制 Windows DLL...
copy /Y addons\cosine_calculator\bin\libcosine_calculator.windows.template_release.x86_64.dll .\
echo 完成！
```

保存为 `copy_dll.bat`，导出后运行即可。
