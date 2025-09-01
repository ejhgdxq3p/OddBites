extends VBoxContainer

@onready var anim_container: Control = $PoolAnimContainer

var card_texture: Texture2D
const CARD_COUNT: int = 5

func _ready() -> void:
	# 占位美术资源
	card_texture = load("res://Assets/Art/GachaIcons/Picture12.png")
	if not card_texture:
		push_warning("占位图未找到: res://Assets/Art/GachaIcons/Picture12.png")

func play_showcase(pool_name: String = "") -> void:
	# 清空旧动画
	for c in anim_container.get_children():
		c.queue_free()

	if not card_texture:
		return

	var size: Vector2 = anim_container.size
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
	var start_pos: Vector2 = Vector2(size.x + 120.0, 20.0) # 右上角外侧
	var target_radius: float = min(size.x, size.y) * 0.28
	var angle_start: float = -0.5
	var angle_step: float = 0.25

	for i in range(CARD_COUNT):
		var card: TextureRect = TextureRect.new()
		card.texture = card_texture
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		card.custom_minimum_size = Vector2(160, 220)
		card.modulate = Color(1,1,1,0)
		card.position = start_pos
		card.scale = Vector2(0.6, 0.6)
		card.rotation = -0.2
		anim_container.add_child(card)

		# 目标位置按圆弧摊开
		var ang: float = angle_start + float(i) * angle_step
		var target: Vector2 = center + Vector2(cos(ang), sin(ang)) * target_radius

		# 卡片飞入与放大
		var t: Tween = get_tree().create_tween()
		t.set_parallel(true)
		t.set_trans(Tween.TRANS_BACK)
		t.set_ease(Tween.EASE_OUT)
		t.tween_property(card, "position", target, 0.45).from(start_pos).set_delay(i * 0.06)
		t.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35).from(card.scale).set_delay(i * 0.06)
		t.tween_property(card, "rotation", ang * 0.3, 0.35).from(card.rotation).set_delay(i * 0.06)
		t.tween_property(card, "modulate:a", 1.0, 0.25).from(0.0).set_delay(i * 0.06)

		# 轻微呼吸发光效果
		var glow: Tween = get_tree().create_tween()
		glow.set_loops()
		glow.tween_property(card, "modulate", Color(1.05,1.05,1.05,1.0), 0.8).from(Color(1,1,1,1)).set_delay(0.5 + i*0.05)
		glow.tween_property(card, "scale", Vector2(1.03,1.03), 0.8).from(Vector2(1,1))

func clear_showcase() -> void:
	for c in anim_container.get_children():
		c.queue_free()
