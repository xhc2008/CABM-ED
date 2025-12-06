extends Node
class_name ExploreSceneChunkManager

## 探索场景区块流式加载管理器
## 负责管理地图的分块加载和卸载

var chunk_size_tiles: int = 64
var active_radius_chunks: int = 2

var bg_chunk_data := {}
var fg_chunk_data := {}
var loaded_chunks_bg := {}
var loaded_chunks_fg := {}
var last_player_chunk := Vector2i(2147483647, 2147483647)

var background_layer: TileMapLayer
var frontground_layer: TileMapLayer
var player: Node2D

func setup(bg_layer: TileMapLayer, fg_layer: TileMapLayer, player_node: Node2D):
	"""初始化区块管理器"""
	background_layer = bg_layer
	frontground_layer = fg_layer
	player = player_node
	
	if background_layer:
		bg_chunk_data = _build_chunk_data_for_layer(background_layer)
		var cells_bg = background_layer.get_used_cells()
		for pos in cells_bg:
			background_layer.erase_cell(pos)
	
	if frontground_layer:
		fg_chunk_data = _build_chunk_data_for_layer(frontground_layer)
		var cells_fg = frontground_layer.get_used_cells()
		for pos in cells_fg:
			frontground_layer.erase_cell(pos)
	
	last_player_chunk = Vector2i(2147483647, 2147483647)
	update_loaded_chunks()

func update_loaded_chunks():
	"""更新已加载的区块"""
	if not player:
		return
	
	var cur_chunk = _get_player_chunk()
	if cur_chunk == last_player_chunk:
		return
	
	last_player_chunk = cur_chunk
	var desired := {}
	
	for dx in range(-active_radius_chunks, active_radius_chunks + 1):
		for dy in range(-active_radius_chunks, active_radius_chunks + 1):
			var key = Vector2i(cur_chunk.x + dx, cur_chunk.y + dy)
			desired[key] = true
	
	# 更新背景层
	if background_layer:
		for key in desired.keys():
			if not loaded_chunks_bg.has(key) and bg_chunk_data.has(key):
				_load_chunk_into_layer(background_layer, bg_chunk_data, key)
				loaded_chunks_bg[key] = true
		
		for key in loaded_chunks_bg.keys():
			if not desired.has(key):
				_unload_chunk_from_layer(background_layer, bg_chunk_data, key)
				loaded_chunks_bg.erase(key)
	
	# 更新前景层
	if frontground_layer:
		for key in desired.keys():
			if not loaded_chunks_fg.has(key) and fg_chunk_data.has(key):
				_load_chunk_into_layer(frontground_layer, fg_chunk_data, key)
				loaded_chunks_fg[key] = true
		
		for key in loaded_chunks_fg.keys():
			if not desired.has(key):
				_unload_chunk_from_layer(frontground_layer, fg_chunk_data, key)
				loaded_chunks_fg.erase(key)

func _build_chunk_data_for_layer(layer: TileMapLayer) -> Dictionary:
	"""为图层构建区块数据"""
	var data := {}
	var cells = layer.get_used_cells()
	
	for pos in cells:
		var key = Vector2i(
			int(floor(pos.x / float(chunk_size_tiles))),
			int(floor(pos.y / float(chunk_size_tiles)))
		)
		
		if not data.has(key):
			data[key] = []
		
		var source_id = layer.get_cell_source_id(pos)
		var atlas_coords = layer.get_cell_atlas_coords(pos)
		var alt = layer.get_cell_alternative_tile(pos)
		
		data[key].append({
			"pos": pos,
			"source": source_id,
			"atlas": atlas_coords,
			"alt": alt
		})
	
	return data

func _get_player_chunk() -> Vector2i:
	"""获取玩家当前所在的区块"""
	var base_layer = background_layer if background_layer != null else frontground_layer
	if base_layer == null or player == null:
		return last_player_chunk
	
	var tile_pos = base_layer.local_to_map(base_layer.to_local(player.global_position))
	return Vector2i(
		int(floor(tile_pos.x / float(chunk_size_tiles))),
		int(floor(tile_pos.y / float(chunk_size_tiles)))
	)

func _load_chunk_into_layer(layer: TileMapLayer, chunk_data: Dictionary, key: Vector2i):
	"""加载区块到图层"""
	var arr = chunk_data.get(key, [])
	for item in arr:
		layer.set_cell(item.pos, item.source, item.atlas, item.alt)

func _unload_chunk_from_layer(layer: TileMapLayer, chunk_data: Dictionary, key: Vector2i):
	"""从图层卸载区块"""
	var arr = chunk_data.get(key, [])
	for item in arr:
		layer.erase_cell(item.pos)
