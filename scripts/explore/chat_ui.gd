extends Control
class_name ChatUI

signal message_submitted(text: String)
signal close_requested()

@onready var panel: Panel = $Panel
@onready var scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var history_container: VBoxContainer = $Panel/Margin/VBox/Scroll/History
@onready var input: LineEdit = $Panel/Margin/VBox/Input
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var message_item_scene: PackedScene = load("res://scenes/message_item.tscn")

var messages: Array[String] = []
var max_messages: int = 200

func _ready():
	visible = false
	if input:
		input.text_submitted.connect(_on_input_submitted)
		input.placeholder_text = "输入消息，按 Enter 发送..."
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		
	# 阻止聊天UI处理输入，让父节点决定哪些按键要处理
	set_process_input(false)
	set_process_unhandled_input(false)

func open():
	"""打开聊天框"""
	visible = true
	if input:
		input.grab_focus()
	_refresh_history()

func close():
	"""关闭聊天框"""
	visible = false

func toggle():
	"""切换聊天框显示/隐藏"""
	if visible:
		close()
	else:
		open()

func add_message(line: String):
	"""添加一条聊天消息到历史"""
	if line.is_empty():
		return
	messages.append(line)
	if messages.size() > max_messages:
		messages.pop_front()
	
	# 如果当前可见，增量更新显示
	if history_container and visible:
		_append_label(line)
		_scroll_to_bottom()

func set_messages(new_messages: Array[String]):
	"""重设消息历史（用于从外部同步）"""
	messages = new_messages.duplicate()
	_refresh_history()

func _refresh_history():
	"""重新构建整个历史列表"""
	if not history_container:
		return
	for child in history_container.get_children():
		child.queue_free()
	for line in messages:
		_append_label(line)
	_scroll_to_bottom()

func _append_label(text: String):
	if not message_item_scene:
		return
	var msg_panel := message_item_scene.instantiate()
	var label := msg_panel.get_node("Label") as Label
	if label:
		label.text = text
	history_container.add_child(msg_panel)

func _scroll_to_bottom():
	if not scroll:
		return
	await get_tree().process_frame
	var bar := scroll.get_v_scroll_bar()
	if bar:
		scroll.scroll_vertical = bar.max_value

func _on_input_submitted(text: String):
	text = text.strip_edges()
	if text.is_empty():
		return
	input.clear()
	message_submitted.emit(text)
	
func _on_close_pressed():
	close_requested.emit()
