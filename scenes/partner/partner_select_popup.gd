class_name PartnerSelectPopup
extends CanvasLayer

## 伙伴选择弹窗：竖版卡片风格，用于招募伙伴时的选择界面

signal partner_selected(partner_id: String, partner_data: Dictionary)
signal popup_cancelled()

const CARD_SIZE := Vector2(240, 320)
const AVATAR_SIZE := Vector2(160, 160)
const BORDER_COLOR := RunMainSettings.COLOR_WOOD_MEDIUM
const PARTNER_CARD_SCENE: PackedScene = preload("res://scenes/partner/partner_card.tscn")
const BORDER_HOVER := RunMainSettings.COLOR_GOLD
const BG_SELECTED := RunMainSettings.COLOR_PARCHMENT_DARK

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var main_panel: PanelContainer = $MainPanel
@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var cards_container: HBoxContainer = $MainPanel/VBoxContainer/PartnerCardsContainer
@onready var info_panel: PanelContainer = $MainPanel/VBoxContainer/InfoPanel
@onready var button_bar: HBoxContainer = $MainPanel/VBoxContainer/ButtonBar
@onready var confirm_btn: Button = $MainPanel/VBoxContainer/ButtonBar/ConfirmBtn
@onready var cancel_btn: Button = $MainPanel/VBoxContainer/ButtonBar/CancelBtn

var _selected_card: PanelContainer = null
var _selected_partner_data: Dictionary = {}

@onready var _font_cn: Font = load("res://assets/fonts/cute/ZCOOLKuaiLe-Regular.ttf") as Font


func _ready() -> void:
	visible = false
	main_panel.pivot_offset = main_panel.size / 2
	_setup_main_panel()
	_setup_info_panel()
	_setup_buttons()
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)


func _setup_main_panel() -> void:
	var style := RunMainSettings.create_parchment_flat_style(16)
	style.shadow_color = RunMainSettings.COLOR_SHADOW
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 10)
	main_panel.add_theme_stylebox_override("panel", style)
	
	## 标题
	title_label.add_theme_font_override("font", _font_cn)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)


func _setup_info_panel() -> void:
	info_panel.visible = false
	var style := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_PARCHMENT_DARK,
		RunMainSettings.COLOR_WOOD_MEDIUM, 1, 8
	)
	info_panel.add_theme_stylebox_override("panel", style)


func _setup_buttons() -> void:
	## 确认按钮（木牌样式）
	confirm_btn.custom_minimum_size = Vector2(180, 48)
	confirm_btn.text = "确认招募"
	confirm_btn.disabled = true
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.add_theme_font_override("font", _font_cn)

	var confirm_normal := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_PANEL,
		RunMainSettings.COLOR_WOOD_MEDIUM, 2, 8
	)
	var confirm_hover := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_LIGHT,
		RunMainSettings.COLOR_GOLD, 2, 8
	)
	var confirm_disabled := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_PARCHMENT_DARK,
		RunMainSettings.COLOR_WOOD_MEDIUM, 1, 8
	)
	confirm_btn.add_theme_stylebox_override("normal", confirm_normal)
	confirm_btn.add_theme_stylebox_override("hover", confirm_hover)
	confirm_btn.add_theme_stylebox_override("disabled", confirm_disabled)
	confirm_btn.add_theme_stylebox_override("pressed", confirm_normal)
	confirm_btn.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	confirm_btn.add_theme_color_override("font_hover_color", RunMainSettings.COLOR_INK)
	confirm_btn.add_theme_color_override("font_disabled_color", RunMainSettings.COLOR_WOOD_MEDIUM)

	## 取消按钮
	cancel_btn.custom_minimum_size = Vector2(120, 48)
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.add_theme_font_override("font", _font_cn)

	var cancel_normal := RunMainSettings.create_parchment_flat_style(8)
	cancel_normal.border_width_left = 2
	cancel_normal.border_width_top = 2
	cancel_normal.border_width_right = 2
	cancel_normal.border_width_bottom = 2
	cancel_normal.border_color = RunMainSettings.COLOR_WOOD_MEDIUM
	cancel_btn.add_theme_stylebox_override("normal", cancel_normal)
	cancel_btn.add_theme_color_override("font_color", RunMainSettings.COLOR_WOOD_MEDIUM)

	var cancel_hover := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_PARCHMENT_DARK,
		RunMainSettings.COLOR_GOLD, 2, 8
	)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)
	cancel_btn.add_theme_color_override("font_hover_color", RunMainSettings.COLOR_INK)


func show_popup(partner_options: Array[Dictionary]) -> void:
	_selected_card = null
	_selected_partner_data = {}
	visible = true

	## 清空旧卡片
	for child in cards_container.get_children():
		child.queue_free()

	## 构建卡片
	_build_partner_cards(partner_options)

	## 重置详情面板和按钮
	info_panel.visible = false
	confirm_btn.disabled = true

	## 遮罩淡入
	dim_overlay.color = Color(0, 0, 0, 0)
	var dim_tween := create_tween()
	dim_tween.tween_property(dim_overlay, "color:a", 0.5, 0.3)

	## 主面板缩放入场
	main_panel.scale = Vector2(0.9, 0.9)
	main_panel.modulate.a = 0.0

	var panel_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(main_panel, "scale", Vector2.ONE, 0.35)
	panel_tween.parallel().tween_property(main_panel, "modulate:a", 1.0, 0.3)

	## 卡片依次入场（stagger 并行）
	await panel_tween.finished
	var cards := cards_container.get_children()
	var card_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(cards.size()):
		var card: Control = cards[i]
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0

		var delay := i * 0.06
		if i == 0:
			card_tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(delay)
		else:
			card_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(delay)
		card_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)


func hide_popup() -> void:
	## 主面板淡出缩小
	var panel_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(main_panel, "scale", Vector2(0.9, 0.9), 0.2)
	panel_tween.parallel().tween_property(main_panel, "modulate:a", 0.0, 0.2)

	## 遮罩淡出
	var dim_tween := create_tween()
	dim_tween.tween_property(dim_overlay, "color:a", 0.0, 0.25)

	await panel_tween.finished
	visible = false
	_selected_card = null
	_selected_partner_data = {}
	for child in cards_container.get_children():
		child.queue_free()


func _build_partner_cards(partner_options: Array[Dictionary]) -> void:
	for i in range(partner_options.size()):
		var card := _create_partner_card(partner_options[i], i)
		cards_container.add_child(card)


func _create_partner_card(partner_data: Dictionary, index: int) -> PanelContainer:
	var card: PanelContainer = PARTNER_CARD_SCENE.instantiate()
	card.custom_minimum_size = CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.set_meta("partner_id", str(partner_data.get("partner_id", "")))
	card.set_meta("partner_data", partner_data)
	card.set_meta("card_index", index)
	card.pivot_offset = CARD_SIZE / 2

	## 卡片基础样式：羊皮纸底 + 木色边框
	var style := RunMainSettings.create_parchment_flat_style(12)
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)

	## 等级标签
	var level_badge: Label = card.get_node("VBoxContainer/LevelBadge")
	level_badge.text = "Lv.%d" % partner_data.get("level", 1)

	## 头像
	var avatar: TextureRect = card.get_node("VBoxContainer/AvatarContainer/Avatar")
	var portrait_path: String = partner_data.get("portrait_path", "")
	if portrait_path.is_empty():
		portrait_path = ResourcePaths.get_partner_portrait(str(partner_data.get("partner_id", 0)))
	var tex: Texture2D = _resolve_texture_from_path(portrait_path)
	if tex != null:
		avatar.texture = tex

	## 伙伴名字
	var name_label: Label = card.get_node("VBoxContainer/NameLabel")
	name_label.text = partner_data.get("name", "???")

	## 定位/职业
	var class_label: Label = card.get_node("VBoxContainer/ClassLabel")
	class_label.text = partner_data.get("role", "伙伴")

	## 交互信号
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_partner_card(card, partner_data)
	)
	card.mouse_entered.connect(func(): _card_hover_tween(card, true))
	card.mouse_exited.connect(func(): _card_hover_tween(card, false))

	return card


func _card_hover_tween(card: PanelContainer, is_enter: bool) -> void:
	if card == _selected_card:
		return
	if not card.has_meta("base_y"):
		card.set_meta("base_y", card.position.y)
	if card.has_meta("hover_tween"):
		var old: Tween = card.get_meta("hover_tween")
		if old != null and old.is_valid():
			old.kill()

	var base_y: float = card.get_meta("base_y")
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_enter:
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.15)
		tween.parallel().tween_property(card, "position:y", base_y - 8, 0.15)

		var hover_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		hover_style.border_color = BORDER_HOVER
		hover_style.shadow_size = 12
		hover_style.shadow_color = Color(BORDER_HOVER.r, BORDER_HOVER.g, BORDER_HOVER.b, 0.25)
		card.add_theme_stylebox_override("panel", hover_style)
	else:
		tween.tween_property(card, "scale", Vector2.ONE, 0.2)
		tween.parallel().tween_property(card, "position:y", base_y, 0.2)

		var base_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		base_style.border_color = BORDER_COLOR
		base_style.shadow_size = 6
		base_style.shadow_color = RunMainSettings.COLOR_SHADOW
		card.add_theme_stylebox_override("panel", base_style)

	card.set_meta("hover_tween", tween)


func _select_partner_card(card: PanelContainer, partner_data: Dictionary) -> void:
	_selected_partner_data = partner_data

	## 取消旧选中
	if _selected_card != null and is_instance_valid(_selected_card):
		var old_style: StyleBoxFlat = _selected_card.get_theme_stylebox("panel").duplicate()
		old_style.bg_color = RunMainSettings.COLOR_PARCHMENT
		old_style.border_color = BORDER_COLOR
		old_style.border_width_left = 2
		old_style.border_width_top = 2
		old_style.border_width_right = 2
		old_style.border_width_bottom = 3
		old_style.shadow_size = 6
		_selected_card.add_theme_stylebox_override("panel", old_style)
		_selected_card.modulate = Color.WHITE  ## modulate 重置即可

		if _selected_card.has_meta("base_y"):
			_selected_card.position.y = _selected_card.get_meta("base_y")

		var unselect_tween := create_tween()
		unselect_tween.tween_property(_selected_card, "scale", Vector2.ONE, 0.15)

	_selected_card = card

	## 新选中态：羊皮纸底 + 金色边框 + 阴影扩散
	var new_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	new_style.bg_color = BG_SELECTED
	new_style.border_color = BORDER_HOVER
	new_style.border_width_left = 3
	new_style.border_width_top = 3
	new_style.border_width_right = 3
	new_style.border_width_bottom = 4
	new_style.shadow_size = 16
	new_style.shadow_color = Color(BORDER_HOVER.r, BORDER_HOVER.g, BORDER_HOVER.b, 0.25)
	card.add_theme_stylebox_override("panel", new_style)

	## 选中弹跳动画
	var select_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	select_tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.12)
	select_tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.18)

	## 更新详情面板
	_update_info_panel(partner_data)

	## 启用确认按钮
	confirm_btn.disabled = false


func _update_info_panel(partner_data: Dictionary) -> void:
	info_panel.visible = true

	## 清空旧内容
	for child in info_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(vbox)

	## 名字
	var name_label := Label.new()
	name_label.text = partner_data.get("name", "???")
	name_label.add_theme_font_override("font", _font_cn)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	## 等级 + 职业
	var sub_label := Label.new()
	sub_label.text = "Lv.%d | %s" % [partner_data.get("level", 1), partner_data.get("role", "伙伴")]
	sub_label.add_theme_font_override("font", _font_cn)
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", RunMainSettings.COLOR_WOOD_MEDIUM)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)

	## 技能描述（如果有）
	var skill_desc: String = partner_data.get("skill_desc", "")
	if skill_desc.is_empty():
		## 尝试从 ConfigManager 获取
		var config_id: String = str(partner_data.get("partner_id", ""))
		var cfg: Dictionary = ConfigManager.get_partner_config(config_id)
		skill_desc = cfg.get("skill_desc", "")

	if not skill_desc.is_empty():
		var desc_label := RichTextLabel.new()
		desc_label.text = skill_desc
		desc_label.fit_content = true
		desc_label.custom_minimum_size = Vector2(0, 60)
		desc_label.add_theme_color_override("default_color", RunMainSettings.COLOR_WOOD_MEDIUM)
		desc_label.add_theme_font_override("normal_font", _font_cn)
		desc_label.add_theme_font_size_override("normal_font_size", 14)
		vbox.add_child(desc_label)


func _on_confirm_pressed() -> void:
	if _selected_partner_data.is_empty():
		return

	AudioManager.play_ui("confirm")

	## 确认按钮弹跳
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(confirm_btn, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(confirm_btn, "scale", Vector2.ONE, 0.15)
	await tween.finished

	partner_selected.emit(
		str(_selected_partner_data.get("partner_id", "")),
		_selected_partner_data
	)
	hide_popup()


func _on_cancel_pressed() -> void:
	AudioManager.play_ui("cancel")
	popup_cancelled.emit()
	hide_popup()


func _resolve_texture_from_path(path: String) -> Texture2D:
	return ResourcePaths.resolve_texture_from_path(path)
