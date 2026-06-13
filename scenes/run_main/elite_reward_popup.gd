class_name EliteRewardPopup
extends PanelContainer

signal reward_selected(reward_index: int)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer
@onready var confirm_button: Button = $VBoxContainer/ConfirmButton

var _reward_data: Array[Dictionary] = []
var _selected_index: int = -1
var _font_cn: Font = preload(RunMainSettings.FONT_CN_PATH)

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.visible = false
	_init_styles()
	_apply_font_recursive(self)


func _init_styles() -> void:
	var parchment := RunMainSettings.create_parchment_flat_style(RunMainSettings.CORNER_PARCHMENT)
	add_theme_stylebox_override("panel", parchment)
	
	_apply_primary_button_style(confirm_button)
	
	title_label.add_theme_font_override("font", _font_cn)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	
	description_label.add_theme_font_override("normal_font", _font_cn)
	description_label.add_theme_color_override("default_color", RunMainSettings.COLOR_INK)


func _apply_primary_button_style(btn: Button) -> void:
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
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size.y = RunMainSettings.BUTTON_HEIGHT


func _apply_font_recursive(node: Node) -> void:
	if node is Label or node is Button:
		node.add_theme_font_override("font", _font_cn)
	for child in node.get_children():
		_apply_font_recursive(child)


func setup(rewards: Array[Dictionary]) -> void:
	_reward_data = rewards
	_selected_index = -1
	confirm_button.visible = false
	
	title_label.text = "精英战利品"
	description_label.text = "击败精英怪物后，你发现了三件珍贵的战利品，只能选择一件："
	
	for child in choices_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	for i in range(rewards.size()):
		var reward: Dictionary = rewards[i]
		var btn := Button.new()
		var rtype: String = reward.get("type", "")
		var name_text: String = reward.get("name", "???")
		var desc: String = reward.get("description", "")
		btn.text = "%s\n%s" % [name_text, desc]
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_reward_selected.bind(i))
		_apply_primary_button_style(btn)
		choices_container.add_child(btn)
	
	visible = true
	_play_entrance_animation()


func _kill_popup_tween() -> void:
	if has_meta("popup_tween"):
		var old: Tween = get_meta("popup_tween")
		if old != null and old.is_valid():
			old.kill()
		remove_meta("popup_tween")


func _play_entrance_animation() -> void:
	_kill_popup_tween()
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	pivot_offset = size / 2
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	set_meta("popup_tween", tween)


func _play_exit_animation(on_finished: Callable) -> void:
	_kill_popup_tween()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(on_finished)
	set_meta("popup_tween", tween)


func _on_reward_selected(index: int) -> void:
	_selected_index = index
	confirm_button.visible = true
	for i in range(choices_container.get_child_count()):
		var btn: Button = choices_container.get_child(i) as Button
		if btn != null:
			btn.modulate = Color(0.6, 0.6, 0.6) if i != index else Color(1.2, 1.1, 0.9)


func _on_confirm_pressed() -> void:
	if _selected_index < 0:
		return
	_play_exit_animation(func():
		visible = false
		reward_selected.emit(_selected_index)
		## 重置缩放和透明度，为下次显示做准备
		scale = Vector2.ONE
		modulate = Color.WHITE
	)
