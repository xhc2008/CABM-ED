# 配置系统测试指南

## 测试目的
验证音频配置系统在开发环境和打包后都能正常工作。

## 测试环境

### 开发环境测试
在Godot编辑器中运行游戏

### 打包环境测试
- Windows: 导出为 .exe
- Android: 导出为 .apk
- Linux: 导出为可执行文件
- macOS: 导出为 .app

## 测试用例

### 1. 配置文件加载测试

**步骤**：
1. 启动游戏
2. 查看控制台日志

**预期结果**：
```
✅ 默认音频配置已加载
ℹ️ 用户音频设置不存在，将使用默认值
🔊 音量设置: BGM=30%, 氛围音=30%
```

**验证点**：
- [ ] 默认配置成功加载
- [ ] 音量设置正确应用
- [ ] 没有错误信息

### 2. 音量保存测试

**步骤**：
1. 打开音乐播放器面板
2. 调整BGM音量到50%
3. 调整氛围音音量到70%
4. 关闭游戏
5. 重新启动游戏

**预期结果**：
```
✅ 默认音频配置已加载
✅ 用户音频设置已加载
🔊 音量设置: BGM=50%, 氛围音=70%
💾 用户音频设置已保存到: user://audio_settings.json
```

**验证点**：
- [ ] 音量设置被保存
- [ ] 重启后音量恢复到上次设置
- [ ] user://audio_settings.json 文件存在

### 3. 自定义BGM保存测试

**步骤**：
1. 上传一个自定义BGM
2. 播放该BGM
3. 关闭游戏
4. 重新启动游戏

**预期结果**：
```
✅ 用户音频设置已加载
🎵 恢复上次播放的BGM: user://custom_bgm/test.ogg
✅ 播放自定义BGM: user://custom_bgm/test.ogg
```

**验证点**：
- [ ] BGM路径被保存
- [ ] 重启后自动播放上次的BGM
- [ ] 文件路径正确

### 4. 打包后配置测试（重要！）

**步骤**：
1. 导出游戏到目标平台
2. 在目标平台运行游戏
3. 调整音量设置
4. 上传并播放自定义BGM
5. 关闭游戏
6. 重新启动游戏

**预期结果**：
- 所有设置都能正常保存和恢复
- 没有"权限拒绝"或"文件不存在"错误

**验证点**：
- [ ] 打包后能正常加载默认配置
- [ ] 打包后能创建用户设置文件
- [ ] 打包后能保存音量设置
- [ ] 打包后能保存自定义BGM路径
- [ ] 重启后所有设置正确恢复

### 5. 跨平台路径测试

**Windows测试**：
```
用户设置路径: %APPDATA%\Godot\app_userdata\[项目名]\audio_settings.json
自定义BGM路径: %APPDATA%\Godot\app_userdata\[项目名]\custom_bgm\
```

**Android测试**：
```
用户设置路径: /data/data/[包名]/files/audio_settings.json
自定义BGM路径: /data/data/[包名]/files/custom_bgm/
```

**验证点**：
- [ ] 文件路径符合平台规范
- [ ] 文件可以正常读写
- [ ] 应用卸载前数据持久化

### 6. 错误恢复测试

**步骤**：
1. 手动删除 user://audio_settings.json
2. 启动游戏

**预期结果**：
```
ℹ️ 用户音频设置不存在，将使用默认值
🔊 音量设置: BGM=30%, 氛围音=30%
```

**验证点**：
- [ ] 游戏不会崩溃
- [ ] 自动使用默认设置
- [ ] 可以重新保存设置

### 7. 无效BGM路径测试

**步骤**：
1. 手动编辑 user://audio_settings.json
2. 设置一个不存在的BGM路径
3. 启动游戏

**预期结果**：
```
⚠️ 上次播放的BGM文件不存在: user://custom_bgm/deleted.ogg
💾 用户音频设置已保存到: user://audio_settings.json
```

**验证点**：
- [ ] 游戏不会崩溃
- [ ] 自动清除无效路径
- [ ] 保存更新后的配置

## 测试工具

### 查看用户配置文件

**Windows**:
```cmd
notepad %APPDATA%\Godot\app_userdata\[项目名]\audio_settings.json
```

**Linux/Mac**:
```bash
cat ~/.local/share/godot/app_userdata/[项目名]/audio_settings.json
```

**Android** (需要root或调试模式):
```bash
adb shell cat /data/data/[包名]/files/audio_settings.json
```

### 清除用户配置（重置测试）

**Windows**:
```cmd
del %APPDATA%\Godot\app_userdata\[项目名]\audio_settings.json
```

**Linux/Mac**:
```bash
rm ~/.local/share/godot/app_userdata/[项目名]/audio_settings.json
```

## 自动化测试脚本

```gdscript
# test_audio_config.gd
extends Node

func _ready():
    test_config_system()

func test_config_system():
    print("=== 开始配置系统测试 ===")
    
    # 测试1: 检查默认配置
    var audio_mgr = get_node("/root/Main/AudioManager")
    assert(audio_mgr != null, "AudioManager存在")
    
    # 测试2: 检查音量范围
    var bgm_vol = audio_mgr.get_bgm_volume()
    assert(bgm_vol >= 0.0 and bgm_vol <= 1.0, "BGM音量在有效范围")
    
    # 测试3: 保存和加载
    audio_mgr.set_bgm_volume(0.5)
    await get_tree().create_timer(0.1).timeout
    
    # 测试4: 检查文件存在
    var user_config_path = "user://audio_settings.json"
    assert(FileAccess.file_exists(user_config_path), "用户配置文件已创建")
    
    print("=== 配置系统测试完成 ===")
```

## 测试清单

### 开发阶段
- [ ] 默认配置加载正常
- [ ] 音量调节正常
- [ ] 音量保存正常
- [ ] 自定义BGM保存正常
- [ ] 重启后设置恢复正常

### 打包前
- [ ] 清理测试数据
- [ ] 验证默认配置文件完整
- [ ] 验证路径使用正确（user:// vs res://）

### 打包后（Windows）
- [ ] 配置加载正常
- [ ] 配置保存正常
- [ ] 路径正确
- [ ] 重启后恢复正常

### 打包后（Android）
- [ ] 配置加载正常
- [ ] 配置保存正常
- [ ] 路径正确
- [ ] 重启后恢复正常
- [ ] 应用切换后状态正常

### 打包后（iOS）
- [ ] 配置加载正常
- [ ] 配置保存正常
- [ ] 路径正确
- [ ] 重启后恢复正常
- [ ] 应用切换后状态正常

## 已知问题

### 问题1: 打包后无法保存配置
**原因**: 使用了 res:// 路径
**解决**: 改用 user:// 路径

### 问题2: Android上路径错误
**原因**: 使用了绝对路径
**解决**: 使用 user:// 相对路径

### 问题3: 配置文件损坏
**原因**: JSON格式错误
**解决**: 添加错误处理，使用默认配置

## 测试报告模板

```
测试日期: YYYY-MM-DD
测试平台: [Windows/Android/iOS/Linux/macOS]
测试版本: [版本号]

测试结果:
✅ 配置加载: 通过
✅ 音量保存: 通过
✅ BGM保存: 通过
✅ 重启恢复: 通过
✅ 路径正确: 通过

问题记录:
[无/描述问题]

备注:
[其他说明]
```

## 更新日志

- **2024-10-31**: 初始版本，添加配置系统测试指南
