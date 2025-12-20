extends Node
class_name AdventureAI

signal reply_ready(text: String)

func request_reply(prompt: String) -> void:
	await get_tree().create_timer(0.8).timeout
	reply_ready.emit("这是一个测试回复，用于验证聊天功能。")
