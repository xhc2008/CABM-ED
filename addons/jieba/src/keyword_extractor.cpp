#include "keyword_extractor.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>

// cppjieba headers - 根据实际目录结构调整
#include "cppjieba/Jieba.hpp"
#include "cppjieba/KeywordExtractor.hpp"

using namespace godot;

void JiebaKeywordExtractor::_bind_methods() {
    ClassDB::bind_method(D_METHOD("extract_keywords", "text", "top_k"), &JiebaKeywordExtractor::extract_keywords, DEFVAL(5));
}

JiebaKeywordExtractor::JiebaKeywordExtractor() {
}

JiebaKeywordExtractor::~JiebaKeywordExtractor() {
}

Array JiebaKeywordExtractor::extract_keywords(const String &text, int top_k) {
    Array result;

    // 使用 res:// 协议路径，这在所有平台上都能正确工作
    String dict_path = "res://addons/jieba/config/jieba.dict.utf8";
    String model_path = "res://addons/jieba/config/hmm_model.utf8";
    String idf_path = "res://addons/jieba/config/idf.utf8";
    String stop_words_path = "res://addons/jieba/config/stop_words.utf8";

    // 在 Android 上，需要将文件复制到 user:// 目录，因为 cppjieba 需要实际的文件路径
    // 检查是否在 Android 平台
    String user_dict_path = "user://jieba.dict.utf8";
    String user_model_path = "user://hmm_model.utf8";
    String user_idf_path = "user://idf.utf8";
    String user_stop_path = "user://stop_words.utf8";

    // 复制文件到 user:// 目录（如果还不存在）
    auto copy_if_needed = [](const String &src, const String &dst) -> bool {
        if (!FileAccess::file_exists(dst)) {
            Ref<FileAccess> src_file = FileAccess::open(src, FileAccess::READ);
            if (src_file.is_null()) {
                UtilityFunctions::printerr("无法打开源文件: ", src);
                return false;
            }
            
            PackedByteArray data = src_file->get_buffer(src_file->get_length());
            src_file->close();
            
            Ref<FileAccess> dst_file = FileAccess::open(dst, FileAccess::WRITE);
            if (dst_file.is_null()) {
                UtilityFunctions::printerr("无法创建目标文件: ", dst);
                return false;
            }
            
            dst_file->store_buffer(data);
            dst_file->close();
            UtilityFunctions::print("已复制文件: ", src, " -> ", dst);
        }
        return true;
    };

    // 复制所有必需的文件
    if (!copy_if_needed(dict_path, user_dict_path) ||
        !copy_if_needed(model_path, user_model_path) ||
        !copy_if_needed(idf_path, user_idf_path) ||
        !copy_if_needed(stop_words_path, user_stop_path)) {
        UtilityFunctions::printerr("文件复制失败");
        return result;
    }

    // 使用 globalize_path 将 user:// 路径转换为实际的文件系统路径
    String actual_dict = ProjectSettings::get_singleton()->globalize_path(user_dict_path);
    String actual_model = ProjectSettings::get_singleton()->globalize_path(user_model_path);
    String actual_idf = ProjectSettings::get_singleton()->globalize_path(user_idf_path);
    String actual_stop = ProjectSettings::get_singleton()->globalize_path(user_stop_path);

    // cppjieba expects std::string paths
    std::string dict_s = actual_dict.utf8().get_data();
    std::string model_s = actual_model.utf8().get_data();
    std::string idf_s = actual_idf.utf8().get_data();
    std::string stop_s = actual_stop.utf8().get_data();

    // try {
        // 明确使用 cppjieba 命名空间
        cppjieba::KeywordExtractor extractor(dict_s, model_s, idf_s, stop_s);
        std::vector<std::string> keywords;
        std::string utf8_text = text.utf8().get_data();
        extractor.Extract(utf8_text, keywords, top_k);

        for (size_t i = 0; i < keywords.size(); ++i) {
            const std::string &kw = keywords[i];
            // keywords are UTF-8 encoded; use String::utf8 to construct Godot String correctly
            result.append(String::utf8(kw.c_str(), (int64_t)kw.size()));
        }
    // } catch (const std::exception &e) {
    //     UtilityFunctions::printerr("Jieba 提取关键词时出错: ", e.what());
    // }

    return result;
}