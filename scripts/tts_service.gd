extends Node

# TTS 服务 - 处理语音合成
# 自动加载单例

signal voice_ready(voice_uri: String) # 声音URI准备完成
signal audio_chunk_ready(audio_data: PackedByteArray) # 音频块准备完成
signal tts_error(error_message: String)

var config: Dictionary = {}
var api_key: String = ""
var voice_uri: String = "" # 缓存的声音URI
var is_enabled: bool = false # 是否启用TTS
var volume: float = 0.8 # 音量 (0.0 - 1.0)

# HTTP请求节点
var upload_request: HTTPRequest
var tts_request: HTTPRequest

# TTS请求队列
var tts_request_queue: Array = [] # 存储待发送的TTS请求文本
var is_requesting: bool = false # 是否正在发送请求

# 音频播放队列
var audio_queue: Array = [] # 存储待播放的音频数据
var current_player: AudioStreamPlayer
var is_playing: bool = false

# 中文标点符号
const CHINESE_PUNCTUATION = ["。", "！", "？", "；", "…"]

func _ready():
	_load_config()
	_load_tts_settings()
	_load_voice_cache()
	
	# 创建HTTP请求节点
	upload_request = HTTPRequest.new()
	add_child(upload_request)
	upload_request.request_completed.connect(_on_upload_completed)
	
	tts_request = HTTPRequest.new()
	add_child(tts_request)
	tts_request.request_completed.connect(_on_tts_completed)
	
	# 创建音频播放器
	current_player = AudioStreamPlayer.new()
	add_child(current_player)
	current_player.finished.connect(_on_audio_finished)
	
	# 如果没有缓存的voice_uri，上传参考音频
	if voice_uri.is_empty() and is_enabled:
		upload_reference_audio()

func _load_config():
	"""加载AI配置（包含TTS配置）"""
	var config_path = "res://config/ai_config.json"
	if not FileAccess.file_exists(config_path):
		push_error("AI配置文件不存在")
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		config = json.data
		print("TTS配置加载成功")
	else:
		push_error("AI配置解析失败")

func _load_tts_settings():
	"""加载TTS设置（API密钥、启用状态、音量）"""
	var settings_path = "user://tts_settings.json"
	
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var settings = json.data
			api_key = settings.get("api_key", "")
			is_enabled = settings.get("enabled", false)
			volume = settings.get("volume", 0.8)
			print("TTS设置加载成功: enabled=%s, volume=%.2f, api_key=%s" % [is_enabled, volume, "已设置" if not api_key.is_empty() else "未设置"])
			if not api_key.is_empty():
				return
	
	# 如果没有TTS专用设置或API密钥为空，尝试从AI配置加载
	var ai_keys_path = "user://ai_keys.json"
	if FileAccess.file_exists(ai_keys_path):
		var file = FileAccess.open(ai_keys_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var ai_config = json.data
			# 尝试从tts_model获取
			if ai_config.has("tts_model") and ai_config.tts_model.has("api_key"):
				api_key = ai_config.tts_model.get("api_key", "")
				print("从AI配置(tts_model)加载TTS密钥")
			# 如果tts_model没有，尝试从简单模式获取
			elif ai_config.has("mode") and ai_config.mode == "simple" and ai_config.has("api_key"):
				api_key = ai_config.get("api_key", "")
				print("从AI配置(简单模式)加载TTS密钥")
			# 如果是详细模式，尝试从chat_model获取
			elif ai_config.has("chat_model") and ai_config.chat_model.has("api_key"):
				api_key = ai_config.chat_model.get("api_key", "")
				print("从AI配置(chat_model)加载TTS密钥")
			
			if not api_key.is_empty():
				print("API密钥已加载: ", api_key.substr(0, 10) + "...")
			else:
				print("警告: 未找到API密钥")

func save_tts_settings():
	"""保存TTS设置"""
	var settings = {
		"api_key": api_key,
		"enabled": is_enabled,
		"volume": volume
	}
	
	var settings_path = "user://tts_settings.json"
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
		print("TTS设置已保存")

func _load_voice_cache():
	"""加载缓存的声音URI"""
	var cache_path = "user://voice_cache.json"
	if FileAccess.file_exists(cache_path):
		var file = FileAccess.open(cache_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var cache = json.data
			voice_uri = cache.get("voice_uri", "")
			if not voice_uri.is_empty():
				print("加载缓存的声音URI: ", voice_uri)
				voice_ready.emit(voice_uri)

func _save_voice_cache():
	"""保存声音URI到缓存"""
	var cache = {
		"voice_uri": voice_uri
	}
	
	var cache_path = "user://voice_cache.json"
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache, "\t"))
		file.close()
		print("声音URI已缓存")

func upload_reference_audio():
	"""上传参考音频"""
	if api_key.is_empty():
		push_error("TTS API密钥未配置")
		return
	
	var ref_audio_path = "res://assets/audio/ref.wav"
	var ref_text_path = "res://assets/audio/ref.txt"
	
	# 检查文件是否存在
	if not FileAccess.file_exists(ref_audio_path):
		push_error("参考音频文件不存在: " + ref_audio_path)
		return
	
	if not FileAccess.file_exists(ref_text_path):
		push_error("参考文本文件不存在: " + ref_text_path)
		return
	
	# 读取参考文本
	var text_file = FileAccess.open(ref_text_path, FileAccess.READ)
	var ref_text = text_file.get_as_text().strip_edges()
	text_file.close()
	
	# 读取音频文件
	var audio_file = FileAccess.open(ref_audio_path, FileAccess.READ)
	var audio_data = audio_file.get_buffer(audio_file.get_length())
	audio_file.close()
	
	# 构建multipart/form-data请求
	var boundary = "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body = PackedByteArray()
	
	# 添加model字段
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"model\"\r\n\r\n".to_utf8_buffer())
	body.append_array((config.get("tts_model", {}).get("model", "FunAudioLLM/CosyVoice2-0.5B") + "\r\n").to_utf8_buffer())
	
	# 添加customName字段
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"customName\"\r\n\r\n".to_utf8_buffer())
	body.append_array("character-voice\r\n".to_utf8_buffer())
	
	# 添加text字段
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"text\"\r\n\r\n".to_utf8_buffer())
	body.append_array((ref_text + "\r\n").to_utf8_buffer())
	
	# 添加file字段
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"file\"; filename=\"ref.wav\"\r\n".to_utf8_buffer())
	body.append_array("Content-Type: audio/wav\r\n\r\n".to_utf8_buffer())
	body.append_array(audio_data)
	body.append_array("\r\n".to_utf8_buffer())
	
	# 结束boundary
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())
	
	var url = config.get("tts_model", {}).get("base_url", "https://api.siliconflow.cn") + "/v1/uploads/audio/voice"
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: multipart/form-data; boundary=" + boundary
	]
	
	print("上传参考音频...")
	upload_request.request_raw(url, headers, HTTPClient.METHOD_POST, body)

func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""上传完成回调"""
	if result != HTTPRequest.RESULT_SUCCESS:
		tts_error.emit("上传失败: " + str(result))
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		tts_error.emit("上传错误 (%d): %s" % [response_code, error_text])
		return
	
	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		tts_error.emit("解析上传响应失败")
		return
	
	var response = json.data
	if response.has("uri"):
		voice_uri = response.uri
		print("声音URI获取成功: ", voice_uri)
		_save_voice_cache()
		voice_ready.emit(voice_uri)
	else:
		tts_error.emit("响应中没有URI字段")

func synthesize_speech(text: String):
	"""合成语音（加入队列）"""
	if not is_enabled:
		print("TTS未启用，跳过合成")
		return
	
	if api_key.is_empty():
		push_error("TTS API密钥未配置")
		return
	
	if voice_uri.is_empty():
		push_error("声音URI未准备好")
		return
	
	if text.strip_edges().is_empty():
		return
	
	# 将文本加入请求队列
	tts_request_queue.append(text)
	print("TTS请求加入队列: ", text, " (队列长度: ", tts_request_queue.size(), ")")
	
	# 如果当前没有正在处理的请求，开始处理队列
	if not is_requesting:
		_process_tts_queue()

func _process_tts_queue():
	"""处理TTS请求队列"""
	if tts_request_queue.is_empty():
		is_requesting = false
		print("TTS请求队列为空")
		return
	
	if is_requesting:
		print("正在处理TTS请求，等待完成")
		return
	
	is_requesting = true
	var text = tts_request_queue.pop_front()
	
	print("=== 处理TTS请求队列 ===")
	print("剩余队列长度: ", tts_request_queue.size())
	print("当前文本: ", text)
	
	var url = config.get("tts_model", {}).get("base_url", "https://api.siliconflow.cn") + "/v1/audio/speech"
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var request_body = {
		"model": config.get("tts_model", {}).get("model", "FunAudioLLM/CosyVoice2-0.5B"),
		"input": text,
		"voice": voice_uri
	}
	
	var json_body = JSON.stringify(request_body)
	print("URL: ", url)
	print("模型: ", request_body.model)
	print("Voice URI: ", voice_uri)
	
	var error = tts_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("TTS请求发送失败: " + str(error))
		is_requesting = false
		# 继续处理下一个
		_process_tts_queue()
	else:
		print("TTS请求已发送")

func _on_tts_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""TTS请求完成回调"""
	print("TTS请求完成 - result: %d, response_code: %d, body_size: %d" % [result, response_code, body.size()])
	
	# 标记请求完成
	is_requesting = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "TTS请求失败: " + str(result)
		print(error_msg)
		tts_error.emit(error_msg)
		# 继续处理队列中的下一个请求
		_process_tts_queue()
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "TTS错误 (%d): %s" % [response_code, error_text]
		print(error_msg)
		tts_error.emit(error_msg)
		# 继续处理队列中的下一个请求
		_process_tts_queue()
		return
	
	# 检查音频数据大小
	if body.size() == 0:
		print("错误: 接收到的音频数据为空")
		# 继续处理队列中的下一个请求
		_process_tts_queue()
		return
	
	print("接收到音频数据: %d 字节" % body.size())
	
	# 音频数据已接收，添加到播放队列
	audio_queue.append(body)
	audio_chunk_ready.emit(body)
	
	print("音频已加入播放队列，队列长度: %d" % audio_queue.size())
	
	# 如果当前没有播放，开始播放
	if not is_playing:
		print("开始播放队列中的音频")
		_play_next_audio()
	else:
		print("当前正在播放，音频已排队")
	
	# 继续处理TTS请求队列中的下一个请求
	_process_tts_queue()

func _play_next_audio():
	"""播放队列中的下一个音频"""
	if audio_queue.is_empty():
		is_playing = false
		print("播放队列为空，停止播放")
		return
	
	is_playing = true
	var audio_data = audio_queue.pop_front()
	
	print("准备播放音频，数据大小: %d 字节" % audio_data.size())
	
	# 将音频数据转换为AudioStream
	var stream = _create_audio_stream(audio_data)
	if stream:
		current_player.stream = stream
		current_player.volume_db = linear_to_db(volume)
		print("设置音量: %.2f (%.2f dB)" % [volume, linear_to_db(volume)])
		current_player.play()
		print("开始播放语音，音频流长度: %.2f 秒" % stream.get_length())
	else:
		print("音频流创建失败，跳过")
		# 如果转换失败，继续播放下一个
		_play_next_audio()

func _create_audio_stream(audio_data: PackedByteArray) -> AudioStream:
	"""将音频数据转换为AudioStream"""
	# 检查数据是否有效
	if audio_data.size() == 0:
		push_error("音频数据为空")
		return null
	
	# 检查音频格式（前几个字节）
	var header = ""
	for i in range(min(4, audio_data.size())):
		header += "%02X " % audio_data[i]
	print("音频数据头: ", header)
	
	# API返回的是MP3格式
	var stream = AudioStreamMP3.new()
	stream.data = audio_data
	
	# 尝试获取音频长度来验证是否有效
	var length = stream.get_length()
	if length <= 0:
		push_error("音频流无效，长度: %.2f" % length)
		return null
	
	print("音频流创建成功，长度: %.2f 秒" % length)
	return stream

func _on_audio_finished():
	"""音频播放完成"""
	print("语音播放完成")
	# 播放下一个
	_play_next_audio()

func process_text_chunk(text: String):
	"""处理文本块，检测中文标点并合成语音"""
	if not is_enabled:
		return
	
	# 检查是否包含中文标点
	for punct in CHINESE_PUNCTUATION:
		if punct in text:
			# 按标点分割
			var sentences = text.split(punct, false)
			for i in range(sentences.size()):
				var sentence = sentences[i].strip_edges()
				if not sentence.is_empty():
					# 添加标点符号
					if i < sentences.size() - 1 or text.ends_with(punct):
						sentence += punct
					synthesize_speech(sentence)
			return
	
	# 如果没有标点，暂时不合成（等待更多文本）

func clear_queue():
	"""清空所有队列"""
	# 清空TTS请求队列
	tts_request_queue.clear()
	is_requesting = false
	
	# 清空音频播放队列
	audio_queue.clear()
	if current_player.playing:
		current_player.stop()
	is_playing = false
	
	print("所有队列已清空（TTS请求队列 + 音频播放队列）")

func set_enabled(enabled: bool):
	"""设置是否启用TTS"""
	is_enabled = enabled
	save_tts_settings()
	
	if enabled and voice_uri.is_empty():
		upload_reference_audio()

func set_volume(vol: float):
	"""设置音量"""
	volume = clamp(vol, 0.0, 1.0)
	save_tts_settings()
	
	if current_player.playing:
		current_player.volume_db = linear_to_db(volume)
