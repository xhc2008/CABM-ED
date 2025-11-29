extends Control

# 自动保存提示控件
# 使用方法：在主界面或HUD中实例化此场景，放置到右上角。
# 会自动连接 /root/AIService 的 `auto_save_started` 和 `auto_save_completed` 信号。

@onready var lbl := $Label

# 如果你想在调试时让指示器在场景实例化时可见，可设置为 true
@export var visible_on_start: bool = false

func _ready():
	visible = visible_on_start
	var ai = get_node_or_null("/root/AIService")
	if ai:
		var cb_start = Callable(self, "_on_auto_save_started")
		var cb_done = Callable(self, "_on_auto_save_completed")
		if not ai.is_connected("auto_save_started", cb_start):
			ai.connect("auto_save_started", cb_start)
		if not ai.is_connected("auto_save_completed", cb_done):
			ai.connect("auto_save_completed", cb_done)

func _on_auto_save_started(message: String) -> void:
	lbl.text = message
	visible = true

func _on_auto_save_completed(summary: String) -> void:
	# 简单短暂反馈：显示“已保存” 1.2 秒后隐藏
	# lbl.text = "已保存"
	# visible = true
	# await get_tree().create_timer(1.2).timeout
	visible = false
