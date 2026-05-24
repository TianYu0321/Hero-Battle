## res://scenes/tavern/tavern.gd
## 模块: TavernUI (Party Assemble)
## 职责: 酒馆集结界面，展示可用伙伴，选择3名首发伙伴组成初始队伍
## 依赖: EventBus, ConfigManager, PartyAssembleSettings
## 被依赖: 无
## class_name: TavernUI

class_name TavernUI
extends Control

# --- 顶层引用 ---
@onready var _top_bar: HBoxContainer = $UILayer/TopBar
@onready var _back_btn: Button = $UILayer/TopBar/BackButton
@onready var _title_label: Label = $UILayer/TopBar/TitleLabel
@onready var _step_label: Label = $UILayer/TopBar/StepLabel

@onready var _hero_banner: PanelContainer = $UILayer/SelectedHeroBanner
@onready var _hero_portrait: TextureRect = $UILayer/SelectedHeroBanner/HBoxContainer/HeroPortrait
@onready var _hero_name_label: Label = $UILayer/SelectedHeroBanner/HBoxContainer/HeroInfoVBox/HeroNameLabel
@onready var _hero_class_label: Label = $UILayer/SelectedHeroBanner/HBoxContainer/HeroInfoVBox/HeroClassLabel

@onready var _mid_section: HBoxContainer = $UILayer/MidSection
@onready var _left_panel: VBoxContainer = $UILayer/MidSection/LeftPanel
@onready var _pool_title: Label = $UILayer/MidSection/LeftPanel/PoolTitle
@onready var _partner_pool_grid: GridContainer = $UILayer/MidSection/LeftPanel/PartnerPool/PartnerPoolGrid

@onready var _right_panel: VBoxContainer = $UILayer/MidSection/RightPanel
@onready var _team_title: Label = $UILayer/MidSection/RightPanel/TeamTitle
@onready var _team_slots: HBoxContainer = $UILayer/MidSection/RightPanel/TeamSlots

@onready var _bottom_bar: HBoxContainer = $UILayer/BottomBar
@onready var _team_stats_preview: HBoxContainer = $UILayer/BottomBar/TeamStatsPreview
@onready var _start_btn: Button = $UILayer/BottomBar/StartRunButton

@onready var _transition_overlay: ColorRect = $TransitionOverlay

# --- 数据状态 ---
var _partner_ids: Array[String] = []
var _selected_team: Array[Dictionary] = []
# --- 字体 ---
var _font_cn: FontFile

# --- 常量快捷引用 ---
const SETTINGS = preload("res://scripts/core/party_assemble_settings.gd")

# ========== 生命周期 ==========

func _ready() -> void:
	# 加载字体
	_font_cn = load("res://assets/fonts/cute/ZCOOLKuaiLe-Regular.ttf")
	if _font_cn == null:
		push_error("[Tavern] 中文字体加载失败")
	
	# 连接信号
	_back_btn.pressed.connect(_on_back_pressed)
	_start_btn.pressed.connect(_on_start_run_pressed)
	
	# 设置UI样式
	_setup_top_bar()
	_setup_hero_banner()
	_setup_team_slots()
	_setup_start_button()
	_setup_pool_title()
	
	# 读取可用伙伴
	_partner_ids = _get_available_partner_ids()
	
	# 填充伙伴池
	_populate_partner_pool()
	
	# 应用字体
	_apply_fonts_recursive(self)
	
	# 入场动画
	_play_entrance_animation()

# ========== 字体应用 ==========

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

# ========== StyleBox 辅助 ==========

func _create_stylebox(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	bottom_border: int,
	radius: int,
	shadow_size: int,
	shadow_offset: Vector2,
	shadow_color: Color
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_color = border_color
	s.border_width_left = border_width
	s.border_width_top = border_width
	s.border_width_right = border_width
	s.border_width_bottom = bottom_border
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.shadow_color = shadow_color
	s.shadow_size = shadow_size
	s.shadow_offset = shadow_offset
	return s

func _create_card_style(state: String) -> StyleBoxFlat:
	match state:
		"normal":
			return _create_stylebox(
				SETTINGS.COLOR_BG_PANEL,
				SETTINGS.COLOR_BORDER, 2, 3,
				SETTINGS.RADIUS_CARD,
				SETTINGS.SHADOW_CARD_NORMAL.size,
				SETTINGS.SHADOW_CARD_NORMAL.offset,
				SETTINGS.SHADOW_CARD_NORMAL.color
			)
		"hover":
			return _create_stylebox(
				SETTINGS.COLOR_BG_PANEL,
				SETTINGS.COLOR_BORDER_HOVER, 2, 3,
				SETTINGS.RADIUS_CARD,
				SETTINGS.SHADOW_CARD_HOVER.size,
				SETTINGS.SHADOW_CARD_HOVER.offset,
				SETTINGS.SHADOW_CARD_HOVER.color
			)
		"selected":
			return _create_stylebox(
				SETTINGS.COLOR_BG_SELECTED,
				SETTINGS.COLOR_BORDER_SELECTED, 3, 4,
				SETTINGS.RADIUS_CARD,
				SETTINGS.SHADOW_CARD_SELECTED.size,
				SETTINGS.SHADOW_CARD_SELECTED.offset,
				SETTINGS.SHADOW_CARD_SELECTED.color
			)
		"disabled":
			return _create_stylebox(
				Color(0.94, 0.94, 0.96, 0.5),
				Color(0.8, 0.8, 0.82, 0.5), 2, 2,
				SETTINGS.RADIUS_CARD,
				0, Vector2.ZERO, Color.TRANSPARENT
			)
		_:
			return _create_card_style("normal")

# ========== 顶部栏 ==========

func _setup_top_bar() -> void:
	_back_btn.custom_minimum_size = Vector2(120, 48)
	_back_btn.add_theme_font_size_override("font_size", 16)
	_back_btn.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	
	# 返回按钮样式
	var back_normal := _create_stylebox(
		SETTINGS.COLOR_BG_PANEL, SETTINGS.COLOR_BORDER, 2, 2,
		SETTINGS.RADIUS_BUTTON, 4, Vector2(0, 2), Color(0, 0, 0, 0.06)
	)
	var back_hover := _create_stylebox(
		SETTINGS.COLOR_BG_PANEL, SETTINGS.COLOR_BORDER_HOVER, 2, 2,
		SETTINGS.RADIUS_BUTTON, 6, Vector2(0, 3), Color(0.4, 0.6, 1, 0.1)
	)
	_back_btn.add_theme_stylebox_override("normal", back_normal)
	_back_btn.add_theme_stylebox_override("hover", back_hover)
	_back_btn.add_theme_stylebox_override("pressed", back_hover)
	
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	
	_step_label.add_theme_font_size_override("font_size", 14)
	_step_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)

# ========== 主角横幅 ==========

func _setup_hero_banner() -> void:
	_hero_banner.add_theme_stylebox_override("panel", _create_stylebox(
		SETTINGS.COLOR_BG_SELECTED,
		SETTINGS.COLOR_BORDER, 2, 2,
		SETTINGS.RADIUS_CARD,
		4, Vector2(0, 2), Color(0, 0, 0, 0.06)
	))
	
	var hero_id: String = GameManager.pending_archive.get("hero_id", "")
	var config: Dictionary = ConfigManager.get_hero_config(hero_id) if not hero_id.is_empty() else {}
	
	if not config.is_empty():
		var portrait_path: String = ConfigManager.get_hero_avatar_path(hero_id)
		if not portrait_path.is_empty():
			var tex: Texture2D = load(portrait_path)
			if tex != null:
				_hero_portrait.texture = tex
		
		_hero_name_label.text = config.get("hero_name", "???")
		_hero_class_label.text = config.get("class_desc", "")
	else:
		_hero_name_label.text = "???"
		_hero_class_label.text = ""
	
	_hero_name_label.add_theme_font_size_override("font_size", 16)
	_hero_name_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	_hero_class_label.add_theme_font_size_override("font_size", 12)
	_hero_class_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)

# ========== 队伍槽位初始化 ==========

func _setup_team_slots() -> void:
	for i in range(SETTINGS.MAX_TEAM_SIZE):
		var slot: PanelContainer = _team_slots.get_child(i)
		if slot == null:
			continue
		# 统一连接一次点击信号
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		_reset_team_slot(i)

func _reset_team_slot(index: int) -> void:
	var slot: PanelContainer = _team_slots.get_child(index)
	if slot == null:
		return
	
	# 清除旧内容
	for child in slot.get_children():
		child.queue_free()
	
	# 空槽样式
	slot.add_theme_stylebox_override("panel", _create_stylebox(
		Color(0.94, 0.94, 0.96, 1),
		Color(0.8, 0.8, 0.82, 1), 2, 2,
		SETTINGS.RADIUS_CARD,
		4, Vector2(0, 1), Color(0, 0, 0, 0.04)
	))
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)
	
	var plus_label := Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 48)
	plus_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(plus_label)
	
	var hint_label := Label.new()
	hint_label.text = "点击左侧伙伴加入"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.68, 1))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_label)

# ========== 开始按钮 ==========

func _setup_start_button() -> void:
	_start_btn.custom_minimum_size = Vector2(220, 56)
	_start_btn.add_theme_font_size_override("font_size", 18)
	_start_btn.disabled = true
	
	# 正常态：蓝色底
	var normal := _create_stylebox(
		Color(0.25, 0.55, 0.95, 1),
		Color(0.2, 0.45, 0.85, 1), 2, 4,
		SETTINGS.RADIUS_BUTTON,
		6, Vector2(0, 3), Color(0.25, 0.55, 0.95, 0.2)
	)
	_start_btn.add_theme_stylebox_override("normal", normal)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	
	# hover态
	var hover := _create_stylebox(
		Color(0.35, 0.65, 1.0, 1),
		Color(0.3, 0.55, 0.95, 1), 2, 4,
		SETTINGS.RADIUS_BUTTON,
		10, Vector2(0, 4), Color(0.35, 0.65, 1.0, 0.3)
	)
	_start_btn.add_theme_stylebox_override("hover", hover)
	_start_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# disabled态
	var disabled := _create_stylebox(
		Color(0.88, 0.88, 0.9, 1),
		Color(0.75, 0.75, 0.77, 1), 2, 3,
		SETTINGS.RADIUS_BUTTON,
		0, Vector2.ZERO, Color.TRANSPARENT
	)
	_start_btn.add_theme_stylebox_override("disabled", disabled)
	_start_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.52, 1))

func _setup_pool_title() -> void:
	_pool_title.add_theme_font_size_override("font_size", 18)
	_pool_title.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)

# ========== 伙伴池填充 ==========

func _get_available_partner_ids() -> Array[String]:
	var user_id: String = SaveManager.get_user_id()
	var unlock_state: Dictionary = SaveManager.load_unlock_state(user_id)
	var unlocked_ids: Array = unlock_state.get("unlocked_partners", [])
	var unlocked: Array = []
	for pid in unlocked_ids:
		unlocked.append(str(pid))
	
	var all_ids: Array[String] = ConfigManager.get_all_partner_ids()
	var result: Array[String] = []
	for pid in all_ids:
		var cfg: Dictionary = ConfigManager.get_partner_config(pid)
		var is_default: bool = cfg.get("is_default_unlock", false)
		var pid_str: String = str(cfg.get("id", ""))
		if is_default or (pid_str in unlocked):
			result.append(pid)
	return result

func _populate_partner_pool() -> void:
	# 清除旧卡片
	for child in _partner_pool_grid.get_children():
		child.queue_free()
	
	for partner_id in _partner_ids:
		var config: Dictionary = ConfigManager.get_partner_config(partner_id)
		if config.is_empty():
			continue
		
		# 注入字符串ID便于后续匹配
		config["partner_id_str"] = partner_id
		
		var card := _create_pool_card(partner_id, config)
		_partner_pool_grid.add_child(card)

# ========== 创建池子卡片 ==========

func _create_pool_card(partner_id: String, partner: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(SETTINGS.CARD_WIDTH, SETTINGS.CARD_HEIGHT)
	card.set_meta("partner_id", partner_id)
	card.set_meta("partner_data", partner)
	card.set_meta("state", "normal")
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_as_relative = false  # z_index 全局生效，hover放大时不被相邻卡片遮盖
	
	# 基础样式（代码样式：白底+边框+阴影）
	card.add_theme_stylebox_override("panel", _create_card_style("normal"))
	
	# === 背景图保留（默认隐藏，方便切换）===
	var card_bg := TextureRect.new()
	card_bg.name = "CardBg"
	card_bg.anchors_preset = Control.PRESET_FULL_RECT
	card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_bg.visible = false  # 默认使用代码样式，设为 true 可切换为图片背景
	var card_path: String = ConfigManager.get_partner_card_path(partner_id, 1)
	if not card_path.is_empty():
		var bg_tex: Texture2D = load(card_path)
		if bg_tex != null:
			card_bg.texture = bg_tex
	card.add_child(card_bg)
	
	# 内部垂直布局
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	
	# 等级角标
	var level_label := Label.new()
	level_label.text = "Lv.%d" % partner.get("level", 1)
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_GOLD)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)
	
	# 正方形头像容器（带圆角背景）
	var avatar_container := PanelContainer.new()
	avatar_container.custom_minimum_size = Vector2(SETTINGS.CARD_AVATAR_SIZE, SETTINGS.CARD_AVATAR_SIZE)
	var avatar_bg := StyleBoxFlat.new()
	avatar_bg.bg_color = Color(0.95, 0.95, 0.97, 1)
	avatar_bg.corner_radius_top_left = SETTINGS.RADIUS_AVATAR
	avatar_bg.corner_radius_top_right = SETTINGS.RADIUS_AVATAR
	avatar_bg.corner_radius_bottom_left = SETTINGS.RADIUS_AVATAR
	avatar_bg.corner_radius_bottom_right = SETTINGS.RADIUS_AVATAR
	avatar_container.add_theme_stylebox_override("panel", avatar_bg)
	avatar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(avatar_container)
	
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(SETTINGS.CARD_AVATAR_SIZE, SETTINGS.CARD_AVATAR_SIZE)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_path: String = partner.get("avatar_path", "")
	if avatar_path.is_empty():
		avatar_path = partner.get("icon_path", "")
	if not avatar_path.is_empty():
		var tex: Texture2D = load(avatar_path)
		if tex != null:
			avatar.texture = tex
	avatar_container.add_child(avatar)
	
	# 名字
	var name_label := Label.new()
	name_label.text = partner.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# 职业
	var class_label := Label.new()
	class_label.text = _format_role_label(partner.get("title", "伙伴"))
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(class_label)
	
	# 稀有度条
	var rarity_bar := ColorRect.new()
	rarity_bar.custom_minimum_size = Vector2(140, 3)
	rarity_bar.color = _get_rarity_color(str(partner.get("rarity", "common")))
	rarity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_bar)
	
	# 交互
	card.gui_input.connect(_on_card_gui_input.bind(card, partner))
	card.mouse_entered.connect(_on_card_hover_enter.bind(card))
	card.mouse_exited.connect(_on_card_hover_exit.bind(card))
	
	return card

func _format_role_label(title: String) -> String:
	if title.contains("输出"):
		return "⚔️ 输出"
	elif title.contains("防御"):
		return "🛡️ 防御"
	elif title.contains("辅助"):
		return "💚 辅助"
	elif title.contains("控场"):
		return "🔮 控场"
	elif title.contains("斩杀"):
		return "⚡ 斩杀"
	return title

func _get_rarity_color(rarity) -> Color:
	var rarity_str: String = str(rarity).to_lower()
	match rarity_str:
		"rare", "3": return Color(0.3, 0.6, 0.9, 1)
		"epic", "4": return Color(0.7, 0.4, 0.9, 1)
		"legendary", "5": return Color(0.95, 0.7, 0.2, 1)
		_: return Color(0.7, 0.7, 0.75, 1)

# ========== Hover 系统（参考 card-framework）==========

func _on_card_hover_enter(card: PanelContainer) -> void:
	var state: String = card.get_meta("state", "normal")
	if state == "selected" or state == "disabled" or state == "in_team":
		return
	if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
		return
	
	_kill_card_tween(card)
	
	# 记录基准位置（避免多次hover导致位置累加漂移）
	var base_y: float = card.get_meta("hover_base_y", card.position.y)
	card.set_meta("hover_base_y", base_y)
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", SETTINGS.HOVER_SCALE, SETTINGS.HOVER_DURATION)
	tween.parallel().tween_property(card, "position:y", base_y + SETTINGS.HOVER_LIFT_Y, SETTINGS.HOVER_DURATION)
	tween.parallel().tween_property(card, "z_index", 10, 0.0)
	tween.parallel().tween_callback(func():
		card.add_theme_stylebox_override("panel", _create_card_style("hover"))
	)
	card.set_meta("hover_tween", tween)

func _on_card_hover_exit(card: PanelContainer) -> void:
	var state: String = card.get_meta("state", "normal")
	if state == "selected" or state == "in_team":
		return
	
	_kill_card_tween(card)
	
	# 恢复基准位置
	var base_y: float = card.get_meta("hover_base_y", card.position.y)
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, SETTINGS.HOVER_DURATION)
	tween.parallel().tween_property(card, "position:y", base_y, SETTINGS.HOVER_DURATION)
	tween.parallel().tween_property(card, "z_index", 0, 0.0)
	tween.parallel().tween_callback(func():
		if state != "disabled":
			card.add_theme_stylebox_override("panel", _create_card_style("normal"))
	)
	card.set_meta("hover_tween", tween)

func _kill_card_tween(card: PanelContainer) -> void:
	if card.has_meta("hover_tween"):
		var old: Tween = card.get_meta("hover_tween")
		if old != null and old.is_valid():
			old.kill()
		card.remove_meta("hover_tween")

# ========== 点击选择 ==========

func _on_card_gui_input(event: InputEvent, card: PanelContainer, partner: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	var state: String = card.get_meta("state", "normal")
	if state == "disabled" or state == "in_team":
		AudioManager.play_ui("error")
		return
	if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
		AudioManager.play_ui("error")
		return
	
	AudioManager.play_ui("confirm")
	_add_to_team(partner, card)

# ========== 加入队伍（飞入动画）==========

func _add_to_team(partner: Dictionary, source_card: PanelContainer) -> void:
	if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
		return
	
	_selected_team.append(partner)
	
	# 1. 标记池子卡片为"已入队"
	source_card.set_meta("state", "in_team")
	_kill_card_tween(source_card)
	
	var fade_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(source_card, "modulate", Color(0.6, 0.6, 0.62, 0.4), 0.2)
	fade_tween.parallel().tween_property(source_card, "scale", Vector2.ONE, 0.2)
	fade_tween.parallel().tween_property(source_card, "position:y", source_card.position.y - SETTINGS.HOVER_LIFT_Y, 0.2)
	fade_tween.parallel().tween_callback(func():
		source_card.add_theme_stylebox_override("panel", _create_card_style("disabled"))
	)
	
	# 2. 更新队伍槽位（飞入效果）
	var slot_index: int = _selected_team.size() - 1
	_update_team_slot_with_fly_in(slot_index, partner, source_card.global_position)
	
	# 3. 更新UI
	_update_team_title()
	_update_team_stats()
	
	if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
		_start_btn.disabled = false

func _update_team_slot_with_fly_in(index: int, partner: Dictionary, from_global_pos: Vector2) -> void:
	var slot: PanelContainer = _team_slots.get_child(index)
	if slot == null:
		return
	
	# 清除空槽内容
	for child in slot.get_children():
		child.queue_free()
	
	# 设置选中样式
	slot.add_theme_stylebox_override("panel", _create_card_style("selected"))
	
	# 构建槽位内容
	var vbox := _build_slot_content(partner)
	slot.add_child(vbox)
	
	# 飞入动画
	var slot_global := slot.global_position
	vbox.global_position = from_global_pos
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.7, 0.7)
	
	var fly_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly_tween.tween_property(vbox, "global_position", slot_global, 0.25)
	fly_tween.parallel().tween_property(vbox, "modulate:a", 1.0, 0.2)
	fly_tween.parallel().tween_property(vbox, "scale", Vector2.ONE, 0.25)
	
	# 到达后弹跳
	fly_tween.chain().tween_property(vbox, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_BACK)
	fly_tween.tween_property(vbox, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)

func _build_slot_content(partner: Dictionary) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 等级
	var level_label := Label.new()
	level_label.text = "Lv.%d" % partner.get("level", 1)
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_GOLD)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)
	
	# 头像
	var avatar_container := PanelContainer.new()
	avatar_container.custom_minimum_size = Vector2(SETTINGS.SLOT_AVATAR_SIZE, SETTINGS.SLOT_AVATAR_SIZE)
	var avatar_bg := StyleBoxFlat.new()
	avatar_bg.bg_color = Color(0.95, 0.95, 0.97, 1)
	avatar_bg.corner_radius_top_left = SETTINGS.RADIUS_AVATAR
	avatar_bg.corner_radius_top_right = SETTINGS.RADIUS_AVATAR
	avatar_bg.corner_radius_bottom_left = SETTINGS.RADIUS_AVATAR
	avatar_bg.corner_radius_bottom_right = SETTINGS.RADIUS_AVATAR
	avatar_container.add_theme_stylebox_override("panel", avatar_bg)
	avatar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(avatar_container)
	
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(SETTINGS.SLOT_AVATAR_SIZE, SETTINGS.SLOT_AVATAR_SIZE)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_path: String = partner.get("avatar_path", "")
	if avatar_path.is_empty():
		avatar_path = partner.get("icon_path", "")
	if not avatar_path.is_empty():
		var tex: Texture2D = load(avatar_path)
		if tex != null:
			avatar.texture = tex
	avatar_container.add_child(avatar)
	
	# 名字
	var name_label := Label.new()
	name_label.text = partner.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# 职业
	var class_label := Label.new()
	class_label.text = partner.get("title", "伙伴")
	class_label.add_theme_font_size_override("font_size", 10)
	class_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(class_label)
	
	# 点击移除提示
	var remove_hint := Label.new()
	remove_hint.text = "点击移除"
	remove_hint.add_theme_font_size_override("font_size", 9)
	remove_hint.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3, 0.5))
	remove_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(remove_hint)
	
	return vbox

# ========== 移除伙伴 ==========

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if index >= _selected_team.size():
		return
	_remove_from_team(index)

func _remove_from_team(index: int) -> void:
	if index >= _selected_team.size():
		return
	
	AudioManager.play_ui("cancel")
	var removed_partner: Dictionary = _selected_team[index]
	_selected_team.remove_at(index)
	
	# 1. 槽位内容淡出缩小
	var slot: PanelContainer = _team_slots.get_child(index)
	var slot_content := slot.get_child(0) if slot.get_child_count() > 0 else null
	
	if slot_content != null:
		var fade_out := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_out.tween_property(slot_content, "modulate:a", 0.0, 0.15)
		fade_out.parallel().tween_property(slot_content, "scale", Vector2(0.8, 0.8), 0.15)
		await fade_out.finished
		slot_content.queue_free()
	
	# 2. 恢复空槽样式
	_reset_team_slot(index)
	
	# 3. 后续槽位前移
	for i in range(index, SETTINGS.MAX_TEAM_SIZE):
		if i < _selected_team.size():
			_rebuild_team_slot(i, _selected_team[i])
		else:
			_reset_team_slot(i)
	
	# 4. 恢复池子卡片状态
	_restore_pool_card(str(removed_partner.get("partner_id_str", "")))
	
	_update_team_title()
	_update_team_stats()
	_start_btn.disabled = true

func _rebuild_team_slot(index: int, partner: Dictionary) -> void:
	var slot: PanelContainer = _team_slots.get_child(index)
	if slot == null:
		return
	
	for child in slot.get_children():
		child.queue_free()
	
	slot.add_theme_stylebox_override("panel", _create_card_style("selected"))
	
	var vbox := _build_slot_content(partner)
	slot.add_child(vbox)
	
	# 简单淡入
	vbox.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.15)

func _restore_pool_card(partner_id: String) -> void:
	for card in _partner_pool_grid.get_children():
		if card.get_meta("partner_id", "") == partner_id:
			card.set_meta("state", "normal")
			_kill_card_tween(card)
			
			var restore_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			restore_tween.tween_property(card, "modulate", Color.WHITE, 0.2)
			restore_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.2)
			restore_tween.tween_callback(func():
				card.add_theme_stylebox_override("panel", _create_card_style("normal"))
			)
			break

# ========== UI 更新 ==========

func _update_team_title() -> void:
	_team_title.text = "出征队伍 %d/%d" % [_selected_team.size(), SETTINGS.MAX_TEAM_SIZE]

func _update_team_stats() -> void:
	# 清除旧统计
	for child in _team_stats_preview.get_children():
		child.queue_free()
	
	if _selected_team.is_empty():
		var hint := Label.new()
		hint.text = "选择伙伴查看队伍属性"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
		_team_stats_preview.add_child(hint)
		return
	
	# 计算总属性
	var total_stats: Dictionary = {"vit": 0, "str": 0, "agi": 0, "tec": 0, "mnd": 0}
	for partner in _selected_team:
		total_stats["vit"] += partner.get("base_physique", 0)
		total_stats["str"] += partner.get("base_strength", 0)
		total_stats["agi"] += partner.get("base_agility", 0)
		total_stats["tec"] += partner.get("base_technique", 0)
		total_stats["mnd"] += partner.get("base_spirit", 0)
	
	var stat_names: Dictionary = {
		"vit": "体魄", "str": "力量", "agi": "敏捷", "tec": "技巧", "mnd": "精神"
	}
	
	for key in ["vit", "str", "agi", "tec", "mnd"]:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		_team_stats_preview.add_child(hbox)
		
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = SETTINGS.STAT_COLORS.get(key, Color.GRAY)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(dot)
		
		var label := Label.new()
		label.text = "%s: %d" % [stat_names[key], total_stats[key]]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
		hbox.add_child(label)

# ========== 入场动画 ==========

func _play_entrance_animation() -> void:
	# Step 1: 面板容器依次淡入+上滑
	var panels: Array[Control] = [
		_top_bar, _hero_banner, _left_panel, _right_panel, _bottom_bar
	]
	
	for panel in panels:
		if panel == null:
			continue
		panel.modulate.a = 0.0
		panel.position.y += 20
	
	var panel_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(panels.size()):
		var panel: Control = panels[i]
		if panel == null:
			continue
		var delay := i * 0.08
		panel_tween.tween_property(panel, "modulate:a", 1.0, SETTINGS.ENTRANCE_DURATION).set_delay(delay)
		panel_tween.parallel().tween_property(panel, "position:y", panel.position.y - 20, SETTINGS.ENTRANCE_DURATION + 0.05).set_delay(delay)
	
	# Step 2: 池子卡片波浪弹出
	await panel_tween.finished
	var cards := _partner_pool_grid.get_children()
	
	for i in range(cards.size()):
		var card: Control = cards[i]
		card.scale = Vector2(0.85, 0.85)
		card.modulate.a = 0.0
	
	for i in range(cards.size()):
		var card: Control = cards[i]
		var card_tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_interval(i * 0.05)
		card_tween.tween_property(card, "scale", Vector2.ONE, 0.3)
		card_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.25)
	
	# Step 3: 空槽位弹跳入场
	var slots := _team_slots.get_children()
	for i in range(slots.size()):
		var slot_tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slot_tween.tween_interval(0.3 + i * 0.1)
		slot_tween.tween_property(slots[i], "scale", Vector2(1.02, 1.02), 0.2)
		slot_tween.tween_property(slots[i], "scale", Vector2.ONE, 0.15)

# ========== 按钮回调 ==========

func _on_back_pressed() -> void:
	EventBus.back_to_hero_select.emit()

func _on_start_run_pressed() -> void:
	if _selected_team.size() < SETTINGS.MAX_TEAM_SIZE:
		return
	
	AudioManager.play_ui("confirm")
	
	# 弹性点击（Fire and Forget，不阻塞交互）
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_btn, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(_start_btn, "scale", Vector2.ONE, 0.15)
	
	# 保存队伍
	var partner_ids: Array[String] = []
	for partner in _selected_team:
		partner_ids.append(partner.get("partner_id_str", ""))
	GameManager.pending_archive["partners"] = partner_ids
	
	# 创建 layer=10 的遮罩层，确保覆盖所有 UI（UILayer 在 layer 2）
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color.BLACK
	overlay.modulate = Color(1, 1, 1, 0)
	layer.add_child(overlay)
	
	# 黑场渐变（0.25s），不等完成——避免画面卡顿期
	var trans := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	trans.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25).from(Color(1, 1, 1, 0))
	
	# 立即发射信号，由 GameManager 在新场景上淡出
	EventBus.team_confirmed.emit(partner_ids)
