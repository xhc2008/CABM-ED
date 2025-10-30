# 背包系统使用指南

## 概述
背包系统提供了玩家背包和仓库的管理功能，支持物品的存储、移动、堆叠等操作。

## 功能特性

### 1. 双存储系统
- **背包**: 30个格子，用于随身携带物品
- **仓库**: 60个格子，用于长期存储物品

### 2. 物品交互
- 点击物品查看详细信息
- 拖拽移动物品（点击选中，再点击目标格子）
- 自动堆叠相同物品
- 不同物品自动交换位置

### 3. 数据持久化
- 自动保存到存档系统
- 支持跨场景数据保留

## 使用方法

### 在场景中添加背包按钮

```gdscript
# 方法1: 直接实例化场景
var inventory_button = preload("res://scenes/inventory_button.tscn").instantiate()
add_child(inventory_button)

# 方法2: 在编辑器中添加
# 将 scenes/inventory_button.tscn 拖入场景树
```

### 代码中添加物品

```gdscript
# 添加到背包
InventoryManager.add_item_to_inventory("CMR-951", 1)
InventoryManager.add_item_to_inventory("9mm_ammo", 60)

# 添加到仓库
InventoryManager.add_item_to_warehouse("medkit_small", 5)
```

### 监听背包变化

```gdscript
func _ready():
    InventoryManager.inventory_changed.connect(_on_inventory_changed)
    InventoryManager.warehouse_changed.connect(_on_warehouse_changed)

func _on_inventory_changed():
    print("背包内容已更新")

func _on_warehouse_changed():
    print("仓库内容已更新")
```

## 配置物品

在 `config/items.json` 中添加新物品：

```json
{
  "items": {
    "item_id": {
      "name": "物品名称",
      "type": "weapon|medical|ammo|misc",
      "description": "物品描述",
      "icon": "图标文件名.png",
      "weight": 1.0,
      "max_stack": 1,
      "其他属性": "..."
    }
  }
}
```

### 物品图标
- 路径: `assets/images/items/`
- 格式: PNG
- 建议尺寸: 64x64 或更高

## API参考

### InventoryManager (自动加载单例)

#### 常量
- `INVENTORY_SIZE`: 背包格子数量 (30)
- `WAREHOUSE_SIZE`: 仓库格子数量 (60)

#### 方法
- `add_item_to_inventory(item_id: String, count: int) -> bool`
  添加物品到背包

- `add_item_to_warehouse(item_id: String, count: int) -> bool`
  添加物品到仓库

- `get_item_config(item_id: String) -> Dictionary`
  获取物品配置信息

- `move_item(from_storage, from_index, to_storage, to_index, from_name, to_name) -> bool`
  移动物品（内部使用）

#### 信号
- `inventory_changed()`: 背包内容变化时触发
- `warehouse_changed()`: 仓库内容变化时触发

## 测试

使用测试脚本快速添加测试物品：

```gdscript
# 将 scripts/inventory_test.gd 添加到场景中
# 运行场景后会自动添加测试物品
```

## 注意事项

1. 物品ID必须在 `config/items.json` 中定义
2. 图标文件必须存在于 `assets/images/items/` 目录
3. 背包数据会自动保存到存档系统
4. 首次使用需要在 `project.godot` 中添加 InventoryManager 自动加载（已完成）
