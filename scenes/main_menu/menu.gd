## res://scenes/main_menu/menu.gd
## 模块: MenuUI
## 职责: 主菜单界面，提供开始新局/继续游戏/斗士档案/退出功能
## 依赖: EventBus, SaveManager, ConfigManager
## 被依赖: 无（顶层入口UI）
## class_name: MenuUI

class_name MenuUI
extends Control

@onready var _btn_new_game: Button = %BtnNewGame
@onready var _btn_continue: Button = %BtnContinue
@onready var _btn_archive: Button = %BtnArchive
@onready var _btn_quit: Button = %BtnQuit

func _ready() -> void:
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_archive.pressed.connect(_on_archive_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)

	var save_data: Dictionary = SaveManager.load_latest_run()
	_btn_continue.disabled = save_data.is_empty()
	if _btn_continue.disabled:
		_btn_continue.modulate.a = 0.5

	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)

func _on_new_game_pressed() -> void:
	EventBus.new_game_requested.emit("")

func _on_continue_pressed() -> void:
	EventBus.continue_game_requested.emit()

func _on_archive_pressed() -> void:
	EventBus.archive_view_requested.emit("")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_save_loaded(save_data: Dictionary) -> void:
	_btn_continue.disabled = false
	_btn_continue.modulate.a = 1.0

func _on_load_failed(error_code: int, error_message: String, save_slot: int) -> void:
	_btn_continue.disabled = true
	_btn_continue.modulate.a = 0.5
