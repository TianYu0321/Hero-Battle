## res://scenes/main_menu/menu.gd
## 模块: MenuUI
## 职责: 主菜单界面，提供开始新局/继续游戏/退出功能
## 依赖: EventBus, SaveManager, ConfigManager
## 被依赖: 无（顶层入口UI）
## class_name: MenuUI

class_name MenuUI
extends Control

@onready var _btn_new_game: BaseButton = $UILayer/MenuButtons/BtnNewGameWrapper/BtnNewGame
@onready var _btn_continue: BaseButton = $UILayer/MenuButtons/BtnContinueWrapper/BtnContinue
@onready var _btn_quit: BaseButton = $UILayer/MenuButtons/BtnQuitWrapper/BtnQuit
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _leaderboard_panel: Panel = $UILayer/LeaderboardPanel
@onready var _shop_panel: ShopPopup = $UILayer/ShopPopup
var _settings_panel: Control = null

@onready var _bg_texture: TextureRect = $BackgroundLayer/BackgroundTexture
@onready var _character_layer: CanvasLayer = $CharacterLayer
@onready var _title_label: Label = $UILayer/TitleLabel
@onready var _ambient_particles: Node2D = $BackgroundLayer/AmbientParticles

var _menu_buttons: Array[BaseButton] = []

@onready var menu_theme: Theme = preload("res://resources/themes/menu_theme.tres")

const BUTTON_TEXTS := {
	"BtnNewGame": "开始冒险",
	"BtnContinue": "继续冒险",
	"BtnSettings": "系统设置",
	"BtnQuit": "退出游戏",
	"BtnArchive": "存档",
	"BtnPVP": "PVP对战",
	"BtnShop": "商店",
	"BtnLeaderboard": "排行",
}

func _ready() -> void:
	print("[MainMenu] _ready 开始, continue_button=", _btn_continue != null)
	
	# 动态创建设置面板（添加到 UILayer 避免被背景遮挡）
	var settings_scene = load("res://scenes/settings/settings_panel.tscn")
	if settings_scene != null:
		_settings_panel = settings_scene.instantiate()
		$UILayer.add_child(_settings_panel)
		_settings_panel.visible = false
	
	# 收集菜单按钮
	_menu_buttons = [_btn_new_game, _btn_continue, _btn_quit]
	var btn_archive: BaseButton = get_node_or_null("UILayer/IconBar/BtnArchiveWrapper/BtnArchive")
	var btn_pvp: BaseButton = get_node_or_null("UILayer/IconBar/BtnPVPWrapper/BtnPVP")
	var btn_shop: BaseButton = get_node_or_null("UILayer/IconBar/BtnShopWrapper/BtnShop")
	var btn_leaderboard: BaseButton = get_node_or_null("UILayer/IconBar/BtnLeaderboardWrapper/BtnLeaderboard")
	var btn_settings: BaseButton = get_node_or_null("UILayer/MenuButtons/BtnSettingsWrapper/BtnSettings")
	if btn_archive != null: _menu_buttons.append(btn_archive)
	if btn_pvp != null: _menu_buttons.append(btn_pvp)
	if btn_shop != null: _menu_buttons.append(btn_shop)
	if btn_leaderboard != null: _menu_buttons.append(btn_leaderboard)
	if btn_settings != null: _menu_buttons.append(btn_settings)

	# 判断存档，无存档时彻底移除继续游戏按钮，让下方按钮自动补上
	var save_data = SaveManager.load_latest_run()
	var is_valid = SaveManager.is_valid_save(save_data)
	if not is_valid and _btn_continue != null:
		var wrapper = _btn_continue.get_parent()
		wrapper.get_parent().remove_child(wrapper)
		wrapper.queue_free()
		_menu_buttons.erase(_btn_continue)
		_btn_continue = null
	print("[MainMenu] 继续游戏按钮显隐: ", is_valid)

	# 标题入场动画
	_animate_title_entrance()

	# 统一设置样式 + 信号
	for btn in _menu_buttons:
		if not is_instance_valid(btn):
			continue
		_setup_button_style(btn)
		_setup_button_signals(btn)

	# 启用斗士档案按钮
	if btn_archive != null:
		btn_archive.visible = true
		btn_archive.disabled = false
		_connect_with_bounce(btn_archive, _on_archive_button_pressed)
		print("[MainMenu] 档案按钮已启用")
	else:
		push_warning("[MainMenu] BtnArchive 未找到")

	# 启用PVP对战按钮
	if btn_pvp != null:
		btn_pvp.visible = true
		btn_pvp.disabled = false
		_connect_with_bounce(btn_pvp, _on_pvp_pressed)
		print("[MainMenu] PVP按钮已启用")
	else:
		push_warning("[MainMenu] BtnPVP 未找到")

	# 启用商店按钮
	if btn_shop != null:
		btn_shop.visible = true
		btn_shop.disabled = false
		_connect_with_bounce(btn_shop, _on_shop_pressed)
		print("[MainMenu] 商店按钮已启用")
	else:
		push_warning("[MainMenu] BtnShop 未找到")

	# 启用排行榜按钮
	if btn_leaderboard != null:
		btn_leaderboard.visible = true
		btn_leaderboard.disabled = false
		_connect_with_bounce(btn_leaderboard, _on_leaderboard_pressed)
		print("[MainMenu] 排行榜按钮已启用")
	else:
		push_warning("[MainMenu] BtnLeaderboard 未找到")
	
	# 连接设置按钮信号
	if btn_settings != null:
		_connect_with_bounce(btn_settings, _on_settings_pressed)
		print("[MainMenu] 设置按钮已启用")
	else:
		push_warning("[MainMenu] BtnSettings 未找到")

	# 主菜单中隐藏PauseMenu的"返回主菜单"按钮
	_pause_menu.set_is_main_menu(true)

	_update_pvp_archive_display()
	
	# 核心菜单按钮的业务信号（带弹跳）
	_connect_with_bounce(_btn_new_game, _on_new_game_pressed)
	_connect_with_bounce(_btn_continue, _on_continue_pressed)
	_connect_with_bounce(_btn_quit, _on_quit_pressed)
	
	# 调试：确认所有按钮状态
	for btn in _menu_buttons:
		if is_instance_valid(btn):
			var btn_label = btn.get("text") if btn.get("text") != null else btn.name
			print("[MainMenu] 按钮 '%s': visible=%s global_pos=%s size=%s modulate=%s" % [btn_label, btn.visible, btn.global_position, btn.size, btn.modulate])
		else:
			push_warning("[MainMenu] 按钮为 null 或无效实例")
	
	# 氛围粒子
	_start_ambient_particles()
	
	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)


# ========== 按钮样式（明亮纸片剧场）==========

func _setup_button_style(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] _setup_button_style: button 为 null")
		return
	button.theme = menu_theme
	button.add_theme_font_size_override("font_size", 24)
	if button.name in BUTTON_TEXTS:
		button.text = BUTTON_TEXTS[button.name]


func _setup_button_signals(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.mouse_exited.connect(_on_button_unhover.bind(button))
	button.focus_entered.connect(_on_button_focus.bind(button))
	button.focus_exited.connect(_on_button_unfocus.bind(button))


func _on_button_hover(button: BaseButton) -> void:
	if button.disabled:
		return
	if button.has_meta("hover_tween"):
		var old: Tween = button.get_meta("hover_tween")
		if old != null and old.is_valid():
			old.kill()
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.02, 1.02), 0.12)
	button.set_meta("hover_tween", tween)


func _on_button_unhover(button: BaseButton) -> void:
	if button.disabled:
		return
	if button.has_meta("hover_tween"):
		var old: Tween = button.get_meta("hover_tween")
		if old != null and old.is_valid():
			old.kill()
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.15)
	button.set_meta("hover_tween", tween)


func _on_button_focus(button: BaseButton) -> void:
	if button.disabled:
		return
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.01, 1.01), 0.08)


func _on_button_unfocus(button: BaseButton) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)


func _connect_with_bounce(button: BaseButton, callback: Callable) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] 尝试连接 null/无效按钮的 pressed 信号")
		return
	button.pressed.connect(func(): _on_button_pressed_with_bounce(button, callback))


func _on_button_pressed_with_bounce(button: BaseButton, callback: Callable) -> void:
	AudioManager.play_ui("confirm")
	
	## 弹性点击动画：快速缩小 → 弹性回位
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(button, "scale", Vector2.ONE, 0.15)
	
	await tween.finished
	callback.call()


# ========== 标题动画（入场效果）==========

func _animate_title_entrance() -> void:
	## 初始状态：标题在上方 30px 外，透明度 0
	_title_label.modulate.a = 0.0
	var target_y := _title_label.position.y
	_title_label.position.y = target_y - 30
	
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.6)
	tween.parallel().tween_property(_title_label, "position:y", target_y, 0.6)


# ========== 氛围粒子 — 樱花/彩纸飘落 ==========

func _start_ambient_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.name = "SakuraParticles"
	particles.position = Vector2(960, -50)  ## 1920x1080 顶部中央
	particles.amount = 80
	particles.lifetime = 8.0
	particles.preprocess = 5.0
	particles.visibility_rect = Rect2(-200, -200, 2240, 1480)
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1200, 10, 1)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 20, 0)  ## 缓慢下落
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.angle_min = -180.0
	mat.angle_max = 180.0  ## 旋转飘落
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	mat.color = Color(1.0, 0.72, 0.77, 0.6)  ## 樱花粉
	
	## 花瓣纹理：用程序生成的小椭圆
	var petal_texture := GradientTexture2D.new()
	petal_texture.gradient = Gradient.new()
	petal_texture.gradient.colors = [Color(1, 0.8, 0.85, 0.7), Color(1, 0.7, 0.75, 0)]
	petal_texture.width = 8
	petal_texture.height = 12
	petal_texture.fill_from = Vector2(0.5, 0)
	petal_texture.fill_to = Vector2(0.5, 1)
	particles.texture = petal_texture
	
	particles.process_material = mat
	_ambient_particles.add_child(particles)
	
	## 可选：第二层白色光点（更稀疏，营造竞技场灯光尘埃感）
	var dust := GPUParticles2D.new()
	dust.name = "DustParticles"
	dust.position = Vector2(960, 0)
	dust.amount = 40
	dust.lifetime = 6.0
	dust.preprocess = 4.0
	dust.visibility_rect = Rect2(-200, -200, 2240, 1480)
	
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(1400, 10, 1)
	dust_mat.direction = Vector3(0.05, 1, 0)
	dust_mat.spread = 10.0
	dust_mat.initial_velocity_min = 20.0
	dust_mat.initial_velocity_max = 50.0
	dust_mat.gravity = Vector3(0, 10, 0)
	dust_mat.scale_min = 0.3
	dust_mat.scale_max = 0.8
	dust_mat.color = Color(1.0, 0.95, 0.85, 0.3)  ## 暖白尘埃
	
	var dust_texture := GradientTexture2D.new()
	dust_texture.gradient = Gradient.new()
	dust_texture.gradient.colors = [Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)]
	dust_texture.width = 4
	dust_texture.height = 4
	dust.texture = dust_texture
	
	dust.process_material = dust_mat
	_ambient_particles.add_child(dust)


# ========== 原有业务逻辑（保持不变）==========

func _on_new_game_pressed() -> void:
	print("[MainMenu] 【点击】开始新局")
	EventBus.new_game_requested.emit("")

func _on_continue_pressed() -> void:
	print("[MainMenu] 【点击】继续游戏, has_active_run=", SaveManager.has_active_run())
	if not SaveManager.has_active_run():
		push_error("[MainMenu] 点击继续游戏但存档无效")
		if _btn_continue != null:
			_btn_continue.visible = false
		return
	EventBus.continue_game_requested.emit()

func _on_quit_pressed() -> void:
	print("[MainMenu] 【点击】退出游戏")
	get_tree().quit()

func _on_archive_button_pressed() -> void:
	print("[MainMenu] 【点击】斗士档案")
	EventBus.archive_view_requested.emit()

func _on_pvp_pressed() -> void:
	print("[MainMenu] 【点击】PVP对战")
	EventBus.pvp_lobby_requested.emit()

func _on_shop_pressed() -> void:
	print("[MainMenu] 【点击】商店")
	_shop_panel.show_popup()

func _on_leaderboard_pressed() -> void:
	print("[MainMenu] 【点击】排行榜")
	var leaderboard_system := LeaderboardSystem.new()
	var rankings := leaderboard_system.get_leaderboard(20)
	if _leaderboard_panel != null:
		_leaderboard_panel.show_rankings(rankings)
	else:
		push_warning("[MainMenu] LeaderboardPanel 未找到")

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
	print("[MainMenu] 【点击】设置")
	AudioManager.play_ui("button_click")
	if _settings_panel != null:
		_show_panel(_settings_panel)
		_settings_panel.load_settings()
	else:
		push_warning("[MainMenu] 设置面板为 null")

func _show_panel(panel: Control) -> void:
	panel.visible = true
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
