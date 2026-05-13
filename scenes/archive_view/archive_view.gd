## res://scenes/archive_view/archive_view.gd
## 模块: ArchiveView
## 职责: 档案浏览主界面，列表展示所有历史档案，支持切换排行榜视图
## class_name: ArchiveView

class_name ArchiveView
extends Control

@onready var _back_button: Button = $VBox/Header/BackButton
@onready var _clear_button: Button = $VBox/Header/ClearButton
@onready var _btn_archives: Button = $VBox/TabButtons/BtnArchives
@onready var _btn_leaderboard: Button = $VBox/TabButtons/BtnLeaderboard
@onready var _scroll: ScrollContainer = $VBox/Scroll
@onready var _list_container: VBoxContainer = $VBox/Scroll/ListContainer
@onready var _archive_detail: ArchiveDetail = $VBox/ArchiveDetail
@onready var _leaderboard_panel: LeaderboardPanel = $VBox/LeaderboardPanel

var _item_scene: PackedScene = preload("res://scenes/archive_view/archive_list_item.tscn")

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_btn_archives.pressed.connect(_on_show_archives)
	_btn_leaderboard.pressed.connect(_on_show_leaderboard)
	_archive_detail.back_requested.connect(_on_detail_back)
	_show_archives()

func _show_archives() -> void:
	_scroll.visible = true
	_leaderboard_panel.visible = false
	_archive_detail.visible = false
	_btn_archives.disabled = true
	_btn_leaderboard.disabled = false
	_refresh_list()

func _show_leaderboard() -> void:
	_scroll.visible = false
	_leaderboard_panel.visible = true
	_archive_detail.visible = false
	_btn_archives.disabled = false
	_btn_leaderboard.disabled = true
	_leaderboard_panel.refresh()

func _refresh_list() -> void:
	# 清空现有条目
	for child in _list_container.get_children():
		child.queue_free()

	var archives: Array[Dictionary] = SaveManager.load_archives("date", 100)
	for data in archives:
		var item: ArchiveListItem = _item_scene.instantiate()
		_list_container.add_child(item)
		item.setup(data)
		item.item_clicked.connect(_on_item_clicked)

func _on_item_clicked(data: Dictionary) -> void:
	_archive_detail.show_archive(data)
	_scroll.visible = false
	_archive_detail.visible = true

func _on_detail_back() -> void:
	_archive_detail.visible = false
	_scroll.visible = true

func _on_show_archives() -> void:
	_show_archives()

func _on_show_leaderboard() -> void:
	_show_leaderboard()

func _on_clear_pressed() -> void:
	SaveManager.clear_all_archives()
	_refresh_list()

func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()
