# 跨平台音频系统说明

## 概述
本文档说明自定义BGM系统在不同平台（Windows、Linux、macOS、Android、iOS）上的兼容性和注意事项。

## 文件存储路径

### 配置文件存储策略

为了确保打包后能正常工作，系统使用**混合存储策略**：

| 文件类型 | 存储位置 | 权限 | 用途 |
|---------|---------|------|------|
| **默认配置** | `res://config/audio_config.json` | 只读 | 场景音乐、氛围音配置 |
| **用户设置** | `user://audio_settings.json` | 可写 | 音量、自定义BGM路径 |
| **自定义BGM** | `user://custom_bgm/` | 可写 | 用户上传的音乐文件 |

### user:// 路径映射

`user://` 路径在不同平台上的实际位置：

| 平台 | 实际路径 |
|------|---------|
| **Windows** | `%APPDATA%\Godot\app_userdata\[项目名]\custom_bgm\` |
| **Linux** | `~/.local/share/godot/app_userdata/[项目名]/custom_bgm/` |
| **macOS** | `~/Library/Application Support/Godot/app_userdata/[项目名]/custom_bgm/` |
| **Android** | `/data/data/[包名]/files/custom_bgm/` |
| **iOS** | `Documents/custom_bgm/` |

### 为什么使用混合存储策略？

1. **打包兼容性**：`res://` 在打包后是只读的，无法写入
2. **跨平台兼容**：`user://` 在所有平台都可写
3. **权限安全**：不需要额外的文件系统权限
4. **数据持久化**：用户设置在卸载前不会丢失
5. **沙盒友好**：符合移动平台的沙盒机制
6. **配置分离**：默认配置和用户设置分开管理

### 配置加载流程

```
1. 加载 res://config/audio_config.json（默认配置）
   ├─ 场景音乐配置
   ├─ 氛围音配置
   └─ 默认音量值

2. 加载 user://audio_settings.json（用户设置）
   ├─ 用户自定义音量
   └─ 上次播放的BGM路径

3. 合并配置（用户设置覆盖默认值）

4. 应用设置
```

## 音频格式支持

### 推荐格式优先级

1. **OGG Vorbis** ⭐⭐⭐⭐⭐
   - 最佳跨平台支持
   - 文件小，质量好
   - 原生支持循环
   - 所有平台完美支持

2. **MP3** ⭐⭐⭐⭐
   - 良好的跨平台支持
   - 通用格式
   - 需要手动加载数据
   - 所有平台支持

3. **WAV** ⭐⭐⭐
   - 原生支持
   - 文件大
   - 适合短音效
   - 所有平台支持

4. **AAC/M4A** ❌
   - Godot 4 原生不支持
   - 需要转换为OGG或MP3

### 格式转换命令

```bash
# 转换为 OGG（推荐）
ffmpeg -i input.mp3 -c:a libvorbis -q:a 5 output.ogg

# 转换为 MP3
ffmpeg -i input.aac -c:a libmp3lame -b:a 192k output.mp3

# 批量转换（Windows PowerShell）
Get-ChildItem *.mp3 | ForEach-Object { 
    ffmpeg -i $_.Name -c:a libvorbis -q:a 5 "$($_.BaseName).ogg" 
}

# 批量转换（Linux/Mac）
for file in *.mp3; do 
    ffmpeg -i "$file" -c:a libvorbis -q:a 5 "${file%.mp3}.ogg"
done
```

## Android 平台特殊说明

### 1. 文件选择器

在Android上，`FileDialog`的行为可能不同：

- **Android 10+**：需要使用系统文件选择器
- **权限**：可能需要 `READ_EXTERNAL_STORAGE` 权限
- **建议**：使用 `OS.get_system_dir()` 获取标准目录

### 2. 文件访问

```gdscript
# Android友好的文件访问方式
var file = FileAccess.open(file_path, FileAccess.READ)
if file:
    var data = file.get_buffer(file.get_length())
    file.close()
    # 处理数据
else:
    print("错误代码: ", FileAccess.get_open_error())
```

### 3. 导出设置

在 `export_presets.cfg` 中添加：

```ini
[preset.0]
name="Android"
platform="Android"

[preset.0.options]
permissions/read_external_storage=true
permissions/write_external_storage=false  # 不需要写入外部存储
```

### 4. 性能优化

- 使用OGG格式减小APK体积
- 避免同时加载大量音频文件
- 考虑使用流式播放（对于大文件）

## iOS 平台特殊说明

### 1. 文件访问限制

- iOS使用严格的沙盒机制
- 只能访问应用的Documents目录
- `user://` 路径自动映射到正确位置

### 2. 音频会话

iOS可能需要配置音频会话：

```gdscript
# 在iOS上确保音频正常播放
if OS.get_name() == "iOS":
    # Godot会自动处理，但可以手动配置
    pass
```

### 3. 后台播放

如果需要后台播放音乐，需要在导出设置中启用：

```ini
[preset.1]
name="iOS"
platform="iOS"

[preset.1.options]
capabilities/audio=true
```

## Web 平台（HTML5）

### 限制

1. **文件上传**：使用浏览器的文件选择器
2. **存储**：使用IndexedDB（有大小限制）
3. **格式**：推荐OGG和MP3
4. **自动播放**：需要用户交互才能播放

### 解决方案

```gdscript
# Web平台检测
if OS.get_name() == "Web":
    # 使用JavaScript接口上传文件
    # 或提供URL输入方式
    pass
```

## 测试清单

### 开发阶段

- [ ] Windows上测试文件上传
- [ ] 测试OGG、MP3、WAV格式
- [ ] 测试文件复制和验证
- [ ] 测试音量保存和恢复
- [ ] 测试BGM循环播放

### 打包前测试

- [ ] 测试user://路径是否正确创建
- [ ] 测试配置文件读写
- [ ] 测试大文件（>10MB）加载
- [ ] 测试特殊字符文件名

### Android测试

- [ ] 在真机上测试文件选择
- [ ] 测试不同Android版本（8.0+）
- [ ] 测试应用重启后BGM恢复
- [ ] 测试后台切换时音频状态
- [ ] 测试低内存情况

### iOS测试

- [ ] 在真机上测试（模拟器音频可能不准确）
- [ ] 测试应用切换时音频状态
- [ ] 测试耳机插拔
- [ ] 测试系统音量控制

## 配置文件详解

### 默认配置文件 (res://config/audio_config.json)

**位置**：项目资源目录（只读）
**用途**：定义场景音乐和氛围音的映射关系

```json
{
  "background_music": {
    "livingroom": {
      "day": {
        "sunny": "",
        "rainy": "",
        "storm": ""
      }
    }
  },
  "ambient_sounds": {
    "_comment": "氛围音配置"
  },
  "volume": {
    "background_music": 0.3,
    "ambient": 0.3
  },
  "last_custom_bgm": ""
}
```

### 用户设置文件 (user://audio_settings.json)

**位置**：用户数据目录（可写）
**用途**：保存用户的音量设置和自定义BGM

```json
{
  "volume": {
    "background_music": 0.5,
    "ambient": 0.7
  },
  "last_custom_bgm": "user://custom_bgm/my_music.ogg"
}
```

**特点**：
- 自动创建（首次保存时）
- 只包含用户修改的设置
- 打包后可正常读写
- 跨平台兼容

### 配置优先级

用户设置 > 默认配置

例如：
- 默认BGM音量：30%
- 用户设置音量：50%
- 最终使用：50%（用户设置）

## 常见问题

### Q: 打包后配置无法保存？
A: 确保使用 `user://` 路径保存用户设置。`res://` 路径在打包后是只读的。

### Q: Android上无法选择文件？
A: 检查权限设置，确保添加了 `READ_EXTERNAL_STORAGE` 权限。

### Q: 文件复制后无法播放？
A: 检查文件格式是否支持，使用 `FileAccess.get_open_error()` 查看错误代码。

### Q: 应用重启后音量设置丢失？
A: 检查 `user://audio_settings.json` 是否正确创建。可以在日志中查看保存路径。

### Q: 应用重启后BGM丢失？
A: 检查 `user://audio_settings.json` 中的 `last_custom_bgm` 路径是否正确。

### Q: 大文件加载卡顿？
A: 考虑使用异步加载或流式播放，或者压缩音频文件。

### Q: iOS上音频延迟？
A: 这是iOS的正常行为，可以通过预加载音频流来减少延迟。

## 最佳实践

1. **优先使用OGG格式**：最佳的跨平台兼容性
2. **文件大小控制**：单个BGM文件建议不超过10MB
3. **错误处理**：始终检查文件操作的返回值
4. **用户提示**：在上传不支持的格式时给出明确提示
5. **测试覆盖**：在目标平台上进行充分测试

## 代码示例

### 跨平台文件加载

```gdscript
func load_audio_cross_platform(file_path: String) -> AudioStream:
    var ext = file_path.get_extension().to_lower()
    var audio_stream = null
    
    if not FileAccess.file_exists(file_path):
        push_error("文件不存在: " + file_path)
        return null
    
    match ext:
        "ogg":
            audio_stream = AudioStreamOggVorbis.load_from_file(file_path)
            if audio_stream:
                audio_stream.loop = true
        "mp3":
            audio_stream = AudioStreamMP3.new()
            var file = FileAccess.open(file_path, FileAccess.READ)
            if file:
                audio_stream.data = file.get_buffer(file.get_length())
                audio_stream.loop = true
                file.close()
        "wav":
            var file = FileAccess.open(file_path, FileAccess.READ)
            if file:
                audio_stream = AudioStreamWAV.new()
                audio_stream.data = file.get_buffer(file.get_length())
                audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
                file.close()
    
    return audio_stream
```

### 平台检测

```gdscript
func get_platform_info() -> Dictionary:
    var platform = OS.get_name()
    var is_mobile = platform in ["Android", "iOS"]
    var supports_file_dialog = platform not in ["Android", "iOS", "Web"]
    
    return {
        "platform": platform,
        "is_mobile": is_mobile,
        "supports_file_dialog": supports_file_dialog,
        "user_data_dir": OS.get_user_data_dir()
    }
```

## 更新日志

- **2024-10-31**: 初始版本，添加跨平台支持说明
