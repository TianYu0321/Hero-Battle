class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal main_menu_requested

@onready var volume_slider: HSlider = $Panel/VolumeSlider
@onready var fullscreen_check: CheckBox = $Panel/FullscreenCheck
@onready var resume_button: Button = $Panel/ResumeButton
@onready var main_menu_button: Button = $Panel/MainMenuButton

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

func hide_menu() -> void:
	visible = false
	get_tree().paused = false

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
