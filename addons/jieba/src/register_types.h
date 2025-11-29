#ifndef JIEBA_REGISTER_TYPES_H
#define JIEBA_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_jieba_module(ModuleInitializationLevel p_level);
void uninitialize_jieba_module(ModuleInitializationLevel p_level);

#endif // JIEBA_REGISTER_TYPES_H
