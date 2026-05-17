## res://scenes/main_menu/menu.gd
## 模块: MenuUI
## 职责: 主菜单界面，提供开始新局/继续游戏/退出功能
## 依赖: EventBus, SaveManager, ConfigManager
## 被依赖: 无（顶层入口UI）
## class_name: MenuUI

class_name MenuUI
extends Control

@onready var _btn_new_game: Button = $UILayer/MenuButtons/BtnNewGame
@onready var _btn_continue: Button = $UILayer/MenuButtons/BtnContinue
@onready var _btn_quit: Button = $UILayer/MenuButtons/BtnQuit
@onready var _menu_button: Button = %MenuButton
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _leaderboard_panel: Panel = $UILayer/LeaderboardPanel
@onready var _shop_panel: ShopPopup = $UILayer/ShopPopup
var _settings_panel: Control = null

@onready var _bg_texture: TextureRect = $BackgroundLayer/BackgroundTexture
@onready var _floor_light: ColorRect = $BackgroundLayer/FloorLightOverlay
@onready var _fog_sprite: Sprite2D = $BackgroundLayer/FogSprite
@onready var _left_hand_glow: Sprite2D = $BackgroundLayer/LeftHandGlow
@onready var _left_hand_particles: GPUParticles2D = $BackgroundLayer/LeftHandParticles
@onready var _tower_glow_1: Sprite2D = $BackgroundLayer/TowerGlow1
@onready var _tower_glow_2: Sprite2D = $BackgroundLayer/TowerGlow2
@onready var _tower_glow_3: Sprite2D = $BackgroundLayer/TowerGlow3
@onready var _character_layer: CanvasLayer = $CharacterLayer

var _fx_config: Dictionary = {}
var _menu_buttons: Array[Button] = []
var _menu_hovered_count: int = 0

var _glow_base_alpha: float = 0.0
var _glow_base_scale: float = 1.0
var _tower_base_alphas: Array[float] = [0.0, 0.0, 0.0]

const FX_CONFIG_PATH := "res://resources/configs/menu_fx_config.json"
const STRETCH_MODE_MAP := {
	"scale_on_expand": 0,
	"scale": 1,
	"tile": 2,
	"keep_aspect_centered": 3,
	"keep_aspect": 4,
	"keep_aspect_covered": 5,
}

func _ready() -> void:
	print("[MainMenu] _ready 开始, continue_button=", _btn_continue != null)
	# 安全连接按钮信号（带 null 检查）
	_safe_connect_pressed(_btn_new_game, _on_new_game_pressed)
	_safe_connect_pressed(_btn_continue, _on_continue_pressed)
	_safe_connect_pressed(_btn_quit, _on_quit_pressed)
	_safe_connect_pressed(_menu_button, _on_menu_button_pressed)
	
	# 加载动态效果配置
	_load_fx_config()
	_apply_fx_config()
	
	# 动态创建设置面板
	var settings_scene = load("res://scenes/settings/settings_panel.tscn")
	if settings_scene != null:
		_settings_panel = settings_scene.instantiate()
		add_child(_settings_panel)
		_settings_panel.visible = false
	
	# 收集左侧菜单按钮并设置样式 + hover
	_menu_buttons = [_btn_new_game, _btn_continue, _btn_quit]
	var btn_archive: Button = get_node_or_null("UILayer/MenuButtons/BtnArchive")
	var btn_pvp: Button = get_node_or_null("UILayer/MenuButtons/BtnPVP")
	var btn_shop: Button = get_node_or_null("UILayer/MenuButtons/BtnShop")
	var btn_leaderboard: Button = get_node_or_null("UILayer/MenuButtons/BtnLeaderboard")
	if btn_archive != null: _menu_buttons.append(btn_archive)
	if btn_pvp != null: _menu_buttons.append(btn_pvp)
	if btn_shop != null: _menu_buttons.append(btn_shop)
	if btn_leaderboard != null: _menu_buttons.append(btn_leaderboard)
	
	for btn in _menu_buttons:
		_setup_button_style(btn)
		_setup_menu_button_hover(btn)
	_setup_button_style(_menu_button)
	_setup_button_hover(_menu_button)

	# 启用斗士档案按钮
	if btn_archive != null:
		btn_archive.visible = true
		btn_archive.disabled = false
		btn_archive.pressed.connect(_on_archive_button_pressed)
		print("[MainMenu] 档案按钮已启用")
	else:
		push_warning("[MainMenu] BtnArchive 未找到")

	# 启用PVP对战按钮
	if btn_pvp != null:
		btn_pvp.visible = true
		btn_pvp.disabled = false
		btn_pvp.pressed.connect(_on_pvp_pressed)
		print("[MainMenu] PVP按钮已启用")
	else:
		push_warning("[MainMenu] BtnPVP 未找到")

	# 启用商店按钮
	if btn_shop != null:
		btn_shop.visible = true
		btn_shop.disabled = false
		btn_shop.pressed.connect(_on_shop_pressed)
		print("[MainMenu] 商店按钮已启用")
	else:
		push_warning("[MainMenu] BtnShop 未找到")

	# 启用排行榜按钮
	if btn_leaderboard != null:
		btn_leaderboard.visible = true
		btn_leaderboard.disabled = false
		btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
		_setup_button_style(btn_leaderboard)
		_setup_button_hover(btn_leaderboard)
		print("[MainMenu] 排行榜按钮已启用")
	else:
		push_warning("[MainMenu] BtnLeaderboard 未找到")
	
	# 启用设置按钮
	var btn_settings: Button = get_node_or_null("UILayer/MenuButtons/BtnSettings")
	if btn_settings != null:
		btn_settings.visible = true
		btn_settings.disabled = false
		btn_settings.pressed.connect(_on_settings_pressed)
		_setup_button_style(btn_settings)
		_setup_button_hover(btn_settings)
		print("[MainMenu] 设置按钮已启用")
	else:
		push_warning("[MainMenu] BtnSettings 未找到")

	# 主菜单中隐藏PauseMenu的"返回主菜单"按钮
	_pause_menu.set_is_main_menu(true)

	var save_data = SaveManager.load_latest_run()
	var is_valid = SaveManager.is_valid_save(save_data)
	if _btn_continue != null:
		_btn_continue.visible = is_valid
	print("[MainMenu] 继续游戏按钮显隐: ", is_valid)

	_update_pvp_archive_display()
	
	# 调试：确认所有按钮状态
	for btn in _menu_buttons:
		if is_instance_valid(btn):
			print("[MainMenu] 按钮 '%s': visible=%s global_pos=%s size=%s modulate=%s" % [btn.text, btn.visible, btn.global_position, btn.size, btn.modulate])
		else:
			push_warning("[MainMenu] 按钮为 null 或无效实例")
	if is_instance_valid(_menu_button):
		print("[MainMenu] 设置按钮: visible=%s global_pos=%s size=%s" % [_menu_button.visible, _menu_button.global_position, _menu_button.size])
	else:
		push_warning("[MainMenu] 设置按钮为 null 或无效实例")
	
	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)

# ========== 配置加载 ==========

func _load_fx_config() -> void:
	_fx_config = ConfigManager._load_json_safe(FX_CONFIG_PATH, {})
	if _fx_config.is_empty():
		push_warning("[MainMenu] 菜单特效配置文件未找到或为空，使用硬编码默认值")
		_fx_config = _get_default_fx_config()

func _get_default_fx_config() -> Dictionary:
	return {
		"background": {
			"mode": "image",
			"texture_path": "res://assets/backgrounds/menu_bg.png",
			"stretch_mode": "keep_aspect"
		},
		"left_hand_glow": {
			"enabled": true,
			"position": [253, 480],
			"texture_size": 280,
			"color": [0.55, 0.1, 0.85, 0.30],
			"color_bright": [0.70, 0.2, 1.0, 0.45],
			"breathe_alpha_min": 0.22,
			"breathe_alpha_max": 0.40,
			"breathe_scale_min": 0.92,
			"breathe_scale_max": 1.10,
			"cycle_seconds": 2.4,
			"trans": "sine",
			"ease": "in_out"
		},
		"left_hand_particles": {
			"enabled": true,
			"position": [253, 480],
			"amount": 20,
			"lifetime": 1.2,
			"preprocess": 1.0,
			"visibility_rect": [-100, -100, 200, 200],
			"emission_shape": 1,
			"emission_sphere_radius": 35.0,
			"direction": [0, -1, 0],
			"spread": 25.0,
			"initial_velocity_min": 15.0,
			"initial_velocity_max": 40.0,
			"gravity": [0, -10, 0],
			"damping_min": 5.0,
			"damping_max": 15.0,
			"scale_min": 1.0,
			"scale_max": 2.5,
			"color": [0.65, 0.15, 0.95, 0.45],
			"particle_texture_size": 4
		},
		"fog_overlay": {
			"enabled": true,
			"position": [640, 360],
			"texture_width": 2560,
			"texture_height": 300,
			"color": [0.45, 0.50, 0.55, 0.10],
			"speed": 18.0,
			"cycle_seconds": 18.0,
			"trans": "linear",
			"ease": "in_out"
		},
		"tower_glows": [
			{
				"enabled": true,
				"position": [920, 147],
				"texture_size": 50,
				"color": [0.95, 0.75, 0.35, 0.28],
				"flicker_alpha_min": 0.15,
				"flicker_alpha_max": 0.42,
				"flicker_speed": 0.14,
				"cycle_min": 1.4,
				"cycle_max": 2.8
			},
			{
				"enabled": true,
				"position": [900, 200],
				"texture_size": 45,
				"color": [0.92, 0.72, 0.32, 0.22],
				"flicker_alpha_min": 0.10,
				"flicker_alpha_max": 0.35,
				"flicker_speed": 0.11,
				"cycle_min": 1.8,
				"cycle_max": 3.2
			},
			{
				"enabled": true,
				"position": [940, 240],
				"texture_size": 40,
				"color": [0.88, 0.68, 0.28, 0.18],
				"flicker_alpha_min": 0.08,
				"flicker_alpha_max": 0.30,
				"flicker_speed": 0.10,
				"cycle_min": 2.0,
				"cycle_max": 3.8
			}
		],
		"floor_light": {
			"enabled": false,
			"anchor_top": 0.75,
			"color": [0.90, 0.75, 0.35, 0.05],
			"color_warm": [0.92, 0.70, 0.30, 0.06],
			"color_cool": [0.82, 0.78, 0.45, 0.04],
			"pulse_alpha_min": 0.03,
			"pulse_alpha_max": 0.14,
			"hold_peak_seconds": 0.6,
			"fade_in_seconds": 2.2,
			"fade_out_seconds": 2.8,
			"trans_in": "cubic",
			"ease_in": "out",
			"trans_out": "sine",
			"ease_out": "in"
		},
		"hover_enhance": {
			"glow_alpha_boost": 0.18,
			"glow_scale_boost": 0.06,
			"tower_alpha_boost": 0.12,
			"tween_duration": 0.35,
			"trans": "cubic",
			"ease": "out"
		}
	}

func _apply_fx_config() -> void:
	var bg_cfg: Dictionary = _fx_config.get("background", {})
	
	# 背景图设置
	var tex_path: String = bg_cfg.get("texture_path", "res://assets/backgrounds/menu_bg.png")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		_bg_texture.texture = load(tex_path)
	var mode_str: String = bg_cfg.get("stretch_mode", "keep_aspect")
	_bg_texture.stretch_mode = STRETCH_MODE_MAP.get(mode_str, TextureRect.STRETCH_KEEP_ASPECT)
	_bg_texture.visible = true
	
	# 紫色左手 glow
	var glow_cfg: Dictionary = _fx_config.get("left_hand_glow", {})
	if glow_cfg.get("enabled", true):
		_start_left_hand_glow(glow_cfg)
	else:
		_left_hand_glow.visible = false
	
	# 左手粒子
	var particle_cfg: Dictionary = _fx_config.get("left_hand_particles", {})
	if particle_cfg.get("enabled", true):
		_start_left_hand_particles(particle_cfg)
	else:
		_left_hand_particles.visible = false
	
	# 雾气层
	var fog_cfg: Dictionary = _fx_config.get("fog_overlay", {})
	if fog_cfg.get("enabled", true):
		_start_fog_overlay(fog_cfg)
	else:
		_fog_sprite.visible = false
	
	# 塔窗暖光
	var tower_cfgs: Array = _fx_config.get("tower_glows", [])
	var tower_nodes: Array[Sprite2D] = [_tower_glow_1, _tower_glow_2, _tower_glow_3]
	for i in range(min(tower_cfgs.size(), tower_nodes.size())):
		var tc: Dictionary = tower_cfgs[i]
		if tc.get("enabled", true):
			_start_tower_glow(tower_nodes[i], tc, i)
		else:
			tower_nodes[i].visible = false
	
	# 底部光带（默认关闭）
	var floor_cfg: Dictionary = _fx_config.get("floor_light", {})
	if floor_cfg.get("enabled", false):
		_start_floor_pulse(floor_cfg)
	else:
		_floor_light.visible = false


# ========== Tween 缓动解析辅助 ==========

const _TRANS_MAP: Dictionary = {
	"linear": Tween.TRANS_LINEAR,
	"sine": Tween.TRANS_SINE,
	"quint": Tween.TRANS_QUINT,
	"quart": Tween.TRANS_QUART,
	"quad": Tween.TRANS_QUAD,
	"expo": Tween.TRANS_EXPO,
	"elastic": Tween.TRANS_ELASTIC,
	"cubic": Tween.TRANS_CUBIC,
	"back": Tween.TRANS_BACK,
	"bounce": Tween.TRANS_BOUNCE,
}

const _EASE_MAP: Dictionary = {
	"in": Tween.EASE_IN,
	"out": Tween.EASE_OUT,
	"in_out": Tween.EASE_IN_OUT,
	"out_in": Tween.EASE_OUT_IN,
}

func _get_trans(name: String) -> int:
	return _TRANS_MAP.get(name, Tween.TRANS_SINE)

func _get_ease(name: String) -> int:
	return _EASE_MAP.get(name, Tween.EASE_IN_OUT)


# ========== 核心特效 ==========

func _start_left_hand_glow(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("position", [253, 480])
	var pos := Vector2(pos_arr[0], pos_arr[1])
	var size: int = cfg.get("texture_size", 280)
	var col_arr: Array = cfg.get("color", [0.55, 0.1, 0.85, 0.30])
	var col := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
	
	_left_hand_glow.position = pos
	_left_hand_glow.texture = _create_radial_glow_texture(size, col)
	_left_hand_glow.modulate = Color.WHITE
	_left_hand_glow.visible = true
	
	_glow_base_alpha = col.a
	_glow_base_scale = 1.0
	
	var alpha_min: float = cfg.get("breathe_alpha_min", 0.22)
	var alpha_max: float = cfg.get("breathe_alpha_max", 0.40)
	var scale_min: float = cfg.get("breathe_scale_min", 0.92)
	var scale_max: float = cfg.get("breathe_scale_max", 1.10)
	var cycle: float = cfg.get("cycle_seconds", 2.4)
	var trans: int = _get_trans(cfg.get("trans", "sine"))
	var ease: int = _get_ease(cfg.get("ease", "in_out"))
	
	# Alpha 呼吸
	var alpha_tween := create_tween().set_loops()
	alpha_tween.set_trans(trans).set_ease(ease)
	alpha_tween.tween_property(_left_hand_glow, "modulate:a", alpha_max, cycle * 0.5)
	alpha_tween.tween_property(_left_hand_glow, "modulate:a", alpha_min, cycle * 0.5)
	
	# 缩放呼吸（错开相位）
	var scale_tween := create_tween().set_loops()
	scale_tween.set_trans(trans).set_ease(ease)
	scale_tween.tween_property(_left_hand_glow, "scale", Vector2(scale_max, scale_max), cycle * 0.5).set_delay(cycle * 0.25)
	scale_tween.tween_property(_left_hand_glow, "scale", Vector2(scale_min, scale_min), cycle * 0.5)

func _start_left_hand_particles(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("position", [253, 480])
	_left_hand_particles.position = Vector2(pos_arr[0], pos_arr[1])
	_left_hand_particles.amount = cfg.get("amount", 20)
	_left_hand_particles.lifetime = cfg.get("lifetime", 1.2)
	_left_hand_particles.preprocess = cfg.get("preprocess", 1.0)
	var vr: Array = cfg.get("visibility_rect", [-100, -100, 200, 200])
	_left_hand_particles.visibility_rect = Rect2(vr[0], vr[1], vr[2], vr[3])
	
	var mat := ParticleProcessMaterial.new()
	var shape: int = cfg.get("emission_shape", 1)
	mat.emission_shape = shape
	if shape == ParticleProcessMaterial.EMISSION_SHAPE_SPHERE:
		mat.emission_sphere_radius = cfg.get("emission_sphere_radius", 35.0)
	
	var dir: Array = cfg.get("direction", [0, -1, 0])
	mat.direction = Vector3(dir[0], dir[1], dir[2])
	mat.spread = cfg.get("spread", 25.0)
	mat.initial_velocity_min = cfg.get("initial_velocity_min", 15.0)
	mat.initial_velocity_max = cfg.get("initial_velocity_max", 40.0)
	var grav: Array = cfg.get("gravity", [0, -10, 0])
	mat.gravity = Vector3(grav[0], grav[1], grav[2])
	mat.damping_min = cfg.get("damping_min", 5.0)
	mat.damping_max = cfg.get("damping_max", 15.0)
	mat.scale_min = cfg.get("scale_min", 1.0)
	mat.scale_max = cfg.get("scale_max", 2.5)
	var col_arr: Array = cfg.get("color", [0.65, 0.15, 0.95, 0.45])
	mat.color = Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
	_left_hand_particles.process_material = mat
	
	var psize: int = cfg.get("particle_texture_size", 4)
	_left_hand_particles.texture = _create_particle_dot_texture(psize)
	_left_hand_particles.visible = true

func _start_fog_overlay(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("position", [640, 360])
	var tex_w: int = cfg.get("texture_width", 2560)
	var tex_h: int = cfg.get("texture_height", 300)
	var col_arr: Array = cfg.get("color", [0.45, 0.50, 0.55, 0.10])
	var col := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
	var speed: float = cfg.get("speed", 18.0)
	var cycle: float = cfg.get("cycle_seconds", 18.0)
	var trans: int = _get_trans(cfg.get("trans", "linear"))
	var ease: int = _get_ease(cfg.get("ease", "in_out"))
	
	_fog_sprite.position = Vector2(pos_arr[0], pos_arr[1])
	_fog_sprite.texture = _create_fog_texture(tex_w, tex_h, col)
	_fog_sprite.visible = true
	
	# 横向循环移动：从右到左
	var half_w: float = tex_w * 0.25  # 因为纹理比屏幕宽，移动范围小一些
	var tween := create_tween().set_loops()
	tween.set_trans(trans).set_ease(ease)
	tween.tween_property(_fog_sprite, "position:x", pos_arr[0] - half_w, cycle * 0.5)
	tween.tween_property(_fog_sprite, "position:x", pos_arr[0] + half_w, cycle * 0.5)

func _start_tower_glow(sprite: Sprite2D, cfg: Dictionary, _index: int) -> void:
	var pos_arr: Array = cfg.get("position", [920, 147])
	var size: int = cfg.get("texture_size", 50)
	var col_arr: Array = cfg.get("color", [0.95, 0.75, 0.35, 0.28])
	var col := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
	var alpha_min: float = cfg.get("flicker_alpha_min", 0.15)
	var alpha_max: float = cfg.get("flicker_alpha_max", 0.42)
	var speed: float = cfg.get("flicker_speed", 0.14)
	var c_min: float = cfg.get("cycle_min", 1.4)
	var c_max: float = cfg.get("cycle_max", 2.8)
	
	sprite.position = Vector2(pos_arr[0], pos_arr[1])
	sprite.texture = _create_radial_glow_texture(size, col)
	sprite.modulate = Color.WHITE
	sprite.visible = true
	
	_tower_base_alphas[_index] = col.a
	
	# 使用随机周期的闪烁，模拟烛光不稳
	_flicker_loop(sprite, alpha_min, alpha_max, speed, c_min, c_max)

func _flicker_loop(sprite: Sprite2D, alpha_min: float, alpha_max: float, _speed: float, c_min: float, c_max: float) -> void:
	var cycle: float = randf_range(c_min, c_max)
	var target: float = randf_range(alpha_min, alpha_max)
	var dur: float = cycle * randf_range(0.3, 0.7)
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate:a", target, dur)
	tween.finished.connect(func():
		_flicker_loop(sprite, alpha_min, alpha_max, _speed, c_min, c_max)
	)

func _start_floor_pulse(cfg: Dictionary) -> void:
	_floor_light.anchor_top = cfg.get("anchor_top", 0.75)
	var col_arr: Array = cfg.get("color", [0.90, 0.75, 0.35, 0.05])
	var base_color := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
	_floor_light.color = base_color
	_floor_light.visible = true
	
	var alpha_min: float = cfg.get("pulse_alpha_min", 0.03)
	var alpha_max: float = cfg.get("pulse_alpha_max", 0.14)
	var hold: float = cfg.get("hold_peak_seconds", 0.6)
	var fade_in: float = cfg.get("fade_in_seconds", 2.2)
	var fade_out: float = cfg.get("fade_out_seconds", 2.8)
	var trans_in: int = _get_trans(cfg.get("trans_in", "cubic"))
	var ease_in: int = _get_ease(cfg.get("ease_in", "out"))
	var trans_out: int = _get_trans(cfg.get("trans_out", "sine"))
	var ease_out: int = _get_ease(cfg.get("ease_out", "in"))
	
	var warm_arr: Array = cfg.get("color_warm", [0.92, 0.70, 0.30, 0.06])
	var cool_arr: Array = cfg.get("color_cool", [0.82, 0.78, 0.45, 0.04])
	var warm := Color(warm_arr[0], warm_arr[1], warm_arr[2], warm_arr[3])
	var cool := Color(cool_arr[0], cool_arr[1], cool_arr[2], cool_arr[3])
	
	var tween := create_tween().set_loops()
	tween.set_trans(trans_in).set_ease(ease_in)
	tween.tween_property(_floor_light, "modulate:a", alpha_max, fade_in)
	tween.parallel().tween_property(_floor_light, "color", warm, fade_in)
	if hold > 0:
		tween.tween_interval(hold)
	tween.set_trans(trans_out).set_ease(ease_out)
	tween.tween_property(_floor_light, "modulate:a", alpha_min, fade_out)
	tween.parallel().tween_property(_floor_light, "color", cool, fade_out)


# ========== 纹理生成辅助 ==========

func _create_radial_glow_texture(size: int, color: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.colors = [color, Color(color.r, color.g, color.b, 0)]
	grad.offsets = [0.0, 1.0]
	tex.gradient = grad
	return tex

func _create_fog_texture(width: int, height: int, color: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = width
	tex.height = height
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var grad := Gradient.new()
	grad.colors = [Color.TRANSPARENT, color, color, Color.TRANSPARENT]
	grad.offsets = [0.0, 0.15, 0.85, 1.0]
	tex.gradient = grad
	return tex

func _create_particle_dot_texture(size: int) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.colors = [Color.WHITE, Color.TRANSPARENT]
	grad.offsets = [0.0, 1.0]
	tex.gradient = grad
	return tex


# ========== 按钮样式（暗黑霓虹）==========

const COLOR_BTN_BG := Color(0.101961, 0.101961, 0.121569, 1)
const COLOR_BTN_BG_HOVER := Color(0.145098, 0.145098, 0.188235, 1)
const COLOR_BTN_BG_PRESSED := Color(0.08, 0.08, 0.1, 1)
const COLOR_BTN_BORDER := Color(0.901961, 0.752941, 0.25098, 0.6)
const COLOR_BTN_BORDER_HOVER := Color(0.901961, 0.752941, 0.25098, 1)
const COLOR_BTN_BORDER_PRESSED := Color(0.78, 0.63, 0.18, 1)
const COLOR_BTN_TEXT := Color(0.901961, 0.752941, 0.25098, 1)
const COLOR_BTN_TEXT_DISABLED := Color(0.4, 0.4, 0.4, 1)

func _setup_button_style(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] _setup_button_style: button 为 null")
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_BTN_BG
	normal.border_color = COLOR_BTN_BORDER
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_BTN_BG_HOVER
	hover.border_color = COLOR_BTN_BORDER_HOVER
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 11
	hover.content_margin_right = 11
	hover.content_margin_top = 7
	hover.content_margin_bottom = 7
	button.add_theme_stylebox_override("hover", hover)
	
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_BTN_BG_PRESSED
	pressed.border_color = COLOR_BTN_BORDER_PRESSED
	pressed.border_width_left = 2
	pressed.border_width_top = 2
	pressed.border_width_right = 2
	pressed.border_width_bottom = 2
	pressed.corner_radius_top_left = 4
	pressed.corner_radius_top_right = 4
	pressed.corner_radius_bottom_left = 4
	pressed.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("pressed", pressed)
	
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.06, 0.06, 0.07, 1)
	disabled.border_color = Color(0.25, 0.25, 0.25, 1)
	disabled.border_width_left = 1
	disabled.border_width_top = 1
	disabled.border_width_right = 1
	disabled.border_width_bottom = 1
	disabled.corner_radius_top_left = 4
	disabled.corner_radius_top_right = 4
	disabled.corner_radius_bottom_left = 4
	disabled.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("disabled", disabled)
	
	button.add_theme_color_override("font_color", COLOR_BTN_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_BTN_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_BTN_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_BTN_TEXT_DISABLED)


# ========== Hover  glow 增强交互 ==========

func _setup_menu_button_hover(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] _setup_menu_button_hover: button 为 null")
		return
	button.mouse_entered.connect(func():
		_menu_hovered_count += 1
		if _menu_hovered_count == 1:
			_enhance_glows(true)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * 1.05, 0.15)
		tween.parallel().tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.15)
	)
	button.mouse_exited.connect(func():
		_menu_hovered_count = maxi(_menu_hovered_count - 1, 0)
		if _menu_hovered_count == 0:
			_enhance_glows(false)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, 0.15)
		tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.15)
	)

func _enhance_glows(active: bool) -> void:
	var hover_cfg: Dictionary = _fx_config.get("hover_enhance", {})
	var duration: float = hover_cfg.get("tween_duration", 0.35)
	var trans: int = _get_trans(hover_cfg.get("trans", "cubic"))
	var ease: int = _get_ease(hover_cfg.get("ease", "out"))
	
	var glow_alpha_boost: float = hover_cfg.get("glow_alpha_boost", 0.18)
	var glow_scale_boost: float = hover_cfg.get("glow_scale_boost", 0.06)
	var tower_alpha_boost: float = hover_cfg.get("tower_alpha_boost", 0.12)
	
	var tween := create_tween().set_trans(trans).set_ease(ease)
	
	if active:
		# 增强紫色 glow
		tween.parallel().tween_property(_left_hand_glow, "modulate:a", _glow_base_alpha + glow_alpha_boost, duration)
		tween.parallel().tween_property(_left_hand_glow, "scale", Vector2.ONE * (1.0 + glow_scale_boost), duration)
		# 增强塔光
		var tower_nodes: Array[Sprite2D] = [_tower_glow_1, _tower_glow_2, _tower_glow_3]
		for i in range(tower_nodes.size()):
			if tower_nodes[i].visible:
				tween.parallel().tween_property(tower_nodes[i], "modulate:a", _tower_base_alphas[i] + tower_alpha_boost, duration)
	else:
		# 恢复
		tween.parallel().tween_property(_left_hand_glow, "modulate:a", _glow_base_alpha, duration)
		tween.parallel().tween_property(_left_hand_glow, "scale", Vector2.ONE, duration)
		var tower_nodes: Array[Sprite2D] = [_tower_glow_1, _tower_glow_2, _tower_glow_3]
		for i in range(tower_nodes.size()):
			if tower_nodes[i].visible:
				tween.parallel().tween_property(tower_nodes[i], "modulate:a", _tower_base_alphas[i], duration)


# ========== 原有业务逻辑（保持不变）==========

func _safe_connect_pressed(button: Button, callback: Callable) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] 尝试连接 null/无效按钮的 pressed 信号，callback=%s" % callback.get_method())
		return
	button.pressed.connect(callback)

func _on_new_game_pressed() -> void:
	EventBus.new_game_requested.emit("")

func _on_continue_pressed() -> void:
	print("[MainMenu] 继续游戏点击, has_active_run=", SaveManager.has_active_run())
	if not SaveManager.has_active_run():
		push_error("[MainMenu] 点击继续游戏但存档无效")
		if _btn_continue != null:
			_btn_continue.visible = false
		return
	EventBus.continue_game_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_archive_button_pressed() -> void:
	print("[MainMenu] 查看档案按钮点击")
	EventBus.archive_view_requested.emit()

func _on_pvp_pressed() -> void:
	print("[MainMenu] PVP对战按钮点击")
	EventBus.pvp_lobby_requested.emit()

func _on_shop_pressed() -> void:
	print("[MainMenu] 商店按钮点击")
	_shop_panel.show_popup()

func _on_leaderboard_pressed() -> void:
	print("[MainMenu] 排行榜按钮点击")
	var leaderboard_system := LeaderboardSystem.new()
	var rankings := leaderboard_system.get_leaderboard(20)
	if _leaderboard_panel != null:
		_leaderboard_panel.show_rankings(rankings)
	else:
		push_warning("[MainMenu] LeaderboardPanel 未找到")

func _on_menu_button_pressed() -> void:
	print("[MainMenu] 菜单按钮点击")
	if _pause_menu.visible:
		_pause_menu.hide_menu()
	else:
		_pause_menu.show_menu()

func _on_save_loaded(_save_data: Dictionary) -> void:
	if _btn_continue != null:
		_btn_continue.visible = true

func _on_load_failed(_error_code: int, _error_message: String, _save_slot: int) -> void:
	if _btn_continue != null:
		_btn_continue.visible = false

func _enter_tree() -> void:
	if _btn_continue:
		var has_save = SaveManager.has_active_run()
		_btn_continue.visible = has_save
		print("[MainMenu] _enter_tree 重新检查存档: ", has_save)

func _update_pvp_archive_display() -> void:
	var archive := GameManager.get_pvp_archive()
	var hint_label: Label = get_node_or_null("UILayer/PVPHintLabel")
	if hint_label == null:
		return
	if not archive.is_empty():
		hint_label.text = "PVP出战: %s (净胜场:%d)" % [
			archive.get("hero_name", "???"),
			archive.get("net_wins", 0)
		]
		hint_label.visible = true
	else:
		hint_label.text = "PVP出战: 未选择档案"
		hint_label.visible = true

## v2.0: 排行榜系统（净胜场制）
func show_leaderboard() -> void:
	var leaderboard_data: Array[Dictionary] = _load_leaderboard_data()
	## 排序：净胜场降序
	leaderboard_data.sort_custom(func(a, b): return a.get("net_wins", 0) > b.get("net_wins", 0))
	
	## 前3名显示档案明细
	for i in range(min(3, leaderboard_data.size())):
		var entry: Dictionary = leaderboard_data[i]
		print("[Leaderboard] #%d %s 净胜场:%d 角色:%s 属性:%s 伙伴:%s" % [
			i + 1,
			entry.get("player_name", "Unknown"),
			entry.get("net_wins", 0),
			entry.get("hero_name", ""),
			entry.get("hero_attrs", ""),
			entry.get("partners", ""),
		])
	
	## 其余仅显示名字和净胜场
	for i in range(3, leaderboard_data.size()):
		var entry: Dictionary = leaderboard_data[i]
		print("[Leaderboard] #%d %s 净胜场:%d" % [
			i + 1,
			entry.get("player_name", "Unknown"),
			entry.get("net_wins", 0),
		])
	
	## 显示自己
	var my_data: Dictionary = _get_my_data()
	print("[Leaderboard] 我的排名: %s 净胜场:%d" % [
		my_data.get("player_name", "Me"),
		my_data.get("net_wins", 0),
	])

func _load_leaderboard_data() -> Array[Dictionary]:
	## 从服务器加载，此处为占位
	return []

func _get_my_data() -> Dictionary:
	return {"player_name": "Player", "net_wins": 0}

func _on_settings_pressed() -> void:
	AudioManager.play_ui("button_click")
	if _settings_panel != null:
		_show_panel(_settings_panel)
		_settings_panel.load_settings()

func _show_panel(panel: Control) -> void:
	panel.visible = true
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)

func _setup_button_hover(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] _setup_button_hover: button 为 null")
		return
	button.mouse_entered.connect(func():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * 1.05, 0.15)
		tween.parallel().tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.15)
	)
	button.mouse_exited.connect(func():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, 0.15)
		tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.15)
	)
