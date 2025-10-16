# TTS初始化和错误处理修复

## 修复的问题

### 问题1：初始设置后TTS未加载

**现象**：
- 在初始设置页面填写API密钥
- 进入游戏后，声音设置显示"⚠ 请先配置API密钥"
- 需要手动打开AI配置并点击"保存配置"才能生效

**原因**：
`initial_setup.gd` 的 `_save_api_key()` 函数只重新加载了AI服务，没有重新加载TTS服务。

**修复**：
```gdscript
# 修复前
if has_node("/root/AIService"):
    var ai_service = get_node("/root/AIService")
    ai_service._load_api_key()
    print("AI服务已重新加载配置")

# 修复后
if has_node("/root/AIService"):
    var ai_service = get_node("/root/AIService")
    ai_service._load_api_key()
    print("AI服务已重新加载配置")

# 新增：重新加载TTS服务
if has_node("/root/TTSService"):
    var tts_service = get_node("/root/TTSService")
    tts_service._load_tts_settings()
    print("TTS服务已重新加载配置")
```

### 问题2：一直显示"正在准备声音..."

**现象**：
- 启用TTS后，状态一直显示"⏳ 正在准备声音..."
- 实际上参考音频上传可能已经失败
- 用户不知道发生了什么错误

**原因**：
1. 上传失败时没有足够的错误信息
2. AI配置面板没有监听TTS错误信号
3. 用户看不到错误提示

**修复**：

#### 1. 增强TTS服务的错误日志

```gdscript
func _on_upload_completed(...):
    print("=== 参考音频上传完成 ===")
    print("result: %d, response_code: %d, body_size: %d" % [result, response_code, body.size()])
    
    if result != HTTPRequest.RESULT_SUCCESS:
        var error_msg = "上传失败: " + str(result)
        push_error(error_msg)
        tts_error.emit(error_msg)
        return
    
    if response_code != 200:
        var error_text = body.get_string_from_utf8()
        var error_msg = "上传错误 (%d): %s" % [response_code, error_text]
        push_error(error_msg)
        print("错误详情: ", error_text)
        tts_error.emit(error_msg)
        return
    
    # ... 更多错误处理
```

#### 2. AI配置面板监听错误信号

```gdscript
func _load_voice_settings():
    var tts = get_node("/root/TTSService")
    
    # 连接信号（如果还没连接）
    if not tts.voice_ready.is_connected(_on_voice_ready):
        tts.voice_ready.connect(_on_voice_ready)
    if not tts.tts_error.is_connected(_on_tts_error):
        tts.tts_error.connect(_on_tts_error)
    
    # ... 其他逻辑

func _on_tts_error(error_message: String):
    """TTS错误"""
    voice_status_label.text = "✗ " + error_message
    voice_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    push_error("TTS错误: " + error_message)
```

## 工作流程

### 修复前 ❌

```
初始设置：
1. 用户填写API密钥
2. 保存到 user://ai_keys.json
3. 重新加载AI服务 ✅
4. TTS服务未重新加载 ❌

进入游戏：
1. 打开AI配置 → 声音设置
2. 显示"⚠ 请先配置API密钥" ❌
3. 用户困惑：明明已经配置了

上传失败：
1. 参考音频上传失败
2. 状态一直显示"⏳ 正在准备声音..." ❌
3. 用户不知道发生了什么
```

### 修复后 ✅

```
初始设置：
1. 用户填写API密钥
2. 保存到 user://ai_keys.json
3. 重新加载AI服务 ✅
4. 重新加载TTS服务 ✅

进入游戏：
1. 打开AI配置 → 声音设置
2. 显示"⏳ 正在准备声音..." ✅
3. 或显示"✓ TTS已就绪" ✅

上传失败：
1. 参考音频上传失败
2. 显示"✗ 上传错误 (401): Unauthorized" ✅
3. 用户知道是API密钥问题
```

## 可能的错误信息

### API密钥问题

```
✗ 上传错误 (401): Unauthorized
```

**原因**：API密钥无效或过期  
**解决**：检查API密钥是否正确

### 网络问题

```
✗ 上传失败: 7
```

**原因**：网络连接失败  
**解决**：检查网络连接

### 文件问题

```
✗ 参考音频文件不存在: res://assets/audio/ref.wav
```

**原因**：参考音频文件缺失  
**解决**：确保文件存在

### 响应格式问题

```
✗ 响应中没有URI字段，响应内容: {...}
```

**原因**：API响应格式不符合预期  
**解决**：检查API版本或联系支持

## 调试日志

### 成功上传

```
上传参考音频...
=== 参考音频上传完成 ===
result: 0, response_code: 200, body_size: 156
上传响应: {"uri":"speech:character-voice:xxx:xxx"}
✓ 声音URI获取成功: speech:character-voice:xxx:xxx
声音URI已缓存
```

### 失败上传（401错误）

```
上传参考音频...
=== 参考音频上传完成 ===
result: 0, response_code: 401, body_size: 45
错误详情: {"error":"Unauthorized"}
上传错误 (401): {"error":"Unauthorized"}
```

### 失败上传（网络错误）

```
上传参考音频...
=== 参考音频上传完成 ===
result: 7, response_code: 0, body_size: 0
上传失败: 7
```

## 测试步骤

### 测试1：正常流程

1. 删除所有配置文件
2. 启动游戏，进入初始设置
3. 填写有效的API密钥
4. 点击"开始游戏"
5. 打开"AI 配置" → "声音设置"
6. 验证状态显示

**预期结果**：
- 显示"⏳ 正在准备声音..."
- 几秒后显示"✓ TTS已就绪"

### 测试2：无效API密钥

1. 删除所有配置文件
2. 启动游戏，进入初始设置
3. 填写无效的API密钥（例如："invalid-key"）
4. 点击"开始游戏"
5. 打开"AI 配置" → "声音设置"
6. 勾选"启用语音合成"

**预期结果**：
- 显示"⏳ 正在上传参考音频..."
- 几秒后显示"✗ 上传错误 (401): Unauthorized"

### 测试3：网络断开

1. 配置有效的API密钥
2. 断开网络连接
3. 打开"AI 配置" → "声音设置"
4. 勾选"启用语音合成"

**预期结果**：
- 显示"⏳ 正在上传参考音频..."
- 几秒后显示"✗ 上传失败: 7"

## 状态显示总结

| 状态 | 显示文本 | 颜色 | 说明 |
|------|---------|------|------|
| 未配置 | ⚠ 请先配置API密钥 | 橙色 | API密钥为空 |
| 准备中 | ⏳ 正在准备声音... | 蓝色 | 正在加载缓存或上传 |
| 上传中 | ⏳ 正在上传参考音频... | 蓝色 | 正在上传参考音频 |
| 已就绪 | ✓ TTS已就绪 | 绿色 | 可以使用 |
| 已启用 | ✓ TTS已启用 | 绿色 | 已启用并就绪 |
| 已禁用 | TTS已禁用 | 灰色 | 用户禁用 |
| 错误 | ✗ [错误信息] | 红色 | 发生错误 |

## 相关文件

- `scripts/initial_setup.gd` - 初始设置（修复）
- `scripts/tts_service.gd` - TTS服务（增强错误处理）
- `scripts/ai_config_panel.gd` - AI配置面板（监听错误）

## 相关信号

### TTSService信号

```gdscript
signal voice_ready(voice_uri: String)  # 声音准备完成
signal tts_error(error_message: String)  # TTS错误
signal audio_chunk_ready(audio_data: PackedByteArray)  # 音频块准备完成
```

### 连接示例

```gdscript
var tts = get_node("/root/TTSService")
tts.voice_ready.connect(_on_voice_ready)
tts.tts_error.connect(_on_tts_error)
```

## 建议

### 对于用户

1. 确保API密钥正确
2. 确保网络连接正常
3. 如果看到错误，根据提示检查问题
4. 可以在控制台查看详细日志

### 对于开发者

1. 始终监听 `tts_error` 信号
2. 提供清晰的错误提示
3. 记录详细的调试日志
4. 处理所有可能的错误情况

---

**修复日期**：2025-10-16  
**状态**：✅ 已修复  
**影响**：初始设置和错误提示
