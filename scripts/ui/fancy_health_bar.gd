class_name FancyHealthBar
extends Control

## 高级血条控件
## 支持两种样式：0=经典JRPG分段式, 1=剧场幕布丝带

@export var style_mode: int = 0  ## 0=Segmented, 1=Ribbon
@export var max_value: float = 100.0
@export var value: float = 100.0:
	set(v):
		value = clampf(v, 0.0, max_value)
		queue_redraw()

## 分段式配置
@export var segment_count: int = 10
@export var segment_gap: float = 3.0

## 颜色（适配日式冒险SD纸片剧场暗色调）
var COLOR_HIGH := Color(0.18, 0.76, 0.49)   ## 翡翠绿
var COLOR_MID := Color(0.95, 0.65, 0.15)    ## 琥珀黄
var COLOR_LOW := Color(0.85, 0.22, 0.15)    ## 珊瑚红
var COLOR_EMPTY := Color(0.10, 0.08, 0.06)  ## 暗木底
var COLOR_BORDER := Color(0.35, 0.25, 0.15) ## 深木边框
var COLOR_RIBBON_BG := Color(0.25, 0.08, 0.08)   ## 深酒红底
var COLOR_RIBBON_FILL := Color(0.72, 0.15, 0.20) ## 亮红丝带
var COLOR_CURTAIN := Color(0.55, 0.10, 0.10)     ## 幕布红
var COLOR_GOLD := Color(0.90, 0.75, 0.35)

## 边框覆盖色（用于狂暴等特效）
var border_flash_color: Color = Color.TRANSPARENT

## 动画状态
var _animated_value: float = 100.0
var _value_tween: Tween = null
var _flash_tween: Tween = null
var _frenzy_tween: Tween = null
var _is_low_hp: bool = false

func _ready() -> void:
	_animated_value = value
	queue_redraw()

func _draw() -> void:
	match style_mode:
		0: _draw_segmented()
		1: _draw_ribbon()


# ==========================================
# Style 02：经典JRPG分段式（带木质装饰外框）
# ==========================================
func _draw_segmented() -> void:
	var ratio := _animated_value / maxf(1.0, max_value)
	var fill_color := _get_threshold_color(ratio)
	var border_color := COLOR_BORDER if border_flash_color.a <= 0 else border_flash_color
	
	## 外框阴影（模拟厚度）
	draw_rect(Rect2(Vector2(1, 2), size), Color(0, 0, 0, 0.3), false, 2.0)
	
	## 外框主体（深木粗线）
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.14, 0.08, 1.0), false, 2.5)
	## 外框高光（倒角效果 — 顶部/左侧）
	draw_rect(Rect2(Vector2(1, 1), Vector2(size.x - 1, 1)), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(Vector2(1, 1), Vector2(1, size.y - 1)), Color(1, 1, 1, 0.08))
	## 外框阴影（底部/右侧）
	draw_rect(Rect2(Vector2(1, size.y - 1), Vector2(size.x - 1, 1)), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(Vector2(size.x - 1, 1), Vector2(1, size.y - 1)), Color(0, 0, 0, 0.15))
	
	## 内部背景区（留 2px 内边距）
	var inner_rect := Rect2(Vector2(2, 2), Vector2(size.x - 4, size.y - 4))
	draw_rect(inner_rect, Color(0.06, 0.04, 0.03, 1.0))
	
	## 连续填充条（平滑实时掉落）
	var inner_w := size.x - 4
	var inner_h := size.y - 4
	var fill_width := inner_w * ratio
	
	if fill_width > 0:
		var fill_rect := Rect2(Vector2(2, 2), Vector2(fill_width, inner_h))
		draw_rect(fill_rect, fill_color)
		
		## 顶部高光
		var shine_rect := Rect2(Vector2(2, 2), Vector2(fill_width, 2))
		draw_rect(shine_rect, Color(1, 1, 1, 0.25))
	
	## 分段分隔线（保留分段外观）
	var seg_width := (inner_w - (segment_count - 1) * segment_gap) / segment_count
	for i in range(1, segment_count):
		var x := 2 + i * (seg_width + segment_gap) - segment_gap * 0.5
		var div_rect := Rect2(Vector2(x, 2), Vector2(segment_gap, inner_h))
		draw_rect(div_rect, Color(0.04, 0.03, 0.02, 0.75))
	
	## 整体内边框
	draw_rect(inner_rect, border_color, false, 1.5)


# ==========================================
# Style 04：剧场幕布丝带
# ==========================================
func _draw_ribbon() -> void:
	var ratio := _animated_value / maxf(1.0, max_value)
	var fill_width := size.x * ratio
	var border_color := COLOR_GOLD if border_flash_color.a <= 0 else border_flash_color
	
	## 幕布褶皱装饰（顶部小三角）
	var curtain_h := 6.0
	var tri_w := 12.0
	var tri_count := int(size.x / tri_w)
	for i in range(tri_count):
		var x := i * tri_w
		var tri := PackedVector2Array([
			Vector2(x, 0),
			Vector2(x + tri_w * 0.5, -curtain_h),
			Vector2(x + tri_w, 0)
		])
		draw_polygon(tri, [COLOR_CURTAIN])
	
	## 丝带底色（深酒红）
	var ribbon_rect := Rect2(Vector2(0, 0), size)
	draw_rect(ribbon_rect, COLOR_RIBBON_BG)
	
	## 丝带填充
	if fill_width > 0:
		var fill_rect := Rect2(Vector2(0, 0), Vector2(fill_width, size.y))
		draw_rect(fill_rect, COLOR_RIBBON_FILL)
		
		## 填充高光（顶部细白线）
		var shine_rect := Rect2(Vector2(0, 0), Vector2(fill_width, 2))
		draw_rect(shine_rect, Color(1, 1, 1, 0.3))
		
		## 填充边缘光（右侧1px）
		if fill_width < size.x:
			var edge_rect := Rect2(Vector2(fill_width - 1, 0), Vector2(2, size.y))
			draw_rect(edge_rect, Color(1, 0.8, 0.8, 0.4))
	
	## 丝带边框（古铜金）
	draw_rect(ribbon_rect, border_color, false, 1.5)
	
	## 底部流苏装饰（小竖线）
	var tassel_w := 8.0
	var tassel_count := int(size.x / tassel_w)
	for i in range(tassel_count):
		var x := i * tassel_w + tassel_w * 0.5
		draw_line(
			Vector2(x, size.y),
			Vector2(x, size.y + 4),
			border_color, 1.0
		)


# ==========================================
# 公共方法
# ==========================================
func set_value_animated(new_value: float, duration: float = 0.4) -> void:
	value = clampf(new_value, 0.0, max_value)
	
	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()
	
	_value_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_value_tween.tween_property(self, "_animated_value", value, duration)
	_value_tween.tween_callback(queue_redraw)
	
	## 动画期间持续重绘
	_value_tween.step_finished.connect(func(_step): queue_redraw())
	
	## 低血量检查
	var ratio := value / maxf(1.0, max_value)
	if ratio < 0.3 and not _is_low_hp:
		_start_low_hp_flash()
	elif ratio >= 0.3 and _is_low_hp:
		_stop_low_hp_flash()


func set_value_instant(new_value: float) -> void:
	value = clampf(new_value, 0.0, max_value)
	_animated_value = value
	queue_redraw()
	var ratio := value / maxf(1.0, max_value)
	if ratio < 0.3:
		_start_low_hp_flash()
	else:
		_stop_low_hp_flash()


func start_frenzy_border_flash() -> void:
	if _frenzy_tween != null and _frenzy_tween.is_valid():
		_frenzy_tween.kill()
	_frenzy_tween = create_tween().set_loops()
	_frenzy_tween.tween_method(_apply_border_flash, Color(1, 0.1, 0.1, 0.0), Color(1, 0.1, 0.1, 1.0), 0.4)
	_frenzy_tween.tween_method(_apply_border_flash, Color(1, 0.1, 0.1, 1.0), Color(1, 0.1, 0.1, 0.0), 0.4)


func stop_frenzy_border_flash() -> void:
	if _frenzy_tween != null and _frenzy_tween.is_valid():
		_frenzy_tween.kill()
	_frenzy_tween = null
	border_flash_color = Color.TRANSPARENT
	queue_redraw()


func _apply_border_flash(c: Color) -> void:
	border_flash_color = c
	queue_redraw()


func _get_threshold_color(ratio: float) -> Color:
	if ratio > 0.7:
		return COLOR_HIGH
	elif ratio > 0.3:
		return COLOR_MID
	else:
		return COLOR_LOW


func _start_low_hp_flash() -> void:
	_is_low_hp = true
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_loops()
	_flash_tween.tween_property(self, "modulate", Color(1.3, 0.7, 0.7), 0.3)
	_flash_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)


func _stop_low_hp_flash() -> void:
	_is_low_hp = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	modulate = Color(1, 1, 1)
