extends Node2D

@onready var player = $Player
@onready var snow_fox = $SnowFox
@onready var joystick = $UI/VirtualJoystick

func _ready():
	# 设置雪狐跟随玩家
	if snow_fox and player:
		snow_fox.set_follow_target(player)
	
	# 连接摇杆信号
	if joystick and player:
		joystick.direction_changed.connect(_on_joystick_direction_changed)

func _on_joystick_direction_changed(direction: Vector2):
	if player:
		player.set_joystick_direction(direction)

func _on_exit_button_pressed():
	# 返回主场景
	get_tree().change_scene_to_file("res://scripts/main.tscn")
