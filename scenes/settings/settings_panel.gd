extends Control

@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var ui_slider: HSlider = $VBoxContainer/UISlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var shake_toggle: CheckButton = $VBoxContainer/ShakeToggle
@onready var damage_toggle: CheckButton = $VBoxContainer/DamageToggle
@onready var close_button: Button = $VBoxContainer/CloseButton

func _ready() -> void:
	# 连接信号
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	ui_slider.value_changed.connect(_on_ui_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	shake_toggle.toggled.connect(_on_shake_toggled)
	damage_toggle.toggled.connect(_on_damage_toggled)
	close_button.pressed.connect(_on_close_pressed)
	
	load_settings()

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume_linear("SFX", value)
	save_settings()

func _on_ui_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume_linear("UI", value)
	save_settings()

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume_linear("Music", value)
	save_settings()

func _on_shake_toggled(enabled: bool) -> void:
	GameManager.screen_shake_enabled = enabled
	save_settings()

func _on_damage_toggled(enabled: bool) -> void:
	GameManager.damage_numbers_enabled = enabled
	save_settings()

func _on_close_pressed() -> void:
	visible = false

func save_settings() -> void:
	var settings: Dictionary = {
		"sfx_volume": sfx_slider.value,
		"ui_volume": ui_slider.value,
		"music_volume": music_slider.value,
		"screen_shake": shake_toggle.button_pressed,
		"damage_numbers": damage_toggle.button_pressed
	}
	SaveManager.save_settings(settings)

func load_settings() -> void:
	var settings: Dictionary = SaveManager.load_settings()
	sfx_slider.value = settings.get("sfx_volume", 0.8)
	ui_slider.value = settings.get("ui_volume", 0.8)
	music_slider.value = settings.get("music_volume", 0.5)
	shake_toggle.button_pressed = settings.get("screen_shake", true)
	damage_toggle.button_pressed = settings.get("damage_numbers", true)
	
	# 同时应用到 AudioManager
	AudioManager.set_bus_volume_linear("SFX", sfx_slider.value)
	AudioManager.set_bus_volume_linear("UI", ui_slider.value)
	AudioManager.set_bus_volume_linear("Music", music_slider.value)
