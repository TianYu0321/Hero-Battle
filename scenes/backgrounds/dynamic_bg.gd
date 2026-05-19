extends Control

## ==========================================
## 动态背景控制器 — PVE 分层背景动画
## 所有可调参数集中在下方
## ==========================================

# ---------- 纹理路径 ----------
@export_group("图层纹理路径")
@export var sky_texture_path:       String = "res://assets/backgrounds/pve/stages/4.png"
@export var window_texture_path:    String = "res://assets/backgrounds/pve/stages/2.png"
@export var ground_texture_path:    String = "res://assets/backgrounds/pve/stages/5.png"
@export var bat_texture_path:       String = "res://assets/backgrounds/pve/stages/3.png"
@export var foreground_texture_path: String = "res://assets/backgrounds/pve/stages/1.png"

# ---------- 天空视差 ----------
@export_group("天空视差")
@export var sky_drift_speed:   float = 6.0    ## 漂移速度 (px/s)
@export var sky_drift_range:   float = 30.0   ## 最大漂移距离 (px)

# ---------- 蝙蝠层 ----------
@export_group("蝙蝠层")
@export var bat_drift_speed:       float = 10.0   ## 横向漂移速度 (px/s)
@export var bat_drift_range:       float = 20.0   ## 横向漂移范围 (px)
@export var bat_breathe_min:       float = 0.65   ## 透明度最小值
@export var bat_breathe_max:       float = 1.0    ## 透明度最大值
@export var bat_breathe_duration:  float = 4.0    ## 呼吸周期 (s)

# ---------- 前景装饰 ----------
@export_group("前景装饰")
@export var fg_float_range:      float = 4.0    ## 上下浮动范围 (px)
@export var fg_float_duration:   float = 5.0    ## 浮动周期 (s)

# ---------- 窗外光效 ----------
@export_group("窗外光效")
@export var glow_color:          Color = Color(1.0, 0.92, 0.75, 1.0)
@export var glow_min_alpha:      float = 0.12
@export var glow_max_alpha:      float = 0.30
@export var glow_duration:       float = 6.0
@export var glow_scale:          float = 1.15    ## 光效比屏幕大多少倍

# ---------- 雾气 ----------
@export_group("雾气")
@export var fog_color:   Color = Color(0.65, 0.70, 0.78, 1.0)
@export var fog_alpha:   float = 0.045

# ---------- 暗角 ----------
@export_group("暗角")
@export var vignette_color:   Color = Color(0.0, 0.0, 0.0, 1.0)
@export var vignette_alpha:   float = 0.55
@export var vignette_softness: float = 0.35     ## 0=硬边, 1=极软

# ---------- Dust 粒子 ----------
@export_group("Dust 粒子")
@export var dust_amount:     int = 25
@export var dust_speed:      float = 15.0
@export var dust_lifetime:   float = 8.0
@export var dust_size_min:   float = 0.4
@export var dust_size_max:   float = 1.6

# ==========================================
# 节点引用
# ==========================================
@onready var sky_layer:        Sprite2D = $SkyLayer
@onready var window_layer:     Sprite2D = $WindowFrameLayer
@onready var ground_layer:     Sprite2D = $GroundLayer
@onready var bat_layer:        Sprite2D = $BatLayer
@onready var foreground_layer: Sprite2D = $ForegroundLayer
@onready var light_glow:       Sprite2D = $LightGlow
@onready var fog_overlay:      Sprite2D = $FogOverlay
@onready var vignette_overlay: Sprite2D = $VignetteOverlay
@onready var dust_particles:   CPUParticles2D = $DustParticles

var _screen_size: Vector2
var _screen_center: Vector2

func _ready() -> void:
	_screen_size = get_viewport_rect().size
	_screen_center = _screen_size / 2.0
	
	_setup_texture_layers()
	_setup_light_glow()
	_setup_fog()
	_setup_vignette()
	_setup_particles()
	_start_animations()

# ==========================================
# 图层初始化
# ==========================================
func _setup_texture_layers() -> void:
	var layers: Array[Sprite2D] = [sky_layer, window_layer, ground_layer, bat_layer, foreground_layer]
	var paths: Array[String] = [sky_texture_path, window_texture_path, ground_texture_path, bat_texture_path, foreground_texture_path]
	
	for i in range(layers.size()):
		var layer: Sprite2D = layers[i]
		var path: String = paths[i]
		if not path.is_empty() and FileAccess.file_exists(path):
			layer.texture = load(path)
		else:
			push_warning("[DynamicBg] 纹理不存在: %s" % path)
		
		_fit_sprite_to_screen(layer)
		layer.position = _screen_center

func _fit_sprite_to_screen(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	var sx: float = _screen_size.x / tex_size.x
	var sy: float = _screen_size.y / tex_size.y
	var cover_scale: float = maxf(sx, sy)
	sprite.scale = Vector2(cover_scale, cover_scale)
	sprite.centered = true

# ==========================================
# 光效初始化
# ==========================================
func _setup_light_glow() -> void:
	var w: int = int(_screen_size.x * glow_scale)
	var h: int = int(_screen_size.y * glow_scale)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(glow_color)
	
	light_glow.texture = ImageTexture.create_from_image(img)
	light_glow.scale = Vector2.ONE
	light_glow.position = _screen_center
	light_glow.centered = true
	light_glow.modulate = Color(1, 1, 1, glow_max_alpha)

# ==========================================
# 雾气初始化
# ==========================================
func _setup_fog() -> void:
	var img := Image.create(int(_screen_size.x), int(_screen_size.y), false, Image.FORMAT_RGBA8)
	img.fill(fog_color)
	fog_overlay.texture = ImageTexture.create_from_image(img)
	fog_overlay.scale = Vector2.ONE
	fog_overlay.position = _screen_center
	fog_overlay.centered = true
	fog_overlay.modulate = Color(1, 1, 1, fog_alpha)

# ==========================================
# 暗角初始化 — 径向渐变
# ==========================================
func _setup_vignette() -> void:
	var tex := GradientTexture2D.new()
	tex.gradient = Gradient.new()
	tex.gradient.colors = [
		Color(vignette_color.r, vignette_color.g, vignette_color.b, 0.0),
		Color(vignette_color.r, vignette_color.g, vignette_color.b, vignette_alpha),
	]
	tex.gradient.offsets = [0.0, 1.0]
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(vignette_softness + 0.5, 0.5)
	tex.width = int(_screen_size.x)
	tex.height = int(_screen_size.y)
	
	vignette_overlay.texture = tex
	vignette_overlay.scale = Vector2.ONE
	vignette_overlay.position = _screen_center
	vignette_overlay.centered = true

# ==========================================
# Dust 粒子初始化
# ==========================================
func _setup_particles() -> void:
	dust_particles.position = _screen_center
	dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_particles.emission_rect_extents = Vector2(_screen_size.x * 0.5, _screen_size.y * 0.5)
	dust_particles.amount = dust_amount
	dust_particles.lifetime = dust_lifetime
	dust_particles.preprocess = dust_lifetime
	dust_particles.speed_scale = 0.25
	dust_particles.direction = Vector2(0.15, -0.4)
	dust_particles.spread = 25.0
	dust_particles.gravity = Vector2.ZERO
	dust_particles.initial_velocity_min = dust_speed * 0.3
	dust_particles.initial_velocity_max = dust_speed
	dust_particles.angular_velocity_min = -10.0
	dust_particles.angular_velocity_max = 10.0
	dust_particles.angle_min = 0.0
	dust_particles.angle_max = 360.0
	dust_particles.scale_amount_min = dust_size_min
	dust_particles.scale_amount_max = dust_size_max
	dust_particles.color = Color(1.0, 1.0, 1.0, 0.25)
	dust_particles.color_ramp = _make_dust_fade_ramp()
	
	## 小圆点纹理
	var pimg := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	pimg.fill(Color.WHITE)
	dust_particles.texture = ImageTexture.create_from_image(pimg)
	dust_particles.emitting = true

func _make_dust_fade_ramp() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = [Color(1, 1, 1, 0), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)]
	grad.offsets = [0.0, 0.5, 1.0]
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 64
	return tex

# ==========================================
# 动画启动
# ==========================================
func _start_animations() -> void:
	## 1. 天空视差：非常慢的来回漂移
	var sky_t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var sky_half: float = sky_drift_range / sky_drift_speed
	sky_t.tween_property(sky_layer, "position:x", _screen_center.x + sky_drift_range, sky_half)
	sky_t.tween_property(sky_layer, "position:x", _screen_center.x - sky_drift_range, sky_half)
	
	## 2. 蝙蝠层：横向漂移 + 透明度呼吸
	var bat_pos_t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bat_half: float = bat_drift_range / bat_drift_speed
	bat_pos_t.tween_property(bat_layer, "position:x", _screen_center.x + bat_drift_range, bat_half)
	bat_pos_t.tween_property(bat_layer, "position:x", _screen_center.x - bat_drift_range, bat_half)
	
	var bat_alpha_t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bat_alpha_t.tween_property(bat_layer, "modulate:a", bat_breathe_min, bat_breathe_duration * 0.5)
	bat_alpha_t.tween_property(bat_layer, "modulate:a", bat_breathe_max, bat_breathe_duration * 0.5)
	
	## 3. 前景装饰：极轻微上下浮动
	var fg_t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fg_t.tween_property(foreground_layer, "position:y", _screen_center.y - fg_float_range, fg_float_duration * 0.5)
	fg_t.tween_property(foreground_layer, "position:y", _screen_center.y + fg_float_range, fg_float_duration * 0.5)
	
	## 4. 光效呼吸
	var glow_t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_t.tween_property(light_glow, "modulate:a", glow_min_alpha, glow_duration * 0.5)
	glow_t.tween_property(light_glow, "modulate:a", glow_max_alpha, glow_duration * 0.5)
