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

# TTS请求管理（句子为单位）
var tts_requests: Dictionary = {} # {sentence_hash: HTTPRequest}
var translate_requests: Dictionary = {}
var translate_callbacks: Dictionary = {}
var next_translate_id: int = 0

# 句子跟踪系统（使用哈希作为句子唯一ID）
var sentence_audio: Dictionary = {} # {sentence_hash: audio_data 或 null}
var sentence_state: Dictionary = {} # {sentence_hash: "pending"|"ready"|"abandoned"|"playing"}
var current_sentence_hash: String = "" # 当前正在显示/应播放的句子哈希
var playing_sentence_hash: String = "" # 正在播放的句子哈希

var current_player: AudioStreamPlayer
var is_playing: bool = false

# 中文标点符号
const CHINESE_PUNCTUATION = ["。", "！", "？", "；"]

func _ready():
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.is_resources_ready():
		return
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
	
	var url = tts_base_url + "/uploads/audio/voice"
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
	"""移除括号"""
	var result = text
	
	# 移除所有成对括号及内容
	var paired_regex = RegEx.new()
	paired_regex.compile("(\\([^)]*\\)|（[^）]*）|\\[[^]]*\\]|【[^】]*】|\\{[^}]*\\}|<[^>]*>)")
	result = paired_regex.sub(result, "", true)
	
	# 移除所有单边括号情况
	# 匹配 "(xxx" 或 "xxx)" 的模式
	var single_regex = RegEx.new()
	# 这个正则匹配：左括号开头的内容 或 右括号结尾的内容
	single_regex.compile("(^\\([^)]*|^（[^）]*|^\\[[^]]*|^【[^】]*|^\\{[^}]*|^<[^>]*|[^)]*\\)$|[^）]*）$|[^]]*\\]$|[^】]*】$|[^}]*\\}$|[^>]*>$)")
	result = single_regex.sub(result, "", true)
	
	# 清理空格
	result = result.strip_edges()
	var spaces = RegEx.new()
	spaces.compile("\\s+")
	result = spaces.sub(result, " ")
	
	return result

func _compute_sentence_hash(original_text: String) -> String:
	"""对句子原始内容（未翻译、未去除括号）计算SHA256哈希，返回十六进制字符串"""
	# 接受 null 或 非字符串 的输入，保证返回非 null 的字符串（空字符串可能会被外部误判为 null）
	if original_text == null:
		original_text = ""
	# 确保类型为字符串
	original_text = str(original_text)
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(original_text.to_utf8_buffer())
	var hash_bytes = hashing_context.finish()
	return hash_bytes.hex_encode()

func _short_hash(h: String) -> String:
	if h == null:
		return "(null)"
	if h == "":
		return "(empty)"
	var s = str(h)
	if s.length() <= 8:
		return s
	return s.substr(0, 8)

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

	# 保留原始文本用于哈希（未翻译，未去除括号）
	var original_text = text
	var sentence_hash = _compute_sentence_hash(original_text)

	# 对用于合成的文本继续进行后处理（移除括号）
	text = _remove_parentheses(original_text)
	if text.is_empty():
		return

	# 仅在第一次见到该哈希时初始化状态
	if not sentence_state.has(sentence_hash):
		sentence_state[sentence_hash] = "pending"
		sentence_audio[sentence_hash] = null
		print("初始化句子 hash:%s 的状态为 pending" % _short_hash(sentence_hash))

	print("=== 新句子 hash:%s (%s) ===" % [_short_hash(sentence_hash), chosen_lang])
	print("原文: ", original_text)
	print("用于合成的文本: ", text)

	# 如果目标语言不是中文，先进行翻译（翻译结果仍与该哈希绑定）
	if chosen_lang != "zh":
		translate_text(chosen_lang, text, func(translated_text: String) -> void:
			_on_translation_ready(sentence_hash, translated_text, chosen_lang)
		)
	else:
		_on_translation_ready(sentence_hash, text, chosen_lang)

func _on_translation_ready(sentence_hash: String, text: String, lang: String):
	"""翻译完成或无需翻译时触发"""
	# 如果该哈希已被标记为放弃，忽略
	if sentence_state.get(sentence_hash, "") == "abandoned":
		print("句子 hash:%s 已被放弃（翻译后），忽略" % _short_hash(sentence_hash))
		return

	if text.strip_edges().is_empty():
		print("句子 hash:%s 翻译后为空，标记为已放弃" % _short_hash(sentence_hash))
		sentence_state[sentence_hash] = "abandoned"
		return

	print("句子 hash:%s 已准备翻译，开始合成语音" % _short_hash(sentence_hash))
	_synthesize_with_voice(sentence_hash, text, lang)

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

func _synthesize_with_voice(sentence_hash: String, text: String, lang: String):
	"""发送TTS请求
	
	参数:
	- sentence_id: 句子ID（用于追踪和跳过被遗弃的句子）
	- text: 要合成的文本
	- lang: 目标语言
	"""
	if api_key.is_empty():
		push_error("TTS API密钥未配置")
		sentence_state[sentence_hash] = "abandoned"
		return

	var voice_for_lang = voice_uri_map.get(lang, "")
	if voice_for_lang.is_empty():
		push_error("声音URI(%s)未准备好，跳过 hash:%s" % [lang, _short_hash(sentence_hash)])
		sentence_state[sentence_hash] = "abandoned"
		return

	if sentence_state.get(sentence_hash, "") == "abandoned":
		print("句子 hash:%s 已被放弃（合成前），忽略" % _short_hash(sentence_hash))
		return

	print("=== 开始TTS请求 hash:%s (%s) ===" % [_short_hash(sentence_hash), lang])
	print("文本: ", text)

	var http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.set_meta("sentence_hash", sentence_hash)
	http_request.set_meta("text", text)

	http_request.request_completed.connect(_on_tts_completed.bind(sentence_hash, http_request))
	tts_requests[sentence_hash] = http_request

	if tts_base_url.is_empty() or tts_model.is_empty():
		push_error("TTS配置不完整（model或base_url未配置）")
		sentence_state[sentence_hash] = "abandoned"
		tts_requests.erase(sentence_hash)
		http_request.queue_free()
		return

	var url = tts_base_url + "/audio/speech"
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
		push_error("TTS请求 hash:%s 发送失败: %s" % [_short_hash(sentence_hash), str(error)])
		sentence_state[sentence_hash] = "abandoned"
		tts_requests.erase(sentence_hash)
		http_request.queue_free()
	else:
		print("TTS请求 hash:%s 已发送" % _short_hash(sentence_hash))

func _on_tts_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, sentence_hash: String, http_request: HTTPRequest):
	"""TTS请求完成回调"""
	var text = http_request.get_meta("text", "")
	print("=== TTS请求 hash:%s 完成 ===" % _short_hash(sentence_hash))
	print("文本: ", text)
	print("result: %d, response_code: %d, body_size: %d" % [result, response_code, body.size()])

	# 清理请求节点
	tts_requests.erase(sentence_hash)
	http_request.queue_free()

	# 检查句子是否已被放弃
	if sentence_state.get(sentence_hash, "") == "abandoned":
		print("句子 hash:%s 已被放弃（TTS回调），忽略音频数据" % _short_hash(sentence_hash))
		return

	var request_failed = false

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "TTS请求 hash:%s 失败: %s" % [_short_hash(sentence_hash), str(result)]
		print(error_msg)
		tts_error.emit(error_msg)
		request_failed = true
	elif response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "TTS请求 hash:%s 错误 (%d): %s" % [_short_hash(sentence_hash), response_code, error_text]
		print(error_msg)
		tts_error.emit(error_msg)
		request_failed = true
	elif body.size() == 0:
		print("错误: TTS请求 hash:%s 接收到的音频数据为空" % _short_hash(sentence_hash))
		request_failed = true

	if request_failed:
		print("句子 hash:%s 标记为已放弃（请求失败）" % _short_hash(sentence_hash))
		sentence_state[sentence_hash] = "abandoned"
		return

	print("句子 hash:%s 接收到音频数据: %d 字节" % [_short_hash(sentence_hash), body.size()])

	# 保存音频文件到永久存储
	_save_audio_to_file(sentence_hash, body)

	# 存储音频数据
	sentence_audio[sentence_hash] = body
	sentence_state[sentence_hash] = "ready"

	audio_chunk_ready.emit(body)
	var cur_disp = "(none)"
	if current_sentence_hash != "":
		cur_disp = _short_hash(current_sentence_hash)
	print("句子 hash:%s 状态更新为 ready，当前应播放 hash:%s" % [_short_hash(sentence_hash), cur_disp])

	# 只有当这个句子是当前应该播放的句子时，才尝试播放
	if sentence_hash == current_sentence_hash:
		_try_play_sentence()
	else:
		print("句子 hash:%s 不是当前应播放的句子（当前 hash:%s），暂不播放" % [_short_hash(sentence_hash), _short_hash(current_sentence_hash)])

func _save_audio_to_file(sentence_hash: String, audio_data: PackedByteArray) -> bool:
	"""保存音频数据到 user://speech/ 目录，使用哈希作为文件名
	
	返回: 是否保存成功
	"""
	# 确保目录存在
	var dir_path = "user://speech/"
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(dir_path):
		var error = dir.make_dir_recursive(dir_path)
		if error != OK:
			push_error("创建目录失败: user://speech/")
			return false
	
	# 构建文件路径（使用哈希作为文件名，保存为MP3格式）
	var file_path = dir_path + sentence_hash + ".mp3"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("无法创建音频文件 %s (错误: %d)" % [file_path, error])
		return false
	
	# 写入音频数据
	file.store_buffer(audio_data)
	file.close()
	
	print("音频文件已保存: %s (%d 字节)" % [file_path, audio_data.size()])
	return true
		
func on_new_sentence_displayed(sentence_hash: String):
	"""用户通知：某个句子（通过其哈希ID）已被显示。

	参数：
	- sentence_hash: 由句子原始文本计算的SHA256十六进制字符串（唯一ID）

	此函数会：
	1. 中断并停止正在播放的不同句子的音频
	2. 取消并放弃与当前显示句子无关的未完成TTS请求（节省资源）
	3. 尝试播放当前句子的语音（如果已准备好）
	"""

	print("=== 用户显示新句子 hash:%s ===" % _short_hash(sentence_hash))

	# 如果正在播放的是旧句子，立即中断
	if is_playing and playing_sentence_hash != sentence_hash:
		print("中断旧句子 hash:%s 的语音播放" % _short_hash(playing_sentence_hash))
		current_player.stop()
		is_playing = false
		playing_sentence_hash = ""

	# 将当前期望播放的句子设置为该哈希
	current_sentence_hash = sentence_hash

	# # 取消所有与当前句子不同的进行中TTS请求（只保留当前句子的请求）
	# var keys_to_cancel = []
	# for hash_key in tts_requests.keys():
	# 	if hash_key != sentence_hash:
	# 		keys_to_cancel.append(hash_key)

	# for hash_key in keys_to_cancel:
	# 	var http_request = tts_requests.get(hash_key, null)
	# 	if http_request:
	# 		print("取消其他句子 hash:%s 的TTS请求（当前显示 hash:%s）" % [_short_hash(hash_key), _short_hash(sentence_hash)])
	# 		http_request.cancel_request()
	# 		http_request.queue_free()
	# 		tts_requests.erase(hash_key)
	# 		# 只标记被取消的句子为abandoned，不影响其他句子
	# 		if sentence_state.has(hash_key):
	# 			sentence_state[hash_key] = "abandoned"

	# 确保当前哈希有初始化的状态条目
	if not sentence_state.has(sentence_hash):
		sentence_state[sentence_hash] = "pending"
		sentence_audio[sentence_hash] = null
		print("初始化句子 hash:%s 的状态为 pending" % _short_hash(sentence_hash))

	print("当前句子 hash:%s 的状态: %s" % [_short_hash(sentence_hash), sentence_state.get(sentence_hash, "unknown")])

	# 尝试播放
	_try_play_sentence()

func _try_play_sentence():
	"""尝试播放当前句子的语音（基于哈希ID）"""
	# 如果正在播放，先等播放完成
	if is_playing:
		print("正在播放句子 hash:%s，等待完成" % _short_hash(playing_sentence_hash))
		return

	# 如果没有当前句子哈希，等待
	if current_sentence_hash == "" or current_sentence_hash == null:
		print("当前没有要播放的句子，等待...")
		return

	var cur_hash = current_sentence_hash

	# 检查当前句子的状态
	var current_state = sentence_state.get(cur_hash, "")

	if current_state == "abandoned":
		print("句子 hash:%s 已被放弃，不播放" % _short_hash(cur_hash))
		return

	if current_state != "ready":
		print("句子 hash:%s 状态为 %s，等待..." % [_short_hash(cur_hash), current_state])
		return

	# 开始播放
	var audio_data = sentence_audio.get(cur_hash)
	if audio_data == null or audio_data.size() == 0:
		print("错误：句子 hash:%s 的音频数据为空或null" % _short_hash(cur_hash))
		sentence_state[cur_hash] = "abandoned"
		return

	print("=== 开始播放句子 hash:%s ===" % _short_hash(cur_hash))
	print("音频数据大小: %d 字节" % audio_data.size())

	is_playing = true
	playing_sentence_hash = cur_hash
	sentence_state[cur_hash] = "playing"

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

		print("开始播放语音 hash:%s，音频流长度: %.2f 秒" % [_short_hash(current_sentence_hash), stream.get_length()])
	else:
		print("音频流创建失败，跳过")
		is_playing = false
		playing_sentence_hash = ""

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
	#由于Godot对于音频处理的支持有限，这里不进行处理
	return 0.0

func _on_audio_finished():
	"""音频播放完成"""
	print("句子 hash:%s 的语音播放完成" % _short_hash(playing_sentence_hash))
	is_playing = false
	playing_sentence_hash = ""

	# 通知聊天对话框语音播放完毕（用于重置计时器）
	_notify_voice_finished()

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
	# 取消所有进行中的TTS请求（keys 为句子哈希）
	for hash_key in tts_requests.keys():
		var http_request = tts_requests[hash_key]
		if http_request:
			http_request.cancel_request()
			http_request.queue_free()
	tts_requests.clear()

	# 清空句子相关数据
	sentence_audio.clear()
	sentence_state.clear()

	# 停止播放
	if current_player.playing:
		current_player.stop()
	is_playing = false
	playing_sentence_hash = ""

	# 重置当前句子哈希
	current_sentence_hash = ""
	
	print("所有队列和缓冲已清空（TTS请求 + 句子数据）")

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
