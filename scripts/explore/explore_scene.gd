extends Node2D

func _ready():
	pass

func _on_exit_button_pressed():
	# 返回主场景
	get_tree().change_scene_to_file("res://scripts/main.tscn")
