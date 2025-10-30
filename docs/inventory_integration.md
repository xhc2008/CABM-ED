# 背包系统集成说明

## 快速开始

### 1. 在Godot编辑器中重新加载项目
由于添加了新的自动加载节点 `InventoryManager`，需要重启Godot编辑器或重新加载项目。

### 2. 在主场景中添加背包按钮

找到你的主游戏场景（例如 `scenes/main.tscn` 或其他主场景），添加背包按钮：

#### 方法A: 在编辑器中添加（推荐）
1. 打开主场景
2. 在场景树中右键点击根节点
3. 选择 "实例化子场景"
4. 选择 `res://scenes/inventory_button.tscn`
5. 按钮会自动出现在左上角 (10, 10) 位置

#### 方法B: 通过代码添加
在主场景的脚本中添加：

```gdscript
func _ready():
    # 添加背包按钮
    var inventory_button = preload("res://scenes/inventory_button.tscn").instantiate()
    add_child(inventory_button)
```

### 3. 测试背包系统

#### 添加测试物品
创建一个测试场景或在现有场景中添加：

```gdscript
# 在 _ready() 函数中
func _ready():
    # 添加测试物品
    InventoryManager.add_item_to_inventory("CMR-951", 1)
    InventoryManager.add_item_to_inventory("UMP45", 1)
    InventoryManager.add_item_to_inventory("medkit_small", 3)
    InventoryManager.add_item_to_inventory("9mm_ammo", 60)
```

或者使用提供的测试脚本：
1. 在场景树中添加一个新的 Node
2. 将 `scripts/inventory_test.gd` 附加到该节点
3. 运行场景

### 4. 运行游戏
1. 点击左上角的"背包"按钮
2. 查看背包和仓库界面
3. 点击物品查看详情
4. 尝试移动物品

## 界面说明

### 背包界面布局
```
┌─────────────────────────────────────────────────────┐
│  [关闭]                                              │
├──────────────┬──────────────┬────────────────────────┤
│   背包       │   仓库       │   物品信息              │
│ ┌──┬──┬──┐  │ ┌──┬──┬──┐  │  物品名称               │
│ │  │  │  │  │ │  │  │  │  │  [图标]                 │
│ ├──┼──┼──┤  │ ├──┼──┼──┤  │  物品描述               │
│ │  │  │  │  │ │  │  │  │  │  属性详情               │
│ └──┴──┴──┘  │ └──┴──┴──┘  │                         │
│  (可滚动)    │  (可滚动)    │  (可滚动)               │
└──────────────┴──────────────┴────────────────────────┘
```

### 操作说明
1. **查看物品**: 点击有物品的格子，右侧显示详细信息
2. **移动物品**: 
   - 点击物品（格子高亮）
   - 再点击目标格子
   - 空格子：物品移动过去
   - 相同物品：自动堆叠
   - 不同物品：交换位置
3. **取消选择**: 再次点击已选中的格子

## 添加新物品

### 1. 准备物品图标
- 将图标文件放到 `assets/images/items/` 目录
- 推荐格式: PNG
- 推荐尺寸: 64x64 或更高

### 2. 在配置文件中添加物品
编辑 `config/items.json`:

```json
{
  "items": {
    "your_item_id": {
      "name": "物品显示名称",
      "type": "weapon",
      "description": "物品描述文本",
      "icon": "your_icon.png",
      "weight": 1.0,
      "max_stack": 1,
      "damage": 50
    }
  }
}
```

### 3. 在代码中使用
```gdscript
# 给玩家添加物品
InventoryManager.add_item_to_inventory("your_item_id", 1)
```

## 与现有系统集成

### 与SaveManager集成
背包数据已自动集成到保存系统中，无需额外操作。

### 在事件系统中使用
```gdscript
# 在事件中给予物品
func on_quest_complete():
    InventoryManager.add_item_to_inventory("reward_item", 1)
    # 显示提示
    print("获得了奖励物品！")
```

### 检查物品数量
```gdscript
func has_item(item_id: String, count: int = 1) -> bool:
    var total = 0
    for item in InventoryManager.inventory:
        if item != null and item.item_id == item_id:
            total += item.count
    return total >= count
```

## 自定义

### 修改格子数量
在 `scripts/inventory_manager.gd` 中修改：
```gdscript
const INVENTORY_SIZE = 30  # 背包格子数
const WAREHOUSE_SIZE = 60  # 仓库格子数
```

### 修改UI布局
编辑 `scenes/inventory_ui.tscn` 调整：
- 格子大小
- 列数
- 面板大小
- 颜色主题

### 修改按钮位置
编辑 `scenes/inventory_button.tscn` 调整按钮的 offset 属性。

## 故障排除

### 问题: 点击按钮没有反应
- 确保已重启Godot编辑器
- 检查 `project.godot` 中是否有 `InventoryManager` 自动加载
- 查看控制台是否有错误信息

### 问题: 物品图标不显示
- 检查图标文件是否存在于 `assets/images/items/` 目录
- 检查 `items.json` 中的 `icon` 字段是否正确
- 确保图标文件已被Godot导入

### 问题: 物品无法添加
- 检查物品ID是否在 `items.json` 中定义
- 检查背包是否已满
- 查看控制台错误信息

## 下一步

- 添加物品使用功能
- 添加物品丢弃功能
- 添加物品拖拽动画
- 添加音效
- 添加物品分类筛选
- 添加搜索功能
