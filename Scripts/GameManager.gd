class_name GameManager
extends Node

# 游戏核心管理器
signal card_drawn(card_data)
signal recipe_generated(recipe_data)
signal meal_sold(meal_data, price)

var card_pools: Dictionary = {}
var player_cards: Array[Dictionary] = []
var player_recipes: Array[Dictionary] = []
var player_currency: int = 100
var current_trends: Array[String] = []

# 玩家信息与成长
var player_name: String = "新玩家"
var player_avatar_path: String = ""
var player_level: int = 1
var player_exp: int = 0
var player_exp_to_next: int = 100
var daily_free_draws: int = 3

# Tripo API 配置
var tripo_api_key: String = ""
var tripo_base_url: String = "https://api.tripo3d.ai/v2/openapi"

func _ready():
	load_card_pools()
	initialize_trends()
	print("游戏管理器初始化完成")

func load_card_pools():
	"""加载卡池数据"""
	var file = FileAccess.open("res://Data/pools.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			card_pools = json.data
			print("卡池数据加载成功，共", card_pools.size(), "个卡池")
		else:
			print("卡池数据解析失败")
	else:
		print("无法打开卡池数据文件")

func initialize_trends():
	"""初始化当前潮流"""
	var trend_options = ["奇异风暴", "甜蜜时光", "火辣挑战", "未来科技", "经典回归"]
	current_trends = [trend_options[randi() % trend_options.size()]]
	# 潮流持续30分钟
	trend_end_time = Time.get_unix_time_from_system() + 30 * 60
	print("当前潮流：", current_trends[0])

# 潮流倒计时（Unix 时间戳，秒）
var trend_end_time: int = 0

func get_trend_remaining_seconds() -> int:
	"""获取当前潮流剩余秒数，<=0 表示需要刷新"""
	return trend_end_time - Time.get_unix_time_from_system()

func maybe_rotate_trend():
	"""若潮流结束则切换到新潮流并重置倒计时"""
	if get_trend_remaining_seconds() <= 0:
		initialize_trends()

func get_pool_names() -> Array[String]:
	"""获取所有卡池名称"""
	var names: Array[String] = []
	for pool_name in card_pools.keys():
		names.append(pool_name)
	return names

func draw_card_from_pool(pool_name: String) -> Dictionary:
	"""从指定卡池抽卡"""
	if not card_pools.has(pool_name):
		print("卡池不存在：", pool_name)
		return {}
	
	var pool_cards = card_pools[pool_name]
	if pool_cards.is_empty():
		print("卡池为空：", pool_name)
		return {}
	
	var drawn_card = pool_cards[randi() % pool_cards.size()].duplicate()
	drawn_card["pool"] = pool_name
	drawn_card["id"] = generate_card_id()
	
	player_cards.append(drawn_card)
	card_drawn.emit(drawn_card)

	# 抽卡获得少量经验
	_gain_exp(5)
	
	print("抽到卡片：", drawn_card.name, " 来自卡池：", pool_name)
	return drawn_card

func generate_card_id() -> String:
	"""生成唯一卡片ID"""
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _gain_exp(amount: int) -> void:
	player_exp += amount
	while player_exp >= player_exp_to_next:
		player_exp -= player_exp_to_next
		player_level += 1
		player_exp_to_next = int(player_exp_to_next * 1.2)

func calculate_recipe_attributes(selected_cards: Array[Dictionary]) -> Dictionary:
	"""计算料理属性"""
	var total_spice = 0
	var total_sweet = 0
	var total_weird = 0
	var base_price = 0
	
	for card in selected_cards:
		total_spice += card.get("spice", 0)
		total_sweet += card.get("sweet", 0)
		total_weird += card.get("weird", 0)
		base_price += card.get("base_price", 0)
	
	# 添加随机波动
	var spice_variation = randi_range(-1, 1)
	var sweet_variation = randi_range(-1, 1)
	var weird_variation = randi_range(-1, 1)
	
	return {
		"spice": max(0, total_spice + spice_variation),
		"sweet": max(0, total_sweet + sweet_variation),
		"weird": max(0, total_weird + weird_variation),
		"base_price": base_price,
		"trend_bonus": calculate_trend_bonus(total_spice, total_sweet, total_weird)
	}

func calculate_trend_bonus(spice: int, sweet: int, weird: int) -> float:
	"""计算潮流加成"""
	var bonus = 1.0
	var current_trend = current_trends[0] if not current_trends.is_empty() else ""
	
	match current_trend:
		"奇异风暴":
			if weird >= 8:
				bonus = 1.5
		"甜蜜时光":
			if sweet >= 4:
				bonus = 1.3
		"火辣挑战":
			if spice >= 4:
				bonus = 1.4
		"未来科技":
			if weird >= 6 and spice >= 2:
				bonus = 1.3
		"经典回归":
			if spice <= 2 and sweet <= 2 and weird <= 3:
				bonus = 1.2
	
	return bonus

func generate_prompt_from_cards(selected_cards: Array[Dictionary], style_modifiers: Array[String] = []) -> String:
	"""
	参考 Tripo 官方示例，生成简洁有效的 3D 菜肴 Prompt
	"""
	var ingredients: Array[String] = []
	for card in selected_cards:
		ingredients.append(str(card.name))

	var attributes: Dictionary = calculate_recipe_attributes(selected_cards)
	
	# 构建简洁的主体描述
	var dish_name = "dish with " + ", ".join(ingredients) if ingredients.size() > 0 else "creative dish"
	var base_prompt = "Create a 3D model of a " + dish_name
	
	# 根据属性添加关键特征
	var features: Array[String] = []
	
	if attributes.sweet >= 4:
		features.append("glossy candy-like surface")
		features.append("pastel colors")
	elif attributes.spice >= 4:
		features.append("fiery red accents")
		features.append("steam effects")
	
	if attributes.weird >= 8:
		features.append("whimsical fantasy elements")
		features.append("floating components")
	else:
		features.append("appetizing presentation")
	
	# 添加基础视觉要求
	features.append("vibrant colors")
	features.append("smooth textures")
	features.append("studio lighting")
	
	if features.size() > 0:
		base_prompt += " with " + ", ".join(features)
	
	return base_prompt
