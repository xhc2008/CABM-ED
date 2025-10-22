extends Node

# AI 响应解析器
# 负责解析流式响应和提取字段

signal content_received(content: String)
signal mood_extracted(mood_id: int)

var sse_buffer: String = ""
var json_response_buffer: String = ""
var msg_buffer: String = ""
var extracted_fields: Dictionary = {}

func reset():
	"""重置所有缓冲区"""
	sse_buffer = ""
	json_response_buffer = ""
	msg_buffer = ""
	extracted_fields = {}

func process_stream_data(data: String):
	"""处理流式响应数据（SSE格式）"""
	sse_buffer += data
	
	var lines = sse_buffer.split("\n")
	
	if not sse_buffer.ends_with("\n"):
		sse_buffer = lines[-1]
		lines = lines.slice(0, -1)
	else:
		sse_buffer = ""
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		
		if line == "data: [DONE]":
			return true  # 流式结束
		
		if line.begins_with("data: "):
			var json_str = line.substr(6)
			_parse_stream_chunk(json_str)
	
	return false  # 继续接收

func _parse_stream_chunk(json_str: String):
	"""解析单个流式数据块"""
	var json = JSON.new()
	if json.parse(json_str) != OK:
		print("流式块解析失败: ", json_str.substr(0, 100))
		return
	
	var chunk = json.data
	if not chunk.has("choices") or chunk.choices.is_empty():
		return
	
	var delta = chunk.choices[0].get("delta", {})
	if delta.has("content"):
		var content = delta.content
		json_response_buffer += content
		print("接收到内容块: ", content)
		_extract_msg_from_buffer()

func _extract_msg_from_buffer():
	"""从流式缓冲中实时提取msg字段内容"""
	var buffer_to_parse = json_response_buffer
	
	if buffer_to_parse.contains("```json"):
		var json_start = buffer_to_parse.find("```json") + 7
		buffer_to_parse = buffer_to_parse.substr(json_start)
	elif buffer_to_parse.contains("```"):
		var json_start = buffer_to_parse.find("```") + 3
		buffer_to_parse = buffer_to_parse.substr(json_start)
	
	if buffer_to_parse.contains("```"):
		var json_end = buffer_to_parse.find("```")
		buffer_to_parse = buffer_to_parse.substr(0, json_end)
	
	buffer_to_parse = buffer_to_parse.strip_edges()
	
	_extract_mood_from_buffer(buffer_to_parse)
	
	var msg_start = buffer_to_parse.find('"msg"')
	if msg_start == -1:
		return
	
	var colon_pos = buffer_to_parse.find(':', msg_start)
	if colon_pos == -1:
		return
	
	var quote_start = -1
	for i in range(colon_pos + 1, buffer_to_parse.length()):
		if buffer_to_parse[i] == '"':
			quote_start = i
			break
		elif buffer_to_parse[i] != ' ' and buffer_to_parse[i] != '\t':
			break
	
	if quote_start == -1:
		return
	
	var content_start = quote_start + 1
	var current_pos = content_start
	var extracted_content = ""
	
	while current_pos < buffer_to_parse.length():
		var ch = buffer_to_parse[current_pos]
		
		if ch == '\\' and current_pos + 1 < buffer_to_parse.length():
			var next_ch = buffer_to_parse[current_pos + 1]
			if next_ch == '"':
				extracted_content += '"'
				current_pos += 2
				continue
			elif next_ch == 'n':
				extracted_content += '\n'
				current_pos += 2
				continue
			elif next_ch == 't':
				extracted_content += '\t'
				current_pos += 2
				continue
			elif next_ch == '\\':
				extracted_content += '\\'
				current_pos += 2
				continue
			else:
				extracted_content += ch
				current_pos += 1
		elif ch == '"':
			break
		else:
			extracted_content += ch
			current_pos += 1
	
	if extracted_content.length() > msg_buffer.length():
		var new_content = extracted_content.substr(msg_buffer.length())
		msg_buffer = extracted_content
		
		if not new_content.is_empty():
			print("发送新内容: ", new_content)
			content_received.emit(new_content)

func _extract_mood_from_buffer(buffer: String):
	"""从缓冲中提取mood字段"""
	if extracted_fields.has("mood"):
		return
	
	var mood_start = buffer.find('"mood"')
	if mood_start == -1:
		return
	
	var colon_pos = buffer.find(':', mood_start)
	if colon_pos == -1:
		return
	
	var value_start = -1
	for i in range(colon_pos + 1, buffer.length()):
		var ch = buffer[i]
		if ch == ' ' or ch == '\t' or ch == '\n':
			continue
		value_start = i
		break
	
	if value_start == -1:
		return
	
	var value_str = ""
	for i in range(value_start, buffer.length()):
		var ch = buffer[i]
		if ch in [',', '\n', ' ', '\t', '}', '\r']:
			break
		value_str += ch
	
	if value_str.is_empty():
		return
	
	if value_str.begins_with("null"):
		print("mood字段为null，跳过")
		extracted_fields["mood"] = null
		return
	
	if not value_str.is_valid_int():
		return
	
	var mood_id = int(value_str)
	extracted_fields["mood"] = mood_id
	
	print("实时提取到mood字段: ", mood_id)
	mood_extracted.emit(mood_id)

func finalize_response() -> Dictionary:
	"""完成流式响应处理，返回提取的所有字段"""
	print("流式响应完成，完整内容: ", json_response_buffer)
	
	var clean_json = json_response_buffer
	if clean_json.contains("```json"):
		var json_start = clean_json.find("```json") + 7
		clean_json = clean_json.substr(json_start)
	elif clean_json.contains("```"):
		var json_start = clean_json.find("```") + 3
		clean_json = clean_json.substr(json_start)
	
	if clean_json.contains("```"):
		var json_end = clean_json.find("```")
		clean_json = clean_json.substr(0, json_end)
	
	clean_json = clean_json.strip_edges()
	
	var json = JSON.new()
	if json.parse(clean_json) == OK:
		var full_response = json.data
		if full_response.has("mood") and full_response.mood != null:
			extracted_fields["mood"] = int(full_response.mood)
		if full_response.has("will"):
			extracted_fields["will"] = full_response.will
		if full_response.has("like"):
			extracted_fields["like"] = full_response.like
		if full_response.has("goto") and full_response.goto != null:
			extracted_fields["goto"] = int(full_response.goto)
		print("提取的字段: ", extracted_fields)
	else:
		print("JSON解析失败: ", json.get_error_message())
		print("尝试解析的内容: ", clean_json.substr(0, 200))
	
	return extracted_fields.duplicate()

func get_full_response() -> String:
	"""获取完整的响应内容"""
	return json_response_buffer

func get_msg_content() -> String:
	"""获取提取的msg内容"""
	return msg_buffer
