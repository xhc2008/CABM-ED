extends Area2D
class_name DropItem

signal picked_up(drop_id: String)

var drop_id: String = ""
var item_id: String = ""
var count: int = 1
var items_config: Dictionary = {}

func setup(id: String, item: String, n: int, config: Dictionary):
	drop_id = id
	item_id = item
	count = int(n)
	items_config = config
	
	var shape = CircleShape2D.new()
	shape.radius = 24.0
	var collision = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	var sprite = Sprite2D.new()
	sprite.centered = true
	
	var item_config = items_config.get(item_id, {})
	var icon_path = "res://assets/images/items/" + item_config.get("icon", "")
	if ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	else:
		sprite.texture = load("res://assets/images/error.png")
	
	# 设置像素风格和固定高度
	if sprite.texture:
		# 设置纹理过滤为最近邻（像素风格）
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		# 固定目标高度，宽度按比例自动调整
		var target_height = 32.0  # 你可以调整这个值
		var tex_size = sprite.texture.get_size()
		
		# 计算缩放比例（保持宽高比）
		var scale_factor = target_height / tex_size.y
		
		sprite.scale = Vector2(scale_factor, scale_factor)
	
	add_child(sprite)
	z_index = 1

func get_interaction_data() -> Dictionary:
	var item_config = items_config.get(item_id, {})
	var name = item_config.get("name", item_id)
	var text = "F: " + name
	if count > 1:
		text += "*" + str(count)
	return {
		"text": text,
		"callback": func(): _pick_up(),
		"object": self,
		"type": "drop"
	}

func _pick_up():
	var scene = get_tree().current_scene
	if scene and scene.has_method("get_player_inventory"):
		var p_inv = scene.get_player_inventory()
		if p_inv and p_inv.add_item(item_id, count):
			picked_up.emit(drop_id)
			queue_free()