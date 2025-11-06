# 背包系统优化总结

## 完成的优化

### 1. 武器栏功能
- **StorageContainer**: 添加了 `weapon_slot` 和 `has_weapon_slot` 属性
- **初始化**: 玩家背包和雪狐背包启用武器栏（`enable_weapon_slot=true`）
- **UI组件**: 创建了 `weapon_slot.tscn` 和 `weapon_slot.gd` 用于显示武器栏
- **拖拽支持**: 武器栏支持拖拽，只能放置type为"武器"的物品
- **大小区别**: 武器槽尺寸为 160x80，普通槽为 64x64

**修改的文件**:
- `scripts/storage_container.gd` - 添加武器栏支持
- `scripts/inventory_manager.gd` - 初始化时启用武器栏
- `scripts/inventory_ui.gd` - 雪狐背包启用武器栏
- `scripts/explore/player_inventory.gd` - 探索模式背包启用武器栏
- `scripts/explore/snow_fox_companion.gd` - 雪狐存储格式更新
- `scripts/universal_inventory_ui.gd` - UI支持武器栏显示和交互
- `scenes/weapon_slot.tscn` - 武器槽场景（新建）
- `scripts/weapon_slot.gd` - 武器槽脚本（新建）

### 2. 每日刷新地图
- **SaveManager**: 添加 `_check_daily_refresh()` 函数
- **逻辑**: 加载存档时检查日期，如果与上次游玩日期不同，删除 `opened_chests` 字段
- **实现位置**: `load_game()` 函数中，在加载数据后立即检查

**修改的文件**:
- `scripts/save_manager.gd` - 添加每日刷新逻辑

### 3. 取消仓库物品上限
- **InventoryManager**: 仓库大小从 60 改为 9999
- **实现**: `warehouse_container = StorageContainer.new(9999, items_config, false)`

**修改的文件**:
- `scripts/inventory_manager.gd` - 移除 WAREHOUSE_SIZE 常量，直接使用大数字

### 4. 唯一物品管理
- **配置文件**: 创建 `config/unique_items.json` 定义唯一物品列表
- **管理逻辑**: 
  - 扫描玩家背包、雪狐背包和仓库
  - 缺少的唯一物品自动添加到仓库
  - 多余的唯一物品自动删除（保留第一个）
- **触发时机**: 加载存档数据后自动执行

**新建的文件**:
- `config/unique_items.json` - 唯一物品配置

**修改的文件**:
- `scripts/inventory_manager.gd` - 添加唯一物品管理逻辑

### 5. 代码优化
- **存储格式统一**: 所有容器使用统一的数据格式（支持新旧格式兼容）
- **武器栏数据**: 使用 Dictionary 格式 `{storage: Array, weapon_slot: Dictionary}`
- **类型安全**: 确保所有 count 字段都是整数类型

### 6. 探索场景背包按钮
- **位置**: 左上角，返回按钮下方
- **功能**: 点击打开/关闭背包（相当于B键）
- **样式**: 显示 "背包 (B)" 文本

**修改的文件**:
- `scripts/explore/explore_scene.gd` - 配置背包按钮

### 7. 探索场景固定分辨率
- **分辨率**: 1280x720
- **缩放模式**: 不同屏幕直接缩放
- **实现**: 在 `_ready()` 中设置视口大小

**修改的文件**:
- `scripts/explore/explore_scene.gd` - 设置固定分辨率

## 数据格式变化

### 旧格式（Array）
```json
[
  {"item_id": "CMR-951", "count": 1},
  null,
  {"item_id": "apple", "count": 5}
]
```

### 新格式（Dictionary）
```json
{
  "storage": [
    {"item_id": "CMR-951", "count": 1},
    null,
    {"item_id": "apple", "count": 5}
  ],
  "weapon_slot": {
    "item_id": "UMP45",
    "count": 1
  }
}
```

## 兼容性
- 所有加载函数都支持新旧格式自动转换
- 旧存档可以正常加载并自动升级到新格式
- 武器栏为可选功能，不影响现有容器

## 测试建议
1. 测试武器栏拖拽（武器与武器交换、武器与空槽）
2. 测试每日刷新（修改系统日期后重新加载游戏）
3. 测试唯一物品管理（删除/添加唯一物品后重新加载）
4. 测试仓库大容量（添加大量物品）
5. 测试探索场景背包按钮和B键
6. 测试不同分辨率下探索场景的显示
