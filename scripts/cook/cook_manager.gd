extends RefCounted
class_name CookManager

# 烹饪管理器 - 管理烹饪相关的数据逻辑

# 食材状态枚举
# 食材状态枚举
enum IngredientState {
	RAW,        # 生
	LIGHT,      # 微熟
	MEDIUM,     # 半熟
	WELL_DONE,  # 全熟
	OVERCOOKED, # 过熟
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
		
		if progress < 0.2:        # 0-20%
			ingredient.state = IngredientState.RAW
		elif progress < 0.4:      # 20-40%
			ingredient.state = IngredientState.LIGHT
		elif progress < 0.6:      # 40-60%
			ingredient.state = IngredientState.MEDIUM
		elif progress < 0.8:      # 60-80%
			ingredient.state = IngredientState.WELL_DONE
		elif progress < 1.0:      # 80-100%
			ingredient.state = IngredientState.OVERCOOKED
		else:                     # 超过100%
			ingredient.state = IngredientState.BURNT

func get_ingredient_color(ingredient: PanIngredient) -> Color:
	"""根据状态返回食材颜色"""
	match ingredient.state:
		IngredientState.RAW:
			return Color.WHITE      # 原始颜色
		IngredientState.LIGHT:
			return Color(1.0, 0.9, 0.7)  # 很淡的黄色
		IngredientState.MEDIUM:
			return Color(1.0, 0.8, 0.6)  # 淡黄色
		IngredientState.WELL_DONE:
			return Color(0.9, 0.7, 0.5)  # 金黄色
		IngredientState.OVERCOOKED:
			return Color(0.6, 0.4, 0.3)  # 深棕色
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

func record_dish(ingredients: Array, p_items_config: Dictionary, dish_name: String = "谜之炖菜") -> Dictionary:
	"""记录菜品信息"""
	if ingredients.is_empty():
		return {}
	
	# 统计食材类型和数量
	var ingredient_counts = {}
	var cook_levels = []  # 记录所有食材的熟度
	
	for ingredient in ingredients:
		var item_id = ingredient.item_id
		var item_config = p_items_config.get(item_id, {})
		var item_name = item_config.get("name", item_id)
		
		# 统计食材数量
		if item_name in ingredient_counts:
			ingredient_counts[item_name] += 1
		else:
			ingredient_counts[item_name] = 1
		
		# 记录熟度
		cook_levels.append(ingredient.state)
	
	# 按数量排序，取前三个
	var sorted_ingredients = []
	for ingredient_name in ingredient_counts:
		sorted_ingredients.append({
			"name": ingredient_name,
			"count": ingredient_counts[ingredient_name]
		})
	
	# 按数量降序排序
	sorted_ingredients.sort_custom(func(a, b): return a["count"] > b["count"])
	
	# 构建食材描述（只取前三个，不记录数量）
	var top_ingredients = []
	for i in range(min(3, sorted_ingredients.size())):
		top_ingredients.append(sorted_ingredients[i]["name"])
	
	var ingredients_desc = "、".join(top_ingredients)
	
	# 如果食材超过三种，加上"等"
	if sorted_ingredients.size() > 3:
		ingredients_desc += "等"
	
	# 分析整体熟度
	var overall_cook_state = analyze_overall_cook_state(cook_levels)
	
	# 记录菜品
	var dish = {
		"dish_name": dish_name,
		"ingredients": ingredients_desc,
		"cook_state": overall_cook_state,
		"raw_count": cook_levels.count(IngredientState.RAW),
		"light_count": cook_levels.count(IngredientState.LIGHT),
		"medium_count": cook_levels.count(IngredientState.MEDIUM),
		"well_done_count": cook_levels.count(IngredientState.WELL_DONE),
		"overcooked_count": cook_levels.count(IngredientState.OVERCOOKED),
		"burnt_count": cook_levels.count(IngredientState.BURNT),
		"total_ingredients": sorted_ingredients.size()  # 记录总食材种类数
	}
	
	return dish
	
func analyze_overall_cook_state(cook_levels: Array) -> String:
	"""分析整体熟度状态"""
	var raw_count = cook_levels.count(IngredientState.RAW)
	var light_count = cook_levels.count(IngredientState.LIGHT)
	var medium_count = cook_levels.count(IngredientState.MEDIUM)
	var well_done_count = cook_levels.count(IngredientState.WELL_DONE)
	var overcooked_count = cook_levels.count(IngredientState.OVERCOOKED)
	var burnt_count = cook_levels.count(IngredientState.BURNT)
	
	var total = cook_levels.size()
	
	# 特殊情况：混合状态
	if raw_count > 0 and burnt_count > 0:
		return "有的没熟有的焦了"
	elif raw_count > 0 and (well_done_count > 0 or medium_count > 0 or light_count > 0):
		return "有的熟了有的没熟"
	elif burnt_count > 0 and (well_done_count > 0 or medium_count > 0 or light_count > 0):
		return "有的熟了有的焦了"
	elif raw_count > 0 and overcooked_count > 0:
		return "有的没熟有的过熟了"
	
	# 单一或主导状态
	elif burnt_count == total:
		return "完全烧焦了"
	elif burnt_count > total * 0.5:
		return "大部分烧焦了"
	elif overcooked_count == total:
		return "熟过头了"
	elif overcooked_count > total * 0.5:
		return "有点过了"
	elif well_done_count == total:
		return "完美全熟"
	elif well_done_count > total * 0.7:
		return "基本全熟"
	elif medium_count == total:
		return "适中熟度"
	elif medium_count > total * 0.6:
		return "基本熟了"
	elif light_count == total:
		return "没完全熟"
	elif light_count > total * 0.6:
		return "还有点生"
	elif raw_count == total:
		return "完全没熟"
	elif raw_count > total * 0.5:
		return "大部分没熟"
	else:
		return "应该能吃……？"
		
func build_cook_memory_content(cooked_dishes: Array, user_name: String, character_scene: String) -> String:
	"""构建烹饪记忆内容
	
	参数：
	- cooked_dishes: 菜品列表
	- user_name: 用户名
	- character_scene: 角色所在场景
	
	返回：记忆内容字符串
	"""
	if cooked_dishes.size() == 0:
		return ""
	
	# 判断角色是否在厨房
	var is_in_kitchen = (character_scene == "kitchen")
	
	# 构建记忆内容
	var subject_prefix = ""
	if is_in_kitchen:
		subject_prefix = "%s和我一起" % user_name
	else:
		subject_prefix = "%s" % user_name
	
	var memory_content = "%s做了%d道菜：" % [subject_prefix, cooked_dishes.size()]
	var dish_descriptions = []
	
	# 如果菜品超过3个，随机选择3个详细记录
	var dishes_to_record = cooked_dishes
	if cooked_dishes.size() > 3:
		dishes_to_record = []
		var shuffled_dishes = cooked_dishes.duplicate()
		shuffled_dishes.shuffle()
		for i in range(3):
			dishes_to_record.append(shuffled_dishes[i])
	
	# 构建菜品描述
	for dish in dishes_to_record:
		var desc = dish.dish_name
		var details = []
		
		if dish.has("ingredients"):
			details.append("用了" + dish.ingredients)
		
		if details.size() > 0:
			desc += "（" + "，".join(details) + "）"

		# 使用熟度描述
		if dish.has("cook_state"):
			desc += "，" + dish.cook_state
		dish_descriptions.append(desc)
	
	memory_content += "；".join(dish_descriptions)
	
	# 如果菜品超过3个，添加省略号
	if cooked_dishes.size() > 3:
		memory_content += "……"
	
	return memory_content