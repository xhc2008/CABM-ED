# 角色立绘目录

## 目录结构

每个服装对应一个子目录，目录名必须与配置文件中的 `id` 字段一致。

```
character/
├── default/              # 默认服装
│   ├── livingroom/       # 客厅场景立绘
│   ├── bedroom/          # 卧室场景立绘
│   ├── bathroom/         # 浴室场景立绘
│   ├── studyroom/        # 书房场景立绘
│   ├── kitchen/          # 厨房场景立绘
│   ├── rooftop/          # 天台场景立绘
│   └── chat/             # 聊天表情立绘
├── costume2/             # 其他服装
│   └── ...
└── ...
```

## 场景立绘

每个场景目录下可以包含多个立绘文件（1.png, 2.png, ...），对应配置文件中的不同预设位置。

## 聊天表情立绘

`chat/` 目录必须包含以下文件：
- `normal.png` - 平静
- `happy.png` - 开心
- `sad.png` - 难过
- `angry.png` - 生气
- `surprised.png` - 惊讶
- `scared.png` - 害怕
- `disgusted.png` - 厌恶
- `worried.png` - 担心
- `shy.png` - 害羞
- `doubtful.png` - 疑惑
- `speechless.png` - 无语

这些文件会在聊天时根据角色的心情自动切换。
