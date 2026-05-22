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
@onready var _menu_button: Button = $UILayer/MenuButton
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _leaderboard_panel: Panel = $UILayer/LeaderboardPanel
@onready var _shop_panel: ShopPopup = $UILayer/ShopPopup
var _settings_panel: Control = null

@onready var _bg_texture: TextureRect = $BackgroundLayer/BackgroundTexture
@onready var _character_layer: CanvasLayer = $CharacterLayer

var _menu_buttons: Array[BaseButton] = []

func _ready() -> void:
	print("[MainMenu] _ready 开始, continue_button=", _btn_continue != null)
	# 安全连接按钮信号（带 null 检查）
	_safe_connect_pressed(_btn_new_game, _on_new_game_pressed)
	_safe_connect_pressed(_btn_continue, _on_continue_pressed)
	_safe_connect_pressed(_btn_quit, _on_quit_pressed)
	_safe_connect_pressed(_menu_button, _on_menu_button_pressed)
	
	
	# 动态创建设置面板（添加到 UILayer 避免被背景遮挡）
	var settings_scene = load("res://scenes/settings/settings_panel.tscn")
	if settings_scene != null:
		_settings_panel = settings_scene.instantiate()
		$UILayer.add_child(_settings_panel)
		_settings_panel.visible = false
	
	# 收集左侧菜单按钮
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

	# 统一设置样式 + hover
	for btn in _menu_buttons:
		if not is_instance_valid(btn):
			continue
		_setup_button_style(btn)
		# 已有 menu_button.gd 脚本的 TextureButton 自带悬停动画，不再叠加
		if btn.get_script() == null or btn.get_script().resource_path != "res://scripts/ui/menu_button.gd":
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
		if btn_leaderboard.get_script() == null or btn_leaderboard.get_script().resource_path != "res://scripts/ui/menu_button.gd":
			_setup_button_style(btn_leaderboard)
			_setup_button_hover(btn_leaderboard)
		print("[MainMenu] 排行榜按钮已启用")
	else:
		push_warning("[MainMenu] BtnLeaderboard 未找到")
	
	# 连接设置按钮信号（样式已在 _menu_buttons 循环中应用）
	if btn_settings != null:
		_safe_connect_pressed(btn_settings, _on_settings_pressed)
		print("[MainMenu] 设置按钮已启用")
	else:
		push_warning("[MainMenu] BtnSettings 未找到")

	# 主菜单中隐藏PauseMenu的"返回主菜单"按钮
	_pause_menu.set_is_main_menu(true)

	_update_pvp_archive_display()
	
	# 调试：确认所有按钮状态
	for btn in _menu_buttons:
		if is_instance_valid(btn):
			var btn_label = btn.get("text") if btn.get("text") != null else btn.name
			print("[MainMenu] 按钮 '%s': visible=%s global_pos=%s size=%s modulate=%s" % [btn_label, btn.visible, btn.global_position, btn.size, btn.modulate])
		else:
			push_warning("[MainMenu] 按钮为 null 或无效实例")
	if is_instance_valid(_menu_button):
		print("[MainMenu] 设置按钮: visible=%s global_pos=%s size=%s" % [_menu_button.visible, _menu_button.global_position, _menu_button.size])
	else:
		push_warning("[MainMenu] 设置按钮为 null 或无效实例")
	
	
	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)

# ========== 按钮样式（暗黑霓虹）==========

const COLOR_BTN_BG := Color(0.101961, 0.101961, 0.121569, 1)
const COLOR_BTN_BG_HOVER := Color(0.145098, 0.145098, 0.188235, 1)
const COLOR_BTN_BG_PRESSED := Color(0.08, 0.08, 0.1, 1)
const COLOR_BTN_BORDER := Color(0.901961, 0.752941, 0.25098, 0.6)
const COLOR_BTN_BORDER_HOVER := Color(0.901961, 0.752941, 0.25098, 1)
const COLOR_BTN_BORDER_PRESSED := Color(0.78, 0.63, 0.18, 1)
const COLOR_BTN_TEXT := Color(0.901961, 0.752941, 0.25098, 1)
const COLOR_BTN_TEXT_DISABLED := Color(0.4, 0.4, 0.4, 1)

func _setup_button_style(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] _setup_button_style: button 为 null")
		return
	# 跳过 TextureButton：纹理按钮自带图片外观，叠加 StyleBoxFlat 会产生背景重影与边框重叠
	if button is TextureButton:
		button.add_theme_color_override("font_color", COLOR_BTN_TEXT)
		button.add_theme_color_override("font_pressed_color", COLOR_BTN_TEXT)
		button.add_theme_color_override("font_disabled_color", COLOR_BTN_TEXT_DISABLED)
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

func _setup_menu_button_hover(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] _setup_menu_button_hover: button 为 null")
		return
	button.mouse_entered.connect(func(): _on_menu_button_hover_entered(button))
	button.mouse_exited.connect(func(): _on_menu_button_hover_exited(button))

func _on_menu_button_hover_entered(button: BaseButton) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * 1.05, 0.15)
	tween.parallel().tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.15)

func _on_menu_button_hover_exited(button: BaseButton) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.15)
	tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.15)



# ========== 原有业务逻辑（保持不变）==========

func _safe_connect_pressed(button: BaseButton, callback: Callable) -> void:
	if button == null or not is_instance_valid(button):
		push_warning("[MainMenu] 尝试连接 null/无效按钮的 pressed 信号，callback=%s" % callback.get_method())
		return
	button.pressed.connect(callback)

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

func _setup_button_hover(button: BaseButton) -> void:
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
