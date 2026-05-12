class_name PvpLobby
extends Control

@onready var hero_name_label: Label = $HeroNameLabel
@onready var net_wins_label: Label = $NetWinsDisplay
@onready var coin_label: Label = $MochengCoinDisplay
@onready var match_button: Button = $MatchButton
@onready var record_button: Button = $RecordButton
@onready var back_button: Button = $BackButton
@onready var match_result_panel: Panel = $MatchResultPanel
@onready var opponent_info_label: Label = $MatchResultPanel/OpponentInfoLabel
@onready var start_battle_button: Button = $MatchResultPanel/StartBattleButton
@onready var cancel_button: Button = $MatchResultPanel/CancelButton
@onready var battle_summary_panel = $BattleSummaryPanel
@onready var no_archive_warning: Label = $NoArchiveWarning

var _current_opponent: Dictionary = {}
var _player_data: Dictionary = {}
var _selected_archive: Dictionary = {}
var _virtual_pool: VirtualArchivePool = null

func _ready() -> void:
	_load_player_data()
	_load_selected_archive()
	_update_ui()

	match_button.pressed.connect(_on_match_pressed)
	record_button.pressed.connect(_on_record_pressed)
	back_button.pressed.connect(_on_back_pressed)
	start_battle_button.pressed.connect(_on_start_battle)
	cancel_button.pressed.connect(_on_cancel_match)
	battle_summary_panel.confirmed.connect(_on_battle_confirmed)

	match_result_panel.visible = false
	battle_summary_panel.visible = false

	_virtual_pool = VirtualArchivePool.new()
	_virtual_pool._load_virtual_archives()

func _load_player_data() -> void:
	_player_data = SaveManager.load_player_data()
	if _player_data.is_empty():
		_player_data = {
			"net_wins": 0,
			"total_wins": 0,
			"total_losses": 0,
			"mocheng_coin": 0,
			"pvp_wins_today": 0,
			"last_pvp_date": "",
		}

func _load_selected_archive() -> void:
	_selected_archive = GameManager.get_pvp_archive()
	if _selected_archive.is_empty():
		print("[PvpLobby] 没有出战档案")
		return

	# 补全字段（兼容旧档案）
	if not _selected_archive.has("net_wins"):
		_selected_archive["net_wins"] = 0
	if not _selected_archive.has("total_wins"):
		_selected_archive["total_wins"] = 0
	if not _selected_archive.has("total_losses"):
		_selected_archive["total_losses"] = 0

	print("[PvpLobby] 出战档案: %s, 净胜场=%d" % [
		_selected_archive.get("hero_name", "???"),
		_selected_archive.get("net_wins", 0)
	])

func _update_ui() -> void:
	coin_label.text = "魔城币: %d" % _player_data.get("mocheng_coin", 0)

	if _selected_archive.is_empty():
		hero_name_label.visible = false
		net_wins_label.visible = false
		no_archive_warning.visible = true
		match_button.disabled = true
	else:
		hero_name_label.visible = true
		net_wins_label.visible = true
		no_archive_warning.visible = false
		match_button.disabled = false
		hero_name_label.text = "出战: %s (%s级)" % [
			_selected_archive.get("hero_name", "???"),
			_selected_archive.get("final_grade", "?")
		]
		net_wins_label.text = "净胜场: %d" % _selected_archive.get("net_wins", 0)

func _on_match_pressed() -> void:
	if _selected_archive.is_empty():
		push_warning("[PvpLobby] 未选择出战档案")
		return

	print("[PvpLobby] 开始匹配")

	var net_wins: int = _selected_archive.get("net_wins", 0)
	var opponent: Dictionary = _find_opponent_by_net_wins(net_wins)

	if opponent.is_empty():
		opponent_info_label.text = "未找到匹配对手，使用AI挑战者"
		_current_opponent = _generate_ai_opponent()
	else:
		var opp_name: String = opponent.get("hero_name", "影子斗士")
		var opp_wins: int = opponent.get("net_wins", 0)
		opponent_info_label.text = "匹配到对手: %s\n净胜场: %d" % [opp_name, opp_wins]
		_current_opponent = opponent

	match_result_panel.visible = true

func _find_opponent_by_net_wins(player_net_wins: int) -> Dictionary:
	var all_archives: Array[Dictionary] = SaveManager.load_archives("date", 9999, "")

	# 加入虚拟档案
	for va in _virtual_pool._virtual_archives:
		all_archives.append(va)

	var candidates: Array[Dictionary] = []
	for archive in all_archives:
		var opp_net_wins: int = archive.get("net_wins", 0)
		if abs(opp_net_wins - player_net_wins) <= 2:
			candidates.append(archive)

	if candidates.is_empty():
		for archive in all_archives:
			candidates.append(archive)

	if candidates.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi() % candidates.size()]

func _generate_ai_opponent() -> Dictionary:
	return {
		"hero_name": "AI挑战者",
		"hero_config_id": 1,
		"attr_snapshot_vit": 20,
		"attr_snapshot_str": 20,
		"attr_snapshot_agi": 20,
		"attr_snapshot_tec": 20,
		"attr_snapshot_mnd": 20,
		"partners": [
			{"partner_config_id": 1001, "current_level": 1},
		],
		"net_wins": 0,
		"_source": "ai",
	}

func _on_start_battle() -> void:
	print("[PvpLobby] 开始PVP战斗")
	match_result_panel.visible = false

	var pvp_director := PvpDirector.new()
	add_child(pvp_director)

	var pvp_config: Dictionary = {
		"turn_number": 30,
		"player_gold": 0,
		"player_hp": _selected_archive.get("max_hp_reached", 100),
		"player_hero": _archive_to_battle_dict(_selected_archive),
		"run_seed": randi(),
		"use_archive": true,
		"opponent_archive": _current_opponent,
	}

	var result: Dictionary = pvp_director.execute_pvp(pvp_config)
	pvp_director.queue_free()

	_process_pvp_result(result)

	# 转换格式给 BattleSummaryPanel
	var battle_result: Dictionary = {
		"winner": "player" if result.get("won", false) else "enemy",
		"enemies": [{"name": result.get("opponent_name", "???")}],
		"turns_elapsed": result.get("combat_summary", {}).get("turns", 0),
		"hero_remaining_hp": int(_selected_archive.get("max_hp_reached", 100) * result.get("combat_summary", {}).get("player_hp_ratio", 1.0)),
		"hero_max_hp": _selected_archive.get("max_hp_reached", 100),
		"gold_reward": 0,
		"max_chain_count": result.get("combat_summary", {}).get("max_chain", 0),
		"opponent_source": _current_opponent.get("_source", result.get("opponent_source", "ai")),
	}
	battle_summary_panel.show_result(battle_result)
	battle_summary_panel.visible = true

func _process_pvp_result(result: Dictionary) -> void:
	var won: bool = result.get("won", false)
	var archive_total_wins: int = _selected_archive.get("total_wins", 0)
	var archive_total_losses: int = _selected_archive.get("total_losses", 0)
	var current_coin: int = _player_data.get("mocheng_coin", 0)
	var today_wins: int = _player_data.get("pvp_wins_today", 0)
	var last_date: String = _player_data.get("last_pvp_date", "")

	var today_str: String = Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), true).split(" ")[0]
	if last_date != today_str:
		today_wins = 0
		last_date = today_str

	if won:
		archive_total_wins += 1
		_selected_archive["total_wins"] = archive_total_wins

		if today_wins < 5:
			current_coin += 20
			today_wins += 1
			print("[PvpLobby] 魔城币+20，今日胜利 %d/5" % today_wins)
			EventBus.emit_signal("mocheng_coin_changed", current_coin, 20, "pvp_reward")
		else:
			print("[PvpLobby] 今日PVP已达上限，不再发放魔城币")
	else:
		archive_total_losses += 1
		_selected_archive["total_losses"] = archive_total_losses
		print("[PvpLobby] PVP失败")

	var net_wins: int = maxi(0, archive_total_wins - archive_total_losses)
	_selected_archive["net_wins"] = net_wins

	# 保存档案更新
	_save_archive_update()

	# 更新账号数据
	_player_data["mocheng_coin"] = current_coin
	_player_data["pvp_wins_today"] = today_wins
	_player_data["last_pvp_date"] = last_date
	# 同时更新全局统计
	_player_data["total_wins"] = _player_data.get("total_wins", 0) + (1 if won else 0)
	_player_data["total_losses"] = _player_data.get("total_losses", 0) + (0 if won else 1)
	_player_data["net_wins"] = maxi(0, _player_data.get("total_wins", 0) - _player_data.get("total_losses", 0))

	SaveManager.save_player_data(_player_data)
	_update_ui()

	print("[PvpLobby] PVP结算完成: 档案净胜场=%d, 魔城币=%d" % [net_wins, current_coin])

func _save_archive_update() -> void:
	var archive_id: String = _selected_archive.get("archive_id", "")
	if archive_id.is_empty():
		push_warning("[PvpLobby] 档案没有 archive_id，无法保存更新")
		return
	SaveManager.update_archive(archive_id, _selected_archive)
	GameManager.set_pvp_archive(_selected_archive)

func _archive_to_battle_dict(archive: Dictionary) -> Dictionary:
	return {
		"hero_id": ConfigManager.get_hero_id_by_config_id(archive.get("hero_config_id", 1)),
		"stats": {
			"physique": archive.get("attr_snapshot_vit", 10),
			"strength": archive.get("attr_snapshot_str", 10),
			"agility": archive.get("attr_snapshot_agi", 10),
			"technique": archive.get("attr_snapshot_tec", 10),
			"spirit": archive.get("attr_snapshot_mnd", 10),
		},
		"max_hp": archive.get("max_hp_reached", 100),
		"hp": archive.get("max_hp_reached", 100),
	}

func _on_record_pressed() -> void:
	print("[PvpLobby] 查看PVP记录")
	# TODO: 显示PVP历史记录弹窗

func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()

func _on_cancel_match() -> void:
	match_result_panel.visible = false
	_current_opponent = {}

func _on_battle_confirmed() -> void:
	battle_summary_panel.visible = false
