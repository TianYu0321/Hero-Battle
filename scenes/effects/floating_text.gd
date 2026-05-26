## res://scenes/effects/floating_text.gd
## 模块: FloatingText
## 职责: 浮动伤害/治疗数字显示节点
## 依赖: 无
## 被依赖: FeedbackManager

extends Label

var _tween: Tween = null

func setup(value: int, is_heal: bool, is_crit: bool, is_missed: bool, position: Vector2) -> void:
	if is_missed:
		text = "MISS"
		add_theme_font_size_override("font_size", 22)
		add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
	elif is_heal:
		text = "+%d" % value
		add_theme_font_size_override("font_size", 32 if is_crit else 24)
		add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1))
	elif is_crit:
		text = "-%d!" % value
		add_theme_font_size_override("font_size", 36)
		add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1))
	else:
		text = "-%d" % value
		add_theme_font_size_override("font_size", 24)
		add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	
	## 描边
	add_theme_constant_override("outline_size", 2)
	add_theme_color_override("font_outline_color", Color.BLACK)
	
	## 定位
	global_position = position
	pivot_offset = size / 2
	
	_animate(is_crit, is_heal)

func _animate(is_crit: bool, is_heal: bool) -> void:
	var duration: float = 1.0 if is_crit else 0.8
	var travel: Vector2 = Vector2(randf_range(-20, 20), -60 if is_heal else -50)
	
	scale = Vector2(0.3, 0.3)
	modulate.a = 1.0
	
	if _tween != null and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	
	if is_crit:
		## 暴击：剧烈弹跳 + 红色闪烁 + 大缩放
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
		_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_ELASTIC)
		
		## 闪烁效果
		var flash_tween := create_tween()
		flash_tween.tween_property(self, "modulate", Color(1.5, 0.5, 0.5, 1), 0.05)
		flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.05)
		flash_tween.tween_property(self, "modulate", Color(1.5, 0.5, 0.5, 1), 0.05)
		flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.05)
	else:
		## 普通：平滑放大
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	
	## 飘移 + 淡出（共用）
	var float_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(self, "position", position + travel, duration * 0.7).set_delay(0.2)
	float_tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	
	if is_crit:
		## 暴击额外：左右抖动
		float_tween.parallel().tween_property(self, "position:x", position.x + randf_range(-15, 15), 0.05).set_delay(0.2)
		float_tween.tween_property(self, "position:x", position.x + randf_range(-10, 10), 0.05)
		float_tween.tween_property(self, "position:x", position.x + randf_range(-5, 5), 0.05)
	
	await float_tween.finished
	queue_free()
