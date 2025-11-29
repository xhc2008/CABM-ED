#include "keyword_extractor.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

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

    String dict_path = "addons/jieba/config/jieba.dict.utf8";
    String model_path = "addons/jieba/config/hmm_model.utf8";
    String idf_path = "addons/jieba/config/idf.utf8";
    String stop_words_path = "addons/jieba/config/stop_words.utf8";

    // cppjieba expects std::string paths
    std::string dict_s = dict_path.utf8().get_data();
    std::string model_s = model_path.utf8().get_data();
    std::string idf_s = idf_path.utf8().get_data();
    std::string stop_s = stop_words_path.utf8().get_data();

        // 明确使用 cppjieba 命名空间
        cppjieba::KeywordExtractor extractor(dict_s, model_s, idf_s, stop_s);
        std::vector<std::string> keywords;
        std::string utf8_text = text.utf8().get_data();
        extractor.Extract(utf8_text, keywords, top_k);

        for (size_t i = 0; i < keywords.size(); ++i) {
            result.append(String(keywords[i].c_str()));
        }


    return result;
}