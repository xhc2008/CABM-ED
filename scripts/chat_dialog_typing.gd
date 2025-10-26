extends Node

# 打字机效果和流式输出模块
# 负责文本的逐字显示和句子分段

signal sentence_completed
signal all_sentences_completed

const TYPING_SPEED = 0.05
const CHINESE_PUNCTUATION = ["。", "！", "？", "；"]

var parent_dialog: Panel
var message_label: Label
var typing_timer: Timer

# 流式输出相关
var display_buffer: String = ""
var displayed_text: String = ""
var is_receiving_stream: bool = false

# 分段输出相关
var sentence_buffer: String = ""
var sentence_queue: Array = []
var current_sentence_index: int = 0
var is_showing_sentence: bool = false

func _ready():
	typing_timer = Timer.new()
	typing_timer.one_shot = false
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(typing_timer)

func setup(dialog: Panel, msg_label: Label):
	parent_dialog = dialog
	message_label = msg_label

func start_stream():
	is_receiving_stream = true
	sentence_buffer = ""
	sentence_queue = []
	current_sentence_index = 0
	is_showing_sentence = false
	message_label.text = ""

func add_stream_content(content: String):
	sentence_buffer += content
	_extract_sentences_from_buffer()

func end_stream():
	is_receiving_stream = false
	
	# 处理剩余的句子缓冲
	if not sentence_buffer.strip_edges().is_empty():
		sentence_queue.append(sentence_buffer.strip_edges())
		sentence_buffer = ""
	
	# 如果还没有开始显示句子，开始显示第一句
	if not is_showing_sentence and sentence_queue.size() > 0:
		_show_next_sentence()

func has_content() -> bool:
	return sentence_queue.size() > 0 or not sentence_buffer.strip_edges().is_empty()

func show_next_sentence():
	# 确保当前句子已经显示完成
	if not typing_timer.is_stopped():
		print("警告: 上一句还在显示中，等待完成")
		typing_timer.stop()
		displayed_text = display_buffer
		message_label.text = displayed_text
	
	_show_next_sentence()

func has_more_sentences() -> bool:
	return current_sentence_index < sentence_queue.size()

func _extract_sentences_from_buffer():
	while true:
		var found_punct = false
		var earliest_pos = -1
		
		for punct in CHINESE_PUNCTUATION:
			var pos = sentence_buffer.find(punct)
			if pos != -1:
				if earliest_pos == -1 or pos < earliest_pos:
					earliest_pos = pos
					found_punct = true
		
		if not found_punct:
			break
		
		var end_pos = earliest_pos + 1
		while end_pos < sentence_buffer.length():
			var next_char = sentence_buffer[end_pos]
			if next_char in CHINESE_PUNCTUATION:
				end_pos += 1
			else:
				break
		
		var sentence = sentence_buffer.substr(0, end_pos).strip_edges()
		
		if not sentence.is_empty():
			sentence_queue.append(sentence)
			print("提取句子: ", sentence)
		
		sentence_buffer = sentence_buffer.substr(end_pos)
	
	# 只有在没有正在显示句子时才开始显示
	# 如果打字机正在运行，说明正在显示句子，不要开始新句子
	if not is_showing_sentence and sentence_queue.size() > 0 and typing_timer.is_stopped():
		# 如果当前索引已经到达队列末尾，说明之前在等待新句子
		# 现在有新句子了，应该继续显示
		if current_sentence_index < sentence_queue.size():
			print("检测到新句子，继续显示")
			_show_next_sentence()

func _show_next_sentence():
	# 防止重复调用
	if is_showing_sentence and not typing_timer.is_stopped():
		print("警告: 句子正在显示中，忽略重复调用")
		return
	
	if current_sentence_index >= sentence_queue.size():
		# 没有更多句子了
		if not is_receiving_stream:
			# 流已结束，真的没有更多句子了
			is_showing_sentence = false
			all_sentences_completed.emit()
			print("所有句子显示完成")
		else:
			# 流还在继续，但暂时没有新句子
			# 保持 is_showing_sentence = false，让系统知道可以接收新句子
			is_showing_sentence = false
			print("等待流式接收更多句子...")
		return
	
	is_showing_sentence = true
	var sentence = sentence_queue[current_sentence_index]
	current_sentence_index += 1
	
	print("开始显示句子 #%d: %s" % [current_sentence_index, sentence])
	
	message_label.text = ""
	displayed_text = ""
	display_buffer = sentence
	
	# 发送TTS
	_send_tts(sentence)
	
	typing_timer.start(TYPING_SPEED)

func _on_typing_timer_timeout():
	if displayed_text.length() < display_buffer.length():
		var next_char = display_buffer[displayed_text.length()]
		displayed_text += next_char
		message_label.text = displayed_text
	else:
		typing_timer.stop()
		sentence_completed.emit()

func _send_tts(text: String):
	if not parent_dialog.has_node("/root/TTSService"):
		return
	
	var tts = parent_dialog.get_node("/root/TTSService")
	if tts.is_enabled and not text.is_empty():
		tts.synthesize_speech(text)
		print("ChatDialog: 发送TTS - ", text)

func stop():
	if typing_timer:
		typing_timer.stop()
	is_receiving_stream = false
	is_showing_sentence = false
