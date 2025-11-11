# AI 记忆修复模块
# 负责：向量数据修复功能

extends Node

var repair_tool: Node = null
var repair_check_button: Button
var repair_check_status_label: Label
var repair_button: Button
var repair_progress_label: Label
var repair_progress_bar: ProgressBar
var repair_log_label: Label
var close_button: Button

## 初始化修复工具
func init_repair_tool() -> void:
    var repair_script = load("res://scripts/vector_repair_tool.gd")
    repair_tool = repair_script.new()
    add_child(repair_tool)
    repair_tool.repair_progress.connect(_on_repair_progress)
    repair_tool.repair_completed.connect(_on_repair_completed)

## 检查向量数据按钮被点击
func on_repair_check_pressed() -> void:
    repair_check_button.disabled = true
    repair_check_status_label.text = "正在检查..."
    repair_check_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
    
    await get_tree().process_frame
    
    # 获取MemoryManager
    var memory_mgr = get_node_or_null("/root/MemoryManager")
    if not memory_mgr:
        repair_check_status_label.text = "✗ MemoryManager未找到"
        repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
        repair_check_button.disabled = false
        return
    
    # 等待初始化
    if not memory_mgr.is_initialized:
        await memory_mgr.memory_system_ready
    
    var memory_system = memory_mgr.memory_system
    if not memory_system:
        repair_check_status_label.text = "✗ memory_system未找到"
        repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
        repair_check_button.disabled = false
        return
    
    var total = memory_system.memory_items.size()
    if total == 0:
        repair_check_status_label.text = "没有记忆数据"
        repair_check_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        repair_check_button.disabled = false
        return
    
    # 检查向量
    var damaged_count = 0
    var damaged_indices = []
    
    for i in range(total):
        if _needs_repair(memory_system.memory_items, i):
            damaged_count += 1
            damaged_indices.append(i)
    
    if damaged_count > 0:
        # 显示损坏的记忆索引（最多显示5个）
        var indices_text = ""
        var show_count = min(5, damaged_indices.size())
        for i in range(show_count):
            indices_text += str(damaged_indices[i] + 1)
            if i < show_count - 1:
                indices_text += ", "
        if damaged_indices.size() > 5:
            indices_text += "..."
        
        repair_check_status_label.text = "✗ 发现 %d 条可能损坏的记忆\n索引: %s" % [damaged_count, indices_text]
        repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
        repair_button.disabled = false
    else:
        repair_check_status_label.text = "✓ 所有记忆数据正常\n共 %d 条记忆" % total
        repair_check_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
        repair_button.disabled = true
    
    repair_check_button.disabled = false

## 检查向量是否需要修复
func _needs_repair(items: Array, index: int) -> bool:
    var item = items[index]
    
    # 检查1：向量为空 -> 肯定损坏
    if item.vector.is_empty():
        return true
    
    # 检查2：向量维度异常（正常应该是1024维）
    if item.vector.size() < 100:
        return true
    
    # 检查3：向量与多个其他记忆完全相同
    var same_vector_count = 0
    var check_range = 5  # 检查前后各5条记忆
    
    for offset in range(-check_range, check_range + 1):
        if offset == 0:
            continue
        
        var other_idx = index + offset
        if other_idx < 0 or other_idx >= items.size():
            continue
        
        var other_item = items[other_idx]
        if other_item.vector.is_empty():
            continue
        
        # 检查文本是否相似（如果文本相似，向量相同是正常的）
        if _texts_are_similar(item.text, other_item.text):
            continue
        
        # 比较前50个值（更严格的检查）
        if _vectors_are_same(item.vector, other_item.vector, 50):
            same_vector_count += 1
            
            # 如果与2个以上不同的记忆向量完全相同，判定为损坏
            if same_vector_count >= 2:
                return true
    
    return false

## 检查两个文本是否相似
func _texts_are_similar(text1: String, text2: String) -> bool:
    # 移除时间戳前缀进行比较
    var clean_text1 = _remove_timestamp(text1)
    var clean_text2 = _remove_timestamp(text2)
    
    # 如果文本完全相同
    if clean_text1 == clean_text2:
        return true
    
    # 如果文本长度相差很大，不相似
    var len_diff = abs(clean_text1.length() - clean_text2.length())
    if len_diff > max(clean_text1.length(), clean_text2.length()) * 0.5:
        return false
    
    # 简单的包含关系检查
    if clean_text1.length() > 10 and clean_text2.length() > 10:
        if clean_text1 in clean_text2 or clean_text2 in clean_text1:
            return true
    
    return false

## 移除文本开头的时间戳
func _remove_timestamp(text: String) -> String:
    # 格式: [MM-DD HH:MM] 文本内容
    var regex = RegEx.new()
    regex.compile("^\\[\\d{2}-\\d{2} \\d{2}:\\d{2}\\] ")
    return regex.sub(text, "", true)

## 检查两个向量的前N个值是否完全相同
func _vectors_are_same(vec1: Array, vec2: Array, check_count: int = 50) -> bool:
    if vec1.size() != vec2.size():
        return false
    
    var count = min(check_count, vec1.size())
    for i in range(count):
        # 使用更严格的阈值
        if abs(vec1[i] - vec2[i]) > 0.00001:
            return false
    
    return true

## 开始修复按钮被点击
func on_repair_start_pressed() -> void:
    repair_button.disabled = true
    repair_check_button.disabled = true
    close_button.disabled = true
    
    repair_progress_label.text = "正在初始化..."
    repair_progress_bar.value = 0
    repair_log_label.text = "开始修复...\n"
    
    # 开始修复
    repair_tool.start_repair()

## 修复进度更新
func _on_repair_progress(current: int, total: int, message: String) -> void:
    var percent = (float(current) / float(total)) * 100.0
    repair_progress_bar.value = percent
    repair_progress_label.text = "[%d/%d] %.1f%%" % [current, total, percent]
    
    # 添加到日志
    repair_log_label.text += "[%d/%d] %s\n" % [current, total, message]

## 修复完成
func _on_repair_completed(success: bool, message: String) -> void:
    repair_progress_bar.value = 100
    repair_progress_label.text = "完成"
    
    if success:
        repair_log_label.text += "\n✓ " + message + "\n"
        repair_check_status_label.text = "✓ 修复完成"
        repair_check_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
    else:
        repair_log_label.text += "\n✗ " + message + "\n"
        repair_check_status_label.text = "✗ 修复失败"
        repair_check_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    
    repair_button.disabled = false
    repair_button.text = "重新修复"
    repair_check_button.disabled = false
    close_button.disabled = false
