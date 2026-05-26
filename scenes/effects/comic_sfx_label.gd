## res://scenes/effects/comic_sfx_label.gd
## 模块: ComicSFXLabel
## 职责: 单个漫画拟声词显示节点
## 依赖: ComicSFXData
## 被依赖: FeedbackManager

extends Label

var _data: Dictionary = {}
var _start_pos: Vector2 = Vector2.ZERO
var _tween: Tween = null

func setup(sfx_type: ComicSFXData.SFXType, position: Vector2, direction: Vector2 = Vector2.UP) -> void:
	_data = ComicSFXData.get_sfx_data(sfx_type)
	
	text = ComicSFXData.get_random_word(sfx_type)
	
	## 字体设置
	add_theme_font_size_override("font_size", _data.get("font_size", 28))
	add_theme_color_override("font_color", _data.get("color", Color.WHITE))
	
	## 描边/阴影（漫画风格）
	add_theme_constant_override("outline_size", 3)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	add_theme_constant_override("shadow_offset_x", 3)
	add_theme_constant_override("shadow_offset_y", 3)
	
	## 定位
	_start_pos = position
	global_position = position
	pivot_offset = size / 2
	
	## 随机略微旋转（漫画手写感）
	rotation_degrees = randf_range(-15, 15)
	
	_animate(direction)

func _animate(direction: Vector2) -> void:
	var travel: Vector2 = direction.normalized() * randf_range(40, 80)
	var duration: float = _data.get("duration", 0.8)
	var scale_bounce: float = _data.get("scale_bounce", 1.3)
	
	## 初始缩放
	scale = Vector2(0.1, 0.1)
	modulate.a = 1.0
	
	if _tween != null and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	## Phase 1: 快速放大弹跳（冲击感）
	_tween.tween_property(self, "scale", Vector2(scale_bounce, scale_bounce), 0.15)
	_tween.parallel().tween_property(self, "rotation_degrees", rotation_degrees + randf_range(-10, 10), 0.15)
	
	## Phase 2: 缩回到正常大小 + 开始移动
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_ELASTIC)
	
	## Phase 3: 向上飘移 + 旋转 + 淡出
	var float_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(self, "position", position + travel, duration * 0.6).set_delay(0.2)
	float_tween.parallel().tween_property(self, "rotation_degrees", rotation_degrees + randf_range(-20, 20), duration * 0.6).set_delay(0.2)
	float_tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.4)
	
	await float_tween.finished
	queue_free()
