extends Control
class_name CardUI

# 卡片UI组件
signal card_selected(card_data: Dictionary)
signal card_deselected(card_data: Dictionary)

@onready var card_bg = $Background
@onready var name_label = $VBox/NameLabel
@onready var pool_label = $VBox/PoolLabel
@onready var attributes_label = $VBox/AttributesLabel
@onready var price_label = $VBox/PriceLabel

var card_data: Dictionary = {}
var is_selected: bool = false

# 稀有度颜色
var rarity_colors = {
	"common": Color(0.7, 0.7, 0.7),      # 灰色
	"rare": Color(0.3, 0.6, 1.0),        # 蓝色
	"epic": Color(0.6, 0.3, 1.0),        # 紫色
	"legendary": Color(1.0, 0.8, 0.2)    # 金色
}

func _ready():
	gui_input.connect(_on_gui_input)

func setup_card(data: Dictionary):
	"""设置卡片数据"""
	card_data = data
	_update_display()

func _update_display():
	"""更新显示"""
	if card_data.is_empty():
		return
	
	name_label.text = card_data.get("name", "未知")
	pool_label.text = card_data.get("pool", "")
	
	# 显示属性
	var spice = card_data.get("spice", 0)
	var sweet = card_data.get("sweet", 0)
	var weird = card_data.get("weird", 0)
	attributes_label.text = "辣:%d 甜:%d 奇:%d" % [spice, sweet, weird]
	
	# 显示价格
	price_label.text = str(card_data.get("base_price", 0)) + "金币"
	
	# 设置稀有度颜色
	var card_obj = CardData.new(card_data)
	var rarity = card_obj.get_rarity_from_attributes()
	card_bg.color = rarity_colors.get(rarity, Color.WHITE)

func _on_gui_input(event):
	"""处理输入事件"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_selection()

func toggle_selection():
	"""切换选中状态"""
	is_selected = !is_selected
	
	if is_selected:
		modulate = Color(1, 1, 1, 0.7)  # 半透明表示选中
		card_selected.emit(card_data)
	else:
		modulate = Color(1, 1, 1, 1)    # 完全不透明
		card_deselected.emit(card_data)

func set_selected(selected: bool):
	"""设置选中状态"""
	is_selected = selected
	modulate = Color(1, 1, 1, 0.7) if selected else Color(1, 1, 1, 1)
