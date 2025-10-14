# 离线时间系统修复日志

## 问题描述

初始实现时出现了负数离线时长的问题：
```
离线时长: -479.99 分钟 (-8.00 小时)
```

## 问题原因

1. **时间戳更新时机错误**：在 `load_game` 中，系统在调用离线检查**之前**就更新了 `last_played_at`，导致计算时使用的是新时间而不是旧时间。

2. **时间解析问题**：`Time.get_datetime_string_from_system()` 返回的是本地时间字符串，但 `Time.get_unix_time_from_datetime_dict()` 使用的是 UTC 时间，导致时区转换错误。

## 解决方案

### 1. 修复时间戳更新逻辑

**之前的错误逻辑**：
```gdscript
# load_game 中
save_data = json.data
call_deferred("_check_offline_time")  # 异步调用
save_data.timestamp.last_played_at = Time.get_datetime_string_from_system()  # 立即更新
```

**修复后的正确逻辑**：
```gdscript
# load_game 中
save_data = json.data
call_deferred("_check_offline_time")  # 异步调用，不立即更新时间

# _check_offline_time 中
get_node("/root/OfflineTimeManager").check_and_apply_offline_changes()
# 检查完成后才更新时间
save_data.timestamp.last_played_at = Time.get_datetime_string_from_system()
save_game(current_slot, false)  # 保存但不再次更新时间
```

### 2. 使用 Unix 时间戳代替字符串解析

**新增字段**：
- `last_played_at_unix`：存储 Unix 时间戳（浮点数）

**优点**：
- 避免时区转换问题
- 避免字符串解析错误
- 计算更精确
- 兼容旧存档（如果没有 Unix 时间戳，会尝试解析字符串）

**实现**：
```gdscript
# 保存时同时存储两种格式
save_data.timestamp.last_played_at = Time.get_datetime_string_from_system()  # 便于阅读
save_data.timestamp.last_played_at_unix = Time.get_unix_time_from_system()  # 用于计算

# 读取时优先使用 Unix 时间戳
var last_played_unix = SaveManager.save_data.timestamp.get("last_played_at_unix", 0.0)
if last_played_unix == 0.0:
    # 兼容旧存档，尝试解析字符串
    last_played_unix = _parse_datetime(last_played_str)
```

### 3. 添加保护机制

**负数时间检测**：
```gdscript
if offline_seconds < 0:
    print("警告: 离线时间为负数，可能是系统时间被修改。跳过离线处理。")
    return
```

**详细调试信息**：
```gdscript
print("=== 离线时间检查 ===")
print("上次游玩时间: ", Time.get_datetime_string_from_unix_time(int(last_played_unix)))
print("当前时间: ", Time.get_datetime_string_from_system())
print("上次游玩Unix时间戳: ", last_played_unix)
print("当前Unix时间戳: ", current_time)
print("离线时长: %.2f 秒 (%.2f 分钟, %.2f 小时)" % [offline_seconds, offline_minutes, offline_hours])
```

## 修改的文件

1. **scripts/save_manager.gd**
   - 修改 `load_game()` 逻辑
   - 修改 `save_game()` 添加 `update_play_time` 参数
   - 修改 `_check_offline_time()` 在检查后更新时间
   - 所有保存操作都同时保存 Unix 时间戳

2. **scripts/offline_time_manager.gd**
   - 修改 `check_and_apply_offline_changes()` 优先使用 Unix 时间戳
   - 添加负数时间检测
   - 添加详细调试信息
   - 保留字符串解析功能以兼容旧存档

3. **config/save_data_template.json**
   - 添加 `last_played_at_unix` 字段

4. **docs/offline_time_system.md**
   - 更新时间戳存储说明

## 测试建议

1. **删除旧存档**，让系统创建新存档（包含 Unix 时间戳）
2. 运行游戏，退出，再次进入，观察控制台输出
3. 应该看到类似这样的输出：
   ```
   === 离线时间检查 ===
   上次游玩时间: 2025-10-14T20:21:44
   当前时间: 2025-10-14T20:21:49
   上次游玩Unix时间戳: 1760444504.0
   当前Unix时间戳: 1760444509.0
   离线时长: 5.00 秒 (0.08 分钟, 0.00 小时)
   离线时间小于5分钟，无变化
   ```

## 已知限制

1. 如果用户修改系统时间，可能导致异常的离线时长（已添加负数检测）
2. 旧存档的字符串解析可能仍有时区问题（建议用户重新开始游戏）

## 总结

通过使用 Unix 时间戳和修复时间更新逻辑，系统现在可以正确计算离线时长。所有时间相关的操作都使用统一的时间源，避免了时区和格式转换问题。
