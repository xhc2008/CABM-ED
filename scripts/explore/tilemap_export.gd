extends Node

@export var map_scene_path: String = "res://scenes/explore_maps/darkice.tscn"
@export var output_filename: String = "forest_rendered.png"

func _ready():
	render_and_save_map()

func render_and_save_map():
	# 加载地图场景
	var map_scene = load(map_scene_path)
	if not map_scene:
		print("Failed to load map scene: ", map_scene_path)
		return

	# 实例化场景
	var map_instance = map_scene.instantiate()
	if not map_instance:
		print("Failed to instantiate map scene")
		return

	# 将实例添加到场景树中以确保它完全初始化
	add_child(map_instance)

	# 等待场景完全加载和初始化
	await get_tree().process_frame
	await get_tree().process_frame

	# 查找TileMapLayersContainer（它是根节点）
	var container = map_instance
	if container.name != "TileMapLayersContainer":
		print("Root node is not TileMapLayersContainer, name: ", container.name)
		map_instance.queue_free()
		return

	# 获取Background和Frontground图层
	var background_layer = container.get_node_or_null("Background")
	var frontground_layer = container.get_node_or_null("Frontground")

	if not background_layer or not frontground_layer:
		print("Background or Frontground layer not found")
		return

	# 计算地图的边界
	var background_rect = get_tilemap_bounds(background_layer)
	var frontground_rect = get_tilemap_bounds(frontground_layer)

	# 合并边界
	var combined_rect = background_rect.merge(frontground_rect)
	var map_size = combined_rect.size
	var map_position = combined_rect.position

	print("Map bounds: ", combined_rect)
	print("Map size: ", map_size)
	print("Map position: ", map_position)

	# 创建Viewport用于渲染
	var viewport = SubViewport.new()
	viewport.size = map_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	# 复制Background图层到viewport
	var background_copy = TileMapLayer.new()
	background_copy.tile_set = background_layer.tile_set
	background_copy.tile_map_data = background_layer.tile_map_data
	background_copy.position = -map_position
	background_copy.z_index = background_layer.z_index
	background_copy.modulate = background_layer.modulate
	background_copy.visible = background_layer.visible
	viewport.add_child(background_copy)
	print("Background layer added, position: ", background_copy.position)

	# 复制Frontground图层到viewport
	var frontground_copy = TileMapLayer.new()
	frontground_copy.tile_set = frontground_layer.tile_set
	frontground_copy.tile_map_data = frontground_layer.tile_map_data
	frontground_copy.position = -map_position
	frontground_copy.z_index = frontground_layer.z_index
	frontground_copy.modulate = frontground_layer.modulate
	frontground_copy.visible = frontground_layer.visible
	viewport.add_child(frontground_copy)
	print("Frontground layer added, position: ", frontground_copy.position)

	# 等待渲染完成
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 获取合成的纹理
	var final_texture = viewport.get_texture()
	if final_texture:
		# 转换为Image
		var image = final_texture.get_image()
		if image:
			# Godot viewport纹理通常需要垂直翻转
			image.flip_y()

			# 如果图像还是反的，可以尝试以下选项之一：
			# image.flip_x()  # 水平翻转
			# image.flip_y()  # 取消上面的翻转
			# 或者两个都翻转：image.flip_x(); image.flip_y()

			# 保存到用户目录
			var user_dir = OS.get_user_data_dir()
			var output_path = user_dir + "/" + output_filename

			var result = image.save_png(output_path)
			if result == OK:
				print("Map rendered and saved successfully to: ", output_path)
			else:
				print("Failed to save image: ", result)
		else:
			print("Failed to get image from texture")
	else:
		print("Failed to get texture from viewport")

	# 清理
	map_instance.queue_free()
	viewport.queue_free()

func get_tilemap_bounds(tilemap_layer: TileMapLayer) -> Rect2:
	var used_rect = tilemap_layer.get_used_rect()
	var tile_size = Vector2(16, 16)  # 瓦片大小为16x16

	print("Layer: ", tilemap_layer.name)
	print("Used rect: ", used_rect)
	print("Tile size: ", tile_size)

	var bounds = Rect2(
		used_rect.position.x * tile_size.x,
		used_rect.position.y * tile_size.y,
		used_rect.size.x * tile_size.x,
		used_rect.size.y * tile_size.y
	)

	# 考虑TileMapLayer的位置偏移
	bounds.position += tilemap_layer.position

	print("Calculated bounds: ", bounds)
	return bounds
