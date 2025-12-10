extends Node

# 游戏启动器 - 检查存档并决定进入开场还是主游戏

func _ready():
	var res_ready := false
	res_ready = true #跳过检查
	if has_node("/root/SaveManager"):
		res_ready = get_node("/root/SaveManager").is_resources_ready()
	if not res_ready:
		print("资源未准备，进入资源下载页面")
		_load_resource_download.call_deferred()
		return

	# 检查存档是否存在
	if _has_save_file():
		print("检测到存档，直接进入游戏")
		_load_main_game.call_deferred()
	else:
		print("首次进入游戏，播放开场动画")
		_load_intro_story.call_deferred()

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

func _load_resource_download():
	"""加载资源下载页面"""
	get_tree().change_scene_to_file("res://scenes/resource_download.tscn")
