#!/usr/bin/env python3
"""
创建一个简单的测试用 tileset 图片
需要安装 Pillow: pip install pillow
"""

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("请先安装 Pillow: pip install pillow")
    exit(1)

# 配置
TILE_SIZE = 32  # 每个 tile 的尺寸
TILES_X = 4     # 横向 tile 数量
TILES_Y = 2     # 纵向 tile 数量
OUTPUT_PATH = "../assets/images/explore/test_tileset.png"

# 颜色定义 (R, G, B, A)
COLORS = [
    (76, 175, 80, 255),   # 绿色 - 草地
    (158, 158, 158, 255), # 灰色 - 石板
    (121, 85, 72, 255),   # 棕色 - 墙壁
    (33, 150, 243, 255),  # 蓝色 - 水面
    (255, 235, 59, 255),  # 黄色 - 沙地
    (139, 69, 19, 255),   # 深棕 - 泥土
    (96, 125, 139, 255),  # 深灰 - 石头
    (205, 220, 57, 255),  # 黄绿 - 草丛
]

def create_tileset():
    """创建 tileset 图片"""
    # 计算图片总尺寸
    width = TILE_SIZE * TILES_X
    height = TILE_SIZE * TILES_Y
    
    # 创建图片
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 绘制每个 tile
    tile_index = 0
    for y in range(TILES_Y):
        for x in range(TILES_X):
            if tile_index >= len(COLORS):
                break
            
            # 计算 tile 位置
            x1 = x * TILE_SIZE
            y1 = y * TILE_SIZE
            x2 = x1 + TILE_SIZE
            y2 = y1 + TILE_SIZE
            
            # 填充颜色
            color = COLORS[tile_index]
            draw.rectangle([x1, y1, x2-1, y2-1], fill=color)
            
            # 绘制边框（方便识别）
            border_color = tuple(max(0, c - 40) for c in color[:3]) + (255,)
            draw.rectangle([x1, y1, x2-1, y2-1], outline=border_color, width=2)
            
            tile_index += 1
    
    # 保存图片
    img.save(OUTPUT_PATH)
    print(f"✅ Tileset 已创建: {OUTPUT_PATH}")
    print(f"📐 图片尺寸: {width}x{height}")
    print(f"🎨 Tile 尺寸: {TILE_SIZE}x{TILE_SIZE}")
    print(f"📊 Tile 数量: {TILES_X}x{TILES_Y} = {TILES_X * TILES_Y}")
    print(f"\n在 Godot 中设置:")
    print(f"  Texture Region Size: {TILE_SIZE}x{TILE_SIZE}")
    print(f"  Separation: 0")
    print(f"  Texture Margin: 0")

if __name__ == "__main__":
    create_tileset()
