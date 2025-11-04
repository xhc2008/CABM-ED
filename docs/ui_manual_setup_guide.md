# UI手动设置指南

## 问题1: 背包UI堆在左上角

### 原因
Control节点的锚点和布局没有正确设置。

### 解决方案

#### 方法1: 在场景编辑器中设置

1. 打开 `explore_scene.tscn`
2. 选择 `UI/InventoryUI` 节点
3. 在 Inspector 中设置：
   - **Layout**: 选择 "Full Rect" (或点击锚点预设的全屏图标)
   - **Anchor Left**: 0
   - **Anchor Top**: 0
   - **Anchor Right**: 1
   - **Anchor Bottom**: 1
   - **Offset Left**: 0
   - **Offset Top**: 0
   - **Offset Right**: 0
   - **Offset Bottom**: 0
   - **Grow Horizontal**: Both
   - **Grow Vertical**: Both

4. 在 `InventoryUI` 下添加一个 `ColorRect` 作为半透明背景：
   - 名称: `Background`
   - Layout: Full Rect
   - Color: 黑色，Alpha = 0.7
   - Mouse Filter: Stop

5. 在 `InventoryUI` 下添加 `Panel` 节点：
   - 名称: `Panel`
   - Layout: Center
   - Custom Minimum Size: 1000 x 600
   - Position: 使用锚点居中，然后调整 offset 使其居中

#### 方法2: 使用辅助脚本（推荐）

1. 打开 `explore_scene.tscn`
2. 在 Godot 编辑器中，点击 `Script` 菜单
3. 选择 `Open Script...`
4. 打开 `scripts/explore/ui_setup_helper.gd`
5. 点击 `File` -> `Run` (或按 `Ctrl+Shift+X`)
6. 脚本会自动创建所有UI节点
7. 保存场景

## 问题2: InteractionPrompt框大小不调整

### 已修复
代码已更新，现在会根据交互选项数量自动调整Panel大小。

### 手动设置（如果需要）

1. 选择 `UI/InteractionPrompt` 节点
2. 设置：
   - Layout: Center Right
   - Anchor Preset: Center Right
   - Offset Left: -250
   - Offset Right: -50
   - Offset Top: -100
   - Offset Bottom: 100

3. `InteractionPrompt/Panel` 设置：
   - Layout: Full Rect
   - 不要设置 Custom Minimum Size（让代码动态调整）

4. `Panel/VBoxContainer` 设置：
   - Layout: Full Rect
   - Separation: 10

5. `VBoxContainer/PromptList` 设置：
   - Separation: 5

## 完整UI结构

```
ExploreScene (Node2D)
├── Player (CharacterBody2D)
├── SnowFox (CharacterBody2D)
├── TileMapLayer
└── UI (CanvasLayer)
    ├── VirtualJoystick
    ├── InteractionPrompt (Control) [脚本: interaction_prompt.gd]
    │   └── Panel (Panel)
    │       └── VBoxContainer (VBoxContainer)
    │           └── PromptList (VBoxContainer)
    ├── InventoryUI (Control) [脚本: explore_inventory_ui.gd]
    │   ├── Background (ColorRect) - 半透明黑色背景
    │   └── Panel (Panel) - 居中的主面板
    │       ├── CloseButton (Button) - 右上角
    │       └── HBoxContainer (HBoxContainer)
    │           ├── PlayerInventoryPanel (Panel)
    │           │   └── VBoxContainer
    │           │       ├── Title (Label) - "背包"
    │           │       └── ScrollContainer
    │           │           └── InventoryGrid (GridContainer) - 6列
    │           ├── StoragePanel (Panel)
    │           │   └── VBoxContainer
    │           │       ├── Title (Label) - "宝箱"
    │           │       └── ScrollContainer
    │           │           └── StorageGrid (GridContainer) - 4列
    │           └── ItemInfoPanel (Panel)
    │               └── VBoxContainer
    │                   ├── ItemName (Label)
    │                   ├── ItemIcon (TextureRect)
    │                   └── ScrollContainer
    │                       └── ItemDescription (Label)
    ├── InventoryButton (Button) - 右上角
    └── ExitButton (Button)
```

## 详细节点属性

### InventoryUI (Control)
```
Layout: Full Rect
Anchors: (0, 0, 1, 1)
Offsets: (0, 0, 0, 0)
Mouse Filter: Stop
Script: explore_inventory_ui.gd
```

### InventoryUI/Background (ColorRect)
```
Layout: Full Rect
Color: rgba(0, 0, 0, 0.7)
Mouse Filter: Stop
```

### InventoryUI/Panel (Panel)
```
Layout: Center
Anchor Preset: Center
Custom Minimum Size: (1000, 600)
Offset Left: -500
Offset Right: 500
Offset Top: -300
Offset Bottom: 300
```

### InventoryUI/Panel/CloseButton (Button)
```
Text: "X"
Layout: Top Right
Offset Left: -40
Offset Right: -10
Offset Top: 10
Offset Bottom: 40
```

### InventoryUI/Panel/HBoxContainer (HBoxContainer)
```
Layout: Full Rect
Offset Left: 10
Offset Top: 50
Offset Right: -10
Offset Bottom: -10
Separation: 10
```

### PlayerInventoryPanel (Panel)
```
Custom Minimum Size: (300, 400)
Size Flags Horizontal: Expand Fill
```

### InventoryGrid (GridContainer)
```
Columns: 6
H Separation: 5
V Separation: 5
```

### StorageGrid (GridContainer)
```
Columns: 4
H Separation: 5
V Separation: 5
```

### ItemInfoPanel (Panel)
```
Custom Minimum Size: (250, 400)
```

### InteractionPrompt (Control)
```
Layout: Center Right
Anchor Preset: Center Right
Offset Left: -250
Offset Right: -50
Offset Top: -100
Offset Bottom: 100
Script: interaction_prompt.gd
```

## 快速检查清单

- [ ] InventoryUI 的 Layout 设置为 Full Rect
- [ ] InventoryUI 有 Background (ColorRect) 子节点
- [ ] Panel 设置为居中，大小为 1000x600
- [ ] HBoxContainer 包含三个面板
- [ ] InventoryGrid 设置为 6 列
- [ ] StorageGrid 设置为 4 列
- [ ] 所有脚本正确附加
- [ ] CloseButton 连接到 `_on_close_button_pressed` 信号
- [ ] InventoryButton 连接到场景的 `_on_inventory_button_pressed` 信号

## 信号连接

在场景编辑器中连接以下信号：

1. `InventoryUI/Panel/CloseButton` 的 `pressed` 信号
   - 连接到: `InventoryUI` 节点
   - 方法: `_on_close_button_pressed`

2. `InventoryButton` 的 `pressed` 信号
   - 连接到: `ExploreScene` 节点
   - 方法: `_on_inventory_button_pressed`

3. `ExitButton` 的 `pressed` 信号
   - 连接到: `ExploreScene` 节点
   - 方法: `_on_exit_button_pressed`

## 测试步骤

1. 运行场景
2. 按 B 键打开背包
3. 检查：
   - [ ] 背包UI应该居中显示
   - [ ] 有半透明黑色背景
   - [ ] Panel在屏幕中央
   - [ ] 可以看到"背包"标题
   - [ ] 格子正确排列
4. 靠近宝箱
5. 检查：
   - [ ] 右侧显示交互提示
   - [ ] 提示框大小适应内容
6. 按 F 打开宝箱
7. 检查：
   - [ ] 显示背包和宝箱两个面板
   - [ ] 可以拖拽物品
8. 按 ESC 关闭
9. 检查：
   - [ ] UI正确关闭
   - [ ] 玩家可以移动

## 常见问题

### Q: 背包还是在左上角
A: 检查 InventoryUI 节点的 Anchor 是否正确设置为 (0,0,1,1)，Offset 是否为 (0,0,0,0)

### Q: Panel 太小或太大
A: 调整 Panel 的 Custom Minimum Size 和 offset 值

### Q: 格子显示不正确
A: 检查 GridContainer 的 columns 属性和 separation 值

### Q: 交互提示不显示
A: 确保 InteractionPrompt 节点的脚本正确附加，且 Panel 和 PromptList 节点存在

### Q: 点击背包没反应
A: 检查 InventoryUI 的 Mouse Filter 是否设置为 Stop，Background 的 Mouse Filter 也应该是 Stop
