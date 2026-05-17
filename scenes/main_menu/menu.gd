## res://scenes/main_menu/menu.gd
## 模块: MenuUI
## 职责: 主菜单界面，提供开始新局/继续游戏/退出功能
## 依赖: EventBus, SaveManager, ConfigManager
## 被依赖: 无（顶层入口UI）
## class_name: MenuUI

class_name MenuUI
extends Control

@onready var _btn_new_game: Button = %BtnNewGame
@onready var _btn_continue: Button = %BtnContinue
@onready var _btn_quit: Button = %BtnQuit
@onready var _menu_button: Button = $MenuButton
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _leaderboard_panel: Panel = $LeaderboardPanel
@onready var _shop_panel: ShopPopup = $ShopPopup
var _settings_panel: Control = null

@onready var _bg_texture: TextureRect = $BackgroundLayer/BackgroundTexture
@onready var _floor_light: ColorRect = $BackgroundLayer/FloorLightOverlay
@onready var _rain_parent: Node2D = $BackgroundLayer/RainParent
@onready var _character_layer: CanvasLayer = $CharacterLayer

var _fx_config: Dictionary = {}

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
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	_menu_button.pressed.connect(_on_menu_button_pressed)
	
	# 加载动态效果配置
	_load_fx_config()
	_apply_fx_config()
	
	# 动态创建设置面板
	var settings_scene = load("res://scenes/settings/settings_panel.tscn")
	if settings_scene != null:
		_settings_panel = settings_scene.instantiate()
		add_child(_settings_panel)
		_settings_panel.visible = false
	
	# 设置按钮悬停动画
	_setup_button_hover(_btn_new_game)
	_setup_button_hover(_btn_continue)
	_setup_button_hover(_btn_quit)
	_setup_button_hover(_menu_button)

	# 启用斗士档案按钮
	var btn_archive: Button = get_node_or_null("%BtnArchive")
	if btn_archive != null:
		btn_archive.visible = true
		btn_archive.disabled = false
		btn_archive.pressed.connect(_on_archive_button_pressed)
		print("[MainMenu] 档案按钮已启用")
	else:
		push_warning("[MainMenu] BtnArchive 未找到")

	# 启用PVP对战按钮
	var btn_pvp: Button = get_node_or_null("%BtnPVP")
	if btn_pvp != null:
		btn_pvp.visible = true
		btn_pvp.disabled = false
		btn_pvp.pressed.connect(_on_pvp_pressed)
		print("[MainMenu] PVP按钮已启用")
	else:
		push_warning("[MainMenu] BtnPVP 未找到")

	# 启用商店按钮
	var btn_shop: Button = get_node_or_null("%BtnShop")
	if btn_shop != null:
		btn_shop.visible = true
		btn_shop.disabled = false
		btn_shop.pressed.connect(_on_shop_pressed)
		print("[MainMenu] 商店按钮已启用")
	else:
		push_warning("[MainMenu] BtnShop 未找到")

	# 启用排行榜按钮
	var btn_leaderboard: Button = get_node_or_null("%BtnLeaderboard")
	if btn_leaderboard != null:
		btn_leaderboard.visible = true
		btn_leaderboard.disabled = false
		btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
		_setup_button_hover(btn_leaderboard)
		print("[MainMenu] 排行榜按钮已启用")
	else:
		push_warning("[MainMenu] BtnLeaderboard 未找到")
	
	# 启用设置按钮
	var btn_settings: Button = get_node_or_null("%BtnSettings")
	if btn_settings != null:
		btn_settings.visible = true
		btn_settings.disabled = false
		btn_settings.pressed.connect(_on_settings_pressed)
		_setup_button_hover(btn_settings)
		print("[MainMenu] 设置按钮已启用")
	else:
		push_warning("[MainMenu] BtnSettings 未找到")

	# 主菜单中隐藏PauseMenu的"返回主菜单"按钮
	_pause_menu.set_is_main_menu(true)

	var save_data = SaveManager.load_latest_run()
	var is_valid = SaveManager.is_valid_save(save_data)
	_btn_continue.visible = is_valid
	print("[MainMenu] 继续游戏按钮显隐: ", is_valid)

	_update_pvp_archive_display()

	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)

func _load_fx_config() -> void:
	_fx_config = ConfigManager._load_json_safe(FX_CONFIG_PATH, {})
	if _fx_config.is_empty():
		push_warning("[MainMenu] 菜单特效配置文件未找到或为空，使用硬编码默认值")
		_fx_config = _get_default_fx_config()

func _get_default_fx_config() -> Dictionary:
	return {
		"background": {
			"texture_path": "res://assets/backgrounds/menu_bg.png",
			"stretch_mode": "keep_aspect",
			"camera_breath": {
				"enabled": true,
				"pivot_offset": [960, 540],
				"primary": {
					"scale_min": [1.0, 1.0],
					"scale_max": [1.025, 1.025],
					"cycle_seconds": 7.0,
					"trans": "sine",
					"ease": "in_out"
				},
				"secondary": {
					"scale_delta": 0.004,
					"cycle_seconds": 2.1,
					"trans": "sine",
					"ease": "in_out"
				},
				"jitter": {
					"enabled": true,
					"intensity_degrees": 0.15,
					"interval_min": 3.0,
					"interval_max": 8.0,
					"duration": 0.4,
					"trans": "quad",
					"ease": "out"
				}
			}
		},
		"rain": {
			"enabled": true,
			"near": {
				"position": [960, -100],
				"amount": 300,
				"lifetime": 1.2,
				"preprocess": 2.0,
				"visibility_rect": [-200, -200, 2240, 1480],
				"emission_box_extents": [1200, 10, 1],
				"direction": [0.15, 1, 0],
				"spread": 2.0,
				"velocity_min": 500.0,
				"velocity_max": 700.0,
				"gravity": [0, 800, 0],
				"scale_min": 1.0,
				"scale_max": 2.0,
				"color": [0.55, 0.65, 0.75, 0.35],
				"drop_gradient_colors": [[1, 1, 1, 0.6], [1, 1, 1, 0]],
				"drop_width": 2,
				"drop_height": 24,
				"drop_fill_from": [0.5, 0],
				"drop_fill_to": [0.5, 1]
			},
			"far": {
				"position": [960, -50],
				"amount": 400,
				"lifetime": 2.0,
				"preprocess": 3.0,
				"visibility_rect": [-200, -200, 2240, 1480],
				"emission_box_extents": [1400, 10, 1],
				"direction": [0.1, 1, 0],
				"spread": 5.0,
				"velocity_min": 300.0,
				"velocity_max": 450.0,
				"gravity": [0, 500, 0],
				"scale_min": 0.5,
				"scale_max": 1.0,
				"color": [0.45, 0.50, 0.60, 0.15],
				"drop_gradient_colors": [[1, 1, 1, 0.3], [1, 1, 1, 0]],
				"drop_width": 1,
				"drop_height": 16,
				"drop_fill_from": [0.5, 0],
				"drop_fill_to": [0.5, 1]
			}
		},
		"floor_light": {
			"enabled": true,
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
		"character": {
			"enabled": false,
			"sprite_path": "",
			"position": [1400, 540],
			"scale": 0.8,
			"float": {
				"range": 5,
				"cycle_seconds": 4.5,
				"trans": "sine",
				"ease": "in_out"
			},
			"breath": {
				"scale_min": 0.785,
				"scale_max": 0.815,
				"cycle_seconds": 3.2,
				"overshoot": 0.003,
				"trans": "back",
				"ease": "in_out"
			},
			"shadow": {
				"alpha_min": 0.25,
				"alpha_max": 0.40,
				"cycle_seconds": 3.2,
				"trans": "sine",
				"ease": "in_out"
			}
		}
	}

func _apply_fx_config() -> void:
	var bg_cfg: Dictionary = _fx_config.get("background", {})
	
	# 应用背景图设置
	var tex_path: String = bg_cfg.get("texture_path", "res://assets/backgrounds/menu_bg.png")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		_bg_texture.texture = load(tex_path)
	
	var mode_str: String = bg_cfg.get("stretch_mode", "keep_aspect")
	_bg_texture.stretch_mode = STRETCH_MODE_MAP.get(mode_str, TextureRect.STRETCH_KEEP_ASPECT)
	
	# 动态效果
	var rain_cfg: Dictionary = _fx_config.get("rain", {})
	if rain_cfg.get("enabled", true):
		_start_rain()
	
	var floor_cfg: Dictionary = _fx_config.get("floor_light", {})
	if floor_cfg.get("enabled", true):
		_start_floor_pulse()
	
	if bg_cfg.get("camera_breath", {}).get("enabled", true):
		_start_camera_breath()
	
	var char_cfg: Dictionary = _fx_config.get("character", {})
	if char_cfg.get("enabled", false):
		var sp: String = char_cfg.get("sprite_path", "")
		var pos_arr: Array = char_cfg.get("position", [1400, 540])
		if not sp.is_empty():
			_add_character_with_breath(sp, Vector2(pos_arr[0], pos_arr[1]))

func _on_new_game_pressed() -> void:
	EventBus.new_game_requested.emit("")

func _on_continue_pressed() -> void:
	print("[MainMenu] 继续游戏点击, has_active_run=", SaveManager.has_active_run())
	if not SaveManager.has_active_run():
		push_error("[MainMenu] 点击继续游戏但存档无效")
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
	_btn_continue.visible = true

func _on_load_failed(_error_code: int, _error_message: String, _save_slot: int) -> void:
	_btn_continue.visible = false

func _enter_tree() -> void:
	if _btn_continue:
		var has_save = SaveManager.has_active_run()
		_btn_continue.visible = has_save
		print("[MainMenu] _enter_tree 重新检查存档: ", has_save)

func _update_pvp_archive_display() -> void:
	var archive := GameManager.get_pvp_archive()
	var hint_label: Label = get_node_or_null("PVPHintLabel")
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


# ========== 动态背景效果（配置驱动）==========

func _start_rain() -> void:
	var rain_cfg: Dictionary = _fx_config.get("rain", {})
	var near_cfg: Dictionary = rain_cfg.get("near", {})
	var far_cfg: Dictionary = rain_cfg.get("far", {})
	
	# 第一层：近景大雨滴
	var rain_near := GPUParticles2D.new()
	rain_near.name = "RainNear"
	var near_pos: Array = near_cfg.get("position", [960, -100])
	rain_near.position = Vector2(near_pos[0], near_pos[1])
	rain_near.amount = near_cfg.get("amount", 300)
	rain_near.lifetime = near_cfg.get("lifetime", 1.2)
	rain_near.preprocess = near_cfg.get("preprocess", 2.0)
	var near_vr: Array = near_cfg.get("visibility_rect", [-200, -200, 2240, 1480])
	rain_near.visibility_rect = Rect2(near_vr[0], near_vr[1], near_vr[2], near_vr[3])
	
	var mat_near := ParticleProcessMaterial.new()
	mat_near.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var near_ee: Array = near_cfg.get("emission_box_extents", [1200, 10, 1])
	mat_near.emission_box_extents = Vector3(near_ee[0], near_ee[1], near_ee[2])
	var near_dir: Array = near_cfg.get("direction", [0.15, 1, 0])
	mat_near.direction = Vector3(near_dir[0], near_dir[1], near_dir[2])
	mat_near.spread = near_cfg.get("spread", 2.0)
	mat_near.initial_velocity_min = near_cfg.get("velocity_min", 500.0)
	mat_near.initial_velocity_max = near_cfg.get("velocity_max", 700.0)
	var near_grav: Array = near_cfg.get("gravity", [0, 800, 0])
	mat_near.gravity = Vector3(near_grav[0], near_grav[1], near_grav[2])
	mat_near.scale_min = near_cfg.get("scale_min", 1.0)
	mat_near.scale_max = near_cfg.get("scale_max", 2.0)
	var near_col: Array = near_cfg.get("color", [0.55, 0.65, 0.75, 0.35])
	mat_near.color = Color(near_col[0], near_col[1], near_col[2], near_col[3])
	rain_near.process_material = mat_near
	
	var drop_texture_near := GradientTexture2D.new()
	drop_texture_near.gradient = Gradient.new()
	var near_grad: Array = near_cfg.get("drop_gradient_colors", [[1,1,1,0.6], [1,1,1,0]])
	drop_texture_near.gradient.colors = [
		Color(near_grad[0][0], near_grad[0][1], near_grad[0][2], near_grad[0][3]),
		Color(near_grad[1][0], near_grad[1][1], near_grad[1][2], near_grad[1][3])
	]
	drop_texture_near.width = near_cfg.get("drop_width", 2)
	drop_texture_near.height = near_cfg.get("drop_height", 24)
	var near_ff: Array = near_cfg.get("drop_fill_from", [0.5, 0])
	var near_ft: Array = near_cfg.get("drop_fill_to", [0.5, 1])
	drop_texture_near.fill_from = Vector2(near_ff[0], near_ff[1])
	drop_texture_near.fill_to = Vector2(near_ft[0], near_ft[1])
	rain_near.texture = drop_texture_near
	
	_rain_parent.add_child(rain_near)
	
	# 第二层：远景小雨滴
	var rain_far := GPUParticles2D.new()
	rain_far.name = "RainFar"
	var far_pos: Array = far_cfg.get("position", [960, -50])
	rain_far.position = Vector2(far_pos[0], far_pos[1])
	rain_far.amount = far_cfg.get("amount", 400)
	rain_far.lifetime = far_cfg.get("lifetime", 2.0)
	rain_far.preprocess = far_cfg.get("preprocess", 3.0)
	var far_vr: Array = far_cfg.get("visibility_rect", [-200, -200, 2240, 1480])
	rain_far.visibility_rect = Rect2(far_vr[0], far_vr[1], far_vr[2], far_vr[3])
	
	var mat_far := ParticleProcessMaterial.new()
	mat_far.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var far_ee: Array = far_cfg.get("emission_box_extents", [1400, 10, 1])
	mat_far.emission_box_extents = Vector3(far_ee[0], far_ee[1], far_ee[2])
	var far_dir: Array = far_cfg.get("direction", [0.1, 1, 0])
	mat_far.direction = Vector3(far_dir[0], far_dir[1], far_dir[2])
	mat_far.spread = far_cfg.get("spread", 5.0)
	mat_far.initial_velocity_min = far_cfg.get("velocity_min", 300.0)
	mat_far.initial_velocity_max = far_cfg.get("velocity_max", 450.0)
	var far_grav: Array = far_cfg.get("gravity", [0, 500, 0])
	mat_far.gravity = Vector3(far_grav[0], far_grav[1], far_grav[2])
	mat_far.scale_min = far_cfg.get("scale_min", 0.5)
	mat_far.scale_max = far_cfg.get("scale_max", 1.0)
	var far_col: Array = far_cfg.get("color", [0.45, 0.50, 0.60, 0.15])
	mat_far.color = Color(far_col[0], far_col[1], far_col[2], far_col[3])
	rain_far.process_material = mat_far
	
	var drop_texture_far := GradientTexture2D.new()
	drop_texture_far.gradient = Gradient.new()
	var far_grad: Array = far_cfg.get("drop_gradient_colors", [[1,1,1,0.3], [1,1,1,0]])
	drop_texture_far.gradient.colors = [
		Color(far_grad[0][0], far_grad[0][1], far_grad[0][2], far_grad[0][3]),
		Color(far_grad[1][0], far_grad[1][1], far_grad[1][2], far_grad[1][3])
	]
	drop_texture_far.width = far_cfg.get("drop_width", 1)
	drop_texture_far.height = far_cfg.get("drop_height", 16)
	var far_ff: Array = far_cfg.get("drop_fill_from", [0.5, 0])
	var far_ft: Array = far_cfg.get("drop_fill_to", [0.5, 1])
	drop_texture_far.fill_from = Vector2(far_ff[0], far_ff[1])
	drop_texture_far.fill_to = Vector2(far_ft[0], far_ft[1])
	rain_far.texture = drop_texture_far
	
	_rain_parent.add_child(rain_far)


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


# ========== 动态背景效果（配置驱动 + Tween 丝滑）==========

func _start_floor_pulse() -> void:
	var floor_cfg: Dictionary = _fx_config.get("floor_light", {})
	
	# 应用锚点和颜色
	_floor_light.anchor_top = floor_cfg.get("anchor_top", 0.75)
	var col_arr: Array = floor_cfg.get("color", [0.90, 0.75, 0.35, 0.05])
	var base_color := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
	_floor_light.color = base_color
	
	var alpha_min: float = floor_cfg.get("pulse_alpha_min", 0.03)
	var alpha_max: float = floor_cfg.get("pulse_alpha_max", 0.14)
	var hold: float = floor_cfg.get("hold_peak_seconds", 0.6)
	var fade_in: float = floor_cfg.get("fade_in_seconds", 2.2)
	var fade_out: float = floor_cfg.get("fade_out_seconds", 2.8)
	var trans_in: int = _get_trans(floor_cfg.get("trans_in", "cubic"))
	var ease_in: int = _get_ease(floor_cfg.get("ease_in", "out"))
	var trans_out: int = _get_trans(floor_cfg.get("trans_out", "sine"))
	var ease_out: int = _get_ease(floor_cfg.get("ease_out", "in"))
	
	# 颜色呼吸
	var warm_arr: Array = floor_cfg.get("color_warm", [0.92, 0.70, 0.30, 0.06])
	var cool_arr: Array = floor_cfg.get("color_cool", [0.82, 0.78, 0.45, 0.04])
	var warm := Color(warm_arr[0], warm_arr[1], warm_arr[2], warm_arr[3])
	var cool := Color(cool_arr[0], cool_arr[1], cool_arr[2], cool_arr[3])
	
	# 三段式：淡入(慢起)→保持峰值→淡出(慢收)
	var tween := create_tween().set_loops()
	tween.set_trans(trans_in).set_ease(ease_in)
	tween.tween_property(_floor_light, "modulate:a", alpha_max, fade_in)
	tween.parallel().tween_property(_floor_light, "color", warm, fade_in)
	if hold > 0:
		tween.tween_interval(hold)
	tween.set_trans(trans_out).set_ease(ease_out)
	tween.tween_property(_floor_light, "modulate:a", alpha_min, fade_out)
	tween.parallel().tween_property(_floor_light, "color", cool, fade_out)


func _start_camera_breath() -> void:
	var breath_cfg: Dictionary = _fx_config.get("background", {}).get("camera_breath", {})
	var pivot: Array = breath_cfg.get("pivot_offset", [960, 540])
	_bg_texture.pivot_offset = Vector2(pivot[0], pivot[1])
	
	# 主呼吸：大幅慢周期
	var pri: Dictionary = breath_cfg.get("primary", {})
	var pri_min: Array = pri.get("scale_min", [1.0, 1.0])
	var pri_max: Array = pri.get("scale_max", [1.025, 1.025])
	var pri_cycle: float = pri.get("cycle_seconds", 7.0)
	var pri_trans: int = _get_trans(pri.get("trans", "sine"))
	var pri_ease: int = _get_ease(pri.get("ease", "in_out"))
	
	var pri_tween := create_tween().set_loops()
	pri_tween.set_trans(pri_trans).set_ease(pri_ease)
	pri_tween.tween_property(_bg_texture, "scale", Vector2(pri_max[0], pri_max[1]), pri_cycle * 0.5)
	pri_tween.tween_property(_bg_texture, "scale", Vector2(pri_min[0], pri_min[1]), pri_cycle * 0.5)
	
	# 次呼吸：小幅快周期，叠加在主呼吸上
	var sec: Dictionary = breath_cfg.get("secondary", {})
	var sec_delta: float = sec.get("scale_delta", 0.004)
	var sec_cycle: float = sec.get("cycle_seconds", 2.1)
	var sec_trans: int = _get_trans(sec.get("trans", "sine"))
	var sec_ease: int = _get_ease(sec.get("ease", "in_out"))
	
	var sec_tween := create_tween().set_loops()
	sec_tween.set_trans(sec_trans).set_ease(sec_ease)
	sec_tween.tween_property(_bg_texture, "scale", Vector2.ONE + Vector2(sec_delta, sec_delta), sec_cycle * 0.5)
	sec_tween.tween_property(_bg_texture, "scale", Vector2.ONE - Vector2(sec_delta, sec_delta), sec_cycle * 0.5)
	
	# 微抖动：随机间隔，模拟手持感
	var jit: Dictionary = breath_cfg.get("jitter", {})
	if jit.get("enabled", true):
		_jitter_loop(jit)

func _jitter_loop(jit_cfg: Dictionary) -> void:
	var intensity: float = jit_cfg.get("intensity_degrees", 0.15)
	var interval_min: float = jit_cfg.get("interval_min", 3.0)
	var interval_max: float = jit_cfg.get("interval_max", 8.0)
	var dur: float = jit_cfg.get("duration", 0.4)
	var trans: int = _get_trans(jit_cfg.get("trans", "quad"))
	var ease: int = _get_ease(jit_cfg.get("ease", "out"))
	
	var base_rot: float = _bg_texture.rotation
	var dir: int = 1 if randf() > 0.5 else -1
	
	var tween := create_tween()
	tween.set_trans(trans).set_ease(ease)
	tween.tween_property(_bg_texture, "rotation", base_rot + intensity * dir, dur * 0.5)
	tween.tween_property(_bg_texture, "rotation", base_rot - intensity * dir * 0.5, dur * 0.5)
	tween.tween_property(_bg_texture, "rotation", base_rot, dur * 0.3)
	
	tween.finished.connect(func():
		var wait: float = randf_range(interval_min, interval_max)
		get_tree().create_timer(wait).timeout.connect(func():
			_jitter_loop(jit_cfg)
		)
	)


func _add_character_with_breath(sprite_path: String, pos: Vector2) -> void:
	var char_cfg: Dictionary = _fx_config.get("character", {})
	var base_scale: float = char_cfg.get("scale", 0.8)
	
	var float_cfg: Dictionary = char_cfg.get("float", {})
	var float_range: float = float_cfg.get("range", 5)
	var float_cycle: float = float_cfg.get("cycle_seconds", 4.5)
	var float_trans: int = _get_trans(float_cfg.get("trans", "sine"))
	var float_ease: int = _get_ease(float_cfg.get("ease", "in_out"))
	
	var breath_cfg: Dictionary = char_cfg.get("breath", {})
	var breath_min: float = breath_cfg.get("scale_min", 0.785)
	var breath_max: float = breath_cfg.get("scale_max", 0.815)
	var breath_cycle: float = breath_cfg.get("cycle_seconds", 3.2)
	var overshoot: float = breath_cfg.get("overshoot", 0.003)
	var breath_trans: int = _get_trans(breath_cfg.get("trans", "back"))
	var breath_ease: int = _get_ease(breath_cfg.get("ease", "in_out"))
	
	var sprite := Sprite2D.new()
	sprite.texture = load(sprite_path)
	sprite.position = pos
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.name = "CharacterSprite"
	_character_layer.add_child(sprite)
	
	# 浮动：Sine InOut 丝滑上下
	var float_tween := create_tween().set_loops()
	float_tween.set_trans(float_trans).set_ease(float_ease)
	float_tween.tween_property(sprite, "position:y", pos.y - float_range, float_cycle * 0.5)
	float_tween.tween_property(sprite, "position:y", pos.y + float_range, float_cycle * 0.5)
	
	# 缩放呼吸：Back 轻微过冲，更有生命力
	var scale_tween := create_tween().set_loops()
	scale_tween.set_trans(breath_trans).set_ease(breath_ease)
	scale_tween.tween_property(sprite, "scale", Vector2(breath_max + overshoot, breath_max + overshoot), breath_cycle * 0.5)
	scale_tween.tween_property(sprite, "scale", Vector2(breath_min, breath_min), breath_cycle * 0.5)
	
	# 阴影呼吸（如果有子节点阴影）
	var shadow_cfg: Dictionary = char_cfg.get("shadow", {})
	var shadow: Node = sprite.get_node_or_null("Shadow")
	if shadow != null and shadow is CanvasItem:
		var s_alpha_min: float = shadow_cfg.get("alpha_min", 0.25)
		var s_alpha_max: float = shadow_cfg.get("alpha_max", 0.40)
		var s_cycle: float = shadow_cfg.get("cycle_seconds", 3.2)
		var s_trans: int = _get_trans(shadow_cfg.get("trans", "sine"))
		var s_ease: int = _get_ease(shadow_cfg.get("ease", "in_out"))
		
		var s_tween := create_tween().set_loops()
		s_tween.set_trans(s_trans).set_ease(s_ease)
		s_tween.tween_property(shadow, "modulate:a", s_alpha_max, s_cycle * 0.5)
		s_tween.tween_property(shadow, "modulate:a", s_alpha_min, s_cycle * 0.5)
