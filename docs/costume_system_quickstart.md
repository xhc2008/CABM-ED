# 服装系统快速入门

## 如何使用

1. **启动游戏**
2. **进入浴室场景**（通过侧边栏或场景菜单）
3. **点击右下角的换装按钮**（👗 换装）
4. **选择想要的服装**
5. **完成！**角色立绘会立即更新

## 如何添加新服装

### 第一步：准备图片

创建以下目录结构：

```
assets/images/character/
└── 你的服装id/          # 例如：summer
    ├── livingroom/       # 客厅立绘
    │   ├── 1.png
    │   ├── 2.png
    │   └── ...
    ├── bedroom/          # 卧室立绘
    │   └── 1.png
    ├── bathroom/         # 浴室立绘
    │   └── 1.png
    ├── studyroom/        # 书房立绘
    │   ├── 1.png
    │   └── 2.png
    ├── kitchen/          # 厨房立绘
    │   └── 1.png
    ├── rooftop/          # 天台立绘
    │   ├── 1.png
    │   └── 2.png
    └── chat/             # 聊天表情（必须包含所有11个）
        ├── normal.png
        ├── happy.png
        ├── sad.png
        ├── angry.png
        ├── surprised.png
        ├── scared.png
        ├── disgusted.png
        ├── worried.png
        ├── shy.png
        ├── doubtful.png
        └── speechless.png
```

### 第二步：创建配置文件

在 `config/character_presets/` 目录下创建 `你的服装id.json`：

```json
{
  "id": "summer",
  "name": "夏日服装",
  "description": "清凉的夏装",
  "livingroom": [
    {
      "des": "趴在沙发上玩游戏",
      "image": "1.png",
      "scale": 0.9,
      "position": {
        "x": 0.63,
        "y": 0.59
      }
    }
  ],
  "bedroom": [
    {
      "des": "趴在床上看手机",
      "image": "1.png",
      "scale": 0.6,
      "position": {
        "x": 0.64,
        "y": 0.73
      }
    }
  ],
  "bathroom": [
    {
      "des": "照镜子",
      "image": "1.png",
      "scale": 1.0,
      "position": {
        "x": 0.45,
        "y": 0.78
      }
    }
  ],
  "studyroom": [
    {
      "des": "坐在地上看书",
      "image": "1.png",
      "scale": 0.6,
      "position": {
        "x": 0.75,
        "y": 0.82
      }
    }
  ],
  "kitchen": [
    {
      "des": "在灶台边思考",
      "image": "1.png",
      "scale": 0.7,
      "position": {
        "x": 0.70,
        "y": 0.75
      }
    }
  ],
  "rooftop": [
    {
      "des": "看风景",
      "image": "1.png",
      "scale": 0.75,
      "position": {
        "x": 0.19,
        "y": 0.73
      }
    }
  ]
}
```

**重要提示**：
- `id` 必须与文件名一致（不含.json）
- `id` 必须与图片目录名一致
- 每个场景至少要有一个预设
- `position.x` 和 `position.y` 是相对位置（0.0-1.0）
- `scale` 是缩放比例

### 第三步：测试

1. 启动游戏
2. 进入浴室
3. 点击换装按钮
4. 应该能看到你的新服装
5. 选择后检查各个场景的显示效果

## 常见问题

### Q: 为什么我的服装没有显示？

A: 检查以下几点：
- 配置文件的 `id` 是否与文件名和图片目录名一致
- 所有场景的图片是否都存在
- 聊天表情的11个图片是否齐全
- JSON格式是否正确（可以用在线JSON验证工具检查）

### Q: 如何调整角色在场景中的位置？

A: 修改配置文件中的 `position` 和 `scale` 值：
- `position.x`: 0.0（最左）到 1.0（最右）
- `position.y`: 0.0（最上）到 1.0（最下）
- `scale`: 建议范围 0.5 到 1.5

### Q: 可以删除默认服装吗？

A: 不建议删除，因为它是回退选项。如果当前服装配置出错，系统会自动使用默认服装。

### Q: 换装后聊天表情没有变化？

A: 确保新服装的 `chat/` 目录包含所有11个心情图片，文件名必须完全一致。

## 技巧

1. **复制默认配置**：创建新服装时，复制 `default.json` 作为模板，只修改 `id`、`name` 和需要调整的位置参数。

2. **批量调整位置**：如果所有场景的角色都需要整体移动，可以统一调整所有 `position` 值。

3. **保持比例**：如果新立绘的尺寸与默认立绘差异较大，记得调整 `scale` 值以保持合适的显示效果。

4. **测试所有场景**：添加新服装后，建议在所有场景中测试一遍，确保显示效果符合预期。
