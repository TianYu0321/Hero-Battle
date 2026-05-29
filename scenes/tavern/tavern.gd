## res://scenes/tavern/tavern.gd
## 模块: TavernUI (Party Assemble)
## 职责: 酒馆集结界面，拳皇99风格：左侧图标矩阵 + 右侧大立绘 + 顶部队伍栏
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

@onready var _team_bar: HBoxContainer = $UILayer/TeamBar
@onready var _team_count_label: Label = $UILayer/TeamBar/TeamCountLabel

@onready var _main_section: HBoxContainer = $UILayer/MainSection
@onready var _left_panel: VBoxContainer = $UILayer/MainSection/LeftPanel
@onready var _pool_title: Label = $UILayer/MainSection/LeftPanel/PoolTitle
@onready var _partner_icon_grid: GridContainer = $UILayer/MainSection/LeftPanel/PartnerIconScroll/PartnerIconGrid

@onready var _right_panel: VBoxContainer = $UILayer/MainSection/RightPanel
@onready var _portrait_container: PanelContainer = $UILayer/MainSection/RightPanel/PortraitContainer
@onready var _portrait_texture: TextureRect = $UILayer/MainSection/RightPanel/PortraitContainer/PortraitTexture
@onready var _detail_panel: VBoxContainer = $UILayer/MainSection/RightPanel/DetailPanel
@onready var _detail_name: Label = $UILayer/MainSection/RightPanel/DetailPanel/NameLabel
@onready var _detail_class: Label = $UILayer/MainSection/RightPanel/DetailPanel/ClassRow/ClassLabel
@onready var _detail_desc: Label = $UILayer/MainSection/RightPanel/DetailPanel/DescLabel
@onready var _action_btn: Button = $UILayer/MainSection/RightPanel/DetailPanel/ActionButton

@onready var _bottom_bar: HBoxContainer = $UILayer/BottomBar
@onready var _team_stats_preview: HBoxContainer = $UILayer/BottomBar/TeamStatsPreview
@onready var _start_btn: Button = $UILayer/BottomBar/StartRunButton

@onready var _transition_overlay: ColorRect = $TransitionOverlay

# --- 数据状态 ---
var _partner_ids: Array[String] = []
var _selected_team: Array[Dictionary] = []
var _selected_partner_id: String = ""       # 当前右侧预览选中的伙伴ID
var _icon_cells: Dictionary = {}             # partner_id → Control 映射

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
	_action_btn.pressed.connect(_on_action_button_pressed)
	
	# 设置UI样式
	_setup_top_bar()
	_setup_team_bar()
	_setup_start_button()
	_setup_pool_title()
	_setup_detail_panel()
	_setup_portrait_container()
	
	# 读取可用伙伴
	_partner_ids = _get_available_partner_ids()
	
	# 填充图标矩阵
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

func _create_cell_style(state: String) -> StyleBoxFlat:
	var s: StyleBoxFlat
	match state:
		"normal":
			s = _create_stylebox(
				SETTINGS.COLOR_BG_PANEL,
				Color(0.85, 0.85, 0.85, 0), 0, 0,
				SETTINGS.RADIUS_AVATAR,
				4, Vector2(0, 1), Color(0, 0, 0, 0.06)
			)
		"hover":
			s = _create_stylebox(
				SETTINGS.COLOR_BG_PANEL,
				SETTINGS.COLOR_BORDER_HOVER, 2, 2,
				SETTINGS.RADIUS_AVATAR,
				6, Vector2(0, 2), Color(0.4, 0.6, 1, 0.1)
			)
		"selected":
			s = _create_stylebox(
				SETTINGS.COLOR_BG_SELECTED,
				SETTINGS.COLOR_BORDER_SELECTED, 3, 3,
				SETTINGS.RADIUS_AVATAR,
				6, Vector2(0, 2), Color(0.25, 0.55, 0.95, 0.15)
			)
		"in_team":
			s = _create_stylebox(
				Color(0.94, 0.94, 0.96, 1),
				Color(0.8, 0.8, 0.82, 0.5), 2, 2,
				SETTINGS.RADIUS_AVATAR,
				0, Vector2.ZERO, Color.TRANSPARENT
			)
		_:
			return _create_cell_style("normal")
	# 关键：content margin 设为 0，让头像贴满 cell，不留白边
	s.content_margin_left = 0
	s.content_margin_top = 0
	s.content_margin_right = 0
	s.content_margin_bottom = 0
	return s

func _create_slot_style(state: String) -> StyleBoxFlat:
	match state:
		"empty":
			return _create_stylebox(
				Color(0.94, 0.94, 0.96, 1),
				Color(0.8, 0.8, 0.82, 1), 2, 2,
				SETTINGS.RADIUS_AVATAR,
				4, Vector2(0, 1), Color(0, 0, 0, 0.04)
			)
		"filled":
			return _create_stylebox(
				SETTINGS.COLOR_BG_SELECTED,
				SETTINGS.COLOR_BORDER_SELECTED, 3, 3,
				SETTINGS.RADIUS_AVATAR,
				6, Vector2(0, 2), Color(0.25, 0.55, 0.95, 0.15)
			)
		_:
			return _create_slot_style("empty")

# ========== 顶部栏 ==========

func _setup_top_bar() -> void:
	_back_btn.custom_minimum_size = Vector2(120, 48)
	_back_btn.add_theme_font_size_override("font_size", 16)
	_back_btn.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	
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

# ========== 队伍栏 ==========

func _setup_team_bar() -> void:
	for i in range(SETTINGS.MAX_TEAM_SIZE):
		var slot: PanelContainer = _team_bar.get_child(i)
		if slot == null:
			continue
		slot.gui_input.connect(_on_team_slot_gui_input.bind(i))
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		_reset_team_slot(i)
	
	_team_count_label.text = "0/%d" % SETTINGS.MAX_TEAM_SIZE
	_team_count_label.add_theme_font_size_override("font_size", 24)
	_team_count_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)

func _reset_team_slot(index: int) -> void:
	var slot: PanelContainer = _team_bar.get_child(index)
	if slot == null:
		return
	
	for child in slot.get_children():
		child.queue_free()
	
	slot.add_theme_stylebox_override("panel", _create_slot_style("empty"))
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)
	
	var plus_label := Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 36)
	plus_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(plus_label)

func _update_team_bar() -> void:
	for i in range(SETTINGS.MAX_TEAM_SIZE):
		var slot: PanelContainer = _team_bar.get_child(i)
		if slot == null:
			continue
		
		for child in slot.get_children():
			child.queue_free()
		
		if i < _selected_team.size():
			var partner: Dictionary = _selected_team[i]
			slot.add_theme_stylebox_override("panel", _create_slot_style("filled"))
			var vbox := _build_team_slot_content(partner)
			slot.add_child(vbox)
			# 淡入
			vbox.modulate.a = 0.0
			var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(vbox, "modulate:a", 1.0, 0.15)
		else:
			_reset_team_slot(i)
	
	_team_count_label.text = "%d/%d" % [_selected_team.size(), SETTINGS.MAX_TEAM_SIZE]

func _build_team_slot_content(partner: Dictionary) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	
	# 头像
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.custom_minimum_size = Vector2(56, 56)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = _get_icon_path_for_partner(partner)
	if not icon_path.is_empty():
		var tex: Texture2D = load(icon_path)
		if tex != null:
			avatar.texture = tex
	vbox.add_child(avatar)
	
	# 名字
	var name_label := Label.new()
	name_label.text = partner.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	return vbox

# ========== 图标矩阵 ==========

func _setup_pool_title() -> void:
	_pool_title.add_theme_font_size_override("font_size", 18)
	_pool_title.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)

func _populate_partner_pool() -> void:
	for child in _partner_icon_grid.get_children():
		child.queue_free()
	_icon_cells.clear()
	
	_partner_icon_grid.columns = SETTINGS.GRID_COLUMNS
	_partner_icon_grid.add_theme_constant_override("h_separation", SETTINGS.GRID_H_SEPARATION)
	_partner_icon_grid.add_theme_constant_override("v_separation", SETTINGS.GRID_V_SEPARATION)
	
	for partner_id in _partner_ids:
		var config: Dictionary = ConfigManager.get_partner_config(partner_id)
		if config.is_empty():
			continue
		config["partner_id_str"] = partner_id
		var cell := _create_icon_cell(partner_id, config)
		_partner_icon_grid.add_child(cell)
		_icon_cells[partner_id] = cell

func _create_icon_cell(partner_id: String, partner: Dictionary) -> PanelContainer:
	var display_state: ConfigManager.PartnerDisplayState = ConfigManager.get_partner_display_state(partner_id)
	var is_locked: bool = (display_state == ConfigManager.PartnerDisplayState.LOCKED_VISIBLE)
	
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(SETTINGS.ICON_CELL_WIDTH, SETTINGS.ICON_CELL_HEIGHT + SETTINGS.ICON_NAME_HEIGHT)
	cell.set_meta("partner_id", partner_id)
	cell.set_meta("partner_data", partner)
	cell.set_meta("state", "normal")
	cell.set_meta("display_state", display_state)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override("panel", _create_cell_style("normal"))
	cell.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	
	# 用 Control 作为内容根，绕过 PanelContainer 的强制布局，anchors 才能生效
	var content := Control.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(content)
	
	# 头像占据 cell 上半部分（图片区域），保持比例不裁切
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	avatar.offset_bottom = SETTINGS.ICON_CELL_HEIGHT
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = _get_icon_path_for_partner(partner)
	if not icon_path.is_empty():
		var tex: Texture2D = load(icon_path)
		if tex != null:
			avatar.texture = tex
	# 未拥有：头像变灰
	if is_locked:
		avatar.self_modulate = Color(0.5, 0.5, 0.5, 1)
	content.add_child(avatar)
	
	# 名字底条固定在底部
	var name_bar := PanelContainer.new()
	name_bar.name = "NameBar"
	name_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_bar.offset_top = -SETTINGS.ICON_NAME_HEIGHT
	name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_bg := StyleBoxFlat.new()
	name_bg.bg_color = Color(1, 1, 1, 0.9)
	name_bg.corner_radius_bottom_left = SETTINGS.RADIUS_AVATAR
	name_bg.corner_radius_bottom_right = SETTINGS.RADIUS_AVATAR
	name_bg.content_margin_left = 0
	name_bg.content_margin_top = 2
	name_bg.content_margin_right = 0
	name_bg.content_margin_bottom = 2
	name_bar.add_theme_stylebox_override("panel", name_bg)
	content.add_child(name_bar)
	
	var name_label := Label.new()
	name_label.text = partner.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 11)
	var name_color: Color = SETTINGS.COLOR_TEXT_DISABLED if is_locked else SETTINGS.COLOR_TEXT_MAIN
	name_label.add_theme_color_override("font_color", name_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_bar.add_child(name_label)
	
	# 锁定标记（未拥有时显示在名字条上）
	if is_locked:
		var lock_label := Label.new()
		lock_label.name = "LockMark"
		lock_label.text = "🔒"
		lock_label.add_theme_font_size_override("font_size", 14)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.set_anchors_preset(Control.PRESET_CENTER)
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(lock_label)
	
	# 勾选标记（默认隐藏，固定在右上角）
	var check_mark := Label.new()
	check_mark.name = "CheckMark"
	check_mark.text = "✓"
	check_mark.add_theme_font_size_override("font_size", 20)
	check_mark.add_theme_color_override("font_color", Color(0.25, 0.55, 0.95, 1))
	check_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_mark.visible = false
	check_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	check_mark.offset_right = -4
	check_mark.offset_bottom = 24
	content.add_child(check_mark)
	
	# 交互（已拥有的才响应点击）
	if not is_locked:
		cell.gui_input.connect(_on_icon_cell_gui_input.bind(cell, partner))
		cell.mouse_entered.connect(_on_icon_cell_hover_enter.bind(cell))
		cell.mouse_exited.connect(_on_icon_cell_hover_exit.bind(cell))
	else:
		cell.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		cell.focus_mode = Control.FOCUS_NONE
	
	return cell

func _get_icon_path_for_partner(partner: Dictionary) -> String:
	# 统一使用 partner/{key}/icon/icon.png（去掉 partner_ 前缀），没有就不显示
	var partner_key: String = partner.get("partner_id_str", "")
	if partner_key.is_empty():
		partner_key = str(partner.get("id", ""))
	# 去掉 partner_ 前缀，比如 partner_pharmacist → pharmacist
	if partner_key.begins_with("partner_"):
		partner_key = partner_key.substr(8)
	var icon_path: String = "res://assets/characters/partner/%s/icon/icon.png" % partner_key
	if FileAccess.file_exists(icon_path):
		return icon_path
	return ""

func _get_portrait_path_for_partner(partner: Dictionary) -> String:
	# 优先级：avatar_path (portrait.png) → card图 → action.png → ready.png
	var avatar_path: String = partner.get("avatar_path", "")
	if not avatar_path.is_empty() and FileAccess.file_exists(avatar_path):
		return avatar_path
	var partner_id: String = str(partner.get("id", ""))
	var card_path: String = "res://assets/characters/card/partners/%s_lv1.png" % partner_id
	if FileAccess.file_exists(card_path):
		return card_path
	var action_path: String = "res://assets/characters/partner/%s/action.png" % partner_id
	if FileAccess.file_exists(action_path):
		return action_path
	var ready_path: String = "res://assets/characters/partner/%s/ready.png" % partner_id
	if FileAccess.file_exists(ready_path):
		return ready_path
	return ""

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

# ========== 图标 Hover ==========

func _on_icon_cell_hover_enter(cell: PanelContainer) -> void:
	var state: String = cell.get_meta("state", "normal")
	if state == "selected" or state == "in_team":
		return
	cell.add_theme_stylebox_override("panel", _create_cell_style("hover"))

func _on_icon_cell_hover_exit(cell: PanelContainer) -> void:
	var state: String = cell.get_meta("state", "normal")
	if state == "selected":
		cell.add_theme_stylebox_override("panel", _create_cell_style("selected"))
	elif state == "in_team":
		cell.add_theme_stylebox_override("panel", _create_cell_style("in_team"))
	else:
		cell.add_theme_stylebox_override("panel", _create_cell_style("normal"))
	cell.clip_children = CanvasItem.CLIP_CHILDREN_ONLY

# ========== 图标点击（预览） ==========

func _on_icon_cell_gui_input(event: InputEvent, cell: PanelContainer, partner: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	var partner_id: String = cell.get_meta("partner_id", "")
	
	# 双击：直接添加/移除
	if event.double_click:
		if _is_partner_in_team(partner_id):
			AudioManager.play_ui("cancel")
			_remove_from_team_by_id(partner_id)
		else:
			if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
				AudioManager.play_ui("error")
				return
			AudioManager.play_ui("confirm")
			_add_to_team_by_id(partner_id)
		_select_partner_cell(partner_id)
		return
	
	# 单击：选中预览
	_select_partner_cell(partner_id)


func _select_partner_cell(partner_id: String) -> void:
	if partner_id == _selected_partner_id:
		return
	
	AudioManager.play_ui("confirm")
	
	# 清除之前的高亮
	if not _selected_partner_id.is_empty() and _icon_cells.has(_selected_partner_id):
		var prev: PanelContainer = _icon_cells[_selected_partner_id]
		var prev_state: String = prev.get_meta("state", "normal")
		if prev_state == "in_team":
			prev.add_theme_stylebox_override("panel", _create_cell_style("in_team"))
		else:
			prev.set_meta("state", "normal")
			prev.add_theme_stylebox_override("panel", _create_cell_style("normal"))
	
	# 高亮当前
	_selected_partner_id = partner_id
	if _icon_cells.has(partner_id):
		var cell: PanelContainer = _icon_cells[partner_id]
		var state: String = cell.get_meta("state", "normal")
		if state != "in_team":
			cell.set_meta("state", "selected")
			cell.add_theme_stylebox_override("panel", _create_cell_style("selected"))
	
	_show_partner_detail(partner_id)

# ========== 详情面板 ==========

func _setup_detail_panel() -> void:
	_detail_name.add_theme_font_size_override("font_size", 28)
	_detail_name.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_MAIN)
	
	_detail_class.add_theme_font_size_override("font_size", 16)
	_detail_class.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
	
	_detail_desc.add_theme_font_size_override("font_size", 13)
	_detail_desc.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
	
	_action_btn.custom_minimum_size = Vector2(180, 48)
	_action_btn.add_theme_font_size_override("font_size", 16)
	_action_btn.disabled = true
	
	var btn_normal := _create_stylebox(
		Color(0.25, 0.55, 0.95, 1),
		Color(0.2, 0.45, 0.85, 1), 2, 4,
		SETTINGS.RADIUS_BUTTON,
		6, Vector2(0, 3), Color(0.25, 0.55, 0.95, 0.2)
	)
	var btn_hover := _create_stylebox(
		Color(0.35, 0.65, 1.0, 1),
		Color(0.3, 0.55, 0.95, 1), 2, 4,
		SETTINGS.RADIUS_BUTTON,
		10, Vector2(0, 4), Color(0.35, 0.65, 1.0, 0.3)
	)
	var btn_disabled := _create_stylebox(
		Color(0.88, 0.88, 0.9, 1),
		Color(0.75, 0.75, 0.77, 1), 2, 3,
		SETTINGS.RADIUS_BUTTON,
		0, Vector2.ZERO, Color.TRANSPARENT
	)
	_action_btn.add_theme_stylebox_override("normal", btn_normal)
	_action_btn.add_theme_stylebox_override("hover", btn_hover)
	_action_btn.add_theme_stylebox_override("pressed", btn_hover)
	_action_btn.add_theme_stylebox_override("disabled", btn_disabled)
	_action_btn.add_theme_color_override("font_color", Color.WHITE)
	_action_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.52, 1))

func _setup_portrait_container() -> void:
	_portrait_container.add_theme_stylebox_override("panel", _create_stylebox(
		Color(0.95, 0.95, 0.97, 1),
		SETTINGS.COLOR_BORDER, 2, 2,
		SETTINGS.RADIUS_CARD,
		8, Vector2(0, 3), Color(0, 0, 0, 0.08)
	))

func _show_partner_detail(partner_id: String) -> void:
	var config: Dictionary = ConfigManager.get_partner_config(partner_id)
	if config.is_empty():
		return
	
	# 加载立绘
	var portrait_path: String = _get_portrait_path_for_partner(config)
	_portrait_texture.modulate.a = 0.0
	if not portrait_path.is_empty():
		var tex: Texture2D = load(portrait_path)
		if tex != null:
			_portrait_texture.texture = tex
	else:
		_portrait_texture.texture = null
	
	# 立绘淡入
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_portrait_texture, "modulate:a", 1.0, SETTINGS.FADE_DURATION)
	
	# 更新文字信息
	_detail_name.text = config.get("name", "???")
	_detail_class.text = _format_role_label(config.get("title", "伙伴"))
	_detail_desc.text = config.get("desc", "")
	if _detail_desc.text.is_empty():
		_detail_desc.text = "暂无描述"
	
	# 更新按钮状态
	_update_action_button_state(partner_id)

func _update_action_button_state(partner_id: String) -> void:
	var is_in_team := _is_partner_in_team(partner_id)
	if is_in_team:
		_action_btn.text = "取消选择"
		_action_btn.disabled = false
	else:
		_action_btn.text = "加入队伍"
		if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
			_action_btn.disabled = true
			_action_btn.tooltip_text = "队伍已满，请先取消其他伙伴"
		else:
			_action_btn.disabled = false
			_action_btn.tooltip_text = ""

func _is_partner_in_team(partner_id: String) -> bool:
	for partner in _selected_team:
		if str(partner.get("partner_id_str", "")) == partner_id:
			return true
	return false

func _get_team_index(partner_id: String) -> int:
	for i in range(_selected_team.size()):
		if str(_selected_team[i].get("partner_id_str", "")) == partner_id:
			return i
	return -1

# ========== 加入/取消队伍 ==========

func _on_action_button_pressed() -> void:
	if _selected_partner_id.is_empty():
		return
	
	if _is_partner_in_team(_selected_partner_id):
		AudioManager.play_ui("cancel")
		_remove_from_team_by_id(_selected_partner_id)
	else:
		if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
			AudioManager.play_ui("error")
			return
		AudioManager.play_ui("confirm")
		_add_to_team_by_id(_selected_partner_id)

func _add_to_team_by_id(partner_id: String) -> void:
	if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
		return
	
	var config: Dictionary = ConfigManager.get_partner_config(partner_id)
	if config.is_empty():
		return
	config["partner_id_str"] = partner_id
	
	_selected_team.append(config)
	
	# 更新图标状态
	if _icon_cells.has(partner_id):
		var cell: PanelContainer = _icon_cells[partner_id]
		cell.set_meta("state", "in_team")
		cell.add_theme_stylebox_override("panel", _create_cell_style("in_team"))
		var check: Label = cell.get_node("Content/CheckMark") if cell.has_node("Content/CheckMark") else null
		if check != null:
			check.visible = true
	
	# 更新UI
	_update_team_bar()
	_update_action_button_state(partner_id)
	_update_team_stats()
	
	if _selected_team.size() >= SETTINGS.MAX_TEAM_SIZE:
		_start_btn.disabled = false

func _remove_from_team_by_id(partner_id: String) -> void:
	var index := _get_team_index(partner_id)
	if index < 0:
		return
	_remove_from_team(index)

func _remove_from_team(index: int) -> void:
	if index >= _selected_team.size():
		return
	
	var removed_partner: Dictionary = _selected_team[index]
	var removed_id: String = str(removed_partner.get("partner_id_str", ""))
	_selected_team.remove_at(index)
	
	# 恢复图标状态
	if _icon_cells.has(removed_id):
		var cell: PanelContainer = _icon_cells[removed_id]
		cell.set_meta("state", "normal")
		cell.add_theme_stylebox_override("panel", _create_cell_style("normal"))
		var check: Label = cell.get_node("Content/CheckMark") if cell.has_node("Content/CheckMark") else null
		if check != null:
			check.visible = false
	
	# 更新UI
	_update_team_bar()
	if not _selected_partner_id.is_empty():
		_update_action_button_state(_selected_partner_id)
	_update_team_stats()
	_start_btn.disabled = true

func _on_team_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if index >= _selected_team.size():
		return
	AudioManager.play_ui("cancel")
	_remove_from_team(index)

# ========== 伙伴池加载 ==========

func _get_available_partner_ids() -> Array[String]:
	## 使用 ConfigManager 的三态显示系统（OWNED / LOCKED_VISIBLE / HIDDEN）
	return ConfigManager.get_displayable_partner_ids()

# ========== UI 更新 ==========

func _update_team_stats() -> void:
	for child in _team_stats_preview.get_children():
		child.queue_free()
	
	if _selected_team.is_empty():
		var hint := Label.new()
		hint.text = "选择伙伴查看队伍属性"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", SETTINGS.COLOR_TEXT_SECOND)
		_team_stats_preview.add_child(hint)
		return
	
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

# ========== 开始按钮 ==========

func _setup_start_button() -> void:
	_start_btn.custom_minimum_size = Vector2(220, 56)
	_start_btn.add_theme_font_size_override("font_size", 18)
	_start_btn.disabled = true
	
	var normal := _create_stylebox(
		Color(0.25, 0.55, 0.95, 1),
		Color(0.2, 0.45, 0.85, 1), 2, 4,
		SETTINGS.RADIUS_BUTTON,
		6, Vector2(0, 3), Color(0.25, 0.55, 0.95, 0.2)
	)
	var hover := _create_stylebox(
		Color(0.35, 0.65, 1.0, 1),
		Color(0.3, 0.55, 0.95, 1), 2, 4,
		SETTINGS.RADIUS_BUTTON,
		10, Vector2(0, 4), Color(0.35, 0.65, 1.0, 0.3)
	)
	var disabled := _create_stylebox(
		Color(0.88, 0.88, 0.9, 1),
		Color(0.75, 0.75, 0.77, 1), 2, 3,
		SETTINGS.RADIUS_BUTTON,
		0, Vector2.ZERO, Color.TRANSPARENT
	)
	_start_btn.add_theme_stylebox_override("normal", normal)
	_start_btn.add_theme_stylebox_override("hover", hover)
	_start_btn.add_theme_stylebox_override("disabled", disabled)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.52, 1))

# ========== 入场动画 ==========

func _play_entrance_animation() -> void:
	var panels: Array[Control] = [
		_top_bar, _team_bar, _left_panel, _right_panel, _bottom_bar
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
	
	# 右侧详情面板淡入
	var detail_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	detail_tween.tween_interval(0.3)
	_detail_panel.modulate.a = 0.0
	detail_tween.tween_property(_detail_panel, "modulate:a", 1.0, 0.3)
	
	# 默认选中第一个【已拥有】的伙伴（跳过未拥有的）
	for pid in _partner_ids:
		if not _icon_cells.has(pid):
			continue
		var state: ConfigManager.PartnerDisplayState = ConfigManager.get_partner_display_state(pid)
		if state == ConfigManager.PartnerDisplayState.OWNED:
			var first_cell: PanelContainer = _icon_cells[pid]
			first_cell.set_meta("state", "selected")
			first_cell.add_theme_stylebox_override("panel", _create_cell_style("selected"))
			_selected_partner_id = pid
			_show_partner_detail(_selected_partner_id)
			break

# ========== 按钮回调 ==========

func _on_back_pressed() -> void:
	EventBus.back_to_hero_select.emit()

func _on_start_run_pressed() -> void:
	if _selected_team.size() < SETTINGS.MAX_TEAM_SIZE:
		return
	
	AudioManager.play_ui("confirm")
	
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_btn, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(_start_btn, "scale", Vector2.ONE, 0.15)
	
	var partner_ids: Array[String] = []
	for partner in _selected_team:
		partner_ids.append(partner.get("partner_id_str", ""))
	GameManager.pending_archive["partners"] = partner_ids
	
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color.BLACK
	overlay.modulate = Color(1, 1, 1, 0)
	layer.add_child(overlay)
	
	var trans := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	trans.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25).from(Color(1, 1, 1, 0))
	
	EventBus.team_confirmed.emit(partner_ids)
