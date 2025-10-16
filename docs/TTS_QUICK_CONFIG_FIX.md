# TTS快速配置修复

## 问题描述

使用"快速配置"保存API密钥后，TTS服务没有自动加载新的密钥，导致TTS功能无法使用。只有使用"详细配置"才能正常工作。

## 原因分析

在 `ai_config_panel.gd` 的 `_on_quick_save_pressed()` 函数中：

```gdscript
# 原来的代码
if _save_config(config):
    _update_quick_status(true, "已保存: " + _mask_key(api_key))
    _reload_ai_service()  # ✅ 重新加载AI服务
    # ❌ 缺少：没有重新加载TTS服务
else:
    _update_quick_status(false, "保存失败")
```

**问题**：
- 保存配置后只重新加载了AI服务
- TTS服务没有重新加载，仍然使用旧的（空的）API密钥
- 导致TTS功能无法使用

## 解决方案

在快速保存后，同时重新加载TTS服务和刷新声音设置显示：

```gdscript
# 修复后的代码
if _save_config(config):
    _update_quick_status(true, "已保存: " + _mask_key(api_key))
    _reload_ai_service()      # ✅ 重新加载AI服务
    _reload_tts_service()     # ✅ 重新加载TTS服务
    _load_voice_settings()    # ✅ 刷新声音设置显示
else:
    _update_quick_status(false, "保存失败")
```

## TTS密钥加载逻辑

TTS服务的 `_load_tts_settings()` 函数会按以下顺序查找API密钥：

1. **TTS专用设置**：`user://tts_settings.json` 的 `api_key`
2. **详细配置TTS**：`user://ai_keys.json` 的 `tts_model.api_key`
3. **简单模式**：`user://ai_keys.json` 的 `api_key` ✅
4. **详细配置对话**：`user://ai_keys.json` 的 `chat_model.api_key`

**关键**：简单模式的API密钥会被TTS服务使用！

## 工作流程

### 修复前 ❌

```
用户操作：
1. 打开"AI 配置" → "快速配置"
2. 输入API密钥
3. 点击"保存配置"

系统行为：
✅ 保存到 user://ai_keys.json
✅ 重新加载AI服务（对话功能正常）
❌ TTS服务未重新加载（仍使用空密钥）
❌ 声音设置显示"⚠ 请先配置API密钥"

结果：
- 对话功能正常
- TTS功能无法使用
```

### 修复后 ✅

```
用户操作：
1. 打开"AI 配置" → "快速配置"
2. 输入API密钥
3. 点击"保存配置"

系统行为：
✅ 保存到 user://ai_keys.json
✅ 重新加载AI服务（对话功能正常）
✅ 重新加载TTS服务（加载简单模式密钥）
✅ 刷新声音设置显示（显示"✓ 声音已准备好"）

结果：
- 对话功能正常
- TTS功能正常
```

## 测试步骤

### 测试1：快速配置

1. 删除 `user://ai_keys.json`（如果存在）
2. 打开"AI 配置" → "快速配置"
3. 输入API密钥
4. 点击"保存配置"
5. 切换到"声音设置"标签页
6. 验证状态显示（应该显示"✓ 声音已准备好"或"⏳ 正在准备声音..."）
7. 勾选"启用语音合成"
8. 发送消息测试TTS

**预期结果**：TTS功能正常工作

### 测试2：详细配置

1. 打开"AI 配置" → "详细配置"
2. 配置TTS模型（包括API密钥）
3. 点击"保存详细配置"
4. 切换到"声音设置"标签页
5. 验证状态显示
6. 测试TTS

**预期结果**：TTS功能正常工作

### 测试3：切换模式

1. 先使用"快速配置"保存
2. 测试TTS（应该正常）
3. 再使用"详细配置"保存
4. 测试TTS（应该正常）
5. 再切换回"快速配置"
6. 测试TTS（应该正常）

**预期结果**：两种模式都能正常工作

## 日志输出

### 快速配置保存后

```
AI服务已重新加载配置
TTS服务已重新加载配置
TTS设置加载成功: enabled=true, volume=0.80, api_key=已设置
从AI配置(简单模式)加载TTS密钥
API密钥已加载: sk-xxxxxxx...
```

### 声音设置刷新

```
✓ 声音已准备好
```

或（如果需要上传）

```
⏳ 正在准备声音...
```

## 相关函数

### _reload_tts_service()

```gdscript
func _reload_tts_service():
    """重新加载TTS服务"""
    if has_node("/root/TTSService"):
        var tts_service = get_node("/root/TTSService")
        tts_service._load_tts_settings()
        print("TTS服务已重新加载配置")
```

### _load_voice_settings()

```gdscript
func _load_voice_settings():
    """加载声音设置"""
    if not has_node("/root/TTSService"):
        return
    
    var tts = get_node("/root/TTSService")
    
    # 更新UI
    voice_enable_checkbox.button_pressed = tts.is_enabled
    voice_volume_slider.value = tts.volume
    
    # 更新状态显示
    if tts.api_key.is_empty():
        voice_status_label.text = "⚠ 请先配置API密钥"
    elif tts.voice_uri.is_empty():
        voice_status_label.text = "⏳ 正在准备声音..."
    else:
        voice_status_label.text = "✓ 声音已准备好"
```

## 配置文件示例

### 快速配置（`user://ai_keys.json`）

```json
{
  "mode": "simple",
  "api_key": "sk-xxxxxxxxxxxxxxxx"
}
```

**TTS使用**：✅ 会使用这个密钥

### 详细配置（`user://ai_keys.json`）

```json
{
  "mode": "detailed",
  "chat_model": {
    "model": "deepseek-ai/DeepSeek-V3.2-Exp",
    "base_url": "https://api.siliconflow.cn/v1",
    "api_key": "sk-xxxxxxxxxxxxxxxx"
  },
  "summary_model": {
    "model": "Qwen/Qwen3-8B",
    "base_url": "https://api.siliconflow.cn/v1",
    "api_key": "sk-xxxxxxxxxxxxxxxx"
  },
  "tts_model": {
    "model": "FunAudioLLM/CosyVoice2-0.5B",
    "base_url": "https://api.siliconflow.cn",
    "api_key": "sk-xxxxxxxxxxxxxxxx"
  }
}
```

**TTS使用**：
1. 优先使用 `tts_model.api_key`
2. 如果没有，使用 `chat_model.api_key`

## 优先级总结

TTS服务加载API密钥的优先级（从高到低）：

1. **TTS专用设置** - `user://tts_settings.json`
2. **详细配置TTS** - `ai_keys.json` 的 `tts_model.api_key`
3. **简单模式** - `ai_keys.json` 的 `api_key`
4. **详细配置对话** - `ai_keys.json` 的 `chat_model.api_key`

## 建议

### 对于普通用户

使用"快速配置"即可，一个API密钥用于所有功能（对话、总结、TTS）。

### 对于高级用户

使用"详细配置"，可以为TTS单独配置API密钥（例如使用不同的账户或配额）。

## 相关文件

- `scripts/ai_config_panel.gd` - 修复的文件
- `scripts/tts_service.gd` - TTS服务（密钥加载逻辑）

---

**修复日期**：2025-10-16  
**状态**：✅ 已修复  
**影响**：快速配置现在可以正常用于TTS
