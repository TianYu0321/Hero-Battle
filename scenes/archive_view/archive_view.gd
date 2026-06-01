## res://scenes/archive_view/archive_view.gd
## 模块: ArchiveView
## 职责: 档案浏览主界面，列表展示所有历史档案，支持切换排行榜视图
## class_name: ArchiveView

class_name ArchiveView
extends Control

@onready var _back_button: Button = $VBox/Header/BackButton
@onready var _clear_button: Button = $VBox/Header/ClearButton
@onready var _bg_panel: ColorRect = $BgPanel
@onready var _title_label: Label = $VBox/Header/TitleLabel
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

func _ready() -> void:
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
	OutgameUIStyle.apply_background(_bg_panel)
	OutgameUIStyle.apply_label(_title_label, "title")
	OutgameUIStyle.apply_button(_back_button)
	OutgameUIStyle.apply_button(_clear_button, false, true)
	OutgameUIStyle.apply_button(_btn_archives, true)
	OutgameUIStyle.apply_button(_btn_leaderboard)
	OutgameUIStyle.apply_button(_btn_achievements)
	OutgameUIStyle.apply_panel(_archive_list_panel)
	OutgameUIStyle.apply_panel(_detail_pane, true)
	OutgameUIStyle.apply_label(_list_title, "section")
	OutgameUIStyle.apply_label(_list_hint, "muted")
	OutgameUIStyle.apply_label(_empty_title, "title")
	OutgameUIStyle.apply_label(_empty_hint, "muted")
