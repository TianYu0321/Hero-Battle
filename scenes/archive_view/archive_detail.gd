## res://scenes/archive_view/archive_detail.gd
## 模块: ArchiveDetail
## 职责: 档案详情弹窗，显示五维快照、伙伴列表、评分明细、战斗统计
## class_name: ArchiveDetail

class_name ArchiveDetail
extends PanelContainer

signal back_requested

@onready var _title_label: Label = $VBox/TitleRow/TitleLabel
@onready var _close_button: Button = $VBox/TitleRow/CloseButton
@onready var _hero_name_label: Label = $VBox/HeroRow/HeroNameLabel
@onready var _rating_label: Label = $VBox/HeroRow/RatingLabel
@onready var _total_score_label: Label = $VBox/HeroRow/TotalScoreLabel
@onready var _attr_container: VBoxContainer = $VBox/AttrSection/AttrContainer
@onready var _partner_container: HBoxContainer = $VBox/PartnerSection/PartnerContainer
@onready var _score_container: VBoxContainer = $VBox/ScoreSection/ScoreContainer
@onready var _stat_container: VBoxContainer = $VBox/StatSection/StatContainer
@onready var _back_button: Button = $VBox/BackButton

const _ATTR_NAMES: Array[String] = ["体魄", "力量", "敏捷", "技巧", "精神"]
const _ATTR_KEYS: Array[String] = ["attr_snapshot_vit", "attr_snapshot_str", "attr_snapshot_agi", "attr_snapshot_tec", "attr_snapshot_mnd"]
const _ATTR_INIT_KEYS: Array[String] = ["initial_vit", "initial_str", "initial_agi", "initial_tec", "initial_mnd"]

const _SCORE_ITEMS: Array[Dictionary] = [
	{"label": "终局战", "weight": 0.4, "raw_key": "final_performance_raw", "weighted_key": "final_performance_weighted"},
	{"label": "养成效率", "weight": 0.2, "raw_key": "training_efficiency_raw", "weighted_key": "training_efficiency_weighted"},
	{"label": "PVP", "weight": 0.2, "raw_key": "pvp_performance_raw", "weighted_key": "pvp_performance_weighted"},
	{"label": "流派纯度", "weight": 0.1, "raw_key": "build_purity_raw", "weighted_key": "build_purity_weighted"},
	{"label": "连锁展示", "weight": 0.1, "raw_key": "chain_showcase_raw", "weighted_key": "chain_showcase_weighted"},
]

func _ready() -> void:
	_back_button.pressed.connect(func(): back_requested.emit())
	_close_button.pressed.connect(func(): back_requested.emit())

func show_archive(data: Dictionary) -> void:
	visible = true
	var hero_name: String = data.get("hero_name", "未知")
	var rating: String = data.get("final_grade", data.get("grade", "D"))
	var total_score: float = data.get("total_score", data.get("final_score", 0))

	_hero_name_label.text = hero_name
	_rating_label.text = "评级: %s" % rating
	_rating_label.add_theme_color_override("font_color", _get_rating_color(rating))
	_total_score_label.text = "总分: %.1f" % total_score

	_populate_attrs(data)
	_populate_partners(data)
	_populate_score(data, total_score)
	_populate_stats(data)

func _populate_attrs(data: Dictionary) -> void:
	# 清空旧节点
	for child in _attr_container.get_children():
		child.queue_free()

	for i in range(_ATTR_KEYS.size()):
		var current: int = data.get(_ATTR_KEYS[i], 0)
		var initial: int = data.get(_ATTR_INIT_KEYS[i], 0)
		var max_val: int = int(maxf(current, initial) * 1.2)
		if max_val <= 0:
			max_val = 1

		var hbox: HBoxContainer = HBoxContainer.new()
		var name_label: Label = Label.new()
		name_label.text = "%s: %d (初始%d)" % [_ATTR_NAMES[i], current, initial]
		name_label.custom_minimum_size = Vector2(180, 0)
		hbox.add_child(name_label)

		var bar: ProgressBar = ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = max_val
		bar.value = current
		bar.custom_minimum_size = Vector2(200, 20)
		hbox.add_child(bar)

		_attr_container.add_child(hbox)

func _populate_partners(data: Dictionary) -> void:
	for child in _partner_container.get_children():
		child.queue_free()

	var partners: Array = data.get("partners", [])
	for p in partners:
		if not p is Dictionary:
			continue
		var pname: String = p.get("partner_name", "伙伴")
		var level: int = p.get("final_level", 1)
		var role: String = ""
		var pcfg_id: int = p.get("partner_config_id", 0)
		for pk in ConfigManager.get_all_partner_configs().values():
			if pk.get("id", 0) == pcfg_id:
				role = pk.get("role", "")
				break
		var label: Label = Label.new()
		label.text = "[%s Lv%d]" % [pname, level]
		if not role.is_empty():
			label.tooltip_text = role
		_partner_container.add_child(label)

	if partners.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "无伙伴"
		_partner_container.add_child(empty_label)

func _populate_score(data: Dictionary, total_score: float) -> void:
	for child in _score_container.get_children():
		child.queue_free()

	for item in _SCORE_ITEMS:
		var raw: float = data.get(item.raw_key, 0.0)
		var weighted: float = data.get(item.weighted_key, 0.0)
		var label: Label = Label.new()
		label.text = "%s(%.0f%%): %.1f/100 → %.1f" % [item.label, item.weight * 100.0, raw, weighted]
		_score_container.add_child(label)

	var sep: HSeparator = HSeparator.new()
	_score_container.add_child(sep)

	var total_label: Label = Label.new()
	total_label.text = "总分: %.1f" % total_score
	total_label.add_theme_font_size_override("font_size", 18)
	_score_container.add_child(total_label)

func _populate_stats(data: Dictionary) -> void:
	for child in _stat_container.get_children():
		child.queue_free()

	var total_damage: int = data.get("total_damage_dealt", 0)
	var kills: int = data.get("total_enemies_killed", 0)
	var max_chain: int = data.get("max_chain_reached", 0)
	var ultimate: bool = data.get("ultimate_triggered", false)
	var pvp10: int = data.get("pvp_10th_result", 0)
	var pvp20: int = data.get("pvp_20th_result", 0)
	var pvp_text: String = "第10回%s/第20回%s" % [
		"胜" if pvp10 == 1 else "败" if pvp10 == 2 else "未参与",
		"胜" if pvp20 == 1 else "败" if pvp20 == 2 else "未参与",
	]

	var line1: Label = Label.new()
	line1.text = "总伤害: %d  击杀: %d  最高连锁: %d" % [total_damage, kills, max_chain]
	_stat_container.add_child(line1)

	var line2: Label = Label.new()
	line2.text = "必杀触发: %s  PVP: %s" % ["是" if ultimate else "否", pvp_text]
	_stat_container.add_child(line2)

func _get_rating_color(rating: String) -> Color:
	match rating:
		"S": return Color("#FFD700")
		"A": return Color("#C0C0C0")
		"B": return Color("#CD7F32")
		"C": return Color("#888888")
		"D": return Color("#555555")
		_: return Color("#888888")
