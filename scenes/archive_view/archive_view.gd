## res://scenes/archive_view/archive_view.gd
## 模块: ArchiveView
## 职责: 档案浏览主界面，列表展示所有历史档案，支持切换排行榜视图
## class_name: ArchiveView

class_name ArchiveView
extends Control

const PolishedOutgameUI := preload("res://scenes/ui/polished_outgame_ui.gd")

@onready var _back_button: Button = $VBox/Header/BackButton
@onready var _clear_button: Button = $VBox/Header/ClearButton
@onready var _bg_panel: TextureRect = $BgPanel
@onready var _header_title_spacer: Label = $VBox/Header/TitleLabel
@onready var _title_label: Label = $TitlePlate/TitleText
@onready var _btn_archives: Button = $VBox/TabButtons/BtnArchives
@onready var _btn_leaderboard: Button = $VBox/TabButtons/BtnLeaderboard
@onready var _btn_achievements: Button = $VBox/TabButtons/BtnAchievements
@onready var _body: HBoxContainer = $VBox/Body
@onready var _archive_list_panel: PanelContainer = $VBox/Body/ArchiveListPanel
@onready var _detail_pane: PanelContainer = $VBox/Body/DetailPane
@onready var _empty_detail: VBoxContainer = $VBox/Body/DetailPane/DetailVBox/EmptyDetail
@onready var _empty_title: Label = $VBox/Body/DetailPane/DetailVBox/EmptyDetail/EmptyTitle
@onready var _empty_hint: Label = $VBox/Body/DetailPane/DetailVBox/EmptyDetail/EmptyHint
@onready var _list_title: Label = $VBox/Body/ArchiveListPanel/ListVBox/ListTitle
@onready var _list_hint: Label = $VBox/Body/ArchiveListPanel/ListVBox/ListHint
@onready var _scroll: ScrollContainer = $VBox/Body/ArchiveListPanel/ListVBox/Scroll
@onready var _list_container: VBoxContainer = $VBox/Body/ArchiveListPanel/ListVBox/Scroll/ListContainer
@onready var _archive_detail: ArchiveDetail = $VBox/Body/DetailPane/DetailVBox/ArchiveDetail
@onready var _leaderboard_panel: LeaderboardPanel = $VBox/LeaderboardPanel
@onready var _achievement_panel: PanelContainer = $VBox/AchievementPanel

var _item_scene: PackedScene = preload("res://scenes/archive_view/archive_list_item.tscn")
var _font_cn: Font = null

func _ready() -> void:
	_font_cn = _load_font("res://assets/fonts/SourceHanSerifSC-Bold.otf")
	_header_title_spacer.text = ""
	_apply_outgame_style()
	_back_button.pressed.connect(_on_back_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_btn_archives.pressed.connect(_on_show_archives)
	_btn_leaderboard.pressed.connect(_on_show_leaderboard)
	_btn_achievements.pressed.connect(_on_show_achievements)
	_archive_detail.back_requested.connect(_on_detail_back)
	if _achievement_panel != null:
		_achievement_panel.closed.connect(_on_achievement_closed)
	_show_archives()

func _show_archives() -> void:
	_body.visible = true
	_leaderboard_panel.visible = false
	_archive_detail.visible = false
	_empty_detail.visible = true
	if _achievement_panel != null:
		_achievement_panel.visible = false
	_btn_archives.disabled = true
	_btn_leaderboard.disabled = false
	_btn_achievements.disabled = false
	_update_tab_styles("archives")
	_refresh_list()

func _show_leaderboard() -> void:
	_body.visible = false
	_leaderboard_panel.visible = true
	_archive_detail.visible = false
	if _achievement_panel != null:
		_achievement_panel.visible = false
	_btn_archives.disabled = false
	_btn_leaderboard.disabled = true
	_btn_achievements.disabled = false
	_update_tab_styles("leaderboard")
	_leaderboard_panel.refresh()

func _refresh_list() -> void:
	# 清空现有条目
	for child in _list_container.get_children():
		child.queue_free()

	var archives: Array[Dictionary] = SaveManager.load_archives("date", 100)
	if archives.is_empty():
		var empty := Label.new()
		empty.text = "暂无斗士档案。完成一次冒险后，阵亡或通关的队伍会被封存到这里。"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		OutgameUIStyle.apply_label(empty, "muted")
		_list_container.add_child(empty)
		return

	for data in archives:
		var item: ArchiveListItem = _item_scene.instantiate()
		_list_container.add_child(item)
		item.setup(data)
		item.item_clicked.connect(_on_item_clicked)

func _on_item_clicked(data: Dictionary) -> void:
	_archive_detail.show_archive(data)
	_empty_detail.visible = false
	_archive_detail.visible = true

func _on_detail_back() -> void:
	_archive_detail.visible = false
	_empty_detail.visible = true

func _show_achievements() -> void:
	_body.visible = false
	_leaderboard_panel.visible = false
	_archive_detail.visible = false
	if _achievement_panel != null:
		_achievement_panel.visible = true
		_achievement_panel.modulate = Color.WHITE
		_achievement_panel.scale = Vector2.ONE
		_achievement_panel._update_total_label()
	_btn_archives.disabled = false
	_btn_leaderboard.disabled = false
	_btn_achievements.disabled = true
	_update_tab_styles("achievements")

func _on_achievement_closed() -> void:
	_show_archives()

func _on_show_archives() -> void:
	_show_archives()

func _on_show_leaderboard() -> void:
	_show_leaderboard()

func _on_show_achievements() -> void:
	_show_achievements()

func _on_clear_pressed() -> void:
	SaveManager.clear_all_archives()
	_archive_detail.visible = false
	_empty_detail.visible = true
	_refresh_list()

func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()


func _apply_outgame_style() -> void:
	PolishedOutgameUI.apply_label(_title_label, "title")
	PolishedOutgameUI.apply_button(_back_button)
	PolishedOutgameUI.apply_button(_clear_button, false, true)
	PolishedOutgameUI.apply_tab(_btn_archives, true)
	PolishedOutgameUI.apply_tab(_btn_leaderboard, false)
	PolishedOutgameUI.apply_tab(_btn_achievements, false)
	_btn_leaderboard.visible = false
	PolishedOutgameUI.apply_panel(_archive_list_panel, "panel_parchment.png", 34, 18)
	PolishedOutgameUI.apply_panel(_detail_pane, "panel_parchment.png", 34, 20)
	PolishedOutgameUI.apply_label(_list_title, "section")
	PolishedOutgameUI.apply_label(_list_hint, "muted")
	PolishedOutgameUI.apply_label(_empty_title, "title")
	PolishedOutgameUI.apply_label(_empty_hint, "muted")
	PolishedOutgameUI.apply_recursive(self)
	_title_label.add_theme_font_size_override("font_size", 30)
	_list_title.add_theme_font_size_override("font_size", 22)
	_empty_title.add_theme_font_size_override("font_size", 28)


func _update_tab_styles(active_tab: String) -> void:
	PolishedOutgameUI.apply_tab(_btn_archives, active_tab == "archives")
	PolishedOutgameUI.apply_tab(_btn_leaderboard, active_tab == "leaderboard")
	PolishedOutgameUI.apply_tab(_btn_achievements, active_tab == "achievements")


func _make_archive_panel_style(strong: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.095, 0.055, 0.36) if strong else Color(0.12, 0.075, 0.045, 0.28)
	style.border_color = Color("#d5a66a")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 18
	style.content_margin_top = 16
	style.content_margin_right = 18
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _apply_font_recursive(node: Node) -> void:
	if _font_cn == null:
		return
	if node is Label:
		node.add_theme_font_override("font", _font_cn)
	elif node is Button:
		node.add_theme_font_override("font", _font_cn)
	for child in node.get_children():
		_apply_font_recursive(child)


func _apply_readability_recursive(node: Node) -> void:
	if node is Label:
		node.add_theme_constant_override("outline_size", 2)
		node.add_theme_color_override("font_outline_color", Color(0.10, 0.055, 0.025, 0.85))
	elif node is Button:
		node.add_theme_constant_override("outline_size", 2)
		node.add_theme_color_override("font_outline_color", Color(0.10, 0.055, 0.025, 0.80))
	for child in node.get_children():
		_apply_readability_recursive(child)


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null
