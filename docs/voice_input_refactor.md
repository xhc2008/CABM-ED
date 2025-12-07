# 语音输入模块重构说明

## 改动概述

### 1. 模块化拆分
将语音输入功能从 `chat_dialog.gd` 拆分为独立模块 `chat_dialog_voice_input.gd`

**优点：**
- 代码结构更清晰，职责分离
- 便于维护和测试
- 减少主对话框文件的复杂度

### 2. 历史记录时隐藏语音按钮
在打开历史记录面板时自动隐藏语音输入按钮，返回输入模式时恢复显示

**实现位置：**
- `scripts/chat_dialog_history.gd` 的 `show_history()` 和 `hide_history()` 方法

### 3. 设备兼容性改进
解决 Windows WASAPI 不支持的通道数问题

**解决方案：**
- 在录音后进行音频格式转换，而不是要求用户修改设备配置
- 自动将立体声转换为单声道
- 自动重采样到 16kHz（STT 标准格式）
- 检测设备可用性，不可用时禁用按钮

**关键改进：**
```gdscript
# 旧方案：要求用户修改设备配置
if OS.get_name() == "Windows":
    print("请在 Windows 录音设备的高级选项将默认格式设置为单声道")
    return

# 新方案：自动适配设备
# 1. 检测设备兼容性
func _check_device_compatibility():
    var devices = AudioServer.get_input_device_list()
    if devices.size() == 0:
        is_voice_available = false
        return
    is_voice_available = true

# 2. 录音后自动转换格式
func _frames_to_wav_bytes(frames, sample_rate):
    # 混合左右声道为单声道
    mono_samples[i] = (f.x + f.y) * 0.5
    # 重采样到 16kHz
    # 转换为 16位 PCM
```

## 文件变更

### 新增文件
- `scripts/chat_dialog_voice_input.gd` - 语音输入模块

### 修改文件
- `scripts/chat_dialog.gd` - 移除语音输入代码，集成新模块
- `scripts/chat_dialog_history.gd` - 添加语音按钮显示/隐藏逻辑

## 使用说明

### 语音输入模块 API

```gdscript
# 初始化
voice_input.setup(dialog, mic_button, input_field)

# 检查可用性
if voice_input.is_available():
    voice_input.start_recording()

# 控制可见性
voice_input.set_visible(true/false)

# 信号
voice_input.recording_started.connect(...)
voice_input.recording_stopped.connect(...)
voice_input.transcription_received.connect(...)
voice_input.transcription_error.connect(...)
```

## 测试要点

1. **设备兼容性**
   - 测试无麦克风设备时的行为
   - 测试单声道/立体声设备
   - 测试不同采样率的设备

2. **UI 交互**
   - 打开历史记录时语音按钮应隐藏
   - 关闭历史记录时语音按钮应显示
   - 录音时按钮应显示波形动画

3. **功能测试**
   - 录音功能正常
   - STT 转换正常
   - 转换结果正确插入输入框

## 已知问题

- Windows WASAPI 通道数警告已通过格式转换解决
- 设备检测在某些平台可能需要进一步优化

## 后续优化建议

1. 添加录音音量阈值检测（避免录制空白音频）
2. 支持更多音频格式和采样率
3. 添加录音时长限制和提示
4. 优化音频重采样算法（当前使用线性插值）
