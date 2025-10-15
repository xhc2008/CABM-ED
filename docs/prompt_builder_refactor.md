# 提示词构建器重构说明

## 概述

将 `ai_service.gd` 中的提示词构建逻辑拆分到独立的 `prompt_builder.gd` 脚本中，使代码结构更清晰，职责更明确。

## 变更内容

### 新增文件

- `scripts/prompt_builder.gd` - 提示词构建器单例

### 修改文件

- `scripts/ai_service.gd` - 移除提示词构建相关函数，改为调用 PromptBuilder
- `project.godot` - 注册 PromptBuilder 为自动加载单例

## 迁移的函数

以下函数从 `ai_service.gd` 迁移到 `prompt_builder.gd`：

1. `_build_system_prompt()` → `build_system_prompt()` (公开方法)
2. `_generate_moods_list()`
3. `_load_app_config()` (公开方法，供其他脚本使用)
4. `_get_scene_description()`
5. `_get_weather_description()`
6. `_convert_to_level()`
7. `_get_current_mood_name()` → `get_current_mood_name()` (公开方法)
8. `_format_current_time()`
9. `_get_trigger_context()`
10. `_get_memory_context()` → `get_memory_context()` (公开方法)
11. `_get_mood_name_en()` → `get_mood_name_en()` (公开方法)

## 使用方式

### 在 ai_service.gd 中

```gdscript
# 构建系统提示词
var prompt_builder = get_node("/root/PromptBuilder")
var system_prompt = prompt_builder.build_system_prompt(actual_trigger_mode)

# 获取心情英文名
var mood_name_en = prompt_builder.get_mood_name_en(mood_id)
```

### 在其他脚本中

如果其他脚本需要使用提示词构建相关的功能，可以直接访问 PromptBuilder 单例：

```gdscript
var prompt_builder = get_node("/root/PromptBuilder")

# 获取当前心情名称
var mood_name = prompt_builder.get_current_mood_name("happy")

# 获取记忆上下文
var memory = prompt_builder.get_memory_context()

# 加载应用配置
var app_config = prompt_builder._load_app_config()
```

## 优势

1. **职责分离** - AIService 专注于 API 调用和流式响应处理，PromptBuilder 专注于提示词构建
2. **代码可读性** - ai_service.gd 从 1100+ 行减少到约 900 行
3. **可维护性** - 提示词相关逻辑集中在一个文件中，便于修改和扩展
4. **可复用性** - 其他脚本也可以使用 PromptBuilder 的功能

## 注意事项

- PromptBuilder 必须在 AIService 之前加载（已在 project.godot 中正确配置）
- PromptBuilder 依赖 SaveManager 单例
- 所有公开方法（不带下划线前缀）可以被其他脚本调用
