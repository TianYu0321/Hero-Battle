class_name ShopPopup
extends Control

signal closed

const CARD_SIZE := Vector2(258, 258)
const CATEGORY_ALL := "all"
const CATEGORY_ATTACK := "attack"
const CATEGORY_GUARD := "guard"
const CATEGORY_SUPPORT := "support"
const CARD_BG_TEXTURE_PATH := "res://assets/ui/shop/shop_partner_card.png"
const CATEGORY_BY_PARTNER := {
	"partner_swordsman": CATEGORY_ATTACK,
	"partner_scout": CATEGORY_ATTACK,
	"partner_hunter": CATEGORY_ATTACK,
	"partner_assassin": CATEGORY_ATTACK,
	"partner_shieldguard": CATEGORY_GUARD,
	"partner_pharmacist": CATEGORY_SUPPORT,
	"partner_sorcerer": CATEGORY_SUPPORT,
}
const CATEGORY_BUTTONS := {
	CATEGORY_ALL: "全部",
	CATEGORY_ATTACK: "攻击",
	CATEGORY_GUARD: "守护",
	CATEGORY_SUPPORT: "支援",
}

@onready var _category_buttons: HBoxContainer = $CategoryButtons
@onready var _item_grid: GridContainer = $ItemScroll/ItemGrid
@onready var _empty_label: Label = $EmptyLabel
@onready var _coin_label: Label = $CurrencyPlate/CoinLabel
@onready var _return_button: TextureButton = $ReturnButton

var _current_category: String = CATEGORY_ALL
var _current_coin: int = 0
var _current_user_id: String = "local_default"
var _unlocked_heroes: Array = []
var _unlocked_partners: Array = []
var _unlocked_skins: Array = []
var _font_cn: Font = null


func _ready() -> void:
	visible = false
	_font_cn = _load_font("res://assets/fonts/SourceHanSerifSC-Bold.otf")
	_return_button.pressed.connect(hide_popup)
	_wire_category_buttons()
	_apply_static_style()


func show_popup() -> void:
	move_to_front()
	visible = true
	modulate = Color(1, 1, 1, 0)
	refresh()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


func hide_popup() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	_current_user_id = SaveManager.get_user_id()
	_load_unlock_state()
	_update_coin_display()
	_render_partner_cards()


func _wire_category_buttons() -> void:
	var bindings := [
		["AllButton", CATEGORY_ALL],
		["AttackButton", CATEGORY_ATTACK],
		["GuardButton", CATEGORY_GUARD],
		["SupportButton", CATEGORY_SUPPORT],
	]
	for binding in bindings:
		var button: Button = _category_buttons.get_node(binding[0])
		var category: String = binding[1]
		button.pressed.connect(_on_category_selected.bind(category))


func _load_unlock_state() -> void:
	var state := SaveManager.load_unlock_state(_current_user_id)
	_unlocked_heroes = state.get("unlocked_heroes", [1])
	_unlocked_partners = state.get("unlocked_partners", [])
	_unlocked_skins = state.get("unlocked_skins", [])
	_current_coin = SaveManager.load_mocheng_coin(_current_user_id)


func _update_coin_display() -> void:
	_coin_label.text = "魔城币  %d" % _current_coin


func _on_category_selected(category: String) -> void:
	if _current_category == category:
		return
	_current_category = category
	_update_category_styles()
	_render_partner_cards()


func _render_partner_cards() -> void:
	for child in _item_grid.get_children():
		child.queue_free()

	var items := _get_filtered_partner_items()
	_empty_label.visible = items.is_empty()
	for item in items:
		_item_grid.add_child(_create_partner_card(item))


func _get_filtered_partner_items() -> Array[Dictionary]:
	var all_configs: Dictionary = ConfigManager.get_all_partner_configs()
	var result: Array[Dictionary] = []
	for partner_key in all_configs.keys():
		var cfg: Dictionary = all_configs[partner_key]
		var availability: String = cfg.get("availability", "hidden")
		if availability == "hidden":
			continue
		var category: String = CATEGORY_BY_PARTNER.get(partner_key, _category_from_attr(cfg.get("favored_attr", 0)))
		if _current_category != CATEGORY_ALL and category != _current_category:
			continue
		var item := cfg.duplicate(true)
		item["partner_key"] = partner_key
		item["category"] = category
		result.append(item)

	result.sort_custom(func(a, b):
		return int(a.get("sort_order", 999)) < int(b.get("sort_order", 999))
	)
	return result


func _category_from_attr(attr_code: int) -> String:
	match attr_code:
		1:
			return CATEGORY_GUARD
		2, 3:
			return CATEGORY_ATTACK
		4, 5:
			return CATEGORY_SUPPORT
		_:
			return CATEGORY_SUPPORT


func _create_partner_card(item: Dictionary) -> Control:
	var partner_key: String = item.get("partner_key", "")
	var partner_id: String = str(item.get("id", ""))
	var is_owned := _is_partner_owned(item)
	var availability: String = item.get("availability", "hidden")
	var price: int = int(item.get("unlock_price_mocheng", 0))
	var can_buy := availability == "shop" and not is_owned and price > 0
	var can_afford := can_buy and _current_coin >= price

	var card := Control.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = ResourcePaths.load_texture_safe(CARD_BG_TEXTURE_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(0.78, 0.70, 0.62, 1.0) if is_owned else Color.WHITE
	card.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(220, 112)
	portrait_frame.add_theme_stylebox_override("panel", _make_portrait_style())
	vbox.add_child(portrait_frame)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(190, 100)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture = _get_partner_texture(partner_key, item)
	portrait_frame.add_child(avatar)

	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color("#ffe6b0"))
	if _font_cn != null:
		name_label.add_theme_font_override("font", _font_cn)
	_apply_label_readability(name_label, 3)
	vbox.add_child(name_label)

	var title_label := Label.new()
	title_label.text = _short_role(item)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color("#d9b77b"))
	if _font_cn != null:
		title_label.add_theme_font_override("font", _font_cn)
	_apply_label_readability(title_label, 2)
	vbox.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 42)
	button.add_theme_font_size_override("font_size", 19)
	if _font_cn != null:
		button.add_theme_font_override("font", _font_cn)
	_apply_button_readability(button, 2)
	_apply_purchase_button_style(button, can_afford)
	if is_owned:
		button.text = "已拥有"
		button.disabled = true
	elif availability == "achievement":
		button.text = "成就解锁"
		button.disabled = true
	elif can_buy:
		button.text = "购买  %d" % price if can_afford else "魔城币不足"
		button.disabled = not can_afford
		if can_afford:
			button.pressed.connect(_on_purchase_requested.bind(item))
	else:
		button.text = "旅途中加入"
		button.disabled = true
	vbox.add_child(button)

	if is_owned:
		card.modulate = Color(0.82, 0.78, 0.72, 1.0)
	return card


func _get_partner_texture(partner_key: String, item: Dictionary) -> Texture2D:
	var icon_path: String = item.get("icon_path", "")
	if not icon_path.is_empty():
		return ResourcePaths.load_texture_safe(icon_path)
	return ResourcePaths.load_texture_safe(ResourcePaths.get_partner_avatar(partner_key))


func _is_partner_owned(item: Dictionary) -> bool:
	if item.get("is_default_unlock", false):
		return true
	var partner_id := str(item.get("id", ""))
	for unlocked in _unlocked_partners:
		if str(unlocked) == partner_id:
			return true
	return false


func _short_role(item: Dictionary) -> String:
	var title: String = item.get("title", "")
	if title.length() <= 8:
		return title
	var category: String = item.get("category", CATEGORY_SUPPORT)
	match category:
		CATEGORY_ATTACK:
			return "攻击伙伴"
		CATEGORY_GUARD:
			return "守护伙伴"
		_:
			return "支援伙伴"


func _on_purchase_requested(item: Dictionary) -> void:
	var price: int = int(item.get("unlock_price_mocheng", 0))
	var partner_id: int = int(str(item.get("id", "0")))
	if price <= 0 or partner_id <= 0 or _current_coin < price:
		return

	_current_coin -= price
	SaveManager.save_mocheng_coin(_current_coin, _current_user_id)
	var unlocked: Array = _unlocked_partners.duplicate()
	var has_partner := false
	for existing in unlocked:
		if int(str(existing)) == partner_id:
			has_partner = true
			break
	if not has_partner:
		unlocked.append(partner_id)
	SaveManager.save_unlock_state(_unlocked_heroes, unlocked, _unlocked_skins, _current_user_id)

	EventBus.partner_unlocked.emit(
		item.get("partner_key", ""),
		item.get("name", "???"),
		-1,
		-1,
		"outgame_shop"
	)
	refresh()


func _apply_static_style() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_empty_label.add_theme_color_override("font_color", Color("#f3d89d"))
	_empty_label.add_theme_font_size_override("font_size", 26)
	if _font_cn != null:
		_empty_label.add_theme_font_override("font", _font_cn)
		_coin_label.add_theme_font_override("font", _font_cn)
		$ReturnButton/ReturnLabel.add_theme_font_override("font", _font_cn)
	_coin_label.add_theme_color_override("font_color", Color("#ffecc4"))
	$ReturnButton/ReturnLabel.add_theme_color_override("font_color", Color("#ffe8bd"))
	_apply_label_readability(_empty_label, 3)
	_apply_label_readability(_coin_label, 3)
	_apply_label_readability($ReturnButton/ReturnLabel, 3)
	_update_category_styles()


func _update_category_styles() -> void:
	for category in CATEGORY_BUTTONS.keys():
		var button := _button_for_category(category)
		if button == null:
			continue
		button.text = CATEGORY_BUTTONS[category]
		button.add_theme_font_size_override("font_size", 24)
		if _font_cn != null:
			button.add_theme_font_override("font", _font_cn)
		_apply_button_readability(button, 2)
		var active: bool = category == _current_category
		button.add_theme_stylebox_override("normal", _make_tab_style(active, false))
		button.add_theme_stylebox_override("hover", _make_tab_style(active, true))
		button.add_theme_stylebox_override("pressed", _make_tab_style(true, true))
		button.add_theme_color_override("font_color", Color("#3b2418") if active else Color("#e7cda0"))


func _button_for_category(category: String) -> Button:
	match category:
		CATEGORY_ALL:
			return $CategoryButtons/AllButton
		CATEGORY_ATTACK:
			return $CategoryButtons/AttackButton
		CATEGORY_GUARD:
			return $CategoryButtons/GuardButton
		CATEGORY_SUPPORT:
			return $CategoryButtons/SupportButton
		_:
			return null


func _make_tab_style(active: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#d5a36c") if active else Color("#4d332b")
	if hover and not active:
		style.bg_color = Color("#684235")
	style.border_color = Color("#ffe0a4") if active or hover else Color("#9f714a")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 5
	return style


func _make_card_style(is_owned: bool, can_buy: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.23, 0.13, 0.09, 0.92) if not is_owned else Color(0.16, 0.13, 0.11, 0.84)
	style.border_color = Color("#e2b56f") if can_buy or is_owned else Color("#a7794f")
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	return style


func _make_portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.045, 0.78)
	style.border_color = Color("#c69558")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _apply_purchase_button_style(button: Button, primary: bool) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(primary, false))
	button.add_theme_stylebox_override("hover", _make_button_style(primary, true))
	button.add_theme_stylebox_override("pressed", _make_button_style(true, true))
	button.add_theme_stylebox_override("disabled", _make_disabled_button_style())
	button.add_theme_color_override("font_color", Color("#3a2012") if primary else Color("#5f4939"))
	button.add_theme_color_override("font_disabled_color", Color("#8f7a65"))


func _make_button_style(primary: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e5b16c") if primary else Color("#b89468")
	if hover:
		style.bg_color = Color("#f0c17c") if primary else Color("#caa477")
	style.border_color = Color("#fff0bc")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _make_disabled_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#594235")
	style.border_color = Color("#8f7359")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _apply_label_readability(label: Label, outline_size: int) -> void:
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.04, 0.9))


func _apply_button_readability(button: Button, outline_size: int) -> void:
	button.add_theme_constant_override("outline_size", outline_size)
	button.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.04, 0.85))


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null
