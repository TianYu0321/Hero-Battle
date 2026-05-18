extends Control

@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var ui_slider: HSlider = $VBoxContainer/UISlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var resolution_option: OptionButton = $VBoxContainer/ResolutionOption
@onready var fullscreen_toggle: CheckButton = $VBoxContainer/FullscreenToggle
@onready var shake_toggle: CheckButton = $VBoxContainer/ShakeToggle
@onready var damage_toggle: CheckButton = $VBoxContainer/DamageToggle
@onready var close_button: Button = $VBoxContainer/CloseButton

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
]

func _ready() -> void:
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
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
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

func _on_resolution_selected(index: int) -> void:
	var res := RESOLUTIONS[index]
	DisplayServer.window_set_size(res)
	save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		# 退出全屏后恢复当前选中的分辨率
		var idx := resolution_option.selected
		if idx >= 0 and idx < RESOLUTIONS.size():
			DisplayServer.window_set_size(RESOLUTIONS[idx])
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
		"resolution_index": resolution_option.selected,
		"fullscreen": fullscreen_toggle.button_pressed,
		"screen_shake": shake_toggle.button_pressed,
		"damage_numbers": damage_toggle.button_pressed
	}
	SaveManager.save_settings(settings)

func load_settings() -> void:
	var settings: Dictionary = SaveManager.load_settings()
	sfx_slider.value = settings.get("sfx_volume", 0.8)
	ui_slider.value = settings.get("ui_volume", 0.8)
	music_slider.value = settings.get("music_volume", 0.5)
	
	# 视频设置
	var res_index: int = settings.get("resolution_index", 0)
	res_index = clampi(res_index, 0, RESOLUTIONS.size() - 1)
	resolution_option.select(res_index)
	
	var fullscreen: bool = settings.get("fullscreen", false)
	fullscreen_toggle.button_pressed = fullscreen
	
	shake_toggle.button_pressed = settings.get("screen_shake", true)
	damage_toggle.button_pressed = settings.get("damage_numbers", true)
	
	# 同时应用到 AudioManager
	AudioManager.set_bus_volume_linear("SFX", sfx_slider.value)
	AudioManager.set_bus_volume_linear("UI", ui_slider.value)
	AudioManager.set_bus_volume_linear("Music", music_slider.value)

func apply_video_settings() -> void:
	# 在启动时调用，应用保存的视频设置
	var settings: Dictionary = SaveManager.load_settings()
	var res_index: int = settings.get("resolution_index", 0)
	res_index = clampi(res_index, 0, RESOLUTIONS.size() - 1)
	
	var fullscreen: bool = settings.get("fullscreen", false)
	if fullscreen:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(RESOLUTIONS[res_index])
