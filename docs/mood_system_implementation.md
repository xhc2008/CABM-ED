# 心情系统实现文档

## 概述

实现了基于AI响应的动态心情系统，包括心情图片切换、好感度和互动意愿的自动更新。

## 配置文件

### mood_config.json

位置：`config/mood_config.json`

```json
{
	"moods": [
		{
			"id": 0,
			"name": "平静",
			"name_en": "calm",
			"image": "normal.png",
			"color": "#FFFFFF"
		},
		...
	]
}
```

**字段说明：**
- `id`: 心情序号（0-6），对应AI返回的mood值
- `name`: 中文名称，显示在UI上
- `name_en`: 英文名称，用于内部存储和图片查找
- `image`: 图片文件名，位于 `assets/images/character/chat/`
- `color`: 显示颜色（十六进制格式）

## 实现细节

### 1. AI服务 (ai_service.gd)

#### 自动生成心情列表
```gdscript
func _generate_moods_list() -> String
```
- 从 `mood_config.json` 读取心情配置
- 生成格式：`"0=平静, 1=开心, 2=难过, ..."`
- 自动替换到system_prompt的 `{moods}` 占位符

#### 字段提取和应用
```gdscript
func _apply_extracted_fields()
```
在流式响应完成后自动执行：

**mood字段：**
- 从AI响应提取mood ID（0-6）
- 转换为英文名称（calm, happy, sad等）
- 更新到SaveManager

**will字段：**
- 提取互动意愿增量（-10到10）
- 与当前值相加，限制在0-150范围
- 更新到SaveManager

**like字段：**
- 提取好感度增量（-10到10）
- 与当前值相加，限制在0-100范围
- 更新到SaveManager

#### 新增信号
```gdscript
signal chat_fields_extracted(fields: Dictionary)
```
当字段提取完成后发送，包含：
- `mood`: 心情ID
- `will`: 互动意愿增量
- `like`: 好感度增量

### 2. 角色脚本 (character.gd)

#### 心情图片加载
```gdscript
func _load_chat_image_for_mood()
```
- 从SaveManager获取当前心情
- 从mood_config.json查找对应图片文件名
- 加载 `assets/images/character/chat/{image_filename}`

#### 实时心情切换
```gdscript
func _on_mood_changed(fields: Dictionary)
```
- 监听 `chat_fields_extracted` 信号
- 提取mood ID并转换为英文名
- 直接切换到新的心情图片（无动画）

#### 连接管理
- `start_chat()`: 连接AI服务信号
- `end_chat()`: 断开AI服务信号

### 3. 侧边栏 (sidebar.gd)

#### 配置驱动的显示
```gdscript
func _get_mood_text(mood: String) -> String
func _get_mood_color(mood: String) -> Color
```
- 从mood_config.json读取心情名称和颜色
- 自动更新UI显示
- 支持配置文件热更新

#### 实时更新
```gdscript
func _on_ai_fields_updated(_fields: Dictionary)
```
- 监听AI服务的 `chat_fields_extracted` 信号
- 当AI响应完成并提取字段后自动刷新显示
- 确保好感度、互动意愿、心情实时同步

#### 显示内容
- 好感度（0-100）
- 交互意愿（0-100）
- 心情（从配置文件读取中文名）
- 已移除：精力、信任等级（暂不使用）

## 图片资源要求

需要在 `assets/images/character/chat/` 目录下准备以下图片：

```
assets/images/character/chat/
├── normal.png      # 平静
├── happy.png       # 开心
├── sad.png         # 难过
├── angry.png       # 生气
├── surprised.png   # 惊讶
├── scared.png      # 害怕
└── disgusted.png   # 厌恶
```

**注意：**
- 如果图片不存在，会自动回退到 `normal.png`
- 所有图片应保持相同的尺寸和风格

## 工作流程

### 对话开始
1. 用户点击角色
2. `character.start_chat()` 被调用
3. 根据当前心情加载对应图片
4. 连接AI服务的字段提取信号

### AI响应处理
1. AI返回流式JSON响应
2. 实时提取并显示msg字段内容
3. 流式结束后解析完整JSON
4. 提取mood, will, like字段
5. 调用 `_apply_extracted_fields()`
6. 更新SaveManager中的数据
7. 发送 `chat_fields_extracted` 信号

### 心情切换
1. 角色脚本接收 `chat_fields_extracted` 信号
2. 提取mood ID
3. 查找对应的图片文件名
4. 直接切换图片（无动画）
5. 侧边栏接收同样的信号
6. 侧边栏调用 `_update_character_stats()` 刷新显示
7. 所有数据实时同步

### 对话结束
1. 用户点击"结束"按钮
2. `character.end_chat()` 被调用
3. 断开AI服务信号
4. 角色返回场景随机位置

## 数据流

```
AI响应 → 提取字段 → 更新SaveManager → 发送信号 → 更新UI
   ↓
完整JSON → 对话历史（用于上下文）
   ↓
msg内容 → 总结模型（生成记忆）
```

## 扩展性

### 添加新心情
1. 在 `mood_config.json` 添加新条目
2. 准备对应的图片文件
3. 无需修改代码

### 修改心情显示
1. 编辑 `mood_config.json` 中的name和color
2. 重启游戏即可生效

### 自定义字段处理
在 `_apply_extracted_fields()` 中添加新的字段处理逻辑

## 调试

### 查看提取的字段
在Godot控制台查看：
```
提取的字段: {mood: 1, will: 5, like: 3}
更新心情: happy
更新互动意愿: 50 -> 55 (增量: 5)
更新好感度: 30 -> 33 (增量: 3)
切换心情图片: res://assets/images/character/chat/happy.png
```

### 常见问题

**问题1: 心情图片不切换**
- 检查图片文件是否存在
- 查看控制台是否有"心情图片不存在"错误
- 确认mood_config.json格式正确

**问题2: 好感度/意愿不更新**
- 检查AI是否返回了will/like字段
- 查看控制台的"提取的字段"输出
- 确认JSON格式正确

**问题3: 心情显示为英文**
- 检查mood_config.json是否存在
- 确认name字段已正确设置
- 重启游戏

## 性能考虑

- 配置文件在每次需要时读取（文件很小，性能影响可忽略）
- 图片切换是直接替换，无额外开销
- 信号连接在对话开始时建立，结束时断开
