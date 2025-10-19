# 日记功能架构说明

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                         游戏主场景                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Sidebar    │  │  Character   │  │ ChatDialog   │      │
│  │  (场景选择)   │  │   (角色)     │  │  (对话框)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
│  ┌──────────────┐                    ┌──────────────┐      │
│  │DiaryButton   │                    │DiaryViewer   │      │
│  │(仅卧室显示)   │ ──点击──>         │ (日记查看器)  │      │
│  └──────────────┘                    └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 对话结束
                          ▼
                  ┌───────────────┐
                  │  AIService    │
                  │ (AI服务单例)   │
                  └───────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
                ▼                   ▼
        ┌──────────────┐    ┌──────────────┐
        │ 总结模型      │    │ 完整对话      │
        │ (原有功能)    │    │ (新增功能)    │
        └──────────────┘    └──────────────┘
                │                   │
                ▼                   ▼
        ┌──────────────┐    ┌──────────────┐
        │user://       │    │user://diary/ │
        │ai_storage/   │    │YYYY-MM-DD    │
        │permanent_    │    │.jsonl        │
        │memory.jsonl  │    │              │
        └──────────────┘    └──────────────┘
```

## 数据流程

### 1. 对话进行中
```
用户输入 ──> ChatDialog ──> AIService ──> AI API
                                  │
                                  ▼
                          current_conversation
                          (临时存储在内存)
```

### 2. 对话结束时
```
结束聊天 ──> AIService.end_chat()
                  │
                  ├──> _call_summary_api()
                  │         │
                  │         ▼
                  │    总结模型处理
                  │         │
                  │         ▼
                  │    _save_memory()
                  │         │
                  │         ├──> 存档系统
                  │         └──> permanent_memory.jsonl
                  │
                  └──> _save_full_conversation_to_diary()
                            │
                            ▼
                       diary/YYYY-MM-DD.jsonl
```

### 3. 查看日记时
```
点击日记按钮 ──> DiaryButton.diary_button_clicked
                      │
                      ▼
                Main._on_diary_button_clicked()
                      │
                      ▼
                DiaryViewer.show_diary()
                      │
                      ├──> _load_available_dates()
                      │         │
                      │         ▼
                      │    扫描 diary/ 目录
                      │         │
                      │         ▼
                      │    获取所有日期列表
                      │
                      └──> _load_date_content(date)
                                │
                                ▼
                          读取 JSONL 文件
                                │
                                ▼
                          _display_more_messages()
                                │
                                ▼
                          显示对话内容
```

## 场景显示逻辑

```
场景切换事件
    │
    ▼
Main.load_scene(scene_id)
    │
    ├──> 加载场景图片
    ├──> 更新角色位置
    ├──> 更新UI布局
    │
    └──> _update_diary_button_visibility()
              │
              ├──> if scene_id == "bedroom":
              │         diary_button.show_button()
              │
              └──> else:
                        diary_button.hide_button()
```

## 文件结构

```
项目根目录/
├── scripts/
│   ├── ai_service.gd          (修改：添加日记保存)
│   ├── main.gd                (修改：集成日记功能)
│   ├── diary_viewer.gd        (新增：日记查看器)
│   └── diary_button.gd        (新增：日记按钮)
│
├── scripts/
│   └── main.tscn              (修改：添加UI节点)
│
└── docs/
    ├── diary_feature.md       (功能说明)
    ├── diary_testing_guide.md (测试指南)
    └── diary_architecture.md  (本文件)

用户数据目录 (user://)/
├── diary/
│   ├── 2024-01-01.jsonl
│   ├── 2024-01-02.jsonl
│   └── 2024-01-03.jsonl
│
└── ai_storage/
    └── permanent_memory.jsonl
```

## 关键类和方法

### AIService (scripts/ai_service.gd)
```gdscript
# 新增方法
func _save_full_conversation_to_diary()
    - 获取当前日期
    - 构建对话记录JSON
    - 追加到日期对应的JSONL文件

# 修改方法
func _save_memory(summary: String)
    - 原有逻辑保持不变
    - 新增：调用 _save_full_conversation_to_diary()
```

### DiaryViewer (scripts/diary_viewer.gd)
```gdscript
# 主要方法
func show_diary()
    - 加载可用日期列表
    - 显示最新日期的内容
    - 播放展开动画

func _load_available_dates()
    - 扫描 diary/ 目录
    - 获取所有 .jsonl 文件
    - 按日期降序排序

func _load_date_content(date_str: String)
    - 读取指定日期的JSONL文件
    - 解析所有对话记录
    - 显示第一页内容

func _display_more_messages()
    - 分页加载消息（每次20条）
    - 创建UI元素显示对话
    - 更新已显示计数

func _on_scroll_changed()
    - 检测滚动到顶部
    - 自动加载更多旧消息
    - 保持滚动位置
```

### DiaryButton (scripts/diary_button.gd)
```gdscript
# 主要方法
func show_button()
    - 淡入动画
    - 设置可见状态

func hide_button()
    - 淡出动画
    - 隐藏按钮
```

### Main (scripts/main.gd)
```gdscript
# 新增方法
func _update_diary_button_layout()
    - 计算按钮位置（场景左下角）
    - 更新按钮坐标

func _update_diary_viewer_layout()
    - 计算查看器位置（场景中央）
    - 更新查看器坐标

func _update_diary_button_visibility()
    - 检查当前场景
    - 显示/隐藏日记按钮

func _on_diary_button_clicked()
    - 打开日记查看器

func _on_diary_closed()
    - 日记查看器关闭回调
```

## 性能考虑

### 内存优化
- **分页加载**：每次只加载20条消息，避免一次性加载大量数据
- **按需读取**：只在打开日记时读取文件，不常驻内存
- **JSONL格式**：逐行读取，不需要解析整个文件

### 存储优化
- **按日期分文件**：避免单个文件过大
- **追加写入**：使用JSONL格式，支持高效追加
- **独立存储**：不影响存档系统的大小

### UI优化
- **虚拟滚动**：只渲染可见区域的消息
- **延迟加载**：滚动到顶部时才加载更多
- **动画流畅**：使用Tween实现平滑动画

## 扩展性

### 可能的扩展方向

1. **搜索功能**
   - 添加搜索框
   - 支持关键词搜索
   - 高亮显示匹配结果

2. **导出功能**
   - 导出为TXT文本
   - 导出为PDF文档
   - 导出为HTML网页

3. **统计功能**
   - 对话次数统计
   - 对话时长统计
   - 词频分析

4. **标签系统**
   - 为对话添加标签
   - 按标签筛选
   - 标签云显示

5. **情感分析**
   - 分析对话情感倾向
   - 显示情感曲线图
   - 情感统计报告

6. **备份和同步**
   - 云端备份
   - 多设备同步
   - 导入/导出功能
