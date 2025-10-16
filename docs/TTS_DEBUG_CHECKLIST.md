# TTS调试检查清单

## 问题：一直显示"正在准备声音..."

### 步骤1：检查控制台输出

启动游戏后，查看控制台，应该看到以下日志：

#### 预期的正常日志

```
TTS配置加载成功
TTS设置加载成功: enabled=false, volume=0.80, api_key=未设置
从AI配置(简单模式)加载TTS密钥
API密钥已加载: sk-xxxxxxx...
=== TTS设置加载完成 ===
API密钥: 已配置
启用状态: false
音量: 0.80
加载缓存的声音URI: speech:character-voice:xxx:xxx
```

或者（如果没有缓存）：

```
TTS配置加载成功
TTS设置加载成功: enabled=false, volume=0.80, api_key=未设置
从AI配置(简单模式)加载TTS密钥
API密钥已加载: sk-xxxxxxx...
=== TTS设置加载完成 ===
API密钥: 已配置
启用状态: false
音量: 0.80
```

### 步骤2：启用TTS后的日志

当你勾选"启用语音合成"后，应该看到：

#### 如果有缓存

```
✓ TTS已启用
```

#### 如果没有缓存

```
=== 开始上传参考音频 ===
上传参考音频...
=== 参考音频上传完成 ===
result: 0, response_code: 200, body_size: 156
上传响应: {"uri":"speech:character-voice:xxx:xxx"}
✓ 声音URI获取成功: speech:character-voice:xxx:xxx
声音URI已缓存
```

### 步骤3：常见错误及解决方案

#### 错误1：API密钥未配置

**日志**：
```
=== TTS设置加载完成 ===
API密钥: 未配置
启用状态: false
音量: 0.80

=== 开始上传参考音频 ===
TTS API密钥未配置
```

**原因**：
- 初始设置时没有填写API密钥
- 或者API密钥保存失败
- 或者TTS服务没有重新加载

**解决方法**：
1. 打开"AI 配置" → "快速配置"
2. 输入API密钥
3. 点击"保存配置"
4. 切换到"声音设置"标签页
5. 勾选"启用语音合成"

#### 错误2：API密钥无效

**日志**：
```
=== 开始上传参考音频 ===
上传参考音频...
=== 参考音频上传完成 ===
result: 0, response_code: 401, body_size: 45
错误详情: {"error":"Unauthorized"}
上传错误 (401): {"error":"Unauthorized"}
```

**原因**：API密钥无效或过期

**解决方法**：
1. 检查API密钥是否正确
2. 登录SiliconFlow账户验证密钥
3. 如果过期，生成新的密钥

#### 错误3：网络连接失败

**日志**：
```
=== 开始上传参考音频 ===
上传参考音频...
=== 参考音频上传完成 ===
result: 7, response_code: 0, body_size: 0
上传失败: 7
```

**原因**：网络连接问题

**解决方法**：
1. 检查网络连接
2. 检查防火墙设置
3. 尝试使用VPN（如果在中国大陆）

#### 错误4：参考音频文件缺失

**日志**：
```
=== 开始上传参考音频 ===
参考音频文件不存在: res://assets/audio/ref.wav
```

**原因**：参考音频文件缺失

**解决方法**：
1. 确认 `assets/audio/ref.wav` 文件存在
2. 确认 `assets/audio/ref.txt` 文件存在
3. 重新下载项目文件

#### 错误5：API响应格式错误

**日志**：
```
=== 参考音频上传完成 ===
result: 0, response_code: 200, body_size: 89
上传响应: {"error":"Invalid model"}
响应中没有URI字段，响应内容: {"error":"Invalid model"}
```

**原因**：API响应不包含URI字段

**解决方法**：
1. 检查 `config/ai_config.json` 中的 `tts_model.model` 是否正确
2. 确认使用的是 `FunAudioLLM/CosyVoice2-0.5B`

### 步骤4：手动测试API

如果仍然有问题，可以手动测试API：

```bash
curl -X POST https://api.siliconflow.cn/v1/uploads/audio/voice \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "model=FunAudioLLM/CosyVoice2-0.5B" \
  -F "customName=test-voice" \
  -F "text=测试文本" \
  -F "file=@assets/audio/ref.wav"
```

**预期响应**：
```json
{
  "uri": "speech:test-voice:xxx:xxx"
}
```

### 步骤5：检查配置文件

#### 检查 `user://ai_keys.json`

位置（Windows）：`%APPDATA%\Godot\app_userdata\CABM-ED\ai_keys.json`

应该包含：
```json
{
  "mode": "simple",
  "api_key": "sk-xxxxxxxxxxxxxxxx"
}
```

#### 检查 `user://tts_settings.json`

位置（Windows）：`%APPDATA%\Godot\app_userdata\CABM-ED\tts_settings.json`

应该包含：
```json
{
  "api_key": "",
  "enabled": true,
  "volume": 0.8
}
```

注意：`api_key` 可以为空，TTS会从 `ai_keys.json` 加载。

#### 检查 `user://voice_cache.json`

位置（Windows）：`%APPDATA%\Godot\app_userdata\CABM-ED\voice_cache.json`

如果存在，应该包含：
```json
{
  "voice_uri": "speech:character-voice:xxx:xxx"
}
```

### 步骤6：强制重新初始化

如果一切都配置正确但仍然不工作，尝试强制重新初始化：

1. 关闭游戏
2. 删除以下文件：
   - `user://voice_cache.json`
   - `user://tts_settings.json`
3. 重新启动游戏
4. 打开"AI 配置" → "声音设置"
5. 勾选"启用语音合成"
6. 观察控制台输出

### 步骤7：查看完整的启动日志

从游戏启动到启用TTS的完整日志应该是：

```
# 游戏启动
TTS配置加载成功
TTS设置加载成功: enabled=false, volume=0.80, api_key=未设置
从AI配置(简单模式)加载TTS密钥
API密钥已加载: sk-xxxxxxx...
=== TTS设置加载完成 ===
API密钥: 已配置
启用状态: false
音量: 0.80

# 打开AI配置面板
# （无特殊日志）

# 切换到声音设置标签页
# （无特殊日志）

# 勾选"启用语音合成"
=== 开始上传参考音频 ===
上传参考音频...

# 等待几秒...

=== 参考音频上传完成 ===
result: 0, response_code: 200, body_size: 156
上传响应: {"uri":"speech:character-voice:xxx:xxx"}
✓ 声音URI获取成功: speech:character-voice:xxx:xxx
声音URI已缓存

# UI显示："✓ TTS已就绪"
```

## 快速诊断表

| 症状 | 可能原因 | 检查项 |
|------|---------|--------|
| 显示"⚠ 请先配置API密钥" | API密钥未加载 | 检查 `ai_keys.json` |
| 显示"⏳ 正在准备声音..." | 正在上传或卡住 | 查看控制台日志 |
| 显示"✗ TTS API密钥未配置" | 密钥为空 | 重新保存配置 |
| 显示"✗ 上传错误 (401)" | 密钥无效 | 检查密钥是否正确 |
| 显示"✗ 上传失败: 7" | 网络问题 | 检查网络连接 |
| 显示"✗ 参考音频文件不存在" | 文件缺失 | 检查文件是否存在 |

## 常见问题

### Q: 为什么初始设置后还是显示"请先配置API密钥"？

A: 可能是TTS服务没有重新加载。解决方法：
1. 打开"AI 配置" → "快速配置"
2. 点击"保存配置"（即使密钥已经填写）
3. 这会触发TTS服务重新加载

### Q: 为什么一直显示"正在准备声音..."？

A: 可能的原因：
1. API密钥实际上是空的（检查日志）
2. 上传请求失败但没有显示错误（检查日志）
3. 网络问题导致请求超时（检查网络）

### Q: 如何查看详细的错误信息？

A: 查看控制台输出，所有错误都会打印到控制台。

### Q: 可以跳过参考音频上传吗？

A: 不可以，参考音频是必需的。但是上传一次后会缓存，下次不需要重新上传。

## 获取帮助

如果以上方法都无法解决问题，请提供：

1. 完整的控制台输出（从启动到出错）
2. `user://ai_keys.json` 的内容（隐藏API密钥）
3. `user://tts_settings.json` 的内容
4. 操作步骤
5. 错误截图

---

**更新日期**：2025-10-16  
**版本**：v1.1
