class_name OutgameUIStyle
extends RefCounted

const BG := Color(0.075, 0.065, 0.07, 1.0)
const PANEL := Color(0.16, 0.12, 0.095, 0.96)
const PANEL_DARK := Color(0.105, 0.085, 0.075, 0.98)
const CARD := Color(0.21, 0.165, 0.12, 0.96)
const CARD_HOVER := Color(0.28, 0.215, 0.145, 1.0)
const GOLD := Color(0.93, 0.68, 0.24, 1.0)
const GOLD_DARK := Color(0.54, 0.36, 0.13, 1.0)
const RED := Color(0.68, 0.23, 0.18, 1.0)
const GREEN := Color(0.34, 0.72, 0.43, 1.0)
const TEXT := Color(0.96, 0.90, 0.78, 1.0)
const MUTED := Color(0.66, 0.60, 0.51, 1.0)
const DIM := Color(0.40, 0.36, 0.32, 1.0)


static func panel_style(bg_color: Color = PANEL, border_color: Color = GOLD_DARK, radius: int = 14, border: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


static func button_style(bg_color: Color, border_color: Color, radius: int = 10) -> StyleBoxFlat:
	var style := panel_style(bg_color, border_color, radius, 1)
	style.content_margin_left = 18
	style.content_margin_top = 8
	style.content_margin_right = 18
	style.content_margin_bottom = 8
	style.shadow_size = 5
	return style


static func apply_background(rect: ColorRect) -> void:
	if rect == null:
		return
	rect.color = BG


static func apply_panel(control: Control, strong: bool = false) -> void:
	if control == null:
		return
	var bg := PANEL_DARK if strong else PANEL
	control.add_theme_stylebox_override("panel", panel_style(bg, GOLD_DARK, 16, 1))


static func apply_card(control: Control, highlighted: bool = false) -> void:
	if control == null:
		return
	var bg := CARD_HOVER if highlighted else CARD
	control.add_theme_stylebox_override("panel", panel_style(bg, GOLD_DARK, 12, 1))


static func apply_button(button: Button, primary: bool = false, danger: bool = false) -> void:
	if button == null:
		return
	var base := PANEL_DARK
	var hover := CARD
	var pressed := GOLD_DARK
	var border := GOLD_DARK
	if primary:
		base = Color(0.55, 0.32, 0.12, 1.0)
		hover = Color(0.70, 0.42, 0.16, 1.0)
		pressed = Color(0.42, 0.22, 0.10, 1.0)
		border = GOLD
	elif danger:
		base = Color(0.35, 0.11, 0.10, 1.0)
		hover = Color(0.48, 0.16, 0.13, 1.0)
		pressed = Color(0.25, 0.08, 0.07, 1.0)
		border = RED

	button.add_theme_stylebox_override("normal", button_style(base, border))
	button.add_theme_stylebox_override("hover", button_style(hover, GOLD))
	button.add_theme_stylebox_override("pressed", button_style(pressed, border))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.12, 0.105, 0.095, 0.9), DIM))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_font_size_override("font_size", 15)


static func apply_label(label: Label, role: String = "body") -> void:
	if label == null:
		return
	match role:
		"title":
			label.add_theme_color_override("font_color", GOLD)
			label.add_theme_font_size_override("font_size", 28)
		"section":
			label.add_theme_color_override("font_color", GOLD)
			label.add_theme_font_size_override("font_size", 18)
		"muted":
			label.add_theme_color_override("font_color", MUTED)
			label.add_theme_font_size_override("font_size", 13)
		"danger":
			label.add_theme_color_override("font_color", RED)
		"success":
			label.add_theme_color_override("font_color", GREEN)
		_:
			label.add_theme_color_override("font_color", TEXT)


static func apply_option_button(option_button: OptionButton) -> void:
	if option_button == null:
		return
	apply_button(option_button, false, false)
