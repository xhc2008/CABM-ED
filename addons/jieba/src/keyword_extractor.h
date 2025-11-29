#ifndef KEYWORD_EXTRACTOR_H
#define KEYWORD_EXTRACTOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>

namespace godot {

class JiebaKeywordExtractor : public RefCounted {
    GDCLASS(JiebaKeywordExtractor, RefCounted)

private:
    // 可以在这里添加私有成员变量

protected:
    static void _bind_methods();

public:
    JiebaKeywordExtractor();
    ~JiebaKeywordExtractor();

    Array extract_keywords(const String &text, int top_k = 5);
};

}

#endif // KEYWORD_EXTRACTOR_H