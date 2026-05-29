class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal main_menu_requested

@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXSlider
@onready var ui_slider: HSlider = $Panel/VBoxContainer/UISlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicSlider
@onready var resolution_option: OptionButton = $Panel/VBoxContainer/ResolutionOption
@onready var fullscreen_check: CheckBox = $Panel/VBoxContainer/FullscreenCheck
@onready var shake_toggle: CheckBox = $Panel/VBoxContainer/ShakeToggle
@onready var damage_toggle: CheckBox = $Panel/VBoxContainer/DamageToggle
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var panel: Panel = $Panel

var _is_main_menu: bool = false

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
]

func _ready() -> void:
	visible = false
	
	# 初始化分辨率下拉框
	resolution_option.clear()
	for i in range(RESOLUTIONS.size()):
		var res := RESOLUTIONS[i]
		resolution_option.add_item("%d x %d" % [res.x, res.y], i)
	
	# 连接信号
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	ui_slider.value_changed.connect(_on_ui_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	shake_toggle.toggled.connect(_on_shake_toggled)
	damage_toggle.toggled.connect(_on_damage_toggled)
	resume_button.pressed.connect(_on_resume)
	main_menu_button.pressed.connect(_on_main_menu)
	
	# 加载设置
	_load_settings()

func _load_settings() -> void:
	var settings: Dictionary = SaveManager.load_settings()
	
	sfx_slider.value = settings.get("sfx_volume", 0.8)
	ui_slider.value = settings.get("ui_volume", 0.8)
	music_slider.value = settings.get("music_volume", 0.5)
	
	var res_index: int = settings.get("resolution_index", 0)
	res_index = clampi(res_index, 0, RESOLUTIONS.size() - 1)
	resolution_option.select(res_index)
	
	fullscreen_check.button_pressed = settings.get("fullscreen", false)
	shake_toggle.button_pressed = settings.get("screen_shake", true)
	damage_toggle.button_pressed = settings.get("damage_numbers", true)
	
	# 同步应用到 AudioManager
	AudioManager.set_bus_volume_linear("SFX", sfx_slider.value)
	AudioManager.set_bus_volume_linear("UI", ui_slider.value)
	AudioManager.set_bus_volume_linear("Music", music_slider.value)

func _save_settings() -> void:
	var settings: Dictionary = {
		"sfx_volume": sfx_slider.value,
		"ui_volume": ui_slider.value,
		"music_volume": music_slider.value,
		"resolution_index": resolution_option.selected,
		"fullscreen": fullscreen_check.button_pressed,
		"screen_shake": shake_toggle.button_pressed,
		"damage_numbers": damage_toggle.button_pressed
	}
	SaveManager.save_settings(settings)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume_linear("SFX", value)
	_save_settings()

func _on_ui_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume_linear("UI", value)
	_save_settings()

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume_linear("Music", value)
	_save_settings()

func _on_resolution_selected(index: int) -> void:
	var res := RESOLUTIONS[index]
	DisplayServer.window_set_size(res)
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var idx := resolution_option.selected
		if idx >= 0 and idx < RESOLUTIONS.size():
			DisplayServer.window_set_size(RESOLUTIONS[idx])
	_save_settings()

func _on_shake_toggled(enabled: bool) -> void:
	GameManager.screen_shake_enabled = enabled
	_save_settings()

func _on_damage_toggled(enabled: bool) -> void:
	GameManager.damage_numbers_enabled = enabled
	_save_settings()

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

func _on_resume() -> void:
	hide_menu()
	resume_requested.emit()

func _on_main_menu() -> void:
	hide_menu()
	main_menu_requested.emit()
