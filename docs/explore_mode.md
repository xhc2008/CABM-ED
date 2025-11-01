# 探索模式 - 俯视视角箱庭玩法

## 概述
探索模式是一个独立于主玩法的俯视视角箱庭式玩法，玩家可以在2D地图中自由移动探索。

## 文件结构

### 脚本文件
- `scripts/explore/explore_player.gd` - 玩家控制器
- `scripts/explore/explore_scene.gd` - 探索场景管理器

### 场景文件
- `scenes/explore_scene.tscn` - 探索模式主场景

### 素材文件
- `assets/images/explore/player.png` - 玩家角色图片
- `assets/images/explore/README.md` - 素材说明文档

## 功能特性

### 玩家控制
- **WASD移动**: 使用 W/A/S/D 键控制玩家上下左右移动
- **朝向鼠标**: 玩家角色始终朝向鼠标指针方向
- **移动速度**: 默认 200 像素/秒（可在 explore_player.gd 中调整）

### 场景切换
- **主场景入口**: 在主场景左上角有"🗺️ 探索模式"按钮
- **探索场景出口**: 在探索场景左上角有"返回主场景"按钮

### 当前地图
目前使用临时素材创建了一个简单的测试房间：
- 绿色背景（草地）
- 棕色墙壁（四周边界）
- 绿色方块装饰（树木）

## 下一步开发建议

### 1. 添加 TileMap 地图系统
参考 `assets/images/explore/README.md` 准备 tileset 素材，然后：
1. 在 Godot 编辑器中打开 `explore_scene.tscn`
2. 删除临时的 `TemporaryWalls` 和 `Decoration` 节点
3. 添加 TileMap 节点
4. 导入 tileset 并绘制地图
5. 设置碰撞层

### 2. 添加多个预设场景
- 创建不同的房间/区域场景
- 使用场景切换实现房间之间的连接
- 可以用门、传送点等方式连接场景

### 3. 添加交互元素
- NPC 对话
- 可拾取物品
- 可交互物体（门、箱子等）

### 4. 添加游戏机制
- 任务系统
- 物品收集
- 解谜元素

## 技术说明

### 碰撞系统
- 玩家使用 `CharacterBody2D` 和圆形碰撞体
- 墙壁使用 `StaticBody2D` 和矩形碰撞体
- 使用 `move_and_slide()` 实现平滑的碰撞检测

### 相机跟随
- 相机作为玩家的子节点，自动跟随玩家移动
- 可以在 Camera2D 节点中调整缩放、平滑度等参数

### 输入处理
- 使用 `Input.is_key_pressed()` 检测 WASD 按键
- 使用 `get_global_mouse_position()` 获取鼠标位置
- 使用 `look_at()` 实现朝向鼠标

## 调试提示
- 按 F5 运行游戏
- 在主场景点击"探索模式"按钮进入
- 使用 WASD 测试移动
- 移动鼠标测试旋转
- 点击"返回主场景"测试场景切换
