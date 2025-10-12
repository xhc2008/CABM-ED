# UI与场景绑定系统

## 概述

所有UI组件（侧边栏、聊天对话框、动作菜单）现在都与场景图片的实际显示区域绑定，无论窗口大小如何变化，UI始终保持在场景范围内。

## 工作原理

### 1. 场景区域计算

系统会实时计算场景图片在屏幕上的实际显示区域：
- 考虑图片的宽高比保持（stretch_mode = 5）
- 计算图片的缩放比例和居中偏移
- 存储在 `scene_rect` 变量中

### 2. UI组件自动定位

#### 侧边栏 (Sidebar)
- 位置：场景左侧
- 高度：与场景高度相同
- 随场景移动和缩放

#### 聊天对话框 (ChatDialog)
- 位置：场景底部，从侧边栏右侧开始
- 宽度：场景宽度减去侧边栏宽度
- 高度：根据内容动态调整（输入模式80px，回复模式200px）
- 自动避开侧边栏，不会超出场景右侧边界

#### 动作菜单 (ActionMenu)
- 位置：角色旁边（点击角色时显示）
- 自动调整位置确保不超出场景边界
- 优先显示在角色右侧，空间不足时显示在左侧

### 3. 响应式更新

系统会在以下情况自动更新UI布局：
- 窗口大小变化
- 场景切换
- 每帧持续计算场景区域（确保实时同步）
- 聊天框可见时，每帧更新其位置（因为高度可能在动画中变化）

## 技术实现

### 核心函数

```gdscript
# 计算场景实际显示区域
func _calculate_scene_rect()

# 更新所有UI布局
func _update_ui_layout()

# 更新各个组件
func _update_sidebar_layout()
func _update_chat_dialog_layout()
func _update_action_menu_position()
```

### 关键变量

- `scene_rect: Rect2` - 场景在屏幕上的实际显示区域
- `scene_scale: Vector2` - 场景的缩放比例

## 优势

1. **完全响应式**：支持任意窗口大小和比例
2. **场景一致性**：UI永远不会超出场景范围
3. **自动适配**：无需手动调整UI位置
4. **视觉统一**：所有UI元素都与场景视觉绑定

## 使用说明

开发者无需手动设置UI位置，系统会自动处理。如需添加新的UI组件：

1. 在场景文件中添加组件（使用 `layout_mode = 0`）
2. 在 `_update_ui_layout()` 中添加更新逻辑
3. 根据 `scene_rect` 计算组件位置

## 示例

```gdscript
# 添加新UI组件到场景顶部
func _update_new_component_layout():
    new_component.position = Vector2(
        scene_rect.position.x,
        scene_rect.position.y
    )
    new_component.size.x = scene_rect.size.x
```
