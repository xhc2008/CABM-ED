# 数值边界控制修复文档

## 问题描述

在检查代码时发现，好感度和回复意愿的数值变化在不同模块中存在不一致的边界控制：

1. **offline_time_manager.gd**：部分函数缺少边界控制，可能导致数值溢出
2. **ai_service.gd**：使用硬编码的边界值（0-100, 0-150）
3. **event_manager.gd**：通过 EventHelpers 统一管理，有边界控制

## 修复方案

### 1. 统一边界控制（EventHelpers）

在 `scripts/event_helpers.gd` 中添加：

- **边界常量**：
  - `AFFECTION_MIN = 0`, `AFFECTION_MAX = 100`（好感度）
  - `WILLINGNESS_MIN = 0`, `WILLINGNESS_MAX = 150`（回复意愿）
  - `ENERGY_MIN = 0`, `ENERGY_MAX = 100`（精力）

- **新增函数**：
  - `set_affection_safe(value: int)`：安全设置好感度
  - `set_willingness_safe(value: int)`：安全设置回复意愿

- **更新现有函数**：
  - `modify_affection(change: int)`：使用常量边界
  - `modify_willingness(change: int)`：使用常量边界（上限150）

### 2. 修复 offline_time_manager.gd

所有离线时间处理函数现在都使用 EventHelpers 的统一边界控制：

- `_apply_short_offline()`：回复意愿变化 -10~30
- `_apply_medium_offline()`：好感度变化 -20~10，回复意愿变化 0~50
- `_apply_long_offline()`：好感度变化 -50~0，回复意愿设置为 70~100

每个函数都包含降级方案：如果 EventHelpers 不可用，直接使用 SaveManager 并手动 clamp。

### 3. 更新 ai_service.gd

`_apply_extracted_fields()` 函数现在使用 EventHelpers 的统一边界控制：

- 好感度增量（like 字段）
- 回复意愿增量（will 字段）

同样包含降级方案以保证兼容性。

## 边界值说明

| 属性 | 最小值 | 最大值 | 说明 |
|------|--------|--------|------|
| 好感度 (affection) | 0 | 100 | 标准百分比范围 |
| 回复意愿 (willingness) | 0 | 150 | 允许超过100以支持更灵活的事件系统 |
| 精力 (energy) | 0 | 100 | 标准百分比范围 |

## 修复效果

1. **防止溢出**：所有数值变化都经过边界检查
2. **统一管理**：所有边界值在 EventHelpers 中定义，便于维护
3. **代码复用**：减少重复的 clamp 代码
4. **降级兼容**：即使 EventHelpers 不可用，也能正常工作

## 测试建议

1. 测试离线时间系统（特别是长时间离线）
2. 测试对话系统中的好感度和回复意愿变化
3. 测试事件系统中的数值变化
4. 验证数值不会超出边界（0-100 或 0-150）

## 相关文件

- `scripts/event_helpers.gd`：统一边界控制
- `scripts/offline_time_manager.gd`：离线时间处理
- `scripts/ai_service.gd`：AI 对话处理
- `scripts/event_manager.gd`：事件系统（已使用 EventHelpers）
