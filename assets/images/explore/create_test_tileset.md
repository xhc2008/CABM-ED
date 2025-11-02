# 创建测试用 Tileset

## 方案 1: 使用图片编辑器手动创建

### 使用任何图片编辑器（Paint、GIMP、Photoshop 等）

1. **创建新图片**
   - 尺寸: 128x64 像素（4个tile，每个32x32）
   - 背景: 透明

2. **绘制 4 个方块**（每个 32x32）
   ```
   [草地-绿色] [石板-灰色] [墙壁-棕色] [水面-蓝色]
   ```
   
   - 位置 0,0-32,32: 填充绿色 (#4CAF50)
   - 位置 32,0-64,32: 填充灰色 (#9E9E9E)
   - 位置 64,0-96,32: 填充棕色 (#795548)
   - 位置 96,0-128,32: 填充蓝色 (#2196F3)

3. **保存为 PNG**
   - 文件名: `test_tileset.png`
   - 保存到: `assets/images/explore/`

## 方案 2: 使用在线工具

### 推荐网站
1. **Pixilart** (https://www.pixilart.com/)
   - 免费在线像素画编辑器
   - 可以直接绘制 32x32 的方块

2. **Piskel** (https://www.piskelapp.com/)
   - 专业的像素艺术工具
   - 支持网格和图层

## 方案 3: 下载免费 Tileset

### 推荐资源
1. **OpenGameArt.org**
   - 搜索: "32x32 tileset"
   - 许可证: 通常是 CC0 或 CC-BY

2. **itch.io**
   - 链接: https://itch.io/game-assets/free/tag-tileset
   - 筛选: Free + Tileset

3. **Kenney.nl**
   - 链接: https://kenney.nl/assets
   - 大量免费游戏素材包

### 推荐的具体素材包
- **Kenney's Roguelike Pack**: 包含地牢、草地等
- **LPC Base Assets**: 大型开源素材集合
- **Tiny 16 Basic**: 简约风格 16x16 tileset

## 在 Godot 中使用

### 导入 Tileset 图片后：

1. **打开场景**: `scenes/explore_scene.tscn`

2. **选择 TileMapLayer 节点**

3. **创建 TileSet**:
   - Inspector → Tile Set → [New TileSet]
   - 点击 TileSet 资源打开编辑器

4. **添加 Atlas**:
   - 点击 `+` → Atlas
   - Texture: 拖入你的 tileset 图片
   - Texture Region Size: 设置为 32x32（或你的 tile 尺寸）

5. **设置碰撞**（重要！）:
   - 选择墙壁类的 tile（如棕色方块）
   - 右侧 Physics 面板 → 点击 `+` 添加物理层
   - 点击矩形工具，绘制碰撞箱（覆盖整个 tile）
   - 地板类 tile（草地、石板）不需要碰撞箱

6. **绘制地图**:
   - 关闭 TileSet 编辑器
   - 在场景视图中点击绘制

## 快速测试配置

### 推荐的简单地图布局
```
墙 墙 墙 墙 墙 墙 墙 墙 墙 墙
墙 地 地 地 地 地 地 地 地 墙
墙 地 地 地 地 地 地 地 地 墙
墙 地 地 墙 墙 墙 地 地 地 墙
墙 地 地 地 地 地 地 地 地 墙
墙 地 地 地 地 地 地 地 地 墙
墙 墙 墙 墙 墙 墙 墙 墙 墙 墙
```

### 碰撞层设置
- **TileMapLayer**:
  - Collision Layer: Layer 1 (环境)
  - Collision Mask: 无（墙壁不需要检测碰撞）

- **Player** (已在代码中):
  - Collision Layer: Layer 2 (玩家)
  - Collision Mask: Layer 1 (与环境碰撞)

## 故障排除

### 问题: 看不到 tile
- 检查 TileMapLayer 的 z_index（应该 > 0）
- 检查是否正确设置了 Texture Region Size

### 问题: 玩家穿墙
- 确认墙壁 tile 有碰撞箱
- 检查 TileMapLayer 的 Collision Layer 设置
- 确认玩家的 Collision Mask 包含环境层

### 问题: 无法绘制
- 确认已经创建了 TileSet 资源
- 确认已经添加了 Atlas 并设置了图片
- 检查 Texture Region Size 是否正确
