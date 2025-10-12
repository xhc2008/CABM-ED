# 自动加载配置说明

## 需要添加的自动加载节点

在 Godot 编辑器中，打开 **项目 > 项目设置 > 自动加载**，添加以下节点：

### 1. SaveManager
- **路径**: `res://scripts/save_manager.gd`
- **节点名称**: `SaveManager`
- **启用**: ✓

### 2. InteractionManager
- **路径**: `res://scripts/interaction_manager.gd`
- **节点名称**: `InteractionManager`
- **启用**: ✓

## 或者手动编辑 project.godot

在 `project.godot` 文件中的 `[autoload]` 部分添加：

```ini
[autoload]

SaveManager="*res://scripts/save_manager.gd"
InteractionManager="*res://scripts/interaction_manager.gd"
```

## 验证配置

配置完成后，可以在任何脚本中直接使用：

```gdscript
# 访问存档管理器
var affection = SaveManager.get_affection()

# 访问交互管理器
var success = InteractionManager.try_interaction("chat")
```

## 注意事项

1. 自动加载的节点在游戏启动时自动创建
2. 这些节点在整个游戏生命周期中持续存在
3. 可以在任何场景的任何脚本中访问
4. 节点名称必须与配置中的名称一致
