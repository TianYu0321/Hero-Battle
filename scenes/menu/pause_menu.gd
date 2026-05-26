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

func _ready() -> void:
	visible = false
	var db = AudioServer.get_bus_volume_db(0)
	volume_slider.value = db_to_linear(db) * 100.0 if AudioServer else 50.0
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	resume_button.pressed.connect(_on_resume)
	main_menu_button.pressed.connect(_on_main_menu)
	


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
