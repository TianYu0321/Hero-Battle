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

# --- 左侧面板 ---
@onready var _hero_list_container: VBoxContainer = $UILayer/LeftPanel/HeroListContainer

# --- 右侧面板 ---
@onready var _big_portrait: ColorRect = $UILayer/RightPanel/HeroBigPortrait
@onready var _silhouette_label: Label = $UILayer/RightPanel/HeroBigPortrait/SilhouetteLabel
@onready var _hero_name_label: Label = $UILayer/RightPanel/HeroNameLabel
@onready var _hero_role_label: Label = $UILayer/RightPanel/HeroRoleLabel
@onready var _lock_overlay: ColorRect = $UILayer/RightPanel/LockOverlay
@onready var _lock_label: Label = $UILayer/RightPanel/LockOverlay/LockLabel

# --- 底部 ---
@onready var _stat_container: HBoxContainer = $UILayer/BottomPanel/StatPreviewContainer
@onready var _desc_label: RichTextLabel = $UILayer/BottomPanel/DescriptionPanel/DescriptionLabel
@onready var _start_btn: Button = $UILayer/BottomPanel/StartRunButton

# --- 过渡 ---
@onready var _transition_overlay: ColorRect = $UILayer/TransitionOverlay
@onready var _transition_label: Label = $UILayer/TransitionOverlay/TransitionLabel

var _hero_ids: Array[String] = []
var _selected_hero_id: String = ""
var _selected_card: PanelContainer = null
var _is_veteran_mode: bool = false

# 五维条缓存 {stat_name: {bar: ProgressBar, label: Label}}
var _stat_bars: Dictionary = {}

# 颜色常量
const COLOR_GOLD := Color(0.901961, 0.752941, 0.25098, 1)
const COLOR_BLUE := Color(0.352941, 0.560784, 0.815686, 1)
const COLOR_RED := Color(0.85098, 0.219608, 0.14902, 1)
const COLOR_GRAY := Color(0.4, 0.4, 0.45, 1)
const COLOR_CARD_BG := Color(0.101961, 0.101961, 0.121569, 1)
const COLOR_CARD_BORDER := Color(0.2, 0.2, 0.22, 1)
const COLOR_CARD_SELECTED_BG := Color(0.145098, 0.145098, 0.188235, 1)

# 属性颜色映射
const STAT_COLORS: Dictionary = {
	"vit": Color(0.305882, 0.803922, 0.768627, 1),   # 绿 #4ECDC4
	"str": Color(1, 0.419608, 0.419608, 1),           # 红 #FF6B6B
	"agi": Color(0.901961, 0.752941, 0.25098, 1),     # 黄 #E6C040
	"tec": Color(0.352941, 0.560784, 0.815686, 1),    # 蓝 #5A8FD0
	"mnd": Color(0.607843, 0.34902, 0.713725, 1),     # 紫 #9B59B6
}

func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_start_btn.pressed.connect(_on_start_run_pressed)
	_novice_btn.toggled.connect(_on_novice_toggled)
	_veteran_btn.toggled.connect(_on_veteran_toggled)
	
	# 默认新手模式
	_update_difficulty_buttons()
	
	# 读取英雄配置
	var all_configs: Dictionary = ConfigManager.get_all_hero_configs()
	# 按 sort_order 排序
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

func _populate_hero_cards() -> void:
	# 清空现有
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
	
	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_CARD_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	
	# 内部布局
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(hbox)
	
	# 头像色块 (48x48)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.color = Color.html(config.get("portrait_color", "#888888"))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(portrait)
	
	# 如果是锁定状态，头像变灰
	if not is_unlocked:
		portrait.modulate = Color(0.5, 0.5, 0.5, 1)
	
	# 文字区
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(vbox)
	
	var name_label := Label.new()
	name_label.text = config.get("hero_name", hero_id)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE if is_unlocked else Color(0.5, 0.5, 0.5, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(name_label)
	
	var role_label := Label.new()
	role_label.text = config.get("class_desc", "")
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1) if is_unlocked else Color(0.4, 0.4, 0.4, 1))
	role_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(role_label)
	
	# 交互
	card.gui_input.connect(_on_card_gui_input.bind(hero_id, card, is_unlocked))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card))
	
	# 存储数据到 card
	card.set_meta("hero_id", hero_id)
	card.set_meta("is_unlocked", is_unlocked)
	
	return card

func _on_card_gui_input(event: InputEvent, hero_id: String, card: PanelContainer, is_unlocked: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_hero(hero_id, card, is_unlocked)

func _on_card_mouse_entered(card: PanelContainer) -> void:
	if card == _selected_card:
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color(1.1, 1.1, 1.2, 1.0), 0.15)
	# 边框变蓝
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.border_color = COLOR_BLUE
	card.add_theme_stylebox_override("panel", style)

func _on_card_mouse_exited(card: PanelContainer) -> void:
	if card == _selected_card:
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color.WHITE, 0.15)
	# 恢复默认边框
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.border_color = COLOR_CARD_BORDER
	card.add_theme_stylebox_override("panel", style)

func _select_hero(hero_id: String, card: PanelContainer, is_unlocked: bool) -> void:
	_selected_hero_id = hero_id
	
	# 更新卡片选中态
	if _selected_card != null and is_instance_valid(_selected_card):
		var old_style: StyleBoxFlat = _selected_card.get_theme_stylebox("panel").duplicate()
		old_style.bg_color = COLOR_CARD_BG
		old_style.border_width_left = 1
		old_style.border_color = COLOR_CARD_BORDER
		_selected_card.add_theme_stylebox_override("panel", old_style)
		_selected_card.modulate = Color.WHITE
	
	_selected_card = card
	var new_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	new_style.bg_color = COLOR_CARD_SELECTED_BG
	new_style.border_width_left = 4
	new_style.border_color = COLOR_GOLD
	card.add_theme_stylebox_override("panel", new_style)
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
	# 全锁定则选第一个
	if _hero_list_container.get_child_count() > 0:
		var first := _hero_list_container.get_child(0) as PanelContainer
		_select_hero(first.get_meta("hero_id", ""), first, first.get_meta("is_unlocked", false))

func _update_right_panel(hero_id: String, is_unlocked: bool) -> void:
	var config: Dictionary = ConfigManager.get_hero_config(hero_id)
	if config.is_empty():
		return
	
	var portrait_color := Color.html(config.get("portrait_color", "#888888"))
	
	# 立绘 fade 切换
	var tween_out := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_out.tween_property(_big_portrait, "modulate:a", 0.0, 0.12)
	
	await tween_out.finished
	
	if is_unlocked:
		_big_portrait.color = portrait_color
		_silhouette_label.visible = false
		_hero_name_label.text = config.get("hero_name", "")
		_hero_role_label.text = config.get("class_desc", "")
		_lock_overlay.visible = false
	else:
		_big_portrait.color = Color(0.06, 0.06, 0.08, 1)
		_silhouette_label.visible = true
		_hero_name_label.text = "???"
		_hero_role_label.text = "???"
		_lock_overlay.visible = true
		var condition: String = config.get("unlock_condition_text", "")
		if not condition.is_empty():
			_lock_label.text = condition
		else:
			_lock_label.text = "未解锁"
	
	# 更新描述
	_desc_label.text = config.get("description", "")
	
	# 更新五维条
	_animate_stat_bars(config)
	
	var tween_in := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_big_portrait, "modulate:a", 1.0, 0.18)

func _update_start_button(is_unlocked: bool) -> void:
	if is_unlocked:
		_start_btn.disabled = false
		_start_btn.self_modulate = Color.WHITE
		_start_btn.text = "进入斗技场"
	else:
		_start_btn.disabled = true
		_start_btn.self_modulate = Color(1, 1, 1, 0.4)
		_start_btn.text = "未解锁"

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
		val_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
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
	style.bg_color = Color(0.15, 0.15, 0.18, 1)
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
		
		# 数值标签动画（用回调实现）
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

# --- 难度切换 ---

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
	var novice_style_on := _create_difficulty_style(true, false)
	var novice_style_off := _create_difficulty_style(false, false)
	var veteran_style_on := _create_difficulty_style(true, true)
	var veteran_style_off := _create_difficulty_style(false, true)
	
	_novice_btn.add_theme_stylebox_override("normal", novice_style_on if not _is_veteran_mode else novice_style_off)
	_novice_btn.add_theme_stylebox_override("pressed", novice_style_on if not _is_veteran_mode else novice_style_off)
	_novice_btn.add_theme_stylebox_override("hover", novice_style_on if not _is_veteran_mode else novice_style_off)
	
	_veteran_btn.add_theme_stylebox_override("normal", veteran_style_on if _is_veteran_mode else veteran_style_off)
	_veteran_btn.add_theme_stylebox_override("pressed", veteran_style_on if _is_veteran_mode else veteran_style_off)
	_veteran_btn.add_theme_stylebox_override("hover", veteran_style_on if _is_veteran_mode else veteran_style_off)

func _create_difficulty_style(is_active: bool, is_veteran: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.15, 0.18, 0.25, 1)
		style.border_color = COLOR_BLUE if not is_veteran else COLOR_RED
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 1)
		style.border_color = Color(0.3, 0.3, 0.32, 1)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

# --- 开始 / 返回 ---

func _on_start_run_pressed() -> void:
	if _selected_hero_id.is_empty():
		return
	AudioManager.play_ui("confirm")
	_start_transition_to_run()

func _start_transition_to_run() -> void:
	_transition_overlay.visible = true
	_transition_overlay.modulate.a = 0.0
	
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, 0.4)
	tween.finished.connect(_on_transition_finished)

func _on_transition_finished() -> void:
	GameManager.selected_hero_config_id = GameManager._HERO_STRING_TO_ID.get(_selected_hero_id, 1)
	GameManager.pending_archive["is_veteran"] = _is_veteran_mode
	EventBus.hero_selected.emit(_selected_hero_id)

func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()
