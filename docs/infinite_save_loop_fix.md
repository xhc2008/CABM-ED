# 无限保存循环修复

## 问题描述
角色场景更新后出现无限保存循环，导致性能问题。

### 循环路径
1. `SaveManager.set_character_scene()` 触发 `character_scene_changed` 信号
2. `main.gd` 的 `_on_character_scene_changed()` 调用 `character.load_character_for_scene()`
3. `load_character_for_scene()` 完成后调用 `_save_character_state()`
4. `_save_character_state()` 调用 `SaveManager.set_character_scene()`
5. 回到步骤1，无限循环！

## 修复方案

### 1. 修改 `_save_character_state()` 函数
**位置**: `scripts/character.gd`

**修改前**:
```gdscript
func _save_character_state():
    save_mgr.set_character_scene(current_scene)  // ❌ 触发信号
    save_mgr.set_character_preset(original_preset)
```

**修改后**:
```gdscript
func _save_character_state():
    // ✅ 只保存预设，不保存场景
    // 场景应该在需要改变时立即保存
    save_mgr.set_character_preset(original_preset)
```

**原因**: 
- 场景应该在需要改变时立即保存（`end_chat`, `_reload_with_probability` 等）
- `_save_character_state()` 只负责保存预设位置
- 避免循环触发 `character_scene_changed` 信号

### 2. 添加首次启动初始化
**位置**: `scripts/character.gd` 的 `load_character_for_scene()`

**添加逻辑**:
```gdscript
var character_scene = _get_character_scene()

// ✅ 如果角色场景为空（首次启动），初始化
if character_scene == "":
    save_mgr.set_character_scene(scene_id)
    character_scene = scene_id
```

**原因**:
- 首次启动时，SaveManager中没有角色场景
- 需要初始化为默认场景
- 这是唯一需要在 `load_character_for_scene()` 中保存场景的情况

### 3. 添加场景变化监听
**位置**: `scripts/main.gd`

**添加代码**:
```gdscript
func _setup_managers():
    // 连接SaveManager的角色场景变化信号
    save_mgr.character_scene_changed.connect(_on_character_scene_changed)

func _on_character_scene_changed(new_scene: String):
    // 重新加载角色，根据当前用户场景决定可见性
    character.load_character_for_scene(current_scene)
```

**作用**:
- 当角色场景变化时，自动更新角色可见性
- 如果用户在角色的新场景，角色显示
- 如果用户不在角色的新场景，角色隐藏

## 场景保存的正确位置

### 应该保存场景的地方
1. **end_chat() - goto场景变化**
   ```gdscript
   save_mgr.set_character_scene(current_scene)
   load_character_for_scene(current_scene)
   ```

2. **_reload_with_probability() - 移动到其他场景**
   ```gdscript
   save_mgr.set_character_scene(current_scene)
   load_character_for_scene(current_scene)
   ```

3. **apply_enter_scene_probability() - 移动到其他场景**
   ```gdscript
   save_mgr.set_character_scene(new_scene)
   load_character_for_scene(new_scene)
   ```

4. **load_character_for_scene() - 仅首次启动**
   ```gdscript
   if character_scene == "":
       save_mgr.set_character_scene(scene_id)
   ```

### 不应该保存场景的地方
- ❌ `_save_character_state()` - 会导致循环
- ❌ `load_character_for_scene()` 的常规流程 - 场景已经保存过了

## 信号流程图

### 正常流程（无循环）
```
AI决定goto
  ↓
end_chat() 保存场景
  ↓
触发 character_scene_changed 信号
  ↓
_on_character_scene_changed()
  ↓
load_character_for_scene()
  ↓
_save_character_state() (只保存预设)
  ↓
结束 ✅
```

### 修复前的错误流程（有循环）
```
end_chat() 保存场景
  ↓
触发 character_scene_changed 信号
  ↓
_on_character_scene_changed()
  ↓
load_character_for_scene()
  ↓
_save_character_state() 保存场景 ❌
  ↓
触发 character_scene_changed 信号
  ↓
无限循环... 💥
```

## 额外修复：角色可见性问题

### 问题
当AI决定换场景或概率触发换场景后，角色仍然显示在用户当前场景，但实际上角色已经到另一个场景了。

### 原因
在 `end_chat()` 和 `_reload_with_probability()` 中，调用了：
```gdscript
load_character_for_scene(current_scene)  // current_scene是角色的新场景
```

但 `load_character_for_scene(scene_id)` 的参数应该是**用户当前所在的场景**，而不是角色的场景。

### 解决方案
移除直接调用 `load_character_for_scene()`，改为依赖信号机制：

```gdscript
// ✅ 只更新SaveManager
save_mgr.set_character_scene(new_scene)

// ✅ 不直接调用load_character_for_scene
// SaveManager会触发character_scene_changed信号
// main.gd监听这个信号，会调用：
// character.load_character_for_scene(用户当前场景)
```

这样：
- 如果用户在角色的新场景，角色会显示
- 如果用户不在角色的新场景，角色会被隐藏

## 测试要点
1. ✅ 角色场景变化后不会无限保存
2. ✅ 首次启动时角色场景正确初始化
3. ✅ 角色在正确的场景显示/隐藏
4. ✅ AI决定换场景后，角色在用户当前场景消失
5. ✅ 用户切换到角色新场景后，角色出现
6. ✅ 侧边栏显示正确的角色位置
7. ✅ 性能正常，没有卡顿
