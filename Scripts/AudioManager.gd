extends Node

# 音频管理器
class_name AudioController

# 音频播放器
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# 音量设置
var music_volume: float = 0.1
var sfx_volume: float = 0.5
var music_enabled: bool = true
var sfx_enabled: bool = true

func _ready():
	# 初始化音频播放器
	_setup_audio_players()

func _setup_audio_players():
	# 音乐播放器
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	
	# 音效播放器
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.volume_db = linear_to_db(sfx_volume)
	add_child(sfx_player)

func play_music(stream: AudioStream, loop: bool = true):
	if not music_enabled or not stream:
		return
	
	music_player.stream = stream
	music_player.play()
	
	if loop:
		music_player.finished.connect(func(): music_player.play(), CONNECT_ONE_SHOT)

func play_sfx(stream: AudioStream):
	if not sfx_enabled or not stream:
		return
	
	sfx_player.stream = stream
	sfx_player.play()

func stop_music():
	music_player.stop()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_player.volume_db = linear_to_db(sfx_volume)

func toggle_music():
	music_enabled = !music_enabled
	if not music_enabled:
		stop_music()

func toggle_sfx():
	sfx_enabled = !sfx_enabled
