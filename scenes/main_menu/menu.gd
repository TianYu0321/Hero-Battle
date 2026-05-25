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
@onready var _menu_buttons_container: VBoxContainer = $UILayer/MenuButtons
@onready var _icon_bar: HBoxContainer = $UILayer/IconBar
@onready var _transition_overlay: ColorRect = $TransitionOverlay

var _menu_buttons: Array[BaseButton] = []
var _sub_menu: Control = null

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
	# 加载可爱字体
	var font_cn: FontFile = load("res://assets/fonts/cute/ZCOOLKuaiLe-Regular.ttf")
	var font_en: FontFile = load("res://assets/fonts/cute/FredokaOne-Regular.ttf")
	if font_cn == null:
		push_error("[MainMenu] 中文字体加载失败")
	if font_en == null:
		push_error("[MainMenu] 英文字体加载失败")
	
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
	
	# 入场动画
	_play_entrance_animation()
	
	# 氛围粒子
	_start_ambient_particles()
	
	# 下雨效果 + 镜头呼吸
	_start_rain()
	_start_camera_breath()
	
	# 应用可爱字体
	_apply_fonts_recursive(self, font_cn)
	print("[MainMenu] 字体已应用: cn=", font_cn != null, " en=", font_en != null)
	
	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)


func _apply_fonts_recursive(node: Node, font: FontFile) -> void:
	if font == null:
		return
	for child in node.get_children():
		if child is Label or child is BaseButton:
			child.add_theme_font_override("font", font)
		if child.get_child_count() > 0:
			_apply_fonts_recursive(child, font)

# ========== 按钮样式（明亮卡片风格）==========

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
	
	## 弹性点击动画：快速缩小 → 弹性回位（Fire and Forget，不阻塞交互）
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(button, "scale", Vector2.ONE, 0.15)
	
	## 立即执行回调，不等动画完成
	callback.call()


# ========== 入场动画（参考高分项目）==========

func _play_entrance_animation() -> void:
	## 参与入场的UI元素
	var elements: Array[Control] = [_title_label, _menu_buttons_container, _icon_bar]
	for el in elements:
		if el == null:
			continue
		el.modulate.a = 0.0
		el.position.y += 30
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(elements.size()):
		if elements[i] == null:
			continue
		var delay := i * 0.06
		if i == 0:
			tween.tween_property(elements[i], "modulate:a", 1.0, 0.3).set_delay(delay)
		else:
			tween.parallel().tween_property(elements[i], "modulate:a", 1.0, 0.3).set_delay(delay)
		tween.parallel().tween_property(elements[i], "position:y", elements[i].position.y - 30, 0.35).set_delay(delay)


# ========== 面板样式（参考高分项目）==========

func _create_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.95)
	s.border_color = Color(0.9, 0.9, 0.9, 1)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	s.shadow_color = Color(0, 0, 0, 0.12)
	s.shadow_size = 15
	s.shadow_offset = Vector2(0, 8)
	return s


# ========== 子菜单系统（参考 Maaack 封装）==========

func open_sub_menu(scene: PackedScene) -> void:
	if _sub_menu != null:
		_sub_menu.queue_free()
	_sub_menu = scene.instantiate()
	add_child(_sub_menu)
	$UILayer.hide()
	_sub_menu.tree_exiting.connect(close_sub_menu, CONNECT_ONE_SHOT)


func close_sub_menu() -> void:
	if _sub_menu == null:
		return
	_sub_menu.queue_free()
	_sub_menu = null
	$UILayer.show()


# ========== 氛围粒子 — 樱花/尘埃 ==========

func _start_ambient_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.name = "SakuraParticles"
	particles.position = Vector2(960, -50)
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
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	mat.color = Color(1.0, 0.72, 0.77, 0.4)  ## 樱花粉，降低透明度适配明亮背景
	
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
	
	## 第二层白色光点（更稀疏，营造竞技场灯光尘埃感）
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
	dust_mat.color = Color(1.0, 0.95, 0.85, 0.25)  ## 暖白尘埃
	
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
	
	# 淡米白遮罩过渡（Fire and Forget，不阻塞信号发射）
	_transition_overlay.visible = true
	_transition_overlay.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, 0.4)
	
	# 立即发射信号，由 GameManager 统一处理场景切换
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


func _start_rain() -> void:
	## 动态创建雨滴父节点
	var rain_parent := Node2D.new()
	rain_parent.name = "RainParent"
	$BackgroundLayer.add_child(rain_parent)
	
	## 第一层：近景大雨滴
	var rain_near := GPUParticles2D.new()
	rain_near.name = "RainNear"
	rain_near.position = Vector2(960, -100)
	rain_near.amount = 300
	rain_near.lifetime = 1.2
	rain_near.preprocess = 2.0
	rain_near.visibility_rect = Rect2(-200, -200, 2240, 1480)
	
	var mat_near := ParticleProcessMaterial.new()
	mat_near.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_near.emission_box_extents = Vector3(1200, 10, 1)
	mat_near.direction = Vector3(0.15, 1, 0)
	mat_near.spread = 2.0
	mat_near.initial_velocity_min = 500.0
	mat_near.initial_velocity_max = 700.0
	mat_near.gravity = Vector3(0, 800, 0)
	mat_near.scale_min = 1.0
	mat_near.scale_max = 2.0
	mat_near.color = Color(0.55, 0.65, 0.75, 0.35)
	rain_near.process_material = mat_near
	
	var drop_texture_near := GradientTexture2D.new()
	drop_texture_near.gradient = Gradient.new()
	drop_texture_near.gradient.colors = [Color(1,1,1,0.6), Color(1,1,1,0)]
	drop_texture_near.width = 2
	drop_texture_near.height = 24
	drop_texture_near.fill_from = Vector2(0.5, 0)
	drop_texture_near.fill_to = Vector2(0.5, 1)
	rain_near.texture = drop_texture_near
	
	rain_parent.add_child(rain_near)
	
	## 第二层：远景小雨滴（更淡更细）
	var rain_far := GPUParticles2D.new()
	rain_far.name = "RainFar"
	rain_far.position = Vector2(960, -50)
	rain_far.amount = 400
	rain_far.lifetime = 2.0
	rain_far.preprocess = 3.0
	rain_far.visibility_rect = Rect2(-200, -200, 2240, 1480)
	
	var mat_far := ParticleProcessMaterial.new()
	mat_far.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_far.emission_box_extents = Vector3(1400, 10, 1)
	mat_far.direction = Vector3(0.1, 1, 0)
	mat_far.spread = 5.0
	mat_far.initial_velocity_min = 300.0
	mat_far.initial_velocity_max = 450.0
	mat_far.gravity = Vector3(0, 500, 0)
	mat_far.scale_min = 0.5
	mat_far.scale_max = 1.0
	mat_far.color = Color(0.45, 0.50, 0.60, 0.15)
	rain_far.process_material = mat_far
	
	var drop_texture_far := GradientTexture2D.new()
	drop_texture_far.gradient = Gradient.new()
	drop_texture_far.gradient.colors = [Color(1,1,1,0.3), Color(1,1,1,0)]
	drop_texture_far.width = 1
	drop_texture_far.height = 16
	drop_texture_far.fill_from = Vector2(0.5, 0)
	drop_texture_far.fill_to = Vector2(0.5, 1)
	rain_far.texture = drop_texture_far
	
	rain_parent.add_child(rain_far)


func _start_camera_breath() -> void:
	## 背景轻微缩放呼吸（6秒周期）
	if _bg_texture == null:
		return
	_bg_texture.pivot_offset = Vector2(960, 540)
	var tween := create_tween().set_loops()
	tween.tween_property(_bg_texture, "scale", Vector2(1.02, 1.02), 6.0)
	tween.tween_property(_bg_texture, "scale", Vector2(1.0, 1.0), 6.0)
