# 服装系统实现文档

## 概述

服装系统允许玩家在浴室场景中更换角色的服装。不同的服装使用完全不同的一套立绘和预设位置。

## 功能特性

1. **换装入口**：在浴室场景右下角添加了可交互的换装按钮
2. **服装选择界面**：点击换装按钮后弹出服装选择界面，显示所有可用服装
3. **动态加载**：从 `config/character_presets/` 目录动态加载所有服装配置
4. **独立立绘**：每套服装有独立的场景立绘和聊天表情
5. **存档保存**：当前选择的服装会保存到存档中

## 文件结构变更

### 配置文件

**原来**：
- `config/character_presets.json` - 单一配置文件

**现在**：
- `config/character_presets/` - 配置目录
  - `default.json` - 默认服装配置
  - `costume2.json` - 其他服装配置
  - ...

每个配置文件新增 `id` 字段，用于标识服装。

### 图片资源

**原来**：
- `assets/images/character/` - 直接包含场景目录
  - `livingroom/1.png`
  - `bedroom/1.png`
  - ...

**现在**：
- `assets/images/character/` - 按服装ID分组
  - `default/` - 默认服装的图片
    - `livingroom/1.png`
    - `bedroom/1.png`
    - `chat/normal.png`
    - ...
  - `costume2/` - 其他服装的图片
    - ...

## 新增文件

### 脚本文件

1. **scripts/costume_button.gd**
   - 换装按钮的交互逻辑
   - 参考 `character_diary_button.gd` 实现
   - 在浴室场景显示，点击后弹出换装界面

2. **scripts/costume_selector.gd**
   - 换装选择界面
   - 动态加载所有可用服装
   - 显示服装名称和描述
   - 标记当前使用的服装

### 配置文件

1. **config/character_presets/default.json**
   - 默认服装的配置
   - 从原 `character_presets.json` 迁移而来
   - 新增 `id`、`name`、`description` 字段

2. **config/interactive_elements.json**
   - 新增 `costume_button` 配置项
   - 定义换装按钮的位置、大小和显示场景

### 文档文件

1. **config/character_presets/README.md**
   - 服装配置说明
   - 添加新服装的步骤

2. **assets/images/character/README.md**
   - 角色立绘目录结构说明
   - 必需的图片文件列表

## 代码修改

### SaveManager (scripts/save_manager.gd)

新增方法：
```gdscript
func get_costume_id() -> String
func set_costume_id(costume_id: String)
```

存档模板新增字段：
```json
"character_data": {
  "costume_id": "default",
  ...
}
```

### Character (scripts/character.gd)

修改的函数：
- `load_character_for_scene()` - 使用服装ID加载配置和图片
- `_load_chat_image_for_mood()` - 使用服装ID加载聊天图片
- `_load_default_chat_image()` - 使用服装ID加载默认图片
- `_reload_same_preset()` - 使用服装ID重新加载
- `_is_valid_scene()` - 验证场景在当前服装配置中是否存在
- `_update_preset_for_scene()` - 使用服装ID更新预设
- `_get_random_other_scene()` - 使用服装ID获取场景列表
- `_on_mood_changed()` - 使用服装ID切换心情图片

新增方法：
```gdscript
func _get_costume_id() -> String
func reload_with_new_costume()
```

### Main (scripts/main.gd)

新增节点引用：
```gdscript
@onready var costume_button = $CostumeButton if has_node("CostumeButton") else null
```

新增方法：
```gdscript
func _update_costume_button_layout()
func _update_costume_button_visibility()
func _on_costume_selector_requested()
func _on_costume_selected(costume_id: String)
```

修改的函数：
- `_ready()` - 连接换装按钮信号
- `_setup_managers()` - 注册换装按钮到UIManager
- `_update_ui_layout()` - 更新换装按钮布局
- `load_scene()` - 更新换装按钮可见性
- `_is_valid_scene()` - 使用当前服装配置验证场景

### InteractiveElementManager (scripts/interactive_element_manager.gd)

无需修改，自动支持新的 `costume_button` 配置。

## 使用流程

1. **进入浴室**：玩家切换到浴室场景
2. **点击换装按钮**：在场景右下角点击换装按钮
3. **选择服装**：在弹出的界面中选择想要的服装
4. **应用更换**：选择后立即应用，角色立绘和聊天表情都会更新
5. **自动保存**：新的服装选择会自动保存到存档

## 添加新服装

详见 `config/character_presets/README.md`

简要步骤：
1. 创建配置文件 `config/character_presets/新服装id.json`
2. 准备图片资源 `assets/images/character/新服装id/`
3. 确保所有场景和聊天表情图片齐全
4. 启动游戏测试

## 技术细节

### 配置文件格式

```json
{
  "id": "default",
  "name": "默认服装",
  "description": "初始服装",
  "livingroom": [...],
  "bedroom": [...],
  "bathroom": [...],
  "studyroom": [...],
  "kitchen": [...],
  "rooftop": [...]
}
```

### 图片路径规则

- 场景立绘：`assets/images/character/{costume_id}/{scene_id}/{image_file}`
- 聊天表情：`assets/images/character/{costume_id}/chat/{mood_image}`

### 存档兼容性

- 旧存档会自动使用 `default` 作为服装ID
- 如果配置的服装不存在，会回退到 `default`

## 注意事项

1. 服装ID必须与配置文件名和图片目录名一致
2. 所有场景的图片必须完整，否则会显示错误
3. 聊天表情图片必须齐全（11个心情）
4. 换装按钮只在浴室场景显示
5. 换装时会重新加载角色，保持当前位置
