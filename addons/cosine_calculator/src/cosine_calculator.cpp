#include "cosine_calculator.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <cmath>

using namespace godot;

void CosineCalculator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("calculate", "vec1", "vec2"), &CosineCalculator::calculate);
    ClassDB::bind_method(D_METHOD("calculate_batch", "query_vec", "vectors"), &CosineCalculator::calculate_batch);
    ClassDB::bind_method(D_METHOD("calculate_batch_with_mags", "query_vec", "vectors", "vector_mags"), &CosineCalculator::calculate_batch_with_mags);
    ClassDB::bind_method(D_METHOD("normalize", "vec"), &CosineCalculator::normalize);
}

CosineCalculator::CosineCalculator() {
}

CosineCalculator::~CosineCalculator() {
}

double CosineCalculator::calculate(const PackedFloat64Array& vec1, const PackedFloat64Array& vec2) {
    if (vec1.size() != vec2.size() || vec1.size() == 0) {
        return 0.0;
    }

    double dot = dot_product(vec1, vec2);
    double mag1 = magnitude(vec1);
    double mag2 = magnitude(vec2);

    if (mag1 == 0.0 || mag2 == 0.0) {
        return 0.0;
    }

    return dot / (mag1 * mag2);
}

Array CosineCalculator::calculate_batch(const PackedFloat64Array& query_vec, const Array& vectors) {
    Array similarities;

    for (int i = 0; i < vectors.size(); i++) {
        PackedFloat64Array vec = vectors[i];
        double sim = calculate(query_vec, vec);
        similarities.append(sim);
    }

    return similarities;
}

Array CosineCalculator::calculate_batch_with_mags(const PackedFloat64Array& query_vec, const Array& vectors, const PackedFloat64Array& vector_mags) {
    Array similarities;

    double query_mag = magnitude(query_vec);

    for (int i = 0; i < vectors.size(); i++) {
        PackedFloat64Array vec = vectors[i];

        double mag_i = 0.0;
        if (vector_mags.size() == vectors.size()) {
            mag_i = vector_mags[i];
        } else {
            mag_i = magnitude(vec);
        }

        if (query_mag == 0.0 || mag_i == 0.0) {
            similarities.append(0.0);
            continue;
        }

        double dot = dot_product(query_vec, vec);
        similarities.append(dot / (query_mag * mag_i));
    }

    return similarities;
}

PackedFloat64Array CosineCalculator::normalize(const PackedFloat64Array& vec) {
    double mag = magnitude(vec);

    if (mag == 0.0) {
        return vec;
    }

    PackedFloat64Array normalized;
    normalized.resize(vec.size());
    for (int i = 0; i < vec.size(); i++) {
        double val = vec[i];
        normalized.set(i, val / mag);
    }

    return normalized;
}

double CosineCalculator::dot_product(const PackedFloat64Array& vec1, const PackedFloat64Array& vec2) {
    double result = 0.0;

    int sz = vec1.size();
    for (int i = 0; i < sz; i++) {
        double v1 = vec1[i];
        double v2 = vec2[i];
        result += v1 * v2;
    }

    return result;
}

double CosineCalculator::magnitude(const PackedFloat64Array& vec) {
    double sum = 0.0;

    for (int i = 0; i < vec.size(); i++) {
        double val = vec[i];
        sum += val * val;
    }

    return std::sqrt(sum);
}
