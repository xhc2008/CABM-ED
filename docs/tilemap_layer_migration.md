# TileMapLayer 迁移指南 (Godot 4.5)

## 主要变化

Godot 4.5 将 `TileMap` 替换为 `TileMapLayer`，这是一个重要的架构变更。

## API 变化对照

### 节点类型
- **旧**: `TileMap`
- **新**: `TileMapLayer`

### 获取 Tile 数据
```gdscript
# 旧 API (TileMap)
var tile_data = tilemap.get_cell_tile_data(layer_id, tile_pos)

# 新 API (TileMapLayer)
var tile_data = tilemap_layer.get_cell_tile_data(tile_pos)
```

**说明**: TileMapLayer 本身就代表一个图层，不需要传递 layer_id

### 坐标转换
```gdscript
# 旧 API
var tile_pos = tilemap.local_to_map(local_pos)
var local_pos = tilemap.map_to_local(tile_pos)

# 新 API (相同)
var tile_pos = tilemap_layer.local_to_map(local_pos)
var local_pos = tilemap_layer.map_to_local(tile_pos)
```

### 设置/获取 Tile
```gdscript
# 旧 API
tilemap.set_cell(layer_id, tile_pos, source_id, atlas_coords)
var source_id = tilemap.get_cell_source_id(layer_id, tile_pos)

# 新 API
tilemap_layer.set_cell(tile_pos, source_id, atlas_coords)
var source_id = tilemap_layer.get_cell_source_id(tile_pos)
```

## 本项目中的更改

### 1. 场景结构
```
探索场景
├── TileMapLayer (替代 TileMap)
└── ...
```

### 2. 脚本更改

#### explore_scene.gd
```gdscript
# 旧
@onready var tilemap = $TileMap

# 新
@onready var tilemap_layer = $TileMapLayer
```

#### interaction_detector.gd
```gdscript
# 旧
func check_tilemap_interactions(tilemap: TileMap):
    var tile_data = tilemap.get_cell_tile_data(0, tile_pos)

# 新
func check_tilemap_interactions(tilemap_layer: TileMapLayer):
    var tile_data = tilemap_layer.get_cell_tile_data(tile_pos)
```

## 多图层处理

如果需要多个图层，现在需要创建多个 TileMapLayer 节点：

```
探索场景
├── GroundLayer (TileMapLayer)
├── ObjectsLayer (TileMapLayer)
├── DecorationLayer (TileMapLayer)
└── ...
```

在代码中：
```gdscript
@onready var ground_layer = $GroundLayer
@onready var objects_layer = $ObjectsLayer

# 检查不同图层
var ground_tile = ground_layer.get_cell_tile_data(tile_pos)
var object_tile = objects_layer.get_cell_tile_data(tile_pos)
```

## 自定义数据设置

自定义数据的设置方式保持不变：

1. 选择 TileMapLayer 节点
2. 在 Inspector 中打开 TileSet
3. 添加 Custom Data Layers
4. 为特定 tile 设置自定义数据值

```gdscript
# 获取自定义数据 (API 相同)
if tile_data:
    var is_chest = tile_data.get_custom_data("is_chest")
    var chest_type = tile_data.get_custom_data("chest_type")
```

## 优势

1. **更清晰的层级结构**: 每个图层是独立的节点
2. **更好的性能**: 可以单独控制每个图层的可见性和处理
3. **更灵活**: 可以为不同图层设置不同的属性和脚本

## 迁移检查清单

- [x] 将场景中的 TileMap 节点替换为 TileMapLayer
- [x] 更新脚本中的节点引用 (`$TileMap` → `$TileMapLayer`)
- [x] 移除 API 调用中的 layer_id 参数
- [x] 更新变量类型声明 (`TileMap` → `TileMapLayer`)
- [x] 测试所有 tile 相关功能

## 兼容性说明

- **Godot 4.5+**: 使用 TileMapLayer
- **Godot 4.0-4.4**: 使用 TileMap

本项目已更新为 Godot 4.5 标准。
