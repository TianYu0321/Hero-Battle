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
@onready var _menu_button: Button = $MenuButton
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _leaderboard_panel: Panel = $LeaderboardPanel

func _ready() -> void:
	print("[MainMenu] _ready 开始, continue_button=", _btn_continue != null)
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	_menu_button.pressed.connect(_on_menu_button_pressed)

	# 启用斗士档案按钮
	var btn_archive: Button = get_node_or_null("%BtnArchive")
	if btn_archive != null:
		btn_archive.visible = true
		btn_archive.disabled = false
		btn_archive.pressed.connect(_on_archive_button_pressed)
		print("[MainMenu] 档案按钮已启用")
	else:
		push_warning("[MainMenu] BtnArchive 未找到")

	# 启用PVP对战按钮
	var btn_pvp: Button = get_node_or_null("%BtnPVP")
	if btn_pvp != null:
		btn_pvp.visible = true
		btn_pvp.disabled = false
		btn_pvp.pressed.connect(_on_pvp_pressed)
		print("[MainMenu] PVP按钮已启用")
	else:
		push_warning("[MainMenu] BtnPVP 未找到")

	# 启用商店按钮
	var btn_shop: Button = get_node_or_null("%BtnShop")
	if btn_shop != null:
		btn_shop.visible = true
		btn_shop.disabled = false
		btn_shop.pressed.connect(_on_shop_pressed)
		print("[MainMenu] 商店按钮已启用")
	else:
		push_warning("[MainMenu] BtnShop 未找到")

	# 启用排行榜按钮
	var btn_leaderboard: Button = get_node_or_null("%BtnLeaderboard")
	if btn_leaderboard != null:
		btn_leaderboard.visible = true
		btn_leaderboard.disabled = false
		btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
		print("[MainMenu] 排行榜按钮已启用")
	else:
		push_warning("[MainMenu] BtnLeaderboard 未找到")

	# 主菜单中隐藏PauseMenu的"返回主菜单"按钮
	_pause_menu.set_is_main_menu(true)

	var save_data = SaveManager.load_latest_run()
	var is_valid = SaveManager.is_valid_save(save_data)
	_btn_continue.visible = is_valid
	print("[MainMenu] 继续游戏按钮显隐: ", is_valid)

	_update_pvp_archive_display()

	EventBus.save_loaded.connect(_on_save_loaded)
	EventBus.load_failed.connect(_on_load_failed)

func _on_new_game_pressed() -> void:
	EventBus.new_game_requested.emit("")

func _on_continue_pressed() -> void:
	print("[MainMenu] 继续游戏点击, has_active_run=", SaveManager.has_active_run())
	if not SaveManager.has_active_run():
		push_error("[MainMenu] 点击继续游戏但存档无效")
		_btn_continue.visible = false
		return
	EventBus.continue_game_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_archive_button_pressed() -> void:
	print("[MainMenu] 查看档案按钮点击")
	EventBus.archive_view_requested.emit()

func _on_pvp_pressed() -> void:
	print("[MainMenu] PVP对战按钮点击")
	EventBus.pvp_lobby_requested.emit()

func _on_shop_pressed() -> void:
	print("[MainMenu] 商店按钮点击")
	EventBus.shop_requested.emit()

func _on_leaderboard_pressed() -> void:
	print("[MainMenu] 排行榜按钮点击")
	var leaderboard_system := LeaderboardSystem.new()
	var rankings := leaderboard_system.get_leaderboard(20)
	if _leaderboard_panel != null:
		_leaderboard_panel.show_rankings(rankings)
	else:
		push_warning("[MainMenu] LeaderboardPanel 未找到")

func _on_menu_button_pressed() -> void:
	print("[MainMenu] 菜单按钮点击")
	if _pause_menu.visible:
		_pause_menu.hide_menu()
	else:
		_pause_menu.show_menu()

func _on_save_loaded(_save_data: Dictionary) -> void:
	_btn_continue.visible = true

func _on_load_failed(_error_code: int, _error_message: String, _save_slot: int) -> void:
	_btn_continue.visible = false

func _enter_tree() -> void:
	if _btn_continue:
		var has_save = SaveManager.has_active_run()
		_btn_continue.visible = has_save
		print("[MainMenu] _enter_tree 重新检查存档: ", has_save)

func _update_pvp_archive_display() -> void:
	var archive := GameManager.get_pvp_archive()
	var hint_label: Label = get_node_or_null("PVPHintLabel")
	if hint_label == null:
		return
	if not archive.is_empty():
		hint_label.text = "PVP出战: %s (净胜场:%d)" % [
			archive.get("hero_name", "???"),
			archive.get("net_wins", 0)
		]
		hint_label.visible = true
	else:
		hint_label.text = "PVP出战: 未选择档案"
		hint_label.visible = true

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
