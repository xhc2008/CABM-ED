extends Node

# AI HTTP 客户端
# 负责处理流式和非流式 HTTP 请求

signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal stream_chunk_received(data: String)
signal stream_completed()
signal stream_error(error_message: String)

var http_client: HTTPClient
var is_streaming: bool = false
var stream_host: String = ""
var stream_port: int = 443
var stream_use_tls: bool = true
var request_start_time: float = 0.0
var request_timeout: float = 30.0

func _ready():
	http_client = HTTPClient.new()

func start_stream_request(url: String, headers: Array, json_body: String, timeout: float = 30.0):
	"""启动流式HTTP请求"""
	request_timeout = timeout
	
	# 解析URL
	var base_url = url.split("/chat/completions")[0]
	var url_parts = base_url.replace("https://", "").replace("http://", "").split("/")
	stream_host = url_parts[0]
	stream_use_tls = url.begins_with("https://")
	stream_port = 443 if stream_use_tls else 80
	
	var tls_options = null
	if stream_use_tls:
		tls_options = TLSOptions.client()
	
	var err = http_client.connect_to_host(stream_host, stream_port, tls_options)
	if err != OK:
		is_streaming = false
		stream_error.emit("连接失败: " + str(err))
		return
	
	request_start_time = Time.get_ticks_msec() / 1000.0
	
	set_meta("stream_url", url)
	set_meta("stream_headers", headers)
	set_meta("stream_body", json_body)
	set_meta("stream_state", "connecting")
	
	is_streaming = true

func _process(_delta):
	"""处理流式HTTP连接"""
	if not is_streaming:
		return
	
	# 检查超时
	var elapsed = (Time.get_ticks_msec() / 1000.0) - request_start_time
	if elapsed > request_timeout:
		print("请求超时（%.1f秒）" % elapsed)
		is_streaming = false
		http_client.close()
		stream_error.emit("响应超时")
		return
	
	http_client.poll()
	var status = http_client.get_status()
	
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			if get_meta("stream_state", "") == "connecting":
				is_streaming = false
				stream_error.emit("连接断开")
		
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
			pass
		
		HTTPClient.STATUS_CONNECTED:
			if get_meta("stream_state", "") == "connecting":
				_send_stream_request()
		
		HTTPClient.STATUS_REQUESTING:
			pass
		
		HTTPClient.STATUS_BODY:
			_receive_stream_chunk()
		
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			is_streaming = false
			stream_error.emit("连接错误: " + str(status))

func _send_stream_request():
	"""发送流式请求"""
	var headers_array = get_meta("stream_headers", [])
	var body = get_meta("stream_body", "")
	
	var path = "/v1/chat/completions"
	
	var err = http_client.request(HTTPClient.METHOD_POST, path, headers_array, body)
	if err != OK:
		is_streaming = false
		stream_error.emit("请求发送失败: " + str(err))
		return
	
	set_meta("stream_state", "requesting")

func _receive_stream_chunk():
	"""接收流式数据块"""
	if http_client.has_response():
		var response_code = http_client.get_response_code()
		if response_code != 200:
			is_streaming = false
			stream_error.emit("API 错误: " + str(response_code))
			return
		
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			var text = chunk.get_string_from_utf8()
			stream_chunk_received.emit(text)

func stop_streaming():
	"""停止流式请求"""
	is_streaming = false
	http_client.close()
	stream_completed.emit()
