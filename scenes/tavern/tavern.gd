## res://scenes/tavern/tavern.gd
## 模块: TavernUI
## 职责: 展示可用伙伴，玩家选择2名首发伙伴组成初始队伍
## 依赖: EventBus, ConfigManager
## 被依赖: 无
## class_name: TavernUI

class_name TavernUI
extends Control

@onready var _partner_grid: GridContainer = %PartnerGrid
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _confirm_btn: Button = %ConfirmBtn
@onready var _back_btn: Button = %BackBtn

var _partner_ids: Array[String] = []
var _selected_partners: Array[String] = []

func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_partner_ids = _get_available_partner_ids()
	_update_confirm_button()
	_populate_partner_slots()

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

func _populate_partner_slots() -> void:
	var slot_index: int = 0
	for partner_id in _partner_ids:
		var config: Dictionary = ConfigManager.get_partner_config(partner_id)
		if config.is_empty():
			continue

		var slot: Control = _partner_grid.get_child(slot_index)
		if slot == null:
			continue

		var card_bg: TextureRect = slot.get_node("CardBg")
		var portrait: TextureRect = slot.get_node("Margin/VBox/Portrait")
		var name_label: Label = slot.get_node("Margin/VBox/NameLabel")
		var role_label: Label = slot.get_node("Margin/VBox/RoleLabel")
		var lv_label: Label = slot.get_node("Margin/VBox/LvLabel")
		var check_box: CheckBox = slot.get_node("Margin/VBox/SelectCheck")

		## 卡片框背景（酒馆伙伴默认 Lv.1）
		card_bg.texture = load(ConfigManager.get_partner_card_path(partner_id, 1))
		
		## 头像
		var avatar_path: String = config.get("avatar_path", "")
		var tex: Texture2D = _resolve_texture_from_path(avatar_path)
		if tex != null:
			portrait.texture = tex
		
		name_label.text = config.get("partner_name", partner_id)
		role_label.text = config.get("role", "")
		lv_label.text = "Lv.1"
		check_box.text = "加入队伍"
		check_box.toggled.connect(_on_partner_toggled.bind(partner_id))
		slot.visible = true

		slot_index += 1
	
	# 隐藏多余的伙伴槽位
	for i in range(slot_index, _partner_grid.get_child_count()):
		var slot: Control = _partner_grid.get_child(i)
		if slot != null:
			slot.visible = false

func _resolve_texture_from_path(path: String) -> Texture2D:
	## 支持 Texture2D 和 SpriteFrames（自动取第一帧）
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

func _on_partner_toggled(pressed: bool, partner_id: String) -> void:
	if pressed:
		if not _selected_partners.has(partner_id):
			_selected_partners.append(partner_id)
	else:
		_selected_partners.erase(partner_id)

	_update_checkbox_states()
	_update_confirm_button()

func _update_checkbox_states() -> void:
	var is_full: bool = _selected_partners.size() >= 2
	var slot_index: int = 0
	for partner_id in _partner_ids:
		var slot: Control = _partner_grid.get_child(slot_index)
		if slot == null:
			continue
		var check_box: CheckBox = slot.get_node("SelectCheck")
		if not check_box.button_pressed:
			check_box.disabled = is_full
		slot_index += 1

func _update_confirm_button() -> void:
	var count: int = _selected_partners.size()
	_subtitle_label.text = "已选择: %d/2" % count
	if count < 2:
		_subtitle_label.add_theme_color_override("font_color", Color("#E74C3C"))
	else:
		_subtitle_label.add_theme_color_override("font_color", Color("#2ECC71"))

	_confirm_btn.disabled = count != 2
	_confirm_btn.modulate.a = 1.0 if count == 2 else 0.5

func _on_confirm_pressed() -> void:
	if _selected_partners.size() != 2:
		return
	EventBus.team_confirmed.emit(_selected_partners.duplicate())

func _on_back_pressed() -> void:
	EventBus.back_to_hero_select.emit()

func get_selected_partners() -> Array[String]:
	return _selected_partners.duplicate()
