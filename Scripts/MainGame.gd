extends Control

# 预加载以确保类型在解析期可用
const GameManager = preload("res://Scripts/GameManager.gd")
const TripoAPI = preload("res://Scripts/TripoAPI.gd")

# 主游戏界面控制器
@onready var game_manager = GameManager.new()
@onready var tripo_api = TripoAPI.new()

# UI 引用
@onready var currency_label = $MainContainer/Header/Currency
@onready var trend_label = $MainContainer/Header/TrendInfo
@onready var nickname_label = $MainContainer/PlayerPanel/PlayerInfo/Nickname
@onready var level_label = $MainContainer/PlayerPanel/PlayerInfo/LevelBox/Level
@onready var exp_bar = $MainContainer/PlayerPanel/PlayerInfo/LevelBox/ExpBar
@onready var daily_free_label = $MainContainer/PlayerPanel/DailyFreeDraws
@onready var pool_buttons_container = $MainContainer/ContentArea/LeftPanel/PoolButtons
@onready var draw_button = $MainContainer/ContentArea/LeftPanel/DrawButton
@onready var card_grid = $MainContainer/ContentArea/CenterPanel/CardGrid
@onready var selected_cards_container = $MainContainer/ContentArea/CenterPanel/SelectedCards
@onready var generate_button = $MainContainer/ContentArea/CenterPanel/GenerateButton
@onready var recipe_list = $MainContainer/ContentArea/RightPanel/RecipesArea/RecipeList
@onready var status_label = $MainContainer/StatusPanel/StatusLabel
@onready var preview_viewport: SubViewport = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport
@onready var dish_root: Node3D = $MainContainer/ContentArea/RightPanel/PreviewArea/PreviewContainer/PreviewViewport/WorldRoot/DishRoot
@onready var image_preview: TextureRect = $MainContainer/ContentArea/RightPanel/PreviewArea/ImagePreview

var selected_pool: String = ""
var selected_cards: Array[Dictionary] = []
var card_buttons: Array[Button] = []

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
	
	# 连接按钮信号
	draw_button.pressed.connect(_on_draw_button_pressed)
	generate_button.pressed.connect(_on_generate_button_pressed)
	
	# 初始化UI
	_setup_pool_buttons()
	_update_ui()
	# 确保“生成料理”按钮可点击
	generate_button.disabled = false

	# 定时刷新UI（潮流倒计时/经验）
	var ui_timer := Timer.new()
	ui_timer.wait_time = 1.0
	ui_timer.timeout.connect(_tick_ui)
	add_child(ui_timer)
	ui_timer.start()
	
	status_label.text = "游戏初始化完成！选择卡池开始抽卡"

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

func _on_draw_button_pressed():
	"""抽卡按钮点击"""
	if selected_pool.is_empty():
		status_label.text = "请先选择一个卡池！"
		return
	
	if game_manager.player_currency < 10:  # 假设每次抽卡消耗10金币
		status_label.text = "金币不足！"
		return
	
	game_manager.player_currency -= 10
	var drawn_card = game_manager.draw_card_from_pool(selected_pool)
	
	if not drawn_card.is_empty():
		status_label.text = "抽到卡片：" + drawn_card.name
	
	_update_ui()

func _on_card_drawn(card_data: Dictionary):
	"""处理抽到卡片"""
	_add_card_to_grid(card_data)

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
	
	# 连接点击事件
	card_button.pressed.connect(func(): _toggle_card_selection(card_data, card_button))
	
	card_grid.add_child(card_button)
	card_buttons.append(card_button)

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
	generate_button.disabled = true
	# 立刻展示占位菜品，避免等待期间预览为空
	# 改为等待 Tripo 的预览图或最终模型，不再渲染占位几何体

func _on_model_generation_completed(model_data: Dictionary):
	"""3D模型生成完成"""
	# 创建料理数据
	var recipe_data = {
		"id": model_data.task_id,
		"name": "美味料理 #" + str(game_manager.player_recipes.size() + 1),
		"ingredients": selected_cards.duplicate(),
		"attributes": game_manager.calculate_recipe_attributes(selected_cards),
		"model_url": model_data.get("model_url", ""),
		"preview_url": model_data.get("preview_url", ""),
		"prompt": model_data.get("prompt", ""),
		"created_at": Time.get_unix_time_from_system()
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
	generate_button.disabled = false

	# 优先尝试渲染真实模型
	var glb_url: String = _extract_model_url(model_data)
	if glb_url.is_empty():
		# 没有拿到模型地址则使用占位几何体
		_render_placeholder_dish(recipe_data)
	else:
		_render_tripo_model(glb_url)

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
		_load_image_from_url(preview_url)

func _on_model_generation_failed(error_message: String):
	"""3D模型生成失败"""
	status_label.text = "料理生成失败：" + error_message
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
func _render_tripo_model(glb_url: String) -> void:
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
				var tmp_path := "user://temp_tripo_model.glb"
				var f := FileAccess.open(tmp_path, FileAccess.WRITE)
				if f:
					f.store_buffer(body)
					f.close()
					var scene := ResourceLoader.load(tmp_path)
					if scene and scene is PackedScene:
						var inst := (scene as PackedScene).instantiate()
						if inst and inst is Node3D:
							instantiated_root = inst

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
