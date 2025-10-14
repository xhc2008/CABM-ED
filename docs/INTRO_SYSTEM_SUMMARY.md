# 开场系统实现总结

## 概述

为游戏添加了完整的首次启动流程，包括开场故事播报和初始设置功能。

## 新增文件

### 脚本文件
1. **scripts/game_launcher.gd** - 游戏启动器，检查存档决定流程
2. **scripts/intro_story.gd** - 开场故事播报脚本
3. **scripts/initial_setup.gd** - 初始设置脚本

### 场景文件
1. **scenes/game_launcher.tscn** - 启动器场景
2. **scenes/intro_scene.tscn** - 开场故事场景
3. **scenes/initial_setup.tscn** - 初始设置场景

### 文档文件
1. **docs/intro_system_guide.md** - 详细使用指南
2. **docs/intro_system_test.md** - 测试指南

## 修改文件

- **project.godot** - 将启动场景改为 `res://scenes/game_launcher.tscn`

## 功能特性

### 1. 智能启动检测
- 首次启动：播放开场 → 初始设置 → 主游戏
- 再次启动：直接进入主游戏

### 2. 开场故事
- 5段背景故事文本
- 逐字显示效果（打字机效果）
- 点击可跳过当前文本动画
- 自动播放，播放完显示继续按钮

### 3. 初始设置
- **用户名输入**（必填）
- **角色名输入**（默认"雪狐"）
- **API密钥输入**（可选）
- 输入验证和错误提示
- 重要提示文字

### 4. 数据保存
- 用户名 → 存档文件
- 角色名 → app_config.json
- API密钥 → user://api_keys.json
- 自动创建初始存档

## 使用流程

### 首次启动
```
游戏启动
  ↓
检测无存档
  ↓
播放开场故事（5段文本）
  ↓
点击"继续"
  ↓
初始设置界面
  ├─ 输入用户名（必填）
  ├─ 输入角色名（默认"雪狐"）
  └─ 输入API密钥（可选）
  ↓
点击"开始游戏"
  ↓
保存数据并创建存档
  ↓
进入主游戏
```

### 再次启动
```
游戏启动
  ↓
检测到存档
  ↓
直接进入主游戏
```

## 技术实现

### 存档检测
```gdscript
func _has_save_file() -> bool:
    var save_path = "user://saves/save_slot_1.json"
    return FileAccess.file_exists(save_path)
```

### 场景切换
- game_launcher → intro_scene → initial_setup → main
- 使用 `get_tree().change_scene_to_file()`

### 数据持久化
- 配置文件：JSON格式
- 存档文件：通过SaveManager管理
- API密钥：独立JSON文件

## 自定义选项

### 修改开场文本
编辑 `scripts/intro_story.gd`:
```gdscript
var story_texts: Array[String] = [
    "你的文本1",
    "你的文本2",
    // ...
]
```

### 修改打字速度
```gdscript
var typing_speed: float = 0.05  # 秒/字符
```

### 修改默认角色名
编辑 `scripts/initial_setup.gd`:
```gdscript
character_name_input.text = "你的默认名"
```

### 添加背景图片
1. 准备图片：`assets/images/index.png`
2. 修改场景文件，将ColorRect替换为TextureRect
3. 加载纹理

## 测试方法

### 测试首次启动
1. 删除存档：`user://saves/save_slot_1.json`
2. 启动游戏
3. 验证流程完整性

### 测试再次启动
1. 关闭游戏
2. 再次启动
3. 验证直接进入主游戏

详细测试步骤见 `docs/intro_system_test.md`

## 注意事项

1. **存档检测**：基于 `save_slot_1.json` 文件是否存在
2. **必填字段**：用户名必须填写，否则显示错误
3. **默认值**：角色名有默认值"雪狐"
4. **API密钥**：完全可选，可在游戏中配置
5. **中文引号**：代码中使用转义的英文引号避免语法错误

## 未来扩展

可以考虑添加：
- [ ] 背景音乐和音效
- [ ] 背景图片和视觉效果
- [ ] 角色立绘展示
- [ ] 更多自定义选项（难度、语言等）
- [ ] 跳过开场的选项
- [ ] 开场动画效果
- [ ] 语音播报

## 相关文档

- [详细使用指南](intro_system_guide.md)
- [测试指南](intro_system_test.md)
- [存档系统指南](save_system_guide.md)

## 版本信息

- 创建日期：2025/10/14
- Godot版本：4.5
- 状态：✅ 已完成并测试
