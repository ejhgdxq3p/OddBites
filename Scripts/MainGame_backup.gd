extends Control

# 预加载以确保类型在解析期可用
const OddBitesGameManager = preload("res://Scripts/GameManager.gd")
const TripoAPI = preload("res://Scripts/TripoAPI.gd")
const CardUIScene: PackedScene = preload("res://UI/CardUI.tscn")

# 抽屉展开高度（像素），避免初始 size 为 0 导致无法展开
const DRAWER_EXPANDED_HEIGHT: float = 420.0
# 悬停延时设置（秒）
const HOVER_DELAY: float = 0.15
const CLOSE_DELAY: float = 0.5

# 安全连接/重绑辅助
func _safe_connect_button_pressed(button: Node, callable) -> void:
	if button == null:
		return
	if not (button is Button):
		return
	var btn := button as Button
	if btn.pressed.is_connected(callable):
		return
	btn.pressed.connect(callable)

func _safe_rebind_draw_button() -> void:
	# 已不使用单独的 right_draw_button（按钮在各页签内部创建并已绑定）
	return

# 主游戏界面控制器
@onready var game_manager = OddBitesGameManager.new()
@onready var tripo_api = TripoAPI.new()

# UI 引用
@onready var currency_label = $MainContainer/Header/Currency
@onready var trend_label = $MainContainer/Header/TrendInfo
@onready var nickname_label = $MainContainer/PlayerPanel/PlayerInfo/Nickname
@onready var level_label = $MainContainer/PlayerPanel/PlayerInfo/LevelBox/Level
@onready var exp_bar = $MainContainer/PlayerPanel/PlayerInfo/LevelBox/ExpBar
@onready var daily_free_label = $MainContainer/PlayerPanel/DailyFreeDraws
@onready var tabs_bar: HBoxContainer = $MainContainer/ContentArea/LeftPanel/InfoView/TabsBar
@onready var left_tabs: TabContainer = $MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs
@onready var my_cards_view: Control = $MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs/MyCardsTab
@onready var my_cards_list = $MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs/MyCardsTab/CardGrid
@onready var card_grid = $MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs/MyCardsTab/CardGrid
@onready var selected_cards_container = $MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs/MyCardsTab/SelectedCards
@onready var generate_button = $MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs/MyCardsTab/GenerateButton
@onready var recipe_list = $MainContainer/ContentArea/RightPanel/RecipesDrawer/DrawerRoot/DrawerPanel/Content/RecipeList
@onready var status_label = $MainContainer/StatusPanel/StatusLabel
@onready var preview_viewport: SubViewport = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport
@onready var dish_root: Node3D = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport/WorldRoot/DishRoot
@onready var image_preview: TextureRect = $MainContainer/ContentArea/RightPanel/PreviewArea/ImagePreview
@onready var preview_container: SubViewportContainer = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer
@onready var back_to_menu_button: Button = $MainContainer/Header/BackToMenuBtn
@onready var drawer_node: Control = $MainContainer/ContentArea/RightPanel/RecipesDrawer
@onready var drawer_handle: Button = $MainContainer/ContentArea/RightPanel/RecipesDrawer/DrawerRoot/DrawerHandle
@onready var drawer_panel: PanelContainer = $MainContainer/ContentArea/RightPanel/RecipesDrawer/DrawerRoot/DrawerPanel
var drawer_opened: bool = false
var drawer_tween: Tween
var close_timer: Timer
var is_mouse_in_drawer_area: bool = false

# 运行时标签按钮
var pool_key_to_title: Dictionary = {
	"weird": "奇趣异域",
	"classic": "传统经典",
	"sweet": "甜点幻想",
	"future": "潮流未来",
	"fire": "火焰烈厨"
}

var selected_pool: String = ""
var selected_cards: Array[Dictionary] = []
var card_buttons: Array[Button] = []
var pool_to_icon: Dictionary = {}

func _ready():
	add_child(game_manager)
	add_child(tripo_api)

	# 直接写入Tripo密钥与Client ID（按你的要求）
	tripo_api.set_api_key("tsk_MKSPq9CEKjB_nnmWdWuMw4jfDCFHHG1IHt0ffzNN63U")
	if tripo_api.has_method("set_client_id"):
		tripo_api.set_client_id("tcli_e7c5a9214a6a49d2a07b05d5412934b0")
	else:
		# 兼容无该方法时，直接设置字段
		tripo_api.set("client_id", "tcli_e7c5a9214a6a49d2a07b05d5412934b0")
	
	# 连接信号
	game_manager.card_drawn.connect(_on_card_drawn)
	tripo_api.model_generation_started.connect(_on_model_generation_started)
	tripo_api.model_generation_completed.connect(_on_model_generation_completed)
	tripo_api.model_generation_failed.connect(_on_model_generation_failed)
	tripo_api.model_preview_updated.connect(_on_model_preview_updated)
	
	# 连接按钮信号（安全连接）
	_safe_connect_button_pressed(generate_button, _on_generate_button_pressed)
	_safe_connect_button_pressed(back_to_menu_button, func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))
	# 连接抽屉手柄点击事件
	drawer_handle.pressed.connect(_on_drawer_handle_clicked)
	
	# 缓存各卡池页签的 GachaIcon 映射
	_cache_pool_nodes()
	
	# 绑定 TabContainer 的 tab_changed 信号
	if is_instance_valid(left_tabs):
		left_tabs.tab_changed.connect(_on_left_tabs_tab_changed)
	
	# 初始化左侧页签按钮
	_rebuild_tabs_bar()
	_update_ui()
	# 确保"生成料理"按钮可点击
	if is_instance_valid(generate_button):
		generate_button.disabled = false
	# 默认显示"我的卡片"视图
	_show_my_cards_view()

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

	# 初始化新的悬停逻辑
	_setup_drawer_hover_system()
	# 开启每帧处理用于悬停检测
	set_process(true)
	# 初始关闭时隐藏面板以避免占位
	drawer_panel.visible = drawer_opened

	# 初始化左侧 InfoView 默认为“我的卡片”（CenterPanel 与 RightPanel 留给 3D）
	_show_my_cards_view()
	
	# 初始化抽屉位置（仅露出手柄）
	call_deferred("_apply_drawer_state")

# 点击打开+悬停关闭系统设置
func _setup_drawer_hover_system() -> void:
	# 只创建关闭延时定时器（不再需要悬停打开定时器）
	close_timer = Timer.new()
	close_timer.one_shot = true
	close_timer.wait_time = CLOSE_DELAY
	close_timer.timeout.connect(_on_close_timer_timeout)
	add_child(close_timer)
	
	# 设置抽屉区域的鼠标过滤器
	drawer_node.mouse_filter = Control.MOUSE_FILTER_PASS
	drawer_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	drawer_panel.mouse_filter = Control.MOUSE_FILTER_PASS

# 每帧检查鼠标是否在抽屉区域内
func _process(_delta: float) -> void:
	_check_mouse_in_drawer_area()

# 检查鼠标是否在抽屉区域内
func _check_mouse_in_drawer_area() -> void:
	if not is_instance_valid(drawer_node):
		return
		
	var mouse_pos = drawer_node.get_global_mouse_position()
	var drawer_rect = drawer_node.get_global_rect()
	var was_in_area = is_mouse_in_drawer_area
	is_mouse_in_drawer_area = drawer_rect.has_point(mouse_pos)
	
	# 鼠标进入抽屉区域
	if is_mouse_in_drawer_area and not was_in_area:
		_on_mouse_enter_drawer()
	# 鼠标离开抽屉区域
	elif not is_mouse_in_drawer_area and was_in_area:
		_on_mouse_exit_drawer()

# 抽屉手柄点击事件
func _on_drawer_handle_clicked() -> void:
	if drawer_opened:
		_close_drawer()
	else:
		_open_drawer()

# 鼠标进入抽屉区域
func _on_mouse_enter_drawer() -> void:
	# 如果抽屉已打开，停止关闭定时器
	if drawer_opened and close_timer.time_left > 0:
		close_timer.stop()

# 鼠标离开抽屉区域
func _on_mouse_exit_drawer() -> void:
	# 如果抽屉已打开，启动关闭定时器
	if drawer_opened:
		close_timer.start()

# 关闭定时器超时，关闭抽屉
func _on_close_timer_timeout() -> void:
	if drawer_opened and not is_mouse_in_drawer_area:
		_close_drawer()

func _apply_drawer_state() -> void:
	# 在容器布局下，使用 DrawerPanel 与父节点的最小高度实现抽拉
	if drawer_tween and drawer_tween.is_running():
		drawer_tween.kill()
	var target_h: float = 0.0 if not drawer_opened else DRAWER_EXPANDED_HEIGHT
	# 面板本身高度
	drawer_panel.custom_minimum_size = Vector2(drawer_panel.custom_minimum_size.x, target_h)
	# 父抽屉节点总高度 = 手柄高度 + 面板高度
	var total_h: float = _get_drawer_handle_height() + target_h
	drawer_node.custom_minimum_size = Vector2(drawer_node.custom_minimum_size.x, total_h)
	# 可见性
	drawer_panel.visible = drawer_opened

func _open_drawer() -> void:
	if drawer_opened:
		return
	drawer_opened = true
	if drawer_tween and drawer_tween.is_running():
		drawer_tween.kill()
	drawer_tween = get_tree().create_tween()
	var from_h: float = drawer_panel.custom_minimum_size.y
	var to_h: float = DRAWER_EXPANDED_HEIGHT
	# 先显示面板
	drawer_panel.visible = true
	# 同步动画：面板高度和父抽屉总高度
	drawer_tween.tween_property(drawer_panel, "custom_minimum_size:y", to_h, 0.20).from(from_h)
	var from_total: float = drawer_node.custom_minimum_size.y
	var to_total: float = _get_drawer_handle_height() + to_h
	drawer_tween.tween_property(drawer_node, "custom_minimum_size:y", to_total, 0.20).from(from_total)

func _close_drawer() -> void:
	if not drawer_opened:
		return
	drawer_opened = false
	if drawer_tween and drawer_tween.is_running():
		drawer_tween.kill()
	drawer_tween = get_tree().create_tween()
	var from_h: float = drawer_panel.custom_minimum_size.y
	var to_h: float = 0.0
	# 同步动画：面板高度和父抽屉总高度
	drawer_tween.tween_property(drawer_panel, "custom_minimum_size:y", to_h, 0.20).from(from_h)
	var from_total: float = drawer_node.custom_minimum_size.y
	var to_total: float = _get_drawer_handle_height() + to_h
	drawer_tween.tween_property(drawer_node, "custom_minimum_size:y", to_total, 0.20).from(from_total)
	# 动画完成后隐藏面板
	drawer_tween.finished.connect(func():
		if not drawer_opened:
			drawer_panel.visible = false
	)

# 读取抽屉手柄的高度（最小高度为 36）
func _get_drawer_handle_height() -> float:
	var h := drawer_handle.get_combined_minimum_size().y
	if h <= 0.0:
		return 36.0
	return h

func _cache_pool_nodes() -> void:
	"""缓存各卡池页签的 GachaIcon 映射"""
	if not is_instance_valid(left_tabs):
		return
	
	pool_to_icon.clear()
	for i in range(left_tabs.get_tab_count()):
		var tab_control = left_tabs.get_tab_control(i)
		if tab_control == null:
			continue
		var tab_name = tab_control.name
		# 查找该页签下的 GachaIcon
		var gacha_icon = tab_control.get_node_or_null("GachaIcon")
		if gacha_icon and gacha_icon is TextureRect:
			# 根据页签名称映射到对应的池名
			var pool_name = ""
			if tab_name.begins_with("Pool_"):
				pool_name = tab_name.substr(5)  # 去掉 "Pool_" 前缀
			elif tab_name == "MyCardsTab":
				continue  # 跳过我的卡片页签
			else:
				pool_name = tab_name
			
			if not pool_name.is_empty():
				pool_to_icon[pool_name] = gacha_icon

func _on_left_tabs_tab_changed(tab_index: int) -> void:
	"""TabContainer 页签切换事件"""
	if not is_instance_valid(left_tabs):
		return
	
	var tab_control = left_tabs.get_tab_control(tab_index)
	if tab_control == null:
		return
	
	var tab_name = tab_control.name
	if tab_name == "MyCardsTab":
		selected_pool = ""
		return
	
	# 如果是卡池页签，设置选中的卡池并绑定抽卡按钮
	if tab_name.begins_with("Pool_"):
		var pool_name = tab_name.substr(5)  # 去掉 "Pool_" 前缀
		selected_pool = pool_name
		
		# 查找该页签下的抽卡按钮并绑定事件
		var draw_button = tab_control.get_node_or_null("DrawButton")
		if draw_button and draw_button is Button:
			# 先断开之前的连接
			if draw_button.pressed.is_connected(_on_draw_button_pressed):
				draw_button.pressed.disconnect(_on_draw_button_pressed)
			# 重新连接
			draw_button.pressed.connect(_on_draw_button_pressed)
		
		# 初始化该页签的图标动画
		var gacha_icon = pool_to_icon.get(pool_name, null)
		if gacha_icon:
			_init_gacha_icon_animation_for(gacha_icon)

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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	we.environment = env
	world_root.add_child(we)

func _ensure_user_recipes_dir() -> void:
	var d := DirAccess.open("user://")
	if d:
		d.make_dir_recursive("recipes")

# 基于所选卡牌名称拼接文件名，附带 task_id 防重，清洗非法字符
func _build_recipe_base_filename(cards: Array[Dictionary], task_id: String) -> String:
	var names: Array[String] = []
	for c in cards:
		var n: String = str(c.get("name", ""))
		if n.is_empty():
			continue
		n = _sanitize_filename(n)
		if not n.is_empty():
			names.append(n)
	var joined := "+".join(names)
	if joined.is_empty():
		joined = "recipe"
	return joined + "_" + task_id

func _sanitize_filename(s: String) -> String:
	# 去除路径分隔、非法字符，替换空白为下划线，限制长度
	var t := s
	var bad := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	for ch in bad:
		t = t.replace(ch, "")
	# 将空格与多余空白变为 '_'
	t = t.strip_edges()
	t = t.replace(" ", "_")
	# 仅保留常见可见字符
	var cleaned := ""
	for i in t.length():
		var code := t.unicode_at(i)
		if code >= 33 and code <= 126:
			cleaned += char(code)
	# 截断以避免超长路径
	if cleaned.length() > 80:
		cleaned = cleaned.substr(0, 80)
	return cleaned

func _rebuild_tabs_bar() -> void:
	if not is_instance_valid(tabs_bar):
		tabs_bar = get_node_or_null("%s" % "MainContainer/ContentArea/LeftPanel/InfoView/TabsBar")
	if not is_instance_valid(tabs_bar):
		return
	# 清空旧
	for c in tabs_bar.get_children():
		c.queue_free()
	# 我的卡片按钮
	var btn_my := Button.new()
	btn_my.text = "我的卡片"
	_safe_connect_button_pressed(btn_my, _show_my_cards_view)
	tabs_bar.add_child(btn_my)
	# 卡池按钮
	for key in pool_key_to_title.keys():
		var btn := Button.new()
		btn.text = pool_key_to_title[key]
		_safe_connect_button_pressed(btn, func(): _show_pool_view(pool_key_to_title[key]))
		tabs_bar.add_child(btn)

func _show_pool_view(pool_name: String) -> void:
	"""切换到指定卡池页签"""
	if not is_instance_valid(left_tabs):
		return
	
	# 查找对应的页签索引
	for i in range(left_tabs.get_tab_count()):
		var tab_control = left_tabs.get_tab_control(i)
		if tab_control == null:
			continue
		var tab_name = tab_control.name
		if tab_name.begins_with("Pool_") and tab_name.substr(5) == pool_name:
			left_tabs.current_tab = i
			break

func _show_my_cards_view() -> void:
	"""切换到我的卡片页签"""
	if is_instance_valid(left_tabs):
		left_tabs.current_tab = 0

func _init_gacha_icon_animation_for(icon: TextureRect) -> void:
	if icon == null:
		return
	# 资源：Assets/Art/GachaIcons/icon.png（正方形显示）
	var icon_path := "res://Assets/Art/GachaIcons/icon.png"
	if ResourceLoader.exists(icon_path):
		var tex := load(icon_path)
		if tex and tex is Texture2D:
			icon.texture = tex
	# 方形显示设置
	icon.custom_minimum_size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 循环轻微动画
	var tween := get_tree().create_tween()
	tween.set_loops()
	tween.tween_property(icon, "scale", Vector2(1.06, 1.06), 0.8).from(Vector2(1, 1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(icon, "rotation_degrees", 6.0, 0.8).from(-6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_gacha_icon_anim(pool_name: String) -> void:
	var icon: TextureRect = pool_to_icon.get(pool_name, null)
	if icon == null:
		return
	# 点击抽卡时一次弹跳
	var bounce := get_tree().create_tween()
	bounce.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.12).from(icon.scale)
	bounce.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.18)

func _select_pool(pool_name: String):
	"""选择卡池"""
	# 兼容旧调用：转到右侧卡池视图
	_show_pool_view(pool_name)


func _on_draw_button_pressed():
	"""抽卡按钮点击"""
	if selected_pool.is_empty():
		status_label.text = "请先选择一个卡池！"
		return
	
	if game_manager.player_currency < 10:  # 假设每次抽卡消耗10金币
		status_label.text = "金币不足！"
		return
	
	game_manager.player_currency -= 10
	_play_gacha_icon_anim(selected_pool)
	var drawn_card = game_manager.draw_card_from_pool(selected_pool)
	
	if not drawn_card.is_empty():
		status_label.text = "抽到卡片：" + drawn_card.name
	
	_update_ui()

func _on_card_drawn(card_data: Dictionary):
	"""处理抽到卡片"""
	_add_card_to_grid(card_data)
	_add_card_to_my_cards(card_data)
	status_label.text = "获得新卡：" + str(card_data.get("name", "未知")) + " → 已加入‘我的卡片’"

func _add_card_to_grid(card_data: Dictionary):
	"""将卡片添加到网格"""
	var card_button = Button.new()
	card_button.text = card_data.name + "\n" + card_data.pool
	card_button.custom_minimum_size = Vector2(120, 80)
	
	# 根据稀有度设置颜色
	var rarity_colors = {
		"common": Color.GRAY,
		"rare": Color.BLUE,
		"epic": Color.PURPLE,
		"legendary": Color.GOLD
	}
	
	var card_obj = CardData.new(card_data)
	var rarity = card_obj.get_rarity_from_attributes()
	card_button.modulate = rarity_colors.get(rarity, Color.WHITE)
	
	# 连接点击事件（安全连接）
	_safe_connect_button_pressed(card_button, func(): _toggle_card_selection(card_data, card_button))
	
	card_grid.add_child(card_button)
	card_buttons.append(card_button)

func _add_card_to_my_cards(card_data: Dictionary) -> void:
	if not is_instance_valid(my_cards_list):
		return
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 占位：使用对应卡池页签的图标作为临时卡面
	var pool_name := str(card_data.get("pool", ""))
	var pool_icon: TextureRect = pool_to_icon.get(pool_name, null)
	if pool_icon and pool_icon.texture:
		icon.texture = pool_icon.texture
	var name_label := Label.new()
	name_label.text = str(card_data.get("name", "未知"))
	row.add_child(icon)
	row.add_child(name_label)
	my_cards_list.add_child(row)

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
	if not is_instance_valid(selected_cards_container):
		selected_cards_container = get_node_or_null("MainContainer/ContentArea/LeftPanel/InfoView/LeftTabs/MyCardsTab/SelectedCards")
	if not is_instance_valid(selected_cards_container):
		return
	for child in selected_cards_container.get_children():
		child.queue_free()
	
	# 添加选中的卡片
	for card in selected_cards:
		var label = Label.new()
		label.text = card.name
		selected_cards_container.add_child(label)
	
	# 更新生成按钮状态
	if is_instance_valid(generate_button):
		generate_button.disabled = selected_cards.is_empty()

func _on_generate_button_pressed():
	"""生成料理按钮点击"""
	if selected_cards.is_empty():
		# 若未选择卡片则自动从已拥有卡片中选取最多5张（按价格降序）
		if game_manager.player_cards.is_empty():
			status_label.text = "请先抽卡！"
			return
		var sorted: Array[Dictionary] = game_manager.player_cards.duplicate()
		sorted.sort_custom(func(a, b): return int(b.get("base_price", 0)) < int(a.get("base_price", 0)))
		selected_cards = sorted.slice(0, min(5, sorted.size()))
		_update_selected_cards_display()
	
	# 计算料理属性
	var recipe_attributes = game_manager.calculate_recipe_attributes(selected_cards)
	
	# 生成Prompt
	var prompt = game_manager.generate_prompt_from_cards(selected_cards)
	
	status_label.text = "正在生成料理：" + prompt
	
	# 调用Tripo API（暂时使用模拟）
	if tripo_api.api_key.is_empty():
		tripo_api.simulate_model_generation(prompt, "recipe_" + str(Time.get_unix_time_from_system()))
	else:
		tripo_api.generate_3d_model_from_text(prompt, "recipe_" + str(Time.get_unix_time_from_system()))

func _on_model_generation_started(task_id: String):
	"""3D模型生成开始"""
	status_label.text = "3D模型生成中，请稍候..."
	if is_instance_valid(generate_button):
		generate_button.disabled = true
	# 立刻展示占位菜品，避免等待期间预览为空
	# 改为等待 Tripo 的预览图或最终模型，不再渲染占位几何体

func _on_model_generation_completed(model_data: Dictionary):
	"""3D模型生成完成"""
	# 基于所选卡牌名称生成文件基名，并组合保存路径
	_ensure_user_recipes_dir()
	var base_filename := _build_recipe_base_filename(selected_cards, model_data.task_id)
	var glb_path := "user://recipes/" + base_filename + ".glb"
	var img_path := "user://recipes/" + base_filename + ".png"

	# 创建料理数据
	var recipe_data = {
		"id": model_data.task_id,
		"name": "美味料理 #" + str(game_manager.player_recipes.size() + 1),
		"ingredients": selected_cards.duplicate(),
		"attributes": game_manager.calculate_recipe_attributes(selected_cards),
		"model_url": model_data.get("model_url", ""),
		"preview_url": model_data.get("preview_url", ""),
		"prompt": model_data.get("prompt", ""),
		"created_at": Time.get_unix_time_from_system(),
		"model_path": glb_path,
		"preview_path": img_path
	}
	
	game_manager.player_recipes.append(recipe_data)
	
	# 添加到料理列表
	_add_recipe_to_list(recipe_data)
	
	# 清空选中的卡片
	selected_cards.clear()
	_update_selected_cards_display()
	
	# 重置按钮状态
	for button in card_buttons:
		button.modulate.a = 1.0
	
	status_label.text = "料理生成成功：" + recipe_data.name
	if is_instance_valid(generate_button):
		generate_button.disabled = false

	# 优先尝试渲染真实模型
	var glb_url: String = _extract_model_url(model_data)
	if glb_url.is_empty():
		# 没有拿到模型地址则使用占位几何体
		_render_placeholder_dish(recipe_data)
	else:
		# 使用基于卡牌名生成的路径保存并渲染
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
		_download_and_show_image(preview_url, img_path)

func _on_model_generation_failed(error_message: String):
	"""3D模型生成失败"""
	status_label.text = "料理生成失败：" + error_message
	if is_instance_valid(generate_button):
		generate_button.disabled = false

func _on_model_preview_updated(url: String) -> void:
	# 中间态预览图显示
	if typeof(url) == TYPE_STRING and not url.is_empty():
		_load_image_from_url(url)

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
	
	var price_label = Label.new()
	var final_price = int(attributes.base_price * attributes.trend_bonus)
	price_label.text = "售价: " + str(final_price) + " 金币"
	price_label.add_theme_font_size_override("font_size", 12)
	
	recipe_container.add_child(name_label)
	recipe_container.add_child(attr_label)
	recipe_container.add_child(price_label)
	
	# 添加分隔线
	var separator = HSeparator.new()
	recipe_container.add_child(separator)
	
	recipe_list.add_child(recipe_container)

func _update_ui():
	"""更新UI显示"""
	currency_label.text = "金币: " + str(game_manager.player_currency)
	
	if not game_manager.current_trends.is_empty():
		trend_label.text = "当前潮流: " + game_manager.current_trends[0]
	
	# 玩家信息
	nickname_label.text = game_manager.player_name
	level_label.text = "Lv." + str(game_manager.player_level)
	exp_bar.value = game_manager.player_exp
	exp_bar.max_value = game_manager.player_exp_to_next
	daily_free_label.text = "今日免费: " + str(game_manager.daily_free_draws) + " 次"

func _tick_ui():
	# 潮流倒计时刷新与轮换
	game_manager.maybe_rotate_trend()
	var remain = max(0, game_manager.get_trend_remaining_seconds())
	var m = int(remain / 60)
	var s = remain % 60
	trend_label.text = "当前潮流: " + (game_manager.current_trends[0] if not game_manager.current_trends.is_empty() else "无") + "  剩余 %02d:%02d" % [m, s]
	# 玩家经验条显示随时更新
	level_label.text = "Lv." + str(game_manager.player_level)
	exp_bar.value = game_manager.player_exp
	exp_bar.max_value = game_manager.player_exp_to_next

func _render_placeholder_dish(recipe_data: Dictionary) -> void:
	"""根据属性在预览中生成占位几何体（方块/球）"""
	if not is_instance_valid(dish_root):
		return
	# 清空旧节点
	if not is_instance_valid(dish_root):
		return
	for child in dish_root.get_children():
		child.queue_free()

	var attributes: Dictionary = recipe_data.get("attributes", {})
	var spice: int = attributes.get("spice", 0)
	var sweet: int = attributes.get("sweet", 0)
	var weird: int = attributes.get("weird", 0)

	# 规则：
	# - 辣度 -> 红色强度，方块数量
	# - 甜度 -> 粉/黄配色与球体数量
	# - 奇异度 -> 随机旋转与缩放幅度

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# 生成底盘（一个大圆柱当盘子）
	var plate_mesh = CylinderMesh.new()
	plate_mesh.top_radius = 2.8
	plate_mesh.bottom_radius = 2.8
	plate_mesh.height = 0.2
	plate_mesh.radial_segments = 32
	var plate_inst = MeshInstance3D.new()
	plate_inst.mesh = plate_mesh
	plate_inst.position = Vector3(0, 0.0, 0)
	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.9, 0.9, 0.95)
	plate_inst.set_surface_override_material(0, plate_mat)
	dish_root.add_child(plate_inst)

	# 创建旋转容器
	var rotating_container = Node3D.new()
	rotating_container.name = "RotatingContainer"
	dish_root.add_child(rotating_container)
	
	# 添加旋转动画
	var tween = get_tree().create_tween()
	tween.set_loops()
	tween.tween_method(func(angle): rotating_container.rotation.y = angle, 0.0, TAU, 8.0)

	# 辣度：生成若干方块
	var cube_count = max(1, spice)
	for i in range(cube_count):
		var cube = MeshInstance3D.new()
		cube.mesh = BoxMesh.new()
		cube.position = Vector3(rng.randf_range(-1.0, 1.0), 0.10 + rng.randf_range(-0.05, 0.05), rng.randf_range(-1.0, 1.0))
		cube.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU)) * (0.2 + weird * 0.02)
		cube.scale = Vector3.ONE * (0.3 + rng.randf_range(-0.1, 0.2))
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6 + 0.08 * spice, 0.15, 0.1)
		cube.set_surface_override_material(0, mat)
		rotating_container.add_child(cube)

	# 甜度：生成若干球体
	var sphere_count = max(1, sweet)
	for j in range(sphere_count):
		var sphere = MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		sphere.position = Vector3(rng.randf_range(-1.2, 1.2), 0.15 + rng.randf_range(-0.05, 0.05), rng.randf_range(-1.2, 1.2))
		sphere.scale = Vector3.ONE * (0.25 + rng.randf_range(-0.08, 0.15))
		var smat = StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.7 + 0.05 * sweet, 0.8)
		smat.metalness = 0.0
		smat.roughness = 0.2
		sphere.set_surface_override_material(0, smat)
		rotating_container.add_child(sphere)

	# 奇异度：添加若干细长胶囊做“装饰”
	var deco_count = clampi(weird / 2, 0, 6)
	for k in range(deco_count):
		var capsule = MeshInstance3D.new()
		var cap = CapsuleMesh.new()
		cap.radius = 0.06
		cap.height = 0.8 + rng.randf_range(-0.2, 0.3)
		capsule.mesh = cap
		capsule.position = Vector3(rng.randf_range(-1.5, 1.5), 0.20 + rng.randf_range(-0.05, 0.2), rng.randf_range(-1.5, 1.5))
		capsule.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		var dmat = StandardMaterial3D.new()
		dmat.albedo_color = Color(0.3, 0.8, 1.0, 1.0)
		dmat.emission_enabled = true
		dmat.emission = Color(0.1, 0.5, 1.0)
		dmat.emission_energy_multiplier = 0.5 + weird * 0.05
		capsule.set_surface_override_material(0, dmat)
		rotating_container.add_child(capsule)

	# 轻微镜头抖动以显示变化
	var cam: Camera3D = preview_viewport.get_node("WorldRoot/Camera3D")
	if cam:
		cam.position = Vector3(3.5, 2.5, 5.0)
		cam.look_at(Vector3(0, 0.15, 0), Vector3.UP)

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
				image_preview.texture = tex
				if save_path != "":
					_ensure_user_recipes_dir()
					img.save_png(save_path)
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
	if not is_instance_valid(dish_root):
		return
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
	# 创建一个局部容器，方便位移与缩放
	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	parent_container.add_child(pivot)
	model_root.reparent(pivot)

	# 计算合并 AABB（基于 MeshInstance3D）
	var aabb := _compute_combined_aabb(model_root)
	if aabb.size == Vector3.ZERO:
		return
	var center := aabb.position + aabb.size * 0.5

	# 将模型中心对齐到 (0, desired_height, 0)
	var desired_height: float = 0.15
	# 平移 pivot 使得模型在场景原点居中且略高于盘面
	pivot.position = Vector3(-center.x, -center.y + desired_height, -center.z)

	# 自适应缩放：目标半径
	var radius: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) * 0.5
	if radius <= 0.0001:
		return
	var target_radius: float = 1.6
	var scale_factor: float = target_radius / radius
	pivot.scale = Vector3.ONE * scale_factor

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
	var distance: float = max(3.0, radius * 3.0)
	cam.position = Vector3(distance * 0.7, distance * 0.5, distance)
	cam.look_at(Vector3(0, 0.15, 0), Vector3.UP)
	cam.fov = 55.0
