# 离线时间系统 - 快速指南

## 已完成的工作

✅ 创建了离线时间管理器 (`scripts/offline_time_manager.gd`)
✅ 修改了存档管理器以支持离线时间检查
✅ 添加了自动加载配置
✅ 创建了测试脚本
✅ 编写了完整文档

## 系统已自动运行

系统已经集成到游戏中，**无需额外配置**。每次玩家进入游戏时会自动：

1. 读取上次游玩时间
2. 计算离线时长
3. 根据时长调整数值
4. 保存新的游玩时间

## 调整规则速查

| 离线时长 | 心情 | 好感度 | 回复意愿 |
|---------|------|--------|----------|
| < 5分钟 | 无变化 | 无变化 | 无变化 |
| 5分钟~3小时 | 随机变化* | 无变化 | -30~+30 |
| 3小时~24小时 | 随机变化* | -20~+10 | 0~+50 |
| 24小时以上 | 随机变化* | -50~0 | **置为** 70~100 |

*心情随机变化时，"平静"的权重是其他心情的5倍

## 测试方法

### 快速测试（推荐）

1. 在场景中添加 `offline_time_test.gd` 脚本
2. 运行游戏
3. 在 Godot 控制台输入：

```gdscript
# 测试1小时离线
$OfflineTimeTest.test_short_offline()

# 测试12小时离线
$OfflineTimeTest.test_medium_offline()

# 测试3天离线
$OfflineTimeTest.test_long_offline()

# 重置时间
$OfflineTimeTest.reset_time()
```

### 真实测试

1. 运行游戏并退出
2. 等待一段时间（或修改存档文件中的时间）
3. 重新进入游戏
4. 查看控制台输出的变化信息

## 控制台输出示例

```
离线时长: 65.50 分钟 (1.09 小时)
离线时间 5分钟~3小时
心情变化: calm -> happy
回复意愿变化: 50 -> 65 (变化: +15)
```

## 存档位置

Windows: `%APPDATA%\Godot\app_userdata\CABM-ED\saves\save_slot_1.json`

## 注意事项

- 首次进入游戏不会触发离线变化
- 系统使用设备的系统时间
- 所有变化都会自动保存
- 回复意愿范围：0~100
- 好感度无上下限

## 相关文件

- `scripts/offline_time_manager.gd` - 核心逻辑
- `scripts/save_manager.gd` - 存档管理（已修改）
- `scripts/offline_time_test.gd` - 测试工具
- `docs/offline_time_system.md` - 详细文档
- `project.godot` - 自动加载配置（已修改）
