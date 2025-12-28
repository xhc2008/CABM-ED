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
const MAP_COMPRESSION_RATIO = 8  # 地图图片的压缩比例（8x8压缩为1px）

# 地图边界（世界坐标）
var map_bounds: Rect2 = Rect2(0, 0, 1000, 1000)  # 默认边界，后续会根据实际地图调整

# 位置校准值映射表 - 场景ID到校准值的映射，用于修正不同场景的计算偏差
var position_calibration_map: Dictionary = {
	"forest": Vector2(-250, 0), 
	"darkice": Vector2(-365, 0), 
}

# 当前使用的校准值
var position_calibration: Vector2 = Vector2(0, 0)

func _ready():
	pass

func setup(p_player: Node2D, p_background_layer: TileMapLayer, p_frontground_layer: TileMapLayer, scene_name: String = ""):
	player = p_player
	background_layer = p_background_layer
	frontground_layer = p_frontground_layer
	current_scene_name = scene_name

	# 根据场景名称设置校准值
	if position_calibration_map.has(scene_name):
		position_calibration = position_calibration_map[scene_name]
	else:
		position_calibration = position_calibration_map.get("default", Vector2.ZERO)

	# 加载地图纹理
	load_map_texture()

	# 计算地图边界
	calculate_map_bounds()
	
	# 调试输出
	if map_texture:
		print("=== 地图调试信息 ===")
		print("场景名称: ", scene_name)
		print("地图图片尺寸: ", map_texture.get_size())
		print("世界边界: ", map_bounds)
		print("使用的校准值: ", position_calibration)

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

	var world_position = Vector2(combined_used_rect.position.x * tile_size.x, combined_used_rect.position.y * tile_size.y)
	var world_size = Vector2(combined_used_rect.size.x * tile_size.x, combined_used_rect.size.y * tile_size.y)

	map_bounds = Rect2(world_position, world_size)

	print("计算地图边界: ", map_bounds, " 瓦片大小: ", tile_size)

func load_map_texture() -> bool:
	"""加载地图纹理 - 使用load()加载已import的图片资源"""
	if map_loaded:
		return map_texture != null

	# 构建地图图片路径
	var map_path = "res://assets/images/map/%s.png" % current_scene_name

	print("尝试加载地图图片: ", map_path)

	# 使用load()加载已import的纹理资源
	map_texture = load(map_path) as Texture2D

	if not map_texture:
		print("地图图片不存在或加载失败: ", map_path, " - 将显示NO SIGNAL")
		map_loaded = true
		return false

	print("地图图片加载成功: ", map_path, " 尺寸: ", map_texture.get_size())
	map_loaded = true
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
	map_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 忽略尺寸，使用 stretch_mode
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
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return

	# 如果没有地图纹理，不显示玩家指示器
	if not map_texture:
		if minimap_ui:
			var player_indicator = minimap_ui.get_node_or_null("Background/SubViewport/PlayerIndicator")
			if player_indicator:
				player_indicator.visible = false

		if fullmap_ui and fullmap_ui.visible:
			var map_display = fullmap_ui.get_node_or_null("MapContainer/MapDisplay")
			if map_display:
				var player_indicator = map_display.get_node_or_null("PlayerIndicator")
				if player_indicator:
					player_indicator.visible = false
		return

	# 计算玩家在世界坐标中的位置
	var player_pos = player.global_position + position_calibration  # 应用校准值

	# 获取玩家朝向角度
	var player_rotation = player.rotation if player else 0.0

	# 更新小地图玩家位置和显示区域
	if minimap_ui:
		var player_indicator = minimap_ui.get_node_or_null("Background/SubViewport/PlayerIndicator")
		if not player_indicator:
			return

		# 小地图上玩家指示标永远在中心
		player_indicator.position = MINIMAP_SIZE / 2
		player_indicator.rotation = player_rotation
		player_indicator.visible = true

		# 更新小地图显示的局部区域
		_update_minimap_view()

	# 更新大地图玩家位置
	if fullmap_ui and fullmap_ui.visible:
		var map_container = fullmap_ui.get_node_or_null("MapContainer")
		if not map_container:
			return
			
		var map_display = map_container.get_node_or_null("MapDisplay")
		if not map_display:
			return
			
		var player_indicator = map_display.get_node_or_null("PlayerIndicator")
		if not player_indicator:
			return

		if map_texture:
			var container_size = map_container.size
			var texture_size = map_texture.get_size()

			# 计算实际显示的缩放比例（保持宽高比）
			var display_scale_x = container_size.x / texture_size.x
			var display_scale_y = container_size.y / texture_size.y
			var display_scale = min(display_scale_x, display_scale_y)

			# 计算地图图片在容器中的实际显示区域
			var display_size = texture_size * display_scale
			var display_pos = (container_size - display_size) / 2

			# 地图图片的实际世界尺寸（考虑压缩比例）
			var actual_image_world_size = texture_size * MAP_COMPRESSION_RATIO
			
			# 计算地图图片覆盖的世界区域（居中对齐到 map_bounds）
			var image_world_offset = (actual_image_world_size - map_bounds.size) / 2.0
			var image_world_position = map_bounds.position - image_world_offset

			# 计算玩家在地图图片世界区域中的归一化位置
			var player_normalized = (player_pos - image_world_position) / actual_image_world_size
			player_normalized = player_normalized.clamp(Vector2(0, 0), Vector2(1, 1))

			# 调试输出
			if Engine.get_frames_drawn() % 60 == 0:
				print("=== 大地图位置调试 ===")
				print("玩家世界位置: ", player_pos - position_calibration)  # 显示原始位置
				print("应用校准后位置: ", player_pos)
				print("地图边界(map_bounds): ", map_bounds)
				print("地图图片尺寸: ", texture_size)
				print("地图图片宽高比: ", texture_size.x / texture_size.y)
				print("地图实际世界尺寸: ", actual_image_world_size)
				print("地图实际世界宽高比: ", actual_image_world_size.x / actual_image_world_size.y)
				print("图片世界偏移: ", image_world_offset)
				print("图片世界起始位置: ", image_world_position)
				print("压缩比例: ", MAP_COMPRESSION_RATIO)
				print("归一化位置: ", player_normalized)
				print("容器尺寸: ", container_size)
				print("容器宽高比: ", container_size.x / container_size.y)
				print("显示缩放: x=", display_scale_x, " y=", display_scale_y, " 使用=", display_scale)
				print("显示尺寸: ", display_size)
				print("显示位置: ", display_pos)
				print("最终指示器位置: ", display_pos + player_normalized * display_size)
				print("校准值: ", position_calibration)

			# 计算玩家在显示区域上的最终位置
			player_indicator.position = display_pos + player_normalized * display_size
			player_indicator.rotation = player_rotation
			player_indicator.visible = true
		else:
			# 没有地图时，隐藏玩家指示标
			player_indicator.visible = false

func _update_minimap_view():
	"""更新小地图的显示区域 - 显示玩家周围的局部区域"""
	if not minimap_ui or not map_texture or not player:
		return

	var map_display = minimap_ui.get_node_or_null("Background/SubViewport/MapDisplay")
	if not map_display:
		return

	# 获取地图图片尺寸
	var image_size = map_texture.get_size()
	
	# 地图图片的实际世界尺寸（考虑压缩比例）
	var actual_image_world_size = image_size * MAP_COMPRESSION_RATIO
	
	# 计算地图图片覆盖的世界区域（居中对齐到 map_bounds）
	var image_world_offset = (actual_image_world_size - map_bounds.size) / 2.0
	var image_world_position = map_bounds.position - image_world_offset

	# 计算世界坐标到像素的缩放比例
	var world_to_pixel_scale = image_size.x / actual_image_world_size.x  # 应该等于 1/MAP_COMPRESSION_RATIO

	# 小地图显示区域大小（世界坐标）
	var minimap_world_size = MINIMAP_SIZE / world_to_pixel_scale

	# 计算玩家位置（应用校准值）
	var player_pos = player.global_position + position_calibration
	
	# 计算要显示的世界区域中心（基于玩家位置）
	var view_center_world = player_pos
	var view_start_world = view_center_world - minimap_world_size / 2

	# 计算在图片坐标系中的区域（使用图片的世界起始位置）
	var texture_start = (view_start_world - image_world_position) * world_to_pixel_scale
	var texture_size = minimap_world_size * world_to_pixel_scale

	# 创建显示图像
	var display_image = Image.create(int(MINIMAP_SIZE.x), int(MINIMAP_SIZE.y), false, Image.FORMAT_RGBA8)
	display_image.fill(Color(0, 0, 0, 0))  # 透明填充

	# 计算地图在显示区域中的位置
	var map_in_display_pos = -texture_start * (MINIMAP_SIZE / texture_size)
	var map_in_display_size = image_size * (MINIMAP_SIZE / texture_size)

	# 计算有效的显示区域
	var display_rect = Rect2(Vector2.ZERO, MINIMAP_SIZE)
	var map_rect = Rect2(map_in_display_pos, map_in_display_size)
	var valid_rect = display_rect.intersection(map_rect)

	if valid_rect.has_area():
		# 计算对应的源图像区域
		var source_start = (valid_rect.position - map_in_display_pos) * (image_size / map_in_display_size)
		var source_size = valid_rect.size * (image_size / map_in_display_size)

		# 确保源区域在图片边界内
		source_start.x = clamp(source_start.x, 0, image_size.x)
		source_start.y = clamp(source_start.y, 0, image_size.y)
		source_size.x = clamp(source_size.x, 0, image_size.x - source_start.x)
		source_size.y = clamp(source_size.y, 0, image_size.y - source_start.y)

		if source_size.x > 0 and source_size.y > 0:
			var source_image = map_texture.get_image()
			# 转换源图像格式以匹配目标图像格式
			if source_image.get_format() != display_image.get_format():
				source_image.convert(display_image.get_format())

			# 复制图像区域
			var source_rect = Rect2i(int(source_start.x), int(source_start.y), int(source_size.x), int(source_size.y))
			var dest_pos = Vector2i(int(valid_rect.position.x), int(valid_rect.position.y))
			display_image.blit_rect(source_image, source_rect, dest_pos)

	# 更新纹理
	var dynamic_texture = ImageTexture.create_from_image(display_image)
	map_display.texture = dynamic_texture

func _process(_delta):
	"""每帧更新玩家位置"""
	if not is_inside_tree():
		return
		
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
		
	if map_loaded and (minimap_ui or (fullmap_ui and fullmap_ui.visible)):
		update_player_position()

func _input(event):
	"""处理输入事件"""
	if fullmap_ui and fullmap_ui.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			hide_fullmap()
			get_viewport().set_input_as_handled()
