class_name CardData
extends Resource

# 卡片数据类
@export var id: String
@export var name: String
@export var pool: String
@export var spice: int = 0
@export var sweet: int = 0
@export var weird: int = 0
@export var base_price: int = 0
@export var rarity: String = "common"  # common, rare, epic, legendary
@export var description: String = ""
@export var image_path: String = ""

func _init(data: Dictionary = {}):
	if data.has("id"):
		id = data.id
	if data.has("name"):
		name = data.name
	if data.has("pool"):
		pool = data.pool
	if data.has("spice"):
		spice = data.spice
	if data.has("sweet"):
		sweet = data.sweet
	if data.has("weird"):
		weird = data.weird
	if data.has("base_price"):
		base_price = data.base_price

func get_rarity_from_attributes() -> String:
	"""根据属性计算稀有度"""
	var total_points = spice + sweet + weird
	
	if total_points >= 15:
		return "legendary"
	elif total_points >= 10:
		return "epic"
	elif total_points >= 6:
		return "rare"
	else:
		return "common"

func get_display_info() -> Dictionary:
	"""获取显示信息"""
	return {
		"name": name,
		"pool": pool,
		"attributes": {
			"spice": spice,
			"sweet": sweet,
			"weird": weird
		},
		"price": base_price,
		"rarity": get_rarity_from_attributes()
	}
