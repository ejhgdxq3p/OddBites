extends Control

# 预加载以确保类型在解析期可用
const OddBitesGameManager = preload("res://Scripts/GameManager.gd")
const TripoAPI = preload("res://Scripts/TripoAPI.gd")
const AvatarManager = preload("res://Scripts/AvatarManager.gd")

# 主游戏界面控制器
@onready var game_manager = OddBitesGameManager.new()
@onready var tripo_api = TripoAPI.new()
@onready var avatar_manager = AvatarManager.new()

# UI 引用
@onready var currency_label = $MainContainer/Header/Currency
@onready var trend_label = $MainContainer/Header/TrendInfo
@onready var avatar_rect = $MainContainer/PlayerPanel/Avatar
@onready var nickname_label = $MainContainer/PlayerPanel/PlayerInfo/Nickname
@onready var level_label = $MainContainer/PlayerPanel/PlayerInfo/LevelBox/Level
@onready var exp_bar = $MainContainer/PlayerPanel/PlayerInfo/LevelBox/ExpBar

@onready var pool_buttons_container = $MainContainer/ContentArea/LeftPanel/PoolButtons
@onready var pool_tab_btn: Button = $MainContainer/ContentArea/LeftPanel/SwitchBar/PoolTabBtn
@onready var mycards_tab_btn: Button = $MainContainer/ContentArea/LeftPanel/SwitchBar/MyCardsTabBtn
@onready var mycards_section: VBoxContainer = $MainContainer/ContentArea/LeftPanel/MyCardsSection
@onready var mycards_list: VBoxContainer = $MainContainer/ContentArea/LeftPanel/MyCardsSection/MyCardsScroll/MyCardsList
@onready var draw_button = $MainContainer/ContentArea/LeftPanel/DrawButton
@onready var card_grid = $MainContainer/ContentArea/CenterPanel/CardScroll/CardGrid
@onready var card_scroll: ScrollContainer = $MainContainer/ContentArea/CenterPanel/CardScroll
@onready var pool_showcase: VBoxContainer = $MainContainer/ContentArea/CenterPanel/PoolShowcase
@onready var pool_anim_container: Control = $MainContainer/ContentArea/CenterPanel/PoolShowcase/PoolAnimContainer
@onready var pool_showcase_script: Node = $MainContainer/ContentArea/CenterPanel/PoolShowcase
@onready var selected_cards_container = $MainContainer/ContentArea/CenterPanel/SelectedCards
@onready var generate_button = $MainContainer/ContentArea/CenterPanel/GenerateButton
@onready var recipe_list = $MainContainer/ContentArea/RightPanel/RecipesDrawer/DrawerRoot/DrawerPanel/Content/RecipeList
@onready var status_label = $MainContainer/StatusPanel/StatusLabel
@onready var preview_viewport: SubViewport = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport
@onready var dish_root: Node3D = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport/WorldRoot/DishRoot
@onready var image_preview: TextureRect = $MainContainer/ContentArea/RightPanel/PreviewArea/ImagePreview
@onready var preview_container: SubViewportContainer = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer
@onready var mydishes_grid: GridContainer = $MainContainer/ContentArea/CenterPanel/MyDishesScroll/MyDishesGrid
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
@onready var serve_button: Button = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeActions/ServeButton
@onready var clear_serve_btn: Button = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeActions/ClearServeBtn
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

@onready var combo_name_box: HBoxContainer = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ComboNameBox
@onready var combo_name_edit: LineEdit = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ComboNameBox/ComboNameEdit
@onready var confirm_serve_btn: Button = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/ServeActions/ConfirmServeBtn
@onready var online_meals_container: VBoxContainer = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/OnlineMealsContainer
@onready var online_meals_label: Label = $MainContainer/ContentArea/SidePanel/ServePanel/ServeContent/OnlineMealsLabel

func _ready():
	add_child(game_manager)
	add_child(tripo_api)
	add_child(avatar_manager)
	
	# 设置初始金币（仅新用户，老用户会从存档读取）
	if game_manager.player_currency == 0:
		game_manager.player_currency = 300

	# 直接写入Tripo密钥与Client ID（按你的要求）
	tripo_api.set_api_key("tsk_MKSPq9CEKjB_nnmWdWuMw4jfDCFHHG1IHt0ffzNN63U")
	if tripo_api.has_method("set_client_id"):
		tripo_api.set_client_id("tcli_e7c5a9214a6a49d2a07b05d5412934b0")
	else:
		# 兼容无该方法时，直接设置字段
		tripo_api.set("client_id", "tcli_e7c5a9214a6a49d2a07b05d5412934b0")
	
	# 连接信号
	game_manager.card_drawn.connect(_on_card_drawn)
	game_manager.meal_sold.connect(_on_meal_sold)  # 新增：监听自动售卖完成
	tripo_api.model_generation_started.connect(_on_model_generation_started)
	tripo_api.model_generation_completed.connect(_on_model_generation_completed)
	
	# 为关键按钮添加悬停特效
	_setup_button_hover_effects()
	
	# 初始化出餐面板状态
	_update_serve_summary()
	
	# 设置按钮初始文字和费用显示
	if is_instance_valid(draw_button):
		draw_button.text = "抽取卡片 (20金币)"
	if is_instance_valid(generate_button):
		generate_button.text = "生成料理 (50金币)"
	if is_instance_valid(serve_button):
		serve_button.text = "上线售卖 (10金币)"
	
	# 确保价格输入框初始为空
	if is_instance_valid(serve_price_edit):
		serve_price_edit.text = ""
		# 设置价格输入框的默认颜色
		serve_price_edit.add_theme_color_override("font_color", Color.CYAN)
		serve_price_edit.add_theme_color_override("font_focus_color", Color.CYAN)
		serve_price_edit.add_theme_color_override("font_hover_color", Color.CYAN)
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
	else:
		push_warning("serve_button 未找到，出餐按钮未连接")
	if is_instance_valid(confirm_serve_btn):
		confirm_serve_btn.pressed.connect(_on_confirm_serve_pressed)
	else:
		push_warning("confirm_serve_btn 未找到")
	if is_instance_valid(clear_serve_btn):
		clear_serve_btn.pressed.connect(func():
			serve_selected_names.clear()
			for c in serve_tags.get_children():
				c.queue_free()
			_update_serve_summary()
			# 重置价格输入状态
			serve_price_user_dirty = false
			serve_last_suggest = 0
			serve_suggest.text = "0"
			serve_price_edit.text = ""
		)
	else:
		push_warning("clear_serve_btn 未找到，清空按钮未连接")
	# 监听价格输入改动，标记为用户编辑
	if is_instance_valid(serve_price_edit):
		serve_price_edit.text_changed.connect(func(_t):
			serve_price_user_dirty = true
			if game_manager:
				game_manager.ui_serve_price_text = serve_price_edit.text
				game_manager.ui_serve_price_user_dirty = serve_price_user_dirty
		)
	# 悬停打开/离开延时关闭（手柄、抽屉节点、面板均监听）
	drawer_handle.mouse_entered.connect(_open_drawer)
	drawer_node.mouse_entered.connect(_open_drawer)
	drawer_panel.mouse_entered.connect(_open_drawer)
	drawer_handle.mouse_exited.connect(_schedule_close_drawer)
	drawer_node.mouse_exited.connect(_schedule_close_drawer)
	drawer_panel.mouse_exited.connect(_schedule_close_drawer)
	
	# 初始化UI
	_setup_pool_buttons()
	_update_ui()
	# 确保"生成料理"按钮可点击
	generate_button.disabled = false
	
	# 生成玩家头像
	_generate_player_avatar()
	# 设置头像点击事件
	_setup_avatar_click()

	# 让 3D 预览支持透明背景并创建透明环境
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_ensure_preview_environment()

	# 定时刷新UI（潮流倒计时/经验）
	var ui_timer := Timer.new()
	ui_timer.wait_time = 1.0
	ui_timer.timeout.connect(_tick_ui)
	add_child(ui_timer)
	ui_timer.start()
	
	status_label.text = "游戏初始化完成！选择卡池开始抽卡"
	
	# 测试广播容器是否正常工作
	if is_instance_valid(broadcast_log):
		broadcast_log.append_text("[color=green]游戏启动完成！广播系统正常\n")
		print("广播容器测试成功！")
		# 添加更多测试信息
		broadcast_log.append_text("[color=blue]广播容器已就绪，等待游戏事件...\n")
	else:
		print("广播容器无效！")
		# 尝试重新获取广播容器
		var test_broadcast = get_node_or_null("MainContainer/ContentArea/SidePanel/BroadcastPanel/BroadcastContent/BroadcastScroll/BroadcastLog")
		if test_broadcast and test_broadcast is RichTextLabel:
			print("重新获取广播容器成功！")
			broadcast_log = test_broadcast
			broadcast_log.append_text("[color=green]广播容器重新连接成功！\n")
		else:
			print("仍然找不到广播容器！")
			push_warning("广播容器未找到！")
	
	# 强制固定所有容器宽度
	call_deferred("_force_fix_container_widths")

	# 初始化抽屉位置（仅露出手柄）
	call_deferred("_apply_drawer_state")
	# 延时关闭定时器
	# 左侧页签切换
	pool_tab_btn.toggled.connect(func(pressed):
		if pressed:
			_pool_tab_on()
			mycards_tab_btn.button_pressed = false
	)
	mycards_tab_btn.toggled.connect(func(pressed):
		if pressed:
			_mycards_tab_on()
			pool_tab_btn.button_pressed = false
	)
	drawer_close_timer = Timer.new()
	drawer_close_timer.one_shot = true
	drawer_close_timer.wait_time = 0.35
	drawer_close_timer.timeout.connect(func():
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered and (drawer_node.is_ancestor_of(hovered) or hovered == drawer_node):
			return
		_close_drawer()
	)
	add_child(drawer_close_timer)

	# 初始化"我的料理"缩略图（读取 user://recipes 下的 png）
	_load_local_recipe_thumbnails()

	# 恢复 UI 存档状态
	_restore_ui_state()

func _restore_ui_state() -> void:
	if not game_manager:
		return
	# 恢复选中池
	if game_manager.ui_selected_pool != "":
		_select_pool(game_manager.ui_selected_pool)
	# 恢复"出餐"选择与价格
	serve_selected_names = game_manager.ui_serve_selected_names.duplicate()
	for name in serve_selected_names:
		_add_serve_tag(name)
	serve_last_suggest = int(game_manager.ui_serve_last_suggest)
	serve_price_user_dirty = bool(game_manager.ui_serve_price_user_dirty)
	serve_price_edit.text = str(game_manager.ui_serve_price_text)
	_update_serve_summary()
	# 恢复最后预览（若本地存在GLB则加载，否则忽略）
	var tid := str(game_manager.ui_last_preview_task_id)
	if tid != "":
		_on_thumb_clicked(tid)
	# 恢复广播日志
	if is_instance_valid(broadcast_log) and game_manager.ui_broadcast_lines.size() > 0:
		for ln in game_manager.ui_broadcast_lines:
			broadcast_log.append_text(ln)
		broadcast_log.scroll_to_line(broadcast_log.get_line_count())

func _apply_drawer_state() -> void:
	# 关闭：只显示手柄高度；展开：显示手柄+面板总高度
	var handle_h: float = 36.0
	var panel_h: float = drawer_panel.size.y
	var target_bottom: float = handle_h if not drawer_opened else (handle_h + panel_h)
	if drawer_tween and drawer_tween.is_running():
		drawer_tween.kill()
	drawer_node.offset_top = 0.0
	drawer_node.offset_bottom = target_bottom

func _toggle_drawer() -> void:
	# 已切换为垂直展开逻辑，此函数保持兼容但不再使用
	if drawer_opened:
		_close_drawer()
	else:
		_open_drawer()

func _open_drawer() -> void:
	if drawer_opened:
		return
	drawer_opened = true
	var handle_h: float = 36.0
	var panel_h: float = drawer_panel.size.y
	var from_bottom: float = drawer_node.offset_bottom
	var to_bottom: float = handle_h + panel_h
	if drawer_tween and drawer_tween.is_running():
		drawer_tween.kill()
	drawer_tween = get_tree().create_tween()
	drawer_tween.tween_property(drawer_node, "offset_bottom", to_bottom, 0.22).from(from_bottom)

func _close_drawer() -> void:
	if not drawer_opened:
		return
	drawer_opened = false
	var handle_h: float = 36.0
	var from_bottom: float = drawer_node.offset_bottom
	var to_bottom: float = handle_h
	if drawer_tween and drawer_tween.is_running():
		drawer_tween.kill()
	drawer_tween = get_tree().create_tween()
	drawer_tween.tween_property(drawer_node, "offset_bottom", to_bottom, 0.22).from(from_bottom)

func _schedule_close_drawer() -> void:
	if drawer_close_timer:
		drawer_close_timer.start()

func _ensure_preview_environment() -> void:
	# 在 SubViewport 的世界中放置透明背景的 WorldEnvironment
	var world_root: Node3D = preview_viewport.get_node("WorldRoot")
	if not world_root:
		return
	var existing := world_root.get_node_or_null("WorldEnvironment")
	if existing:
		return
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	we.environment = env
	world_root.add_child(we)

func _ensure_user_recipes_dir() -> void:
	var d := DirAccess.open("user://")
	if d:
		d.make_dir_recursive("recipes")

func _setup_pool_buttons():
	"""设置卡池按钮"""
	var pool_names = game_manager.get_pool_names()
	
	for pool_name in pool_names:
		var button = Button.new()
		button.text = pool_name
		button.pressed.connect(func(): _select_pool(pool_name))
		pool_buttons_container.add_child(button)

func _select_pool(pool_name: String):
	"""选择卡池"""
	selected_pool = pool_name
	status_label.text = "已选择卡池：" + pool_name
	
	# 更新按钮状态
	for child in pool_buttons_container.get_children():
		if child is Button:
			child.modulate = Color.WHITE if child.text != pool_name else Color.YELLOW
	# 若当前处于卡池页签，播放展示动画
	if pool_showcase.visible and pool_showcase_script and pool_showcase_script.has_method("play_showcase"):
		pool_showcase_script.call("play_showcase", pool_name)

func _on_draw_button_pressed():
	"""抽卡按钮点击"""
	if selected_pool.is_empty():
		_add_button_effect(draw_button, "guide")
		_show_button_tip(draw_button, "请先选择一个卡池！", true)  # 错误提示
		status_label.text = "请先选择一个卡池！"
		_show_pool_buttons_error_effect()  # 卡池按钮红色闪烁
		return
	
	if game_manager.player_currency < 20:  # 每次抽卡消耗20金币
		if game_manager.player_currency < 10:  # 金币少于10时触发救援
			game_manager.player_currency += 100
			status_label.text = "金币不足！已自动救援，补充100金币"
			_show_center_message("金币救援！补充100金币", Color.GREEN)
			_update_ui()
		else:
			_add_button_effect(draw_button, "guide")
			_show_button_tip(draw_button, "金币不足！需要20金币", true)  # 错误提示
			status_label.text = "金币不足！"
			_show_pool_buttons_error_effect()  # 卡池按钮红色闪烁
			return
	
	# 成功抽卡时添加特效
	_add_button_effect(draw_button, "bounce")
	
	game_manager.player_currency -= 20  # 每次抽卡消耗20金币
	var drawn_card = game_manager.draw_card_from_pool(selected_pool)
	
	if not drawn_card.is_empty():
		status_label.text = "抽到卡片：" + drawn_card.name
	
	_update_ui()

func _on_card_drawn(card_data: Dictionary):
	"""处理抽到卡片"""
	_add_card_to_grid(card_data)
	# 同步到"我的卡片"列表
	_add_card_to_mycards(card_data)

func _add_card_to_grid(card_data: Dictionary):
	"""将卡片添加到网格"""
	var card_button = Button.new()
	var rarity = card_data.get("rarity", "N")
	var count = card_data.get("count", 1)
	var card_name = str(card_data.get("name", ""))
	
	# 显示卡片名称、池、稀有度和数量
	card_button.text = card_name + "\n" + card_data.pool + "\n[" + rarity + "]"
	if count > 1:
		card_button.text += " x" + str(count)
	
	card_button.custom_minimum_size = Vector2(120, 80)
	
	# 根据稀有度设置颜色
	var rarity_colors = {
		"N": Color.WHITE,
		"R": Color.CYAN,
		"SR": Color.MAGENTA, 
		"SSR": Color.GOLD
	}
	
	card_button.modulate = rarity_colors.get(rarity, Color.WHITE)
	
	# 连接点击事件
	card_button.pressed.connect(func(): _toggle_card_selection(card_data, card_button))
	
	card_grid.add_child(card_button)
	card_buttons.append(card_button)

func _add_card_to_mycards(card_data: Dictionary) -> void:
	# 检查是否需要创建新行
	var current_rows = mycards_list.get_children()
	var current_row: HBoxContainer = null
	
	# 如果当前行不存在或已有两张卡，创建新行
	if current_rows.is_empty() or current_rows[-1].get_child_count() >= 2:
		current_row = HBoxContainer.new()
		current_row.custom_minimum_size = Vector2(400, 60)  # 设置行宽和行高，确保只能放两张卡
		current_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 居中对齐
		current_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 垂直居中对齐
		current_row.add_theme_constant_override("separation", 10)  # 卡片之间的间距
		mycards_list.add_child(current_row)
		print("创建新行，当前行数: ", current_rows.size() + 1)
	else:
		current_row = current_rows[-1]
		print("使用现有行，当前卡片数: ", current_row.get_child_count())
	
	# 创建卡片容器
	var card_container := Panel.new()
	card_container.custom_minimum_size = Vector2(180, 50)  # 增加宽度确保每行只能放两张
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 强制占用可用空间
	
	# 添加卡片样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # 深灰色半透明背景
	style.border_color = Color.WHITE
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card_container.add_theme_stylebox_override("panel", style)
	
	# 创建内容容器
	var content_container := VBoxContainer.new()
	content_container.position = Vector2(5, 5)  # 内容偏移
	card_container.add_child(content_container)
	
	var name_lbl := Label.new()
	var rarity = card_data.get("rarity", "N")
	var count = card_data.get("count", 1)
	var effective_price = game_manager.get_card_effective_price(str(card_data.name), int(card_data.get("base_price", 0)))
	
	name_lbl.text = "%s [%s] [%s]" % [card_data.name, card_data.pool, rarity]
	if count > 1:
		name_lbl.text += " x" + str(count)
	name_lbl.add_theme_font_size_override("font_size", 12)
	
	var attr_lbl := Label.new()
	attr_lbl.text = "辣:%d 甜:%d 奇:%d 成本:%d" % [card_data.get("spice",0), card_data.get("sweet",0), card_data.get("weird",0), effective_price]
	attr_lbl.add_theme_font_size_override("font_size", 10)
	
	content_container.add_child(name_lbl)
	content_container.add_child(attr_lbl)
	current_row.add_child(card_container)
	print("添加卡片到行，行内卡片数: ", current_row.get_child_count())

func _toggle_card_selection(card_data: Dictionary, button: Button):
	"""切换卡片选中状态"""
	var card_index = -1
	for i in range(selected_cards.size()):
		if selected_cards[i].id == card_data.id:
			card_index = i
			break
	
	if card_index >= 0:
		# 取消选中
		selected_cards.remove_at(card_index)
		button.modulate.a = 1.0
	else:
		# 选中卡片
		if selected_cards.size() < 5:  # 最多选择5张卡片
			selected_cards.append(card_data)
			button.modulate.a = 0.5
		else:
			status_label.text = "最多只能选择5张卡片！"
			return
	
	_update_selected_cards_display()

func _update_selected_cards_display():
	"""更新选中卡片显示"""
	# 清空现有显示
	for child in selected_cards_container.get_children():
		child.queue_free()
	
	# 添加选中的卡片
	for card in selected_cards:
		var label = Label.new()
		label.text = card.name
		selected_cards_container.add_child(label)
	
	# 更新生成按钮状态
	generate_button.disabled = selected_cards.is_empty()
	# 存档 UI 状态（强类型 Array[String]）
	if game_manager:
		var ids: Array[String] = []
		for c in selected_cards:
			ids.append(str(c.get("id", "")))
		game_manager.ui_selected_cards_ids = ids

func _pool_tab_on() -> void:
	$MainContainer/ContentArea/LeftPanel/PoolsLabel.visible = true
	$MainContainer/ContentArea/LeftPanel/PoolButtons.visible = true
	$MainContainer/ContentArea/LeftPanel/DrawButton.visible = true
	$MainContainer/ContentArea/LeftPanel/ShopButtons.visible = true
	mycards_section.visible = false
	# 中心切换到卡池展示
	pool_showcase.visible = true
	$MainContainer/ContentArea/CenterPanel/CardsLabel.visible = false
	$MainContainer/ContentArea/CenterPanel/CardScroll.visible = false
	# 播放展示动画
	if pool_showcase_script and pool_showcase_script.has_method("play_showcase"):
		pool_showcase_script.call("play_showcase", selected_pool)

func _mycards_tab_on() -> void:
	$MainContainer/ContentArea/LeftPanel/PoolsLabel.visible = false
	$MainContainer/ContentArea/LeftPanel/PoolButtons.visible = false
	$MainContainer/ContentArea/LeftPanel/DrawButton.visible = false
	$MainContainer/ContentArea/LeftPanel/ShopButtons.visible = false
	mycards_section.visible = true
	# 中心切到我的卡片列表
	pool_showcase.visible = false
	$MainContainer/ContentArea/CenterPanel/CardsLabel.visible = true
	$MainContainer/ContentArea/CenterPanel/CardScroll.visible = true
	# 清空展示
	if pool_showcase_script and pool_showcase_script.has_method("clear_showcase"):
		pool_showcase_script.call("clear_showcase")

func _on_generate_button_pressed():
	"""生成料理按钮点击"""
	if selected_cards.is_empty():
		# 如果没有选择卡片，直接报错
		_add_button_effect(generate_button, "guide")
		_show_button_tip(generate_button, "请先选择要组合的卡片！", true)  # 错误提示
		status_label.text = "请先选择要组合的卡片！"
		_show_draw_button_error_effect()  # 抽卡按钮红色闪烁
		return
	
	# 检查金币是否足够，不足时触发救援
	if game_manager.player_currency < 50:  # 每次生成料理消耗50金币
		if game_manager.player_currency < 10:  # 金币少于10时触发救援
			game_manager.player_currency += 100
			status_label.text = "金币不足！已自动救援，补充100金币"
			_show_center_message("金币救援！补充100金币", Color.GREEN)
			_update_ui()
		else:
			_add_button_effect(generate_button, "guide")
			_show_button_tip(generate_button, "金币不足！需要50金币", true)  # 错误提示
			status_label.text = "金币不足！"
			_show_draw_button_error_effect()  # 抽卡按钮红色闪烁
			return
	
	# 成功生成时添加特效
	_add_button_effect(generate_button, "bounce")
	
	# 扣除生成料理费用
	game_manager.player_currency -= 50  # 每次生成料理消耗50金币
	
	# 计算料理属性
	var recipe_attributes = game_manager.calculate_recipe_attributes(selected_cards)
	
	# 生成Prompt
	var prompt = game_manager.generate_prompt_from_cards(selected_cards)
	
	status_label.text = "正在生成料理：" + prompt
	
	# 立即在右边显示提示信息
	image_preview.visible = true
	preview_container.visible = false
	_show_center_message("3D模型正在生成当中，您可以点击左侧\"我的料理\"查看料理预览图", Color.YELLOW)
	
	# 调用Tripo API（暂时使用模拟）
	if tripo_api.api_key.is_empty():
		tripo_api.simulate_model_generation(prompt, "recipe_" + str(Time.get_unix_time_from_system()))
	else:
		tripo_api.generate_3d_model_from_text(prompt, "recipe_" + str(Time.get_unix_time_from_system()))

func _on_model_generation_started(task_id: String):
	"""3D模型生成开始"""
	status_label.text = "3D模型生成中，请稍候..."
	generate_button.disabled = true
	current_task_id = task_id
	# 记录本次任务使用的食材快照，避免后续清空导致名称丢失
	pending_selected_by_task[task_id] = selected_cards.duplicate()
	# 保持提示信息显示，等待占位或模型
	# image_preview.visible = false  # 注释掉，保持提示显示
	preview_container.visible = false

func _on_model_generation_completed(model_data: Dictionary):
	"""3D模型生成完成"""
	# 去重：同一任务只处理一次
	var task_id: String = model_data.get("task_id", "")
	if processed_task_ids.get(task_id, false):
		return
	processed_task_ids[task_id] = true
	# 创建料理数据
	var used_cards: Array = pending_selected_by_task.get(task_id, selected_cards.duplicate())
	var ingredients_names: Array[String] = []
	for c in used_cards:
		ingredients_names.append(str(c.get("name", "")))
	var dish_name := (" "+", ").join(ingredients_names)
	if dish_name.strip_edges() == "":
		dish_name = "神秘料理"
	var safe_name := dish_name
	# 替换不安全文件名字符
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe_name = safe_name.replace(ch, "_")

	var recipe_data = {
		"id": model_data.task_id,
		"name": safe_name,
		"ingredients": used_cards,
		"attributes": game_manager.calculate_recipe_attributes(used_cards),
		"model_url": model_data.get("model_url", ""),
		"preview_url": model_data.get("preview_url", ""),
		"prompt": model_data.get("prompt", ""),
		"created_at": Time.get_unix_time_from_system()
	}
	# 保存建议售价
	var attrs: Dictionary = recipe_data.get("attributes", {})
	var base_cost: int = int(attrs.get("base_price", 0))
	var trend_mul: float = float(attrs.get("trend_bonus", 1.0))
	var suggested_price: int = int(base_cost * trend_mul)
	recipe_data["suggested_price"] = suggested_price
	
	game_manager.player_recipes.append(recipe_data)
	# 自动存档
	if game_manager and game_manager.has_method("auto_save"):
		game_manager.auto_save()
	
	# 添加到料理列表
	_add_recipe_to_list(recipe_data)
	# 添加到我的料理缩略图（若已有临时项则更新）
	_update_thumb_for_task(recipe_data.id)
	
	# 清空选中的卡片，并移除任务快照
	selected_cards.clear()
	pending_selected_by_task.erase(task_id)
	_update_selected_cards_display()
	
	# 重置按钮状态
	for button in card_buttons:
		button.modulate.a = 1.0
	
	status_label.text = "料理生成成功：" + recipe_data.name
	generate_button.disabled = false
	
	# 生成成功时添加特效
	_add_button_effect(generate_button, "bounce")

	# 广播：创作完成
	_broadcast_recipe_created(recipe_data)

	# 优先尝试渲染真实模型
	var glb_url: String = _extract_model_url(model_data)
	if glb_url.is_empty():
		# 没有模型地址，显示错误信息
		status_label.text = "模型正在生成当中，请等待"
		image_preview.visible = true
		preview_container.visible = false
		# 在屏幕中央显示提示
		_show_center_message("3D模型正在生成当中，您可以点击左侧\"我的料理\"查看料理预览图", Color.YELLOW)
	else:
		# 持久化路径
		var base := "user://recipes/" + safe_name
		var glb_path := base + ".glb"
		_ensure_user_recipes_dir()
		_render_tripo_model(glb_url, glb_path)

	# 如果有预览图URL，下载并显示
	var preview_url: String = ""
	if model_data.has("output") and typeof(model_data.output) == TYPE_DICTIONARY:
		var out: Dictionary = model_data.output
		var gen_img = out.get("generated_image", "")
		if typeof(gen_img) == TYPE_STRING:
			preview_url = gen_img
	else:
		var pv = model_data.get("preview_url", "")
		if typeof(pv) == TYPE_STRING:
			preview_url = pv
	if not preview_url.is_empty():
		var base := "user://recipes/" + safe_name
		var img_path := base + ".png"
		_download_and_show_image(preview_url, img_path)
		image_preview.visible = false
		preview_container.visible = true # 若已有占位或模型，保持3D；否则由占位逻辑开启

func _on_model_generation_failed(error_message: String):
	"""3D模型生成失败"""
	status_label.text = "料理生成失败：" + error_message
	generate_button.disabled = false

func _on_model_preview_updated(url: String) -> void:
	# 中间态预览图显示
	if typeof(url) == TYPE_STRING and not url.is_empty():
		# 仅作为"我的料理"缩略，不再在右侧图片层显示
		_fetch_preview_to_thumb_only(url)
		image_preview.visible = false
		# 不显示 3D 视口，直到模型或占位渲染
		preview_container.visible = false
		# 将中间预览作为临时缩略加入"我的料理"
		# 由 _load_image_from_url 回调中完成 image_preview 赋值后，这里不做重复设置
		# 存档最后预览为当前任务
		if game_manager:
			game_manager.ui_last_preview_task_id = current_task_id

func _add_recipe_to_list(recipe_data: Dictionary):
	"""将料理添加到列表"""
	var recipe_container = VBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = recipe_data.name
	name_label.add_theme_font_size_override("font_size", 14)
	
	var attributes = recipe_data.attributes
	var attr_label = Label.new()
	attr_label.text = "辣度:%d 甜度:%d 奇异度:%d" % [attributes.spice, attributes.sweet, attributes.weird]
	attr_label.add_theme_font_size_override("font_size", 12)
	
	var cost_label = Label.new()
	var processing_fee = attributes.get("processing_fee", 0)
	var card_count = attributes.get("card_count", 0)
	cost_label.text = "成本:%d (卡片成本 + %d张加工费%d)" % [attributes.base_price, card_count, processing_fee]
	cost_label.add_theme_font_size_override("font_size", 10)
	
	var price_label = Label.new()
	var stored_suggest := int(recipe_data.get("suggested_price", int(attributes.base_price * attributes.trend_bonus)))
	price_label.text = "建议售价: " + str(stored_suggest) + " 金币"
	price_label.add_theme_font_size_override("font_size", 12)
	
	recipe_container.add_child(name_label)
	recipe_container.add_child(attr_label)
	recipe_container.add_child(cost_label)
	recipe_container.add_child(price_label)
	
	# 添加分隔线
	var separator = HSeparator.new()
	recipe_container.add_child(separator)
	
	recipe_list.add_child(recipe_container)

func _update_ui():
	"""更新UI显示"""
	currency_label.text = "金币: " + str(game_manager.player_currency)
	
	# 更新按钮文字，确保费用信息显示
	if is_instance_valid(draw_button):
		draw_button.text = "抽取卡片 (20金币)"
	if is_instance_valid(generate_button):
		generate_button.text = "生成料理 (50金币)"
	if is_instance_valid(serve_button):
		serve_button.text = "上线售卖 (10金币)"
	
	if not game_manager.current_trends.is_empty():
		var t: String = game_manager.current_trends[0]
		trend_label.text = "当前潮流: " + t
		if is_instance_valid(broadcast_trend):
			broadcast_trend.text = "潮流: " + t
	
	# 玩家信息
	nickname_label.text = game_manager.player_name
	level_label.text = "Lv." + str(game_manager.player_level)
	exp_bar.value = game_manager.player_exp
	exp_bar.max_value = game_manager.player_exp_to_next

	# 同步已选卡池到存档
	if game_manager:
		game_manager.ui_selected_pool = selected_pool

func _find_recipe_by_name(name: String) -> Dictionary:
	for r in game_manager.player_recipes:
		if str(r.get("name", "")) == name:
			return r
	return {}

func _find_recipe_by_id(rid: String) -> Dictionary:
	for r in game_manager.player_recipes:
		if str(r.get("id", "")) == rid:
			return r
	return {}

func _trend_baseline_desc(a: Dictionary) -> String:
	var current_trend: String = game_manager.current_trends[0] if not game_manager.current_trends.is_empty() else ""
	match current_trend:
		"奇异风暴":
			return "奇异度>=8"
		"甜蜜时光":
			return "甜度>=4"
		"火辣挑战":
			return "辣度>=4"
		"未来科技":
			return "奇异>=6且辣>=2"
		"经典回归":
			return "三项较低"
		_:
			return "无"

func _load_local_recipe_thumbnails() -> void:
	# 清空现有缩略
	for child in mydishes_grid.get_children():
		child.queue_free()
	thumb_items_by_task.clear()
	thumb_info_by_task.clear()
	# 读取 user://recipes 下的 png
	var dir := DirAccess.open("user://recipes")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			var img_path := "user://recipes/" + file_name
			_add_thumb_from_disk(img_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _refresh_mydishes_from_disk() -> void:
	_load_local_recipe_thumbnails()

func _add_temp_preview_thumb(tex: Texture2D) -> void:
	# 将中间预览作为当前任务的临时项
	if current_task_id == "":
		return
	var item: Control = thumb_items_by_task.get(current_task_id, null)
	if item == null:
		item = _create_thumb_item(tex, current_task_id)
		mydishes_grid.add_child(item)
		thumb_items_by_task[current_task_id] = item
	else:
		var btn := item.get_node("Button") as Button
		if btn:
			btn.icon = tex
	thumb_info_by_task[current_task_id] = {"texture": tex, "img_path": "", "glb_path": "user://recipes/" + current_task_id + ".glb"}

func _add_thumb_from_image(tex: Texture2D, save_path: String) -> void:
	var task_id := current_task_id
	if task_id == "":
		# 回退用文件名作为 id
		task_id = save_path.get_file().get_basename()
	var item: Control = thumb_items_by_task.get(task_id, null)
	if item == null:
		item = _create_thumb_item(tex, task_id)
		mydishes_grid.add_child(item)
		thumb_items_by_task[task_id] = item
	else:
		var btn := item.get_node("Button") as Button
		if btn:
			btn.icon = tex
	thumb_info_by_task[task_id] = {"texture": tex, "img_path": save_path, "glb_path": save_path.get_basename() + ".glb"}

func _add_thumb_from_disk(img_path: String) -> void:
	var img := Image.new()
	if img.load(img_path) != OK:
		return
	var tex := ImageTexture.create_from_image(img)
	var task_id := img_path.get_file().get_basename()
	var item := _create_thumb_item(tex, task_id)
	mydishes_grid.add_child(item)
	thumb_items_by_task[task_id] = item
	thumb_info_by_task[task_id] = {"texture": tex, "img_path": img_path, "glb_path": img_path.get_basename() + ".glb"}

func _create_thumb_item(tex: Texture2D, task_id: String) -> Control:
	var vb := VBoxContainer.new()
	vb.name = task_id
	var btn := Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(120, 90)
	btn.flat = true
	btn.icon = tex
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.pressed.connect(func(): _on_thumb_clicked(task_id))

	vb.add_child(btn)
	return vb

func _on_thumb_clicked(task_id: String) -> void:
	# 点击"我的料理"缩略：若本地有 glb 则加载模型，否则显示图片
	print("点击缩略: ", task_id)
	print("preview_viewport valid: ", is_instance_valid(preview_viewport))
	print("preview_container valid: ", is_instance_valid(preview_container))
	print("dish_root valid: ", is_instance_valid(dish_root))
	
	# 确保相机与环境
	_ensure_preview_environment()
	var cam: Camera3D = preview_viewport.get_node_or_null("WorldRoot/Camera3D")
	if not cam:
		print("重新创建相机")
		var world_root = preview_viewport.get_node("WorldRoot")
		cam = Camera3D.new()
		cam.name = "Camera3D"
		cam.current = true
		cam.fov = 55.0
		cam.position = Vector3(4, 3, 6)
		cam.look_at(Vector3(0, 0.15, 0), Vector3.UP)
		world_root.add_child(cam)

	var info: Dictionary = thumb_info_by_task.get(task_id, {})
	# 第三列永远显示3D：优先尝试本地GLB，其次占位渲染
	image_preview.visible = false
	var glb_path: String = info.get("glb_path", "")
	var candidate_paths: Array[String] = []
	if glb_path != "":
		candidate_paths.append(glb_path)
	# 兜底：基于缩略名与task_id的常见命名
	candidate_paths.append("user://recipes/" + task_id + ".glb")
	var img_path: String = info.get("img_path", "")
	if img_path != "":
		candidate_paths.append(img_path.get_basename() + ".glb")
	var loaded := false
	for p in candidate_paths:
		print("尝试路径: ", p, " 存在: ", FileAccess.file_exists(p))
		if FileAccess.file_exists(p):
			_load_model_from_disk(p)
			preview_container.visible = true
			print("加载模型成功")
			loaded = true
			break
	if not loaded:
		print("没有找到模型文件")
		status_label.text = "模型正在生成当中，请等待"
		preview_container.visible = false
		image_preview.visible = true
		# 在屏幕中央显示提示
		_show_center_message("3D模型正在生成当中，您可以点击左侧\"我的料理\"查看料理预览图", Color.YELLOW)
	
	print("preview_container.visible = ", preview_container.visible)
	print("image_preview.visible = ", image_preview.visible)

	# 将该菜加入"出餐"套餐选择（若未存在），定位 recipe
	var name := ""
	var img_path2: String = info.get("img_path", "")
	if img_path2 != "":
		name = ProjectSettings.globalize_path(img_path2).get_file().get_basename()
	var recipe := {}
	if name != "":
		recipe = _find_recipe_by_name(name)
	if recipe.is_empty():
		recipe = _find_recipe_by_id(task_id)
		if not recipe.is_empty():
			name = str(recipe.get("name", task_id))
	if name == "":
		name = task_id

	# 预览模型时不需要检查套餐状态，直接允许选择
	
	if not serve_selected_names.has(name):
		serve_selected_names.append(name)
		_add_serve_tag(name)
		
		# 在屏幕中央显示选择提示
		_show_center_message("「" + name + "」已选入套餐", Color.GREEN)

	# 单品信息（仅展示）
	if recipe.is_empty():
		serve_name.text = name
		serve_attrs.text = "辣0 甜0 奇0 | 成本0"
		serve_trend_base.text = "潮流基线: 无"
		serve_trend_bonus.text = "加成: x1.0"
	else:
		serve_name.text = str(recipe.get("name", name))
		var a: Dictionary = recipe.get("attributes", {})
		serve_attrs.text = "辣%d 甜%d 奇%d | 成本%d" % [int(a.get("spice",0)), int(a.get("sweet",0)), int(a.get("weird",0)), int(a.get("base_price",0))]
		var base_line := _trend_baseline_desc(a)
		serve_trend_base.text = "潮流基线: " + base_line
		serve_trend_bonus.text = "加成: x" + str(a.get("trend_bonus", 1.0))

	# 以套餐合计为准，更新价格框
	_update_serve_summary()
	# 记录 UI 状态（最后预览与套餐选择）
	if game_manager:
		game_manager.ui_last_preview_task_id = task_id
		game_manager.ui_serve_selected_names = serve_selected_names.duplicate()

func _add_serve_tag(name: String) -> void:
	var hb := HBoxContainer.new()
	hb.name = name
	var tag := Button.new()
	tag.text = name
	tag.toggle_mode = false
	
	# 为每个料理标签设置不同颜色
	var colors = [Color.CYAN, Color.MAGENTA, Color.YELLOW, Color.GREEN, Color.ORANGE]
	var color_index = serve_selected_names.size() - 1  # 根据添加顺序选择颜色
	if color_index < colors.size():
		tag.add_theme_color_override("font_color", colors[color_index])
		tag.add_theme_color_override("font_focus_color", colors[color_index])
		tag.add_theme_color_override("font_hover_color", colors[color_index])
	
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(20, 0)
	close.add_theme_color_override("font_color", Color.RED)
	close.add_theme_color_override("font_focus_color", Color.RED)
	close.add_theme_color_override("font_hover_color", Color.RED)
	close.pressed.connect(func():
		serve_selected_names.erase(name)
		if is_instance_valid(hb):
			hb.queue_free()
		_update_serve_summary()
		
		# 显示删除提示
		_show_center_message("「" + name + "」已从套餐中移除", Color.ORANGE)
		
		# 存档选中菜名
		if game_manager:
			game_manager.ui_serve_selected_names = serve_selected_names.duplicate()
	)
	hb.add_child(tag)
	hb.add_child(close)
	serve_tags.add_child(hb)

func _update_serve_summary() -> void:
	if serve_selected_names.is_empty():
		# 未选择料理
		serve_name.text = "请从'我的料理'选择菜肴"
		serve_attrs.text = "辣:0 甜:0 奇:0"
		serve_trend_base.text = "潮流加成: 无"
		serve_trend_bonus.text = "建议售价: 0"
		serve_summary.text = "合计: 0金币"
		serve_price_box.visible = false
		return
	
	var total_spice := 0
	var total_sweet := 0
	var total_weird := 0
	var total_cost := 0
	
	for n in serve_selected_names:
		# 先从内存中的 player_recipes 查找
		var r := _find_recipe_by_name(n)
		if r.is_empty():
			r = _find_recipe_by_id(n)
		
		# 如果还是找不到，则根据历史文件模拟属性
		if r.is_empty():
			# 从历史PNG文件推测属性（简单模拟）
			var img_path := "user://recipes/" + n + ".png"
			if FileAccess.file_exists(img_path):
				# 历史文件存在，给个基础属性避免全0
				total_spice += 2
				total_sweet += 2  
				total_weird += 2
				total_cost += 15
				print("历史文件 ", n, " 使用模拟属性: 辣2 甜2 奇2 成本15")
			else:
				print("未找到recipe或历史文件: ", n)
		else:
			var a: Dictionary = r.attributes
			total_spice += int(a.get("spice", 0))
			total_sweet += int(a.get("sweet", 0))
			total_weird += int(a.get("weird", 0))
			total_cost += int(a.get("base_price", 0))
			print("从recipe获取属性: ", n, " -> 辣", a.get("spice", 0), " 甜", a.get("sweet", 0), " 奇", a.get("weird", 0), " 成本", a.get("base_price", 0))
	
	serve_summary.text = "合计: 辣%d 甜%d 奇%d | 成本%d" % [total_spice, total_sweet, total_weird, total_cost]
	# 建议价与编辑框（按合计算）
	var bonus := game_manager.calculate_trend_bonus(total_spice, total_sweet, total_weird)
	var suggest := int(total_cost * bonus)
	serve_last_suggest = max(0, suggest)
	serve_suggest.text = str(serve_last_suggest)
	# 不自动预设实际售价，让玩家自己填写
	# 有选择时显示价格编辑框
	serve_price_box.visible = not serve_selected_names.is_empty()
	
	# 确保价格输入框为空，让玩家自己填写
	if serve_price_box.visible:
		serve_price_edit.text = ""
		# 重置价格输入框颜色
		_reset_price_input_color()
	# 同步 UI 状态到存档
	if game_manager:
		game_manager.ui_serve_selected_names = serve_selected_names.duplicate()
		game_manager.ui_serve_last_suggest = serve_last_suggest
		game_manager.ui_serve_price_text = serve_price_edit.text
		game_manager.ui_serve_price_user_dirty = serve_price_user_dirty

func _on_serve_button_pressed() -> void:
	# 检查是否有选择料理
	if serve_selected_names.is_empty():
		_add_button_effect(serve_button, "guide")
		_show_button_tip(serve_button, "请先从'我的料理'选择菜肴加入套餐", true)  # 错误提示
		status_label.text = "请先从'我的料理'选择菜肴加入套餐"
		_show_serve_button_error_effect()  # 出餐按钮红色闪烁
		return
	
	# 检查金币是否足够，不足时触发救援
	if game_manager.player_currency < 10:  # 每次上线售卖消耗10金币
		game_manager.player_currency += 100
		status_label.text = "金币不足！已自动救援，补充100金币"
		_show_center_message("金币救援！补充100金币", Color.GREEN)
		_update_ui()
	
	# 检查在线套餐数量限制
	if game_manager.online_meals.size() >= game_manager.MAX_ONLINE_MEALS:
		_add_button_effect(serve_button, "guide")
		_show_button_tip(serve_button, "在线套餐已达上限(3个)，请先下架一些套餐", true)  # 错误提示
		status_label.text = "在线套餐已达上限(3个)，请先下架一些套餐"
		_show_serve_button_error_effect()  # 出餐按钮红色闪烁
		return
	
	# 显示套餐命名输入框
	combo_name_box.visible = true
	combo_name_edit.text = ""
	combo_name_edit.grab_focus()
	serve_button.visible = false
	confirm_serve_btn.visible = true
	
	# 确保价格输入框为空，让玩家自己填写
	if is_instance_valid(serve_price_edit):
		serve_price_edit.text = ""
		# 重置价格输入框颜色
		_reset_price_input_color()

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
		else:
			# 如果找不到recipe，给个基础成本避免为0
			total_spice += 2
			total_sweet += 2
			total_weird += 2
			total_cost += 15
			names.append(n)
			print("未找到recipe，使用默认成本: ", n)
	
	# 建议价与玩家输入售价
	var bonus := game_manager.calculate_trend_bonus(total_spice, total_sweet, total_weird)
	var suggest := int(total_cost * bonus)
	var price_text := serve_price_edit.text.strip_edges()
	
	# 检查是否填写了价格
	if price_text.is_empty():
		_show_button_tip(confirm_serve_btn, "请填写售卖价格！", true)
		status_label.text = "请填写售卖价格！"
		_show_price_error_effect()
		return
	
	# 检查价格是否为有效数字
	if not price_text.is_valid_int():
		_show_button_tip(confirm_serve_btn, "价格必须是有效数字！", true)
		status_label.text = "价格必须是有效数字！"
		_show_price_error_effect()
		return
	
	var price := int(price_text.to_int())
	
	# 检查价格是否为正数
	if price <= 0:
		_show_button_tip(confirm_serve_btn, "价格必须大于0！", true)
		status_label.text = "价格必须大于0！"
		_show_price_error_effect()
		return
	
	# 计算最终成交额（使用相同的定价逻辑）
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
	print("尝试添加套餐到在线:", meal_data)
	if game_manager.add_meal_to_online(meal_data):
		print("套餐上线成功！")
		# 扣除上线售卖费用
		game_manager.player_currency -= 10  # 每次上线售卖消耗10金币
		# 成功出餐时添加特效
		_add_button_effect(serve_button, "bounce")
		status_label.text = "套餐已上线，等待自动售卖..."
		# 广播上线信息
		_broadcast_meal_online(meal_data)
		# 清空选择
		serve_selected_names.clear()
		for c in serve_tags.get_children():
			c.queue_free()
		_update_serve_summary()
		# 重置价格输入状态
		serve_price_user_dirty = false
		serve_last_suggest = 0
		serve_suggest.text = "0"
		serve_price_edit.text = ""
		# 隐藏命名框，恢复按钮
		combo_name_box.visible = false
		serve_button.visible = true
		confirm_serve_btn.visible = false
		_update_online_meals_display()
	else:
		print("套餐上线失败！")
		status_label.text = "上线失败，请重试"



func _load_model_from_disk(glb_path: String) -> void:
	print("_load_model_from_disk 开始: ", glb_path)
	# 清空现有模型
	for child in dish_root.get_children():
		print("移除旧子节点: ", child.name)
		child.queue_free()
	if not FileAccess.file_exists(glb_path):
		print("文件不存在")
		return
	var file := FileAccess.open(glb_path, FileAccess.READ)
	if not file:
		print("无法打开文件")
		return
	var buffer := file.get_buffer(file.get_length())
	file.close()
	print("文件读取完成，大小: ", buffer.size())
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var parse_result := gltf.append_from_buffer(buffer, "", state)
	print("GLB解析结果: ", parse_result)
	if parse_result != OK:
		print("GLB解析失败")
		return
	var generated := gltf.generate_scene(state)
	print("生成场景结果: ", generated)
	if generated and generated is Node3D:
		print("创建旋转容器")
		var rotating_container := Node3D.new()
		rotating_container.name = "RotatingModel"
		dish_root.add_child(rotating_container)
		rotating_container.add_child(generated)
		print("模型已添加到dish_root, dish_root子节点数: ", dish_root.get_children().size())
		
		# 强制设置位置和缩放
		rotating_container.position = Vector3(0, 0, 0)
		rotating_container.scale = Vector3(1, 1, 1)
		print("容器位置: ", rotating_container.position, " 缩放: ", rotating_container.scale)
		
		print("调用_fit_and_center_model前")
		_fit_and_center_model(rotating_container, generated)
		print("调用_adjust_preview_camera_to_fit前")
		_adjust_preview_camera_to_fit(rotating_container)
		
		# 检查相机状态
		var cam: Camera3D = preview_viewport.get_node_or_null("WorldRoot/Camera3D")
		if cam:
			print("相机位置: ", cam.position, " 朝向: ", cam.transform.basis.z)
		else:
			print("相机不存在！")
		
		# 检查模型最终状态
		print("容器最终位置: ", rotating_container.position, " 缩放: ", rotating_container.scale)
		var pivot = rotating_container.get_node_or_null("ModelPivot")
		if pivot:
			print("pivot位置: ", pivot.position, " 缩放: ", pivot.scale)
		
		# 强制刷新视口
		if preview_viewport:
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		
		print("开始旋转动画")
		var tween := get_tree().create_tween()
		tween.set_loops()
		tween.tween_property(rotating_container, "rotation:y", TAU, 8.0).from(0.0)
	else:
		print("生成场景失败或不是Node3D")

func _update_thumb_for_task(task_id: String) -> void:
	# 现已不显示标签，无需更新
	return

func _tick_ui():
	# 潮流倒计时刷新与轮换
	game_manager.maybe_rotate_trend()
	var remain = max(0, game_manager.get_trend_remaining_seconds())
	var m = int(remain / 60)
	var s = remain % 60
	var detailed_trend = game_manager.get_detailed_trend_info()
	trend_label.text = "当前潮流: " + detailed_trend
	# 玩家经验条显示随时更新
	level_label.text = "Lv." + str(game_manager.player_level)
	exp_bar.value = game_manager.player_exp
	exp_bar.max_value = game_manager.player_exp_to_next
	# 更新在线套餐信息
	_update_online_meals_display()

func _update_online_meals_display() -> void:
	"""更新在线套餐显示"""
	if not is_instance_valid(online_meals_container) or not is_instance_valid(online_meals_label):
		return
		
	# 清空现有显示
	for child in online_meals_container.get_children():
		child.queue_free()
	
	var online_count = game_manager.online_meals.size()
	var max_count = game_manager.MAX_ONLINE_MEALS
	
	# 更新标签
	online_meals_label.text = "我的套餐 (%d/%d)" % [online_count, max_count]
	
	# 显示每个在线套餐
	for meal in game_manager.online_meals:
		var meal_container = VBoxContainer.new()
		meal_container.custom_minimum_size = Vector2(0, 50)
		
		# 套餐名称
		var name_label = RichTextLabel.new()
		var combo_name = meal.get("combo_name", "未命名")
		name_label.text = "[b]%s[/b]" % combo_name
		name_label.bbcode_enabled = true
		name_label.fit_content = true
		name_label.custom_minimum_size = Vector2(0, 25)
		meal_container.add_child(name_label)
		
		# 详情和下架按钮
		var detail_container = HBoxContainer.new()
		var info_label = Label.new()
		var total_cost = meal.get("total_cost", 0)
		var asked_price = meal.get("asked_price", 0)
		info_label.text = "成本:%d 售价:%d" % [total_cost, asked_price]
		info_label.size_flags_horizontal = 3
		detail_container.add_child(info_label)
		
		# 下架按钮
		var offline_btn = Button.new()
		offline_btn.text = "下架"
		offline_btn.custom_minimum_size = Vector2(60, 0)
		offline_btn.pressed.connect(func(): _offline_meal(meal.get("online_id", "")))
		detail_container.add_child(offline_btn)
		
		meal_container.add_child(detail_container)
		online_meals_container.add_child(meal_container)
	
	# 在状态栏显示
	if online_count > 0:
		status_label.text = "在线套餐: %d/%d" % [online_count, max_count]

func _offline_meal(online_id: String) -> void:
	"""下架指定的在线套餐"""
	if game_manager.remove_meal_from_online(online_id):
		status_label.text = "套餐已下架"
		_update_online_meals_display()
		# 广播下架信息
		_broadcast_meal_offline(online_id)
	else:
		status_label.text = "下架失败"

func _broadcast_meal_offline(online_id: String) -> void:
	"""广播套餐下架信息"""
	if not is_instance_valid(broadcast_log):
		return
	# 找到套餐名称
	var combo_name = "未知套餐"
	for meal in game_manager.online_meals:
		if str(meal.get("online_id", "")) == online_id:
			combo_name = meal.get("combo_name", "未命名")
			break
	var line := "[color=red]下架:[/color] [b]%s[/b]\n" % [combo_name]
	broadcast_log.append_text(line)
	broadcast_log.scroll_to_line(broadcast_log.get_line_count())
	_save_broadcast_line(line)

func _broadcast_recipe_created(recipe_data: Dictionary) -> void:
	if not is_instance_valid(broadcast_log):
		return
	var attr: Dictionary = recipe_data.get("attributes", {})
	var name: String = recipe_data.get("name", "料理")
	var base_price: int = int(attr.get("base_price", 0))
	var trend_bonus: float = float(attr.get("trend_bonus", 1.0))
	var final_price: int = int(recipe_data.get("suggested_price", int(base_price * trend_bonus)))
	var spice := int(attr.get("spice", 0))
	var sweet := int(attr.get("sweet", 0))
	var weird := int(attr.get("weird", 0))
	var card_count := int(attr.get("card_count", 0))
	var processing_fee := int(attr.get("processing_fee", 0))
	var detailed_trend = game_manager.get_detailed_trend_info()
	var line := "[color=green]新菜:[/color] [b]%s[/b]  |  辣:%d 甜:%d 奇:%d  |  %d张卡片 成本:%d(含加工费%d)  建议价:%d  |  潮流:%s\n" % [name, spice, sweet, weird, card_count, base_price, processing_fee, final_price, detailed_trend]
	broadcast_log.append_text(line)
	broadcast_log.scroll_to_line(broadcast_log.get_line_count())
	# 存档广播日志（截断以防过长）
	if game_manager:
		if game_manager.ui_broadcast_lines == null:
			game_manager.ui_broadcast_lines = []
		game_manager.ui_broadcast_lines.append(line)
		if game_manager.ui_broadcast_lines.size() > 200:
			game_manager.ui_broadcast_lines = game_manager.ui_broadcast_lines.slice(-200, game_manager.ui_broadcast_lines.size())

func _save_broadcast_line(line: String):
	"""保存广播日志行"""
	if game_manager:
		if game_manager.ui_broadcast_lines == null:
			game_manager.ui_broadcast_lines = []
		game_manager.ui_broadcast_lines.append(line)
		if game_manager.ui_broadcast_lines.size() > 200:
			game_manager.ui_broadcast_lines = game_manager.ui_broadcast_lines.slice(-200, game_manager.ui_broadcast_lines.size())

func _force_fix_container_widths():
	"""强制固定所有容器宽度，确保不会变宽"""
	print("强制固定容器宽度...")
	
	# 固定SidePanel (VBoxContainer)
	if is_instance_valid(get_node_or_null("MainContainer/ContentArea/SidePanel")):
		var side_panel = get_node("MainContainer/ContentArea/SidePanel")
		side_panel.custom_minimum_size = Vector2(320, 0)
		side_panel.size_flags_horizontal = 0
		print("SidePanel宽度已固定")
	
	# 固定ServePanel (PanelContainer)
	if is_instance_valid(get_node_or_null("MainContainer/ContentArea/SidePanel/ServePanel")):
		var serve_panel = get_node("MainContainer/ContentArea/SidePanel/ServePanel")
		serve_panel.custom_minimum_size = Vector2(320, 0)
		serve_panel.size_flags_horizontal = 0
		print("ServePanel宽度已固定")
	
	# 固定ServeContent (VBoxContainer)
	if is_instance_valid(get_node_or_null("MainContainer/ContentArea/SidePanel/ServePanel/ServeContent")):
		var serve_content = get_node("MainContainer/ContentArea/SidePanel/ServePanel/ServeContent")
		serve_content.custom_minimum_size = Vector2(320, 0)
		serve_content.size_flags_horizontal = 0
		print("ServeContent宽度已固定")
	
	# 固定BroadcastPanel (PanelContainer)
	if is_instance_valid(get_node_or_null("MainContainer/ContentArea/SidePanel/BroadcastPanel")):
		var broadcast_panel = get_node("MainContainer/ContentArea/SidePanel/BroadcastPanel")
		broadcast_panel.custom_minimum_size = Vector2(320, 200)
		broadcast_panel.size_flags_horizontal = 0
		print("BroadcastPanel宽度已固定")
	
	print("所有容器宽度强制固定完成！")

func _broadcast_meal_online(meal_data: Dictionary) -> void:
	"""广播套餐上线信息"""
	print("开始广播套餐上线信息")
	print("broadcast_log引用:", broadcast_log)
	print("broadcast_log是否有效:", is_instance_valid(broadcast_log))
	
	if not is_instance_valid(broadcast_log):
		print("broadcast_log无效，尝试重新获取...")
		var test_broadcast = get_node_or_null("MainContainer/ContentArea/SidePanel/BroadcastPanel/BroadcastContent/BroadcastScroll/BroadcastLog")
		if test_broadcast and test_broadcast is RichTextLabel:
			print("重新获取广播容器成功！")
			broadcast_log = test_broadcast
		else:
			print("仍然找不到广播容器，无法广播上线信息")
			return
		
	var combo_name = meal_data.get("combo_name", "未命名")
	var total_spice = meal_data.get("total_spice", 0)
	var total_sweet = meal_data.get("total_sweet", 0)
	var total_weird = meal_data.get("total_weird", 0)
	var total_cost = meal_data.get("total_cost", 0)
	var suggest_price = meal_data.get("suggest_price", 0)
	var asked_price = meal_data.get("asked_price", 0)
	var detailed_trend = game_manager.get_detailed_trend_info()
	var line := "[color=blue]上线:[/color] [b]%s[/b] | 辣:%d 甜:%d 奇:%d | 成本:%d 建议:%d 售价:%d | 潮流:%s\n" % [combo_name, total_spice, total_sweet, total_weird, total_cost, suggest_price, asked_price, detailed_trend]
	print("准备添加上线广播到游戏界面:", line)
	
	# 强制添加到广播容器
	broadcast_log.append_text(line)
	broadcast_log.scroll_to_line(broadcast_log.get_line_count())
	_save_broadcast_line(line)
	print("上线广播已成功添加到游戏界面的广播容器！")
	
	# 确认是否真的添加了
	var current_text = broadcast_log.text
	if current_text.contains(combo_name):
		print("确认：上线广播文本已包含套餐名称")
	else:
		print("警告：上线广播文本中未找到套餐名称！")

func _on_meal_sold(meal_data: Dictionary, final_income: int) -> void:
	"""处理自动售卖完成"""
	print("MainGame收到meal_sold信号！套餐:", meal_data.get("names", []), "收入:", final_income)
	
	# 强制更新UI
	call_deferred("_update_ui")
	call_deferred("_update_online_meals_display")
	
	# 检查广播容器状态
	print("检查广播容器状态...")
	print("broadcast_log引用:", broadcast_log)
	print("broadcast_log是否有效:", is_instance_valid(broadcast_log))
	
	if is_instance_valid(broadcast_log):
		var combo_name = meal_data.get("combo_name", "未命名")
		var total_spice = meal_data.get("total_spice", 0)
		var total_sweet = meal_data.get("total_sweet", 0)
		var total_weird = meal_data.get("total_weird", 0)
		var total_cost = meal_data.get("total_cost", 0)
		var suggest_price = meal_data.get("suggest_price", 0)
		var asked_price = meal_data.get("asked_price", 0)
		var detailed_trend = game_manager.get_detailed_trend_info()
		var line := "[color=yellow]售出:[/color] [b]%s[/b] | 辣:%d 甜:%d 奇:%d | 成本:%d 建议:%d 售价:%d 成交:%d | 潮流:%s\n" % [combo_name, total_spice, total_sweet, total_weird, total_cost, suggest_price, asked_price, final_income, detailed_trend]
		print("准备添加售出广播到游戏界面:", line)
		
		# 强制添加到广播容器
		broadcast_log.append_text(line)
		broadcast_log.scroll_to_line(broadcast_log.get_line_count())
		_save_broadcast_line(line)
		print("售出广播已成功添加到游戏界面的广播容器！")
		
		# 再次确认是否真的添加了
		var current_text = broadcast_log.text
		if current_text.contains(combo_name):
			print("确认：广播文本已包含套餐名称")
		else:
			print("警告：广播文本中未找到套餐名称！")
	else:
		print("错误：broadcast_log无效，尝试重新获取...")
		var test_broadcast = get_node_or_null("MainContainer/ContentArea/SidePanel/BroadcastPanel/BroadcastContent/BroadcastScroll/BroadcastLog")
		if test_broadcast and test_broadcast is RichTextLabel:
			print("重新获取广播容器成功！")
			broadcast_log = test_broadcast
			# 重新尝试添加广播
			var combo_name = meal_data.get("combo_name", "未命名")
			var total_spice = meal_data.get("total_spice", 0)
			var total_sweet = meal_data.get("total_sweet", 0)
			var total_weird = meal_data.get("total_weird", 0)
			var total_cost = meal_data.get("total_cost", 0)
			var suggest_price = meal_data.get("suggest_price", 0)
			var asked_price = meal_data.get("asked_price", 0)
			var detailed_trend = game_manager.get_detailed_trend_info()
			var line := "[color=yellow]售出:[/color] [b]%s[/b] | 辣:%d 甜:%d 奇:%d | 成本:%d 建议:%d 售价:%d 成交:%d | 潮流:%s\n" % [combo_name, total_spice, total_sweet, total_weird, total_cost, suggest_price, asked_price, final_income, detailed_trend]
			broadcast_log.append_text(line)
			broadcast_log.scroll_to_line(broadcast_log.get_line_count())
			print("售出广播已通过重新获取的容器添加成功！")
		else:
			print("仍然找不到广播容器！")



func _load_image_from_url(url: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if code == 200:
			var img := Image.new()
			var err := img.load_webp_from_buffer(body)
			if err != OK:
				# 回退尝试JPEG/PNG
				err = img.load_png_from_buffer(body)
				if err != OK:
					err = img.load_jpg_from_buffer(body)
			if err == OK:
				var tex := ImageTexture.create_from_image(img)
				image_preview.texture = tex
				image_preview.visible = false
		req.queue_free()
	)
	var e = req.request(url)
	if e != OK:
		req.queue_free()

func _fetch_preview_to_thumb_only(url: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if code == 200:
			var img := Image.new()
			var err := img.load_webp_from_buffer(body)
			if err != OK:
				err = img.load_png_from_buffer(body)
				if err != OK:
					err = img.load_jpg_from_buffer(body)
			if err == OK:
				var tex := ImageTexture.create_from_image(img)
				_add_temp_preview_thumb(tex)
		req.queue_free()
	)
	var e = req.request(url)
	if e != OK:
		req.queue_free()

func _download_and_show_image(url: String, save_path: String = "") -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if code == 200:
			var img := Image.new()
			var err := img.load_webp_from_buffer(body)
			if err != OK:
				err = img.load_png_from_buffer(body)
				if err != OK:
					err = img.load_jpg_from_buffer(body)
			if err == OK:
				var tex := ImageTexture.create_from_image(img)
				# 预览图只用于缩略；右侧图片层保持隐藏
				image_preview.texture = tex
				image_preview.visible = false
				if save_path != "":
					_ensure_user_recipes_dir()
					img.save_png(save_path)
					_add_thumb_from_image(tex, save_path)
					# 若是当前任务，立刻刷新缩略栏
					if current_task_id != "":
						_update_thumb_for_task(current_task_id)
		req.queue_free()
	)
	var e = req.request(url)
	if e != OK:
		req.queue_free()

# 从 Tripo 回调中提取模型 glb/gltf 下载地址
func _extract_model_url(model_data: Dictionary) -> String:
	var url = model_data.get("model_url", "")
	if typeof(url) == TYPE_STRING and not url.is_empty():
		return url
	if model_data.has("output") and typeof(model_data.output) == TYPE_DICTIONARY:
		var out: Dictionary = model_data.output
		var m = out.get("model", "")
		if typeof(m) == TYPE_STRING and not m.is_empty():
			return m
		# 有些响应可能是 glb_url 字段
		var glb = out.get("glb_url", "")
		if typeof(glb) == TYPE_STRING and not glb.is_empty():
			return glb
	# 兜底：在整个字典里查找包含 .glb/.gltf 的字符串
	var found = _find_url_with_ext(model_data, [".glb", ".gltf"])
	return found if found != null else ""

func _find_url_with_ext(data, exts: Array[String]):
	match typeof(data):
		TYPE_DICTIONARY:
			for k in data.keys():
				var v = data[k]
				var r = _find_url_with_ext(v, exts)
				if r != null:
					return r
			return null
		TYPE_ARRAY:
			for v in data:
				var r = _find_url_with_ext(v, exts)
				if r != null:
					return r
			return null
		TYPE_STRING:
			var s: String = data
			for e in exts:
				if s.findn(e) != -1:
					return s
			return null
		_:
			return null

# 下载并在 SubViewport 中实例化 GLB 模型
func _render_tripo_model(glb_url: String, save_path: String = "") -> void:
	if not is_instance_valid(dish_root):
		return
	# 清空旧节点
	for child in dish_root.get_children():
		child.queue_free()

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if code == 200:
			var instantiated_root: Node3D = null
			# 优先使用 GLTFDocument 进行运行时解析，避免导入管线依赖
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			var perr: int = gltf.append_from_buffer(body, "", state)
			if perr == OK:
				var generated := gltf.generate_scene(state)
				if generated and generated is Node3D:
					instantiated_root = generated
			else:
				# 回退：保存到本地并尝试 ResourceLoader.load
				var tmp_path := save_path if save_path != "" else "user://temp_tripo_model.glb"
				_ensure_user_recipes_dir()
				var f := FileAccess.open(tmp_path, FileAccess.WRITE)
				if f:
					f.store_buffer(body)
					f.close()
					var scene := ResourceLoader.load(tmp_path)
					if scene and scene is PackedScene:
						var inst := (scene as PackedScene).instantiate()
						if inst and inst is Node3D:
							instantiated_root = inst

			# 无论是否走回退，都持久化一份 GLB（若指定了保存路径）
			if save_path != "":
				_ensure_user_recipes_dir()
				var ff := FileAccess.open(save_path, FileAccess.WRITE)
				if ff:
					ff.store_buffer(body)
					ff.close()

			if instantiated_root != null:
				# 放入旋转容器并缓慢旋转
				var rotating_container := Node3D.new()
				rotating_container.name = "RotatingModel"
				dish_root.add_child(rotating_container)
				rotating_container.add_child(instantiated_root)
				# 自适应居中与缩放，并调整相机取景
				_fit_and_center_model(rotating_container, instantiated_root)
				_adjust_preview_camera_to_fit(rotating_container)
				# 旋转动效
				var tween := get_tree().create_tween()
				tween.set_loops()
				tween.tween_property(rotating_container, "rotation:y", TAU, 8.0).from(0.0)
				# 避免与图片叠加导致闪烁
				image_preview.visible = false
				preview_container.visible = true
		else:
			print("GLB 下载失败 code=", code)
		req.queue_free()
	)
	var headers = ["Accept: model/gltf-binary, application/octet-stream"]
	var err = req.request(glb_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()

# 计算模型的合并包围盒并进行居中与缩放
func _fit_and_center_model(parent_container: Node3D, model_root: Node3D) -> void:
	print("_fit_and_center_model开始")
	# 创建一个局部容器，方便位移与缩放
	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	parent_container.add_child(pivot)
	model_root.reparent(pivot)
	print("模型已reparent到pivot")

	# 计算合并 AABB（基于 MeshInstance3D）
	var aabb := _compute_combined_aabb(model_root)
	print("计算AABB: ", aabb)
	if aabb.size == Vector3.ZERO:
		print("AABB大小为0，跳过居中")
		return
	var center := aabb.position + aabb.size * 0.5
	print("模型中心: ", center)

	# 将模型中心对齐到 (0, desired_height, 0)
	var desired_height: float = 0.15
	# 平移 pivot 使得模型在场景原点居中且略高于盘面
	pivot.position = Vector3(-center.x, -center.y + desired_height, -center.z)
	print("pivot位置设为: ", pivot.position)

	# 自适应缩放：目标半径
	var radius: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) * 0.5
	print("模型半径: ", radius)
	if radius <= 0.0001:
		print("半径太小，跳过缩放")
		return
	var target_radius: float = 1.6
	var scale_factor: float = target_radius / radius
	pivot.scale = Vector3.ONE * scale_factor
	print("缩放因子: ", scale_factor, " pivot最终缩放: ", pivot.scale)

func _compute_combined_aabb(root: Node) -> AABB:
	var combined := AABB()
	var has_any := false
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var b := mi.get_aabb()
			if not has_any:
				combined = b
				has_any = true
			else:
				combined = combined.merge(b)
	return combined if has_any else AABB(Vector3.ZERO, Vector3.ZERO)

# 根据已放入的模型容器自动调整相机至合适取景
func _adjust_preview_camera_to_fit(container: Node3D) -> void:
	var cam: Camera3D = preview_viewport.get_node("WorldRoot/Camera3D")
	if not cam:
		return
	# 基于容器下模型的 AABB 估算距离
	var aabb := _compute_combined_aabb(container)
	if aabb.size == Vector3.ZERO:
		return
	var radius: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) * 0.5
	# 更保守的距离，避免被裁剪和太近
	var distance: float = max(5.0, radius * 4.0)
	cam.position = Vector3(distance * 0.7, distance * 0.5, distance)
	cam.look_at(Vector3(0, 0.15, 0), Vector3.UP)
	cam.fov = 50.0
	cam.near = 0.01
	cam.far = 200.0

func _generate_player_avatar():
	"""生成玩家头像"""
	avatar_manager.generate_avatar(game_manager.player_avatar_seed)

func _setup_avatar_click():
	"""设置头像点击事件"""
	if avatar_rect:
		avatar_rect.gui_input.connect(_on_avatar_clicked)

func _on_avatar_clicked(event: InputEvent):
	"""头像点击事件 - 重新生成食物头像"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_manager.regenerate_avatar()
		avatar_manager.generate_food_avatar(game_manager.player_avatar_seed)
		status_label.text = "正在生成新食物头像..."

func _on_avatar_downloaded(texture: Texture2D):
	"""头像下载完成回调"""
	if avatar_rect is TextureRect:
		avatar_rect.texture = texture
		print("玩家头像更新成功")
	else:
		print("头像容器不是TextureRect类型")

func _on_avatar_failed(error: String):
	"""头像下载失败回调"""
	print("头像生成失败: ", error)
	status_label.text = "头像生成失败: " + error

# 按钮特效和提示系统
func _setup_button_hover_effects() -> void:
	"""为关键按钮设置悬停特效和特殊颜色"""
	var buttons = [draw_button, generate_button, serve_button]
	var colors = [Color.CYAN, Color.MAGENTA, Color.ORANGE]  # 抽卡、生成、出餐的特殊颜色
	
	for i in range(buttons.size()):
		var button = buttons[i]
		if is_instance_valid(button):
			# 设置特殊颜色
			button.add_theme_color_override("font_color", colors[i])
			button.add_theme_color_override("font_focus_color", colors[i])
			button.add_theme_color_override("font_hover_color", colors[i])
			
			# 连接悬停事件
			button.mouse_entered.connect(func(): _on_button_hover_enter(button))
			button.mouse_exited.connect(func(): _on_button_hover_exit(button))

func _on_button_hover_enter(button: Button) -> void:
	"""按钮悬停进入"""
	if is_instance_valid(button):
		var tween = get_tree().create_tween()
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_hover_exit(button: Button) -> void:
	"""按钮悬停离开"""
	if is_instance_valid(button):
		var tween = get_tree().create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func _add_button_effect(button: Button, effect_type: String = "pulse") -> void:
	"""为按钮添加特效"""
	if not is_instance_valid(button):
		return
	
	match effect_type:
		"pulse":
			var tween = get_tree().create_tween()
			tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)
			tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
		"guide":
			var tween = get_tree().create_tween()
			tween.set_loops(3)  # 循环3次引导效果
			tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.3)
			tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)
			# 同时添加颜色变化，让引导更明显
			var color_tween = get_tree().create_tween()
			color_tween.set_loops(3)
			color_tween.tween_property(button, "modulate", Color.CYAN, 0.3)
			color_tween.tween_property(button, "modulate", Color.WHITE, 0.3)
		"glow":
			var tween = get_tree().create_tween()
			tween.tween_property(button, "modulate", Color.YELLOW, 0.2)
			tween.tween_property(button, "modulate", Color.WHITE, 0.2)
		"bounce":
			var tween = get_tree().create_tween()
			tween.tween_property(button, "scale", Vector2(1.2, 1.2), 0.15)
			tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.15)
			tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.15)

func _show_button_tip(button: Button, tip_text: String, is_error: bool = false) -> void:
	"""显示按钮提示"""
	if not is_instance_valid(button):
		return
	
	# 创建提示标签
	var tip_label = Label.new()
	tip_label.text = "💡 " + tip_text if not is_error else "❌ " + tip_text  # 错误时用❌图标
	tip_label.add_theme_font_size_override("font_size", 16 if is_error else 14)
	tip_label.add_theme_color_override("font_color", Color.RED if is_error else Color.WHITE)
	
	# 创建背景面板
	var tip_panel = Panel.new()
	tip_panel.add_child(tip_label)
	tip_label.position = Vector2(8, 4)
	
	# 设置提示位置（错误时在屏幕中央，引导时在按钮下方）
	var tip_pos: Vector2
	if is_error:
		# 屏幕中央显示错误，添加红色边框
		tip_panel.add_theme_stylebox_override("panel", _create_error_stylebox())
		var screen_center = get_viewport().get_visible_rect().size / 2
		tip_pos = screen_center - tip_panel.size / 2
	else:
		# 按钮下方显示引导
		tip_pos = button.global_position + Vector2(0, button.size.y + 10)
	
	tip_panel.global_position = tip_pos
	tip_panel.size = tip_label.size + Vector2(16, 8)
	
	# 添加到场景
	add_child(tip_panel)
	
	# 错误提示显示5秒，引导提示显示3秒
	var display_time = 5.0 if is_error else 3.0
	var timer = get_tree().create_timer(display_time)
	timer.timeout.connect(func(): 
		if is_instance_valid(tip_panel):
			tip_panel.queue_free()
	)

func _create_error_stylebox() -> StyleBoxFlat:
	"""创建错误提示的样式框"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)  # 黑色半透明背景
	style.border_color = Color.WHITE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _show_center_message(message: String, color: Color = Color.WHITE) -> void:
	"""在屏幕中央显示消息"""
	var msg_label = Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", color)
	
	# 创建背景面板
	var msg_panel = Panel.new()
	msg_panel.add_child(msg_label)
	msg_label.position = Vector2(8, 4)
	
	# 设置样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	msg_panel.add_theme_stylebox_override("panel", style)
	
	# 设置位置（屏幕中央）
	var screen_center = get_viewport().get_visible_rect().size / 2
	msg_panel.global_position = screen_center - msg_panel.size / 2
	msg_panel.size = msg_label.size + Vector2(16, 8)
	
	# 添加到场景
	add_child(msg_panel)
	
	# 2秒后自动消失
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(msg_panel):
			msg_panel.queue_free()
	)

func _show_price_error_effect() -> void:
	"""显示价格输入框错误特效（红色闪烁）"""
	if not is_instance_valid(serve_price_edit):
		return
	
	# 保存原始颜色
	var original_color = serve_price_edit.get_theme_color("font_color")
	
	# 创建闪烁动画
	var tween = get_tree().create_tween()
	tween.set_loops(3)  # 闪烁3次
	
	# 红色 → 原色 → 红色 → 原色
	tween.tween_property(serve_price_edit, "modulate", Color.RED, 0.2)
	tween.tween_property(serve_price_edit, "modulate", Color.WHITE, 0.2)
	tween.tween_property(serve_price_edit, "modulate", Color.RED, 0.2)
	tween.tween_property(serve_price_edit, "modulate", Color.WHITE, 0.2)

func _reset_price_input_color() -> void:
	"""重置价格输入框颜色为默认"""
	if not is_instance_valid(serve_price_edit):
		return
	
	serve_price_edit.modulate = Color.WHITE
	# 确保主题颜色保持青色
	serve_price_edit.add_theme_color_override("font_color", Color.CYAN)

func _show_pool_buttons_error_effect() -> void:
	"""显示卡池按钮错误特效（红色闪烁）"""
	var pool_buttons = pool_buttons_container.get_children()
	for button in pool_buttons:
		if button is Button:
			# 保存原始颜色
			var original_color = button.get_theme_color("font_color")
			
			# 创建闪烁动画
			var tween = get_tree().create_tween()
			tween.set_loops(3)  # 闪烁3次
			
			# 红色 → 原色 → 红色 → 原色
			tween.tween_property(button, "modulate", Color.RED, 0.2)
			tween.tween_property(button, "modulate", Color.WHITE, 0.2)
			tween.tween_property(button, "modulate", Color.RED, 0.2)
			tween.tween_property(button, "modulate", Color.WHITE, 0.2)

func _show_draw_button_error_effect() -> void:
	"""显示抽卡按钮错误特效（红色闪烁）"""
	if not is_instance_valid(draw_button):
		return
	
	# 创建闪烁动画
	var tween = get_tree().create_tween()
	tween.set_loops(3)  # 闪烁3次
	
	# 红色 → 原色 → 红色 → 原色
	tween.tween_property(draw_button, "modulate", Color.RED, 0.2)
	tween.tween_property(draw_button, "modulate", Color.WHITE, 0.2)
	tween.tween_property(draw_button, "modulate", Color.RED, 0.2)
	tween.tween_property(draw_button, "modulate", Color.WHITE, 0.2)

func _show_serve_button_error_effect() -> void:
	"""显示出餐按钮错误特效（红色闪烁）"""
	if not is_instance_valid(serve_button):
		return
	
	# 创建闪烁动画
	var tween = get_tree().create_tween()
	tween.set_loops(3)  # 闪烁3次
	
	# 红色 → 原色 → 红色 → 原色
	tween.tween_property(serve_button, "modulate", Color.RED, 0.2)
	tween.tween_property(serve_button, "modulate", Color.WHITE, 0.2)
	tween.tween_property(serve_button, "modulate", Color.RED, 0.2)
	tween.tween_property(serve_button, "modulate", Color.WHITE, 0.2)
