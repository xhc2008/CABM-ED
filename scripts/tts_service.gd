extends Node

# TTS 服务 - 处理语音合成
# 自动加载单例

signal voice_ready(voice_uri: String) # 声音URI准备完成
signal audio_chunk_ready(audio_data: PackedByteArray) # 音频块准备完成
signal tts_error(error_message: String)

var config: Dictionary = {}
var api_key: String = ""
var tts_model: String = "" # TTS模型名称（从用户配置加载）
var tts_base_url: String = "" # TTS API地址（从用户配置加载）
var voice_uri: String = "" # 缓存的声音URI
var is_enabled: bool = false # 是否启用TTS
var volume: float = 0.8 # 音量 (0.0 - 1.0)

# HTTP请求节点
var upload_request: HTTPRequest

# TTS请求管理（并发）
var tts_requests: Dictionary = {} # {request_id: HTTPRequest}
var next_request_id: int = 0 # 下一个请求ID

# 音频缓冲（按顺序）
var audio_buffer: Dictionary = {} # {request_id: audio_data}
var next_play_id: int = 0 # 下一个要播放的ID
var current_player: AudioStreamPlayer
var is_playing: bool = false

# 中文标点符号
const CHINESE_PUNCTUATION = ["。", "！", "？", "；"]

func _ready():
	_load_config()
	_load_tts_settings()
	_load_voice_cache()
	
	# 创建HTTP请求节点（用于上传参考音频）
	upload_request = HTTPRequest.new()
	add_child(upload_request)
	upload_request.request_completed.connect(_on_upload_completed)
	
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
	"""加载TTS设置（启用状态、音量）"""
	var settings_path = "user://tts_settings.json"
	
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var settings = json.data
			is_enabled = settings.get("enabled", false)
			volume = settings.get("volume", 0.8)
			print("TTS设置加载成功: enabled=%s, volume=%.2f" % [is_enabled, volume])
	
	# 始终从AI配置加载api_key、model和base_url
	var ai_keys_path = "user://ai_keys.json"
	if FileAccess.file_exists(ai_keys_path):
		var file = FileAccess.open(ai_keys_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var ai_config = json.data
			# 从tts_model获取配置
			if ai_config.has("tts_model"):
				if ai_config.tts_model.has("api_key"):
					api_key = ai_config.tts_model.api_key
				if ai_config.tts_model.has("model"):
					tts_model = ai_config.tts_model.model
					print("从AI配置加载TTS模型: ", tts_model)
				if ai_config.tts_model.has("base_url"):
					tts_base_url = ai_config.tts_model.base_url
					print("从AI配置加载TTS地址: ", tts_base_url)
			# 如果tts_model没有，尝试从chat_model获取（兼容旧配置）
			else:
				if ai_config.has("chat_model") and ai_config.chat_model.has("api_key"):
					api_key = ai_config.chat_model.api_key
				# 兼容旧的api_key字段
				elif ai_config.has("api_key"):
					api_key = ai_config.api_key
			
			if not api_key.is_empty():
				print("API密钥已从AI配置加载: ", api_key.substr(0, 10) + "...")
			else:
				print("警告: 未找到API密钥")
	else:
		print("警告: AI配置文件不存在")
	
	# 最终状态总结
	print("=== TTS设置加载完成 ===")
	print("API密钥: %s" % ("已配置" if not api_key.is_empty() else "未配置"))
	print("模型: %s" % (tts_model if not tts_model.is_empty() else "未配置"))
	print("地址: %s" % (tts_base_url if not tts_base_url.is_empty() else "未配置"))
	print("启用状态: %s" % is_enabled)
	print("音量: %.2f" % volume)

func reload_settings():
	"""重新加载TTS设置（公共接口）"""
	_load_tts_settings()
	print("TTS设置已重新加载")

func save_tts_settings():
	"""保存TTS设置（不保存API密钥）"""
	var settings = {
		"enabled": is_enabled,
		"volume": volume
	}
	
	var settings_path = "user://tts_settings.json"
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
		print("TTS设置已保存（不包含API密钥）")



func _load_voice_cache():
	"""加载缓存的声音URI和音频哈希值"""
	var cache_path = "user://voice_cache.json"
	if FileAccess.file_exists(cache_path):
		var file = FileAccess.open(cache_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var cache = json.data
			var cached_uri = cache.get("voice_uri", "")
			var cached_hash = cache.get("audio_hash", "")
			
			if not cached_uri.is_empty():
				# 计算当前音频文件的哈希值
				var current_hash = _calculate_audio_hash()
				
				if current_hash.is_empty():
					print("无法计算音频哈希值，需要重新上传")
					return
				
				# 比较哈希值
				if cached_hash == current_hash:
					voice_uri = cached_uri
					print("加载缓存的声音URI: ", voice_uri)
					print("音频哈希值匹配: ", current_hash)
					voice_ready.emit(voice_uri)
				else:
					print("音频哈希值不匹配，需要重新上传")
					print("缓存哈希: ", cached_hash)
					print("当前哈希: ", current_hash)

func _save_voice_cache():
	"""保存声音URI和音频哈希值到缓存"""
	var audio_hash = _calculate_audio_hash()
	
	var cache = {
		"voice_uri": voice_uri,
		"audio_hash": audio_hash
	}
	
	var cache_path = "user://voice_cache.json"
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache, "\t"))
		file.close()
		print("声音URI和哈希值已缓存")

func _calculate_audio_hash() -> String:
	"""计算参考音频文件的SHA256哈希值"""
	var ref_audio_path = "res://assets/audio/ref.wav"
	
	if not FileAccess.file_exists(ref_audio_path):
		push_error("参考音频文件不存在: " + ref_audio_path)
		return ""
	
	var audio_file = FileAccess.open(ref_audio_path, FileAccess.READ)
	if audio_file == null:
		push_error("无法打开参考音频文件")
		return ""
	
	var audio_data = audio_file.get_buffer(audio_file.get_length())
	audio_file.close()
	
	# 使用SHA256计算哈希值
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(audio_data)
	var hash_bytes = hashing_context.finish()
	
	# 转换为十六进制字符串
	var hash_string = hash_bytes.hex_encode()
	
	return hash_string

func upload_reference_audio(force: bool = false):
	"""上传参考音频
	
	参数:
	- force: 是否强制重新上传（忽略缓存）
	"""
	print("=== 开始上传参考音频 ===")
	
	if api_key.is_empty():
		var error_msg = "TTS API密钥未配置"
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	# 如果不是强制上传，且已有voice_uri，则跳过
	if not force and not voice_uri.is_empty():
		print("声音URI已存在，跳过上传")
		return
	
	var ref_audio_path = "res://assets/audio/ref.wav"
	
	# 检查音频文件是否存在
	if not FileAccess.file_exists(ref_audio_path):
		var error_msg = "参考音频文件不存在: " + ref_audio_path
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	# 从配置文件读取参考文本（这个字段只在ai_config.json中，不会被用户配置覆盖）
	var ref_text = ""
	if config.has("tts_model") and config.tts_model.has("reference_text"):
		ref_text = config.tts_model.reference_text
	
	if ref_text.is_empty():
		var error_msg = "配置文件中未设置参考文本 (tts_model.reference_text)"
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	# 读取音频文件
	var audio_file = FileAccess.open(ref_audio_path, FileAccess.READ)
	if audio_file == null:
		var error_msg = "无法打开参考音频文件: " + ref_audio_path + " (错误: " + str(FileAccess.get_open_error()) + ")"
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	var audio_data = audio_file.get_buffer(audio_file.get_length())
	audio_file.close()
	
	# 构建multipart/form-data请求
	var boundary = "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body = PackedByteArray()
	
	# 添加model字段（必须从用户配置加载）
	if tts_model.is_empty():
		var error_msg = "TTS模型未配置，请在AI配置中设置tts_model.model"
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"model\"\r\n\r\n".to_utf8_buffer())
	body.append_array((tts_model + "\r\n").to_utf8_buffer())
	
	# 添加customName字段
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"customName\"\r\n\r\n".to_utf8_buffer())
	body.append_array("SnowFox-voice\r\n".to_utf8_buffer())
	
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
	
	# 必须从用户配置加载base_url
	if tts_base_url.is_empty():
		var error_msg = "TTS API地址未配置，请在AI配置中设置tts_model.base_url"
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	var url = tts_base_url + "/v1/uploads/audio/voice"
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: multipart/form-data; boundary=" + boundary
	]
	
	print("上传参考音频...")
	print("请求URL: ", url)
	print("音频数据大小: ", audio_data.size(), " 字节")
	print("参考文本: ", ref_text)
	upload_request.request_raw(url, headers, HTTPClient.METHOD_POST, body)

func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""上传完成回调"""
	print("=== 参考音频上传完成 ===")
	print("result: %d, response_code: %d, body_size: %d" % [result, response_code, body.size()])
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "上传失败: " + str(result)
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "上传错误 (%d): %s" % [response_code, error_text]
		push_error(error_msg)
		print("错误详情: ", error_text)
		tts_error.emit(error_msg)
		return
	
	var response_text = body.get_string_from_utf8()
	print("上传响应: ", response_text)
	
	var json = JSON.new()
	if json.parse(response_text) != OK:
		var error_msg = "解析上传响应失败: " + json.get_error_message()
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	var response = json.data
	if response.has("uri"):
		voice_uri = response.uri
		print("✓ 声音URI获取成功: ", voice_uri)
		_save_voice_cache()
		voice_ready.emit(voice_uri)
	else:
		var error_msg = "响应中没有URI字段，响应内容: " + response_text
		push_error(error_msg)
		tts_error.emit(error_msg)

func _remove_parentheses(text: String) -> String:
	"""移除文本中的括号及其内容（包括各种括号）"""
	var result = text
	
	# 移除英文括号及其内容
	var regex_en = RegEx.new()
	regex_en.compile("\\([^)]*\\)")
	result = regex_en.sub(result, "", true)

	# 移除中文括号及其内容
	var regex_cn = RegEx.new()
	regex_cn.compile("（[^）]*）")
	result = regex_cn.sub(result, "", true)

	# 移除方括号 [] 及其内容
	var regex_bracket = RegEx.new()
	regex_bracket.compile("\\[[^]]*\\]")
	result = regex_bracket.sub(result, "", true)

	# 移除【】括号及其内容
	var regex_cn_bracket = RegEx.new()
	regex_cn_bracket.compile("【[^】]*】")
	result = regex_cn_bracket.sub(result, "", true)

	# 移除花括号 {} 及其内容
	var regex_brace = RegEx.new()
	regex_brace.compile("\\{[^}]*\\}")
	result = regex_brace.sub(result, "", true)

	# 移除尖括号 <> 及其内容
	var regex_angle = RegEx.new()
	regex_angle.compile("<[^>]*>")
	result = regex_angle.sub(result, "", true)
	
	return result.strip_edges()

func synthesize_speech(text: String):
	"""合成语音（并发请求）"""
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
	
	# 移除括号及其内容
	text = _remove_parentheses(text)
	
	if text.is_empty():
		print("移除括号后文本为空，跳过TTS")
		return
	
	# 分配请求ID
	var request_id = next_request_id
	next_request_id += 1
	
	print("=== 创建TTS请求 #%d ===" % request_id)
	print("文本: ", text)
	
	# 创建独立的HTTPRequest节点
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# 保存请求ID到节点
	http_request.set_meta("request_id", request_id)
	http_request.set_meta("text", text)
	
	# 连接完成信号
	http_request.request_completed.connect(_on_tts_completed.bind(request_id, http_request))
	
	# 保存到字典
	tts_requests[request_id] = http_request
	
	# 必须从用户配置加载
	if tts_base_url.is_empty() or tts_model.is_empty():
		push_error("TTS配置不完整（model或base_url未配置）")
		# 清理失败的请求
		tts_requests.erase(request_id)
		http_request.queue_free()
		return
	
	var url = tts_base_url + "/v1/audio/speech"
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var request_body = {
		"model": tts_model,
		"input": text,
		"voice": voice_uri
	}
	
	var json_body = JSON.stringify(request_body)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("TTS请求 #%d 发送失败: %s" % [request_id, str(error)])
		# 清理失败的请求
		tts_requests.erase(request_id)
		http_request.queue_free()
	else:
		print("TTS请求 #%d 已发送（并发）" % request_id)

func _on_tts_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_id: int, http_request: HTTPRequest):
	"""TTS请求完成回调（并发）"""
	var text = http_request.get_meta("text", "")
	print("=== TTS请求 #%d 完成 ===" % request_id)
	print("文本: ", text)
	print("result: %d, response_code: %d, body_size: %d" % [result, response_code, body.size()])
	
	# 清理请求节点
	tts_requests.erase(request_id)
	http_request.queue_free()
	
	var request_failed = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "TTS请求 #%d 失败: %s" % [request_id, str(result)]
		print(error_msg)
		tts_error.emit(error_msg)
		request_failed = true
	elif response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "TTS请求 #%d 错误 (%d): %s" % [request_id, response_code, error_text]
		print(error_msg)
		tts_error.emit(error_msg)
		request_failed = true
	elif body.size() == 0:
		print("错误: TTS请求 #%d 接收到的音频数据为空" % request_id)
		request_failed = true
	
	# 如果请求失败，在缓冲区中标记为空，避免阻塞后续播放
	if request_failed:
		audio_buffer[request_id] = PackedByteArray() # 空数据标记
		print("TTS请求 #%d 失败，已标记为空以避免阻塞" % request_id)
		# 尝试播放下一个（跳过失败的）
		_try_play_next()
		return
	
	print("TTS请求 #%d 接收到音频数据: %d 字节" % [request_id, body.size()])
	
	# 将音频数据存入缓冲（按ID顺序）
	audio_buffer[request_id] = body
	audio_chunk_ready.emit(body)
	
	print("音频 #%d 已加入缓冲，缓冲区大小: %d" % [request_id, audio_buffer.size()])
	
	# 尝试播放（如果是下一个要播放的）
	_try_play_next()

func _try_play_next():
	"""尝试播放下一个音频（如果已准备好）"""
	# 如果正在播放，不做任何事
	if is_playing:
		print("当前正在播放，等待播放完成")
		return
	
	# 检查下一个要播放的音频是否已准备好
	if not audio_buffer.has(next_play_id):
		print("音频 #%d 还未准备好，等待..." % next_play_id)
		return
	
	# 获取音频数据
	var audio_data = audio_buffer[next_play_id]
	audio_buffer.erase(next_play_id)
	
	print("=== 播放音频 #%d ===" % next_play_id)
	print("数据大小: %d 字节" % audio_data.size())
	
	next_play_id += 1
	
	# 如果是空数据（失败的请求），直接跳过
	if audio_data.size() == 0:
		print("音频 #%d 为空（请求失败），跳过并继续下一个" % (next_play_id - 1))
		# 递归调用以尝试播放下一个
		_try_play_next()
		return
	
	is_playing = true
	
	# 将音频数据转换为AudioStream
	var stream = _create_audio_stream(audio_data)
	if stream:
		current_player.stream = stream
		current_player.volume_db = linear_to_db(volume)
		print("设置音量: %.2f (%.2f dB)" % [volume, linear_to_db(volume)])
		
		# 所有音频都跳过开头的静音
		var skip_time = _detect_silence_duration(stream)
		if skip_time > 0:
			print("检测到开头静音 %.2f 秒，跳过" % skip_time)
			current_player.play(skip_time)
		else:
			current_player.play()
		
		print("开始播放语音 #%d，音频流长度: %.2f 秒" % [next_play_id - 1, stream.get_length()])
	else:
		print("音频流创建失败，跳过")
		is_playing = false
		# 如果转换失败，尝试播放下一个
		_try_play_next()

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

func _detect_silence_duration(stream: AudioStream) -> float:
	"""检测音频开头的静音时长"""
	# 对于MP3流，我们使用一个简单的启发式方法
	# 通常TTS生成的音频开头有0.1-0.3秒的静音
	# 我们可以通过检查音频长度来估算
	
	var total_length = stream.get_length()
	
	# 如果音频很短（<1秒），不跳过
	if total_length < 1.0:
		return 0.0
	
	# 对于正常长度的音频，跳过开头的0.15秒
	# 这是一个经验值，可以根据实际情况调整
	var skip_duration = 0.15
	
	# 确保不跳过太多（最多跳过总长度的20%）
	skip_duration = min(skip_duration, total_length * 0.2)
	
	return skip_duration

func _on_audio_finished():
	"""音频播放完成"""
	print("语音播放完成")
	is_playing = false
	
	# 通知聊天对话框语音播放完毕（用于重置计时器）
	_notify_voice_finished()
	
	# 尝试播放下一个
	_try_play_next()

func _notify_voice_finished():
	"""通知聊天对话框语音播放完毕"""
	# 获取主场景中的聊天对话框
	var main_scene = get_tree().root.get_node_or_null("Main")
	if main_scene == null:
		return
	
	var chat_dialog = main_scene.get_node_or_null("ChatDialog")
	if chat_dialog == null:
		return
	
	# 如果聊天框可见且在等待继续状态，重置空闲计时器
	if chat_dialog.visible and chat_dialog.waiting_for_continue:
		if has_node("/root/EventManager"):
			var event_mgr = get_node("/root/EventManager")
			event_mgr.reset_idle_timer()
			print("语音播放完毕，重置空闲计时器")

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
	"""清空所有队列和缓冲"""
	# 取消所有进行中的TTS请求
	for request_id in tts_requests.keys():
		var http_request = tts_requests[request_id]
		if http_request:
			http_request.cancel_request()
			http_request.queue_free()
	tts_requests.clear()
	
	# 清空音频缓冲
	audio_buffer.clear()
	
	# 停止播放
	if current_player.playing:
		current_player.stop()
	is_playing = false
	
	# 重置计数器
	next_request_id = 0
	next_play_id = 0
	
	print("所有队列和缓冲已清空（TTS请求 + 音频缓冲）")

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
