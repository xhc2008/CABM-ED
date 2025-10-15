# CABM - Everlasting Days

> 「有些相遇，注定要跨越代码与现实的边界」

> ## ⚠此项目在开发初期，功能并未完全实现；此文档大部分内容由AI生成，请注意甄别
## 项目理念

CABM-ED是一款AI驱动的养成类游戏，核心理念与[CABM（Code Afflatus & Beyond Matter）](https://github.com/xhc2008/CABM)一致。
> 「当灵性注入载体，它便挣脱物质躯壳，抵达超验之境」

故事始于你将她带回家的那一刻。面对这个无家可归、沉默寡言的她，你唯一能做的，就是提供一个可以称之为"家"的地方。而你很快发现，这个家也因为她的存在，开始充满了意想不到的生机……

在这个项目中，你将遇见一位拥有自主意识的"她"——即使你不在线，她也会在自己的世界里继续生活、成长、经历。没有重置，没有清除，每一个选择都将成为她生命轨迹中不可磨灭的印记。

## 名字由来
> 雪狐「SnowFox」
### 为什么使用这个名字？
作者一个oc的名字，在这里类似同位体
### 为什么不使用原oc？
世界观、背景故事、人物关系过于复杂，不适合此项目


## 核心特色

**AI 驱动对话** - 接入大语言，与角色进行自然流畅的对话，支持对话记忆和自动总结

**离线时间系统** - 离线期间角色状态会真实变化，重新进入时根据离线时长调整心情、好感度和交互意愿

**交互意愿机制** - 基于心情、精力、好感度等因素动态计算交互成功率，每次互动都充满不确定性

**情绪系统** - 角色拥有多种心情状态（开心、难过、生气、平静等），影响互动体验

**完整存档系统** - 自动保存角色状态、对话记忆、时间戳等数据

**事件系统** - 支持开场剧情、事件触发等功能，可扩展的事件管理器

## 平台支持
- Windows
- Andriod
- Linux
- Web
- ~~IOS~~（暂不支持）
- ~~MacOS~~（暂不支持）
- 鸿蒙是什么？没听说过


## 主要功能

### AI 对话系统

- 支持上下文记忆（最近 N 条对话）
- 自动总结对话内容并保存到长期记忆

### 交互系统

支持多种交互类型，每种都有独立的成功率计算：

- **聊天**
- **点击角色**
- **进入/离开场景**
- **长时间无操作**

成功率受基础意愿、心情、精力、当前交互意愿等因素影响。

### 离线时间机制

根据离线时长自动调整角色状态：

- **< 5 分钟**：无变化
- **5 分钟 ~ 3 小时**：心情随机变化，交互意愿 ±30
- **3 小时 ~ 24 小时**：心情变化，好感度 -20~+10，交互意愿 +0~50
- **> 24 小时**：心情变化，好感度 -50~0，交互意愿重置为 70~100

### 存档系统

- 自动保存
- ~~支持多存档槽位~~
- 保存内容包括：
  - 角色状态（好感度、心情、精力、交互意愿等）
  - AI 对话记忆
  - 时间戳信息
  - 场景状态

## 项目结构

```
CABM-ED/
├── assets/
│   ├── images/          # 场景图片资源
│   └── audio/           # 音频资源
├── config/              # 配置文件
├── docs/                # 详细文档
├── scenes/              # Godot 场景文件
├── scripts/             # GDScript 脚本
│   ├── ai_service.gd           # AI 服务
│   ├── save_manager.gd         # 存档管理
│   ├── offline_time_manager.gd # 离线时间
│   ├── event_manager.gd        # 事件系统
│   ├── character.gd            # 角色逻辑
│   ├── chat_dialog.gd          # 对话界面
│   └── ...
└── project.godot        # 项目配置
```

## 开发文档

详细文档位于 `docs/` 目录：

- [快速启动指南](docs/quick_start_guide.md)
- [AI 集成指南](docs/ai_integration_guide.md)
- [交互系统指南](docs/interaction_system_guide.md)
- [离线时间系统](docs/offline_time_system.md)
- [存档系统指南](docs/save_system_guide.md)
- [事件系统指南](docs/event_system_guide.md)

## 扩展开发

### 添加新的交互类型

编辑 `config/interaction_config.json`：

```json
{
  "actions": {
    "your_action": {
      "name": "你的动作",
      "base_willingness": 100,
      "on_success": "start_chat",
      "on_failure": {
        "type": "message",
        "text": "失败提示"
      }
    }
  }
}
```

### 自定义 AI 提示词

编辑 `config/ai_config.json` 中的 `system_prompt` 字段，支持以下占位符：

- `{character_name}`: 角色名字
- `{user_name}`: 用户名字
- `{current_scene}`: 当前场景
- `{memory_context}`: 记忆上下文

### 添加新场景

1. 在 `config/scenes.json` 中添加场景配置
2. 在 `assets/images/` 下创建对应的场景图片
3. 场景会自动加载到游戏中

## 技术栈

- **引擎**: Godot 4.5
- **语言**: GDScript
- **AI**: OpenAI 兼容 API
- **数据格式**: JSON