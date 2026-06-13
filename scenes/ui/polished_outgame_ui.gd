class_name PolishedOutgameUI
extends RefCounted

const FONT_CN_PATH := "res://assets/fonts/SourceHanSerifSC-Bold.otf"
const ROOT := "res://assets/ui/outgame_polish/"

const TEXT_LIGHT := Color("#fff0c7")
const TEXT_DARK := Color("#392114")
const TEXT_MUTED := Color("#d9b77b")
const GOLD := Color("#f2c572")
const OUTLINE_DARK := Color(0.08, 0.04, 0.02, 0.86)


static func font() -> Font:
	if ResourceLoader.exists(FONT_CN_PATH):
		return load(FONT_CN_PATH)
	return null


static func texture_style(file_name: String, margin: int = 28, content: int = 14) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var path := ROOT + file_name
	if ResourceLoader.exists(path):
		style.texture = load(path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content
	style.content_margin_top = content
	style.content_margin_right = content
	style.content_margin_bottom = content
	style.draw_center = true
	return style


static func apply_panel(control: Control, file_name: String = "panel_parchment.png", margin: int = 32, content: int = 18) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override("panel", texture_style(file_name, margin, content))


static func apply_button(button: Button, primary: bool = false, danger: bool = false) -> void:
	if button == null:
		return
	var normal := "button_gold.png" if primary else "button_wood.png"
	if danger:
		normal = "button_red.png"
	button.add_theme_stylebox_override("normal", texture_style(normal, 24, 16))
	button.add_theme_stylebox_override("hover", texture_style("button_gold.png", 24, 16))
	button.add_theme_stylebox_override("pressed", texture_style("button_red.png" if danger else "button_wood.png", 24, 16))
	button.add_theme_stylebox_override("disabled", texture_style("button_wood.png", 24, 16))
	button.add_theme_color_override("font_color", TEXT_DARK if primary else TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.45, 0.34, 0.85))
	button.add_theme_font_size_override("font_size", 18)
	_apply_font(button)
	_apply_outline(button, 2)


static func apply_tab(button: Button, active: bool) -> void:
	if button == null:
		return
	var tex := "tab_active.png" if active else "tab_inactive.png"
	button.add_theme_stylebox_override("normal", texture_style(tex, 24, 14))
	button.add_theme_stylebox_override("hover", texture_style("tab_active.png", 24, 14))
	button.add_theme_stylebox_override("pressed", texture_style("tab_active.png", 24, 14))
	button.add_theme_stylebox_override("disabled", texture_style("tab_active.png", 24, 14))
	button.add_theme_color_override("font_color", TEXT_DARK if active else TEXT_LIGHT)
	button.add_theme_color_override("font_disabled_color", TEXT_DARK)
	button.add_theme_font_size_override("font_size", 19)
	_apply_font(button)
	_apply_outline(button, 2)


static func apply_label(label: Label, role: String = "body") -> void:
	if label == null:
		return
	match role:
		"title":
			label.add_theme_color_override("font_color", TEXT_LIGHT)
			label.add_theme_font_size_override("font_size", 34)
			_apply_outline(label, 4)
		"section":
			label.add_theme_color_override("font_color", GOLD)
			label.add_theme_font_size_override("font_size", 22)
			_apply_outline(label, 3)
		"muted":
			label.add_theme_color_override("font_color", TEXT_MUTED)
			label.add_theme_font_size_override("font_size", 15)
			_apply_outline(label, 2)
		"dark":
			label.add_theme_color_override("font_color", TEXT_DARK)
			label.add_theme_font_size_override("font_size", 17)
			_apply_outline(label, 1, Color(1, 0.93, 0.78, 0.65))
		_:
			label.add_theme_color_override("font_color", TEXT_LIGHT)
			label.add_theme_font_size_override("font_size", 17)
			_apply_outline(label, 2)
	_apply_font(label)


static func apply_recursive(node: Node) -> void:
	if node is Label:
		_apply_font(node)
		_apply_outline(node, 2)
	elif node is Button:
		_apply_font(node)
		_apply_outline(node, 2)
	for child in node.get_children():
		apply_recursive(child)


static func _apply_font(control: Control) -> void:
	var f := font()
	if f != null:
		control.add_theme_font_override("font", f)


static func _apply_outline(control: Control, size: int, color: Color = OUTLINE_DARK) -> void:
	control.add_theme_constant_override("outline_size", size)
	control.add_theme_color_override("font_outline_color", color)
