## res://scenes/archive_view/leaderboard_panel.gd
## 模块: LeaderboardPanel
## 职责: 排行榜面板，表格展示前N名，支持按主角过滤，显示排名变化
## class_name: LeaderboardPanel

class_name LeaderboardPanel
extends Control

@onready var _filter_option: OptionButton = $VBox/FilterRow/FilterOption
@onready var _refresh_button: Button = $VBox/FilterRow/RefreshButton
@onready var _table_container: VBoxContainer = $VBox/Scroll/TableContainer

var _leaderboard_system: LeaderboardSystem = LeaderboardSystem.new()
var _row_scene: PackedScene = preload("res://scenes/archive_view/leaderboard_row.tscn") if ResourceLoader.exists("res://scenes/archive_view/leaderboard_row.tscn") else null

func _ready() -> void:
	_refresh_button.pressed.connect(refresh)
	_filter_option.item_selected.connect(_on_filter_changed)
	_setup_filter()
	refresh()

func _setup_filter() -> void:
	_filter_option.clear()
	_filter_option.add_item("全部主角")
	_filter_option.set_item_metadata(0, "")
	var heroes: Array[String] = ["勇者", "影舞者", "铁卫"]
	for i in range(heroes.size()):
		_filter_option.add_item(heroes[i])
		_filter_option.set_item_metadata(i + 1, heroes[i])

func refresh() -> void:
	# 清空表格内容
	for child in _table_container.get_children():
		child.queue_free()

	var filter_idx: int = _filter_option.selected
	var filter_hero: String = _filter_option.get_item_metadata(filter_idx) if filter_idx >= 0 else ""
	var entries: Array[Dictionary] = _leaderboard_system.get_leaderboard(10, filter_hero)

	# 表头
	var header: HBoxContainer = _create_row("排名", "主角", "评级", "总分", "日期", "", true)
	_table_container.add_child(header)

	for entry in entries:
		var indicator: String = _leaderboard_system.get_rank_change_indicator(entry.rank, entry.prev_rank)
		var rank_text: String = "%d %s" % [entry.rank, indicator]
		var row: HBoxContainer = _create_row(rank_text, entry.hero_name, entry.rating, str(entry.total_score), entry.date, indicator, false)
		_table_container.add_child(row)

	if entries.is_empty():
		var empty: Label = Label.new()
		empty.text = "暂无档案"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_table_container.add_child(empty)

func _on_filter_changed(_idx: int) -> void:
	refresh()

func _create_row(rank: String, hero: String, rating: String, score: String, date: String, indicator: String, is_header: bool) -> HBoxContainer:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var labels: Array[String] = [rank, hero, rating, score, date]
	var widths: Array[int] = [80, 150, 60, 80, 120]

	for i in range(labels.size()):
		var label: Label = Label.new()
		label.text = labels[i]
		label.custom_minimum_size = Vector2(widths[i], 0)
		if is_header:
			label.add_theme_font_size_override("font_size", 16)
		else:
			label.add_theme_font_size_override("font_size", 14)
			hbox.add_child(label)
			continue
		hbox.add_child(label)

	# 排名变化颜色
	if not is_header and not indicator.is_empty():
		var first_label: Label = hbox.get_child(0)
		match indicator:
			"NEW":
				first_label.add_theme_color_override("font_color", Color.GREEN)
			"↑":
				first_label.add_theme_color_override("font_color", Color.GREEN)
			"↓":
				first_label.add_theme_color_override("font_color", Color.RED)
			"—":
				first_label.add_theme_color_override("font_color", Color.GRAY)

	# 评级颜色
	if not is_header:
		var rating_label: Label = hbox.get_child(2)
		rating_label.add_theme_color_override("font_color", _get_rating_color(rating))

	return hbox

func _get_rating_color(rating: String) -> Color:
	match rating:
		"S": return Color("#FFD700")
		"A": return Color("#C0C0C0")
		"B": return Color("#CD7F32")
		"C": return Color("#888888")
		"D": return Color("#555555")
		_: return Color("#888888")
