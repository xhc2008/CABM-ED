extends Node2D
class_name SparkEffect

# 火花效果 - 子弹击中障碍的动画

var animated_sprite: AnimatedSprite2D
var animation_player: AnimationPlayer

func _ready():
	animated_sprite = $AnimatedSprite2D
	if not animated_sprite:
		# 如果没有AnimatedSprite2D，创建一个简单的效果
		_create_simple_effect()
		return
	
	# 加载火花动画
	_setup_spark_animation()
	
	# 播放动画
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("spark"):
		animated_sprite.play("spark")
		# 动画结束后删除
		if animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_animation_finished)
		animated_sprite.animation_finished.connect(_on_animation_finished)
	else:
		# 如果动画设置失败，使用简单效果
		_create_simple_effect()

func _setup_spark_animation():
	"""设置火花动画"""
	# 创建动画库
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("spark")
	sprite_frames.set_animation_speed("spark", 10.0)  # 设置动画速度
	sprite_frames.set_animation_loop("spark", false)  # 不循环
	
	# 加载火花图片
	var spark_images = [
		load("res://assets/images/explore/spark/spark_001.png"),
		load("res://assets/images/explore/spark/spark_002.png"),
		load("res://assets/images/explore/spark/spark_003.png")
	]
	
	for img in spark_images:
		if img:
			sprite_frames.add_frame("spark", img)
	
	animated_sprite.sprite_frames = sprite_frames

func _create_simple_effect():
	"""创建简单的火花效果（如果没有动画）"""
	# 创建一个简单的粒子效果或定时删除
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _on_animation_finished():
	"""动画结束"""
	queue_free()

