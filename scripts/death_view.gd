extends Control

## 死亡界面
## 显示玩家死亡信息并提供返回选项

signal death_view_closed

@onready var return_button: Button = $Panel/VBox/ReturnButton
@onready var backdrop: ColorRect = $Backdrop
@onready var vignette: ColorRect = $VignetteEffect
@onready var panel: Panel = $Panel

func _ready():
	if return_button:
		return_button.pressed.connect(_on_return_pressed)
	
	# 播放淡入动画
	_play_fade_in_animation()

func _play_fade_in_animation():
	"""播放淡入动画"""
	# 初始状态
	if backdrop:
		backdrop.modulate.a = 0.0
	if vignette:
		vignette.modulate.a = 0.0
	if panel:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.8, 0.8)
	
	# 创建动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 背景淡入
	if backdrop:
		tween.tween_property(backdrop, "modulate:a", 1.0, 0.5)
	
	# 暗角效果淡入
	if vignette:
		tween.tween_property(vignette, "modulate:a", 0.3, 0.8)
	
	# 面板淡入并放大
	if panel:
		tween.tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.2)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.4).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_return_pressed():
	"""点击返回按钮"""
	print("死亡界面：玩家点击返回")
	death_view_closed.emit()
	# 不在这里处理场景切换，由 explore_scene 处理