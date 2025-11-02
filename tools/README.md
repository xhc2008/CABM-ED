# 工具脚本说明

## create_test_tileset.py

创建一个简单的测试用 tileset 图片。

### 使用方法

#### 1. 安装依赖
```bash
pip install pillow
```

#### 2. 运行脚本
```bash
cd tools
python create_test_tileset.py
```

#### 3. 结果
会在 `assets/images/explore/` 生成 `test_tileset.png`

### 配置说明

在脚本中可以修改：
- `TILE_SIZE`: 每个 tile 的尺寸（默认 32）
- `TILES_X`: 横向 tile 数量（默认 4）
- `TILES_Y`: 纵向 tile 数量（默认 2）

### 生成的颜色

1. 🟢 绿色 - 草地（无碰撞）
2. ⚪ 灰色 - 石板（无碰撞）
3. 🟤 棕色 - 墙壁（需要碰撞）
4. 🔵 蓝色 - 水面（需要碰撞）
5. 🟡 黄色 - 沙地（无碰撞）
6. 🟫 深棕 - 泥土（无碰撞）
7. ⚫ 深灰 - 石头（需要碰撞）
8. 🟩 黄绿 - 草丛（无碰撞）

### 在 Godot 中使用

1. 运行脚本生成图片
2. 在 Godot 中打开 `explore_scene.tscn`
3. 选择 TileMapLayer 节点
4. 创建新的 TileSet
5. 添加 Atlas，选择生成的图片
6. 设置 Texture Region Size 为 32x32
7. 为棕色、蓝色、深灰色的 tile 添加碰撞箱

## 如果没有 Python

可以使用在线工具创建：
1. 访问 https://www.pixilart.com/
2. 创建 128x64 的画布
3. 绘制 4x2 的彩色方块
4. 导出为 PNG
