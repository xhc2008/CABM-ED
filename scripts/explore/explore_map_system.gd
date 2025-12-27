extends Node

class_name ExploreMapSystem

# 地图系统 - 管理探索模式的小地图和大地图
# 使用简单的图片加载方式

@onready var player: Node2D
@onready var background_layer: TileMapLayer
@onready var frontground_layer: TileMapLayer

var minimap_ui: Control
var fullmap_ui: Control
var map_texture: Texture2D
var map_loaded: bool = false
var current_scene_name: String = ""

# 地图参数
const MINIMAP_SIZE = Vector2(150, 150)

# 地图边界（世界坐标）
var map_bounds: Rect2 = Rect2(0, 0, 1000, 1000)  # 默认边界，后续会根据实际地图调整

func _ready():
	pass

func setup(p_player: Node2D, p_background_layer: TileMapLayer, p_frontground_layer: TileMapLayer, scene_name: String = ""):
	player = p_player
	background_layer = p_background_layer
	frontground_layer = p_frontground_layer
	current_scene_name = scene_name

	# 加载地图纹理
	load_map_texture()

	# 计算地图边界
	calculate_map_bounds()

func calculate_map_bounds():
	"""计算地图的世界边界"""
	if not background_layer:
		return

	# 获取地图边界（使用合并的used_rect）
	var bg_used_rect = background_layer.get_used_rect()
	var fg_used_rect = Rect2i(0, 0, 0, 0)
	if frontground_layer:
		fg_used_rect = frontground_layer.get_used_rect()

	# 计算并集
	var min_x = min(bg_used_rect.position.x, fg_used_rect.position.x)
	var min_y = min(bg_used_rect.position.y, fg_used_rect.position.y)
	var max_x = max(bg_used_rect.position.x + bg_used_rect.size.x, fg_used_rect.position.x + fg_used_rect.size.x)
	var max_y = max(bg_used_rect.position.y + bg_used_rect.size.y, fg_used_rect.position.y + fg_used_rect.size.y)

	var combined_used_rect = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)

	var tile_size = background_layer.tile_set.tile_size
	map_bounds = Rect2(
		background_layer.map_to_local(combined_used_rect.position),
		Vector2(combined_used_rect.size.x * tile_size.x, combined_used_rect.size.y * tile_size.y)
	)

	print("计算地图边界: ", map_bounds)

func load_map_texture() -> bool:
	"""加载地图纹理 - 直接从assets/images/map/目录加载图片"""
	if map_loaded:
		return map_texture != null

	# 构建地图图片路径
	var map_path = "res://assets/images/map/%s.png" % current_scene_name

	print("尝试加载地图图片: ", map_path)

	# 检查文件是否存在
	if not FileAccess.file_exists(map_path):
		print("地图图片不存在: ", map_path, " - 将显示NO SIGNAL")
		map_texture = null
		map_loaded = true
		return false

	# 加载图片
	var image = Image.new()
	var load_result = image.load(map_path)

	if load_result != OK:
		print("加载地图图片失败: ", load_result, " 路径: ", map_path)
		map_texture = null
		map_loaded = true
		return false

	# 创建纹理
	map_texture = ImageTexture.create_from_image(image)
	map_loaded = true

	print("地图图片加载成功: ", map_path, " 尺寸: ", image.get_size())
	return true


func create_minimap_ui() -> Control:
	"""创建小地图UI"""
	minimap_ui = Control.new()
	minimap_ui.name = "MinimapUI"
	minimap_ui.custom_minimum_size = MINIMAP_SIZE
	minimap_ui.size = MINIMAP_SIZE

	# 设置锚点到左上角，固定大小和位置
	minimap_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap_ui.position = Vector2(20, 20)  # 从屏幕左上角偏移20像素

	# 创建圆形背景
	var background = Panel.new()
	background.name = "Background"
	background.custom_minimum_size = MINIMAP_SIZE
	background.size = MINIMAP_SIZE

	# 创建圆形背景样式
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)  # 半透明黑色背景
	bg_style.set_corner_radius_all(int(MINIMAP_SIZE.x / 2))  # 圆角半径
	background.add_theme_stylebox_override("panel", bg_style)

	minimap_ui.add_child(background)

	# 创建圆形边框
	var border = Panel.new()
	border.name = "Border"
	border.custom_minimum_size = MINIMAP_SIZE + Vector2(4, 4)  # 比背景大4像素
	border.size = MINIMAP_SIZE + Vector2(4, 4)
	border.position = Vector2(-2, -2)  # 居中对齐

	# 创建圆形边框样式
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)  # 透明背景
	border_style.set_corner_radius_all(int((MINIMAP_SIZE.x + 4) / 2))  # 圆角半径
	border_style.border_width_left = 2
	border_style.border_width_top = 2
	border_style.border_width_right = 2
	border_style.border_width_bottom = 2
	border_style.border_color = Color(0.5, 0.5, 0.5, 0.5)  # 灰色边框
	border.add_theme_stylebox_override("panel", border_style)

	minimap_ui.add_child(border)

	# 创建SubViewport用于圆形裁剪
	var sub_viewport = SubViewport.new()
	sub_viewport.name = "SubViewport"
	sub_viewport.size = MINIMAP_SIZE
	sub_viewport.transparent_bg = true
	sub_viewport.disable_3d = true
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	background.add_child(sub_viewport)

	# 在SubViewport中创建地图显示区域
	var map_display = TextureRect.new()
	map_display.name = "MapDisplay"
	map_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	map_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_display.custom_minimum_size = MINIMAP_SIZE
	map_display.size = MINIMAP_SIZE
	map_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sub_viewport.add_child(map_display)

	# 创建ViewportTexture显示裁剪结果
	var viewport_texture = sub_viewport.get_texture()
	var display_rect = TextureRect.new()
	display_rect.name = "DisplayRect"
	display_rect.texture = viewport_texture
	display_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display_rect.custom_minimum_size = MINIMAP_SIZE
	display_rect.size = MINIMAP_SIZE
	display_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 应用圆形裁剪Shader
	var circle_shader = Shader.new()
	circle_shader.code = """
	shader_type canvas_item;

	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		float radius = 0.5;
		vec2 pos = UV - center;
		float dist = length(pos);

		if (dist > radius) {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0); // 透明
		} else {
			COLOR = texture(TEXTURE, UV); // 显示纹理
		}
	}
	"""

	var circle_material = ShaderMaterial.new()
	circle_material.shader = circle_shader
	display_rect.material = circle_material

	background.add_child(display_rect)

	# 小地图初始状态：如果没有地图，显示NO SIGNAL；有地图时会动态更新局部区域
	if not map_texture:
		# 创建NO SIGNAL标签
		var no_signal_label = Label.new()
		no_signal_label.name = "NoSignalLabel"
		no_signal_label.text = " NO SIGNAL"
		no_signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_signal_label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))  # 橙色
		no_signal_label.add_theme_font_size_override("font_size", 16)
		no_signal_label.custom_minimum_size = MINIMAP_SIZE
		no_signal_label.size = MINIMAP_SIZE

		sub_viewport.add_child(no_signal_label)

	# 创建玩家位置指示器（箭头形状）
	var player_indicator = Polygon2D.new()
	player_indicator.name = "PlayerIndicator"
	player_indicator.color = Color(1, 0, 0, 1.0)  # 鲜红色

	# 创建箭头形状（指向右侧）
	var arrow_points = PackedVector2Array([
		Vector2(-8, -6),  # 左上
		Vector2(8, 0),    # 右中
		Vector2(-8, 6),   # 左下
		Vector2(-3, 0)    # 左中（箭尾）
	])
	player_indicator.polygon = arrow_points
	player_indicator.position = MINIMAP_SIZE / 2  # 居中
	sub_viewport.add_child(player_indicator)

	# 创建方向标识
	_create_direction_labels(minimap_ui)

	# 连接点击事件
	var button = Button.new()
	button.name = "MinimapButton"
	button.custom_minimum_size = MINIMAP_SIZE
	button.size = MINIMAP_SIZE
	button.flat = true
	button.pressed.connect(_on_minimap_pressed)
	minimap_ui.add_child(button)

	return minimap_ui

func _create_direction_labels(parent: Control):
	"""创建方向标识标签"""
	var directions = ["N", "S", "E", "W"]
	var positions = [
		Vector2(MINIMAP_SIZE.x / 2 - 4, 0),  # N
		Vector2(MINIMAP_SIZE.x / 2 - 4, MINIMAP_SIZE.y-15),  # S
		Vector2(MINIMAP_SIZE.x-8, MINIMAP_SIZE.y / 2 - 8),  # E
		Vector2(0, MINIMAP_SIZE.y / 2 - 8)  # W
	]

	for i in range(directions.size()):
		var label = Label.new()
		label.text = directions[i]
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		label.add_theme_font_size_override("font_size", 12)
		label.position = positions[i]
		parent.add_child(label)

func create_fullmap_ui() -> Control:
	"""创建大地图UI"""
	fullmap_ui = Control.new()
	fullmap_ui.name = "FullmapUI"
	fullmap_ui.visible = false
	fullmap_ui.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 创建背景遮罩
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.8)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullmap_ui.add_child(backdrop)

	# 创建地图容器
	var map_container = Control.new()
	map_container.name = "MapContainer"
	map_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_container.offset_left = 100
	map_container.offset_right = -100
	map_container.offset_top = 80
	map_container.offset_bottom = -80
	fullmap_ui.add_child(map_container)

	# 创建地图显示
	var map_display = TextureRect.new()
	map_display.name = "MapDisplay"
	map_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH  # 填充宽度
	map_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # 保持宽高比居中
	map_display.set_anchors_preset(Control.PRESET_FULL_RECT)  # 填充整个区域
	map_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 如果有地图纹理，设置纹理；否则显示NO SIGNAL
	if map_texture:
		map_display.texture = map_texture
	else:
		# 创建NO SIGNAL标签
		var no_signal_label = Label.new()
		no_signal_label.name = "NoSignalLabel"
		no_signal_label.text = "NO SIGNAL"
		no_signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_signal_label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))  # 橙色
		no_signal_label.add_theme_font_size_override("font_size", 48)
		no_signal_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		map_display.add_child(no_signal_label)

	map_container.add_child(map_display)

	# 创建玩家位置指示器（箭头形状）
	var player_indicator = Polygon2D.new()
	player_indicator.name = "PlayerIndicator"
	player_indicator.color = Color(1, 0, 0, 1.0)  # 鲜红色

	# 创建箭头形状（指向右侧）
	var arrow_points = PackedVector2Array([
		Vector2(-8, -6),  # 左上
		Vector2(8, 0),    # 右中
		Vector2(-8, 6),   # 左下
		Vector2(-3, 0)    # 左中（箭尾）
	])
	player_indicator.polygon = arrow_points
	map_display.add_child(player_indicator)

	# 创建关闭按钮
	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭地图 (ESC)"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.size = Vector2(120, 40)

	# 设置关闭按钮位置（右上角）
	close_button.anchor_right = 1.0
	close_button.anchor_top = 0.0
	close_button.offset_right = -20
	close_button.offset_top = 20
	close_button.pressed.connect(_on_fullmap_closed)
	fullmap_ui.add_child(close_button)

	return fullmap_ui

func _on_minimap_pressed():
	"""小地图点击事件"""
	show_fullmap()

func show_fullmap():
	"""显示大地图"""
	if not fullmap_ui:
		return

	# 更新地图显示的缩放和位置
	_update_fullmap_display()

	fullmap_ui.visible = true
	update_player_position()

	# 通知探索场景禁用交互
	if get_parent().has_method("_on_fullmap_opened"):
		get_parent()._on_fullmap_opened()

func hide_fullmap():
	"""隐藏大地图"""
	if fullmap_ui:
		fullmap_ui.visible = false

	# 通知探索场景恢复交互
	if get_parent().has_method("_on_fullmap_closed"):
		get_parent()._on_fullmap_closed()

func _update_fullmap_display():
	"""更新大地图显示的缩放和位置"""
	if not fullmap_ui or not map_texture:
		return

	var map_display = fullmap_ui.get_node("MapContainer/MapDisplay")
	if not map_display:
		return

	var texture_size = map_texture.get_size()
	var container = fullmap_ui.get_node("MapContainer")
	var container_size = container.size

	# 使用EXPAND_FIT_WIDTH时，TextureRect会自动按比例缩放填充容器
	# 这里不需要手动设置缩放，直接设置纹理即可
	map_display.texture = map_texture

	print("大地图显示更新 - 纹理尺寸: ", texture_size, " 容器尺寸: ", container_size)

func _on_fullmap_closed():
	"""大地图关闭事件"""
	hide_fullmap()

func update_player_position():
	"""更新玩家位置指示器"""
	if not player:
		return

	# 如果没有地图纹理，不显示玩家指示器
	if not map_texture:
		if minimap_ui:
			var player_indicator = minimap_ui.get_node("Background/SubViewport/PlayerIndicator")
			if player_indicator:
				player_indicator.visible = false

		if fullmap_ui and fullmap_ui.visible:
			var map_display = fullmap_ui.get_node("MapContainer/MapDisplay")
			var player_indicator = map_display.get_node("PlayerIndicator")
			if player_indicator:
				player_indicator.visible = false
		return

	# 计算玩家在世界坐标中的相对位置（四个角映射）
	var player_pos = player.global_position
	var relative_pos = (player_pos - map_bounds.position) / map_bounds.size
	var normalized_pos = relative_pos.clamp(Vector2(0, 0), Vector2(1, 1))

	# 获取玩家朝向角度
	var player_rotation = player.rotation if player else 0.0

	# 更新小地图玩家位置和显示区域
	if minimap_ui:
		var player_indicator = minimap_ui.get_node("Background/SubViewport/PlayerIndicator")

		# 小地图上玩家指示标永远在中心
		player_indicator.position = MINIMAP_SIZE / 2
		player_indicator.rotation = player_rotation
		player_indicator.visible = true

		# 更新小地图显示的局部区域
		_update_minimap_view()

	# 更新大地图玩家位置
	if fullmap_ui and fullmap_ui.visible:
		var map_container = fullmap_ui.get_node("MapContainer")
		var map_display = map_container.get_node("MapDisplay")
		var player_indicator = map_display.get_node("PlayerIndicator")

		if map_texture:
			# 使用EXPAND_FIT_WIDTH时，地图按比例填充容器
			var container_size = map_container.size
			var texture_size = map_texture.get_size()

			# 计算实际显示的缩放比例和位置
			var scale_x = container_size.x / texture_size.x
			var scale_y = container_size.y / texture_size.y
			var scale = min(scale_x, scale_y)

			# 计算地图在容器中的实际显示区域
			var display_size = texture_size * scale
			var display_pos = (container_size - display_size) / 2

			# 计算玩家在地图上的位置
			player_indicator.position = display_pos + normalized_pos * display_size
			player_indicator.rotation = player_rotation
			player_indicator.visible = true
		else:
			# 没有地图时，隐藏玩家指示标
			player_indicator.visible = false

func _update_minimap_view():
	"""更新小地图的显示区域 - 显示玩家周围的局部区域"""
	if not minimap_ui or not map_texture:
		return

	var map_display = minimap_ui.get_node("Background/SubViewport/MapDisplay")
	if not map_texture:
		return

	# 小地图显示玩家周围的区域（比如15个瓦片的半径）
	var minimap_view_radius_tiles = 60.0
	var view_radius_world = minimap_view_radius_tiles * (background_layer.tile_set.tile_size.x if background_layer else 64)
	var view_size_world = Vector2(view_radius_world * 2, view_radius_world * 2)

	# 计算玩家位置在地图边界中的相对位置
	var player_pos = player.global_position
	var relative_pos = (player_pos - map_bounds.position) / map_bounds.size
	relative_pos = relative_pos.clamp(Vector2(0, 0), Vector2(1, 1))

	# 计算要显示的世界区域
	var view_center_world = map_bounds.position + relative_pos * map_bounds.size
	var view_start_world = view_center_world - view_size_world / 2

	# 确保显示区域不超出地图边界
	view_start_world.x = clamp(view_start_world.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x - view_size_world.x)
	view_start_world.y = clamp(view_start_world.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y - view_size_world.y)

	var clamped_view_rect = Rect2(view_start_world, view_size_world)

	# 计算在图片坐标系中的区域
	var image_size = map_texture.get_size()
	var texture_start = ((clamped_view_rect.position - map_bounds.position) / map_bounds.size) * image_size
	var texture_size = (clamped_view_rect.size / map_bounds.size) * image_size

	# 确保纹理区域不超出图片边界
	texture_start = texture_start.clamp(Vector2(0, 0), image_size - texture_size)
	texture_size = texture_size.clamp(Vector2(0, 0), image_size - texture_start)

	# 创建AtlasTexture来显示局部区域
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = map_texture
	atlas_texture.region = Rect2(texture_start, texture_size)

	# 设置TextureRect使用局部纹理
	map_display.texture = atlas_texture

func _process(_delta):
	"""每帧更新玩家位置"""
	if map_loaded and (minimap_ui or (fullmap_ui and fullmap_ui.visible)):
		update_player_position()

func _input(event):
	"""处理输入事件"""
	if fullmap_ui and fullmap_ui.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			hide_fullmap()
			get_viewport().set_input_as_handled()
