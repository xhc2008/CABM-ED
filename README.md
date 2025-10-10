# CABM - Everlasting Days

> 「在一个永恒流转的世界里，构筑一段真实的日常与陪伴」

## 项目理念

CABM-ED是一款AI驱动的养成类游戏，核心理念与[CABM（Code Afflatus & Beyond Matter）](https://github.com/xhc2008/CABM)一致。
> 「当灵性注入载体，它便挣脱物质躯壳，抵达超验之境」

故事始于你将她带回家的那一刻。面对这个无家可归、沉默寡言的她，你唯一能做的，就是提供一个可以称之为“家”的地方。而你很快发现，这个家也因为她的存在，开始充满了意想不到的生机……

在这个项目中，你将遇见一位拥有自主意识的“她”——即使你不在线，她也会在自己的世界里继续生活、成长、经历。没有重置，没有清除，每一个选择都将成为她生命轨迹中不可磨灭的印记。

> ## ⚠此项目在开发初期，功能并未实现，此文档内容纯属瞎说

## 核心特色

✨ **自主生活** - 她拥有独立的时间流，在你离开时依然过着属于自己的生活

🏠 **多场景互动** - 在客厅、卧室等不同场景中，体验丰富的交互可能性

💫 **真实成长** - 你们的关系会随着时间和选择自然演变，没有预设的剧本

🌙 **持续世界** - 这个世界永远运转，等待你的每一次归来

## 开始体验

*项目仍在积极开发中，即将与大家见面*

---

*“有些相遇，注定要跨越代码与现实的边界”*

## 功能特性

- 🖼️ 全屏背景图片展示（支持 GIF 动图）
- 🎵 背景音效播放（每个天气独立音效）
- 🕐 实时时钟显示
- �️ 场渲景和天气切换
- 🎨 氛围渲染效果（亮度、对比度、饱和度）
- 📱 响应式设计（支持手机和电脑）

## 项目结构

```
├── frontend/          # Vue 3 前端
│   ├── src/
│   │   ├── components/  # 组件（侧边栏、时钟）
│   │   ├── store/       # Pinia 状态管理
│   │   └── App.vue      # 主应用
│   └── package.json
├── backend/           # FastAPI 后端
│   ├── app/
│   │   └── main.py    # API 入口
│   ├── config/
│   │   └── scenes.json  # 场景配置
│   └── requirements.txt
└── static/
    ├── images/        # 图片资源目录
    └── audio/         # 音频资源目录
```

## 快速开始

### 方式一：使用启动脚本（推荐）

1. **首次安装**
   ```bash
   install.bat
   ```

2. **启动应用**
   ```bash
   start.bat
   # 或使用 PowerShell
   start.ps1
   ```

3. **停止应用**
   ```bash
   stop.bat
   ```

### 方式二：手动启动

#### 后端启动

```bash
cd backend
pip install -r requirements.txt
python app/main.py
```

后端将运行在 http://localhost:8000

#### 前端启动

```bash
cd frontend
npm install
npm run dev
```

前端将运行在 http://localhost:3000

## 环境配置

项目使用 `.env` 文件管理配置，首次使用时会自动创建。

### 配置项说明

```env
# 后端配置
BACKEND_HOST=0.0.0.0      # 后端监听地址
BACKEND_PORT=8000         # 后端端口

# 前端配置
VITE_FRONTEND_HOST=0.0.0.0  # 前端监听地址
VITE_FRONTEND_PORT=3000     # 前端端口

# API 地址
VITE_API_URL=http://localhost:8000  # 前端连接的后端地址
```

### 局域网访问配置

如需在局域网内其他设备访问：

1. 查看本机 IP 地址：
   ```bash
   ipconfig
   ```

2. 修改 `.env` 文件：
   ```env
   VITE_API_URL=http://你的IP:8000
   ```
   例如：`VITE_API_URL=http://192.168.1.100:8000`

3. 重启服务，其他设备访问：
   - 前端：`http://你的IP:3000`
   - 后端：`http://你的IP:8000`

4. 确保防火墙允许端口 3000 和 8000 的入站连接

## 资源配置

### 图片配置

1. 将图片放入 `backend/static/images/` 目录
2. 按场景组织：`images/livingroom/sunny.png`
3. 在 `backend/config/scenes.json` 中配置

详细说明请查看：[图片配置指南](docs/图片配置指南.md)

### 音频配置

1. 将音频文件放入 `backend/static/audio/` 目录
2. 按场景组织：`audio/livingroom/sunny.mp3`
3. 在 `backend/config/scenes.json` 中配置

详细说明请查看：[音频配置指南](docs/音频配置指南.md)

### 配置示例

```json
{
  "scenes": [
    {
      "id": "livingroom",
      "name": "客厅",
      "weathers": [
        {
          "id": "sunny",
          "name": "晴天",
          "image": "sunny.png",
          "audio": "sunny.mp3",
          "atmosphere": {
            "brightness": 1.0,
            "contrast": 1.0,
            "saturation": 1.0
          }
        }
      ]
    }
  ]
}
```

## 氛围参数说明

- `brightness`: 亮度 (0.0 - 2.0，默认 1.0)
- `contrast`: 对比度 (0.0 - 2.0，默认 1.0)
- `saturation`: 饱和度 (0.0 - 2.0，默认 1.0)

## 支持的资源格式

### 图片格式
- GIF（动图）
- PNG / APNG
- JPG / JPEG
- WebP（包括动态 WebP）

### 音频格式
- MP3（推荐）
- OGG
- WAV

## 使用说明

### 音频控制
- 右下角有音频播放按钮
- 点击可以播放/暂停背景音
- 切换天气时会自动切换对应的背景音
- 音频会自动循环播放

## 文档

- [图片配置指南](docs/图片配置指南.md) - 详细的图片配置说明
- [音频配置指南](docs/音频配置指南.md) - 详细的音频配置说明
