# 背景音乐系统

## 概述
背景音乐系统允许玩家管理游戏中的背景音乐和环境音，包括切换音乐、上传自定义音频文件以及调节音量。

## 功能特性

### 1. 音乐播放器入口
- 在书房场景（studyroom）中有一个**隐藏的可点击区域**
- 点击该区域后会弹出"🎵 背景音乐"按钮（带动画效果）
- 点击按钮打开音乐播放器面板
- 再次点击区域或点击外部可关闭按钮菜单

### 2. 切换音乐选项卡
- **内置音乐列表**：自动加载 `assets/audio/BGM/` 目录下的所有音频文件
- **自定义音乐**：显示玩家上传的自定义音频文件（标记为"[自定义]"）
- **播放音乐**：点击列表中的音乐项即可播放
- **上传音乐**：点击"上传音乐"按钮，选择本地音频文件（支持 MP3、OGG、WAV 格式）
- **删除音乐**：选中自定义音乐后，点击"删除选中"按钮可删除该文件

### 3. 音量调节选项卡
- **背景音乐音量**：独立调节BGM音量（0-100%）
- **环境音音量**：独立调节环境音效音量（0-100%）
- 音量设置会自动保存到配置文件

## 文件结构

### 场景文件
- `scenes/music_button.tscn` - 音乐播放器入口（隐藏点击区域）
- `scenes/music_player_panel.tscn` - 音乐播放器面板UI

### 脚本文件
- `scripts/music_button.gd` - 入口按钮逻辑（参考日记按钮设计）
- `scripts/music_player_panel.gd` - 播放器面板逻辑
- `scripts/audio_manager.gd` - 音频管理器（已扩展）
- `scripts/main.gd` - 主场景逻辑（已添加音乐按钮支持）

### 配置文件
- `config/interactive_elements.json` - 可交互元素配置（包含music_button）
- `config/audio_config.json` - 音频配置（包含音量设置）

### 音频目录
- `assets/audio/BGM/` - 内置背景音乐目录
- `user://custom_bgm/` - 自定义音乐目录（运行时创建）

## 配置说明

### 交互元素配置
在 `config/interactive_elements.json` 中配置音乐按钮：

```json
{
  "elements": {
    "music_button": {
      "name": "音乐播放器入口",
      "type": "click_area",
      "size": {
        "width": 200,
        "height": 150
      },
      "position": {
        "anchor": "bottom_left",
        "offset_x": 160,
        "offset_y": -150
      },
      "scenes": ["studyroom"],
      "enabled": true
    }
  }
}
```

### 音频配置
在 `config/audio_config.json` 中配置音量：

```json
{
  "volume": {
    "background_music": 0.3,
    "ambient": 0.3
  }
}
```

## API 说明

### AudioManager 新增方法

#### `play_custom_bgm(file_path: String)`
播放自定义BGM文件
- 参数：音频文件路径（支持资源路径和用户路径）
- 播放自定义BGM时会暂停场景音乐的自动切换

#### `stop_custom_bgm()`
停止自定义BGM，恢复场景音乐

#### `set_ambient_volume(volume: float)`
设置环境音音量
- 参数：音量值（0.0 - 1.0）

#### `get_ambient_volume() -> float`
获取环境音音量
- 返回：音量值（0.0 - 1.0）

#### `play_ambient_sound(file_path: String, loop: bool = true)`
播放环境音
- 参数：
  - `file_path`：音频文件路径
  - `loop`：是否循环播放（默认true）

#### `stop_ambient_sound()`
停止环境音播放

## 使用示例

### 在代码中播放自定义BGM
```gdscript
var audio_manager = get_node("/root/Main/AudioManager")
audio_manager.play_custom_bgm("user://custom_bgm/my_music.mp3")
```

### 调节音量
```gdscript
var audio_manager = get_node("/root/Main/AudioManager")
audio_manager.set_bgm_volume(0.5)  # 50%音量
audio_manager.set_ambient_volume(0.3)  # 30%音量
```

### 播放环境音
```gdscript
var audio_manager = get_node("/root/Main/AudioManager")
audio_manager.play_ambient_sound("res://assets/audio/rain.mp3", true)
```

## 注意事项

1. **音频格式支持**：
   - **OGG**：✅ 推荐使用，Godot原生完美支持，文件小，质量好
   - **WAV**：✅ 原生支持，但文件较大，适合短音效
   - **MP3**：✅ 原生支持，需要在导入时正确配置
   - **AAC/M4A**：⚠️ Godot 4 原生不支持，需要转换或使用第三方插件
   
   **AAC 格式处理方案**：
   - 方案1：使用 FFmpeg 转换为 OGG 格式（推荐）
     ```bash
     ffmpeg -i input.aac -c:a libvorbis -q:a 5 output.ogg
     ```
   - 方案2：转换为 MP3 格式
     ```bash
     ffmpeg -i input.aac -c:a libmp3lame -b:a 192k output.mp3
     ```
   - 方案3：使用 Godot 插件（如果有可用的 AAC 解码插件）

2. **自定义音乐存储**：
   - 自定义音乐保存在 `user://custom_bgm/` 目录
   - Windows: `%APPDATA%\Godot\app_userdata\[项目名]\custom_bgm\`
   - Linux: `~/.local/share/godot/app_userdata/[项目名]/custom_bgm/`
   - macOS: `~/Library/Application Support/Godot/app_userdata/[项目名]/custom_bgm/`

3. **性能考虑**：
   - 大型音频文件可能影响加载速度
   - 建议压缩音频文件以减小体积

4. **场景切换**：
   - 播放自定义BGM时，场景切换不会自动更换音乐
   - 需要手动停止自定义BGM才能恢复场景音乐

## 音频格式快速参考

| 格式 | 支持状态 | 文件大小 | 音质 | 推荐度 | 说明 |
|------|---------|---------|------|--------|------|
| OGG  | ✅ 完美支持 | 小 | 优秀 | ⭐⭐⭐⭐⭐ | 最推荐，开源格式 |
| MP3  | ✅ 原生支持 | 小 | 良好 | ⭐⭐⭐⭐ | 通用格式 |
| WAV  | ✅ 原生支持 | 大 | 无损 | ⭐⭐⭐ | 适合短音效 |
| AAC  | ❌ 不支持 | 小 | 优秀 | ⭐ | 需要转换 |
| M4A  | ❌ 不支持 | 小 | 优秀 | ⭐ | 需要转换 |

### AAC 转换命令速查

```bash
# 转换为 OGG（推荐，质量最好）
ffmpeg -i input.aac -c:a libvorbis -q:a 5 output.ogg

# 转换为 MP3（兼容性好）
ffmpeg -i input.aac -c:a libmp3lame -b:a 192k output.mp3

# 批量转换（Windows PowerShell）
Get-ChildItem *.aac | ForEach-Object { ffmpeg -i $_.Name -c:a libvorbis -q:a 5 "$($_.BaseName).ogg" }

# 批量转换（Linux/Mac）
for file in *.aac; do ffmpeg -i "$file" -c:a libvorbis -q:a 5 "${file%.aac}.ogg"; done
```

## 扩展建议

1. **播放列表功能**：添加顺序播放、随机播放等功能
2. **音乐信息显示**：显示当前播放的音乐名称和进度
3. **淡入淡出效果**：音乐切换时添加平滑过渡
4. **收藏功能**：允许玩家标记喜欢的音乐
5. **音乐分类**：按类型、场景等分类管理音乐
6. **格式自动转换**：集成音频转换工具，自动转换不支持的格式
