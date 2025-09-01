class_name OddBitesGameManager
extends Node

# 游戏核心管理器
signal card_drawn(card_data)
signal recipe_generated(recipe_data)
signal meal_sold(meal_data, price)
signal avatar_updated(texture: Texture2D)

var card_pools: Dictionary = {}
var player_cards: Array[Dictionary] = []
var player_recipes: Array[Dictionary] = []
var player_currency: int = 100
var current_trends: Array[String] = []

# 卡片稀有度系统
var player_card_inventory: Dictionary = {} # key: card_name, value: {count: int, rarity: String}
const RARITY_LEVELS = ["N", "R", "SR", "SSR"]
const RARITY_THRESHOLDS = [1, 3, 8, 20]  # 达到这些数量时升级稀有度
const RARITY_COST_MULTIPLIERS = [1.0, 1.5, 2.5, 4.0]  # 稀有度成本倍率
const PROCESSING_FEE_PER_CARD = 3  # 每张卡片的基础加工费

# 页面/UI 状态（用于存档恢复）
var ui_serve_selected_names: Array[String] = []
var ui_serve_price_text: String = ""
var ui_serve_price_user_dirty: bool = false
var ui_serve_last_suggest: int = 0
var ui_selected_pool: String = ""
var ui_selected_cards_ids: Array[String] = []
var ui_last_preview_task_id: String = ""
var ui_broadcast_lines: Array[String] = []

# 售卖历史
var sales_history: Array[Dictionary] = []

# 在线套餐系统
var online_meals: Array[Dictionary] = []
const MAX_ONLINE_MEALS = 3

# 售卖延迟系统
var selling_timers: Array[Dictionary] = []

# 玩家信息与成长
var player_name: String = "新玩家"
var player_avatar_path: String = ""
var player_avatar_seed: String = ""
var player_level: int = 1
var player_exp: int = 0
var player_exp_to_next: int = 100
var daily_free_draws: int = 3

# 音乐设置
var music_player: AudioStreamPlayer
var music_volume: float = 0.1
var music_enabled: bool = true

# Tripo API 配置
var tripo_api_key: String = ""
var tripo_base_url: String = "https://api.tripo3d.ai/v2/openapi"

func _ready():
	load_card_pools()
	initialize_trends()
	_initialize_player_avatar()
	# 启动尝试读取存档
	load_game_data()
	
	# 检查并导入预设料理
	_import_preset_recipes()
	
	# 初始化音乐播放器（但不自动播放，只在标题页播放）
	_setup_music_player()
	
	# 启动售卖定时器处理
	var timer = Timer.new()
	timer.name = "SellingTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(_process_selling_timers)
	timer.autostart = true
	add_child(timer)
	
	print("游戏管理器初始化完成，音乐播放器已准备，售卖定时器已启动")

func _initialize_player_avatar():
	"""初始化玩家头像种子"""
	if player_avatar_seed.is_empty():
		# 使用玩家名称生成稳定的头像种子
		player_avatar_seed = player_name

func regenerate_avatar():
	"""重新生成头像（随机种子）"""
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	player_avatar_seed = ""
	for i in range(12):
		player_avatar_seed += chars[randi() % chars.length()]

func regenerate_food_avatar():
	"""重新生成食物主题头像"""
	regenerate_avatar()

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
	
	# 处理重复卡片和稀有度
	var card_name = str(drawn_card.name)
	if not player_card_inventory.has(card_name):
		player_card_inventory[card_name] = {"count": 0, "rarity": "N"}
	
	var inventory_item = player_card_inventory[card_name]
	inventory_item.count += 1
	
	# 检查稀有度升级
	var new_rarity_level = _calculate_rarity_level(inventory_item.count)
	var old_rarity = inventory_item.rarity
	inventory_item.rarity = RARITY_LEVELS[new_rarity_level]
	
	# 如果已经达到SSR且继续获得，转换为金币
	if inventory_item.count > RARITY_THRESHOLDS[3] and inventory_item.rarity == "SSR":
		var bonus_gold = int(drawn_card.base_price * RARITY_COST_MULTIPLIERS[3] * 0.5)
		player_currency += bonus_gold
		print("SSR卡片", card_name, "已满级，获得", bonus_gold, "金币")
		card_drawn.emit({"name": card_name, "rarity": "SSR", "bonus_gold": bonus_gold, "is_duplicate": true})
	else:
		# 更新卡片稀有度信息
		drawn_card["rarity"] = inventory_item.rarity
		drawn_card["count"] = inventory_item.count
		drawn_card["is_upgrade"] = old_rarity != inventory_item.rarity
		
		player_cards.append(drawn_card)
		card_drawn.emit(drawn_card)
		
		if drawn_card.is_upgrade:
			print("卡片升级！", card_name, " ", old_rarity, " -> ", inventory_item.rarity)

	# 抽卡获得少量经验
	_gain_exp(5)
	
	print("抽到卡片：", drawn_card.name, " 来自卡池：", pool_name, " 稀有度：", inventory_item.rarity, " 数量：", inventory_item.count)
	# 自动存档
	auto_save()
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

func _calculate_rarity_level(count: int) -> int:
	"""根据数量计算稀有度等级"""
	for i in range(RARITY_THRESHOLDS.size() - 1, -1, -1):
		if count >= RARITY_THRESHOLDS[i]:
			return i
	return 0

func get_card_effective_price(card_name: String, base_price: int) -> int:
	"""获取卡片的有效价格（包含稀有度加成）"""
	if not player_card_inventory.has(card_name):
		return base_price
	
	var inventory_item = player_card_inventory[card_name]
	var rarity_level = RARITY_LEVELS.find(inventory_item.rarity)
	if rarity_level == -1:
		rarity_level = 0
	
	return int(base_price * RARITY_COST_MULTIPLIERS[rarity_level])

func get_card_rarity(card_name: String) -> String:
	"""获取卡片当前稀有度"""
	if not player_card_inventory.has(card_name):
		return "N"
	return player_card_inventory[card_name].rarity

func _to_dict_array(a) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(a) == TYPE_ARRAY:
		for v in a:
			if typeof(v) == TYPE_DICTIONARY:
				out.append(v)
	return out

func _to_string_array(a) -> Array[String]:
	var out: Array[String] = []
	if typeof(a) == TYPE_ARRAY:
		for v in a:
			out.append(str(v))
	return out

func calculate_recipe_attributes(selected_cards: Array[Dictionary]) -> Dictionary:
	"""计算料理属性"""
	var total_spice = 0
	var total_sweet = 0
	var total_weird = 0
	var total_cost = 0
	
	for card in selected_cards:
		total_spice += card.get("spice", 0)
		total_sweet += card.get("sweet", 0)
		total_weird += card.get("weird", 0)
		
		# 计算考虑稀有度的有效成本
		var card_name = str(card.get("name", ""))
		var base_price = int(card.get("base_price", 0))
		var effective_price = get_card_effective_price(card_name, base_price)
		total_cost += effective_price
	
	# 添加加工费（每张卡片基础费用）
	var processing_fee = selected_cards.size() * PROCESSING_FEE_PER_CARD
	total_cost += processing_fee
	
	# 添加随机波动
	var spice_variation = randi_range(-1, 1)
	var sweet_variation = randi_range(-1, 1)
	var weird_variation = randi_range(-1, 1)
	
	var final_spice = max(0, total_spice + spice_variation)
	var final_sweet = max(0, total_sweet + sweet_variation)
	var final_weird = max(0, total_weird + weird_variation)
	
	return {
		"spice": final_spice,
		"sweet": final_sweet,
		"weird": final_weird,
		"base_price": total_cost,
		"processing_fee": processing_fee,
		"card_count": selected_cards.size(),
		"trend_bonus": calculate_trend_bonus(final_spice, final_sweet, final_weird)
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

func get_trend_baseline_desc() -> String:
	"""获取当前潮流的基线条件描述"""
	var current_trend = current_trends[0] if not current_trends.is_empty() else ""
	match current_trend:
		"奇异风暴":
			return "奇异度≥8"
		"甜蜜时光":
			return "甜度≥4"
		"火辣挑战":
			return "辣度≥4"
		"未来科技":
			return "奇异≥6且辣≥2"
		"经典回归":
			return "三项较低(辣≤2,甜≤2,奇≤3)"
		_:
			return "无"

func get_trend_bonus_desc() -> String:
	"""获取当前潮流的加成描述"""
	var current_trend = current_trends[0] if not current_trends.is_empty() else ""
	match current_trend:
		"奇异风暴":
			return "×1.5"
		"甜蜜时光":
			return "×1.3"
		"火辣挑战":
			return "×1.4"
		"未来科技":
			return "×1.3"
		"经典回归":
			return "×1.2"
		_:
			return "×1.0"

func get_detailed_trend_info() -> String:
	"""获取详细的潮流信息，包括基线、加成和剩余时间"""
	var current_trend = current_trends[0] if not current_trends.is_empty() else "无"
	var baseline = get_trend_baseline_desc()
	var bonus = get_trend_bonus_desc()
	var remain = max(0, get_trend_remaining_seconds())
	var m = int(remain / 60)
	var s = remain % 60
	return "%s(基线:%s 加成:%s 剩余:%02d:%02d)" % [current_trend, baseline, bonus, m, s]

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

# ============ 简单存档系统 (user://save.json) ============
const SAVE_PATH := "user://save.json"

func save_game_data():
	var save_data = {
		"version": "1.2",
		"player_name": player_name,
		"player_avatar_seed": player_avatar_seed,
		"player_level": player_level,
		"player_exp": player_exp,
		"player_exp_to_next": player_exp_to_next,
		"player_currency": player_currency,
		"daily_free_draws": daily_free_draws,
		"player_cards": player_cards,
		"player_recipes": player_recipes,
		"player_card_inventory": player_card_inventory,
		"current_trends": current_trends,
		"trend_end_time": trend_end_time,
		"save_timestamp": Time.get_unix_time_from_system(),
		# 音乐设置
		"music_volume": music_volume,
		"music_enabled": music_enabled,
		# UI 状态
		"ui_serve_selected_names": ui_serve_selected_names,
		"ui_serve_price_text": ui_serve_price_text,
		"ui_serve_price_user_dirty": ui_serve_price_user_dirty,
		"ui_serve_last_suggest": ui_serve_last_suggest,
		"ui_selected_pool": ui_selected_pool,
		"ui_selected_cards_ids": ui_selected_cards_ids,
		"ui_last_preview_task_id": ui_last_preview_task_id,
		"ui_broadcast_lines": ui_broadcast_lines,
		# 在线套餐
		"online_meals": online_meals,
		# 售卖历史
		"sales_history": sales_history
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))
		f.close()
		print("存档已保存: ", SAVE_PATH)

func load_game_data():
	if not FileAccess.file_exists(SAVE_PATH):
		print("没有找到存档，使用默认数据: ", SAVE_PATH)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		print("无法打开存档: ", SAVE_PATH)
		return
	var json_string := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		print("存档解析失败: ", SAVE_PATH)
		return
	var save_data: Dictionary = json.data
	player_name = save_data.get("player_name", player_name)
	player_avatar_seed = save_data.get("player_avatar_seed", player_avatar_seed)
	player_level = save_data.get("player_level", player_level)
	player_exp = save_data.get("player_exp", player_exp)
	player_exp_to_next = save_data.get("player_exp_to_next", player_exp_to_next)
	player_currency = save_data.get("player_currency", player_currency)
	daily_free_draws = save_data.get("daily_free_draws", daily_free_draws)
	player_cards = _to_dict_array(save_data.get("player_cards", []))
	player_recipes = _to_dict_array(save_data.get("player_recipes", []))
	player_card_inventory = save_data.get("player_card_inventory", {})
	current_trends = _to_string_array(save_data.get("current_trends", current_trends))
	trend_end_time = save_data.get("trend_end_time", trend_end_time)
	# 音乐设置
	music_volume = save_data.get("music_volume", music_volume)
	music_enabled = save_data.get("music_enabled", music_enabled)
	# UI 状态
	ui_serve_selected_names = _to_string_array(save_data.get("ui_serve_selected_names", []))
	ui_serve_price_text = save_data.get("ui_serve_price_text", "")
	ui_serve_price_user_dirty = save_data.get("ui_serve_price_user_dirty", false)
	ui_serve_last_suggest = save_data.get("ui_serve_last_suggest", 0)
	ui_selected_pool = save_data.get("ui_selected_pool", "")
	ui_selected_cards_ids = _to_string_array(save_data.get("ui_selected_cards_ids", []))
	ui_last_preview_task_id = save_data.get("ui_last_preview_task_id", "")
	ui_broadcast_lines = _to_string_array(save_data.get("ui_broadcast_lines", []))
	# 在线套餐
	online_meals = _to_dict_array(save_data.get("online_meals", []))
	# 售卖历史
	sales_history = _to_dict_array(save_data.get("sales_history", []))
	if get_trend_remaining_seconds() <= 0:
		initialize_trends()
	print("存档加载完成: ", SAVE_PATH)
	print("加载了", online_meals.size(), "个在线套餐")

func add_meal_to_online(meal_data: Dictionary) -> bool:
	"""将套餐添加到在线售卖列表"""
	if online_meals.size() >= MAX_ONLINE_MEALS:
		return false
	
	# 生成唯一ID
	meal_data["online_id"] = generate_card_id()
	meal_data["online_time"] = Time.get_unix_time_from_system()
	online_meals.append(meal_data)
	
	# 计算售卖延迟并启动定时器
	_start_selling_timer(meal_data)
	return true

func remove_meal_from_online(online_id: String) -> bool:
	"""从在线售卖列表移除套餐"""
	for i in range(online_meals.size()):
		if str(online_meals[i].get("online_id", "")) == online_id:
			online_meals.remove_at(i)
			# 移除对应的定时器
			_remove_selling_timer(online_id)
			return true
	return false

func _start_selling_timer(meal_data: Dictionary) -> void:
	"""启动售卖延迟定时器"""
	var base_delay = 5.0  # 测试用：改为5秒，更快看到效果
	var suggest_price = float(meal_data.get("suggest_price", 100))
	var asked_price = float(meal_data.get("asked_price", 100))
	
	# 定价倍率：过高降低延迟，过低增加延迟
	var price_factor = 1.0
	if asked_price > suggest_price * 1.2:
		price_factor = 0.6  # 高价快速售出但收入低
	elif asked_price < suggest_price * 0.8:
		price_factor = 1.5  # 低价慢速售出
	
	# 随机扰动 0.7~1.3
	var random_factor = randf_range(0.7, 1.3)
	
	var final_delay = base_delay * price_factor * random_factor
	
	# 创建定时器数据
	var timer_data = {
		"online_id": meal_data.get("online_id"),
		"end_time": Time.get_unix_time_from_system() + final_delay,
		"meal_data": meal_data
	}
	selling_timers.append(timer_data)
	print("套餐", meal_data.get("names", []), "将在", int(final_delay), "秒后售出")
	print("定时器数据:", timer_data)
	print("当前定时器总数:", selling_timers.size())
	print("当前时间:", Time.get_unix_time_from_system(), "，结束时间:", timer_data.get("end_time"))

func _remove_selling_timer(online_id: String) -> void:
	"""移除指定的售卖定时器"""
	for i in range(selling_timers.size() - 1, -1, -1):
		if str(selling_timers[i].get("online_id", "")) == online_id:
			selling_timers.remove_at(i)

func _process_selling_timers() -> void:
	"""处理售卖定时器，完成自动售卖"""
	var current_time = Time.get_unix_time_from_system()
	print("检查售卖定时器，当前时间:", current_time, "，定时器数量:", selling_timers.size())
	
	for i in range(selling_timers.size() - 1, -1, -1):
		var timer = selling_timers[i]
		var end_time = timer.get("end_time", 0)
		print("定时器", i, "结束时间:", end_time, "，剩余:", end_time - current_time, "秒")
		
		if current_time >= end_time:
			# 时间到，执行售卖
			var meal_data = timer.get("meal_data", {})
			print("执行自动售卖:", meal_data.get("names", []))
			_complete_automatic_sale(meal_data)
			# 移除定时器和在线套餐
			selling_timers.remove_at(i)
			remove_meal_from_online(str(meal_data.get("online_id", "")))
			print("售卖完成，剩余定时器:", selling_timers.size())
			break  # 一次只处理一个，避免索引问题

func _complete_automatic_sale(meal_data: Dictionary) -> void:
	"""完成自动售卖"""
	var final_income = int(meal_data.get("final_income", 0))
	player_currency += final_income
	
	print("自动售卖完成！套餐:", meal_data.get("names", []), "收入:", final_income, "，当前余额:", player_currency)
	
	# 记录到售卖历史
	var sale = {
		"timestamp": Time.get_unix_time_from_system(),
		"names": meal_data.get("names", []),
		"total_spice": meal_data.get("total_spice", 0),
		"total_sweet": meal_data.get("total_sweet", 0),
		"total_weird": meal_data.get("total_weird", 0),
		"total_cost": meal_data.get("total_cost", 0),
		"trend_bonus": meal_data.get("trend_bonus", 0),
		"suggest_price": meal_data.get("suggest_price", 0),
		"asked_price": meal_data.get("asked_price", 0),
		"final_income": final_income
	}
	
	if sales_history == null:
		sales_history = []
	sales_history.append(sale)
	
	# 发出售卖信号
	print("准备发出meal_sold信号...")
	print("信号连接数:", meal_sold.get_connections().size())
	print("信号数据:", meal_data)
	print("收入:", final_income)
	
	meal_sold.emit(meal_data, final_income)
	
	print("meal_sold信号已发出！")
	print("自动售出：", meal_data.get("names", []), "获得", final_income, "金币")
	auto_save()
	
	# 强制保存，确保数据不丢失
	save_game_data()

func auto_save():
	save_game_data()

# 音乐相关方法
func _setup_music_player():
	"""初始化音乐播放器"""
	print("开始初始化音乐播放器...")
	
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	# 设置为自动暂停模式，这样场景切换时音乐不会停止
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	
	# 加载音乐文件
	print("尝试加载音乐文件: res://Assets/Music/simple_cook.mp3")
	var music_stream = load("res://Assets/Music/simple_cook.mp3")
	if music_stream:
		print("音乐文件加载成功！")
		music_player.stream = music_stream
		music_player.volume_db = linear_to_db(music_volume)
		print("设置音量: ", music_volume, " -> ", music_player.volume_db, " dB")
		
		# 设置循环播放
		music_player.finished.connect(func(): 
			print("音乐播放完成，重新开始播放")
			music_player.play()
		)
		
		# 不自动播放，等待手动调用
		print("音乐播放器已准备就绪，等待手动播放")
		
		print("音乐播放器初始化完成")
	else:
		print("音乐文件加载失败！请检查路径: res://Assets/Music/simple_cook.mp3")

func _start_music_playback():
	"""开始播放音乐（延迟一帧确保播放器完全初始化）"""
	if music_player and music_enabled:
		music_player.play()
		print("音乐开始播放！状态: ", music_player.playing)
		print("音乐播放器名称: ", music_player.name)
		print("音乐播放器父节点: ", music_player.get_parent().name if music_player.get_parent() else "无父节点")

func set_music_volume(volume: float):
	"""设置音乐音量"""
	print("设置音乐音量: ", volume)
	music_volume = volume
	if music_player:
		music_player.volume_db = linear_to_db(volume)
		print("音乐播放器音量已更新: ", music_player.volume_db, " dB")
	else:
		print("警告：音乐播放器不存在！")
	save_game_data()

func set_music_enabled(enabled: bool):
	"""设置音乐开关"""
	print("设置音乐开关: ", enabled)
	music_enabled = enabled
	if music_player:
		if enabled:
			print("开始播放音乐...")
			music_player.play()
			print("音乐播放状态: ", music_player.playing)
		else:
			print("停止播放音乐...")
			music_player.stop()
	else:
		print("警告：音乐播放器不存在！")
	save_game_data()

func get_music_volume() -> float:
	"""获取音乐音量"""
	return music_volume

func get_music_enabled() -> bool:
	"""获取音乐开关状态"""
	return music_enabled

func play_title_music():
	"""播放标题页音乐（只在标题页调用）"""
	if music_player and music_enabled and not music_player.playing:
		music_player.play()
		print("标题页音乐开始播放")

# 预设料理导入功能
func _import_preset_recipes() -> void:
	"""导入预设料理到用户目录"""
	print("检查预设料理导入...")
	
	# 确保用户recipes目录存在
	var user_dir = DirAccess.open("user://")
	if not user_dir:
		print("无法访问用户目录")
		return
	
	if not user_dir.dir_exists("recipes"):
		user_dir.make_dir("recipes")
		print("创建用户recipes目录")
	
	# 预设料理列表（从Data目录的文件名推断）
	var preset_recipes = [
		"香橙片 , 奶油",
		"透明蘑菇 , 发光果冻", 
		"蜜糖 , 马卡龙外壳 , 巧克力酱 , 草莓酱 , 杏仁酱",
		"蜜糖 , 西兰花 , 胡椒粉 , 洋葱丁",
		"巧克力酱球 , 奶酪球 , 抹茶粉",
		"蒜末 , 漂浮坚果 , 面包片 , 洋葱丁",
		"抹茶粉 , 焦糖液 , 布丁液"
	]
	
	var imported_count = 0
	for recipe_name in preset_recipes:
		if _import_single_preset_recipe(recipe_name):
			imported_count += 1
	
	print("预设料理导入完成，共导入", imported_count, "个料理")

func _import_single_preset_recipe(recipe_name: String) -> bool:
	"""导入单个预设料理"""
	# 检查是否已经导入过
	var user_glb_path = "user://recipes/" + recipe_name + ".glb"
	var user_png_path = "user://recipes/" + recipe_name + ".png"
	
	if FileAccess.file_exists(user_glb_path) and FileAccess.file_exists(user_png_path):
		print("料理已存在，跳过: ", recipe_name)
		return false
	
	# 源文件路径
	var source_glb = "res://Data/" + recipe_name + ".glb"
	var source_png = "res://Data/" + recipe_name + ".png"
	
	# 检查源文件是否存在
	if not FileAccess.file_exists(source_glb) or not FileAccess.file_exists(source_png):
		print("源文件不存在，跳过: ", recipe_name)
		return false
	
	# 复制文件
	var success = true
	
	# 复制GLB文件
	var glb_file = FileAccess.open(source_glb, FileAccess.READ)
	if glb_file:
		var glb_data = glb_file.get_buffer(glb_file.get_length())
		glb_file.close()
		
		var user_glb = FileAccess.open(user_glb_path, FileAccess.WRITE)
		if user_glb:
			user_glb.store_buffer(glb_data)
			user_glb.close()
			print("复制GLB文件: ", recipe_name)
		else:
			print("无法写入GLB文件: ", user_glb_path)
			success = false
	else:
		print("无法读取源GLB文件: ", source_glb)
		success = false
	
	# 复制PNG文件
	var png_file = FileAccess.open(source_png, FileAccess.READ)
	if png_file:
		var png_data = png_file.get_buffer(png_file.get_length())
		png_file.close()
		
		var user_png = FileAccess.open(user_png_path, FileAccess.WRITE)
		if user_png:
			user_png.store_buffer(png_data)
			user_png.close()
			print("复制PNG文件: ", recipe_name)
		else:
			print("无法写入PNG文件: ", user_png_path)
			success = false
	else:
		print("无法读取源PNG文件: ", source_png)
		success = false
	
	# 如果复制成功，添加到玩家料理列表
	if success:
		_add_preset_recipe_to_player_data(recipe_name)
		print("成功导入预设料理: ", recipe_name)
		return true
	
	return false

func _add_preset_recipe_to_player_data(recipe_name: String) -> void:
	"""将预设料理添加到玩家数据中"""
	# 检查是否已经存在
	for recipe in player_recipes:
		if recipe.get("name", "") == recipe_name:
			print("料理已存在于玩家数据中: ", recipe_name)
			return
	
	# 创建预设料理数据
	var recipe_data = {
		"name": recipe_name,
		"task_id": "preset_" + str(recipe_name.hash()),
		"glb_path": "user://recipes/" + recipe_name + ".glb",
		"png_path": "user://recipes/" + recipe_name + ".png",
		"attributes": _generate_preset_attributes(recipe_name),
		"suggested_price": 0,  # 预设料理不计算价格
		"is_preset": true,
		"created_time": Time.get_unix_time_from_system()
	}
	
	player_recipes.append(recipe_data)
	print("添加预设料理到玩家数据: ", recipe_name)
	
	# 保存游戏数据
	save_game_data()

func _generate_preset_attributes(recipe_name: String) -> Dictionary:
	"""为预设料理生成属性"""
	# 根据料理名称生成合理的属性
	var attributes = {
		"spice": 0,
		"sweet": 0,
		"weird": 0
	}
	
	# 根据料理名称关键词设置属性
	if "辣" in recipe_name or "辣椒" in recipe_name or "胡椒粉" in recipe_name:
		attributes.spice = randi() % 3 + 3  # 3-5
	
	if "甜" in recipe_name or "蜜糖" in recipe_name or "巧克力" in recipe_name or "奶油" in recipe_name or "马卡龙" in recipe_name or "草莓" in recipe_name:
		attributes.sweet = randi() % 3 + 3  # 3-5
	
	if "透明" in recipe_name or "发光" in recipe_name or "蘑菇" in recipe_name or "果冻" in recipe_name:
		attributes.weird = randi() % 5 + 6  # 6-10
	elif "漂浮" in recipe_name:
		attributes.weird = randi() % 4 + 4  # 4-7
	
	# 随机调整其他属性
	if attributes.spice == 0:
		attributes.spice = randi() % 3  # 0-2
	if attributes.sweet == 0:
		attributes.sweet = randi() % 4  # 0-3
	if attributes.weird == 0:
		attributes.weird = randi() % 5  # 0-4
	
	return attributes
