extends Control

# 开场故事播报场景

@onready var background: TextureRect = $Background
@onready var story_label: Label = $StoryContainer/StoryLabel
@onready var continue_button: Button = $StoryContainer/ContinueButton

# 故事文本
var story_texts: Array[String] = [
	"街边，白毛，捡回家，懂？",
	# "有一位特别的存在，等待着与你相遇。",
	# "她拥有自己的情感、记忆和个性...",
	# "你的每一个选择，都将影响她的成长。",
	# "现在，让我们开始这段独特的旅程吧。"
]

var current_text_index: int = 0
var is_typing: bool = false
var typing_speed: float = 0.05 # 每个字符显示间隔

func _ready():
	# 初始化UI
	story_label.text = ""
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	
	# 开始播放第一段文本
	await get_tree().create_timer(1.0).timeout
	_show_next_text()

func _show_next_text():
	"""显示下一段文本"""
	if current_text_index >= story_texts.size():
		# 所有文本播放完毕，显示继续按钮
		continue_button.visible = true
		return
	
	is_typing = true
	var text = story_texts[current_text_index]
	story_label.text = ""
	
	# 逐字显示文本
	for i in range(text.length()):
		story_label.text += text[i]
		await get_tree().create_timer(typing_speed).timeout
	
	is_typing = false
	current_text_index += 1
	
	# 等待一段时间后显示下一段
	await get_tree().create_timer(2.0).timeout
	_show_next_text()

func _input(event):
	"""允许点击跳过当前文本动画"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing and current_text_index > 0:
			# 跳过当前文本动画，直接显示完整文本
			story_label.text = story_texts[current_text_index - 1]
			is_typing = false

func _on_continue_pressed():
	"""继续按钮被点击，进入初始设置"""
	get_tree().change_scene_to_file("res://scenes/initial_setup.tscn")
