# 背包系统重构指南

## 概述

背包系统已重构为通用、可复用的组件，消除了代码重复，并修复了UI布局问题。

## 新架构

### 1. StorageContainer (scripts/storage_container.gd)
通用存储容器类，处理所有存储逻辑：
- 添加/移除物品
- 物品堆叠
- 容器内移动
- 跨容器转移
- 数据保存/加载

### 2. UniversalInventoryUI (scripts/universal_inventory_ui.gd)
通用背包UI组件，布局：
- **左侧**：玩家背包
- **中间**：其他容器（可选，如宝箱、仓库）
- **右侧**：物品详细信息

### 3. InventoryManager (scripts/inventory_manager.gd)
全局单例，管理主场景的背包和仓库：
```gdscript
InventoryManager.inventory_container  # 玩家背包
InventoryManager.warehouse_container  # 仓库
```

### 4. PlayerInventory (scripts/explore/player_inventory.gd)
探索模式的玩家背包，使用StorageContainer

### 5. ExploreInventoryUI (scripts/explore/explore_inventory_ui.gd)
探索模式的背包UI，继承自UniversalInventoryUI

## 使用方法

### 主场景使用（背包+仓库）

```gdscript
# scripts/inventory_ui.gd 已自动配置
extends UniversalInventoryUI

func _ready():
    super._ready()
    setup_player_inventory(InventoryManager.inventory_container, "背包")
    setup_other_container(InventoryManager.warehouse_container, "仓库")

func toggle_visibility():
    if visible:
        close_inventory()
    else:
        open_with_container()  # 显示背包和仓库
```

### 探索场景使用（背包+宝箱）

```gdscript
# 在explore_scene.gd中
var inventory_ui: ExploreInventoryUI

func _ready():
    # 创建背包UI
    var inventory_ui_scene = load("res://scenes/explore_inventory_ui.tscn")
    inventory_ui = inventory_ui_scene.instantiate()
    $UI.add_child(inventory_ui)
    inventory_ui.setup(player_inventory, chest_system)

# 打开玩家背包
func open_inventory():
    inventory_ui.open_player_inventory()

# 打开宝箱
func open_chest(chest_storage: Array):
    inventory_ui.open_chest(chest_storage)
```

### 创建自定义存储

```gdscript
# 创建一个20格的容器
var my_container = StorageContainer.new(20, items_config)

# 添加物品
my_container.add_item("item_001", 5)

# 在UI中显示
inventory_ui.setup_other_container(my_container, "我的容器")
inventory_ui.open_with_container()
```

## 修复的问题

1. ✅ **代码重复**：统一使用StorageContainer，消除重复逻辑
2. ✅ **UI布局问题**：UniversalInventoryUI使用正确的锚点和全屏布局
3. ✅ **通用性**：可在任何场景使用，支持任意容器组合
4. ✅ **三栏布局**：左侧背包 | 中间容器 | 右侧详情

## 迁移注意事项

### 旧代码
```gdscript
# 旧方式 - 直接访问数组
InventoryManager.inventory[0]
player_inventory.inventory[0]
```

### 新代码
```gdscript
# 新方式 - 通过容器访问
InventoryManager.inventory_container.storage[0]
player_inventory.container.storage[0]
```

## 键盘快捷键

- **B键**：打开/关闭背包
- **ESC键**：关闭背包
- **鼠标点击**：选择/移动物品

## 下一步

如果需要添加新的存储类型（如商店、交易等），只需：
1. 创建StorageContainer实例
2. 使用setup_other_container()设置
3. 调用open_with_container()显示
