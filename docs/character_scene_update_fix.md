# 角色场景状态更新修复

## 问题描述
角色通过goto或概率系统移动到新场景后，虽然 `current_scene` 变量更新了，但 SaveManager 中的角色场景没有同步更新。

### 症状
- 角色从当前场景消失
- 侧边栏显示角色仍在原场景
- 重新加载游戏后角色位置错误

### 根本原因
`load_character_for_scene()` 函数开始时会检查：
```gdscript
var character_scene = _get_character_scene()  // 从SaveManager获取
if character_scene != scene_id:
    visible = false  // 角色不在这个场景，隐藏
    return
```

如果在调用 `load_character_for_scene()` 之前没有更新 SaveManager，角色会被错误地隐藏。

## 修复方案

### 修复位置1: end_chat() - goto场景变化
```gdscript
if goto_scene != "":
    current_scene = goto_scene
    
    // ✅ 添加：先更新SaveManager
    if has_node("/root/SaveManager"):
        var save_mgr = get_node("/root/SaveManager")
        save_mgr.set_character_scene(current_scene)
    
    load_character_for_scene(current_scene)
```

### 修复位置2: _reload_with_probability() - 移动到其他场景
```gdscript
var new_scene = _get_random_other_scene()
if new_scene != "":
    current_scene = new_scene
    
    // ✅ 添加：更新SaveManager
    if has_node("/root/SaveManager"):
        var save_mgr = get_node("/root/SaveManager")
        save_mgr.set_character_scene(current_scene)
    
    load_character_for_scene(current_scene)
```

### 修复位置3: apply_enter_scene_probability()
此函数中已经有正确的更新逻辑，无需修改。

## 关键点
⚠️ **必须在调用 `load_character_for_scene()` 之前更新 SaveManager**

原因：
1. `load_character_for_scene()` 会检查 SaveManager 中的角色场景
2. 如果场景不匹配，角色会被隐藏
3. 只有场景匹配时，才会继续加载角色

## 验证方法
1. 让AI输出goto字段移动到其他场景
2. 检查侧边栏显示的角色位置是否正确
3. 切换到角色所在场景，确认角色可见
4. 切换到其他场景，确认角色不可见
5. 重新加载游戏，确认角色位置保持正确

## 相关信号
`SaveManager.set_character_scene()` 会触发 `character_scene_changed` 信号，侧边栏会自动更新显示。
