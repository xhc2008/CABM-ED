# BGM系统问题修复

## 问题描述
升级后默认音乐和之前的自定义音乐都消失了。

## 原因分析
1. 新的BGM配置格式使用 `bgm_config` 字段，而不是旧的 `last_custom_bgm`
2. 升级后 `bgm_config["all"]["enabled_music"]` 列表为空
3. 音乐文件本身还在，但没有被添加到新的配置中

## 修复方案

### 1. 自动初始化默认音乐列表
在 `music_player_panel.gd` 中添加了 `_init_default_music_list()` 函数：
- 检查"全部"场景的音乐列表是否为空
- 如果为空，自动将所有扫描到的音乐文件添加到列表中
- 这样升级后所有音乐都会自动出现在"全部"场景中

### 2. 恢复播放列表
在 `audio_manager.gd` 中修改了启动逻辑：
- 不再使用旧的 `last_custom_bgm` 单曲恢复
- 改为从 `SaveManager` 获取 `bgm_config`
- 自动播放"全部"场景的音乐列表
- 使用保存的播放模式

### 3. 文件验证
恢复播放列表时会验证文件是否存在：
- 跳过不存在的文件
- 只播放有效的音乐文件
- 避免因文件丢失导致的错误

## 使用说明

### 首次升级后
1. 打开音乐播放器
2. 所有音乐（内置+自定义）会自动出现在"全部"场景中
3. 默认使用"顺序播放"模式
4. 点击任意音乐开始播放

### 如果音乐仍然不显示
1. 检查 `user://custom_bgm/` 目录是否存在自定义音乐文件
2. 检查 `res://assets/audio/BGM/` 目录是否有内置音乐
3. 查看控制台日志，确认音乐文件是否被扫描到

### 手动添加音乐
如果自动初始化失败，可以：
1. 点击"上传音乐"重新上传
2. 或在"全部"场景中点击"编辑"，手动勾选音乐

## 技术细节

### 配置迁移
旧格式：
```json
{
  "last_custom_bgm": "user://custom_bgm/music.mp3"
}
```

新格式：
```json
{
  "bgm_config": {
    "all": {
      "enabled_music": [
        "res://assets/audio/BGM/music1.mp3",
        "user://custom_bgm/music2.mp3"
      ],
      "play_mode": 1
    }
  }
}
```

### 初始化时机
- `music_player_panel._ready()` → `_load_music_list()` → `_init_default_music_list()`
- 在扫描完所有音乐文件后立即检查并初始化
- 只在"全部"场景的列表为空时执行

### 恢复播放时机
- `audio_manager._ready()` → `_load_audio_config()` → `_restore_bgm_playlist()`
- 延迟0.5秒等待SaveManager加载完成
- 验证文件存在性后开始播放

## 测试检查清单
- [ ] 升级后打开音乐播放器，所有音乐都显示在"全部"场景
- [ ] 点击音乐可以正常播放
- [ ] 播放模式切换正常
- [ ] 重启游戏后自动恢复播放列表
- [ ] 上传新音乐后正常显示
- [ ] 编辑模式勾选/取消勾选正常工作
