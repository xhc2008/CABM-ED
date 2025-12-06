# 探索场景重构文档

## 概述

本次重构主要解决以下问题：
1. `explore_scene.gd` 文件过大（1000+ 行）
2. 离开探索场景时缺少暂停逻辑，导致在加载期间仍可交互
3. 缺少加载动画，用户体验不佳
4. 死亡界面未被使用

## 主要改动

### 1. 模块化拆分

将 `explore_scene.gd` 拆分为多个专门的管理器：

#### ExploreSceneEnemyManager (敌人管理器)
- 文件：`scripts/explore/explore_scene_enemy_manager.gd`
- 职责：
  - 敌人生成和销毁
  - 敌人状态保存和加载
  - 敌人数据管理

#### ExploreSceneChunkManager (区块管理器)
- 文件：`scripts/explore/explore_scene_chunk_manager.gd`
- 职责：
  - 地图分块流式加载
  - 区块的加载和卸载
  - 优化大地图性能

#### ExploreSceneState (状态管理器)
- 文件：`scripts/explore/explore_scene_state.gd`
- 职责：
  - 场景状态管理（ACTIVE, PAUSED, EXITING, LOADING）
  - 检查点保存和恢复
  - 临时背包状态管理
  - 地图配置缓存

### 2. 场景状态系统

新增状态枚举：
```gdscript
enum State {
    ACTIVE,      # 正常探索中
    PAUSED,      # 暂停（打开背包等）
    EXITING,     # 正在退出（撤离或死亡）
    LOADING      # 加载中
}
```

状态转换：
- 场景加载 → LOADING → ACTIVE
- 打开背包 → PAUSED
- 撤离/死亡 → EXITING

### 3. 暂停逻辑

新增 `_pause_exploration()` 函数：
- 设置状态为 EXITING
- 禁用玩家控制
- 禁用雪狐物理
- 隐藏所有交互提示
- 禁用所有敌人

在以下情况下调用：
- 玩家死亡
- 玩家撤离

### 4. 加载界面

#### 撤离加载界面
- 文件：`scenes/loading_view.tscn` 和 `scripts/loading_view.gd`
- 功能：
  - 显示"撤离中..."标题
  - 显示当前操作状态（保存数据、保存记忆等）
  - 动画进度条
  - 完成提示

#### 死亡界面改进
- 文件：`scenes/death_view.tscn` 和 `scripts/death_view.gd`
- 改进：
  - 简化逻辑，只负责显示和用户确认
  - 发出 `death_view_closed` 信号
  - 由 `explore_scene.gd` 处理后续逻辑

### 5. 流程改进

#### 撤离流程
1. 玩家触发撤离
2. 立即调用 `_pause_exploration()` 暂停所有交互
3. 显示加载界面
4. 保存探索状态
5. 保存记忆（异步）
6. 更新加载状态
7. 切换到主场景

#### 死亡流程
1. 玩家死亡
2. 立即调用 `_pause_exploration()` 暂停所有交互
3. 显示死亡界面
4. 掉落玩家物品
5. 等待玩家点击"返回安全区"
6. 显示加载界面
7. 保存探索状态
8. 保存记忆（异步）
9. 切换到主场景

## 代码结构

### 主场景 (explore_scene.gd)
- 减少到约 600 行
- 主要负责协调各个管理器
- 处理UI交互
- 管理场景生命周期

### 管理器职责分离
- **EnemyManager**: 敌人相关
- **ChunkManager**: 地图加载相关
- **SceneState**: 状态和数据相关

## 使用示例

### 检查场景状态
```gdscript
if scene_state and scene_state.is_active():
    # 只在活跃状态下处理逻辑
    _check_nearby_chests()
```

### 暂停探索
```gdscript
func _on_player_died():
    _pause_exploration()  # 立即暂停所有交互
    _show_death_view()    # 显示死亡界面
```

### 显示加载界面
```gdscript
_show_loading_view("撤离中...", "正在保存数据...")
await get_tree().create_timer(0.1).timeout
# 执行保存操作
loading_view.set_status("正在保存记忆...")
```

## 优势

1. **代码可维护性**：文件更小，职责更清晰
2. **用户体验**：加载过程有视觉反馈，不会出现卡顿感
3. **稳定性**：暂停逻辑防止在加载期间的意外交互
4. **可扩展性**：模块化设计便于后续添加新功能

## 注意事项

1. 所有管理器都需要在 `_ready()` 中正确初始化
2. 状态转换应该通过 `scene_state.set_state()` 进行
3. 在 `_process()` 中始终检查 `scene_state.is_exiting()` 避免退出时的逻辑执行
4. 加载界面和死亡界面都应该添加到 `ui_root` 节点下
