# 开场系统更新日志

## 版本 1.1 (2025/10/14)

### 新增功能

#### 1. 添加开场背景图片
- ✅ 使用 `assets/images/index.png` 作为开场故事场景的背景
- 替换了原来的纯色背景
- 图片自动适应屏幕大小，保持宽高比

#### 2. 修复自动保存机制
- ✅ 解决了在初始设置完成前退出游戏会创建空存档的问题
- 添加 `is_initial_setup_completed` 标志
- 只有在初始设置完成后才允许自动保存

### 技术细节

#### 背景图片实现
**修改文件**: `scenes/intro_scene.tscn`, `scripts/intro_story.gd`

```gdscript
# 将 ColorRect 替换为 TextureRect
@onready var background: TextureRect = $Background
```

场景配置：
- `expand_mode = 1` - 忽略纹理大小
- `stretch_mode = 5` - 保持宽高比居中

#### 自动保存控制

**修改文件**: `scripts/save_manager.gd`, `scripts/initial_setup.gd`

**SaveManager 新增变量**:
```gdscript
var is_initial_setup_completed: bool = false
```

**SaveManager._ready() 修改**:
```gdscript
# 检查是否存在存档
var has_save = _has_save_file()

if has_save:
    load_game(current_slot)
    is_initial_setup_completed = true
else:
    # 首次启动，不加载存档，等待初始设置完成
    is_initial_setup_completed = false
```

**_auto_save() 修改**:
```gdscript
func _auto_save():
    # 只有在初始设置完成后才允许自动保存
    if enable_instant_save and is_initial_setup_completed:
        save_game(current_slot)
```

**_on_auto_save_timeout() 修改**:
```gdscript
func _on_auto_save_timeout():
    # 只有在初始设置完成后才允许自动保存
    if is_initial_setup_completed:
        save_game(current_slot)
```

**_notification() 修改**:
```gdscript
func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        # 只有在初始设置完成后才保存
        if is_initial_setup_completed:
            save_game(current_slot)
        get_tree().quit()
```

**initial_setup._create_initial_save() 修改**:
```gdscript
# 直接设置用户名，不触发自动保存
save_mgr.save_data.user_data.user_name = user_name

# 标记初始设置已完成
save_mgr.is_initial_setup_completed = true

# 现在可以保存了
save_mgr.save_game(1)
```

### 问题修复

#### 问题1: 开场背景缺失
**现象**: 开场场景使用纯色背景，缺少视觉吸引力

**解决方案**: 
- 添加 `assets/images/index.png` 作为背景
- 使用 TextureRect 替代 ColorRect
- 配置自动缩放和居中

#### 问题2: 提前创建空存档
**现象**: 
- 用户在开场或初始设置阶段退出游戏
- SaveManager 的自动保存机制创建了空存档
- 再次启动时跳过开场，但数据不完整

**解决方案**:
- 添加 `is_initial_setup_completed` 标志
- 首次启动时设为 `false`
- 所有自动保存操作检查此标志
- 只有在初始设置完成并创建存档后才设为 `true`

### 测试场景

#### 场景1: 正常首次启动
1. 删除存档
2. 启动游戏
3. 观看开场故事（现在有背景图片）
4. 完成初始设置
5. 进入游戏
6. ✅ 存档正常创建

#### 场景2: 开场阶段退出
1. 删除存档
2. 启动游戏
3. 在开场故事播放时退出
4. 再次启动
5. ✅ 仍然播放开场故事（没有创建空存档）

#### 场景3: 初始设置阶段退出
1. 删除存档
2. 启动游戏
3. 进入初始设置界面
4. 不填写任何信息，直接退出
5. 再次启动
6. ✅ 仍然播放开场故事（没有创建空存档）

#### 场景4: 完成设置后正常使用
1. 完成初始设置
2. 进入游戏
3. 进行各种操作（聊天、切换场景等）
4. ✅ 自动保存正常工作
5. 退出游戏
6. ✅ 保存正常触发

### 向后兼容性

- ✅ 已有存档的用户不受影响
- ✅ 启动时检测到存档会自动设置 `is_initial_setup_completed = true`
- ✅ 所有现有功能正常工作

### 已知限制

1. **背景图片**: 
   - 需要确保 `assets/images/index.png` 存在
   - 如果图片不存在，会显示空白背景

2. **UID问题**: 
   - 场景文件中的纹理UID是占位符
   - Godot会在导入时自动生成正确的UID

### 下一步改进建议

- [ ] 添加开场背景音乐
- [ ] 添加淡入淡出过渡效果
- [ ] 支持自定义开场背景
- [ ] 添加"跳过开场"选项（针对重装用户）
- [ ] 添加进度指示器

## 版本 1.0 (2025/10/14)

### 初始版本
- 游戏启动器
- 开场故事播报
- 初始设置界面
- 存档检测机制
- 数据保存功能

---

**更新时间**: 2025/10/14  
**状态**: ✅ 已完成并测试
