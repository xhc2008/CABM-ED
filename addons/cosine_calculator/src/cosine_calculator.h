#ifndef COSINE_CALCULATOR_H
#define COSINE_CALCULATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

using namespace godot;

class CosineCalculator : public RefCounted {
    GDCLASS(CosineCalculator, RefCounted)

protected:
    static void _bind_methods();

public:
    CosineCalculator();
    ~CosineCalculator();

    // 计算两个向量的余弦相似度（使用 double 精度）
    double calculate(const PackedFloat64Array &vec1, const PackedFloat64Array &vec2);
    
    // 批量计算查询向量与多个向量的相似度
    // vectors: Array of PackedFloat64Array
    Array calculate_batch(const PackedFloat64Array &query_vec, const Array &vectors);

    // 批量计算（接受预先计算好的每个向量模长），可提高性能
    Array calculate_batch_with_mags(const PackedFloat64Array &query_vec, const Array &vectors, const PackedFloat64Array &vector_mags);
    
    // 归一化向量
    PackedFloat64Array normalize(const PackedFloat64Array &vec);

private:
    // 计算向量点积
    double dot_product(const PackedFloat64Array &vec1, const PackedFloat64Array &vec2);
    
    // 计算向量模长
    double magnitude(const PackedFloat64Array &vec);
};

#endif // COSINE_CALCULATOR_H
