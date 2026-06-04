## res://scenes/hero_select/hero_select.gd
## 模块: HeroSelectUI
## 职责: 选人界面，左侧列表 + 右侧立绘 + 底部属性 + 新手老手切换
## 依赖: EventBus, ConfigManager, SaveManager, GameManager
## class_name: HeroSelectUI

class_name HeroSelectUI
extends Control

# --- 顶部 ---
@onready var _back_btn: Button = $UILayer/TopBar/BackButton
@onready var _title_label: Label = $UILayer/TopBar/TitleLabel
@onready var _novice_btn: Button = $UILayer/TopBar/DifficultyToggle/NoviceButton
@onready var _veteran_btn: Button = $UILayer/TopBar/DifficultyToggle/VeteranButton
@onready var _top_bar: HBoxContainer = $UILayer/TopBar
@onready var _difficulty_toggle: HBoxContainer = $UILayer/TopBar/DifficultyToggle
@onready var _background_color: ColorRect = $BackgroundLayer/BackgroundColor
@onready var _background_texture: TextureRect = $BackgroundLayer/BackgroundTexture

# --- 左侧面板 ---
@onready var _hero_list_container: VBoxContainer = $UILayer/LeftPanel/HeroListContainer
@onready var _left_panel: VBoxContainer = $UILayer/LeftPanel

# --- 右侧面板 ---
@onready var _right_panel: PanelContainer = $UILayer/RightPanel
@onready var _big_portrait: TextureRect = $UILayer/RightPanel/Content/HeroBigPortrait
@onready var _silhouette_label: Label = $UILayer/RightPanel/Content/HeroBigPortrait/SilhouetteLabel
@onready var _hero_name_label: Label = $UILayer/RightPanel/Content/HeroNameLabel
@onready var _hero_role_label: Label = $UILayer/RightPanel/Content/HeroRoleLabel
@onready var _lock_overlay: ColorRect = $UILayer/RightPanel/Content/LockOverlay
@onready var _lock_label: Label = $UILayer/RightPanel/Content/LockOverlay/LockLabel

# --- 底部 ---
@onready var _bottom_panel: PanelContainer = $UILayer/BottomPanel
@onready var _stat_container: HBoxContainer = $UILayer/BottomPanel/Content/StatPreviewContainer
@onready var _description_panel: PanelContainer = $UILayer/BottomPanel/Content/DescriptionPanel
@onready var _desc_label: RichTextLabel = $UILayer/BottomPanel/Content/DescriptionPanel/DescriptionLabel
@onready var _start_btn: Button = $UILayer/BottomPanel/Content/StartRunButton

# --- 过渡 ---
@onready var _transition_overlay: ColorRect = $TransitionOverlay
@onready var _transition_label: Label = $TransitionOverlay/TransitionLabel

var _hero_ids: Array[String] = []
var _selected_hero_id: String = ""
var _selected_card: PanelContainer = null
var _is_veteran_mode: bool = false
var _left_panel_frame: Panel = null

var _stat_bars: Dictionary = {}

var _font_cn: FontFile
var _font_en: FontFile

# ========== 颜色常量（明亮风格）==========

const COLOR_TEXT_DARK := Color(0.176, 0.216, 0.282, 1)
const COLOR_TEXT_BODY := Color(0.29, 0.333, 0.408, 1)
const COLOR_TEXT_MUTE := Color(0.443, 0.502, 0.588, 1)
const COLOR_TEXT_LIGHT := Color(0.627, 0.682, 0.753, 1)
const COLOR_TEXT_GOLD := Color(0.901961, 0.752941, 0.25098, 1)
const COLOR_BLUE := Color(0.4, 0.6, 1, 1)
const COLOR_BLUE_ACCENT := Color(0.352941, 0.560784, 0.815686, 1)
const COLOR_BLUE_DARK := Color(0.3, 0.5, 0.9, 1)
const COLOR_BLUE_LIGHT := Color(0.5, 0.65, 1, 1)
const COLOR_RED := Color(0.85098, 0.219608, 0.14902, 1)
const COLOR_GRAY := Color(0.443, 0.502, 0.588, 1)
const COLOR_GRAY_LIGHT := Color(0.627, 0.682, 0.753, 1)
const COLOR_BG_PANEL := Color(1, 1, 1, 1)
const COLOR_BG_SELECTED := Color(0.98, 0.98, 1, 1)
const COLOR_CARD_BORDER := Color(0.85, 0.85, 0.85, 1)
const COLOR_CARD_BORDER_HOVER := Color(0.4, 0.6, 1, 1)
const COLOR_PROGRESS_BG := Color(0.88, 0.88, 0.92, 1)

# ========== 公会委托布告栏风格 ==========

const RPG_INK := Color(0.18, 0.105, 0.055, 1)
const RPG_BODY := Color(0.35, 0.22, 0.12, 1)
const RPG_MUTE := Color(0.54, 0.39, 0.22, 1)
const RPG_GOLD := Color(0.96, 0.74, 0.28, 1)
const RPG_BLUE := Color(0.20, 0.43, 0.78, 1)
const RPG_BLUE_DARK := Color(0.3, 0.5, 0.9, 1)
const RPG_BLUE_LIGHT := Color(0.42, 0.68, 1.0, 1)
const RPG_RED := Color(0.72, 0.22, 0.13, 1)
const RPG_WOOD := Color(0.34, 0.17, 0.07, 0.95)
const RPG_WOOD_DARK := Color(0.18, 0.08, 0.025, 1)
const RPG_PARCHMENT := Color(0.98, 0.88, 0.64, 0.96)
const RPG_PARCHMENT_DARK := Color(0.82, 0.62, 0.34, 1)
const RPG_SKY_OVERLAY := Color(0.98, 0.83, 0.55, 0.16)

const STAT_COLORS: Dictionary = {
	"vit": Color(0.305882, 0.803922, 0.768627, 1),
	"str": Color(1, 0.419608, 0.419608, 1),
	"agi": Color(0.901961, 0.752941, 0.25098, 1),
	"tec": Color(0.352941, 0.560784, 0.815686, 1),
	"mnd": Color(0.607843, 0.34902, 0.713725, 1),
}

# ========== 生命周期 ==========

func _ready() -> void:
	_font_cn = load("res://assets/fonts/cute/ZCOOLKuaiLe-Regular.ttf")
	_font_en = load("res://assets/fonts/cute/FredokaOne-Regular.ttf")
	if _font_cn == null:
		push_error("[HeroSelect] 中文字体加载失败")
	if _font_en == null:
		push_error("[HeroSelect] 英文字体加载失败")

	_back_btn.pressed.connect(_on_back_pressed)
	_start_btn.pressed.connect(_on_start_run_pressed)
	_novice_btn.toggled.connect(_on_novice_toggled)
	_veteran_btn.toggled.connect(_on_veteran_toggled)

	_setup_scene_layout()
	_setup_background_style()
	_setup_top_bar()
	_setup_left_panel_style()
	_setup_right_panel_style()
	_setup_bottom_panel_style()
	_setup_start_button_style()

	_apply_fonts_recursive(self)
	print("[HeroSelect] 字体已应用 cn=", _font_cn != null, " en=", _font_en != null)

	call_deferred("_setup_portrait_pivot")

	_update_difficulty_buttons()

	var all_configs: Dictionary = ConfigManager.get_all_hero_configs()
	var sorted: Array = all_configs.keys()
	sorted.sort_custom(func(a, b):
		return all_configs[a].get("sort_order", 0) < all_configs[b].get("sort_order", 0)
	)
	_hero_ids.assign(sorted)

	_populate_hero_cards()

	_build_stat_bars()

	_select_first_unlocked()

	_play_entrance_animation()


func _setup_scene_layout() -> void:
	_top_bar.set_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_left = 64
	_top_bar.offset_top = 28
	_top_bar.offset_right = -64
	_top_bar.offset_bottom = 106
	_top_bar.add_theme_constant_override("separation", 18)
	_difficulty_toggle.add_theme_constant_override("separation", 6)

	_left_panel.position = Vector2(72, 148)
	_left_panel.size = Vector2(430, 654)
	_left_panel.add_theme_constant_override("separation", 12)

	_right_panel.position = Vector2(535, 140)
	_right_panel.size = Vector2(1315, 665)
	_bottom_panel.position = Vector2(72, 830)
	_bottom_panel.size = Vector2(1778, 190)

	_big_portrait.anchor_left = 0.5
	_big_portrait.anchor_right = 0.5
	_big_portrait.anchor_top = 0.0
	_big_portrait.anchor_bottom = 0.0
	_big_portrait.offset_left = -360
	_big_portrait.offset_top = 18
	_big_portrait.offset_right = 360
	_big_portrait.offset_bottom = 525

	_hero_name_label.offset_top = -158
	_hero_name_label.offset_bottom = -105
	_hero_role_label.offset_top = -102
	_hero_role_label.offset_bottom = -62
	_stat_container.custom_minimum_size = Vector2(650, 0)


func _setup_background_style() -> void:
	_background_color.color = Color(0.98, 0.90, 0.73, 1)
	_background_texture.modulate = Color(1.0, 0.94, 0.78, 0.78)

	var warm_glow := ColorRect.new()
	warm_glow.name = "AdventureWarmGlow"
	warm_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	warm_glow.color = RPG_SKY_OVERLAY
	warm_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$BackgroundLayer.add_child(warm_glow)

	var vignette := ColorRect.new()
	vignette.name = "AdventureVignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.20, 0.10, 0.035, 0.10)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$BackgroundLayer.add_child(vignette)


func _setup_portrait_pivot() -> void:
	_big_portrait.pivot_offset = _big_portrait.size / 2


func _apply_fonts_recursive(node: Node) -> void:
	if _font_cn == null:
		return
	for child in node.get_children():
		if child is Label or child is Button:
			child.add_theme_font_override("font", _font_cn)
		elif child is RichTextLabel:
			child.add_theme_font_override("normal_font", _font_cn)
			child.add_theme_font_override("bold_font", _font_cn)
		elif child is ProgressBar:
			child.add_theme_font_override("font", _font_cn)
		if child.get_child_count() > 0:
			_apply_fonts_recursive(child)


# ========== 顶部栏样式 ==========

func _setup_top_bar() -> void:
	_title_label.text = "勇者出发名册"
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", RPG_INK)
	_title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.86, 0.46, 0.85))
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 0.65))
	_title_label.add_theme_constant_override("outline_size", 4)

	# 返回按钮
	_back_btn.custom_minimum_size = Vector2(120, 50)
	_back_btn.text = "返回"
	var back_normal := _create_btn_style(RPG_PARCHMENT, RPG_WOOD, 2, 12, 7, Color(0.16, 0.07, 0.02, 0.18))
	var back_hover := _create_btn_style(Color(1.0, 0.91, 0.67, 1), RPG_GOLD, 2, 12, 10, Color(0.9, 0.55, 0.14, 0.22))
	_back_btn.add_theme_stylebox_override("normal", back_normal)
	_back_btn.add_theme_stylebox_override("hover", back_hover)
	_back_btn.add_theme_stylebox_override("pressed", back_hover)
	_back_btn.add_theme_color_override("font_color", RPG_INK)
	_back_btn.add_theme_font_size_override("font_size", 16)


func _setup_left_panel_style() -> void:
	if _left_panel_frame == null:
		_left_panel_frame = Panel.new()
		_left_panel_frame.name = "GuildBoardFrame"
		_left_panel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_left_panel_frame.position = _left_panel.position - Vector2(18, 18)
		_left_panel_frame.size = _left_panel.size + Vector2(36, 36)
		_left_panel_frame.add_theme_stylebox_override("panel", _create_wood_panel_style())
		$UILayer.add_child(_left_panel_frame)
		$UILayer.move_child(_left_panel_frame, _left_panel.get_index())

	if _left_panel.get_node_or_null("ListHeader") == null:
		var header := Label.new()
		header.name = "ListHeader"
		header.text = "冒险者名册"
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 22)
		header.add_theme_color_override("font_color", RPG_GOLD)
		header.add_theme_color_override("font_outline_color", RPG_WOOD_DARK)
		header.add_theme_constant_override("outline_size", 3)
		header.add_theme_font_override("font", _font_cn)
		_left_panel.add_child(header)
		_left_panel.move_child(header, 0)


func _setup_right_panel_style() -> void:
	var s := _create_panel_style(16)
	_right_panel.add_theme_stylebox_override("panel", s)
	_hero_name_label.add_theme_font_size_override("font_size", 32)
	_hero_name_label.add_theme_color_override("font_color", RPG_INK)
	_hero_name_label.add_theme_color_override("font_outline_color", Color(1.0, 0.84, 0.42, 0.55))
	_hero_name_label.add_theme_constant_override("outline_size", 2)
	_hero_role_label.add_theme_font_size_override("font_size", 17)
	_hero_role_label.add_theme_color_override("font_color", RPG_MUTE)
	_lock_overlay.color = Color(0.26, 0.18, 0.10, 0.58)
	_lock_label.add_theme_color_override("font_color", RPG_GOLD)
	_lock_label.add_theme_color_override("font_outline_color", RPG_WOOD_DARK)
	_lock_label.add_theme_constant_override("outline_size", 3)


func _setup_bottom_panel_style() -> void:
	var s := _create_panel_style(12)
	_bottom_panel.add_theme_stylebox_override("panel", s)
	_description_panel.add_theme_stylebox_override("panel", _create_inner_parchment_style())
	_desc_label.add_theme_color_override("default_color", RPG_BODY)
	_desc_label.add_theme_font_size_override("normal_font_size", 16)


func _setup_start_button_style() -> void:
	_start_btn.custom_minimum_size = Vector2(260, 66)
	var normal := _create_start_btn_style(RPG_BLUE, RPG_GOLD, 10, Color(0.1, 0.05, 0.02, 0.28))
	var hover := _create_start_btn_style(RPG_BLUE_LIGHT, RPG_GOLD, 14, Color(1.0, 0.72, 0.18, 0.30))
	var pressed := _create_start_btn_style(RPG_BLUE_DARK, RPG_WOOD, 5, Color(0, 0, 0, 0.20))
	var disabled := _create_start_btn_style(Color(0.46, 0.40, 0.34, 1), Color(0.34, 0.29, 0.24, 1), 0, Color(0, 0, 0, 0))
	_start_btn.add_theme_stylebox_override("normal", normal)
	_start_btn.add_theme_stylebox_override("hover", hover)
	_start_btn.add_theme_stylebox_override("pressed", pressed)
	_start_btn.add_theme_stylebox_override("disabled", disabled)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_disabled_color", Color(0.74, 0.68, 0.58, 1))
	_start_btn.add_theme_font_size_override("font_size", 22)


# ========== 样式工厂 ==========

func _create_panel_style(shadow_size: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = RPG_PARCHMENT
	s.border_color = RPG_PARCHMENT_DARK
	s.border_width_left = 4
	s.border_width_top = 4
	s.border_width_right = 4
	s.border_width_bottom = 6
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18
	s.corner_radius_bottom_right = 18
	s.shadow_color = Color(0.18, 0.08, 0.02, 0.28)
	s.shadow_size = shadow_size
	s.shadow_offset = Vector2(0, 8)
	s.content_margin_left = 18
	s.content_margin_top = 16
	s.content_margin_right = 18
	s.content_margin_bottom = 16
	return s


func _create_wood_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = RPG_WOOD
	s.border_color = RPG_WOOD_DARK
	s.border_width_left = 5
	s.border_width_top = 5
	s.border_width_right = 5
	s.border_width_bottom = 7
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18
	s.corner_radius_bottom_right = 18
	s.shadow_color = Color(0.05, 0.02, 0.0, 0.42)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 8)
	return s


func _create_inner_parchment_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1.0, 0.92, 0.70, 0.70)
	s.border_color = Color(0.68, 0.43, 0.18, 0.65)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	s.content_margin_left = 16
	s.content_margin_top = 10
	s.content_margin_right = 16
	s.content_margin_bottom = 10
	return s


func _create_btn_style(bg: Color, border: Color, bw: int, radius: int, shadow_sz: int, shadow_col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = bw
	s.border_width_top = bw
	s.border_width_right = bw
	s.border_width_bottom = bw
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.shadow_color = shadow_col
	s.shadow_size = shadow_sz
	s.shadow_offset = Vector2(0, 2)
	return s


func _create_start_btn_style(bg: Color, border: Color, shadow_sz: int, shadow_col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 4
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	s.corner_radius_bottom_left = 16
	s.corner_radius_bottom_right = 16
	s.shadow_color = shadow_col
	s.shadow_size = shadow_sz
	s.shadow_offset = Vector2(0, 3)
	return s


# ========== 左侧英雄卡片 ==========

func _populate_hero_cards() -> void:
	for child in _hero_list_container.get_children():
		child.queue_free()

	var player_data: Dictionary = SaveManager.load_player_data()
	var unlocked: Array = player_data.get("unlocked_heroes", ["hero_warrior"])

	for hero_id in _hero_ids:
		var config: Dictionary = ConfigManager.get_hero_config(hero_id)
		if config.is_empty():
			continue

		var is_unlocked: bool = config.get("is_default_unlock", false) or hero_id in unlocked
		var card := _create_hero_card(hero_id, config, is_unlocked)
		_hero_list_container.add_child(card)


func _create_hero_card(hero_id: String, config: Dictionary, is_unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(388, 96)
	card.size_flags_horizontal = Control.SIZE_FILL

	var style := _create_card_style(is_unlocked, false, false)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(hbox)

	var portrait_color := Color.html(config.get("portrait_color", "#888888"))

	# 头像
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(62, 62)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_PASS
	avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var avatar_path: String = ResourcePaths.get_hero_avatar(hero_id)
	var tex: Texture2D = ResourcePaths.load_texture_safe(avatar_path)
	if tex != null:
		avatar.texture = tex
	else:
		avatar.modulate = portrait_color
	hbox.add_child(avatar)

	# 文字区
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = config.get("hero_name", hero_id)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", RPG_INK if is_unlocked else RPG_MUTE)
	name_label.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.55, 0.35))
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_font_override("font", _font_cn)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(name_label)

	var role_label := Label.new()
	role_label.text = config.get("class_desc", "")
	role_label.add_theme_font_size_override("font_size", 13)
	role_label.add_theme_color_override("font_color", RPG_MUTE if is_unlocked else Color(0.62, 0.55, 0.46, 1))
	role_label.add_theme_font_override("font", _font_cn)
	role_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(role_label)

	# 未解锁锁图标
	if not is_unlocked:
		card.modulate = Color(0.74, 0.70, 0.62, 1)
		var lock_icon := Label.new()
		lock_icon.text = "封"
		lock_icon.add_theme_font_size_override("font_size", 20)
		lock_icon.add_theme_color_override("font_color", RPG_RED)
		lock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_child(lock_icon)

	# 交互
	card.gui_input.connect(_on_card_gui_input.bind(hero_id, card, is_unlocked))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card))

	card.set_meta("hero_id", hero_id)
	card.set_meta("is_unlocked", is_unlocked)

	return card


func _create_card_style(is_unlocked: bool, is_selected: bool, is_hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()

	if is_selected:
		s.bg_color = COLOR_BG_SELECTED
		s.border_color = RPG_GOLD
		s.border_width_left = 6
		s.border_width_top = 3
		s.border_width_right = 3
		s.border_width_bottom = 5
		s.shadow_color = Color(1.0, 0.68, 0.20, 0.28)
		s.shadow_size = 14
	elif is_hover:
		s.bg_color = Color(1.0, 0.88, 0.58, 0.98)
		s.border_color = COLOR_CARD_BORDER_HOVER
		s.border_width_left = 4
		s.border_width_top = 3
		s.border_width_right = 3
		s.border_width_bottom = 4
		s.shadow_color = Color(0.5, 0.25, 0.05, 0.18)
		s.shadow_size = 11
	else:
		s.bg_color = Color(0.96, 0.80, 0.48, 0.96) if is_unlocked else Color(0.62, 0.52, 0.40, 0.82)
		s.border_color = COLOR_CARD_BORDER
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.shadow_color = Color(0.08, 0.03, 0.0, 0.20)
		s.shadow_size = 8

	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


# ========== 卡片交互 ==========

func _on_card_gui_input(event: InputEvent, hero_id: String, card: PanelContainer, is_unlocked: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_hero(hero_id, card, is_unlocked)


func _on_card_mouse_entered(card: PanelContainer) -> void:
	if card == _selected_card:
		return
	_kill_card_tween(card, "hover_tween")

	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.02, 1.02), 0.12)
	card.set_meta("hover_tween", tween)

	var style := _create_card_style(card.get_meta("is_unlocked", true), false, true)
	card.add_theme_stylebox_override("panel", style)


func _on_card_mouse_exited(card: PanelContainer) -> void:
	if card == _selected_card:
		return
	_kill_card_tween(card, "hover_tween")

	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.15)
	card.set_meta("hover_tween", tween)

	var style := _create_card_style(card.get_meta("is_unlocked", true), false, false)
	card.add_theme_stylebox_override("panel", style)


func _kill_card_tween(card: PanelContainer, key: String) -> void:
	if card.has_meta(key):
		var old: Tween = card.get_meta(key)
		if old != null and old.is_valid():
			old.kill()


func _select_hero(hero_id: String, card: PanelContainer, is_unlocked: bool) -> void:
	_selected_hero_id = hero_id

	# 取消旧选中
	if _selected_card != null and is_instance_valid(_selected_card):
		_kill_card_tween(_selected_card, "select_tween")
		var tween_out := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween_out.tween_property(_selected_card, "scale", Vector2.ONE, 0.2)
		_selected_card.set_meta("select_tween", tween_out)

		var style := _create_card_style(_selected_card.get_meta("is_unlocked", true), false, false)
		_selected_card.add_theme_stylebox_override("panel", style)
		_selected_card.modulate = Color.WHITE if _selected_card.get_meta("is_unlocked", true) else Color(0.7, 0.7, 0.72, 1)

	_selected_card = card
	_kill_card_tween(card, "hover_tween")

	# 新选中态弹簧
	var tween_in := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(card, "scale", Vector2(1.03, 1.03), 0.15)
	tween_in.tween_property(card, "scale", Vector2.ONE, 0.2)
	card.set_meta("select_tween", tween_in)

	var style := _create_card_style(is_unlocked, true, false)
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color.WHITE

	_update_right_panel(hero_id, is_unlocked)
	_update_start_button(is_unlocked)


func _select_first_unlocked() -> void:
	for card in _hero_list_container.get_children():
		if card.get_meta("is_unlocked", false):
			_select_hero(card.get_meta("hero_id", ""), card, true)
			return
	if _hero_list_container.get_child_count() > 0:
		var first := _hero_list_container.get_child(0) as PanelContainer
		_select_hero(first.get_meta("hero_id", ""), first, first.get_meta("is_unlocked", false))


# ========== 右侧面板 ==========

func _update_right_panel(hero_id: String, is_unlocked: bool) -> void:
	var config: Dictionary = ConfigManager.get_hero_config(hero_id)
	if config.is_empty():
		return

	var portrait_color := Color.html(config.get("portrait_color", "#888888"))
	var portrait_path: String = ResourcePaths.get_hero_portrait(hero_id)

	# 立绘 fade + scale 切换
	var tween_out := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_out.tween_property(_big_portrait, "modulate:a", 0.0, 0.12)
	tween_out.parallel().tween_property(_big_portrait, "scale", Vector2(0.95, 0.95), 0.12)

	await tween_out.finished

	if is_unlocked:
		var tex: Texture2D = ResourcePaths.load_texture_safe(portrait_path)
		if tex != null:
			_big_portrait.texture = tex
			_big_portrait.modulate = Color.WHITE
		else:
			_big_portrait.texture = null
			_big_portrait.modulate = portrait_color
		_silhouette_label.visible = false
		_hero_name_label.text = config.get("hero_name", "")
		_hero_role_label.text = config.get("class_desc", "")
		_lock_overlay.visible = false
	else:
		_big_portrait.texture = null
		_big_portrait.modulate = Color(0.85, 0.85, 0.87, 1)
		_silhouette_label.visible = true
		_hero_name_label.text = "???"
		_hero_role_label.text = "被封印的传说"
		_lock_overlay.visible = true
		var condition: String = config.get("unlock_condition_text", "")
		_lock_label.text = condition if not condition.is_empty() else "未解锁"

	# 更新描述
	_desc_label.text = "[b]冒险者札记[/b]\n%s" % config.get("description", "")

	# 更新五维条
	_animate_stat_bars(config)

	# 立绘入场弹跳
	_big_portrait.scale = Vector2(1.05, 1.05)
	var tween_in := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_big_portrait, "modulate:a", 1.0, 0.18)
	tween_in.parallel().tween_property(_big_portrait, "scale", Vector2.ONE, 0.3)
	tween_in.tween_property(_big_portrait, "scale", Vector2(1.03, 1.03), 0.1)
	tween_in.tween_property(_big_portrait, "scale", Vector2.ONE, 0.15)


# ========== 开始按钮 ==========

func _update_start_button(is_unlocked: bool) -> void:
	if is_unlocked:
		_start_btn.disabled = false
		_start_btn.text = "踏上旅程"
	else:
		_start_btn.disabled = true
		_start_btn.text = "传说未解锁"


# ========== 五维条 ==========

func _build_stat_bars() -> void:
	var stats: Array[Dictionary] = [
		{"key": "vit", "name": "体魄", "color": STAT_COLORS["vit"]},
		{"key": "str", "name": "力量", "color": STAT_COLORS["str"]},
		{"key": "agi", "name": "敏捷", "color": STAT_COLORS["agi"]},
		{"key": "tec", "name": "技巧", "color": STAT_COLORS["tec"]},
		{"key": "mnd", "name": "精神", "color": STAT_COLORS["mnd"]},
	]

	for stat in stats:
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(112, 0)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		_stat_container.add_child(vbox)

		var name_label := Label.new()
		name_label.text = stat["name"]
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", stat["color"])
		name_label.add_theme_font_override("font", _font_cn)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(92, 10)
		bar.max_value = 100
		bar.value = 0
		bar.add_theme_stylebox_override("fill", _create_progress_style(stat["color"]))
		bar.add_theme_stylebox_override("background", _create_progress_bg_style())
		vbox.add_child(bar)

		var val_label := Label.new()
		val_label.text = "0"
		val_label.add_theme_font_size_override("font_size", 15)
		val_label.add_theme_color_override("font_color", RPG_INK)
		val_label.add_theme_font_override("font", _font_cn)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(val_label)

		_stat_bars[stat["key"]] = {"bar": bar, "label": val_label}


func _create_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _create_progress_bg_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PROGRESS_BG
	style.border_color = Color(0.55, 0.32, 0.12, 0.45)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _animate_stat_bars(config: Dictionary) -> void:
	var base_stats: Dictionary = {
		"vit": config.get("base_physique", 0),
		"str": config.get("base_strength", 0),
		"agi": config.get("base_agility", 0),
		"tec": config.get("base_technique", 0),
		"mnd": config.get("base_spirit", 0),
	}

	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	for key in base_stats.keys():
		var entry: Dictionary = _stat_bars.get(key, {})
		var bar: ProgressBar = entry.get("bar")
		var label: Label = entry.get("label")
		if bar == null or label == null:
			continue

		var target: float = clampf(base_stats[key] / 20.0 * 100.0, 0, 100)
		tween.tween_property(bar, "value", target, 0.4)
		_tween_label_number(label, base_stats[key], 0.4)


func _tween_label_number(label: Label, target_value: int, duration: float) -> void:
	var start_value: int = int(label.text) if label.text.is_valid_int() else 0
	var tween := create_tween()
	tween.tween_method(
		_tween_label_update.bind(label),
		start_value,
		target_value,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _tween_label_update(v: int, label: Label) -> void:
	label.text = str(v)


# ========== 难度切换（胶囊分段控件）==========

func _on_novice_toggled(pressed: bool) -> void:
	if pressed:
		_is_veteran_mode = false
		_veteran_btn.button_pressed = false
		_update_difficulty_buttons()


func _on_veteran_toggled(pressed: bool) -> void:
	if pressed:
		_is_veteran_mode = true
		_novice_btn.button_pressed = false
		_update_difficulty_buttons()


func _update_difficulty_buttons() -> void:
	_novice_btn.text = "轻松启程"
	_veteran_btn.text = "老练远征"
	var novice_on := _create_capsule_style(true, true)
	var novice_off := _create_capsule_style(false, true)
	var veteran_on := _create_capsule_style(true, false)
	var veteran_off := _create_capsule_style(false, false)

	_novice_btn.add_theme_stylebox_override("normal", novice_on if not _is_veteran_mode else novice_off)
	_novice_btn.add_theme_stylebox_override("pressed", novice_on if not _is_veteran_mode else novice_off)
	_novice_btn.add_theme_stylebox_override("hover", novice_on if not _is_veteran_mode else novice_off)
	_novice_btn.add_theme_color_override("font_color", Color.WHITE if not _is_veteran_mode else RPG_MUTE)

	_veteran_btn.add_theme_stylebox_override("normal", veteran_on if _is_veteran_mode else veteran_off)
	_veteran_btn.add_theme_stylebox_override("pressed", veteran_on if _is_veteran_mode else veteran_off)
	_veteran_btn.add_theme_stylebox_override("hover", veteran_on if _is_veteran_mode else veteran_off)
	_veteran_btn.add_theme_color_override("font_color", Color.WHITE if _is_veteran_mode else RPG_MUTE)


func _create_capsule_style(is_active: bool, is_left: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var radius := 22

	if is_active:
		s.bg_color = RPG_BLUE if is_left else RPG_RED
		s.border_color = RPG_GOLD
	else:
		s.bg_color = Color(0.98, 0.84, 0.58, 0.96)
		s.border_color = RPG_PARCHMENT_DARK

	s.border_width_left = 2 if is_left else 1
	s.border_width_top = 2
	s.border_width_right = 1 if is_left else 2
	s.border_width_bottom = 2

	if is_left:
		s.corner_radius_top_left = radius
		s.corner_radius_bottom_left = radius
		s.corner_radius_top_right = 0
		s.corner_radius_bottom_right = 0
	else:
		s.corner_radius_top_left = 0
		s.corner_radius_bottom_left = 0
		s.corner_radius_top_right = radius
		s.corner_radius_bottom_right = radius

	return s


# ========== 开始 / 返回 ==========

func _on_start_run_pressed() -> void:
	if _selected_hero_id.is_empty():
		return
	AudioManager.play_ui("confirm")

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_btn, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(_start_btn, "scale", Vector2.ONE, 0.15)

	_start_transition_to_run()


func _start_transition_to_run() -> void:
	# 创建 layer=10 的遮罩层，确保覆盖所有 UI（UILayer 在 layer 1）
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color.BLACK
	overlay.modulate = Color(1, 1, 1, 0)
	layer.add_child(overlay)

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25).from(Color(1, 1, 1, 0))

	_on_transition_finished()


func _on_transition_finished() -> void:
	GameManager.selected_hero_config_id = GameManager._HERO_STRING_TO_ID.get(_selected_hero_id, 1)
	GameManager.pending_archive["is_veteran"] = _is_veteran_mode
	GameManager.pending_archive["hero_id"] = _selected_hero_id
	EventBus.hero_selected.emit(_selected_hero_id)


func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()


# ========== 入场动画 ==========

func _play_entrance_animation() -> void:
	var elements: Array[Control] = [_top_bar, _left_panel_frame, _left_panel, _right_panel, _bottom_panel]
	for el in elements:
		if el == null:
			continue
		el.modulate.a = 0.0
		el.position.y += 25

	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(elements.size()):
		if elements[i] == null:
			continue
		var delay := i * 0.05
		if i == 0:
			tween.tween_property(elements[i], "modulate:a", 1.0, 0.28).set_delay(delay)
		else:
			tween.parallel().tween_property(elements[i], "modulate:a", 1.0, 0.28).set_delay(delay)
		tween.parallel().tween_property(elements[i], "position:y", elements[i].position.y - 25, 0.32).set_delay(delay)
