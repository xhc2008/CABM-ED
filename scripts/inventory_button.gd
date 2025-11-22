extends Button

# 背包按钮 - 放在左上角

var inventory_ui: Control = null

func _ready():
	pressed.connect(_on_pressed)
	
	# 延迟加载背包UI
	call_deferred("_setup_inventory_ui")

func _setup_inventory_ui():
	"""延迟设置背包UI"""
	var inventory_scene = preload("res://scenes/inventory_ui.tscn")
	inventory_ui = inventory_scene.instantiate()
	var tree = get_tree()
	if tree != null and tree.root != null:
		tree.root.add_child(inventory_ui)
	else:
		var parent = get_parent()
		if parent != null:
			parent.add_child(inventory_ui)
		else:
			add_child(inventory_ui)
	inventory_ui.hide()

func _on_pressed():
	"""点击按钮"""
	if inventory_ui:
		inventory_ui.toggle_visibility()
