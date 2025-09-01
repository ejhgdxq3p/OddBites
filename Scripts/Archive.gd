extends Control

@onready var back_button: Button = $MainContainer/LeftPanel/BackButton
@onready var refresh_button: Button = $MainContainer/LeftPanel/Toolbar/RefreshButton
@onready var open_folder_button: Button = $MainContainer/LeftPanel/Toolbar/OpenFolderButton
@onready var thumb_grid: GridContainer = $MainContainer/LeftPanel/Scroll/ThumbGrid
@onready var preview_viewport: SubViewport = $MainContainer/RightPanel/PreviewContainer/PreviewViewport
@onready var dish_root: Node3D = $MainContainer/RightPanel/PreviewContainer/PreviewViewport/WorldRoot/DishRoot
@onready var model_name_label: Label = $MainContainer/RightPanel/InfoPanel/ModelName

func _ready() -> void:
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	)
	refresh_button.pressed.connect(_refresh_thumbs)
	open_folder_button.pressed.connect(_open_user_folder)
	
	# 设置3D预览环境
	preview_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_ensure_preview_environment()
	
	_refresh_thumbs()

func _refresh_thumbs() -> void:
	# 清空
	for child in thumb_grid.get_children():
		child.queue_free()
	# 遍历 user://recipes 下的 png 作为缩略图
	var dir := DirAccess.open("user://recipes")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			var thumb := _create_thumb_item("user://recipes/" + file_name)
			thumb_grid.add_child(thumb)
		file_name = dir.get_next()
	dir.list_dir_end()

func _create_thumb_item(img_path: String) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(140, 140)
	
	# 创建缩略图按钮
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 90)
	button.flat = true
	
	# 加载图片并设置为按钮图标
	var img := Image.new()
	var err := img.load(img_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(img)
		button.icon = tex
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.expand_icon = true
	else:
		button.text = "无预览图"
	
	var label := Label.new()
	label.text = img_path.get_file().get_basename()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)

	# 点击加载3D模型
	button.pressed.connect(func():
		var base := img_path.substr(0, img_path.length() - 4)
		var glb_path := base + ".glb"
		_load_3d_model(glb_path, img_path.get_file().get_basename())
	)

	vb.add_child(button)
	vb.add_child(label)
	return vb

func _open_user_folder() -> void:
	var p := ProjectSettings.globalize_path("user://recipes")
	OS.shell_open(p)

func _open_in_os_folder(path: String) -> void:
	var p := ProjectSettings.globalize_path(path)
	OS.shell_open(p.get_base_dir())

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

func _load_3d_model(glb_path: String, model_name: String) -> void:
	# 清空现有模型
	for child in dish_root.get_children():
		child.queue_free()
	
	model_name_label.text = "加载中: " + model_name
	
	if not FileAccess.file_exists(glb_path):
		model_name_label.text = "模型文件不存在: " + model_name
		return
	
	# 加载GLB文件
	var file := FileAccess.open(glb_path, FileAccess.READ)
	if not file:
		model_name_label.text = "无法打开文件: " + model_name
		return
	
	var buffer := file.get_buffer(file.get_length())
	file.close()
	
	var instantiated_root: Node3D = null
	
	# 使用GLTFDocument解析
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_buffer(buffer, "", state)
	if err == OK:
		var generated := gltf.generate_scene(state)
		if generated and generated is Node3D:
			instantiated_root = generated
	
	if instantiated_root != null:
		# 创建旋转容器
		var rotating_container := Node3D.new()
		rotating_container.name = "RotatingModel"
		dish_root.add_child(rotating_container)
		rotating_container.add_child(instantiated_root)
		
		# 自适应居中与缩放
		_fit_and_center_model(rotating_container, instantiated_root)
		_adjust_preview_camera_to_fit(rotating_container)
		
		# 旋转动效
		var tween := get_tree().create_tween()
		tween.set_loops()
		tween.tween_property(rotating_container, "rotation:y", TAU, 8.0).from(0.0)
		
		model_name_label.text = model_name
	else:
		model_name_label.text = "加载失败: " + model_name

# 以下函数复制自MainGame.gd，用于模型适配
func _fit_and_center_model(parent_container: Node3D, model_root: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	parent_container.add_child(pivot)
	model_root.reparent(pivot)

	var aabb := _compute_combined_aabb(model_root)
	if aabb.size == Vector3.ZERO:
		return
	var center := aabb.position + aabb.size * 0.5

	var desired_height: float = 0.15
	pivot.position = Vector3(-center.x, -center.y + desired_height, -center.z)

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

func _adjust_preview_camera_to_fit(container: Node3D) -> void:
	var cam: Camera3D = preview_viewport.get_node("WorldRoot/Camera3D")
	if not cam:
		return
	var aabb := _compute_combined_aabb(container)
	if aabb.size == Vector3.ZERO:
		return
	var radius: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) * 0.5
	var distance: float = max(3.0, radius * 3.0)
	cam.position = Vector3(distance * 0.7, distance * 0.5, distance)
	cam.look_at(Vector3(0, 0.15, 0), Vector3.UP)
	cam.fov = 55.0

