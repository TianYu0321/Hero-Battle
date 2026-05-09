## res://scenes/archive_view/archive_list_item.gd
## 模块: ArchiveListItem
## 职责: 档案列表单条条目，显示色块、主角名、评级、总分、终局结果、日期
## class_name: ArchiveListItem

class_name ArchiveListItem
extends Control

signal item_clicked(archive_data: Dictionary)

@onready var _color_rect: ColorRect = $HBox/ColorRect
@onready var _name_label: Label = $HBox/InfoColumn/NameLabel
@onready var _rating_label: Label = $HBox/InfoColumn/RatingLabel
@onready var _score_label: Label = $HBox/InfoColumn/ScoreLabel
@onready var _result_label: Label = $HBox/InfoColumn/ResultLabel
@onready var _date_label: Label = $HBox/InfoColumn/DateLabel

var _archive_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	_archive_data = data.duplicate()
	var hero_name: String = data.get("hero_name", "未知")
	var rating: String = data.get("final_grade", data.get("rating", "D"))
	var total_score: int = data.get("final_score", data.get("total_score", 0))
	var created_at: int = data.get("created_at", 0)
	var run_status: int = data.get("run_status", 1)

	_name_label.text = hero_name
	_rating_label.text = "评级: %s" % rating
	_rating_label.add_theme_color_override("font_color", _get_rating_color(rating))
	_score_label.text = "总分: %d" % total_score
	_result_label.text = "终局: %s" % ("胜利" if run_status == 2 else "败北" if run_status == 3 else "放弃")
	_date_label.text = _format_date(created_at)

	# 色块颜色取自主角配置
	var hero_config_id: int = data.get("hero_config_id", 0)
	var hero_id: String = ConfigManager.get_hero_id_by_config_id(hero_config_id)
	if hero_id.is_empty():
		hero_id = "hero_warrior"
	var hero_cfg: Dictionary = ConfigManager.get_hero_config(hero_id)
	var color_str: String = hero_cfg.get("portrait_color", "#888888")
	_color_rect.color = Color(color_str)

	# 点击区域
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		item_clicked.emit(_archive_data)

func _get_rating_color(rating: String) -> Color:
	match rating:
		"S": return Color("#FFD700")
		"A": return Color("#C0C0C0")
		"B": return Color("#CD7F32")
		"C": return Color("#888888")
		"D": return Color("#555555")
		_: return Color("#888888")

func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(unix_time, true).split(" ")[0]
