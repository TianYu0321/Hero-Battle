class_name RescuePopup
extends Control

## 营救弹窗：显示3名候选伙伴，玩家选择一名招募

signal partner_selected(partner_config_id: int)
signal abandoned

@onready var title_label: Label = $TitleLabel
@onready var candidates_container: HBoxContainer = $CandidatesContainer

func show_popup(candidates: Array) -> void:
	visible = true
	## 清空旧卡片
	for child in candidates_container.get_children():
		child.queue_free()
	
	## 创建卡片
	for candidate in candidates:
		var card := _create_rescue_card(candidate)
		candidates_container.add_child(card)

func hide_popup() -> void:
	visible = false
	for child in candidates_container.get_children():
		child.queue_free()

func _create_rescue_card(candidate: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(200, 280)
	
	## 卡片框背景（按伙伴ID+等级）
	var partner_id: String = str(candidate.get("partner_id", ""))
	var level: int = int(candidate.get("level", 1))
	level = clampi(level, 1, 5)
	var card_bg := TextureRect.new()
	card_bg.name = "CardBg"
	card_bg.layout_mode = 1
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_bg.texture = ResourcePaths.load_texture_safe(ResourcePaths.get_partner_card_path(partner_id, level))
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_bg)
	
	## 内容区（留边距避免遮挡卡片框边框）
	var margin := MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	## 稀有度角标
	var rarity: String = candidate.get("rarity_str", "C")
	var border_color: Color = _get_rarity_color(rarity)
	var badge := Label.new()
	badge.text = rarity
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", border_color)
	vbox.add_child(badge)
	
	## 头像
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path: String = candidate.get("portrait_path", "")
	if portrait_path.is_empty():
		portrait_path = ResourcePaths.get_partner_portrait(str(candidate.get("partner_id", 0)))
	var tex: Texture2D = _resolve_texture_from_path(portrait_path)
	if tex != null:
		portrait.texture = tex
	vbox.add_child(portrait)
	
	## 名字
	var name_label := Label.new()
	name_label.text = candidate.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("#E6C040"))
	vbox.add_child(name_label)
	
	## 职业/定位
	var role_label := Label.new()
	role_label.text = candidate.get("role", "伙伴")
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", Color("#888888"))
	vbox.add_child(role_label)
	
	## 招募按钮
	var partner_config_id: int = int(candidate.get("partner_id", 0))
	var btn := Button.new()
	btn.text = "招募"
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(func(): _on_recruit_pressed(partner_config_id))
	vbox.add_child(btn)
	
	return card

func _on_recruit_pressed(partner_config_id: int) -> void:
	partner_selected.emit(partner_config_id)

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"S": return Color("#E6C040")
		"A": return Color("#5A8FD0")
		"B": return Color("#4ECDC4")
		_:   return Color("#888888")

func _resolve_texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var res: Resource = load(path)
	if res == null:
		return null
	if res is Texture2D:
		return res as Texture2D
	if res is SpriteFrames:
		var frames: SpriteFrames = res
		var anim_names: PackedStringArray = frames.get_animation_names()
		for anim_name in anim_names:
			var frame_count: int = frames.get_frame_count(anim_name)
			if frame_count > 0:
				return frames.get_frame_texture(anim_name, 0)
	return null
