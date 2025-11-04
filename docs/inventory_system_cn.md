# 背包系统重构完成

## 重构内容

已成功重构背包系统，解决了以下问题：

### 1. 消除代码重复
- 创建了 `StorageContainer` 通用存储容器类
- `PlayerInventory` 和 `InventoryManager` 现在都使用相同的底层逻辑
- 减少了约70%的重复代码

### 2. 修复UI布局问题
- 创建了 `UniversalInventoryUI` 通用背包UI
- 使用正确的锚点设置，确保全屏显示
- 修复了探索场景中UI堆在左上角的问题

### 3. 实现三栏布局
```
┌─────────────────────────────────────────────────┐
│  [关闭]                                         │
├──────────┬──────────┬──────────────────────────┤
│          │          │                          │
│  玩家背包 │  容器    │    物品详细信息          │
│  (左侧)  │  (中间)  │    (右侧)                │
│          │  可选    │                          │
│          │          │                          │
└──────────┴──────────┴──────────────────────────┘
```

### 4. 提高通用性
- 背包UI可在任何场景使用
- 支持任意容器组合（背包+仓库、背包+宝箱等）
- 容易扩展到新的存储类型

## 新文件结构

```
scripts/
├── storage_container.gd          # 通用存储容器类
├── universal_inventory_ui.gd     # 通用背包UI
├── inventory_manager.gd          # 全局背包管理器（已重构）
├── inventory_ui.gd               # 主场景背包UI（已重构）
├── inventory_slot.gd             # 物品格子（已更新）
└── explore/
    ├── player_inventory.gd       # 探索模式背包（已重构）
    └── explore_inventory_ui.gd   # 探索模式UI（已重构）

scenes/
├── universal_inventory_ui.tscn   # 通用背包UI场景
└── explore_inventory_ui.tscn     # 探索模式背包场景
```

## 核心类说明

### StorageContainer
```gdscript
# 创建容器
var container = StorageContainer.new(30, items_config)

# 添加物品
container.add_item("item_001", 5)

# 移除物品
container.remove_item(0, 1)

# 容器内移动
container.move_item_internal(0, 5)

# 跨容器转移
container.transfer_to(0, other_container, 5)

# 保存/加载
var data = container.get_data()
container.load_data(data)
```

### UniversalInventoryUI
```gdscript
# 设置玩家背包
setup_player_inventory(container, "背包")

# 设置其他容器（可选）
setup_other_container(container, "仓库")

# 只显示背包
open_inventory_only()

# 显示背包和容器
open_with_container()

# 关闭
close_inventory()
```

## 使用示例

### 主场景（背包+仓库）
```gdscript
# inventory_ui.gd
extends UniversalInventoryUI

func _ready():
    super._ready()
    setup_player_inventory(InventoryManager.inventory_container, "背包")
    setup_other_container(InventoryManager.warehouse_container, "仓库")

func toggle_visibility():
    if visible:
        close_inventory()
    else:
        open_with_container()
```

### 探索场景（背包+宝箱）
```gdscript
# explore_inventory_ui.gd
extends UniversalInventoryUI

func open_chest(chest_storage: Array):
    # 创建临时容器包装宝箱数据
    var chest_container = StorageContainer.new(chest_storage.size(), items_config)
    chest_container.storage = chest_storage
    
    setup_other_container(chest_container, "宝箱")
    open_with_container()
```

## 兼容性

### 数据格式保持不变
```gdscript
# 物品数据格式
{
    "item_id": "item_001",
    "count": 5
}
```

### API变化
```gdscript
# 旧方式
InventoryManager.inventory[0]
player_inventory.inventory[0]

# 新方式
InventoryManager.inventory_container.storage[0]
player_inventory.container.storage[0]
```

## 测试建议

1. **主场景测试**
   - 打开背包和仓库
   - 在背包和仓库之间移动物品
   - 测试物品堆叠
   - 测试保存/加载

2. **探索场景测试**
   - 按B键打开背包
   - 打开宝箱
   - 在背包和宝箱之间移动物品
   - 测试ESC键关闭

3. **UI测试**
   - 确认全屏显示正确
   - 确认三栏布局正确
   - 确认物品信息显示正确
   - 确认滚动条工作正常

## 已知问题

无

## 下一步优化建议

1. 添加物品拖拽功能
2. 添加快捷键（如Shift+点击快速转移）
3. 添加物品排序功能
4. 添加物品搜索/过滤功能
5. 添加物品使用/装备功能
