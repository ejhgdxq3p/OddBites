extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var preview_viewport: SubViewport = $PreviewOverlay/PreviewViewport
@onready var world_root: Node3D = $PreviewOverlay/PreviewViewport/WorldRoot

var rotation_tween: Tween
var game_manager: Node

func _ready() -> void:
	# 初始化游戏管理器并开始播放音乐
	var OddBitesGameManagerClass = load("res://Scripts/GameManager.gd")
	game_manager = OddBitesGameManagerClass.new()
	add_child(game_manager)
	
	# 在标题页播放音乐
	if game_manager.has_method("play_title_music"):
		game_manager.play_title_music()
	
	start_button.pressed.connect(func():
		# 停止旋转动画避免访问已销毁的节点
		if rotation_tween:
			rotation_tween.kill()
		# 停止音乐播放
		if game_manager.has_method("stop_music"):
			game_manager.stop_music()
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	)
	quit_button.pressed.connect(func():
		get_tree().quit()
	)
	# 透明背景 & 环境
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_ensure_preview_environment()
	# 随机挑选一个本地 GLB 展示
	_show_random_cover_model()

func _ensure_preview_environment() -> void:
	var existing := world_root.get_node_or_null("WorldEnvironment")
	if existing: return
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0,0,0,0)
	we.environment = env
	world_root.add_child(we)

func _show_random_cover_model() -> void:
	var dir := DirAccess.open("user://recipes")
	if dir == null:
		return
	dir.list_dir_begin()
	var glbs: Array[String] = []
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".glb"):
			glbs.append("user://recipes/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	if glbs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick := glbs[rng.randi_range(0, glbs.size() - 1)]
	_load_and_spin_model(pick)

func _load_and_spin_model(glb_path: String) -> void:
	# 清空
	for c in world_root.get_children():
		if c.name != "DirectionalLight3D" and c.name != "Camera3D" and c.name != "WorldEnvironment":
			c.queue_free()

	if not FileAccess.file_exists(glb_path):
		return
	var f := FileAccess.open(glb_path, FileAccess.READ)
	if not f:
		return
	var buf := f.get_buffer(f.get_length())
	f.close()
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var perr := gltf.append_from_buffer(buf, "", state)
	if perr != OK:
		return
	var generated := gltf.generate_scene(state)
	if not generated or not (generated is Node3D):
		return
	var model_root: Node3D = generated
	var container := Node3D.new()
	container.name = "CoverModel"
	world_root.add_child(container)
	container.add_child(model_root)
	# 自适应居中与缩放（内部创建 ModelPivot）
	_fit_and_center_model(container, model_root)
	# 移动到更左边，让模型只展示很少一部分
	container.position += Vector3(-14.0, 2.0, 0.0)
	# 相机固定看向世界原点
	_adjust_camera_for_top_left()
	# 视轴自转：外层对准相机，内层+Y朝向相机，外层绕视轴持续旋转
	var pivot := container.get_node_or_null("ModelPivot")
	if pivot and pivot is Node3D:
		var axis := Node3D.new()
		axis.name = "AxisPivot"
		container.add_child(axis)
		pivot.reparent(axis)
		# 对齐外层到相机方向
		var cam: Camera3D = preview_viewport.get_node("WorldRoot/Camera3D")
		if cam:
			axis.look_at(cam.global_transform.origin, Vector3.UP)
		# 让模型 +Y 指向相机方向的反向（-Z）：菜面朝向玩家
		pivot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		# 持续绕视轴（Z）旋转，永不停止
		rotation_tween = get_tree().create_tween()
		rotation_tween.set_loops()
		rotation_tween.tween_method(func(angle): axis.rotation.z = angle, 0.0, TAU, 8.0)

func _fit_and_center_model(parent_container: Node3D, model_root: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	parent_container.add_child(pivot)
	model_root.reparent(pivot)
	var aabb: AABB = _compute_combined_aabb(model_root)
	if aabb.size == Vector3.ZERO:
		return
	var center: Vector3 = aabb.position + aabb.size * 0.5
	pivot.position = Vector3(-center.x, -center.y + 0.15, -center.z)
	var radius: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) * 0.5
	if radius <= 0.0001:
		return
	# 放大很多，让模型变得更大
	var target_radius: float = 3.0
	pivot.scale = Vector3.ONE * (target_radius / radius)

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

func _adjust_camera_for_top_left() -> void:
	var cam: Camera3D = preview_viewport.get_node("WorldRoot/Camera3D")
	if not cam:
		return
	# 调整相机以适应更大的模型和左边展示
	var distance: float = 10.0
	cam.position = Vector3(distance * 0.8, distance * 1.0, distance * 1.2)
	cam.look_at(Vector3(-3.0, 0.0, 0), Vector3.UP)  # 看向左边偏移位置
	cam.fov = 55.0
