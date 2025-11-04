@tool
extends EditorScript

# 这是一个编辑器脚本，用于快速创建探索场景的UI结构
# 使用方法：
# 1. 打开 explore_scene.tscn
# 2. 在脚本编辑器中打开此文件
# 3. 点击 File -> Run (或按 Ctrl+Shift+X)

func _run():
	var scene_root = get_scene()
	if not scene_root:
		print("错误: 请先打开 explore_scene.tscn")
		return
	
	# 查找或创建UI层
	var ui_layer = scene_root.get_node_or_null("UI")
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		scene_root.add_child(ui_layer)
		ui_layer.owner = scene_root
		print("创建 UI CanvasLayer")
	
	# 创建 InteractionPrompt
	create_interaction_prompt(ui_layer, scene_root)
	
	# 创建 InventoryUI
	create_inventory_ui(ui_layer, scene_root)
	
	# 创建 InventoryButton
	create_inventory_button(ui_layer, scene_root)
	
	print("UI结构创建完成！")
	print("请保存场景并检查各个节点的设置")

func create_interaction_prompt(parent: Node, root: Node):
	var prompt = parent.get_node_or_null("InteractionPrompt")
	if prompt:
		print("InteractionPrompt 已存在")
		return
	
	# 创建主容器
	prompt = Control.new()
	prompt.name = "InteractionPrompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	prompt.offset_left = -250
	prompt.offset_right = -50
	prompt.offset_top = -100
	prompt.offset_bottom = 100
	
	var script = load("res://scripts/explore/interaction_prompt.gd")
	prompt.set_script(script)
	
	# 创建Panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 创建VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# 创建PromptList
	var prompt_list = VBoxContainer.new()
	prompt_list.name = "PromptList"
	prompt_list.add_theme_constant_override("separation", 5)
	
	# 组装
	vbox.add_child(prompt_list)
	panel.add_child(vbox)
	prompt.add_child(panel)
	
	parent.add_child(prompt)
	prompt.owner = root
	panel.owner = root
	vbox.owner = root
	prompt_list.owner = root
	
	print("创建 InteractionPrompt")

func create_inventory_ui(parent: Node, root: Node):
	var inv_ui = parent.get_node_or_null("InventoryUI")
	if inv_ui:
		print("InventoryUI 已存在")
		return
	
	# 创建主容器
	inv_ui = Control.new()
	inv_ui.name = "InventoryUI"
	inv_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_ui.mouse_filter = Control.MOUSE_FILTER_STOP  # 阻止鼠标穿透
	
	var script = load("res://scripts/explore/explore_inventory_ui.gd")
	inv_ui.set_script(script)
	
	# 创建半透明背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 创建主Panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1000, 600)
	panel.offset_left = -500
	panel.offset_right = 500
	panel.offset_top = -300
	panel.offset_bottom = 300
	
	# 创建关闭按钮
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -40
	close_btn.offset_right = -10
	close_btn.offset_top = 10
	close_btn.offset_bottom = 40
	
	# 创建HBoxContainer
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 10
	hbox.offset_top = 50
	hbox.offset_right = -10
	hbox.offset_bottom = -10
	hbox.add_theme_constant_override("separation", 10)
	
	# 创建玩家背包面板
	var player_panel = create_inventory_panel("PlayerInventoryPanel", "背包", 6)
	
	# 创建存储面板
	var storage_panel = create_inventory_panel("StoragePanel", "宝箱", 4)
	
	# 创建物品信息面板
	var info_panel = create_info_panel()
	
	# 组装
	hbox.add_child(player_panel)
	hbox.add_child(storage_panel)
	hbox.add_child(info_panel)
	
	panel.add_child(close_btn)
	panel.add_child(hbox)
	
	inv_ui.add_child(bg)
	inv_ui.add_child(panel)
	
	parent.add_child(inv_ui)
	inv_ui.owner = root
	bg.owner = root
	panel.owner = root
	close_btn.owner = root
	hbox.owner = root
	
	# 设置子节点owner
	set_all_owners(player_panel, root)
	set_all_owners(storage_panel, root)
	set_all_owners(info_panel, root)
	
	print("创建 InventoryUI")

func create_inventory_panel(panel_name: String, title: String, columns: int) -> Panel:
	var panel = Panel.new()
	panel.name = panel_name
	panel.custom_minimum_size = Vector2(300, 400)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	
	var title_label = Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var grid = GridContainer.new()
	grid.name = "InventoryGrid" if panel_name == "PlayerInventoryPanel" else "StorageGrid"
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	
	scroll.add_child(grid)
	vbox.add_child(title_label)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	
	return panel

func create_info_panel() -> Panel:
	var panel = Panel.new()
	panel.name = "ItemInfoPanel"
	panel.custom_minimum_size = Vector2(250, 400)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)
	
	var name_label = Label.new()
	name_label.name = "ItemName"
	name_label.text = "选择物品查看详情"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	
	var icon = TextureRect.new()
	icon.name = "ItemIcon"
	icon.custom_minimum_size = Vector2(128, 128)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var desc_label = Label.new()
	desc_label.name = "ItemDescription"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	scroll.add_child(desc_label)
	vbox.add_child(name_label)
	vbox.add_child(icon)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	
	return panel

func create_inventory_button(parent: Node, root: Node):
	var btn = parent.get_node_or_null("InventoryButton")
	if btn:
		print("InventoryButton 已存在")
		return
	
	btn = Button.new()
	btn.name = "InventoryButton"
	btn.text = "背包 (B)"
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -120
	btn.offset_right = -10
	btn.offset_top = 10
	btn.offset_bottom = 50
	
	parent.add_child(btn)
	btn.owner = root
	
	print("创建 InventoryButton")

func set_all_owners(node: Node, owner: Node):
	node.owner = owner
	for child in node.get_children():
		set_all_owners(child, owner)
