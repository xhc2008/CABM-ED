# 开场系统快速参考

## 新增文件
- `scripts/game_launcher.gd` - 启动器
- `scripts/intro_story.gd` - 开场故事
- `scripts/initial_setup.gd` - 初始设置
- `scenes/game_launcher.tscn` - 启动器场景
- `scenes/intro_scene.tscn` - 开场场景
- `scenes/initial_setup.tscn` - 设置场景

## 修改文件
- `project.godot` - 启动场景改为 `game_launcher.tscn`

## 流程
首次: 启动器 → 开场故事 → 初始设置 → 主游戏
再次: 启动器 → 主游戏

## 测试
删除存档: `user://saves/save_slot_1.json`
然后运行游戏

## 文档
- [使用指南](docs/intro_system_guide.md)
- [测试指南](docs/intro_system_test.md)
- [实现总结](docs/INTRO_SYSTEM_SUMMARY.md)
- [快速测试](TEST_INTRO_SYSTEM.md)
