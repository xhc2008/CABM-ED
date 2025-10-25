# C++插件故障排查

## 问题：Godot尝试导入.obj文件

### 症状
```
ERROR: Couldn't read OBJ file 'res://addons/cosine_calculator/src/xxx.obj'
ERROR: Error importing 'res://addons/cosine_calculator/src/xxx.obj'
```

### 原因
Godot把C++编译的中间文件（.obj）当成3D模型文件导入了。

### 解决方案 ✅
已添加 `src/.gdignore` 文件，Godot会忽略该目录。

如果问题仍然存在：
1. 关闭Godot
2. 删除 `.godot/imported/` 目录
3. 删除 `src/*.obj.import` 文件
4. 重新打开Godot

## 问题：找不到DLL文件

### 症状
```
ERROR: GDExtension dynamic library not found
```

### 检查清单
1. ✅ 确认DLL文件存在：
   - Debug: `bin/libcosine_calculator.windows.template_debug.x86_64.dll`
   - Release: `bin/libcosine_calculator.windows.template_release.x86_64.dll`

2. ✅ 确认.gdextension文件正确：
   - 路径：`addons/cosine_calculator/cosine_calculator.gdextension`
   - 内容包含正确的DLL路径

3. ✅ 重启Godot编辑器

## 问题：插件加载失败

### 症状
控制台显示：
```
ℹ 余弦计算插件未编译，使用GDScript实现
```

### 可能原因
1. DLL依赖缺失（需要Visual C++ Redistributable）
2. DLL版本不匹配（32位/64位）
3. godot-cpp版本不匹配

### 解决方案
1. 安装 Visual C++ Redistributable 2019+
2. 确认编译的是x86_64版本
3. 重新编译godot-cpp和插件

## 验证插件是否正常工作

运行游戏，查看控制台：

### ✅ 成功
```
✓ 余弦计算插件加载成功（C++高性能模式）
记忆系统初始化完成
```

### ⚠️ 降级模式（仍可使用）
```
ℹ 余弦计算插件未编译，使用GDScript实现（性能较低但功能完整）
记忆系统初始化完成
```

## 清理编译产物

如果需要重新编译：

```cmd
cd addons\cosine_calculator
scons --clean
```

然后重新编译：
```cmd
scons platform=windows target=template_debug
scons platform=windows target=template_release
```

## 不想编译？

完全可以！系统会自动使用GDScript实现，功能完全相同，只是：
- 小规模数据（<100条）：影响不大
- 中规模数据（100-500条）：可能有轻微延迟
- 大规模数据（>500条）：建议使用C++插件
