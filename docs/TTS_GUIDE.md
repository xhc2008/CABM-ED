# TTS语音合成功能使用指南

## 功能概述

本项目集成了基于SiliconFlow API的TTS（文本转语音）功能，可以为角色对话添加语音播放。

## 功能特性

1. **参考音频上传**：游戏启动时自动上传参考音频，获取声音URI并缓存
2. **实时语音合成**：在接收LLM响应时，检测到中文标点就立即合成语音
3. **顺序播放**：多段语音按照顺序播放，不会混乱
4. **独立控制**：可以在声音设置中启用/禁用和调节音量
5. **配置管理**：TTS模型配置保存在AI配置中

## 配置步骤

### 1. 准备参考音频

参考音频文件位于 `assets/audio/`：
- `ref.wav`：参考音频文件（WAV格式）
- `ref.txt`：参考文本（与音频内容对应）

**注意**：参考音频的质量和特征会影响合成语音的效果。

### 2. 配置API密钥

有两种配置方式：

#### 方式一：快速配置（推荐）
1. 点击左侧边栏的"AI 配置"按钮
2. 在"快速配置"标签页输入SiliconFlow API密钥
3. 点击"保存配置"

TTS会自动使用相同的API密钥。

#### 方式二：详细配置
1. 点击左侧边栏的"AI 配置"按钮
2. 切换到"详细配置"标签页
3. 在"TTS模型配置"部分填写：
   - 模型名称：`FunAudioLLM/CosyVoice2-0.5B`
   - Base URL：`https://api.siliconflow.cn`
   - API 密钥：你的SiliconFlow API密钥
4. 点击"保存详细配置"

### 3. 启用语音合成

1. 点击左侧边栏的"AI 配置"按钮
2. 切换到"声音设置"标签页
3. 勾选"启用语音合成"
4. 调节音量滑块（0-100%）
5. 等待"声音已准备好"提示

## 工作原理

### 参考音频上传流程

```
游戏启动 → 检查缓存 → 如果没有缓存 → 上传ref.wav和ref.txt → 获取voice_uri → 保存到缓存
```

缓存文件位于：`user://voice_cache.json`

### 语音合成流程

```
接收LLM响应 → 检测中文标点（。！？；…）→ 提取句子 → 发送TTS请求 → 获取音频 → 加入播放队列 → 按顺序播放
```

### 中文标点检测

系统会检测以下中文标点符号：
- `。` 句号
- `！` 感叹号
- `？` 问号
- `；` 分号
- `…` 省略号

一旦检测到标点，就会将该句子发送给TTS进行合成。

## 配置文件说明

### AI配置文件 (`config/ai_config.json`)

```json
{
  "tts_model": {
    "model": "FunAudioLLM/CosyVoice2-0.5B",
    "base_url": "https://api.siliconflow.cn"
  }
}
```

### TTS设置文件 (`user://tts_settings.json`)

```json
{
  "api_key": "sk-...",
  "enabled": true,
  "volume": 0.8
}
```

### 声音缓存文件 (`user://voice_cache.json`)

```json
{
  "voice_uri": "speech:character-voice:xxx:xxx"
}
```

## API说明

### 上传参考音频

```
POST https://api.siliconflow.cn/v1/uploads/audio/voice
Content-Type: multipart/form-data

- model: FunAudioLLM/CosyVoice2-0.5B
- customName: character-voice
- text: 参考文本内容
- file: ref.wav文件
```

响应：
```json
{
  "uri": "speech:character-voice:xxx:xxx"
}
```

### 语音合成

```
POST https://api.siliconflow.cn/v1/audio/speech
Content-Type: application/json

{
  "model": "FunAudioLLM/CosyVoice2-0.5B",
  "input": "要合成的文本",
  "voice": "speech:character-voice:xxx:xxx"
}
```

响应：音频文件（MP3格式）

## 故障排除

### 问题：声音一直显示"正在准备..."

**可能原因**：
1. API密钥未配置或无效
2. 参考音频文件不存在
3. 网络连接问题

**解决方法**：
1. 检查AI配置中的API密钥是否正确
2. 确认 `assets/audio/ref.wav` 和 `ref.txt` 文件存在
3. 查看控制台输出的错误信息

### 问题：没有语音播放

**可能原因**：
1. 语音合成未启用
2. 音量设置为0
3. voice_uri未准备好

**解决方法**：
1. 在声音设置中勾选"启用语音合成"
2. 调高音量滑块
3. 等待"声音已准备好"提示

### 问题：语音播放不流畅

**可能原因**：
1. 网络延迟
2. API响应慢

**解决方法**：
- 这是正常现象，系统会按顺序播放所有语音
- 文字输出和语音播放是独立的，不会相互阻塞

## 技术细节

### 自动加载单例

`TTSService` 作为自动加载单例，在 `project.godot` 中配置：

```
TTSService="*res://scripts/tts_service.gd"
```

### 信号系统

TTSService提供以下信号：
- `voice_ready(voice_uri: String)`：声音URI准备完成
- `audio_chunk_ready(audio_data: PackedByteArray)`：音频块准备完成
- `tts_error(error_message: String)`：TTS错误

### 播放队列

系统使用队列管理多段语音：
```gdscript
var audio_queue: Array = []  # 存储待播放的音频数据
var is_playing: bool = false  # 是否正在播放
```

播放完一段后自动播放下一段，确保顺序正确。

## 注意事项

1. **API费用**：TTS服务会消耗API额度，请注意使用量
2. **音频格式**：参考音频必须是WAV格式
3. **文本匹配**：参考文本应与音频内容完全匹配
4. **缓存管理**：voice_uri会被缓存，删除缓存文件会重新上传
5. **并发限制**：同时只能播放一段语音，其他会排队等待

## 未来改进

- [ ] 支持多种音色选择
- [ ] 支持语速调节
- [ ] 支持音频缓存（减少API调用）
- [ ] 支持离线TTS模型
- [ ] 支持更多音频格式
