extends Node

# 音频播放器
var bgm_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# 音频配置
var audio_config: Dictionary = {}

# 当前播放状态
var current_scene: String = ""
var current_time: String = ""
var current_weather: String = ""
var is_playing_custom_bgm: bool = false
var current_bgm_path: String = "" # 当前播放的BGM路径

func _ready():
	# 创建背景音乐播放器
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	
	# 创建环境音播放器
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)
	
	# 加载音频配置
	_load_audio_config()

func _load_audio_config():
	"""加载音频配置文件（混合策略：默认配置从res://，用户配置从user://）"""
	# 1. 先加载默认配置（res://，只读，包含场景音乐和氛围音配置）
	var default_config_path = "res://config/audio_config.json"
	if FileAccess.file_exists(default_config_path):
		var file = FileAccess.open(default_config_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				audio_config = json.data
				print("✅ 默认音频配置已加载")
			else:
				print("❌ 解析默认音频配置失败")
				audio_config = _get_default_config()
		else:
			print("❌ 无法打开默认音频配置")
			audio_config = _get_default_config()
	else:
		print("⚠️ 默认音频配置文件不存在，使用内置默认值")
		audio_config = _get_default_config()
	
	# 2. 加载用户配置（user://，可写，包含音量和自定义BGM设置）
	var user_config_path = "user://audio_settings.json"
	if FileAccess.file_exists(user_config_path):
		var file = FileAccess.open(user_config_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var user_config = json.data
				print("✅ 用户音频设置已加载")
				
				# 合并用户配置（覆盖默认配置）
				if user_config.has("volume"):
					audio_config["volume"] = user_config["volume"]
				if user_config.has("last_custom_bgm"):
					audio_config["last_custom_bgm"] = user_config["last_custom_bgm"]
			else:
				print("❌ 解析用户音频设置失败")
	else:
		print("ℹ️ 用户音频设置不存在，将使用默认值")
	
	# 3. 应用音量设置
	if audio_config.has("volume"):
		var bgm_volume = audio_config["volume"].get("background_music", 0.5)
		var ambient_volume = audio_config["volume"].get("ambient", 0.3)
		bgm_player.volume_db = linear_to_db(bgm_volume)
		ambient_player.volume_db = linear_to_db(ambient_volume)
		print("🔊 音量设置: BGM=%.0f%%, 氛围音=%.0f%%" % [bgm_volume * 100, ambient_volume * 100])
	
	# 4. 恢复上次播放的自定义BGM
	if audio_config.has("last_custom_bgm") and audio_config["last_custom_bgm"] != "":
		var last_bgm = audio_config["last_custom_bgm"]
		if FileAccess.file_exists(last_bgm) or ResourceLoader.exists(last_bgm):
			# 延迟播放，等待场景加载完成
			await get_tree().create_timer(0.5).timeout
			play_custom_bgm(last_bgm)
			print("🎵 恢复上次播放的BGM: ", last_bgm)
		else:
			print("⚠️ 上次播放的BGM文件不存在: ", last_bgm)
			# 清除无效的BGM路径
			audio_config["last_custom_bgm"] = ""
			_save_user_config()

func _get_default_config() -> Dictionary:
	"""获取默认配置（当配置文件不存在时使用）"""
	return {
		"background_music": {},
		"ambient_sounds": {},
		"volume": {
			"background_music": 0.3,
			"ambient": 0.3
		},
		"last_custom_bgm": ""
	}

func play_background_music(scene_id: String, time_id: String, weather_id: String):
	"""根据场景、时间和天气播放背景音乐和氛围音"""
	# 更新当前状态
	current_scene = scene_id
	current_time = time_id
	current_weather = weather_id
	
	# 如果正在播放自定义BGM，不自动切换BGM，但仍然播放氛围音
	if not is_playing_custom_bgm:
		# 检查是否需要切换音乐
		var should_switch = (current_bgm_path == "" or not bgm_player.playing)
		
		if should_switch:
			# 获取音频路径
			var audio_path = _get_audio_path(scene_id, time_id, weather_id)
			
			if audio_path.is_empty():
				print("未找到BGM配置: ", scene_id, "/", time_id, "/", weather_id)
				stop_background_music()
			else:
				# 检查音频文件是否存在
				if not ResourceLoader.exists(audio_path):
					print("BGM文件不存在: ", audio_path)
					stop_background_music()
				else:
					# 加载并播放音频
					var audio_stream = load(audio_path)
					if audio_stream:
						bgm_player.stream = audio_stream
						bgm_player.play()
						current_bgm_path = audio_path
						print("播放背景音乐: ", audio_path)
						
						# 连接播放结束信号以实现循环
						if not bgm_player.finished.is_connected(_on_bgm_finished):
							bgm_player.finished.connect(_on_bgm_finished)
					else:
						print("加载BGM失败: ", audio_path)
	
	# 播放氛围音（独立于BGM）
	_play_ambient_for_scene(scene_id, time_id, weather_id)

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

func get_bgm_volume() -> float:
	"""获取背景音乐音量 (0.0 - 1.0)"""
	return db_to_linear(bgm_player.volume_db)

func set_bgm_volume(volume: float):
	"""设置背景音乐音量 (0.0 - 1.0)"""
	bgm_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
	_save_volume_config()

func set_ambient_volume(volume: float):
	"""设置环境音音量 (0.0 - 1.0)"""
	ambient_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
	_save_volume_config()

func get_ambient_volume() -> float:
	"""获取环境音音量 (0.0 - 1.0)"""
	return db_to_linear(ambient_player.volume_db)

func play_custom_bgm(file_path: String):
	"""播放自定义BGM（跨平台兼容）"""
	var audio_stream = null
	var ext = file_path.get_extension().to_lower()
	
	# 检查是否为不支持的格式
	if ext in ["aac", "m4a"]:
		push_warning("AAC/M4A格式不被Godot原生支持，请转换为OGG或MP3格式")
		print("⚠️ 不支持的音频格式: ", ext)
		print("建议使用FFmpeg转换: ffmpeg -i input.", ext, " -c:a libvorbis -q:a 5 output.ogg")
		return
	
	# 尝试加载音频文件
	if file_path.begins_with("res://"):
		# 资源路径（打包在游戏内）
		if ResourceLoader.exists(file_path):
			audio_stream = load(file_path)
	else:
		# 用户路径（user://）- 跨平台兼容
		if FileAccess.file_exists(file_path):
			# 根据文件扩展名加载
			if ext == "mp3":
				# MP3需要手动加载数据
				audio_stream = AudioStreamMP3.new()
				var file = FileAccess.open(file_path, FileAccess.READ)
				if file:
					audio_stream.data = file.get_buffer(file.get_length())
					file.close()
					# 设置循环
					audio_stream.loop = true
				else:
					print("❌ 无法打开MP3文件: ", file_path)
					return
			elif ext == "ogg":
				# OGG推荐格式，跨平台支持最好
				audio_stream = AudioStreamOggVorbis.load_from_file(file_path)
				if audio_stream:
					# 设置循环
					audio_stream.loop = true
			elif ext == "wav":
				# WAV需要手动加载
				var file = FileAccess.open(file_path, FileAccess.READ)
				if file:
					var wav_data = file.get_buffer(file.get_length())
					file.close()
					
					# 创建AudioStreamWAV并加载数据
					audio_stream = AudioStreamWAV.new()
					audio_stream.data = wav_data
					audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				else:
					print("❌ 无法打开WAV文件: ", file_path)
					return
		else:
			print("❌ 文件不存在: ", file_path)
			return
	
	if audio_stream:
		bgm_player.stream = audio_stream
		bgm_player.play()
		is_playing_custom_bgm = true
		current_bgm_path = file_path
		print("✅ 播放自定义BGM: ", file_path)
		
		# 连接播放结束信号以实现循环（对于不支持内置循环的格式）
		if not bgm_player.finished.is_connected(_on_bgm_finished):
			bgm_player.finished.connect(_on_bgm_finished)
		
		# 保存到配置
		_save_last_bgm(file_path)
	else:
		push_error("❌ 加载自定义BGM失败: " + file_path)
		print("支持的格式: OGG (推荐), MP3, WAV")

func stop_custom_bgm():
	"""停止自定义BGM，恢复场景音乐"""
	is_playing_custom_bgm = false
	current_bgm_path = ""
	stop_background_music()
	
	# 清除保存的BGM
	_save_last_bgm("")
	
	# 重新播放场景音乐
	if not current_scene.is_empty():
		play_background_music(current_scene, current_time, current_weather)

func play_ambient_sound(file_path: String, loop: bool = true):
	"""播放环境音"""
	if not ResourceLoader.exists(file_path):
		print("环境音文件不存在: ", file_path)
		return
	
	var audio_stream = load(file_path)
	if audio_stream:
		ambient_player.stream = audio_stream
		ambient_player.play()
		print("播放环境音: ", file_path)
		
		if loop and not ambient_player.finished.is_connected(_on_ambient_finished):
			ambient_player.finished.connect(_on_ambient_finished)

func _on_ambient_finished():
	"""环境音播放完毕，循环播放"""
	if ambient_player.stream:
		ambient_player.play()

func stop_ambient_sound():
	"""停止环境音"""
	if ambient_player.playing:
		ambient_player.stop()
		print("停止环境音")

func _save_volume_config():
	"""保存音量配置到用户目录"""
	if not audio_config.has("volume"):
		audio_config["volume"] = {}
	
	audio_config["volume"]["background_music"] = get_bgm_volume()
	audio_config["volume"]["ambient"] = get_ambient_volume()
	
	_save_user_config()

func _save_last_bgm(bgm_path: String):
	"""保存上次播放的BGM到用户目录"""
	audio_config["last_custom_bgm"] = bgm_path
	_save_user_config()

func _save_user_config():
	"""保存用户配置到user://（可写目录）"""
	var user_config = {
		"volume": audio_config.get("volume", {
			"background_music": 0.3,
			"ambient": 0.3
		}),
		"last_custom_bgm": audio_config.get("last_custom_bgm", "")
	}
	
	var config_path = "user://audio_settings.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(user_config, "\t"))
		file.close()
		print("💾 用户音频设置已保存到: ", config_path)
	else:
		push_error("❌ 无法保存用户音频设置")
		print("错误代码: ", FileAccess.get_open_error())

func _play_ambient_for_scene(scene_id: String, time_id: String, weather_id: String):
	"""根据场景、时间和天气播放氛围音"""
	# 获取氛围音配置
	if not audio_config.has("ambient_sounds"):
		return
	
	var ambient_config = audio_config["ambient_sounds"]
	
	# 优先级：天气 > 时间 > 场景
	var ambient_path = ""
	
	# 1. 检查天气氛围音（如雨声）
	if weather_id in ["rainy", "storm"]:
		ambient_path = "res://assets/audio/rain.mp3"
	
	# 2. 如果没有天气氛围音，检查场景特定氛围音
	if ambient_path.is_empty() and ambient_config.has(scene_id):
		var scene_ambient = ambient_config[scene_id]
		if scene_ambient.has(time_id):
			var filename = scene_ambient[time_id]
			if not filename.is_empty():
				ambient_path = "res://assets/audio/" + filename
	
	# 播放或停止氛围音
	if ambient_path.is_empty():
		stop_ambient_sound()
	else:
		# 检查是否已经在播放相同的氛围音
		if ambient_player.playing and ambient_player.stream:
			# 使用元数据来跟踪当前播放的氛围音路径
			if has_meta("current_ambient_path") and get_meta("current_ambient_path") == ambient_path:
				return # 已经在播放相同的氛围音
		
		if ResourceLoader.exists(ambient_path):
			var audio_stream = load(ambient_path)
			if audio_stream:
				ambient_player.stream = audio_stream
				ambient_player.play()
				set_meta("current_ambient_path", ambient_path)
				print("播放氛围音: ", ambient_path)
				
				# 连接循环信号
				if not ambient_player.finished.is_connected(_on_ambient_finished):
					ambient_player.finished.connect(_on_ambient_finished)
		else:
			print("氛围音文件不存在: ", ambient_path)

func get_current_bgm_path() -> String:
	"""获取当前播放的BGM路径"""
	return current_bgm_path
