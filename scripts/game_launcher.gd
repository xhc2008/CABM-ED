extends Node

# 游戏启动器 - 检查存档并决定进入开场还是主游戏

func _ready():
	# 检查存档是否存在
	if _has_save_file():
		print("检测到存档，直接进入游戏")
		_load_main_game()
	else:
		print("首次进入游戏，播放开场动画")
		_load_intro_story()

func _has_save_file() -> bool:
	"""检查是否存在存档文件"""
	var save_path = "user://saves/save_slot_1.json"
	return FileAccess.file_exists(save_path)

func _load_intro_story():
	"""加载开场故事场景"""
	get_tree().change_scene_to_file("res://scenes/intro_scene.tscn")

func _load_main_game():
	"""加载主游戏场景"""
	get_tree().change_scene_to_file("res://scripts/main.tscn")
