# 安卓存储权限问题解决方案

## 问题描述
在安卓设备上上传音乐时，会显示"无权访问文件夹"的错误。

## 原因分析
从 Android 6.0 (API 23) 开始，应用需要在运行时请求危险权限（如存储访问权限）。
从 Android 13 (API 33) 开始，存储权限模型发生了变化，需要使用更细粒度的权限。

## 解决方案

### 1. 导出配置修改
在 `export_presets.cfg` 中启用以下权限：

```ini
permissions/read_external_storage=true  # Android 6-12 需要
permissions/read_media_audio=true       # Android 13+ 需要
```

### 2. 代码修改
在 `scripts/music_player_panel.gd` 中添加运行时权限请求：

- 在上传音乐时自动请求权限
- 使用 `OS.request_permissions()` 触发系统权限对话框
- 确保 FileDialog 使用 `ACCESS_FILESYSTEM` 模式

### 3. 权限说明

#### Android 版本差异
- **Android 6-12 (API 23-32)**：需要 `READ_EXTERNAL_STORAGE` 权限
- **Android 13+ (API 33+)**：需要 `READ_MEDIA_AUDIO` 权限（更细粒度）

#### 权限请求流程
1. 用户点击"上传音乐"按钮
2. 应用检测到安卓系统
3. 调用 `OS.request_permissions()` 请求权限
4. 系统弹出权限对话框
5. 用户授权后，打开文件选择器

## 重新打包
修改配置后，需要重新导出安卓 APK：

```bash
# 使用 Godot 编辑器导出，或使用命令行
godot --export-release "Android" CABM-ED.apk
```

## 测试建议
1. 在 Android 6-12 设备上测试
2. 在 Android 13+ 设备上测试
3. 测试拒绝权限后的行为
4. 测试授权后能否正常选择文件

## 用户提示
首次使用上传功能时，会弹出权限请求对话框：
- **允许**：可以正常选择音乐文件
- **拒绝**：无法访问文件，需要在系统设置中手动授权

## 注意事项
- 权限只在首次使用时请求一次
- 如果用户拒绝权限，需要引导用户到系统设置中手动授权
- 不同安卓版本的权限对话框样式可能不同
