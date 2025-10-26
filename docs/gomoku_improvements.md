# 五子棋游戏改进文档

## 改进概述

本次改进让五子棋小游戏与主游戏更好地衔接，提升了用户体验和游戏性。

## 1. 场景切换动画

### 进入动画
- 进入五子棋页面时，整个场景从透明渐变到完全显示
- 动画时长：0.5秒
- 实现位置：`_ready()` 函数

### 退出动画
- 退出时场景淡出效果
- 动画时长：0.3秒
- 实现位置：`_on_back_pressed()` 函数

## 2. UI改进

### 开始前的提示优化
- **"点击棋盘开始"提示**：字体放大到24号，颜色改为金黄色（更醒目）
- **"你先吧"按钮**：字体放大到22号

### 难度选择按钮
新增三个难度选择按钮，位于棋盘中央：
- **"能放点水吗"**：对应难度1（AI会放水）
- **"随便玩玩就好"**：对应难度2（普通难度）
- **"使出全力吧"**：对应难度3（高难度）

按钮样式：
- 字体大小：20号
- 最小尺寸：180x50像素
- 垂直排列，间距15像素

### 游戏信息显示
新增游戏信息标签，显示：
- 当前步数
- 谁先手
- 比分（玩家 vs AI）

格式示例：`步数: 15 | 先手: 你 | 比分: 2 - 1`

### 角色头像视频
- 位置：右侧面板（AI一侧）
- 视频路径：`assets/images/character/games/chess.mp4`
- 循环播放
- 游戏开始时显示，游戏结束时隐藏

注意：视频需要是Godot支持的格式（如Theora）

## 3. 游戏动画

### 落子动画
- 预留了落子动画接口（`_play_stone_animation`）
- 可以在此添加棋子落下的视觉效果

### 胜利/失败动画
- 胜利方的面板会闪烁（变亮再恢复）
- 动画时长：0.3秒变亮 + 0.3秒恢复
- 颜色变化：从白色到淡黄色再回到白色

### 游戏结束选项
- 游戏结束后显示"再来一局"按钮
- 按钮样式：24号字体，200x60像素
- 点击后重置棋盘，保留比分

## 4. 记录系统

### 日记记录
游戏记录会自动保存到角色日记，类型为 `games`

#### 记录内容格式
根据游戏情况生成不同的记录：

1. **完成了至少一局**：
   ```
   我和{user_name}玩了{x}局五子棋，我赢了/我输了/我们打成了平手，比分{ai_wins}比{player_wins}
   ```

2. **一局未完成但有进行中的游戏**：
   ```
   我和{user_name}玩了五子棋，但我们还没分出胜负
   ```

3. **没有开始游戏**：
   - 不记录

#### 日记查看器适配
在 `character_diary_viewer.gd` 中新增了对 `games` 类型的支持：
- 显示游戏图标：🎮
- 格式与 `offline` 类型类似
- 不可点击查看详情

## 5. 退出时保留棋盘

### 实现方式
- 退出时不调用 `_init_board()`
- 棋盘状态保留在内存中
- 下次进入时棋盘状态依然存在

### 重新开始功能
- 点击"再来一局"按钮会重置棋盘
- 但比分会保留

## 技术实现细节

### 新增变量
```gdscript
var ai_difficulty: int = 2 # AI难度
var player_wins: int = 0 # 玩家胜场
var ai_wins: int = 0 # AI胜场
var total_moves: int = 0 # 当前局总步数
var game_in_progress: bool = false # 是否有进行中的游戏
```

### 新增节点
```gdscript
@onready var difficulty_container: VBoxContainer = $DifficultyContainer
@onready var game_info_label: Label = $GameInfoLabel
@onready var player_video: VideoStreamPlayer = $LeftPanel/PlayerVideo
@onready var ai_video: VideoStreamPlayer = $RightPanel/AIVideo
```

### 新增函数
- `_setup_difficulty_buttons()`: 设置难度选择按钮
- `_setup_videos()`: 设置角色视频
- `_on_difficulty_selected(difficulty)`: 处理难度选择
- `_update_game_info()`: 更新游戏信息显示
- `_play_stone_animation()`: 落子动画（预留）
- `_play_game_end_animation(winner)`: 游戏结束动画
- `_show_restart_button()`: 显示再来一局按钮
- `_save_game_to_diary()`: 保存游戏记录到日记
- `_on_restart_pressed()`: 处理重新开始

## 使用说明

### 开始游戏
1. 进入五子棋页面
2. 选择难度（三个按钮之一）
3. 点击棋盘开始游戏，或点击"你先吧"让AI先手

### 游戏过程
- 查看顶部的游戏信息（步数、先手、比分）
- 观察右侧的角色视频
- 轮流落子

### 游戏结束
- 查看胜负结果和动画效果
- 点击"再来一局"继续游戏
- 点击"← 返回"退出（会自动保存记录）

### 查看记录
- 在角色日记中可以看到游戏记录
- 记录带有🎮图标
- 显示游戏结果和比分

## 注意事项

1. **视频格式**：`chess.mp4` 需要转换为Godot支持的格式（如Theora）
2. **性能**：视频播放可能影响性能，建议使用较小的视频文件
3. **用户名获取**：从 `app_config.json` 中读取 `user_name` 字段
4. **日记系统**：依赖 `SaveManager` 的 `add_diary_entry()` 方法

## 未来改进建议

1. 添加更丰富的落子动画效果
2. 添加音效（落子声、胜利音效等）
3. 添加悔棋功能
4. 添加游戏回放功能
5. 优化AI算法，提供更多难度级别
6. 添加游戏统计（总胜率、连胜记录等）
