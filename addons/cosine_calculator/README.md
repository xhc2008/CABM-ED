# Cosine Calculator - GDExtension

高性能余弦相似度计算插件，用于向量数据库的相似度检索。

## 功能

- 计算两个向量的余弦相似度
- 批量计算查询向量与多个向量的相似度
- 向量归一化

## 编译

### 前置要求

1. 安装 SCons: `pip install scons`
2. 确保项目根目录有 `godot-cpp` 子模块

### 编译步骤

```bash
cd addons/cosine_calculator

# Windows (MSVC)
scons platform=windows target=template_debug
scons platform=windows target=template_release

# Linux
scons platform=linux target=template_debug
scons platform=linux target=template_release

# macOS
scons platform=macos target=template_debug
scons platform=macos target=template_release
```

## 使用

```gdscript
# 创建计算器实例
var calculator = CosineCalculator.new()

# 计算两个向量的相似度
var vec1 = [1.0, 2.0, 3.0]
var vec2 = [4.0, 5.0, 6.0]
var similarity = calculator.calculate(vec1, vec2)

# 批量计算
var query = [1.0, 0.0, 0.0]
var vectors = [
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0]
]
var similarities = calculator.calculate_batch(query, vectors)

# 归一化向量
var normalized = calculator.normalize([3.0, 4.0])
```

## 性能

相比 GDScript 实现，C++ 插件在大规模向量计算时性能提升约 10-50 倍。
