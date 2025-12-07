# AI 配置管理模块
# 负责：配置的加载、保存、迁移等

extends Node

const CONFIG_PATH = "user://ai_keys.json"
const OLD_CONFIG_PATH = "user://api_keys.json"

# 配置模板定义
const CONFIG_TEMPLATES = {
    "free": {
        "name": "免费",
        "description": "没有语音，而且有点不太聪明的样子，但是免费",
        "chat_model": {
            "model": "Qwen/Qwen3-8B",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "summary_model": {
            "model": "Qwen/Qwen3-8B",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "tts_model": {
            "model": "【DISABLED】",
            "base_url": "【DISABLED】",
        },
        "embedding_model": {
            "model": "BAAI/bge-m3",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "view_model": {
            "model": "THUDM/GLM-4.1V-9B-Thinking",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "stt_model": {
            "model": "FunAudioLLM/SenseVoiceSmall",
            "base_url": "https://api.siliconflow.cn/v1"
        }
    },
    "standard": {
        "name": "标准",
        "description": "支持语音，以高性价比获得更佳的体验",
        "chat_model": {
            "model": "deepseek-ai/DeepSeek-V3.2",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "summary_model": {
            "model": "Qwen/Qwen3-30B-A3B-Instruct-2507",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "tts_model": {
            "model": "FunAudioLLM/CosyVoice2-0.5B",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "embedding_model": {
            "model": "BAAI/bge-m3",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "view_model": {
            "model": "Qwen/Qwen3-Omni-30B-A3B-Captioner",
            "base_url": "https://api.siliconflow.cn/v1"
        },
        "stt_model": {
            "model": "FunAudioLLM/SenseVoiceSmall",
            "base_url": "https://api.siliconflow.cn/v1"
        }
    }
}

## 加载现有配置
func load_config() -> Dictionary:
    if not FileAccess.file_exists(CONFIG_PATH):
        migrate_old_config()
        return {}
    
    var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file == null:
        return {}
    
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    if json.parse(json_string) != OK:
        return {}
    
    return json.data as Dictionary

## 从旧的api_keys.json迁移配置
func migrate_old_config() -> void:
    if not FileAccess.file_exists(OLD_CONFIG_PATH):
        return
    
    var file = FileAccess.open(OLD_CONFIG_PATH, FileAccess.READ)
    if file == null:
        return
    
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    if json.parse(json_string) != OK:
        return
    
    var old_config = json.data
    if old_config.has("openai_api_key"):
        var new_config = {
            "api_key": old_config.openai_api_key
        }
        save_config(new_config)

## 保存配置到文件
func save_config(config: Dictionary) -> bool:
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file == null:
        return false
    
    file.store_string(JSON.stringify(config, "\t"))
    file.close()
    
    print("AI配置已保存")
    return true

## 获取模板配置
func get_template(template_name: String) -> Dictionary:
    if CONFIG_TEMPLATES.has(template_name):
        return CONFIG_TEMPLATES[template_name]
    return {}

## 获取所有模板
func get_all_templates() -> Dictionary:
    return CONFIG_TEMPLATES

## 验证API密钥
func verify_api_key(input_key: String) -> bool:
    if not FileAccess.file_exists(CONFIG_PATH):
        return false
    
    var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    if json.parse(json_string) != OK:
        return false
    
    var config = json.data
    
    # 检查 chat_model 的 api_key
    if config.has("chat_model") and config.chat_model.has("api_key"):
        if config.chat_model.api_key == input_key:
            return true
    
    # 检查快速配置的 api_key
    if config.has("api_key"):
        if config.api_key == input_key:
            return true
    
    return false

## 加载特定模型的配置
func load_model_config(model_type: String) -> Dictionary:
    var config = load_config()
    
    if config.has(model_type):
        return config[model_type] as Dictionary
    
    return {}

## 保存响应模式
func save_response_mode(mode: String) -> bool:
    var config = load_config()
    config["response_mode"] = mode
    return save_config(config)

## 加载响应模式
func load_response_mode() -> String:
    var config = load_config()
    return config.get("response_mode", "verbal")

## 遮蔽密钥显示
func mask_key(key: String) -> String:
    if key.length() <= 10:
        return "***"
    return key.substr(0, 7) + "..." + key.substr(key.length() - 4)
