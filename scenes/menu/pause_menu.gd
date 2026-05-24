class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal main_menu_requested

@onready var volume_slider: HSlider = $Panel/VolumeSlider
@onready var fullscreen_check: CheckBox = $Panel/FullscreenCheck
@onready var resume_button: Button = $Panel/ResumeButton
@onready var main_menu_button: Button = $Panel/MainMenuButton
@onready var panel: Panel = $Panel

var _is_main_menu: bool = false
var _font_cn: Font = preload(RunMainSettings.FONT_CN_PATH)

func _ready() -> void:
	visible = false
	var db = AudioServer.get_bus_volume_db(0)
	volume_slider.value = db_to_linear(db) * 100.0 if AudioServer else 50.0
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	resume_button.pressed.connect(_on_resume)
	main_menu_button.pressed.connect(_on_main_menu)
	
	_init_styles()
	_apply_font_recursive(self)


func _init_styles() -> void:
	## Panel 羊皮纸弹窗样式
	var parchment := RunMainSettings.create_parchment_flat_style(RunMainSettings.CORNER_PARCHMENT)
	panel.add_theme_stylebox_override("panel", parchment)
	
	## 按钮样式
	_apply_wood_button_style(resume_button)
	_apply_parchment_button_style(main_menu_button)
	
	## 标题加木牌样式（用 PanelContainer 包裹标题）
	var title: Label = $Panel/TitleLabel
	title.add_theme_font_override("font", _font_cn)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	
	## 音量/全屏标签
	var vol_label: Label = $Panel/VolumeLabel
	vol_label.add_theme_font_override("font", _font_cn)
	vol_label.add_theme_color_override("font_color", RunMainSettings.COLOR_WOOD_MEDIUM)
	fullscreen_check.add_theme_font_override("font", _font_cn)


func _apply_wood_button_style(btn: Button) -> void:
	var normal := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_PANEL,
		RunMainSettings.COLOR_WOOD_MEDIUM, 2,
		RunMainSettings.CORNER_WOOD
	)
	var hover := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_LIGHT,
		RunMainSettings.COLOR_GOLD, 2,
		RunMainSettings.CORNER_WOOD
	)
	var pressed := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_MEDIUM,
		RunMainSettings.COLOR_WOOD_DARK, 3,
		RunMainSettings.CORNER_WOOD
	)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	btn.add_theme_color_override("font_hover_color", RunMainSettings.COLOR_INK)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_override("font", _font_cn)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size.y = RunMainSettings.BUTTON_HEIGHT


func _apply_parchment_button_style(btn: Button) -> void:
	var normal := RunMainSettings.create_parchment_flat_style(RunMainSettings.CORNER_WOOD)
	var hover := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_PARCHMENT_DARK,
		RunMainSettings.COLOR_GOLD, 2,
		RunMainSettings.CORNER_WOOD
	)
	var pressed := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_PANEL,
		RunMainSettings.COLOR_WOOD_DARK, 3,
		RunMainSettings.CORNER_WOOD
	)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	btn.add_theme_color_override("font_hover_color", RunMainSettings.COLOR_INK)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_override("font", _font_cn)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size.y = RunMainSettings.BUTTON_HEIGHT


func _apply_font_recursive(node: Node) -> void:
	if node is Label or node is Button:
		node.add_theme_font_override("font", _font_cn)
	for child in node.get_children():
		_apply_font_recursive(child)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume()

func set_is_main_menu(value: bool) -> void:
	_is_main_menu = value
	main_menu_button.visible = not _is_main_menu

func show_menu() -> void:
	visible = true
	get_tree().paused = true
	_play_entrance_animation()

func hide_menu() -> void:
	_play_exit_animation(func():
		visible = false
		get_tree().paused = false
	)

func _kill_panel_tween() -> void:
	if panel.has_meta("panel_tween"):
		var old: Tween = panel.get_meta("panel_tween")
		if old != null and old.is_valid():
			old.kill()
		panel.remove_meta("panel_tween")

func _play_entrance_animation() -> void:
	_kill_panel_tween()
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
	panel.set_meta("panel_tween", tween)

func _play_exit_animation(on_finished: Callable) -> void:
	_kill_panel_tween()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.2)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(on_finished)
	panel.set_meta("panel_tween", tween)

func _on_volume_changed(value: float) -> void:
	var vol = value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(vol))

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_resume() -> void:
	hide_menu()
	resume_requested.emit()

func _on_main_menu() -> void:
	hide_menu()
	main_menu_requested.emit()
