# TTS状态显示修复

## 问题描述

当TTS未启用时，声音设置显示"⏳ 正在准备声音..."，这是误导性的。应该显示"TTS已禁用"。

## 原因分析

在 `ai_config_panel.gd` 的 `_load_voice_settings()` 函数中，状态判断逻辑没有考虑 `is_enabled` 的状态：

```gdscript
# 原来的逻辑（有问题）
if tts.api_key.is_empty():
    voice_status_label.text = "⚠ 请先配置API密钥"
elif tts.voice_uri.is_empty():
    voice_status_label.text = "⏳ 正在准备声音..."  # ❌ 即使未启用也显示这个
else:
    voice_status_label.text = "✓ TTS已就绪"
```

**问题**：
- 没有检查 `is_enabled` 状态
- 当 `is_enabled = false` 且 `voice_uri` 为空时，显示"正在准备声音..."
- 用户困惑：明明没有启用，为什么显示"正在准备"？

## 解决方案

修改状态判断逻辑，优先检查 `is_enabled`：

```gdscript
# 修复后的逻辑
if not tts.is_enabled:
    # 未启用
    voice_status_label.text = "TTS已禁用"
    voice_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
elif tts.api_key.is_empty():
    # 已启用但API密钥未配置
    voice_status_label.text = "⚠ 请先配置API密钥"
    voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
elif tts.voice_uri.is_empty():
    # 已启用，有密钥，但声音URI未准备好
    voice_status_label.text = "⏳ 正在准备声音..."
    voice_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
else:
    # 已启用且已就绪
    voice_status_label.text = "✓ TTS已就绪"
    voice_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
```

## 状态判断流程图

```
开始
  ↓
is_enabled? ──否──→ "TTS已禁用" (灰色)
  ↓ 是
api_key为空? ──是──→ "⚠ 请先配置API密钥" (橙色)
  ↓ 否
voice_uri为空? ──是──→ "⏳ 正在准备声音..." (蓝色)
  ↓ 否
"✓ TTS已就绪" (绿色)
```

## 状态显示对照表

| is_enabled | api_key | voice_uri | 显示文本 | 颜色 |
|-----------|---------|-----------|---------|------|
| false | 任意 | 任意 | TTS已禁用 | 灰色 |
| true | 空 | 任意 | ⚠ 请先配置API密钥 | 橙色 |
| true | 有 | 空 | ⏳ 正在准备声音... | 蓝色 |
| true | 有 | 有 | ✓ TTS已就绪 | 绿色 |

## 测试场景

### 场景1：初始状态（未启用）

**状态**：
- `is_enabled = false`
- `api_key = ""`
- `voice_uri = ""`

**修复前**：⏳ 正在准备声音... ❌  
**修复后**：TTS已禁用 ✅

### 场景2：启用但未配置密钥

**状态**：
- `is_enabled = true`
- `api_key = ""`
- `voice_uri = ""`

**修复前**：⚠ 请先配置API密钥 ✅  
**修复后**：⚠ 请先配置API密钥 ✅

### 场景3：启用且已配置密钥，但未上传

**状态**：
- `is_enabled = true`
- `api_key = "sk-xxx"`
- `voice_uri = ""`

**修复前**：⏳ 正在准备声音... ✅  
**修复后**：⏳ 正在准备声音... ✅

### 场景4：启用且已就绪

**状态**：
- `is_enabled = true`
- `api_key = "sk-xxx"`
- `voice_uri = "speech:xxx"`

**修复前**：✓ TTS已就绪 ✅  
**修复后**：✓ TTS已就绪 ✅

### 场景5：禁用但有缓存

**状态**：
- `is_enabled = false`
- `api_key = "sk-xxx"`
- `voice_uri = "speech:xxx"`

**修复前**：✓ TTS已就绪 ❌（误导）  
**修复后**：TTS已禁用 ✅

## 用户体验改进

### 修复前 ❌

```
用户操作：
1. 打开"AI 配置" → "声音设置"
2. 看到"⏳ 正在准备声音..."
3. 等待...
4. 还是"⏳ 正在准备声音..."
5. 困惑：为什么一直在准备？

实际情况：
- TTS根本没有启用
- 不会上传参考音频
- 永远不会"准备好"
```

### 修复后 ✅

```
用户操作：
1. 打开"AI 配置" → "声音设置"
2. 看到"TTS已禁用"
3. 理解：需要勾选"启用语音合成"
4. 勾选复选框
5. 看到"⏳ 正在准备声音..."
6. 几秒后看到"✓ TTS已就绪"

实际情况：
- 状态清晰明确
- 用户知道如何操作
- 体验流畅
```

## 状态转换

### 正常流程

```
TTS已禁用 (灰色)
  ↓ 勾选"启用语音合成"
⏳ 正在准备声音... (蓝色)
  ↓ 上传完成
✓ TTS已就绪 (绿色)
  ↓ 取消勾选
TTS已禁用 (灰色)
```

### 错误流程

```
TTS已禁用 (灰色)
  ↓ 勾选"启用语音合成"（但没有API密钥）
⚠ 请先配置API密钥 (橙色)
  ↓ 配置API密钥
⏳ 正在准备声音... (蓝色)
  ↓ 上传失败
✗ 上传错误 (401): Unauthorized (红色)
  ↓ 修正API密钥
⏳ 正在准备声音... (蓝色)
  ↓ 上传成功
✓ TTS已就绪 (绿色)
```

## 代码改进

### 优先级顺序

1. **is_enabled** - 最高优先级，如果未启用，其他都不重要
2. **api_key** - 第二优先级，启用了但没密钥
3. **voice_uri** - 第三优先级，有密钥但还没上传
4. **就绪** - 所有条件都满足

### 清晰的注释

```gdscript
# 检查配置状态
if not tts.is_enabled:
    # 未启用
    ...
elif tts.api_key.is_empty():
    # 已启用但API密钥未配置
    ...
elif tts.voice_uri.is_empty():
    # 已启用，有密钥，但声音URI未准备好
    ...
else:
    # 已启用且已就绪
    ...
```

## 相关文件

- `scripts/ai_config_panel.gd` - 修复的文件

## 测试建议

### 测试1：未启用状态

1. 确保TTS未启用（取消勾选）
2. 打开"AI 配置" → "声音设置"
3. 验证显示"TTS已禁用"（灰色）

### 测试2：启用但无密钥

1. 删除 `user://ai_keys.json`
2. 勾选"启用语音合成"
3. 验证显示"⚠ 请先配置API密钥"（橙色）

### 测试3：启用且有密钥

1. 配置API密钥
2. 删除 `user://voice_cache.json`
3. 勾选"启用语音合成"
4. 验证显示"⏳ 正在准备声音..."（蓝色）
5. 等待上传完成
6. 验证显示"✓ TTS已就绪"（绿色）

### 测试4：禁用已就绪的TTS

1. 确保TTS已就绪
2. 取消勾选"启用语音合成"
3. 验证显示"TTS已禁用"（灰色）

## 相关问题

这个修复解决了以下相关问题：

1. ✅ 未启用时显示误导性状态
2. ✅ 用户不知道需要启用TTS
3. ✅ 状态显示不清晰

## 总结

这是一个简单但重要的修复：

- **问题**：状态判断逻辑缺少 `is_enabled` 检查
- **影响**：用户体验差，状态显示误导
- **修复**：添加 `is_enabled` 优先级检查
- **结果**：状态显示清晰准确

---

**修复日期**：2025-10-16  
**状态**：✅ 已修复  
**影响**：UI显示逻辑
