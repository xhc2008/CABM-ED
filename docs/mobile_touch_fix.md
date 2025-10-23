# 移动端触摸滚动修复

## 问题描述

在移动端（手机/平板）上，日记页面无法通过触摸滑动，只能拖动右侧滚动条。

## 原因分析

1. **ScrollContainer配置不完整**：缺少必要的滚动模式设置
2. **鼠标过滤器设置不当**：子元素阻止了触摸事件传递到ScrollContainer

## 解决方案

### 1. ScrollContainer配置

在 `scenes/character_diary_viewer.tscn` 中添加：

```gdscript
[node name="ScrollContainer" type="ScrollContainer" parent="MarginContainer/VBoxContainer"]
custom_minimum_size = Vector2(0, 400)
layout_mode = 2
size_flags_vertical = 3
follow_focus = true              # 新增：跟随焦点
horizontal_scroll_mode = 0       # 新增：禁用横向滚动
vertical_scroll_mode = 2         # 新增：始终显示纵向滚动条
```

**参数说明**：
- `follow_focus = true`：当子元素获得焦点时自动滚动
- `horizontal_scroll_mode = 0`：禁用横向滚动（0 = SCROLL_MODE_DISABLED）
- `vertical_scroll_mode = 2`：始终显示纵向滚动条（2 = SCROLL_MODE_SHOW_ALWAYS）

### 2. 鼠标过滤器设置

在 `scripts/character_diary_viewer.gd` 中，确保所有不需要交互的元素设置为 `MOUSE_FILTER_IGNORE`：

#### Chat类型卡片（可点击）
```gdscript
# 内容容器忽略鼠标事件
card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

# 所有Label忽略鼠标事件
time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

# 只有Button接收点击事件
var click_button = Button.new()
click_button.flat = true
```

#### Offline类型卡片（不可点击）
```gdscript
# 所有元素都忽略鼠标事件
card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

## 鼠标过滤器模式说明

Godot中的鼠标过滤器有三种模式：

1. **MOUSE_FILTER_STOP** (默认)
   - 接收鼠标事件并阻止传递
   - 用于需要交互的控件（Button、TextEdit等）

2. **MOUSE_FILTER_PASS**
   - 接收鼠标事件但继续传递
   - 用于需要监听但不阻止的情况

3. **MOUSE_FILTER_IGNORE**
   - 完全忽略鼠标事件
   - 用于纯显示的控件（Label、Panel等）

## 触摸滚动原理

在移动端，触摸事件的传递顺序：

1. 用户触摸屏幕
2. 事件从最上层的控件开始传递
3. 如果控件的 `mouse_filter = STOP`，事件被拦截
4. 如果控件的 `mouse_filter = IGNORE`，事件继续传递
5. 最终到达 ScrollContainer，触发滚动

**关键点**：如果中间任何一个控件拦截了事件，ScrollContainer就无法接收到触摸事件，导致无法滚动。

## 测试建议

### 桌面端测试
- 鼠标滚轮滚动 ✓
- 拖动滚动条 ✓
- Chat卡片点击 ✓

### 移动端测试
- 触摸滑动滚动 ✓
- Chat卡片点击 ✓
- Offline卡片不可点击 ✓

## 其他ScrollContainer的最佳实践

1. **始终设置滚动模式**
   ```gdscript
   horizontal_scroll_mode = 0  # 通常禁用横向
   vertical_scroll_mode = 2    # 显示纵向滚动条
   ```

2. **子元素使用IGNORE**
   ```gdscript
   # 纯显示的元素
   label.mouse_filter = Control.MOUSE_FILTER_IGNORE
   panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
   ```

3. **可交互元素使用STOP**
   ```gdscript
   # 需要点击的元素
   button.mouse_filter = Control.MOUSE_FILTER_STOP
   ```

4. **容器使用PASS或IGNORE**
   ```gdscript
   # 容器通常不需要拦截事件
   vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
   ```

## 相关文档

- Godot官方文档：[ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html)
- Godot官方文档：[Control.MouseFilter](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-mousefilter)
