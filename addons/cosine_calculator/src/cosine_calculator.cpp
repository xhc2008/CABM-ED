#include "cosine_calculator.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void CosineCalculator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("calculate", "vec1", "vec2"), &CosineCalculator::calculate);
    ClassDB::bind_method(D_METHOD("calculate_batch", "query_vec", "vectors"), &CosineCalculator::calculate_batch);
    ClassDB::bind_method(D_METHOD("normalize", "vec"), &CosineCalculator::normalize);
}

CosineCalculator::CosineCalculator() {
}

CosineCalculator::~CosineCalculator() {
}

float CosineCalculator::calculate(const Array& vec1, const Array& vec2) {
    if (vec1.size() != vec2.size() || vec1.size() == 0) {
        return 0.0f;
    }

    float dot = dot_product(vec1, vec2);
    float mag1 = magnitude(vec1);
    float mag2 = magnitude(vec2);

    if (mag1 == 0.0f || mag2 == 0.0f) {
        return 0.0f;
    }

    return dot / (mag1 * mag2);
}

Array CosineCalculator::calculate_batch(const Array& query_vec, const Array& vectors) {
    Array similarities;
    
    for (int i = 0; i < vectors.size(); i++) {
        Array vec = vectors[i];
        float sim = calculate(query_vec, vec);
        similarities.append(sim);
    }
    
    return similarities;
}

Array CosineCalculator::normalize(const Array& vec) {
    float mag = magnitude(vec);
    
    if (mag == 0.0f) {
        return vec;
    }
    
    Array normalized;
    for (int i = 0; i < vec.size(); i++) {
        float val = vec[i];
        normalized.append(val / mag);
    }
    
    return normalized;
}

float CosineCalculator::dot_product(const Array& vec1, const Array& vec2) {
    float result = 0.0f;
    
    for (int i = 0; i < vec1.size(); i++) {
        float v1 = vec1[i];
        float v2 = vec2[i];
        result += v1 * v2;
    }
    
    return result;
}

float CosineCalculator::magnitude(const Array& vec) {
    float sum = 0.0f;
    
    for (int i = 0; i < vec.size(); i++) {
        float val = vec[i];
        sum += val * val;
    }
    
    return std::sqrt(sum);
}
