# TTS功能更新日志

## 新增功能

### 1. TTS服务 (`scripts/tts_service.gd`)

- ✅ 自动加载单例，全局可用
- ✅ 参考音频上传和缓存管理
- ✅ 实时语音合成
- ✅ 音频播放队列管理
- ✅ 中文标点检测
- ✅ 配置持久化

**主要方法**：
- `upload_reference_audio()` - 上传参考音频
- `synthesize_speech(text)` - 合成语音
- `set_enabled(enabled)` - 启用/禁用TTS
- `set_volume(volume)` - 设置音量
- `clear_queue()` - 清空播放队列

**信号**：
- `voice_ready(voice_uri)` - 声音准备完成
- `audio_chunk_ready(audio_data)` - 音频块准备完成
- `tts_error(error_message)` - TTS错误

### 2. 声音设置面板

**文件**：
- `scenes/voice_settings_panel.tscn` - 场景文件
- `scripts/voice_settings_panel.gd` - 脚本文件

**功能**：
- 启用/禁用语音合成
- 音量调节（0-100%）
- 实时状态显示
- 配置验证

### 3. 侧边栏集成 (`scripts/sidebar.gd`)

**新增**：
- "声音设置"按钮
- `_on_voice_settings_pressed()` 方法

### 4. AI配置面板扩展 (`scripts/ai_config_panel.gd`)

**新增**：
- TTS模型配置区域（详细配置标签页）
- TTS配置加载和保存
- `_reload_tts_service()` 方法

**配置字段**：
- 模型名称
- Base URL
- API 密钥

### 5. 聊天对话集成 (`scripts/chat_dialog.gd`)

**新增**：
- TTS文本缓冲 (`tts_buffer`)
- `_process_tts_chunk(text)` - 处理TTS文本块
- `_send_tts(text)` - 发送TTS请求
- 对话结束时清空TTS队列

**工作流程**：
```
接收AI响应 → 添加到TTS缓冲 → 检测标点 → 提取句子 → 发送TTS → 播放
```

### 6. 配置文件更新

**`config/ai_config.json`**：
```json
{
  "tts_model": {
    "model": "FunAudioLLM/CosyVoice2-0.5B",
    "base_url": "https://api.siliconflow.cn"
  }
}
```

**`project.godot`**：
```
TTSService="*res://scripts/tts_service.gd"
```

### 7. 文档

- `docs/TTS_GUIDE.md` - 完整使用指南
- `docs/TTS_QUICK_START.md` - 快速开始指南
- `docs/CHANGELOG_TTS.md` - 更新日志（本文件）

## 技术实现

### 参考音频上传

使用 `multipart/form-data` 格式上传：
- 音频文件：`assets/audio/ref.wav`
- 参考文本：`assets/audio/ref.txt`
- 自定义名称：`character-voice`

### 语音合成

使用流式处理：
1. 接收LLM响应的文本块
2. 检测中文标点（。！？；…）
3. 提取完整句子
4. 发送TTS请求
5. 接收音频数据
6. 加入播放队列
7. 按顺序播放

### 缓存机制

- **声音URI缓存**：`user://voice_cache.json`
  - 避免重复上传参考音频
  - 游戏启动时检查缓存
  
- **TTS设置缓存**：`user://tts_settings.json`
  - 保存启用状态
  - 保存音量设置
  - 保存API密钥

### 播放队列

使用数组管理音频队列：
```gdscript
var audio_queue: Array = []
var is_playing: bool = false
```

播放逻辑：
1. 音频数据加入队列
2. 如果没有正在播放，开始播放
3. 播放完成后，播放下一个
4. 队列为空时停止

## API集成

### SiliconFlow API

**上传参考音频**：
```
POST /v1/uploads/audio/voice
```

**语音合成**：
```
POST /v1/audio/speech
```

**模型**：
- `FunAudioLLM/CosyVoice2-0.5B`

## 文件清单

### 新增文件

```
scripts/tts_service.gd                 # TTS服务核心
scripts/voice_settings_panel.gd        # 声音设置面板脚本
scenes/voice_settings_panel.tscn       # 声音设置面板场景
docs/TTS_GUIDE.md                      # 完整指南
docs/TTS_QUICK_START.md                # 快速开始
docs/CHANGELOG_TTS.md                  # 更新日志
```

### 修改文件

```
scripts/sidebar.gd                     # 添加声音设置按钮
scripts/ai_config_panel.gd             # 添加TTS配置
scripts/chat_dialog.gd                 # 集成TTS功能
scenes/ai_config_panel.tscn            # 添加TTS配置UI
config/ai_config.json                  # 添加TTS模型配置
project.godot                          # 注册TTSService自动加载
```

### 依赖文件（已存在）

```
assets/audio/ref.wav                   # 参考音频
assets/audio/ref.txt                   # 参考文本
```

## 配置示例

### 简单模式（推荐）

```json
{
  "mode": "simple",
  "api_key": "sk-xxxxxxxxxxxxxxxx"
}
```

TTS自动使用相同的API密钥。

### 详细模式

```json
{
  "mode": "detailed",
  "chat_model": { ... },
  "summary_model": { ... },
  "tts_model": {
    "model": "FunAudioLLM/CosyVoice2-0.5B",
    "base_url": "https://api.siliconflow.cn",
    "api_key": "sk-xxxxxxxxxxxxxxxx"
  }
}
```

## 使用流程

```
游戏启动
  ↓
加载TTS配置
  ↓
检查voice_uri缓存
  ↓
如果没有缓存 → 上传参考音频 → 获取voice_uri → 保存缓存
  ↓
用户启用TTS
  ↓
开始对话
  ↓
接收AI响应 → 检测标点 → 合成语音 → 播放
```

## 性能考虑

- ✅ 异步处理，不阻塞主线程
- ✅ 队列管理，避免并发问题
- ✅ 缓存机制，减少API调用
- ✅ 独立于文字输出，互不影响

## 兼容性

- ✅ Godot 4.5+
- ✅ Windows / Linux / macOS
- ✅ Android / iOS（需要网络权限）
- ✅ 支持所有场景和对话模式

## 已知限制

1. **网络依赖**：需要稳定的网络连接
2. **API费用**：每次合成都会消耗API额度
3. **延迟**：首次合成可能有1-2秒延迟
4. **音频格式**：仅支持MP3格式输出
5. **并发限制**：同时只能播放一段语音

## 未来计划

- [ ] 支持多种音色
- [ ] 支持语速调节
- [ ] 音频缓存（减少API调用）
- [ ] 离线TTS支持
- [ ] 更多音频格式
- [ ] 实时音量调节
- [ ] 播放进度显示

## 测试建议

1. **基础测试**：
   - 启用TTS
   - 发送简单消息
   - 验证语音播放

2. **边界测试**：
   - 长文本（多个句子）
   - 快速连续发送
   - 中途关闭对话

3. **错误测试**：
   - 无效API密钥
   - 网络断开
   - 参考音频缺失

4. **性能测试**：
   - 长时间对话
   - 频繁切换启用/禁用
   - 音量调节响应

## 贡献者

- 实现：Kiro AI Assistant
- 日期：2025-10-16

---

如有问题或建议，请查看 [TTS_GUIDE.md](TTS_GUIDE.md) 或提交 Issue。
