# 探索模式背包和宝箱系统 - 更新说明

## 新增功能

### 1. 宝箱系统
- 支持在TileMapLayer上放置宝箱（Godot 4.5）
- 靠近宝箱时显示交互提示
- 开启宝箱后显示战利品
- 宝箱开启状态会被记录
- 支持多种宝箱类型（普通、稀有、食物箱等）

### 2. 玩家背包系统
- 独立于主场景的背包系统
- 30格背包空间
- 支持物品堆叠
- 支持拖拽移动物品
- 按B键或点击按钮打开背包

### 3. 交互提示UI
- 显示附近可交互物体
- 支持多个交互选项
- 鼠标滚轮切换选项
- F键或点击确认交互

### 4. 物品转移系统
- 背包与宝箱之间转移物品
- 支持物品堆叠合并
- 支持物品交换
- 为后续扩展（炉灶、商店等）预留接口

## 新增文件

### 脚本文件
- `scripts/explore/chest_system.gd` - 宝箱系统管理
- `scripts/explore/player_inventory.gd` - 玩家背包管理
- `scripts/explore/explore_inventory_ui.gd` - 背包UI
- `scripts/explore/interaction_prompt.gd` - 交互提示UI
- `scripts/explore/interaction_detector.gd` - 交互检测器

### 配置文件
- `config/chest_loot.json` - 宝箱战利品配置

### 文档
- `docs/explore_inventory_setup.md` - 详细设置指南
- `docs/explore_inventory_update.md` - 本文档

## 修改的文件

- `scripts/explore/explore_scene.gd` - 添加背包和宝箱系统集成
- `scripts/explore/explore_player.gd` - 添加交互检测器

## 架构设计

### 系统分离
```
主场景背包系统 (InventoryManager)
├── 背包 (inventory)
└── 仓库 (warehouse)

探索模式背包系统 (PlayerInventory)
└── 玩家背包 (inventory)
    └── 可与多种存储器交互
        ├── 宝箱 (ChestSystem)
        ├── 炉灶 (未实现)
        ├── 商店 (未实现)
        └── 其他... (可扩展)
```

### 优势
1. **独立性**: 探索模式和主场景的背包互不影响
2. **灵活性**: 玩家背包UI保持不变，只需改变存储器UI
3. **可扩展性**: 轻松添加新的存储器类型
4. **复用性**: 物品配置文件共享

## 使用方法

### 基本操作
1. 进入探索场景
2. 按 `B` 键打开背包
3. 靠近宝箱，按 `F` 键开启
4. 在背包和宝箱之间拖拽物品

### 开发者接口

#### 添加物品到背包
```gdscript
var explore_scene = get_tree().current_scene
explore_scene.player_inventory.add_item("apple", 5)
```

#### 检查背包内容
```gdscript
var inventory = explore_scene.player_inventory.inventory
for i in range(inventory.size()):
    if inventory[i] != null:
        print("格子 ", i, ": ", inventory[i].item_id, " x", inventory[i].count)
```

#### 自定义宝箱战利品
编辑 `config/chest_loot.json`:
```json
{
  "loot_tables": {
    "my_chest": {
      "name": "我的宝箱",
      "items": [
        {
          "item_id": "apple",
          "min_count": 1,
          "max_count": 5,
          "probability": 0.8
        }
      ]
    }
  }
}
```

## 后续扩展建议

### 1. 炉灶系统
- 创建 `FurnaceSystem` 类
- 在 `ExploreInventoryUI` 添加 `open_furnace()` 方法
- 实现烹饪逻辑

### 2. 商店系统
- 创建 `ShopSystem` 类
- 添加货币系统
- 实现买卖逻辑

### 3. 物品使用
- 在 `PlayerInventory` 添加 `use_item()` 方法
- 实现消耗品效果
- 添加装备系统

### 4. 背包升级
- 添加背包容量升级
- 实现背包分类
- 添加快捷栏

### 5. 宝箱动画
- 添加开启动画
- 添加粒子效果
- 添加音效

## 注意事项

1. **TileMapLayer设置**: 必须为宝箱tile添加自定义数据 `is_chest = true` (Godot 4.5使用TileMapLayer)
2. **物品配置**: 确保战利品表中的物品ID在 `items.json` 中存在
3. **场景结构**: 按照 `explore_inventory_setup.md` 中的结构创建UI节点
4. **性能**: 宝箱检测每帧执行，如果宝箱很多可以考虑优化
5. **保存系统**: 需要将 `player_inventory` 和 `chest_system` 的数据加入存档

## 测试清单

- [ ] 打开/关闭背包
- [ ] 靠近宝箱显示提示
- [ ] 开启宝箱获得战利品
- [ ] 在背包内移动物品
- [ ] 在背包和宝箱间转移物品
- [ ] 物品堆叠功能
- [ ] 物品交换功能
- [ ] 多个宝箱的交互
- [ ] 已开启宝箱不再显示提示
- [ ] B键快捷键
- [ ] 背包按钮

## 已知问题

无

## 版本历史

- v1.0 (2025-11-04): 初始版本
  - 实现基础背包系统
  - 实现宝箱系统
  - 实现交互提示
  - 系统分离完成
