## res://scenes/main_menu/menu.gd
## 模块: MenuUI
## 职责: 主菜单界面，提供开始新局/继续游戏/退出功能
## 依赖: EventBus, SaveManager, ConfigManager
## 被依赖: 无（顶层入口UI）
## class_name: MenuUI

class_name MenuUI
extends Control

@onready var _btn_new_game: Button = %BtnNewGame
@onready var _btn_continue: Button = %BtnContinue
@onready var _btn_quit: Button = %BtnQuit

func _ready() -> void:
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)

	# Phase 1: 斗士档案按钮隐藏（MVP范围外）
	var btn_archive: Button = get_node_or_null("%BtnArchive")
	if btn_archive != null:
		btn_archive.visible = false
		btn_archive.disabled = true

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

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_save_loaded(save_data: Dictionary) -> void:
	_btn_continue.disabled = false
	_btn_continue.modulate.a = 1.0

func _on_load_failed(error_code: int, error_message: String, save_slot: int) -> void:
	_btn_continue.disabled = true
	_btn_continue.modulate.a = 0.5

## v2.0: 排行榜系统（净胜场制）
func show_leaderboard() -> void:
	var leaderboard_data: Array[Dictionary] = _load_leaderboard_data()
	## 排序：净胜场降序
	leaderboard_data.sort_custom(func(a, b): return a.get("net_wins", 0) > b.get("net_wins", 0))
	
	## 前3名显示档案明细
	for i in range(min(3, leaderboard_data.size())):
		var entry: Dictionary = leaderboard_data[i]
		print("[Leaderboard] #%d %s 净胜场:%d 角色:%s 属性:%s 伙伴:%s" % [
			i + 1,
			entry.get("player_name", "Unknown"),
			entry.get("net_wins", 0),
			entry.get("hero_name", ""),
			entry.get("hero_attrs", ""),
			entry.get("partners", ""),
		])
	
	## 其余仅显示名字和净胜场
	for i in range(3, leaderboard_data.size()):
		var entry: Dictionary = leaderboard_data[i]
		print("[Leaderboard] #%d %s 净胜场:%d" % [
			i + 1,
			entry.get("player_name", "Unknown"),
			entry.get("net_wins", 0),
		])
	
	## 显示自己
	var my_data: Dictionary = _get_my_data()
	print("[Leaderboard] 我的排名: %s 净胜场:%d" % [
		my_data.get("player_name", "Me"),
		my_data.get("net_wins", 0),
	])

func _load_leaderboard_data() -> Array[Dictionary]:
	## 从服务器加载，此处为占位
	return []

func _get_my_data() -> Dictionary:
	return {"player_name": "Player", "net_wins": 0}
