# TTS UI集成改进

## 改进说明

将独立的"声音设置"面板集成到"AI 配置"面板中，作为一个标签页。

## 改进原因

1. **统一管理**：所有AI相关配置（对话、总结、TTS）集中在一个地方
2. **减少按钮**：侧边栏更简洁，不需要单独的"声音设置"按钮
3. **逻辑清晰**：TTS是AI功能的一部分，放在AI配置中更合理
4. **用户体验**：一个面板管理所有配置，更方便

## 改动内容

### 1. AI配置面板场景（`scenes/ai_config_panel.tscn`）

**新增**：
- "声音设置"标签页
- 启用/禁用复选框
- 音量滑块
- 音量百分比显示
- 状态标签
- 提示文本

**结构**：
```
TabContainer
├── 快速配置
├── 详细配置
└── 声音设置 ← 新增
    ├── 启用语音合成 [CheckBox]
    ├── 音量 [HSlider]
    ├── 音量显示 [Label]
    ├── 状态 [Label]
    └── 提示 [Label]
```

### 2. AI配置面板脚本（`scripts/ai_config_panel.gd`）

**新增变量**：
```gdscript
@onready var voice_enable_checkbox = ...
@onready var voice_volume_slider = ...
@onready var voice_volume_label = ...
@onready var voice_status_label = ...
```

**新增函数**：
```gdscript
func _load_voice_settings()
func _on_voice_enable_toggled(enabled: bool)
func _on_voice_volume_changed(value: float)
func _update_voice_volume_label(value: float)
func _on_voice_ready(_voice_uri: String)
```

**功能**：
- 加载TTS设置
- 启用/禁用TTS
- 调节音量
- 显示状态

### 3. 侧边栏（`scripts/sidebar.gd`）

**移除**：
- "声音设置"按钮
- `_on_voice_settings_pressed()` 函数

**保留**：
- "AI 配置"按钮（现在包含声音设置）

### 4. 独立声音设置面板

**状态**：
- `scenes/voice_settings_panel.tscn` - 保留（可选删除）
- `scripts/voice_settings_panel.gd` - 保留（可选删除）

**说明**：这些文件现在不再使用，但保留以备将来需要独立面板时使用。

## 使用方式

### 旧方式 ❌
```
左侧边栏 → "声音设置"按钮 → 独立面板
```

### 新方式 ✅
```
左侧边栏 → "AI 配置"按钮 → "声音设置"标签页
```

## 功能对比

| 功能 | 独立面板 | 集成标签页 |
|------|---------|-----------|
| 启用/禁用 | ✅ | ✅ |
| 音量调节 | ✅ | ✅ |
| 状态显示 | ✅ | ✅ |
| 提示信息 | ❌ | ✅ |
| 统一管理 | ❌ | ✅ |
| 侧边栏简洁 | ❌ | ✅ |

## 界面预览

### AI配置面板 - 声音设置标签页

```
┌─────────────────────────────────────┐
│          AI 配置              [×]   │
├─────────────────────────────────────┤
│ [快速配置] [详细配置] [声音设置]    │
├─────────────────────────────────────┤
│                                     │
│  启用语音合成          [✓]          │
│                                     │
│  音量                               │
│  ├─────────●─────────┤              │
│           80%                       │
│                                     │
│  ─────────────────────────────      │
│                                     │
│  ✓ 声音已准备好                     │
│                                     │
│  提示：首次启用需要上传参考音频，   │
│  可能需要5-10秒                     │
│                                     │
└─────────────────────────────────────┘
```

## 状态显示

### 未配置API密钥
```
⚠ 请先配置API密钥
```
颜色：橙色

### 正在准备
```
⏳ 正在准备声音...
⏳ 正在上传参考音频...
```
颜色：蓝色

### 已准备好
```
✓ 声音已准备好
✓ 语音合成已启用
```
颜色：绿色

### 已禁用
```
语音合成已禁用
```
颜色：灰色

## 工作流程

### 首次使用

1. 打开"AI 配置"
2. 在"快速配置"或"详细配置"中设置API密钥
3. 切换到"声音设置"标签页
4. 勾选"启用语音合成"
5. 等待"正在上传参考音频..."
6. 看到"✓ 声音已准备好"
7. 调节音量
8. 关闭面板，开始使用

### 再次使用

1. 打开"AI 配置"
2. 切换到"声音设置"标签页
3. 调节设置（如果需要）
4. 关闭面板

## 代码示例

### 加载设置

```gdscript
func _load_voice_settings():
    var tts = get_node("/root/TTSService")
    
    voice_enable_checkbox.button_pressed = tts.is_enabled
    voice_volume_slider.value = tts.volume
    
    if tts.voice_uri.is_empty():
        voice_status_label.text = "⏳ 正在准备声音..."
    else:
        voice_status_label.text = "✓ 声音已准备好"
```

### 启用/禁用

```gdscript
func _on_voice_enable_toggled(enabled: bool):
    var tts = get_node("/root/TTSService")
    tts.set_enabled(enabled)
    
    if enabled:
        voice_status_label.text = "✓ 语音合成已启用"
    else:
        voice_status_label.text = "语音合成已禁用"
```

### 音量调节

```gdscript
func _on_voice_volume_changed(value: float):
    var tts = get_node("/root/TTSService")
    tts.set_volume(value)
    voice_volume_label.text = "%d%%" % int(value * 100)
```

## 优势

1. ✅ **统一入口**：所有AI配置在一个地方
2. ✅ **简洁界面**：侧边栏按钮更少
3. ✅ **逻辑清晰**：TTS作为AI功能的一部分
4. ✅ **易于发现**：用户配置AI时自然会看到声音设置
5. ✅ **一致体验**：与其他配置标签页风格一致

## 文档更新

已更新以下文档：
- `docs/TTS_QUICK_START.md` - 快速开始指南
- `docs/TTS_GUIDE.md` - 完整指南

需要更新的文档：
- `README.md` - 主文档
- `docs/TTS_IMPLEMENTATION_SUMMARY.md` - 实现总结

## 兼容性

- ✅ 不影响现有功能
- ✅ TTS服务保持不变
- ✅ 配置文件格式不变
- ✅ 向后兼容

## 测试建议

1. 打开"AI 配置"面板
2. 切换到"声音设置"标签页
3. 测试启用/禁用
4. 测试音量调节
5. 验证状态显示
6. 关闭并重新打开，验证设置保存

---

**更新日期**：2025-10-16  
**状态**：✅ 已完成  
**影响**：UI改进，功能不变
