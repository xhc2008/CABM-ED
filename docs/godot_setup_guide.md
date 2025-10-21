# Godot 编辑器设置指南 - 角色日记功能

## 在 main.tscn 中添加节点

### 1. 添加角色日记按钮

1. 打开 `scripts/main.tscn`
2. 在场景树中右键点击根节点（Main）
3. 选择"添加子节点" → 搜索 `Control` → 添加
4. 重命名节点为 `CharacterDiaryButton`
5. 在检查器中：
   - 附加脚本：点击"附加脚本"按钮
   - 选择 `scripts/character_diary_button.gd`
   - 点击"加载"

### 2. 添加角色日记查看器

#### 2.1 创建主节点
1. 在场景树中右键点击根节点（Main）
2. 选择"添加子节点" → 搜索 `Panel` → 添加
3. 重命名节点为 `CharacterDiaryViewer`
4. 在检查器中：
   - 附加脚本：`scripts/character_diary_viewer.gd`
   - 设置 `Custom Minimum Size`：`x=800, y=600`
   - 设置 `Visible`：关闭（取消勾选）

#### 2.2 创建子节点结构

**添加 MarginContainer：**
1. 右键点击 `CharacterDiaryViewer`
2. 添加子节点 → `MarginContainer`
3. 在检查器中设置：
   - `Layout` → `Anchors Preset` → `Full Rect`
   - `Theme Overrides` → `Constants`：
     - `margin_left`: 20
     - `margin_top`: 20
     - `margin_right`: 20
     - `margin_bottom`: 20

**添加 VBoxContainer：**
1. 右键点击 `MarginContainer`
2. 添加子节点 → `VBoxContainer`
3. 在检查器中设置：
   - `Theme Overrides` → `Constants` → `separation`: 10

**添加 TitleLabel：**
1. 右键点击 `VBoxContainer`
2. 添加子节点 → `Label`
3. 重命名为 `TitleLabel`
4. 在检查器中设置：
   - `Text`: "角色日记"
   - `Horizontal Alignment`: `Center`
   - `Theme Overrides` → `Font Sizes` → `font_size`: 24

**添加 CloseButton：**
1. 右键点击 `VBoxContainer`
2. 添加子节点 → `Button`
3. 重命名为 `CloseButton`
4. 在检查器中设置：
   - `Text`: "关闭"
   - `Size Flags` → `Horizontal`: `Shrink End`

**添加 DateSelector (HBoxContainer)：**
1. 右键点击 `VBoxContainer`
2. 添加子节点 → `HBoxContainer`
3. 重命名为 `DateSelector`
4. 在检查器中设置：
   - `Alignment`: `Center`
   - `Theme Overrides` → `Constants` → `separation`: 10

**添加 PrevButton：**
1. 右键点击 `DateSelector`
2. 添加子节点 → `Button`
3. 重命名为 `PrevButton`
4. 在检查器中设置：
   - `Text`: "◀ 前一天"

**添加 DateLabel：**
1. 右键点击 `DateSelector`
2. 添加子节点 → `Label`
3. 重命名为 `DateLabel`
4. 在检查器中设置：
   - `Text`: "2025-10-21"
   - `Custom Minimum Size` → `x`: 150
   - `Horizontal Alignment`: `Center`

**添加 NextButton：**
1. 右键点击 `DateSelector`
2. 添加子节点 → `Button`
3. 重命名为 `NextButton`
4. 在检查器中设置：
   - `Text`: "后一天 ▶"

**添加 ScrollContainer：**
1. 右键点击 `VBoxContainer`
2. 添加子节点 → `ScrollContainer`
3. 在检查器中设置：
   - `Size Flags` → `Vertical`: `Expand Fill`
   - `Custom Minimum Size` → `y`: 400

**添加 ContentVBox：**
1. 右键点击 `ScrollContainer`
2. 添加子节点 → `VBoxContainer`
3. 重命名为 `ContentVBox`
4. 在检查器中设置：
   - `Size Flags` → `Horizontal`: `Expand Fill`
   - `Theme Overrides` → `Constants` → `separation`: 10

### 3. 保存场景

1. 按 `Ctrl+S` 保存场景
2. 运行游戏测试功能

## 验证设置

### 检查节点路径

在脚本中使用的 `@onready` 路径应该匹配：

```gdscript
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var date_selector: HBoxContainer = $MarginContainer/VBoxContainer/DateSelector
@onready var prev_date_button: Button = $MarginContainer/VBoxContainer/DateSelector/PrevButton
@onready var date_label: Label = $MarginContainer/VBoxContainer/DateSelector/DateLabel
@onready var next_date_button: Button = $MarginContainer/VBoxContainer/DateSelector/NextButton
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var content_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox
```

### 测试功能

1. 运行游戏
2. 进入 bedroom 场景
3. 应该能看到角色日记按钮（在左下角）
4. 点击按钮，应该弹出选项菜单
5. 点击"{角色名}的日记"，应该打开日记查看器

## 常见问题

### 问题：节点路径错误
**解决方案**：检查节点名称是否与脚本中的 `@onready` 声明完全匹配（区分大小写）

### 问题：按钮不显示
**解决方案**：
1. 检查 `config/interactive_elements.json` 中 `character_diary_button` 的 `enabled` 是否为 `true`
2. 检查 `scenes` 数组是否包含 `"bedroom"`
3. 确保在 bedroom 场景中

### 问题：点击按钮没有反应
**解决方案**：
1. 检查脚本是否正确附加到节点
2. 检查信号是否正确连接（在 `main.gd` 中）
3. 查看控制台是否有错误信息

## 可选：使用场景实例化

如果你想创建可重用的场景文件：

1. 创建新场景：`scenes/character_diary_viewer.tscn`
2. 按照上述步骤创建节点结构
3. 保存场景
4. 在 `main.tscn` 中：
   - 右键点击根节点
   - 选择"实例化子场景"
   - 选择 `scenes/character_diary_viewer.tscn`
   - 重命名实例为 `CharacterDiaryViewer`

这样可以在多个地方重用相同的 UI 结构。
