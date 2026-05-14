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
	var unlocked_ids: Array[int] = unlock_state.get("unlocked_partners", [])
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

		var portrait: ColorRect = slot.get_node("PortraitRect")
		var name_label: Label = slot.get_node("NameLabel")
		var role_label: Label = slot.get_node("RoleLabel")
		var lv_label: Label = slot.get_node("LvLabel")
		var check_box: CheckBox = slot.get_node("SelectCheck")

		portrait.color = Color.html(config.get("portrait_color", "#FFFFFF"))
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
