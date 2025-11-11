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
var voice_uri_map: Dictionary = {"zh":"", "en":"", "ja":""} # per-language voice URIs
var is_enabled: bool = false # 是否启用TTS
var volume: float = 0.8 # 音量 (0.0 - 1.0)
var language: String = "zh" # 当前选择语言: zh / en / ja

# HTTP请求节点
var upload_request: HTTPRequest

# TTS请求管理（并发）
var tts_requests: Dictionary = {} # {request_id: HTTPRequest}
var next_request_id: int = 0 # 下一个请求ID
var translate_requests: Dictionary = {}
var translate_callbacks: Dictionary = {}
var next_translate_id: int = 0

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
	if is_enabled:
		# 只上传当前语言的参考音频（如果没有缓存）
		if voice_uri_map.get(language, "").is_empty():
			upload_reference_audio(false, language)

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
			language = settings.get("language", "zh")
			print("TTS设置加载成功: enabled=%s, volume=%.2f, language=%s" % [is_enabled, volume, language])
	
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
		"volume": volume,
		"language": language
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
			# 兼容旧格式
			if cache.has("voice_uri_map"):
				voice_uri_map = cache.get("voice_uri_map", {"zh":"", "en":"", "ja":""})
			else:
				# 旧字段适配
				var cached_uri = cache.get("voice_uri", "")
				if not cached_uri.is_empty():
					voice_uri_map["zh"] = cached_uri

			# 加载音频哈希映射
			var audio_hash_map = cache.get("audio_hash_map", {})

			# 仅检查当前语言对应的缓存
			var cached_hash = audio_hash_map.get(language, "")
			var cached_lang_uri = voice_uri_map.get(language, "")

			if not cached_lang_uri.is_empty():
				var current_hash = _calculate_audio_hash_for_lang(language)
				if current_hash.is_empty():
					print("无法计算音频哈希值，需要重新上传")
					return
				if cached_hash == current_hash:
					voice_uri = cached_lang_uri
					print("加载缓存的声音URI(%s): %s" % [language, voice_uri])
					print("音频哈希值匹配: ", current_hash)
					voice_ready.emit(voice_uri)
				else:
					print("音频哈希值不匹配，需要重新上传(%s)" % language)
					print("缓存哈希: ", cached_hash)
					print("当前哈希: ", current_hash)

func _save_voice_cache():
	"""保存声音URI和音频哈希值到缓存"""
	var audio_hash_map = {}
	# 仅为已存在的语言计算哈希
	for lang in ["zh", "en", "ja"]:
		var h = _calculate_audio_hash_for_lang(lang)
		if not h.is_empty():
			audio_hash_map[lang] = h

	var cache = {
		"voice_uri_map": voice_uri_map,
		"audio_hash_map": audio_hash_map
	}
	
	var cache_path = "user://voice_cache.json"
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache, "\t"))
		file.close()
		print("声音URI和哈希值已缓存")

func _calculate_audio_hash() -> String:
	"""计算参考音频文件的SHA256哈希值
	可选参数: language ("zh","en","ja") 指定哪种参考音频文件
	如果文件不存在或无法读取返回空字符串
	"""
	return _calculate_audio_hash_for_lang("zh")

func _calculate_audio_hash_for_lang(lang: String) -> String:
	var ref_audio_path = "res://assets/audio/ref_%s.wav" % lang

	if not FileAccess.file_exists(ref_audio_path):
		# 回退到通用ref.wav（兼容旧项目）
		ref_audio_path = "res://assets/audio/ref.wav"
		if not FileAccess.file_exists(ref_audio_path):
			push_error("参考音频文件不存在: " + ref_audio_path)
			return ""

	var audio_file = FileAccess.open(ref_audio_path, FileAccess.READ)
	if audio_file == null:
		push_error("无法打开参考音频文件: " + ref_audio_path)
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

func upload_reference_audio(force: bool = false, lang: String = ""):
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
	
	var chosen_lang = lang if not lang.is_empty() else language

	# 如果不是强制上传，且已有该语言的voice_uri，则跳过
	if not force and not voice_uri_map.get(chosen_lang, "").is_empty():
		print("声音URI(%s)已存在，跳过上传" % chosen_lang)
		return

	var ref_audio_path = "res://assets/audio/ref_%s.wav" % chosen_lang
	if not FileAccess.file_exists(ref_audio_path):
		# 兼容旧项目：回退到通用ref.wav
		ref_audio_path = "res://assets/audio/ref.wav"
	
	# 检查音频文件是否存在
	if not FileAccess.file_exists(ref_audio_path):
		var error_msg = "参考音频文件不存在: " + ref_audio_path
		push_error(error_msg)
		tts_error.emit(error_msg)
		return
	
	# 从配置文件读取参考文本（这个字段只在ai_config.json中，不会被用户配置覆盖）
	var ref_text = ""
	if config.has("tts_model") and config.tts_model.has("reference_text"):
		var rt = config.tts_model.reference_text
		# 支持两种配置格式：
		# 1) 字符串（旧格式）: "reference_text": "some text"
		# 2) 字典（新格式，按语言区分）: "reference_text": {"zh":"...","en":"...","ja":"..."}
		if typeof(rt) == TYPE_DICTIONARY:
			# 优先使用当前要上传的语言
			ref_text = rt.get(chosen_lang, "")
			# 回退：尝试常见中文键或第一条可用值
			if ref_text.is_empty():
				if rt.has("zh"):
					ref_text = rt.get("zh", "")
				else:
					# 取第一个可用的值
					for k in rt.keys():
						ref_text = rt.get(k, "")
						if not ref_text.is_empty():
							break
		elif typeof(rt) == TYPE_STRING:
			ref_text = rt

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
	var filename = "ref_%s.wav" % chosen_lang
	body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n" % filename).to_utf8_buffer())
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
	
	# 记录上传语言到请求meta，以便回调时识别
	upload_request.set_meta("upload_language", chosen_lang)

	print("上传参考音频 (%s)..." % chosen_lang)
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
		var returned_uri = response.uri
		# 从请求meta获取语言
		var uploaded_lang = upload_request.get_meta("upload_language", language)
		voice_uri_map[uploaded_lang] = returned_uri
		print("✓ 声音URI获取成功(%s): %s" % [uploaded_lang, returned_uri])
		# 如果上传的语言是当前选择语言，更新voice_uri并通知
		if uploaded_lang == language:
			voice_uri = returned_uri
			voice_ready.emit(voice_uri)
		_save_voice_cache()
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

func synthesize_speech(text: String, lang: String = ""):
	"""合成语音（入口）
	- 如果 lang 为空，使用当前self.language
	- 如果语言不是中文（zh），先调用翻译（summary_model.translation）再合成
	"""
	if not is_enabled:
		return

	if text.strip_edges().is_empty():
		return

	var chosen_lang = lang if not lang.is_empty() else language

	# 移除括号及其内容
	text = _remove_parentheses(text)
	if text.is_empty():
		return

	# 如果目标语言不是中文，先进行翻译
	if chosen_lang != "zh":
		translate_text(chosen_lang, text, func(translated_text: String) -> void:
			if translated_text.strip_edges().is_empty():
				print("翻译结果为空，跳过TTS")
				return
			_synthesize_with_voice(translated_text, chosen_lang)
		)
	else:
		_synthesize_with_voice(text, chosen_lang)

func translate_text(target_lang: String, text: String, callback: Callable) -> void:
	"""使用 summary_model.translation 配置将 text 翻译到 target_lang，回调呼回传入翻译后的文本"""
	var ai_service = get_node_or_null("/root/AIService")
	var summary_conf = {}
	if ai_service and ai_service.config.has("summary_model"):
		summary_conf = ai_service.config.summary_model
	else:
		push_error("未配置 summary_model，无法进行翻译")
		callback.call("")
		return

	var model = summary_conf.get("model", "")
	var base_url = summary_conf.get("base_url", "")
	var trans_params = summary_conf.get("translation", {})


	var system_prompt = trans_params.get("system_prompt", "")
	system_prompt = system_prompt.replace("{language}", target_lang)

	var messages = [
		{"role":"system","content": system_prompt},
		{"role":"user","content": text}
	]

	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": int(trans_params.get("max_tokens", 256)),
		"temperature": float(trans_params.get("temperature", 0.2)),
		"top_p": float(trans_params.get("top_p", 0.7))
	}

	var tid = next_translate_id
	next_translate_id += 1

	var http_request = HTTPRequest.new()
	add_child(http_request)
	translate_requests[tid] = http_request
	translate_callbacks[tid] = callback
	http_request.request_completed.connect(_on_translate_completed.bind(tid, http_request))

	var url = base_url + "/chat/completions"
	var auth_key = ""
	if ai_service:
		auth_key = ai_service.api_key
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_key]
	var json_body = JSON.stringify(body)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		push_error("翻译请求发送失败: %s" % str(err))
		translate_requests.erase(tid)
		var cb = translate_callbacks.get(tid, null)
		translate_callbacks.erase(tid)
		if cb:
			cb.call("")

func _on_translate_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, tid: int, http_request: HTTPRequest):
	print("翻译请求完成: tid=%d, result=%d, code=%d" % [tid, result, response_code])
	var cb = translate_callbacks.get(tid, null)
	translate_requests.erase(tid)
	translate_callbacks.erase(tid)
	if http_request:
		http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if cb:
			cb.call("")
		return

	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		if cb:
			cb.call("")
		return

	var response = json.data
	# 修复这里：将 empty() 改为 is_empty()
	if not response.has("choices") or response.choices.is_empty():
		if cb:
			cb.call("")
		return

	var message = response.choices[0].get("message", null)
	var translated = ""
	if message and message.has("content"):
		translated = message.content

	if cb:
		cb.call(translated)

func _synthesize_with_voice(text: String, lang: String):
	"""真正发送TTS请求，使用 lang 对应的 voice_uri"""
	if api_key.is_empty():
		push_error("TTS API密钥未配置")
		return

	var voice_for_lang = voice_uri_map.get(lang, "")
	if voice_for_lang.is_empty():
		push_error("声音URI(%s)未准备好" % lang)
		return

	# 分配请求ID
	var request_id = next_request_id
	next_request_id += 1

	print("=== 创建TTS请求 #%d (%s) ===" % [request_id, lang])
	print("文本: ", text)

	var http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.set_meta("request_id", request_id)
	http_request.set_meta("text", text)

	http_request.request_completed.connect(_on_tts_completed.bind(request_id, http_request))
	tts_requests[request_id] = http_request

	if tts_base_url.is_empty() or tts_model.is_empty():
		push_error("TTS配置不完整（model或base_url未配置）")
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
		"voice": voice_for_lang
	}

	var json_body = JSON.stringify(request_body)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("TTS请求 #%d 发送失败: %s" % [request_id, str(error)])
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
	
	if enabled and voice_uri_map.get(language, "").is_empty():
		upload_reference_audio(false, language)

func set_volume(vol: float):
	"""设置音量"""
	volume = clamp(vol, 0.0, 1.0)
	save_tts_settings()
	
	if current_player.playing:
		current_player.volume_db = linear_to_db(volume)
