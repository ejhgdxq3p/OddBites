extends Control

# UI引用
@onready var currency_label: Label = $MainContainer/Header/PlayerInfo/CurrencyLabel
@onready var trend_label: Label = $MainContainer/Header/TrendInfo/TrendLabel
@onready var nickname_label: Label = $MainContainer/Header/PlayerInfo/NicknameLabel
@onready var level_label: Label = $MainContainer/Header/PlayerInfo/LevelLabel
@onready var exp_bar: ProgressBar = $MainContainer/Header/PlayerInfo/ExpBar
@onready var daily_free_label: Label = $MainContainer/Header/PlayerInfo/DailyFreeLabel
@onready var avatar_button: Button = $MainContainer/Header/PlayerInfo/AvatarButton

@onready var pool_buttons_container: HBoxContainer = $MainContainer/ContentArea/LeftPanel/PoolButtons
@onready var draw_button: Button = $MainContainer/ContentArea/LeftPanel/DrawSection/DrawButton
@onready var generate_button: Button = $MainContainer/ContentArea/LeftPanel/DrawSection/GenerateButton
@onready var status_label: Label = $MainContainer/StatusPanel/StatusLabel

@onready var cards_grid: GridContainer = $MainContainer/ContentArea/MiddlePanel/CardsSection/CardScroll/CardsGrid
@onready var mydishes_grid: GridContainer = $MainContainer/ContentArea/MiddlePanel/DishesSection/MyDishesScroll/MyDishesGrid

@onready var image_preview: TextureRect = $MainContainer/ContentArea/RightPanel/PreviewArea/ImagePreview
@onready var preview_container: SubViewportContainer = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer
@onready var preview_viewport: SubViewport = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport
@onready var dish_root: Node3D = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport/WorldRoot/DishRoot

@onready var broadcast_trend: Label = $MainContainer/ContentArea/SidePanel/BroadcastPanel/BroadcastContent/BroadcastTrend
@onready var broadcast_log: RichTextLabel = $MainContainer/ContentArea/SidePanel/BroadcastPanel/BroadcastContent/BroadcastScroll/BroadcastLog

@onready var serve_name: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeName
@onready var serve_attrs: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeAttrs
@onready var serve_trend_base: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeTrendBase
@onready var serve_trend_bonus: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeTrendBonus
@onready var serve_suggest: LineEdit = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServePriceBox/ServeSuggest
@onready var serve_price_edit: LineEdit = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServePriceBox/ServePriceEdit
@onready var serve_price_box: HBoxContainer = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServePriceBox
@onready var serve_tags: FlowContainer = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeTags
@onready var serve_summary: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeSummary
@onready var combo_name_box: HBoxContainer = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ComboNameBox
@onready var combo_name_edit: LineEdit = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ComboNameBox/ComboNameEdit
@onready var serve_button: Button = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeActions/ServeButton
@onready var clear_serve_btn: Button = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeActions/ClearServeBtn
@onready var confirm_serve_btn: Button = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeActions/ConfirmServeBtn
@onready var online_meals_container: VBoxContainer = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/OnlineMealsContainer
@onready var online_meals_label: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/OnlineMealsLabel
@onready var back_to_menu_button: Button = $MainContainer/Header/BackToMenuBtn
@onready var drawer_node: Control = $MainContainer/ContentArea/RightPanel/RecipesDrawer
@onready var drawer_handle: Button = $MainContainer/ContentArea/RightPanel/RecipesDrawer/DrawerRoot/DrawerHandle
@onready var drawer_panel: PanelContainer = $MainContainer/ContentArea/RightPanel/RecipesDrawer/DrawerRoot/DrawerPanel

var drawer_opened: bool = false
var drawer_tween: Tween
var drawer_close_timer: Timer

var selected_pool: String = ""
var selected_cards: Array[Dictionary] = []
var card_buttons: Array[Button] = []
var current_task_id: String = ""
var thumb_items_by_task: Dictionary = {}
var thumb_info_by_task: Dictionary = {}
var processed_task_ids: Dictionary = {}
var pending_selected_by_task: Dictionary = {}
var serve_selected_names: Array[String] = []
const SERVE_PRICE_SOFTCAP: float = 1.0
const SERVE_PRICE_OVERSHOOT_PENALTY: float = 0.7
const SERVE_PRICE_UNDERSHOOT_BONUS: float = 1.1
var serve_price_user_dirty: bool = false
var serve_last_suggest: int = 0

var game_manager = preload("res://Scripts/GameManager.gd").new()
var tripo_api = preload("res://Scripts/TripoAPI.gd").new()
var avatar_manager = preload("res://Scripts/AvatarManager.gd").new()

func _ready():
	add_child(game_manager)
	add_child(tripo_api)
	add_child(avatar_manager)

	# 直接写入Tripo密钥与Client ID
	tripo_api.set_api_key("tsk_MKSPq9CEKjB_nnmWdWuMw4jfDCFHHG1IHt0ffzNN63U")
	if tripo_api.has_method("set_client_id"):
		tripo_api.set_client_id("tcli_e7c5a9214a6a49d2a07b05d5412934b0")
	else:
		tripo_api.set("client_id", "tcli_e7c5a9214a6a49d2a07b05d5412934b0")
	
	# 连接信号
	game_manager.card_drawn.connect(_on_card_drawn)
	game_manager.meal_sold.connect(_on_meal_sold)
	tripo_api.model_generation_started.connect(_on_model_generation_started)
	tripo_api.model_generation_completed.connect(_on_model_generation_completed)
	tripo_api.model_generation_failed.connect(_on_model_generation_failed)
	tripo_api.model_preview_updated.connect(_on_model_preview_updated)
	avatar_manager.avatar_downloaded.connect(_on_avatar_downloaded)
	avatar_manager.avatar_failed.connect(_on_avatar_failed)
	
	# 连接按钮信号
	if is_instance_valid(draw_button):
		draw_button.pressed.connect(_on_draw_button_pressed)
	if is_instance_valid(generate_button):
		generate_button.pressed.connect(_on_generate_button_pressed)
	if is_instance_valid(back_to_menu_button):
		back_to_menu_button.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))
	if is_instance_valid(serve_button):
		serve_button.pressed.connect(_on_serve_button_pressed)
	if is_instance_valid(confirm_serve_btn):
		confirm_serve_btn.pressed.connect(_on_confirm_serve_pressed)
	if is_instance_valid(clear_serve_btn):
		clear_serve_btn.pressed.connect(_clear_serve_selection)
	if is_instance_valid(serve_price_edit):
		serve_price_edit.text_changed.connect(func(_t):
			serve_price_user_dirty = true
			if game_manager:
				game_manager.ui_serve_price_text = serve_price_edit.text
				game_manager.ui_serve_price_user_dirty = serve_price_user_dirty
		)
	if is_instance_valid(avatar_button):
		avatar_button.pressed.connect(_on_avatar_button_pressed)
	
	# 初始化UI
	_setup_pool_buttons()
	_update_ui()
	_load_local_recipe_thumbnails()
	_restore_ui_state()
	
	# 启动定时器
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick_ui)
	timer.autostart = true
	add_child(timer)

func _on_serve_button_pressed() -> void:
	if serve_selected_names.is_empty():
		status_label.text = "请先从'我的料理'选择菜肴加入套餐"
		return
	
	if game_manager.online_meals.size() >= game_manager.MAX_ONLINE_MEALS:
		status_label.text = "在线套餐已达上限(3个)，请先下架一些套餐"
		return
	
	# 显示套餐命名输入框
	combo_name_box.visible = true
	combo_name_edit.text = ""
	combo_name_edit.grab_focus()
	serve_button.visible = false
	confirm_serve_btn.visible = true

func _on_confirm_serve_pressed() -> void:
	var combo_name = combo_name_edit.text.strip_edges()
	if combo_name.is_empty():
		status_label.text = "请输入套餐名称"
		return
	
	# 合计属性与成本
	var total_spice := 0
	var total_sweet := 0
	var total_weird := 0
	var total_cost := 0
	var names: Array[String] = []
	for n in serve_selected_names:
		var r := _find_recipe_by_name(n)
		if not r.is_empty():
			var a: Dictionary = r.attributes
			total_spice += int(a.get("spice", 0))
			total_sweet += int(a.get("sweet", 0))
			total_weird += int(a.get("weird", 0))
			total_cost += int(a.get("base_price", 0))
			names.append(n)
	
	# 建议价与玩家输入售价
	var bonus := game_manager.calculate_trend_bonus(total_spice, total_sweet, total_weird)
	var suggest := int(total_cost * bonus)
	var price_text := serve_price_edit.text.strip_edges()
	var price := int(price_text.to_int() if price_text.is_valid_int() else suggest)
	
	# 计算最终成交额
	var price_factor := SERVE_PRICE_SOFTCAP
	if price > suggest:
		var ratio := float(price) / float(max(1, suggest))
		if ratio >= 1.2:
			price_factor = SERVE_PRICE_OVERSHOOT_PENALTY
	elif price < suggest:
		price_factor = SERVE_PRICE_UNDERSHOOT_BONUS
	var final_income := int(price * price_factor)
	if final_income < 0:
		final_income = 0
	
	# 创建套餐数据
	var meal_data = {
		"combo_name": combo_name,
		"names": names,
		"total_spice": total_spice,
		"total_sweet": total_sweet,
		"total_weird": total_weird,
		"total_cost": total_cost,
		"trend_bonus": bonus,
		"suggest_price": suggest,
		"asked_price": price,
		"final_income": final_income
	}
	
	# 添加到在线套餐
	if game_manager.add_meal_to_online(meal_data):
		status_label.text = "套餐已上线，等待自动售卖..."
		_broadcast_meal_online(meal_data)
		_clear_serve_selection()
		combo_name_box.visible = false
		serve_button.visible = true
		confirm_serve_btn.visible = false
		_update_online_meals_display()
	else:
		status_label.text = "上线失败，请重试"

func _clear_serve_selection():
	serve_selected_names.clear()
	for c in serve_tags.get_children():
		c.queue_free()
	_update_serve_summary()
	serve_price_user_dirty = false
	serve_last_suggest = 0
	serve_suggest.text = "0"
	serve_price_edit.text = ""

func _update_online_meals_display() -> void:
	if not is_instance_valid(online_meals_container) or not is_instance_valid(online_meals_label):
		return
		
	for child in online_meals_container.get_children():
		child.queue_free()
	
	var online_count = game_manager.online_meals.size()
	var max_count = game_manager.MAX_ONLINE_MEALS
	online_meals_label.text = "我的套餐 (%d/%d)" % [online_count, max_count]
	
	for meal in game_manager.online_meals:
		var meal_container = VBoxContainer.new()
		meal_container.custom_minimum_size = Vector2(0, 50)
		
		# 套餐名称
		var name_label = Label.new()
		var combo_name = meal.get("combo_name", "未命名")
		name_label.text = "[b]%s[/b]" % combo_name
		name_label.bbcode_enabled = true
		meal_container.add_child(name_label)
		
		# 详情和下架按钮
		var detail_container = HBoxContainer.new()
		var info_label = Label.new()
		var names = meal.get("names", [])
		var total_cost = meal.get("total_cost", 0)
		var asked_price = meal.get("asked_price", 0)
		info_label.text = "%s | 成本:%d 售价:%d" % [", ".join(names), total_cost, asked_price]
		info_label.size_flags_horizontal = 3
		detail_container.add_child(info_label)
		
		var offline_btn = Button.new()
		offline_btn.text = "下架"
		offline_btn.custom_minimum_size = Vector2(60, 0)
		offline_btn.pressed.connect(func(): _offline_meal(meal.get("online_id", "")))
		detail_container.add_child(offline_btn)
		
		meal_container.add_child(detail_container)
		online_meals_container.add_child(meal_container)

func _offline_meal(online_id: String) -> void:
	if game_manager.remove_meal_from_online(online_id):
		status_label.text = "套餐已下架"
		_update_online_meals_display()
		_broadcast_meal_offline(online_id)
	else:
		status_label.text = "下架失败"

func _broadcast_meal_online(meal_data: Dictionary) -> void:
	if not is_instance_valid(broadcast_log):
		return
	var combo_name = meal_data.get("combo_name", "未命名")
	var names = meal_data.get("names", [])
	var total_spice = meal_data.get("total_spice", 0)
	var total_sweet = meal_data.get("total_sweet", 0)
	var total_weird = meal_data.get("total_weird", 0)
	var total_cost = meal_data.get("total_cost", 0)
	var suggest_price = meal_data.get("suggest_price", 0)
	var asked_price = meal_data.get("asked_price", 0)
	var detailed_trend = game_manager.get_detailed_trend_info()
	var line := "[color=blue]上线:[/color] [b]%s[/b] | %s | 辣:%d 甜:%d 奇:%d | 成本:%d 建议:%d 售价:%d | 潮流:%s\n" % [combo_name, ", ".join(names), total_spice, total_sweet, total_weird, total_cost, suggest_price, asked_price, detailed_trend]
	broadcast_log.append_text(line)
	broadcast_log.scroll_to_line(broadcast_log.get_line_count())
	_save_broadcast_line(line)

func _broadcast_meal_offline(online_id: String) -> void:
	if not is_instance_valid(broadcast_log):
		return
	var line := "[color=red]下架:[/color] 套餐ID: %s\n" % [online_id]
	broadcast_log.append_text(line)
	broadcast_log.scroll_to_line(broadcast_log.get_line_count())
	_save_broadcast_line(line)

func _on_meal_sold(meal_data: Dictionary, final_income: int) -> void:
	_update_ui()
	_update_online_meals_display()
	if is_instance_valid(broadcast_log):
		var combo_name = meal_data.get("combo_name", "未命名")
		var names = meal_data.get("names", [])
		var total_spice = meal_data.get("total_spice", 0)
		var total_sweet = meal_data.get("total_sweet", 0)
		var total_weird = meal_data.get("total_weird", 0)
		var total_cost = meal_data.get("total_cost", 0)
		var suggest_price = meal_data.get("suggest_price", 0)
		var asked_price = meal_data.get("asked_price", 0)
		var detailed_trend = game_manager.get_detailed_trend_info()
		var line := "[color=yellow]售出:[/color] [b]%s[/b] | %s | 辣:%d 甜:%d 奇:%d | 成本:%d 建议:%d 售价:%d 成交:%d | 潮流:%s\n" % [combo_name, ", ".join(names), total_spice, total_sweet, total_weird, total_cost, suggest_price, asked_price, final_income, detailed_trend]
		broadcast_log.append_text(line)
		broadcast_log.scroll_to_line(broadcast_log.get_line_count())
		_save_broadcast_line(line)

func _broadcast_recipe_created(recipe_data: Dictionary) -> void:
	if not is_instance_valid(broadcast_log):
		return
	var attr: Dictionary = recipe_data.get("attributes", {})
	var name: String = recipe_data.get("name", "料理")
	var base_price: int = int(attr.get("base_price", 0))
	var final_price: int = int(recipe_data.get("suggested_price", int(base_price * attr.get("trend_bonus", 1.0))))
	var spice := int(attr.get("spice", 0))
	var sweet := int(attr.get("sweet", 0))
	var weird := int(attr.get("weird", 0))
	var card_count := int(attr.get("card_count", 0))
	var processing_fee := int(attr.get("processing_fee", 0))
	var detailed_trend = game_manager.get_detailed_trend_info()
	var line := "[color=green]新菜:[/color] [b]%s[/b] | 辣:%d 甜:%d 奇:%d | %d张卡片 成本:%d(含加工费%d) 建议价:%d | 潮流:%s\n" % [name, spice, sweet, weird, card_count, base_price, processing_fee, final_price, detailed_trend]
	broadcast_log.append_text(line)
	broadcast_log.scroll_to_line(broadcast_log.get_line_count())
	_save_broadcast_line(line)

func _save_broadcast_line(line: String):
	if game_manager:
		if game_manager.ui_broadcast_lines == null:
			game_manager.ui_broadcast_lines = []
		game_manager.ui_broadcast_lines.append(line)
		if game_manager.ui_broadcast_lines.size() > 200:
			game_manager.ui_broadcast_lines = game_manager.ui_broadcast_lines.slice(-200, game_manager.ui_broadcast_lines.size())

func _tick_ui():
	game_manager.maybe_rotate_trend()
	var detailed_trend = game_manager.get_detailed_trend_info()
	trend_label.text = "当前潮流: " + detailed_trend
	if is_instance_valid(broadcast_trend):
		broadcast_trend.text = "潮流: " + detailed_trend
	level_label.text = "Lv." + str(game_manager.player_level)
	exp_bar.value = game_manager.player_exp
	exp_bar.max_value = game_manager.player_exp_to_next
	_update_online_meals_display()

# 保留所有其他原有函数...
func _setup_pool_buttons():
	pass
func _update_ui():
	pass
func _on_card_drawn(card_data):
	pass
func _on_model_generation_started(task_id: String):
	pass
func _on_model_generation_completed(model_data: Dictionary):
	pass
func _on_model_generation_failed(error_message: String):
	pass
func _on_model_preview_updated(preview_data: Dictionary):
	pass
func _on_avatar_downloaded(texture: Texture2D):
	pass
func _on_avatar_failed(error: String):
	pass
func _on_draw_button_pressed():
	pass
func _on_generate_button_pressed():
	pass
func _on_avatar_button_pressed():
	pass
func _find_recipe_by_name(name: String) -> Dictionary:
	return {}
func _find_recipe_by_id(rid: String) -> Dictionary:
	return {}
func _load_local_recipe_thumbnails():
	pass
func _restore_ui_state():
	pass
func _update_serve_summary():
	pass
