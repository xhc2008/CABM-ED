extends Node

# 音频播放器
var bgm_player: AudioStreamPlayer

# 音频配置
var audio_config: Dictionary = {}

# 当前播放状态
var current_scene: String = ""
var current_time: String = ""
var current_weather: String = ""

func _ready():
	# 创建背景音乐播放器
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	
	# 加载音频配置
	_load_audio_config()

func _load_audio_config():
	"""加载音频配置文件"""
	var config_path = "res://config/audio_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			audio_config = json.data
			print("音频配置已加载")
			
			# 设置音量
			if audio_config.has("volume"):
				var volume = audio_config["volume"].get("background_music", 0.5)
				bgm_player.volume_db = linear_to_db(volume)
		else:
			print("解析音频配置失败")
	else:
		print("音频配置文件不存在")

func play_background_music(scene_id: String, time_id: String, weather_id: String):
	"""根据场景、时间和天气播放背景音乐"""
	# 检查是否需要切换音乐
	if current_scene == scene_id and current_time == time_id and current_weather == weather_id:
		# 如果音乐已经在播放，不需要重新加载
		if bgm_player.playing:
			return
	
	# 更新当前状态
	current_scene = scene_id
	current_time = time_id
	current_weather = weather_id
	
	# 获取音频路径
	var audio_path = _get_audio_path(scene_id, time_id, weather_id)
	
	if audio_path.is_empty():
		print("未找到音频配置: ", scene_id, "/", time_id, "/", weather_id)
		stop_background_music()
		return
	
	# 检查音频文件是否存在
	if not ResourceLoader.exists(audio_path):
		print("音频文件不存在: ", audio_path)
		stop_background_music()
		return
	
	# 加载并播放音频
	var audio_stream = load(audio_path)
	if audio_stream:
		bgm_player.stream = audio_stream
		bgm_player.play()
		print("播放背景音乐: ", audio_path)
		
		# 连接播放结束信号以实现循环
		if not bgm_player.finished.is_connected(_on_bgm_finished):
			bgm_player.finished.connect(_on_bgm_finished)
	else:
		print("加载音频失败: ", audio_path)

func _get_audio_path(scene_id: String, time_id: String, weather_id: String) -> String:
	"""获取指定场景、时间和天气的音频路径"""
	if not audio_config.has("background_music"):
		return ""
	
	var bgm_config = audio_config["background_music"]
	
	# 检查场景配置
	if not bgm_config.has(scene_id):
		return ""
	
	var scene_config = bgm_config[scene_id]
	
	# 检查时间配置
	if not scene_config.has(time_id):
		return ""
	
	var time_config = scene_config[time_id]
	
	# 检查天气配置
	if not time_config.has(weather_id):
		return ""
	
	var filename = time_config[weather_id]
	
	# 如果文件名为空，返回空字符串
	if filename.is_empty():
		return ""
	
	# 拼接完整路径
	return "res://assets/audio/" + filename

func _on_bgm_finished():
	"""背景音乐播放完毕，循环播放"""
	if bgm_player.stream:
		bgm_player.play()
		print("循环播放背景音乐")

func stop_background_music():
	"""停止背景音乐"""
	if bgm_player.playing:
		bgm_player.stop()
		print("停止背景音乐")

func set_bgm_volume(volume: float):
	"""设置背景音乐音量 (0.0 - 1.0)"""
	bgm_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))

func get_bgm_volume() -> float:
	"""获取背景音乐音量 (0.0 - 1.0)"""
	return db_to_linear(bgm_player.volume_db)
