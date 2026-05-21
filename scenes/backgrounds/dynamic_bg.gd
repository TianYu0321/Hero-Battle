extends Control

## ==========================================
## 动态背景控制器 - PVE 三阶段分层视差背景
## ==========================================

enum StageType { FOREST, CASTLE, TERRACE }

const CONFIG_PATH: String = "res://resources/configs/bg_stage_configs.json"
var _stage_config: Dictionary = {}

func _load_stage_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("[DynamicBg] 配置文件不存在: " + CONFIG_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("[DynamicBg] JSON 解析失败: " + CONFIG_PATH)
		return
	var raw: Dictionary = json.data.get("stages", {})
	_stage_config[StageType.FOREST] = _parse_stage(raw.get("forest", {}))
	_stage_config[StageType.CASTLE] = _parse_stage(raw.get("castle", {}))
	_stage_config[StageType.TERRACE] = _parse_stage(raw.get("terrace", {}))

func _parse_stage(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var fc: Array = result.get("fog_color", [0.5, 0.5, 0.5, 1.0])
	result["fog_color"] = Color(fc[0], fc[1], fc[2], fc[3])
	return result

@onready var base_layer: Sprite2D = $BaseLayer
@onready var parallax_container: Node2D = $ParallaxContainer
@onready var fog_overlay: Sprite2D = $FogOverlay
@onready var vignette_overlay: Sprite2D = $VignetteOverlay
@onready var effect_particles: CPUParticles2D = $EffectParticles

var _screen_size: Vector2
var _screen_center: Vector2
var _current_stage: StageType = -1
var _parallax_sprites: Array[Sprite2D] = []
var _parallax_drift: Array[float] = []
var _mouse_pos: Vector2
var _drift_time: float = 0.0
var _flyer: Sprite2D = null
var _flyer_time: float = 0.0
var _editor_panel: PanelContainer = null

func _ready() -> void:
	_screen_size = get_viewport_rect().size
	_screen_center = _screen_size / 2.0
	_mouse_pos = _screen_center
	_load_stage_config()
	_setup_overlays()
	_setup_vignette()
	if EventBus.has_signal("floor_changed"):
		EventBus.floor_changed.connect(_on_floor_changed)
	load_stage_for_floor(1)
	_setup_editor()

func _setup_editor() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BgEditorCanvas"
	canvas.layer = 100
	add_child(canvas)
	
	var panel := preload("res://scenes/backgrounds/bg_editor_panel.gd").new()
	panel.name = "BgEditorPanel"
	canvas.add_child(panel)
	_editor_panel = panel
	panel.setup(self)
	panel.position = Vector2(20, 20)
	panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7:
		if _editor_panel != null:
			_editor_panel.visible = not _editor_panel.visible
			_editor_panel.sync_from_bg()
			_set_ui_visible(not _editor_panel.visible)

var _ui_visibility_backup: Dictionary = {}

func _set_ui_visible(visible: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	if visible:
		# 恢复：只把之前被隐藏的节点恢复为 true，原本就是 false 的保持 false
		for child in parent.get_children():
			if child == self:
				continue
			if child.name in _ui_visibility_backup:
				child.visible = _ui_visibility_backup[child.name]
		_ui_visibility_backup.clear()
	else:
		# 隐藏：备份当前可见状态，然后把所有可见的 UI 节点隐藏
		_ui_visibility_backup.clear()
		for child in parent.get_children():
			if child == self:
				continue
			if child.name == "RunController":
				continue
			_ui_visibility_backup[child.name] = child.visible
			child.visible = false

func _process(delta: float) -> void:
	_mouse_pos = get_viewport().get_mouse_position()
	_drift_time += delta
	_update_parallax()
	_update_flyer(delta)

func _on_floor_changed(current_floor: int, _max_floor: int, _floor_type: String) -> void:
	load_stage_for_floor(current_floor)

static func get_stage_type(floor: int) -> StageType:
	if floor <= 10:
		return StageType.FOREST
	elif floor <= 20:
		return StageType.CASTLE
	else:
		return StageType.TERRACE

func load_stage_for_floor(floor: int) -> void:
	var stage: StageType = get_stage_type(floor)
	if stage == _current_stage:
		return
	_current_stage = stage
	var config: Dictionary = _stage_config[stage]
	
	var base_path: String = config["base"]
	if FileAccess.file_exists(base_path):
		base_layer.texture = load(base_path)
		_fit_sprite_cover(base_layer)
		base_layer.position = _screen_center
		base_layer.visible = config.get("base_visible", true)
	else:
		push_warning("[DynamicBg] 底图不存在: %s" % base_path)
	
	_clear_parallax()
	
	var layers: Array = config["layers"]
	for i in range(layers.size()):
		var layer_data: Dictionary = layers[i]
		var sprite := Sprite2D.new()
		sprite.name = "Parallax_%d" % i
		sprite.centered = false
		var tex_path: String = layer_data["path"]
		if FileAccess.file_exists(tex_path):
			sprite.texture = load(tex_path)
			var tex_w: float = sprite.texture.get_width()
			var tex_h: float = sprite.texture.get_height()
			var base_scale: float = _screen_size.x / tex_w
			var layer_scale: float = layer_data.get("scale", 1.0)
			sprite.scale = Vector2(base_scale * layer_scale, base_scale * layer_scale)
			var base_y: float = _screen_size.y - tex_h * base_scale * layer_scale
			var off_x: float = layer_data.get("offset_x", 0.0)
			var off_y: float = layer_data.get("offset_y", 0.0)
			sprite.position = Vector2(off_x, base_y + off_y)
		else:
			push_warning("[DynamicBg] 视差纹理不存在: %s" % tex_path)
		parallax_container.add_child(sprite)
		_parallax_sprites.append(sprite)
		_parallax_drift.append(0.0)
	
	fog_overlay.modulate = Color(1, 1, 1, config["fog_alpha"])
	var fog_img := Image.create(int(_screen_size.x), int(_screen_size.y), false, Image.FORMAT_RGBA8)
	fog_img.fill(config["fog_color"])
	fog_overlay.texture = ImageTexture.create_from_image(fog_img)
	_setup_effect(config["effect"])
	_setup_flyer(stage)
	# 应用保存的全局参数覆盖默认值
	var saved_amount: int = config.get("particle_amount", -1)
	if saved_amount >= 0:
		effect_particles.amount = saved_amount
	var saved_pspeed: float = config.get("particle_speed", -1.0)
	if saved_pspeed >= 0:
		effect_particles.initial_velocity_max = saved_pspeed
		effect_particles.initial_velocity_min = saved_pspeed * 0.3
	var saved_psize: float = config.get("particle_size", -1.0)
	if saved_psize >= 0:
		effect_particles.scale_amount_max = saved_psize
		effect_particles.scale_amount_min = saved_psize * 0.4
	set_meta("flyer_speed", config.get("flyer_speed", 90.0))
	set_meta("flyer_y", config.get("flyer_y", 200.0))
	set_meta("flyer_amp", config.get("flyer_amp", 35.0))
	set_meta("drift_speed", config.get("drift_speed", 0.3))
	set_meta("drift_amp", config.get("drift_amp", 1.0))

func _update_parallax() -> void:
	var offset: Vector2 = _mouse_pos - _screen_center
	for i in range(_parallax_sprites.size()):
		var sprite: Sprite2D = _parallax_sprites[i]
		var config: Dictionary = _stage_config[_current_stage]["layers"][i]
		var depth: float = config["depth"]
		# 鼠标视差 + 正弦波自动漂移(统一方向, 避免Tween冲突)
		var drift_speed: float = get_meta("drift_speed", 0.3)
		var drift_amp: float = get_meta("drift_amp", 1.0)
		var layer_drift_phase: float = config.get("drift_phase", i * 0.7)
		var layer_drift_amp: float = config.get("drift_amp", 1.0)
		var drift: float = sin(_drift_time * drift_speed + layer_drift_phase) * (6.0 + depth * 8.0) * drift_amp * layer_drift_amp
		var user_off_x: float = config.get("offset_x", 0.0)
		var target_x: float = user_off_x - offset.x * depth * 0.12 + drift
		sprite.position.x = lerp(sprite.position.x, target_x, 0.08)


func _setup_flyer(stage: StageType) -> void:
	if _flyer != null:
		_flyer.queue_free()
		_flyer = null
	var cfg: Dictionary = _stage_config.get(stage, {})
	if not cfg.get("flyer_enabled", false):
		return
	_flyer = Sprite2D.new()
	_flyer.name = "Flyer"
	var img := Image.create(28, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x in range(28):
		for y in range(20):
			var dx := absf(x - 14.0)
			var dy := absf(y - 10.0)
			if dy < 10.0 - dx * 0.6 or (dx < 5.0 and dy < 8.0):
				img.set_pixel(x, y, Color(0.08, 0.08, 0.12, 0.55))
	_flyer.texture = ImageTexture.create_from_image(img)
	_flyer.position = Vector2(-60, 200)
	add_child(_flyer)
	_flyer_time = 0.0

func _update_flyer(delta: float) -> void:
	if _flyer == null:
		return
	_flyer_time += delta
	var speed: float = get_meta("flyer_speed", 90.0)
	var amplitude: float = get_meta("flyer_amp", 35.0)
	var base_y: float = get_meta("flyer_y", 200.0)
	var cycle_width: float = 2200.0
	var t: float = fmod(_flyer_time * speed, cycle_width)
	var x: float = t - 100.0
	var y: float = base_y + sin(_flyer_time * 1.5) * amplitude
	_flyer.position = Vector2(x, y)
	# 根据方向翻转
	_flyer.flip_h = false

func _setup_effect(effect_type: String) -> void:
	match effect_type:
		"forest":
			_setup_forest_effect()
		"castle":
			_setup_castle_effect()
		"terrace":
			_setup_terrace_effect()

func _setup_forest_effect() -> void:
	effect_particles.amount = 30
	effect_particles.lifetime = 6.0
	effect_particles.preprocess = 6.0
	effect_particles.speed_scale = 0.3
	effect_particles.direction = Vector2(0.1, 0.8)
	effect_particles.spread = 30.0
	effect_particles.gravity = Vector2(0, 20)
	effect_particles.initial_velocity_min = 10.0
	effect_particles.initial_velocity_max = 30.0
	effect_particles.angular_velocity_min = -20.0
	effect_particles.angular_velocity_max = 20.0
	effect_particles.scale_amount_min = 0.5
	effect_particles.scale_amount_max = 2.0
	effect_particles.color = Color(0.7, 0.6, 0.4, 0.4)
	effect_particles.color_ramp = _make_gradient([
		Color(0.7, 0.6, 0.4, 0.0),
		Color(0.7, 0.6, 0.4, 0.5),
		Color(0.7, 0.6, 0.4, 0.0),
	])
	_effect_particle_texture(4)
	_setup_emission_rect()
	effect_particles.emitting = true

func _setup_castle_effect() -> void:
	effect_particles.amount = 50
	effect_particles.lifetime = 5.0
	effect_particles.preprocess = 5.0
	effect_particles.speed_scale = 0.4
	effect_particles.direction = Vector2(0.3, 0.9)
	effect_particles.spread = 20.0
	effect_particles.gravity = Vector2(0, 10)
	effect_particles.initial_velocity_min = 20.0
	effect_particles.initial_velocity_max = 50.0
	effect_particles.angular_velocity_min = 0.0
	effect_particles.angular_velocity_max = 0.0
	effect_particles.scale_amount_min = 0.3
	effect_particles.scale_amount_max = 1.2
	effect_particles.color = Color(0.9, 0.95, 1.0, 0.5)
	effect_particles.color_ramp = _make_gradient([
		Color(0.9, 0.95, 1.0, 0.0),
		Color(0.9, 0.95, 1.0, 0.6),
		Color(0.9, 0.95, 1.0, 0.0),
	])
	_effect_particle_texture(3)
	_setup_emission_rect()
	effect_particles.emitting = true

func _setup_terrace_effect() -> void:
	effect_particles.amount = 40
	effect_particles.lifetime = 8.0
	effect_particles.preprocess = 8.0
	effect_particles.speed_scale = 0.2
	effect_particles.direction = Vector2(0.5, -0.2)
	effect_particles.spread = 45.0
	effect_particles.gravity = Vector2.ZERO
	effect_particles.initial_velocity_min = 5.0
	effect_particles.initial_velocity_max = 20.0
	effect_particles.angular_velocity_min = -5.0
	effect_particles.angular_velocity_max = 5.0
	effect_particles.scale_amount_min = 0.4
	effect_particles.scale_amount_max = 1.5
	effect_particles.color = Color(0.7, 0.75, 1.0, 0.35)
	effect_particles.color_ramp = _make_gradient([
		Color(0.7, 0.75, 1.0, 0.0),
		Color(0.7, 0.75, 1.0, 0.5),
		Color(0.7, 0.75, 1.0, 0.0),
	])
	_effect_particle_texture(3)
	_setup_emission_rect()
	effect_particles.emitting = true

func _setup_emission_rect() -> void:
	effect_particles.position = _screen_center
	effect_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	effect_particles.emission_rect_extents = Vector2(_screen_size.x * 0.5, _screen_size.y * 0.5)

func _effect_particle_texture(size_px: int) -> void:
	var pimg := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	pimg.fill(Color.WHITE)
	effect_particles.texture = ImageTexture.create_from_image(pimg)

func _make_gradient(colors: Array[Color]) -> Gradient:
	var grad := Gradient.new()
	grad.colors = colors
	var offsets: Array[float] = []
	for i in range(colors.size()):
		offsets.append(float(i) / float(colors.size() - 1))
	grad.offsets = offsets
	return grad

func _fit_sprite_cover(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	var sx: float = _screen_size.x / tex_size.x
	var sy: float = _screen_size.y / tex_size.y
	var cover_scale: float = maxf(sx, sy)
	sprite.scale = Vector2(cover_scale, cover_scale)
	sprite.centered = true

func _clear_parallax() -> void:
	for sprite in _parallax_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_parallax_sprites.clear()
	_parallax_drift.clear()

func _setup_overlays() -> void:
	fog_overlay.scale = Vector2.ONE
	fog_overlay.position = _screen_center
	fog_overlay.centered = true

func _setup_vignette() -> void:
	var tex := GradientTexture2D.new()
	tex.gradient = Gradient.new()
	tex.gradient.colors = [
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.50),
	]
	tex.gradient.offsets = [0.0, 1.0]
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.85, 0.5)
	tex.width = int(_screen_size.x)
	tex.height = int(_screen_size.y)
	vignette_overlay.texture = tex
	vignette_overlay.scale = Vector2.ONE
	vignette_overlay.position = _screen_center
	vignette_overlay.centered = true
