class_name RescuePopup
extends Control

## 营救弹窗：显示3名候选伙伴，玩家选择一名招募

signal partner_selected(partner_config_id: int)
signal abandoned

@onready var title_label: Label = $TitleLabel
@onready var candidates_container: HBoxContainer = $CandidatesContainer

const RESCUE_CARD_SCENE: PackedScene = preload("res://scenes/rescue/rescue_card.tscn")

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
	var card: Control = RESCUE_CARD_SCENE.instantiate()
	
	## 卡片框背景（按伙伴ID+等级）
	var partner_id: String = str(candidate.get("partner_id", ""))
	var level: int = int(candidate.get("level", 1))
	level = clampi(level, 1, 5)
	var card_bg: TextureRect = card.get_node("CardBg")
	card_bg.texture = ResourcePaths.load_texture_safe(ResourcePaths.get_partner_card_path(partner_id, level))
	
	## 头像
	var portrait: TextureRect = card.get_node("MarginContainer/VBoxContainer/Portrait")
	var portrait_path: String = candidate.get("portrait_path", "")
	if portrait_path.is_empty():
		portrait_path = ResourcePaths.get_partner_portrait(str(candidate.get("partner_id", 0)))
	var tex: Texture2D = _resolve_texture_from_path(portrait_path)
	if tex != null:
		portrait.texture = tex
	
	## 名字
	var name_label: Label = card.get_node("MarginContainer/VBoxContainer/NameLabel")
	name_label.text = candidate.get("name", "???")
	
	## 职业/定位
	var role_label: Label = card.get_node("MarginContainer/VBoxContainer/RoleLabel")
	role_label.text = candidate.get("role", "伙伴")
	
	## 招募按钮
	var partner_config_id: int = int(candidate.get("partner_id", 0))
	var btn: Button = card.get_node("MarginContainer/VBoxContainer/RecruitBtn")
	btn.pressed.connect(func(): _on_recruit_pressed(partner_config_id))
	
	return card

func _on_recruit_pressed(partner_config_id: int) -> void:
	partner_selected.emit(partner_config_id)

func _resolve_texture_from_path(path: String) -> Texture2D:
	return ResourcePaths.resolve_texture_from_path(path)
