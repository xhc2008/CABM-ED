from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import json
import os
import sys
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# 设置控制台编码为 UTF-8
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

app = FastAPI(title="Atmosphere Viewer API")

# CORS 配置 - 允许局域网访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有来源（局域网访问）
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件服务 - 使用绝对路径
static_images_path = os.path.join(os.path.dirname(__file__), "..", "static", "images")
static_audio_path = os.path.join(os.path.dirname(__file__), "..", "static", "audio")

if os.path.exists(static_images_path):
    app.mount("/images", StaticFiles(directory=static_images_path), name="images")
else:
    print(f"警告: 静态图片目录不存在: {static_images_path}")

if os.path.exists(static_audio_path):
    app.mount("/audio", StaticFiles(directory=static_audio_path), name="audio")
else:
    print(f"警告: 静态音频目录不存在: {static_audio_path}")

@app.get("/")
def read_root():
    return {"message": "Atmosphere Viewer API"}

@app.get("/api/scenes")
def get_scenes():
    """获取所有场景和天气数据"""
    # 从配置文件读取或返回默认数据
    config_path = os.path.join(os.path.dirname(__file__), "..", "config", "scenes.json")
    
    if os.path.exists(config_path):
        with open(config_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
            # 自动构建完整的图片和音频路径
            for scene in data.get("scenes", []):
                scene_id = scene.get("id")
                for weather in scene.get("weathers", []):
                    weather_id = weather.get("id")
                    for time in weather.get("times", []):
                        # 处理图片路径: /images/{场景ID}/{天气ID}/{时间段}.png
                        image = time.get("image", "")
                        if image and not image.startswith("/"):
                            time["image"] = f"/images/{scene_id}/{weather_id}/{image}"
                        
                        # 处理音频路径: /audio/{场景ID}/{天气ID}/{时间段}.mp3
                        audio = time.get("audio", "")
                        if audio and not audio.startswith("/"):
                            time["audio"] = f"/audio/{scene_id}/{weather_id}/{audio}"
            
            return data
    
    # 默认数据
    return {
        "scenes": [
            {
                "id": "scene1",
                "name": "场景 1",
                "weathers": [
                    {
                        "id": "sunny",
                        "name": "晴天",
                        "times": [
                            {
                                "id": "day",
                                "name": "白天",
                                "image": "day.png",
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
        ]
    }

if __name__ == "__main__":
    import uvicorn
    
    # 从环境变量读取配置
    host = os.getenv("BACKEND_HOST", "0.0.0.0")
    port = int(os.getenv("BACKEND_PORT", "8000"))
    
    print("=" * 50)
    print("后端服务器启动中...")
    print(f"静态图片路径: {static_images_path}")
    print(f"静态音频路径: {static_audio_path}")
    print(f"API 地址: http://localhost:{port}")
    print(f"API 文档: http://localhost:{port}/docs")
    print(f"监听地址: {host}:{port}")
    print("=" * 50)
    uvicorn.run(app, host=host, port=port)
