extends Control

# 预加载
const OddBitesGameManager = preload("res://Scripts/GameManager.gd")
const AvatarManager = preload("res://Scripts/AvatarManager.gd")

@onready var start_game_button: Button = $CenterContainer/VBoxContainer/StartGameButton
@onready var archive_button: Button = $CenterContainer/VBoxContainer/ArchiveButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var back_to_title_button: Button = $CenterContainer/VBoxContainer/BackToTitleButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var avatar_rect: TextureRect = $PlayerPanel/Avatar
@onready var nickname_label: Label = $PlayerPanel/PlayerInfo/Nickname
@onready var level_label: Label = $PlayerPanel/PlayerInfo/Level

var game_manager: OddBitesGameManager
var avatar_manager: AvatarManager

func _ready() -> void:
	# 初始化管理器
	game_manager = OddBitesGameManager.new()
	avatar_manager = AvatarManager.new()
	add_child(game_manager)
	add_child(avatar_manager)
	
	# 连接头像信号
	avatar_manager.avatar_downloaded.connect(_on_avatar_downloaded)
	avatar_manager.avatar_failed.connect(_on_avatar_failed)
	
	start_game_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scenes/MainGame.tscn")
	)
	archive_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scenes/Archive.tscn")
	)
	settings_button.pressed.connect(func():
		_show_settings_placeholder()
	)
	back_to_title_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scenes/Title.tscn")
	)
	exit_button.pressed.connect(func():
		get_tree().quit()
	)
	
	# 更新玩家信息UI
	_update_player_info()
	# 生成头像
	_generate_player_avatar()
	# 设置头像点击事件
	_setup_avatar_click()

func _show_settings_placeholder() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "音乐设置"
	dlg.dialog_text = "音乐控制"
	dlg.dialog_autowrap = true
	
	# 创建音乐控制容器
	var music_container = VBoxContainer.new()
	music_container.custom_minimum_size = Vector2(300, 150)
	
	# 音乐开关
	var music_check = CheckBox.new()
	music_check.text = "播放音乐"
	music_check.button_pressed = game_manager.get_music_enabled()
	music_check.toggled.connect(func(enabled): game_manager.set_music_enabled(enabled))
	
	# 音量滑块
	var volume_label = Label.new()
	volume_label.text = "音量: " + str(int(game_manager.get_music_volume() * 100)) + "%"
	
	var volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.1
	volume_slider.value = game_manager.get_music_volume()
	volume_slider.value_changed.connect(func(value): 
		game_manager.set_music_volume(value)
		volume_label.text = "音量: " + str(int(value * 100)) + "%"
	)
	
	# 测试播放按钮
	var test_button = Button.new()
	test_button.text = "测试播放"
	test_button.pressed.connect(func():
		if game_manager.music_player and game_manager.music_player.stream:
			print("测试播放音乐...")
			game_manager.music_player.play()
			print("音乐播放状态: ", game_manager.music_player.playing)
		else:
			print("音乐播放器或流不存在！")
	)
	
	# 添加到容器
	music_container.add_child(music_check)
	music_container.add_child(volume_label)
	music_container.add_child(volume_slider)
	music_container.add_child(test_button)
	
	dlg.add_child(music_container)
	add_child(dlg)
	dlg.popup_centered()

func _update_player_info():
	"""更新玩家信息显示"""
	nickname_label.text = game_manager.player_name
	level_label.text = "Lv." + str(game_manager.player_level)

func _generate_player_avatar():
	"""生成玩家头像"""
	avatar_manager.generate_avatar(game_manager.player_avatar_seed)

func _on_avatar_downloaded(texture: Texture2D):
	"""头像下载完成回调"""
	avatar_rect.texture = texture
	print("主菜单头像更新成功")

func _on_avatar_failed(error: String):
	"""头像下载失败回调"""
	print("主菜单头像生成失败: ", error)

func _setup_avatar_click():
	"""设置头像点击事件"""
	if avatar_rect:
		avatar_rect.gui_input.connect(_on_avatar_clicked)

func _on_avatar_clicked(event: InputEvent):
	"""头像点击事件 - 重新生成食物头像"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_manager.regenerate_avatar()
		avatar_manager.generate_food_avatar(game_manager.player_avatar_seed)
