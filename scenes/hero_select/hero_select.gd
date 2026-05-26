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
@onready var _desc_label: RichTextLabel = $UILayer/BottomPanel/Content/DescriptionPanel/DescriptionLabel
@onready var _start_btn: Button = $UILayer/BottomPanel/Content/StartRunButton

# --- 过渡 ---
@onready var _transition_overlay: ColorRect = $TransitionOverlay
@onready var _transition_label: Label = $TransitionOverlay/TransitionLabel

var _hero_ids: Array[String] = []
var _selected_hero_id: String = ""
var _selected_card: PanelContainer = null
var _is_veteran_mode: bool = false

# 五维条缓存 {stat_name: {bar: ProgressBar, label: Label}}
var _stat_bars: Dictionary = {}

# 可爱字体
var _font_cn: FontFile
var _font_en: FontFile

# ========== 颜色常量（明亮风格） ==========

const COLOR_TEXT_DARK := Color(0.176, 0.216, 0.282, 1)   # #2D3748 深蓝灰
const COLOR_TEXT_BODY := Color(0.29, 0.333, 0.408, 1)        # #4A5568 暖灰蓝
const COLOR_TEXT_MUTE := Color(0.443, 0.502, 0.588, 1)       # #718096 浅灰蓝
const COLOR_TEXT_LIGHT := Color(0.627, 0.682, 0.753, 1)      # #A0AEC0 更浅
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

# 属性颜色映射
const STAT_COLORS: Dictionary = {
	"vit": Color(0.305882, 0.803922, 0.768627, 1),   # 绿
	"str": Color(1, 0.419608, 0.419608, 1),           # 红
	"agi": Color(0.901961, 0.752941, 0.25098, 1),     # 黄
	"tec": Color(0.352941, 0.560784, 0.815686, 1),    # 蓝
	"mnd": Color(0.607843, 0.34902, 0.713725, 1),     # 紫
}

# ========== 生命周期 ==========

func _ready() -> void:
	# 加载可爱字体
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
	
	# 设置样式
	_setup_top_bar()
	_setup_right_panel_style()
	_setup_bottom_panel_style()
	_setup_start_button_style()
	
	# 应用可爱字体到所有子控件
	_apply_fonts_recursive(self)
	print("[HeroSelect] 字体已应用: cn=", _font_cn != null, " en=", _font_en != null)
	
	# 延迟设置立绘中心点
	call_deferred("_setup_portrait_pivot")
	
	# 默认新手模式
	_update_difficulty_buttons()
	
	# 读取英雄配置
	var all_configs: Dictionary = ConfigManager.get_all_hero_configs()
	var sorted: Array = all_configs.keys()
	sorted.sort_custom(func(a, b):
		return all_configs[a].get("sort_order", 0) < all_configs[b].get("sort_order", 0)
	)
	_hero_ids.assign(sorted)
	
	# 构建左侧列表
	_populate_hero_cards()
	
	# 构建五维条
	_build_stat_bars()
	
	# 默认选中第一个已解锁英雄
	_select_first_unlocked()
	
	# 入场动画
	_play_entrance_animation()

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
	# 标题
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.9, 0.95, 1, 1))
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.add_theme_color_override("font_outline_color", Color(0.8, 0.85, 0.95, 1))
	_title_label.add_theme_constant_override("outline_size", 2)
	
	# 返回按钮
	_back_btn.custom_minimum_size = Vector2(120, 50)
	var back_normal := _create_btn_style(COLOR_BG_PANEL, COLOR_CARD_BORDER, 2, 8, 6, Color(0, 0, 0, 0.06))
	var back_hover := _create_btn_style(COLOR_BG_PANEL, COLOR_BLUE, 2, 8, 8, Color(0.4, 0.6, 1, 0.15))
	_back_btn.add_theme_stylebox_override("normal", back_normal)
	_back_btn.add_theme_stylebox_override("hover", back_hover)
	_back_btn.add_theme_stylebox_override("pressed", back_hover)
	_back_btn.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	_back_btn.add_theme_font_size_override("font_size", 16)

func _setup_right_panel_style() -> void:
	var s := _create_panel_style(15)
	_right_panel.add_theme_stylebox_override("panel", s)

func _setup_bottom_panel_style() -> void:
	var s := _create_panel_style(12)
	_bottom_panel.add_theme_stylebox_override("panel", s)

func _setup_start_button_style() -> void:
	_start_btn.custom_minimum_size = Vector2(240, 56)
	var normal := _create_start_btn_style(COLOR_BLUE, COLOR_BLUE, 8, Color(0, 0, 0, 0.1))
	var hover := _create_start_btn_style(COLOR_BLUE_LIGHT, COLOR_BLUE_LIGHT, 12, Color(0.4, 0.6, 1, 0.2))
	var pressed := _create_start_btn_style(COLOR_BLUE_DARK, COLOR_BLUE_DARK, 4, Color(0, 0, 0, 0.15))
	var disabled := _create_start_btn_style(Color(0.85, 0.85, 0.87), Color(0.85, 0.85, 0.87), 0, Color(0, 0, 0, 0))
	_start_btn.add_theme_stylebox_override("normal", normal)
	_start_btn.add_theme_stylebox_override("hover", hover)
	_start_btn.add_theme_stylebox_override("pressed", pressed)
	_start_btn.add_theme_stylebox_override("disabled", disabled)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_disabled_color", COLOR_GRAY)
	_start_btn.add_theme_font_size_override("font_size", 20)

func _create_panel_style(shadow_size: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_PANEL
	s.border_color = Color(0.9, 0.9, 0.9, 1)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	s.shadow_color = Color(0, 0, 0, 0.12)
	s.shadow_size = shadow_size
	s.shadow_offset = Vector2(0, 8)
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
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 4  # 底部加粗
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
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
	card.custom_minimum_size = Vector2(280, 72)
	card.size_flags_horizontal = Control.SIZE_FILL
	
	# 默认样式
	var style := _create_card_style(is_unlocked, false, false)
	card.add_theme_stylebox_override("panel", style)
	
	# 内部布局
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(hbox)
	
	var portrait_color := Color.html(config.get("portrait_color", "#888888"))
	
	# 头像
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(48, 48)
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
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_DARK if is_unlocked else COLOR_GRAY)
	name_label.add_theme_font_override("font", _font_cn)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(name_label)
	
	var role_label := Label.new()
	role_label.text = config.get("class_desc", "")
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", COLOR_GRAY_LIGHT if is_unlocked else Color(0.7, 0.7, 0.72, 1))
	role_label.add_theme_font_override("font", _font_cn)
	role_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(role_label)
	
	# 未解锁锁图标
	if not is_unlocked:
		card.modulate = Color(0.7, 0.7, 0.72, 1)
		var lock_icon := Label.new()
		lock_icon.text = "🔒"
		lock_icon.add_theme_font_size_override("font_size", 20)
		lock_icon.add_theme_color_override("font_color", COLOR_GRAY_LIGHT)
		lock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_child(lock_icon)
	
	# 交互
	card.gui_input.connect(_on_card_gui_input.bind(hero_id, card, is_unlocked))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card))
	
	# 存储数据
	card.set_meta("hero_id", hero_id)
	card.set_meta("is_unlocked", is_unlocked)
	
	return card

func _create_card_style(is_unlocked: bool, is_selected: bool, is_hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	
	if is_selected:
		s.bg_color = COLOR_BG_SELECTED
		s.border_color = COLOR_BLUE
		s.border_width_left = 4
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.shadow_color = Color(0.4, 0.6, 1, 0.2)
		s.shadow_size = 12
	elif is_hover:
		s.bg_color = COLOR_BG_PANEL
		s.border_color = COLOR_CARD_BORDER_HOVER
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.shadow_color = Color(0.4, 0.6, 1, 0.15)
		s.shadow_size = 10
	else:
		s.bg_color = COLOR_BG_PANEL
		s.border_color = COLOR_CARD_BORDER
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.shadow_color = Color(0, 0, 0, 0.06)
		s.shadow_size = 6
	
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
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
	
	# 新选中态弹跳
	var tween_in := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(card, "scale", Vector2(1.03, 1.03), 0.15)
	tween_in.tween_property(card, "scale", Vector2.ONE, 0.2)
	card.set_meta("select_tween", tween_in)
	
	var style := _create_card_style(is_unlocked, true, false)
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color.WHITE
	
	# 更新右侧展示
	_update_right_panel(hero_id, is_unlocked)
	
	# 更新开始按钮
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
		_hero_role_label.text = "???"
		_lock_overlay.visible = true
		var condition: String = config.get("unlock_condition_text", "")
		_lock_label.text = condition if not condition.is_empty() else "未解锁"
	
	# 更新描述
	_desc_label.text = config.get("description", "")
	
	# 更新五维条
	_animate_stat_bars(config)
	
	# 立绘入场弹跳 + 额外一次小弹跳
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
		_start_btn.text = "出发"
	else:
		_start_btn.disabled = true
		_start_btn.text = "未解锁"

# ========== 五维条 ==========

func _build_stat_bars() -> void:
	var stats: Array[Dictionary] = [
		{"key": "vit", "name": "Vit", "color": STAT_COLORS["vit"]},
		{"key": "str", "name": "Str", "color": STAT_COLORS["str"]},
		{"key": "agi", "name": "Agi", "color": STAT_COLORS["agi"]},
		{"key": "tec", "name": "Tec", "color": STAT_COLORS["tec"]},
		{"key": "mnd", "name": "Mnd", "color": STAT_COLORS["mnd"]},
	]
	
	for stat in stats:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		_stat_container.add_child(vbox)
		
		var name_label := Label.new()
		name_label.text = stat["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", stat["color"])
		name_label.add_theme_font_override("font", _font_cn)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)
		
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(64, 8)
		bar.max_value = 100
		bar.value = 0
		bar.add_theme_stylebox_override("fill", _create_progress_style(stat["color"]))
		bar.add_theme_stylebox_override("background", _create_progress_bg_style())
		vbox.add_child(bar)
		
		var val_label := Label.new()
		val_label.text = "0"
		val_label.add_theme_font_size_override("font_size", 12)
		val_label.add_theme_color_override("font_color", COLOR_GRAY)
		val_label.add_theme_font_override("font", _font_cn)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(val_label)
		
		_stat_bars[stat["key"]] = {"bar": bar, "label": val_label}

func _create_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

func _create_progress_bg_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PROGRESS_BG
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
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

# ========== 难度切换（胶囊分段控件） ==========

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
	var novice_on := _create_capsule_style(true, true)
	var novice_off := _create_capsule_style(false, true)
	var veteran_on := _create_capsule_style(true, false)
	var veteran_off := _create_capsule_style(false, false)
	
	_novice_btn.add_theme_stylebox_override("normal", novice_on if not _is_veteran_mode else novice_off)
	_novice_btn.add_theme_stylebox_override("pressed", novice_on if not _is_veteran_mode else novice_off)
	_novice_btn.add_theme_stylebox_override("hover", novice_on if not _is_veteran_mode else novice_off)
	_novice_btn.add_theme_color_override("font_color", Color.WHITE if not _is_veteran_mode else COLOR_GRAY)
	
	_veteran_btn.add_theme_stylebox_override("normal", veteran_on if _is_veteran_mode else veteran_off)
	_veteran_btn.add_theme_stylebox_override("pressed", veteran_on if _is_veteran_mode else veteran_off)
	_veteran_btn.add_theme_stylebox_override("hover", veteran_on if _is_veteran_mode else veteran_off)
	_veteran_btn.add_theme_color_override("font_color", Color.WHITE if _is_veteran_mode else COLOR_GRAY)

func _create_capsule_style(is_active: bool, is_left: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var radius := 22
	
	if is_active:
		s.bg_color = COLOR_BLUE if is_left else COLOR_RED
		s.border_color = COLOR_BLUE if is_left else COLOR_RED
	else:
		s.bg_color = Color(0.95, 0.95, 0.95, 1)
		s.border_color = COLOR_CARD_BORDER
	
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
	
	# 弹性点击（Fire and Forget，不阻塞交互）
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_btn, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(_start_btn, "scale", Vector2.ONE, 0.15)
	
	# 立即开始过渡
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
	
	# 黑场渐变（0.25s），不等完成——避免画面卡顿期
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25).from(Color(1, 1, 1, 0))
	
	# 立即发射信号，由 GameManager 在新场景上淡出
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
	var elements: Array[Control] = [_top_bar, _left_panel, _right_panel, _bottom_panel]
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
