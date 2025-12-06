extends Control

## 加载界面
## 用于显示撤离或其他加载过程

@onready var title_label: Label = $Panel/VBox/Title
@onready var progress_bar: ProgressBar = $Panel/VBox/ProgressBar
@onready var status_label: Label = $Panel/VBox/StatusLabel

var progress_tween: Tween

func _ready():
	# 启动进度条动画
	_animate_progress()

func set_title(text: String):
	"""设置标题"""
	if title_label:
		title_label.text = text

func set_status(text: String):
	"""设置状态文本"""
	if status_label:
		status_label.text = text

func set_progress(value: float):
	"""设置进度（0-100）"""
	if progress_bar:
		progress_bar.value = value

func _animate_progress():
	"""动画化进度条"""
	if not progress_bar:
		return
	
	if progress_tween:
		progress_tween.kill()
	
	progress_tween = create_tween()
	progress_tween.set_loops()
	progress_tween.tween_property(progress_bar, "value", 90.0, 2.0)
	progress_tween.tween_property(progress_bar, "value", 10.0, 2.0)

func complete():
	"""完成加载"""
	if progress_tween:
		progress_tween.kill()
	
	if progress_bar:
		progress_bar.value = 100.0
	
	# if status_label:
	# 	status_label.text = "完成！"
