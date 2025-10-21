# 角色日记功能说明

## 功能概述

角色日记功能允许角色在玩家离线时"做一些事情"，并生成日记记录。玩家可以通过日记查看器查看角色在离线期间的活动。

## 实现细节

### 1. 日记生成

日记在 `offline_time_manager.gd` 中根据离线时间自动生成：

- **5分钟~3小时**：生成 1-2 条日记
- **3小时~24小时**：生成 3-5 条日记
- **24小时以上**：生成 6-10 条日记

### 2. 提示词配置

在 `config/ai_config.json` 中配置了离线日记生成的提示词：

- 使用 `offline` 框架
- 包含角色设定、任务、回复格式和记忆上下文
- AI 返回 JSON 数组格式，每个元素包含 `time` 和 `event` 字段

示例输出格式：
```json
[
  {"time": "09:30", "event": "早上起床后，我在卧室整理了一下衣柜。"},
  {"time": "14:00", "event": "下午在书房看了一会儿书，感觉很放松。"}
]
```

### 3. 日记保存

日记保存在两个地方：

1. **文件系统**：`user://character_diary/YYYY-MM-DD.jsonl`
   - 每天一个文件
   - JSONL 格式（每行一个 JSON 对象）

2. **记忆系统**：同时保存到 AI 记忆中
   - 作为记忆条目参与后续对话
   - 受 `max_memory_items` 限制

### 4. 日记查看

- **入口**：在 bedroom 场景点击角色日记按钮（配置在 `interactive_elements.json` 中）
- **界面**：
  - 按日期浏览
  - 显示时间和事件
  - 简洁的卡片式布局

## 文件结构

```
scripts/
├── offline_time_manager.gd          # 离线时间管理和日记生成
├── prompt_builder.gd                # 提示词构建（新增 build_offline_diary_prompt）
├── character_diary_button.gd        # 角色日记按钮
├── character_diary_viewer.gd        # 角色日记查看器
└── main.gd                          # 主场景集成

config/
├── ai_config.json                   # AI 配置（新增 offline 框架和提示词）
└── interactive_elements.json        # 交互元素配置（已有 SnowFox_diary_button）

user://
└── character_diary/                 # 角色日记存储目录
    ├── 2025-10-21.jsonl
    ├── 2025-10-22.jsonl
    └── ...
```

## 使用方法

### 玩家视角

1. 离线一段时间后重新进入游戏
2. 系统自动生成角色日记
3. 进入 bedroom 场景
4. 点击角色日记按钮（书本图标）
5. 在弹出的选项菜单中点击"📖 {角色名}的日记"
6. 浏览角色在离线期间的活动

### 开发者配置

1. **调整生成条目数**：修改 `offline_time_manager.gd` 中的 `randi_range()` 参数
2. **修改提示词**：编辑 `config/ai_config.json` 中的 `offline` 框架
3. **更改显示位置**：修改 `config/interactive_elements.json` 中的 `character_diary_button` 配置
4. **更改角色名称**：修改 `config/app_config.json` 中的 `character_name` 字段

## 注意事项

1. 日记生成需要 API 密钥配置
2. 如果 API 调用失败，不会影响其他离线逻辑
3. 日记同时保存到文件和记忆系统，确保数据持久化
4. 日记查看器使用与玩家日记相同的 UI 风格，保持一致性

## 未来扩展

- [ ] 支持日记搜索功能
- [ ] 添加日记导出功能
- [ ] 支持日记中的图片或表情
- [ ] 根据好感度调整日记内容风格
