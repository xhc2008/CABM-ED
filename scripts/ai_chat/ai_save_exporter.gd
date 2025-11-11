# AI 存档导出模块
# 负责：存档导出到ZIP文件功能

extends Node

var config_manager: Node
var save_export_api_key_input: LineEdit
var save_export_button: Button
var save_export_status_label: Label

func _init(cfg_mgr: Node) -> void:
    config_manager = cfg_mgr

## 存档导出按钮被点击
func on_save_export_pressed() -> void:
    var input_key = save_export_api_key_input.text.strip_edges()
    
    if input_key.is_empty():
        update_save_export_status("请输入API密钥", Color(1.0, 0.3, 0.3))
        return
    
    # 验证API密钥
    if not config_manager.verify_api_key(input_key):
        update_save_export_status("API密钥验证失败，请输入正确的密钥", Color(1.0, 0.3, 0.3))
        return
    
    # 执行导出
    export_save_archive()

## 导出存档为zip文件
func export_save_archive() -> void:
    update_save_export_status("正在导出存档...", Color(0.3, 0.8, 1.0))
    save_export_button.disabled = true
    
    # 生成导出文件名（带时间戳）
    var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
    var export_filename = "CABM-ED_Save_%s.zip" % timestamp
    
    # 根据平台选择不同的导出方式
    if OS.get_name() == "Android":
        # Android: 直接导出到Documents目录
        export_save_android(export_filename)
    else:
        # PC: 使用文件对话框
        var file_dialog = FileDialog.new()
        file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
        file_dialog.access = FileDialog.ACCESS_FILESYSTEM
        file_dialog.current_file = export_filename
        file_dialog.add_filter("*.zip", "存档文件")
        file_dialog.file_selected.connect(_on_save_export_path_selected)
        file_dialog.canceled.connect(_on_save_export_canceled)
        get_tree().root.add_child(file_dialog)
        file_dialog.popup_centered(Vector2i(800, 600))

## Android平台导出存档
func export_save_android(filename: String) -> void:
    # 请求存储权限
    var perm_helper = load("res://scripts/android_permissions.gd").new()
    add_child(perm_helper)
    
    var has_permission = await perm_helper.request_storage_permission()
    perm_helper.queue_free()
    
    if not has_permission:
        update_save_export_status("✗ 需要存储权限才能导出", Color(1.0, 0.3, 0.3))
        save_export_button.disabled = false
        return
    
    var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
    if documents_path.is_empty():
        documents_path = "/storage/emulated/0/Documents"
    
    var export_path = documents_path + "/CABM-ED_Saves"
    
    # 创建导出目录
    var dir = DirAccess.open(documents_path)
    if dir and not dir.dir_exists("CABM-ED_Saves"):
        dir.make_dir("CABM-ED_Saves")
    
    var full_export_path = export_path + "/" + filename
    
    # 使用Godot内置的ZIPPacker
    if create_zip_archive(full_export_path):
        update_save_export_status("✓ 导出成功\n" + full_export_path, Color(0.3, 1.0, 0.3))
        print("存档导出成功: ", full_export_path)
    else:
        update_save_export_status("✗ 导出失败", Color(1.0, 0.3, 0.3))
    
    save_export_button.disabled = false

## 用户选择了导出路径（PC平台）
func _on_save_export_path_selected(export_path: String) -> void:
    print("开始导出存档: ", export_path)
    
    # 使用Godot内置的ZIPPacker
    if create_zip_archive(export_path):
        update_save_export_status("✓ 导出成功: " + export_path, Color(0.3, 1.0, 0.3))
        print("存档导出成功")
    else:
        update_save_export_status("✗ 导出失败", Color(1.0, 0.3, 0.3))
    
    save_export_button.disabled = false

## 使用Godot内置ZIPPacker创建存档
func create_zip_archive(zip_path: String) -> bool:
    var zip = ZIPPacker.new()
    var err = zip.open(zip_path)
    
    if err != OK:
        print("无法创建ZIP文件: ", err)
        return false
    
    # 获取user://目录
    var user_path = OS.get_user_data_dir()
    
    # 递归添加所有文件
    var success = add_directory_to_zip(zip, user_path, "")
    
    zip.close()
    
    return success

## 递归添加目录到ZIP
func add_directory_to_zip(zip: ZIPPacker, dir_path: String, zip_base_path: String) -> bool:
    var dir = DirAccess.open(dir_path)
    if dir == null:
        print("无法打开目录: ", dir_path)
        return false
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name == "." or file_name == "..":
            file_name = dir.get_next()
            continue
        
        var full_path = dir_path + "/" + file_name
        var zip_path = zip_base_path + file_name if zip_base_path.is_empty() else zip_base_path + "/" + file_name
        
        if dir.current_is_dir():
            # 递归添加子目录
            add_directory_to_zip(zip, full_path, zip_path)
        else:
            # 添加文件
            var file = FileAccess.open(full_path, FileAccess.READ)
            if file:
                var content = file.get_buffer(file.get_length())
                file.close()
                zip.start_file(zip_path)
                zip.write_file(content)
                zip.close_file()
        
        file_name = dir.get_next()
    
    dir.list_dir_end()
    return true

## 用户取消了导出
func _on_save_export_canceled() -> void:
    update_save_export_status("已取消导出", Color(0.6, 0.6, 0.6))
    save_export_button.disabled = false

## 更新存档导出状态
func update_save_export_status(message: String, color: Color) -> void:
    save_export_status_label.text = message
    save_export_status_label.add_theme_color_override("font_color", color)

## 样式化存档导出警告面板
func style_warning_panel(parent_node: Node) -> void:
    var warning_panel = parent_node.get_node("MarginContainer/VBoxContainer/TabContainer/存档导出/ScrollContainer/VBoxContainer/WarningPanel")
    if warning_panel == null:
        return
    
    var style_box = StyleBoxFlat.new()
    style_box.bg_color = Color(0.3, 0.1, 0.1, 0.8)  # 深红色背景
    style_box.border_width_left = 3
    style_box.border_width_top = 3
    style_box.border_width_right = 3
    style_box.border_width_bottom = 3
    style_box.border_color = Color(1.0, 0.2, 0.2, 1.0)  # 红色边框
    style_box.corner_radius_top_left = 8
    style_box.corner_radius_top_right = 8
    style_box.corner_radius_bottom_left = 8
    style_box.corner_radius_bottom_right = 8
    
    warning_panel.add_theme_stylebox_override("panel", style_box)
