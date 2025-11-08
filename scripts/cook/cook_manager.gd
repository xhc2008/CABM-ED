extends RefCounted
class_name CookManager

# 烹饪管理器 - 管理烹饪相关的数据逻辑

# 食材状态枚举
enum IngredientState {
	RAW,        # 生
	MEDIUM,     # 半熟
	COOKED,     # 熟
	BURNT       # 焦糊
}

# 锅中的食材
class PanIngredient:
	var item_id: String
	var position: Vector2
	var rotation: float
	var state: IngredientState = IngredientState.RAW
	var cook_time: float = 0.0  # 烹饪时间
	
	func _init(p_item_id: String, p_position: Vector2, p_rotation: float):
		item_id = p_item_id
		position = p_position
		rotation = p_rotation

var pan_ingredients: Array[PanIngredient] = []
var heat_level: float = 0.5  # 火力等级 0.0-1.0
var items_config: Dictionary = {}

func _init(config: Dictionary):
	items_config = config

func add_ingredient_to_pan(item_id: String, pan_rect: Rect2):
	"""添加食材到锅中"""
	# 检查最大数量限制
	if pan_ingredients.size() >= 20:
		return
	
	# 随机位置和角度，偏左上角（锅柄在右下角）
	var rand_pos = Vector2(
		randf_range(pan_rect.position.x + 30, pan_rect.position.x + pan_rect.size.x * 0.7),  # 调整范围，更偏左
		randf_range(pan_rect.position.y + 30, pan_rect.position.y + pan_rect.size.y * 0.7)   # 调整范围，更偏上
	)
	var rand_rot = randf() * PI * 2
	
	var ingredient = PanIngredient.new(item_id, rand_pos, rand_rot)
	pan_ingredients.append(ingredient)

func update_cooking(delta: float):
	"""更新烹饪状态"""
	for ingredient in pan_ingredients:
		# 获取该食材的烹饪时间配置
		var item_config = items_config.get(ingredient.item_id, {})
		var total_cook_time = item_config.get("cook_time", 9.0)  # 默认9秒
		
		ingredient.cook_time += delta * heat_level
		
		# 根据烹饪时间占总时间的比例改变状态
		var progress = ingredient.cook_time / total_cook_time
		
		if progress < 0.33:  # 0-33%
			ingredient.state = IngredientState.RAW
		elif progress < 0.66:  # 33-66%
			ingredient.state = IngredientState.MEDIUM
		elif progress < 1.0:  # 66-100%
			ingredient.state = IngredientState.COOKED
		else:  # 超过100%
			ingredient.state = IngredientState.BURNT

func get_ingredient_color(ingredient: PanIngredient) -> Color:
	"""根据状态返回食材颜色"""
	match ingredient.state:
		IngredientState.RAW:
			return Color.WHITE  # 原始颜色
		IngredientState.MEDIUM:
			return Color(1.0, 0.8, 0.6)  # 淡黄色
		IngredientState.COOKED:
			return Color(0.8, 0.6, 0.4)  # 金黄色
		IngredientState.BURNT:
			return Color(0.3, 0.2, 0.1)  # 黑色
		_:
			return Color.WHITE

func clear_pan():
	"""清空锅"""
	pan_ingredients.clear()

func get_finished_ingredients() -> Array[PanIngredient]:
	"""获取出锅的食材列表"""
	return pan_ingredients.duplicate()

