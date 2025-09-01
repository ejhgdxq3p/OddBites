class_name AvatarManager
extends Node

# DiceBear 头像管理器
signal avatar_downloaded(texture: Texture2D)
signal avatar_failed(error: String)

# DiceBear API 配置
const DICEBEAR_BASE_URL = "https://api.dicebear.com/7.x"
const DEFAULT_STYLE = "fun-emoji"  # 改为食物友好的风格
const DEFAULT_SIZE = 128

var cache_dir: String = "user://avatars/"
var cached_avatars: Dictionary = {}

func _ready():
	# 确保缓存目录存在
	_ensure_cache_dir()

func _ensure_cache_dir():
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive("avatars")

func generate_avatar(seed: String = "", style: String = DEFAULT_STYLE, size: int = DEFAULT_SIZE) -> void:
	"""
	生成DiceBear头像
	
	参数:
	- seed: 种子字符串，相同种子生成相同头像。留空则随机生成
	- style: 头像风格 (adventurer, avataaars, big-ears, big-smile等)
	- size: 头像尺寸 (像素)
	"""
	if seed.is_empty():
		seed = _generate_random_seed()
	
	var cache_key = "%s_%s_%d" % [style, seed, size]
	var cache_path = cache_dir + cache_key + ".png"
	
	# 检查缓存
	if FileAccess.file_exists(cache_path):
		print("从缓存加载头像: ", cache_key)
		_load_cached_avatar(cache_path)
		return
	
	# 构建DiceBear URL
	var url = "%s/%s/png?seed=%s&size=%d" % [DICEBEAR_BASE_URL, style, seed, size]
	
	print("请求DiceBear头像: ", url)
	_download_avatar(url, cache_path)

func _generate_random_seed() -> String:
	"""生成随机种子"""
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var seed = ""
	for i in range(12):
		seed += chars[randi() % chars.length()]
	return seed

func _download_avatar(url: String, cache_path: String) -> void:
	"""下载头像并缓存"""
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			# 保存到缓存
			var file = FileAccess.open(cache_path, FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
				print("头像缓存成功: ", cache_path)
			
			# 加载为纹理
			var image = Image.new()
			var error = image.load_png_from_buffer(body)
			if error == OK:
				var texture = ImageTexture.create_from_image(image)
				avatar_downloaded.emit(texture)
				print("头像生成成功")
			else:
				avatar_failed.emit("图像解析失败")
				print("图像解析失败: ", error)
		else:
			avatar_failed.emit("下载失败，状态码: " + str(response_code))
			print("头像下载失败，状态码: ", response_code)
		
		http_request.queue_free()
	)
	
	var error = http_request.request(url)
	if error != OK:
		avatar_failed.emit("请求发送失败")
		http_request.queue_free()

func _load_cached_avatar(cache_path: String) -> void:
	"""从缓存加载头像"""
	var image = Image.new()
	var error = image.load(cache_path)
	if error == OK:
		var texture = ImageTexture.create_from_image(image)
		avatar_downloaded.emit(texture)
	else:
		avatar_failed.emit("缓存加载失败")

func get_available_styles() -> Array[String]:
	"""获取可用的头像风格列表"""
	return [
		"fun-emoji",       # 🍕🍔🍦 食物表情风格（推荐！）
		"adventurer",      # 冒险家风格
		"avataaars",       # 经典卡通风格
		"big-ears",        # 大耳朵风格
		"big-smile",       # 大笑脸风格
		"bottts",          # 机器人风格
		"croodles",        # 涂鸦风格
		"icons",           # 图标风格
		"identicon",       # 身份图标风格
		"initials",        # 首字母风格
		"lorelei",         # 卡通女性风格
		"micah",           # 扁平化风格
		"miniavs",         # 迷你头像风格
		"open-peeps",      # 开放式人物风格
		"personas",        # 人物角色风格
		"pixel-art"        # 像素艺术风格
	]

func get_food_styles() -> Array[String]:
	"""获取食物主题相关的头像风格"""
	return [
		"fun-emoji",       # 🍕🍔🍦 食物表情风格（最推荐！）
		"icons",           # 🍽️ 餐具图标风格
		"pixel-art",       # 🎮 像素食物风格
		"croodles",        # 🎨 涂鸦食物风格
		"bottts"           # 🤖 机器人食物风格
	]

func generate_player_avatar(player_name: String) -> void:
	"""
	为玩家生成食物主题头像，使用玩家名称作为种子
	确保同一玩家名总是生成相同的食物头像
	"""
	generate_food_avatar(player_name)

func generate_random_avatar() -> void:
	"""生成随机头像"""
	generate_avatar("", DEFAULT_STYLE, DEFAULT_SIZE)

func generate_food_avatar(seed: String = "") -> void:
	"""生成食物主题头像"""
	var food_styles = get_food_styles()
	var random_style = food_styles[randi() % food_styles.size()]
	generate_avatar(seed, random_style, DEFAULT_SIZE)

func generate_random_food_avatar() -> void:
	"""生成随机食物头像"""
	generate_food_avatar("")

func clear_cache() -> void:
	"""清除头像缓存"""
	var dir = DirAccess.open(cache_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				dir.remove(file_name)
				print("删除缓存文件: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		print("头像缓存已清空")
