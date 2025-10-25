#ifndef COSINE_CALCULATOR_H
#define COSINE_CALCULATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class CosineCalculator : public RefCounted {
    GDCLASS(CosineCalculator, RefCounted)

protected:
    static void _bind_methods();

public:
    CosineCalculator();
    ~CosineCalculator();

    // 计算两个向量的余弦相似度
    float calculate(const Array& vec1, const Array& vec2);
    
    // 批量计算查询向量与多个向量的相似度
    Array calculate_batch(const Array& query_vec, const Array& vectors);
    
    // 归一化向量
    Array normalize(const Array& vec);

private:
    // 计算向量点积
    float dot_product(const Array& vec1, const Array& vec2);
    
    // 计算向量模长
    float magnitude(const Array& vec);
};

#endif // COSINE_CALCULATOR_H
