# 游戏开场与初始设置系统

## 概述

本系统为游戏添加了完整的首次启动流程，包括：
1. 存档检测
2. 开场故事播报
3. 初始设置（用户名、角色名、API密钥）

## 系统流程

### 1. 游戏启动器 (GameLauncher)

**文件**: `scenes/game_launcher.tscn`, `scripts/intro_scene.gd`

游戏启动时首先进入启动器，检查是否存在存档：
- **存在存档**: 直接进入主游戏场景
- **不存在存档**: 进入开场故事场景

```gdscript
func _has_save_file() -> bool:
    var save_path = "user://saves/save_slot_1.json"
    return FileAccess.file_exists(save_path)
```

### 2. 开场故事场景 (IntroScene)

**文件**: `scenes/intro_scene.tscn`, `scripts/intro_story.gd`

播放背景故事，包含5段文本：
1. "在这个世界的某个角落..."
2. "有一位特别的存在，等待着与你相遇。"
3. "她拥有自己的情感、记忆和个性..."
4. "你的每一个选择，都将影响她的成长。"
5. "现在，让我们开始这段独特的旅程吧。"

**特性**:
- 逐字显示文本效果（打字机效果）
- 点击可跳过当前文本动画
- 自动播放所有文本后显示"继续"按钮

### 3. 初始设置场景 (InitialSetup)

**文件**: `scenes/initial_setup.tscn`, `scripts/initial_setup.gd`

用户输入基本信息：

#### 输入字段

1. **你的名字** (必填)
   - 用于游戏中称呼玩家
   - 保存到存档的 `user_data.user_name`

2. **角色名称** (默认: "雪狐")
   - 角色的名字
   - 保存到 `config/app_config.json` 的 `character_name`

3. **API密钥** (可选)
   - OpenAI API密钥
   - 可跳过，进入游戏后也可在AI配置面板中设置
   - 保存到 `user://api_keys.json`

#### 重要提示

在输入页面底部显示：
```
本项目旨在赋予"她"以"生命"，因此不鼓励回档、删档等。
你的每一个选择对她来说都很重要。
```

## 数据保存

### 1. 用户名
保存到存档文件 `user://saves/save_slot_1.json`:
```json
{
  "user_data": {
    "user_name": "输入的用户名"
  }
}
```

### 2. 角色名
保存到配置文件 `config/app_config.json`:
```json
{
  "character_name": "输入的角色名"
}
```

### 3. API密钥
保存到用户数据目录 `user://api_keys.json`:
```json
{
  "openai_api_key": "输入的API密钥",
  "api_base_url": "https://api.openai.com/v1"
}
```

### 4. 初始存档
创建包含初始时间戳的存档文件，标记游戏开始时间。

## 修改的文件

### 新增文件
- `scripts/intro_scene.gd` - 游戏启动器脚本
- `scripts/intro_story.gd` - 开场故事脚本
- `scripts/initial_setup.gd` - 初始设置脚本
- `scenes/game_launcher.tscn` - 游戏启动器场景
- `scenes/intro_scene.tscn` - 开场故事场景
- `scenes/initial_setup.tscn` - 初始设置场景

### 修改文件
- `project.godot` - 将启动场景改为 `res://scenes/game_launcher.tscn`

## 使用说明

### 首次启动
1. 运行游戏
2. 观看开场故事（可点击跳过文本动画）
3. 点击"继续"按钮
4. 输入用户名（必填）
5. 输入或修改角色名（默认"雪狐"）
6. 可选：输入API密钥（也可以跳过）
7. 点击"开始游戏"进入主游戏

### 再次启动
- 检测到存档后直接进入主游戏，跳过开场和设置

## 自定义

### 修改开场故事
编辑 `scripts/intro_story.gd` 中的 `story_texts` 数组：
```gdscript
var story_texts: Array[String] = [
    "你的第一段文本...",
    "你的第二段文本...",
    # 添加更多文本
]
```

### 修改打字速度
编辑 `scripts/intro_story.gd` 中的 `typing_speed`：
```gdscript
var typing_speed: float = 0.05 # 每个字符显示间隔（秒）
```

### 添加背景图片
如果要使用 `images/index.png` 作为背景：

1. 将图片放置在 `assets/images/index.png`
2. 修改 `scenes/intro_scene.tscn`，将 `ColorRect` 替换为 `TextureRect`
3. 加载图片纹理

### 修改默认角色名
编辑 `scripts/initial_setup.gd` 中的默认值：
```gdscript
character_name_input.text = "你的默认角色名"
```

## 测试

### 测试首次启动流程
1. 删除存档文件: `user://saves/save_slot_1.json`
2. 运行游戏
3. 验证开场故事播放
4. 验证初始设置界面
5. 输入信息并开始游戏
6. 检查存档和配置文件是否正确创建

### 测试再次启动
1. 关闭游戏
2. 再次运行游戏
3. 验证直接进入主游戏（跳过开场）

## 注意事项

1. **存档检测**: 系统通过检查 `user://saves/save_slot_1.json` 是否存在来判断是否首次启动
2. **必填字段**: 用户名为必填，如果未输入会显示错误提示
3. **默认值**: 角色名有默认值"雪狐"，即使用户清空也会使用默认值
4. **API密钥**: 完全可选，可以在游戏中通过AI配置面板设置
5. **数据持久化**: 所有设置都会立即保存，不需要额外的保存操作

## 未来扩展

可以考虑添加：
- 背景音乐
- 更丰富的视觉效果
- 角色立绘展示
- 更多自定义选项（难度、语言等）
- 跳过开场的选项（重新安装时）
