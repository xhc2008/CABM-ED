extends Node

signal description_ready(text: String)
signal description_error(error: String)

var http_request: HTTPRequest
var last_description: String = ""

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func describe_image(path: String) -> String:
	var ai = get_node_or_null("/root/AIService")
	if ai == null:
		description_error.emit("AIService 不可用")
		return ""
	var cfg = ai.config_loader.config.get("view_model", {})
	var model = cfg.get("model", "")
	var base_url = cfg.get("base_url", "")
	var timeout_s = int(cfg.get("timeout", 30))
	var max_tokens = int(cfg.get("max_tokens", 256))
	var temperature = float(cfg.get("temperature", 0.3))
	var top_p = float(cfg.get("top_p", 0.7))
	var system_prompt = cfg.get("system_prompt", "")
	if model.is_empty() or base_url.is_empty():
		description_error.emit("视图模型未配置")
		return ""
	if base_url.ends_with("/"):
		base_url = base_url.substr(0, base_url.length() - 1)
	var url = base_url + "/chat/completions"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + ai.config_loader.api_key
	]
	var bytes = FileAccess.get_file_as_bytes(path)
	var mime = _guess_mime(path)
	var data_uri = "data:" + mime + ";base64," + Marshalls.raw_to_base64(bytes)
	var content = [
		{"type": "text", "text": ""},
		{"type": "image_url", "image_url": {"url": data_uri}}
	]
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": content}
	]
	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"top_p": top_p
	}
	var json_body = JSON.stringify(body)
	http_request.timeout = timeout_s
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		description_error.emit("请求失败: " + str(err))
		return ""
	await description_ready
	return last_description

func _guess_mime(path: String) -> String:
	var lower = path.to_lower()
	if lower.ends_with(".png"):
		return "image/png"
	if lower.ends_with(".jpg") or lower.ends_with(".jpeg"):
		return "image/jpeg"
	if lower.ends_with(".webp"):
		return "image/webp"
	return "application/octet-stream"

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		description_error.emit("请求失败: " + str(result))
		return
	var text = body.get_string_from_utf8()
	if response_code != 200:
		description_error.emit("HTTP" + str(response_code) + ": " + text)
		return
	var json = JSON.new()
	if json.parse(text) != OK:
		description_error.emit("解析失败")
		return
	var data = json.data
	var choices = data.get("choices", [])
	if choices.size() == 0:
		description_error.emit("响应为空")
		return
	var msg = choices[0].get("message", {})
	var content = msg.get("content", "")
	last_description = String(content).strip_edges()
	description_ready.emit(last_description)

