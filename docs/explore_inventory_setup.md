# 探索模式背包和宝箱系统设置指南

## 场景设置

### 1. 探索场景 (explore_scene.tscn)

需要添加以下节点：

```
Node2D (ExploreScene)
├── Player (CharacterBody2D)
├── SnowFox (CharacterBody2D)
├── TileMapLayer
└── UI (CanvasLayer)
    ├── VirtualJoystick
    ├── InteractionPrompt (Control)
    │   └── Panel
    │       └── VBoxContainer
    │           └── PromptList (VBoxContainer)
    ├── InventoryUI (Control)
    │   └── Panel
    │       ├── CloseButton (Button)
    │       └── HBoxContainer
    │           ├── PlayerInventoryPanel (Panel)
    │           │   ├── Title (Label) - "背包"
    │           │   └── ScrollContainer
    │           │       └── InventoryGrid (GridContainer)
    │           ├── StoragePanel (Panel)
    │           │   ├── Title (Label) - "宝箱"
    │           │   └── ScrollContainer
    │           │       └── StorageGrid (GridContainer)
    │           └── ItemInfoPanel (Panel)
    │               └── VBoxContainer
    │                   ├── ItemName (Label)
    │                   ├── ItemIcon (TextureRect)
    │                   └── ScrollContainer
    │                       └── ItemDescription (Label)
    ├── InventoryButton (Button) - "背包"
    └── ExitButton (Button)
```

### 2. 脚本附加

- `ExploreScene` 节点: 附加 `explore_scene.gd`
- `Player` 节点: 附加 `explore_player.gd`
- `InteractionPrompt` 节点: 附加 `interaction_prompt.gd`
- `InventoryUI` 节点: 附加 `explore_inventory_ui.gd`

### 3. TileMapLayer 设置

在 TileMapLayer 的 TileSet 中，为宝箱 tile 添加自定义数据：

1. 选择 TileMapLayer 节点
2. 在 Inspector 中打开 TileSet
3. 在 TileSet 编辑器中，选择 "Custom Data Layers"
4. 添加一个新的自定义数据层：
   - 名称: `is_chest`
   - 类型: `bool`
5. 选择宝箱对应的 tile，在右侧面板中设置 `is_chest = true`

可选：添加 `chest_type` (String) 来区分不同类型的宝箱

**注意**: Godot 4.5 使用 TileMapLayer 替代了旧的 TileMap

### 4. GridContainer 设置

- `InventoryGrid`: 设置 `columns = 6`
- `StorageGrid`: 设置 `columns = 4`

### 5. InteractionPrompt 位置

将 `InteractionPrompt` 定位在玩家角色右侧：
- Anchor Preset: Center Right
- Position: 根据需要调整

## 配置文件

### chest_loot.json

已创建在 `config/chest_loot.json`，包含：
- `loot_tables`: 战利品表配置
  - `common_chest`: 普通宝箱
  - `rare_chest`: 稀有宝箱
  - `food_chest`: 食物箱
- `chest_types`: 宝箱类型与 tile_id 的映射

可以根据需要修改概率和物品数量。

## 使用说明

### 玩家操作

1. **打开背包**: 
   - 按 `B` 键
   - 点击右上角的"背包"按钮

2. **与宝箱交互**:
   - 靠近宝箱时，右侧会显示 "F: 开启宝箱"
   - 按 `F` 键或点击提示开启宝箱
   - 宝箱开启后会自动显示背包和宝箱界面

3. **物品操作**:
   - 点击物品选中
   - 再次点击目标格子移动物品
   - 相同物品会自动堆叠
   - 不同物品会交换位置

4. **多个可交互物体**:
   - 使用鼠标滚轮切换选项
   - 点击选项直接交互

### 代码集成

在其他脚本中访问玩家背包：

```gdscript
# 获取探索场景
var explore_scene = get_tree().current_scene

# 添加物品到背包
if explore_scene.player_inventory:
    explore_scene.player_inventory.add_item("apple", 5)

# 检查背包中的物品
var inventory = explore_scene.player_inventory.inventory
for item in inventory:
    if item != null:
        print(item.item_id, ": ", item.count)
```

## 与主场景背包的区别

1. **独立系统**: 探索模式背包与主场景的背包/仓库系统完全分离
2. **单一背包**: 探索模式只有玩家背包，没有仓库
3. **动态存储**: 可以与不同类型的存储器交互（宝箱、炉灶、商店等）
4. **扩展性**: 后期可以轻松添加新的存储器类型

## 后续扩展

### 添加新的存储器类型

1. 在 `ExploreInventoryUI` 中添加新的打开方法：

```gdscript
func open_furnace(furnace_storage: Array):
    storage_mode = "furnace"
    current_storage = furnace_storage
    storage_title.text = "炉灶"
    storage_panel.show()
    _create_storage_slots(furnace_storage.size())
    _refresh_all_slots()
    show()
```

2. 创建对应的交互逻辑

### 添加新的宝箱类型

在 `config/chest_loot.json` 中添加：

```json
{
  "loot_tables": {
    "weapon_chest": {
      "name": "武器箱",
      "items": [
        {
          "item_id": "CMR-951",
          "min_count": 1,
          "max_count": 1,
          "probability": 0.3
        }
      ]
    }
  },
  "chest_types": {
    "4": {
      "name": "武器箱",
      "loot_table": "weapon_chest",
      "tile_id": 4
    }
  }
}
```

## 注意事项

1. 确保 `config/items.json` 中包含所有在战利品表中引用的物品
2. 宝箱的 tile_id 需要与 TileMap 中实际使用的 tile 对应
3. 已开启的宝箱会被记录，重新进入场景时不会重置（除非清除存档）
4. 物品图标路径: `res://assets/images/items/[icon_name]`
