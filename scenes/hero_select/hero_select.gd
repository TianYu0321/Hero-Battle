## res://scenes/hero_select/hero_select.gd
## 模块: HeroSelectUI
## 职责: 展示可选主角，允许玩家查看详情并确认选择
## 依赖: EventBus, ConfigManager
## 被依赖: 无
## class_name: HeroSelectUI

class_name HeroSelectUI
extends Control

@onready var _hero_cards: HBoxContainer = %HeroCards
@onready var _back_btn: Button = %BackBtn

var _hero_ids: Array[String] = []
var _selected_hero_id: String = ""

func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_hero_ids.assign(ConfigManager.get_all_hero_configs().keys())
	_populate_hero_cards()

func _populate_hero_cards() -> void:
	var user_id: String = SaveManager.get_user_id()
	var unlock_state: Dictionary = SaveManager.load_unlock_state(user_id)
	var unlocked_ids: Array = unlock_state.get("unlocked_heroes", [1])
	var unlocked: Array = []
	for hid in unlocked_ids:
		var key: String = ConfigManager.get_hero_id_by_config_id(hid)
		if not key.is_empty():
			unlocked.append(key)

	var card_index: int = 0
	for hero_id in _hero_ids:
		var config: Dictionary = ConfigManager.get_hero_config(hero_id)
		if config.is_empty():
			continue

		var card: Control = _hero_cards.get_child(card_index)
		if card == null:
			continue

		var portrait: ColorRect = card.get_node("PortraitRect")
		var name_label: Label = card.get_node("NameLabel")
		var desc_label: Label = card.get_node("ClassDesc")
		var stats_container: VBoxContainer = card.get_node("StatsPreview")
		var select_btn: Button = card.get_node("SelectBtn")

		portrait.color = Color.html(config.get("portrait_color", "#FFFFFF"))
		name_label.text = config.get("hero_name", hero_id)
		desc_label.text = config.get("class_desc", "")

		var favored_attr: int = config.get("favored_attr", 0)
		_set_stat_label(stats_container.get_node("StatPhysique"), "体魄", config.get("base_physique", 0), favored_attr == 1)
		_set_stat_label(stats_container.get_node("StatStrength"), "力量", config.get("base_strength", 0), favored_attr == 2)
		_set_stat_label(stats_container.get_node("StatAgility"), "敏捷", config.get("base_agility", 0), favored_attr == 3)
		_set_stat_label(stats_container.get_node("StatTechnique"), "技巧", config.get("base_technique", 0), favored_attr == 4)
		_set_stat_label(stats_container.get_node("StatSpirit"), "精神", config.get("base_spirit", 0), favored_attr == 5)

		var is_unlocked: bool = config.get("is_default_unlock", false) or hero_id in unlocked
		
		if is_unlocked:
			select_btn.text = "选择"
			select_btn.disabled = false
			select_btn.modulate = Color(1, 1, 1)
			select_btn.pressed.connect(_on_select_hero.bind(hero_id, config))
		else:
			select_btn.text = "未解锁"
			select_btn.disabled = true
			select_btn.modulate = Color(0.3, 0.3, 0.3)
			var condition: String = config.get("unlock_condition", "")
			var condition_text: String = _get_unlock_condition_text(condition)
			desc_label.text += "\n[color=gray]%s[/color]" % condition_text

		card_index += 1

func _get_unlock_condition_text(condition: String) -> String:
	match condition:
		"clear_with_hero_warrior":
			return "通关勇者解锁"
		"clear_with_hero_shadow_dancer":
			return "通关影舞者解锁"
	return "未解锁"

func _set_stat_label(label: Label, attr_name: String, value: int, is_star: bool) -> void:
	label.text = "%s: %d %s" % [attr_name, value, "★" if is_star else ""]

func _on_select_hero(hero_id: String, _config: Dictionary) -> void:
	_selected_hero_id = hero_id
	EventBus.hero_selected.emit(hero_id)

func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()

func get_selected_hero_id() -> String:
	return _selected_hero_id
