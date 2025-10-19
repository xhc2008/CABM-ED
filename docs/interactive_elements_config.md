# 可交互元素配置说明

## 概述

所有可交互UI元素（如日记入口、未来的物品交互等）的位置、大小、显示场景等配置都统一在 `config/interactive_elements.json` 中管理。

## 配置文件结构

```json
{
  "elements": {
    "element_id": {
      "name": "元素名称",
      "type": "元素类型",
      "size": {
        "width": 宽度,
        "height": 高度
      },
      "position": {
        "anchor": "锚点位置",
        "offset_x": X偏移,
        "offset_y": Y偏移
      },
      "scenes": ["场景1", "场景2"],
      "enabled": true/false
    }
  }
}
```

## 配置项说明

### 基本属性

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | String | 元素的显示名称（用于调试） |
| `type` | String | 元素类型（如 "click_area"） |
| `enabled` | Boolean | 是否启用该元素 |

### 大小配置 (size)

| 字段 | 类型 | 说明 |
|------|------|------|
| `width` | Number | 元素宽度（像素） |
| `height` | Number | 元素高度（像素） |

### 位置配置 (position)

#### 锚点 (anchor)

支持的锚点位置：

| 锚点值 | 说明 | 示例用途 |
|--------|------|----------|
| `top_left` | 场景左上角 | 菜单按钮 |
| `top_right` | 场景右上角 | 设置按钮 |
| `bottom_left` | 场景左下角 | 日记入口 |
| `bottom_right` | 场景右下角 | 状态显示 |
| `center` | 场景中心 | 弹窗 |
| `left_center` | 场景左侧中心 | 侧边栏 |
| `right_center` | 场景右侧中心 | 场景切换 |

#### 偏移 (offset)

- `offset_x`: 水平偏移
  - 正值：向右移动
  - 负值：向左移动
  
- `offset_y`: 垂直偏移
  - 正值：向下移动
  - 负值：向上移动

**注意**：偏移是从锚点位置开始计算的。

### 场景配置 (scenes)

| 值 | 说明 |
|----|------|
| `[]` | 空数组，在所有场景显示 |
| `["bedroom"]` | 只在卧室显示 |
| `["bedroom", "livingroom"]` | 在卧室和客厅显示 |

## 示例配置

### 示例1：日记入口（左下角）

```json
{
  "diary_button": {
    "name": "日记入口",
    "type": "click_area",
    "size": {
      "width": 80,
      "height": 80
    },
    "position": {
      "anchor": "bottom_left",
      "offset_x": 10,
      "offset_y": -10
    },
    "scenes": ["bedroom"],
    "enabled": true
  }
}
```

效果：在卧室场景的左下角，距离左边缘10像素，距离底部10像素。

### 示例2：物品交互（右下角）

```json
{
  "item_interact": {
    "name": "物品交互",
    "type": "click_area",
    "size": {
      "width": 100,
      "height": 100
    },
    "position": {
      "anchor": "bottom_right",
      "offset_x": -20,
      "offset_y": -20
    },
    "scenes": ["livingroom"],
    "enabled": true
  }
}
```

效果：在客厅场景的右下角，距离右边缘20像素，距离底部20像素。

### 示例3：全局菜单（右上角）

```json
{
  "global_menu": {
    "name": "全局菜单",
    "type": "button",
    "size": {
      "width": 60,
      "height": 60
    },
    "position": {
      "anchor": "top_right",
      "offset_x": -15,
      "offset_y": 15
    },
    "scenes": [],
    "enabled": true
  }
}
```

效果：在所有场景的右上角显示。

## 响应式布局

### 自动适配

系统会自动处理以下情况：

1. **窗口大小变化**：所有元素位置自动重新计算
2. **场景切换**：根据配置自动显示/隐藏元素
3. **聊天状态**：聊天时自动禁用所有交互元素

### 测试不同屏幕尺寸

1. 调整游戏窗口大小
2. 观察元素位置是否正确
3. 检查元素是否保持在场景范围内

## 添加新元素

### 步骤1：在配置文件中添加

编辑 `config/interactive_elements.json`：

```json
{
  "elements": {
    "my_new_element": {
      "name": "我的新元素",
      "type": "click_area",
      "size": {
        "width": 100,
        "height": 100
      },
      "position": {
        "anchor": "center",
        "offset_x": 0,
        "offset_y": 0
      },
      "scenes": ["bedroom"],
      "enabled": true
    }
  }
}
```

### 步骤2：创建元素脚本

参考 `scripts/diary_button.gd`：

```gdscript
extends Control

const ELEMENT_ID = "my_new_element"

func _ready():
    # 从配置获取大小
    if has_node("/root/InteractiveElementManager"):
        var mgr = get_node("/root/InteractiveElementManager")
        var element_size = mgr.get_element_size(ELEMENT_ID)
        custom_minimum_size = element_size
        mgr.register_element(ELEMENT_ID, self)
```

### 步骤3：在main.gd中添加布局更新

```gdscript
func _update_my_element_layout():
    if my_element == null:
        return
    
    if has_node("/root/InteractiveElementManager"):
        var mgr = get_node("/root/InteractiveElementManager")
        my_element.position = mgr.calculate_element_position(
            "my_new_element", 
            scene_rect, 
            my_element.size
        )
```

### 步骤4：注册到UIManager

```gdscript
func _setup_managers():
    if has_node("/root/UIManager"):
        var ui_mgr = get_node("/root/UIManager")
        ui_mgr.register_element(my_element)
```

## 调试技巧

### 查看元素配置

```gdscript
var mgr = get_node("/root/InteractiveElementManager")
var config = mgr.get_element_config("diary_button")
print(config)
```

### 检查元素是否应该显示

```gdscript
var mgr = get_node("/root/InteractiveElementManager")
var should_show = mgr.should_show_in_scene("diary_button", "bedroom")
print("Should show: ", should_show)
```

### 计算位置

```gdscript
var mgr = get_node("/root/InteractiveElementManager")
var pos = mgr.calculate_element_position("diary_button", scene_rect, element_size)
print("Position: ", pos)
```

## 常见问题

### Q: 修改配置后不生效？
**A:** 需要重启游戏，配置在启动时加载。

### Q: 元素位置不对？
**A:** 检查：
1. 锚点是否正确
2. 偏移值的正负号
3. 元素大小是否正确

### Q: 元素在某些场景不显示？
**A:** 检查 `scenes` 配置，确保包含目标场景ID。

### Q: 如何临时禁用某个元素？
**A:** 将 `enabled` 设置为 `false`。

### Q: 如何让元素在所有场景显示？
**A:** 将 `scenes` 设置为空数组 `[]`。

## 性能考虑

- 配置文件只在启动时加载一次
- 位置计算只在需要时进行（窗口大小变化、场景切换）
- 不会影响游戏性能

## 未来扩展

可能的扩展方向：

1. **动画配置**：配置元素的显示/隐藏动画
2. **条件显示**：基于游戏状态的显示条件
3. **热重载**：运行时重新加载配置
4. **可视化编辑器**：图形化配置工具
5. **多分辨率适配**：不同分辨率使用不同配置
