# TTS调试指南

## 问题：发送了TTS请求但没有播放

### 调试步骤

#### 1. 检查控制台输出

启动游戏后，查看控制台输出，应该看到：

```
TTS配置加载成功
TTS设置加载成功: enabled=true, volume=0.80, api_key=已设置
API密钥已加载: sk-xxxxxxx...
加载缓存的声音URI: speech:character-voice:xxx:xxx
```

#### 2. 发送消息时的输出

当你发送消息并收到回复时，应该看到：

```
发送TTS: 你好！
=== 发送TTS请求 ===
URL: https://api.siliconflow.cn/v1/audio/speech
文本: 你好！
模型: FunAudioLLM/CosyVoice2-0.5B
Voice URI: speech:character-voice:xxx:xxx
API密钥: sk-xxxxxxx...
TTS请求已发送
```

#### 3. 接收响应时的输出

应该看到：

```
TTS请求完成 - result: 0, response_code: 200, body_size: xxxxx
响应头:
  content-type: audio/mpeg
  ...
接收到音频数据: xxxxx 字节
音频已加入队列，队列长度: 1
开始播放队列中的音频
准备播放音频，数据大小: xxxxx 字节
音频数据头: FF FB 90 ...
音频流创建成功，长度: x.xx 秒
设置音量: 0.80 (-1.94 dB)
开始播放语音，音频流长度: x.xx 秒
```

### 常见问题排查

#### 问题1：没有看到"TTS请求已发送"

**可能原因**：
- TTS未启用
- API密钥未配置
- voice_uri未准备好

**解决方法**：
1. 打开"声音设置"，确认已勾选"启用语音合成"
2. 检查是否显示"✓ 声音已准备好"
3. 如果显示"正在准备..."，等待上传完成

#### 问题2：看到"TTS请求已发送"但没有"TTS请求完成"

**可能原因**：
- 网络问题
- API服务器无响应
- 请求超时

**解决方法**：
1. 检查网络连接
2. 等待更长时间（首次请求可能较慢）
3. 查看是否有错误信息

#### 问题3：看到"TTS请求完成"但response_code不是200

**可能原因**：
- API密钥无效
- voice_uri无效
- API配额用尽

**解决方法**：
1. 检查API密钥是否正确
2. 删除 `user://voice_cache.json` 重新上传参考音频
3. 检查API账户余额

#### 问题4：response_code是200但body_size是0

**可能原因**：
- API返回了空响应
- 请求参数错误

**解决方法**：
1. 检查控制台的完整请求信息
2. 确认模型名称正确
3. 确认voice_uri格式正确

#### 问题5：接收到音频数据但"音频流创建失败"

**可能原因**：
- 音频格式不正确
- 音频数据损坏

**解决方法**：
1. 查看"音频数据头"输出
2. MP3格式应该以 `FF FB` 或 `FF FA` 开头
3. 如果不是，说明API返回的不是MP3数据

#### 问题6：音频流创建成功但没有声音

**可能原因**：
- 音量设置为0
- 音频设备问题
- AudioStreamPlayer配置问题

**解决方法**：
1. 检查音量设置（应该显示"设置音量: 0.80 (-1.94 dB)"）
2. 测试其他音频是否正常（如背景音乐）
3. 检查系统音量

### 手动测试API

你可以使用curl命令手动测试API：

```bash
# 测试语音合成
curl -X POST https://api.siliconflow.cn/v1/audio/speech \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "FunAudioLLM/CosyVoice2-0.5B",
    "input": "你好，这是测试",
    "voice": "YOUR_VOICE_URI"
  }' \
  --output test.mp3
```

如果成功，会生成 `test.mp3` 文件，可以播放验证。

### 检查配置文件

#### 检查 `user://ai_keys.json`

应该包含：

```json
{
  "mode": "simple",
  "api_key": "sk-xxxxxxxxxxxxxxxx"
}
```

或者（详细模式）：

```json
{
  "mode": "detailed",
  "chat_model": {
    "api_key": "sk-xxxxxxxxxxxxxxxx"
  },
  "tts_model": {
    "model": "FunAudioLLM/CosyVoice2-0.5B",
    "base_url": "https://api.siliconflow.cn",
    "api_key": "sk-xxxxxxxxxxxxxxxx"
  }
}
```

#### 检查 `user://tts_settings.json`

应该包含：

```json
{
  "api_key": "sk-xxxxxxxxxxxxxxxx",
  "enabled": true,
  "volume": 0.8
}
```

#### 检查 `user://voice_cache.json`

应该包含：

```json
{
  "voice_uri": "speech:character-voice:xxx:xxx"
}
```

### 强制重新初始化

如果一切都配置正确但仍然不工作，尝试：

1. 关闭游戏
2. 删除以下文件：
   - `user://voice_cache.json`
   - `user://tts_settings.json`
3. 重新启动游戏
4. 重新配置TTS

### 获取详细日志

在 `scripts/tts_service.gd` 中，所有关键步骤都有日志输出。

查看完整的控制台输出，从游戏启动到发送消息的全过程。

### 常见错误信息

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| "TTS API密钥未配置" | API密钥为空 | 配置API密钥 |
| "声音URI未准备好" | voice_uri为空 | 等待上传完成或重新上传 |
| "TTS请求失败: X" | 网络错误 | 检查网络连接 |
| "TTS错误 (401)" | API密钥无效 | 检查API密钥 |
| "TTS错误 (429)" | API配额用尽 | 充值或等待配额恢复 |
| "音频数据为空" | API返回空数据 | 检查请求参数 |
| "音频流无效" | 音频格式错误 | 检查API返回的数据格式 |

### 联系支持

如果以上方法都无法解决问题，请提供：

1. 完整的控制台输出（从启动到出错）
2. 配置文件内容（隐藏API密钥）
3. 操作步骤
4. 错误截图

---

**提示**：大部分问题都是由于API密钥未正确配置或网络问题导致的。请先确认这两点。
