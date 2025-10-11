# CABM-ED

Godot 场景背景切换项目

## 项目结构

```
CABM-ED/
├── assets/              # 资源文件夹
│   ├── images/         # 图片素材（按场景/天气/时间组织）
│   └── audio/          # 音频素材
├── config/             # 配置文件
│   └── scenes.json     # 场景配置（可选，目前在代码中硬编码）
├── scripts/            # 代码文件夹
│   ├── main.tscn      # 主场景
│   ├── main.gd        # 主场景脚本
│   └── sidebar.gd     # 侧边栏脚本
└── project.godot       # Godot 项目配置
```

## 图片组织结构

```
assets/images/
└── [场景ID]/
    └── [天气ID]/
        ├── day.png    # 白天
        ├── dusk.png   # 傍晚
        └── night.png  # 夜晚
```

## 使用说明

1. 在 Godot 编辑器中打开项目
2. 按 F5 运行
3. 点击左侧面板切换场景和天气
4. 点击 ◀/▶ 按钮展开/收起侧边栏

## 添加新场景

在 `scripts/sidebar.gd` 的 `scenes` 字典中添加：

```gdscript
var scenes = {
    "livingroom": {
        "name": "客厅",
        "weathers": {"sunny": "晴天", "rainy": "雨天", "storm": "雷雨"}
    },
    "bedroom": {
        "name": "卧室",
        "weathers": {"sunny": "晴天"}
    }
}
```

然后在 `assets/images/` 下创建对应的文件夹和图片。
