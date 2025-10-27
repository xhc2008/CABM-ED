# 安卓RAG检索问题排查指南

## 问题现象
在电脑上可以正常使用RAG（检索增强生成）功能，但在安卓设备上检索结果始终为空。

## 核心原因分析

根据代码分析，RAG系统的工作流程如下：

1. **记忆保存**（`UnifiedMemorySaver`）
   - 对话总结 → 存档（saves/）
   - 对话总结 → 日记（diary/）
   - 对话总结 → 向量数据库（memory_main_memory.json）

2. **向量化**（`MemorySystem`）
   - 调用嵌入API获取文本向量
   - 使用HTTPRequest发送网络请求
   - 需要API密钥和Base URL

3. **检索**（`MemoryManager`）
   - 将查询文本向量化
   - 计算余弦相似度
   - 返回最相关的记忆

## 可能的故障点

### 1. 网络请求失败 ⭐⭐⭐⭐⭐（最可能）

**症状**：
- 嵌入API调用返回空向量
- 日志中可能有401、403、超时等错误

**原因**：
- API密钥在安卓上未正确加载
- 网络权限未启用
- Base URL在安卓网络环境下不可访问
- 请求超时（安卓网络较慢）

**检查方法**：
```gdscript
# 在memory_system.gd的get_embedding函数中
# 查看是否输出了错误信息
print("嵌入API返回错误 %d: %s" % [response_code, error_text])
```

**解决方案**：
1. 确认 `export_presets.cfg` 中：
   ```
   permissions/internet=true
   permissions/access_network_state=true
   ```

2. 检查 `user://ai_keys.json` 是否存在且包含：
   ```json
   {
     "embedding_model": {
       "model": "your-model",
       "base_url": "https://api.example.com/v1",
       "api_key": "your-api-key"
     }
   }
   ```

3. 增加超时时间（在 `ai_config.json` 中）：
   ```json
   "embedding_model": {
     "timeout": 60
   }
   ```

### 2. 记忆文件未同步 ⭐⭐⭐⭐

**症状**：
- 记忆库为空（memory_items.size() == 0）
- 检索时提示"记忆库为空"

**原因**：
- PC上生成的记忆数据没有传输到安卓
- 安卓上是全新安装，没有历史数据

**解决方案**：

方法1：使用adb传输
```bash
# 1. 在PC上找到记忆文件
# Windows: %APPDATA%\Godot\app_userdata\CABM-ED\memory_main_memory.json
# Linux: ~/.local/share/godot/app_userdata/CABM-ED/memory_main_memory.json

# 2. 传输到安卓
adb push memory_main_memory.json /sdcard/Download/

# 3. 在应用内移动文件（需要添加文件导入功能）
```

方法2：云同步（推荐）
- 实现一个云存储同步功能
- 在PC上上传记忆数据
- 在安卓上下载记忆数据

方法3：在安卓上重新生成
- 在安卓上进行对话
- 等待系统自动生成记忆数据

### 3. 配置文件路径问题 ⭐⭐⭐

**症状**：
- 配置加载失败
- API密钥为空

**原因**：
- `user://` 路径在不同平台上的实际位置不同
- 配置文件优先级：`user://ai_keys.json` > `res://config/ai_config.json`

**安卓路径**：
```
user:// = /data/data/cabm.ed/files/
```

**检查代码**（在 `memory_manager.gd` 的 `_load_config` 函数）：
```gdscript
# 优先读取用户配置
if FileAccess.file_exists(user_config_path):
    # 加载成功
else:
    # 回退到项目配置
```

**解决方案**：
1. 确保 `res://config/ai_config.json` 包含完整配置（作为备用）
2. 在首次运行时，从项目配置复制到用户配置
3. 添加配置检查和提示功能

### 4. 向量维度不匹配 ⭐⭐

**症状**：
- 检索时出现错误
- 相似度计算异常

**原因**：
- PC和安卓使用了不同的嵌入模型
- 配置中的 `vector_dim` 不一致

**检查**：
```gdscript
# 在memory_system.gd中
print("向量维度: ", vector.size())
print("配置维度: ", vector_dim)
```

**解决方案**：
- 确保两端使用相同的嵌入模型
- 统一 `vector_dim` 配置（通常是1024或768）

### 5. C++插件未编译 ⭐

**症状**：
- 日志显示"余弦计算插件未编译"
- 使用GDScript实现

**影响**：
- 不影响功能，只影响性能
- 在安卓上性能影响较小

**解决方案**：
- 可以忽略，GDScript实现足够使用
- 如需优化，为安卓平台编译C++插件

## 使用调试工具

### 快速集成

#### 方法1：添加到AutoLoad
1. 打开 `项目 -> 项目设置 -> AutoLoad`
2. 添加 `res://scripts/add_debug_button_helper.gd`
3. 命名为 `RAGDebugHelper`
4. 重启游戏，按F12打开调试面板

#### 方法2：手动添加按钮
在你的设置界面或主菜单中：

```gdscript
extends Control

func _ready():
	# 添加调试按钮（仅在调试模式或安卓平台）
	if OS.is_debug_build() or OS.get_name() == "Android":
		var debug_button = Button.new()
		debug_button.text = "RAG调试"
		debug_button.pressed.connect(_open_debug_panel)
		add_child(debug_button)

func _open_debug_panel():
	var panel = load("res://scenes/android_rag_debug_panel.tscn").instantiate()
	add_child(panel)
```

### 运行测试

1. **启动测试**
   - 点击"开始测试RAG系统"
   - 等待10-30秒

2. **查看结果**
   - ✓ 绿色勾：正常
   - ✗ 红色叉：错误
   - ⚠ 黄色警告：需要注意

3. **导出日志**
   - 点击"导出调试日志"
   - 日志保存位置会显示在界面上

### 日志分析示例

#### 正常情况
```
[2025-10-27 10:00:00] 1. 检查MemoryManager...
[2025-10-27 10:00:00]   ✓ MemoryManager已加载
[2025-10-27 10:00:00]   - 初始化状态: true
[2025-10-27 10:00:01] 5. 测试嵌入API...
[2025-10-27 10:00:02]   ✓ 嵌入API调用成功
[2025-10-27 10:00:02]   - 向量维度: 1024
[2025-10-27 10:00:03] 6. 测试检索...
[2025-10-27 10:00:04]   ✓ 检索成功
[2025-10-27 10:00:04]     结果1: 相似度=0.856, 文本=[10-27 09:30] 今天天气不错
```

#### API密钥问题
```
[2025-10-27 10:00:00] 2. 检查配置...
[2025-10-27 10:00:00]   - API密钥长度: 0
[2025-10-27 10:00:01] 5. 测试嵌入API...
[2025-10-27 10:00:02]   ✗ 嵌入API调用失败，返回空向量
[2025-10-27 10:00:02]   - 可能原因：
[2025-10-27 10:00:02]     1. API密钥未配置或错误
```

#### 网络问题
```
[2025-10-27 10:00:00] 5. 测试嵌入API...
[2025-10-27 10:00:30]   ✗ 嵌入API调用失败，返回空向量
[2025-10-27 10:00:30]   - 可能原因：
[2025-10-27 10:00:30]     2. Base URL不可访问
[2025-10-27 10:00:30]     3. 网络连接问题
```

#### 记忆库为空
```
[2025-10-27 10:00:00] 4. 检查记忆文件...
[2025-10-27 10:00:00]   ✗ 记忆文件不存在
[2025-10-27 10:00:01] 6. 测试检索...
[2025-10-27 10:00:01]   ⚠ 记忆库为空，无法测试检索
[2025-10-27 10:00:01]   - 建议：先在PC上使用一段时间，生成记忆数据
```

## 逐步排查流程

### 第一步：确认基础环境
- [ ] 安卓版本 ≥ 5.0
- [ ] 网络连接正常
- [ ] 应用有网络权限

### 第二步：检查配置
- [ ] API密钥已配置
- [ ] Base URL正确
- [ ] 嵌入模型名称正确

### 第三步：测试网络
- [ ] 在浏览器中访问Base URL
- [ ] 使用Postman测试API
- [ ] 确认API密钥有效

### 第四步：运行调试工具
- [ ] 安装带调试功能的APK
- [ ] 运行RAG系统测试
- [ ] 导出并分析日志

### 第五步：针对性修复
根据日志中的错误信息，采取相应措施。

## 临时绕过方案

如果短期内无法解决，可以：

### 方案1：禁用长期记忆
修改 `ai_config.json`：
```json
"memory": {
  "vector_db": {
    "enable": false
  }
}
```

### 方案2：增加短期记忆容量
```json
"memory": {
  "max_memory_items": 30,
  "max_conversation_history": 20
}
```

### 方案3：使用本地嵌入
如果有本地推理能力（如ONNX Runtime）：
- 部署本地嵌入模型
- 修改 `get_embedding` 函数调用本地模型
- 避免网络请求

## 预防措施

### 开发阶段
1. 在多个安卓设备上测试
2. 使用真实网络环境（非模拟器）
3. 添加详细的错误日志
4. 实现配置验证功能

### 发布阶段
1. 提供配置向导
2. 添加网络诊断工具
3. 实现数据同步功能
4. 提供离线模式

## 获取帮助

如果问题仍未解决，请提供以下信息：

1. **完整的调试日志**
   - 从"开始测试"到"测试完成"的全部输出

2. **配置信息**（隐藏敏感数据）
   ```json
   {
     "embedding_model": {
       "model": "text-embedding-3-large",
       "base_url": "https://api.xxx.com/v1",
       "api_key": "sk-***",
       "vector_dim": 1024
     }
   }
   ```

3. **设备信息**
   - 安卓版本
   - 设备型号
   - 网络类型（WiFi/4G/5G）

4. **复现步骤**
   - 详细描述如何触发问题
   - 是否每次都出现

5. **PC上的表现**
   - PC上是否正常
   - PC上的记忆数据量
