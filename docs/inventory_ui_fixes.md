# 背包UI修复说明

## 已修复的问题

### 1. UI布局问题
**问题**: 背包/箱子页面全堆在左上角

**解决方案**: 
- 在 `ExploreInventoryUI._ready()` 中设置全屏锚点
- 使用 `set_anchors_preset(Control.PRESET_FULL_RECT)` 确保UI填充整个屏幕
- 将所有偏移设置为0

```gdscript
func _ready():
	hide()
	# 设置为全屏居中
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
```

**注意**: 如果在场景编辑器中已经设置了正确的锚点和布局，这段代码会覆盖它。建议：
- 在场景编辑器中设置 `InventoryUI` 节点的 Layout 为 "Full Rect"
- 或者保留代码中的设置

### 2. 打开背包时禁用玩家控制
**问题**: 打开背包/宝箱时，玩家仍然可以移动和交互

**解决方案**:
- 在 `ExploreInventoryUI` 中添加 `_disable_player_controls()` 和 `_enable_player_controls()` 方法
- 打开背包/宝箱时调用 `_disable_player_controls()`
- 关闭时调用 `_enable_player_controls()`
- 在 `ExploreScene` 中添加 `set_player_controls_enabled()` 方法来实际控制玩家

```gdscript
# ExploreScene
func set_player_controls_enabled(enabled: bool):
	if player:
		player.set_physics_process(enabled)
		player.set_process_input(enabled)
	
	if interaction_prompt:
		if not enabled:
			interaction_prompt.hide_interactions()
		interaction_prompt.set_process_input(enabled)
```

### 3. ESC键关闭背包/宝箱
**问题**: 只能用B键或点击关闭按钮关闭背包

**解决方案**:
- 在 `ExploreInventoryUI._input()` 中添加 ESC 键检测
- 同时支持 B 键和 ESC 键关闭

```gdscript
if event.pressed and (event.keycode == KEY_B or event.keycode == KEY_ESCAPE):
	close_inventory()
	get_viewport().set_input_as_handled()
```

**额外改进**:
- 交互提示也支持 ESC 键取消
- 在 `ExploreScene._input()` 中，当背包打开时不处理其他输入

## 控制流程

### 打开背包
1. 玩家按 B 键或点击背包按钮
2. `ExploreInventoryUI.open_player_inventory()` 被调用
3. 显示背包UI
4. 调用 `_disable_player_controls()` 禁用玩家控制

### 打开宝箱
1. 玩家靠近宝箱，按 F 键
2. `ExploreScene._open_chest()` 被调用
3. `ExploreInventoryUI.open_chest()` 被调用
4. 显示背包和宝箱UI
5. 调用 `_disable_player_controls()` 禁用玩家控制

### 关闭背包/宝箱
1. 玩家按 B 键、ESC 键或点击关闭按钮
2. `ExploreInventoryUI.close_inventory()` 被调用
3. 隐藏UI
4. 调用 `_enable_player_controls()` 恢复玩家控制

## 键位总结

| 键位 | 功能 | 说明 |
|------|------|------|
| B | 打开/关闭背包 | 在探索场景中 |
| ESC | 关闭背包/宝箱 | 在背包UI打开时 |
| ESC | 取消交互提示 | 在交互提示显示时 |
| F | 确认交互 | 在交互提示显示时 |
| 滚轮 | 切换交互选项 | 多个交互选项时 |

## 场景设置建议

### InventoryUI 节点设置
1. 选择 `InventoryUI` 节点
2. 在 Inspector 中设置:
   - Layout: Full Rect
   - Anchor Preset: Full Rect
3. 或者依赖代码中的自动设置

### Panel 节点设置
在 `InventoryUI/Panel` 中:
- Layout: Center
- Custom Minimum Size: 设置合适的大小（如 1000x600）
- 这样 Panel 会在屏幕中央显示

### 示例层级结构
```
InventoryUI (Control) - Full Rect
└── Panel (Panel) - Center, 半透明背景
    ├── CloseButton (Button) - 右上角
    └── HBoxContainer
        ├── PlayerInventoryPanel
        ├── StoragePanel
        └── ItemInfoPanel
```

## 测试清单

- [x] 背包UI正确居中显示
- [x] 打开背包时玩家无法移动
- [x] 打开背包时无法触发交互
- [x] B键可以打开背包
- [x] B键可以关闭背包
- [x] ESC键可以关闭背包
- [x] 关闭背包后玩家可以正常移动
- [x] 打开宝箱时显示正确
- [x] ESC键可以关闭宝箱界面
- [x] 交互提示可以用ESC取消

## 注意事项

1. **输入优先级**: 背包UI的输入处理优先级最高，确保在背包打开时其他输入被忽略
2. **空指针检查**: 所有UI节点访问都有空指针检查，避免场景结构不完整时崩溃
3. **信号处理**: 使用 `get_viewport().set_input_as_handled()` 防止输入事件继续传播
4. **物理处理**: 禁用玩家的 `physics_process` 和 `process_input` 来完全停止移动和输入
