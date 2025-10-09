# 图片存放说明

请将你的图片素材放在这里，**按场景ID → 天气ID组织，每个天气包含三个时间段**：

```
images/
├── livingroom/         # 场景ID（客厅）
│   ├── sunny/         # 天气ID（晴天）
│   │   ├── day.png   # 白天
│   │   ├── dusk.png  # 傍晚
│   │   └── night.png # 夜晚
│   ├── rainy/        # 雨天
│   │   ├── day.png
│   │   ├── dusk.png
│   │   └── night.png
│   └── storm/        # 雷雨
│       ├── day.png
│       ├── dusk.png
│       └── night.png
├── bedroom/           # 场景ID（卧室）
│   └── sunny/
│       ├── day.png
│       ├── dusk.png
│       └── night.png
```

## 支持的图片格式

- GIF（动图）
- PNG / APNG
- JPG / JPEG
- WebP（包括动态 WebP）
- MP4（视频）

## 时间段说明

- **day.png**：白天（6:00-17:00）
- **dusk.png**：傍晚（17:00-19:00）和凌晨（0:00-6:00）
- **night.png**：夜晚（19:00-24:00）

## 当前状态

如果你看到这个文件，说明图片目录已经创建成功。
请按照上述结构创建天气文件夹并放入对应的图片文件。

## 测试

你可以先创建 `livingroom/sunny/` 文件夹，放入三张测试图片（day.png、dusk.png、night.png）来测试功能。
