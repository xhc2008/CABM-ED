# 心情系统测试指南

## 准备工作

### 1. 准备图片资源

在 `assets/images/character/chat/` 目录下至少需要：
- `normal.png` - 必需（默认图片）
- 其他心情图片（可选，如果没有会回退到normal.png）

**临时测试方案：**
如果还没有所有心情图片，可以先复制 `normal.png` 为其他名称：
```bash
# Windows CMD
cd assets\images\character\chat
copy normal.png happy.png
copy normal.png sad.png
copy normal.png angry.png
copy normal.png surprised.png
copy normal.png scared.png
copy normal.png disgusted.png
```

### 2. 检查配置文件

确认 `config/mood_config.json` 存在且格式正确。

## 测试步骤

### 测试1: 心情配置加载

1. 启动游戏
2. 查看Godot控制台
3. 应该看到类似输出：
   ```
   AI 配置加载成功
   ```

### 测试2: 初始心情图片

1. 点击角色进入对话
2. 观察角色图片
3. 应该显示当前心情对应的图片
4. 查看控制台：
   ```
   加载心情图片: res://assets/images/character/chat/normal.png
   ```

### 测试3: AI响应和字段提取

1. 发送一条消息给角色
2. 等待AI响应
3. 查看控制台输出：
   ```
   接收到内容块: ...
   发送新内容: ...
   流式响应完成，完整内容: {"mood": 1, "msg": "...", "will": 5, "like": 3}
   提取的字段: {mood: 1, will: 5, like: 3}
   更新心情: happy
   更新互动意愿: 50 -> 55 (增量: 5)
   更新好感度: 30 -> 33 (增量: 3)
   切换心情图片: res://assets/images/character/chat/happy.png
   ```

### 测试4: 心情图片切换

1. 继续对话，发送不同类型的消息
2. 观察角色图片是否随心情变化
3. 图片应该立即切换（无动画）

**测试消息建议：**
- "你好" - 可能触发开心（happy）
- "我讨厌你" - 可能触发生气（angry）或难过（sad）
- "突然出现！" - 可能触发惊讶（surprised）

### 测试5: 侧边栏显示

1. 对话过程中观察左侧边栏
2. 心情、好感度、互动意愿应该实时更新
3. 心情文本应该显示中文（如"开心"）
4. 颜色应该根据配置文件变化
5. 确认只显示：好感度、交互意愿、心情（精力和信任已移除）

### 测试6: 多轮对话

1. 进行3-5轮对话
2. 每次响应后检查：
   - 心情是否更新
   - 好感度是否变化
   - 互动意愿是否变化
   - 图片是否正确切换

### 测试7: 对话结束

1. 点击"结束"按钮
2. 角色应该消失并返回场景
3. 再次点击角色进入对话
4. 应该显示最新的心情图片

## 验证清单

- [ ] 配置文件正确加载
- [ ] 初始心情图片正确显示
- [ ] AI响应包含mood, will, like字段
- [ ] 字段被正确提取
- [ ] SaveManager数据被更新
- [ ] 心情图片实时切换
- [ ] 侧边栏实时更新（每次AI响应后）
- [ ] 侧边栏只显示3项：好感度、交互意愿、心情
- [ ] 多轮对话稳定工作
- [ ] 对话结束后状态保持

## 查看日志

### AI日志
位置：`%APPDATA%\Godot\app_userdata\CABM-ED\ai_logs\log.txt`

运行：`view_ai_log.bat`

**检查内容：**
- 响应是否包含完整JSON
- mood, will, like字段是否存在
- 值是否在合理范围内

### 存档数据
位置：`%APPDATA%\Godot\app_userdata\CABM-ED\saves/`

**检查内容：**
```json
{
	"character_data": {
		"mood": "happy",
		"affection": 33,
		"reply_willingness": 55
	}
}
```

## 常见问题排查

### 问题1: 控制台显示"心情图片不存在"

**原因：** 图片文件缺失

**解决：**
1. 检查 `assets/images/character/chat/` 目录
2. 确认对应的图片文件存在
3. 或者复制 `normal.png` 为缺失的文件名

### 问题2: 提取的字段为空

**原因：** AI没有返回JSON格式或格式错误

**解决：**
1. 查看AI日志中的完整响应
2. 检查是否有 ```json``` 包裹
3. 确认system_prompt包含JSON格式要求
4. 查看控制台的"JSON解析失败"错误

### 问题3: 心情不更新

**原因：** mood字段值不在0-6范围内

**解决：**
1. 查看控制台的"提取的字段"输出
2. 检查mood值是否为整数
3. 确认mood_config.json包含对应ID

### 问题4: 好感度/意愿变化异常

**原因：** will/like增量过大

**解决：**
1. 检查AI返回的增量值
2. 确认在-10到10范围内
3. 可能需要调整system_prompt的说明

### 问题5: 侧边栏显示英文

**原因：** mood_config.json加载失败

**解决：**
1. 检查配置文件是否存在
2. 验证JSON格式是否正确
3. 查看控制台错误信息

## 性能测试

### 长时间对话测试
1. 进行10轮以上对话
2. 观察内存使用
3. 检查是否有卡顿
4. 确认图片切换流畅

### 快速切换测试
1. 快速发送多条消息
2. 观察心情切换是否正常
3. 检查是否有图片加载延迟

## 调试技巧

### 强制设置心情
在Godot控制台执行：
```gdscript
get_node("/root/SaveManager").set_mood("happy")
```

### 查看当前状态
```gdscript
var sm = get_node("/root/SaveManager")
print("心情: ", sm.get_mood())
print("好感度: ", sm.get_affection())
print("意愿: ", sm.get_reply_willingness())
```

### 模拟字段提取
```gdscript
var ai = get_node("/root/AIService")
ai.extracted_fields = {"mood": 1, "will": 5, "like": 3}
ai._apply_extracted_fields()
```

## 成功标准

系统正常工作应该满足：
1. ✅ 所有心情图片正确加载
2. ✅ AI响应包含所有必需字段
3. ✅ 字段值在合理范围内
4. ✅ 图片切换即时无延迟
5. ✅ 侧边栏显示准确
6. ✅ 数据持久化到存档
7. ✅ 多轮对话稳定
8. ✅ 无内存泄漏或性能问题
