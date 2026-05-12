class_name PvpLobby
extends Control

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

var _current_opponent: Dictionary = {}
var _player_data: Dictionary = {}
var _virtual_pool: VirtualArchivePool = null

func _ready() -> void:
	_load_player_data()
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

func _update_ui() -> void:
	net_wins_label.text = "当前净胜场: %d" % _player_data.get("net_wins", 0)
	coin_label.text = "魔城币: %d" % _player_data.get("mocheng_coin", 0)

func _on_match_pressed() -> void:
	print("[PvpLobby] 开始匹配")

	var net_wins: int = _player_data.get("net_wins", 0)
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

	var player_archive := _get_current_player_archive()
	var pvp_config: Dictionary = {
		"turn_number": 30,
		"player_gold": 0,
		"player_hp": player_archive.get("max_hp_reached", 100),
		"player_hero": _archive_to_battle_dict(player_archive),
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
		"hero_remaining_hp": int(player_archive.get("max_hp_reached", 100) * result.get("combat_summary", {}).get("player_hp_ratio", 1.0)),
		"hero_max_hp": player_archive.get("max_hp_reached", 100),
		"gold_reward": 0,
		"max_chain_count": result.get("combat_summary", {}).get("max_chain", 0),
		"opponent_source": _current_opponent.get("_source", result.get("opponent_source", "ai")),
	}
	battle_summary_panel.show_result(battle_result)
	battle_summary_panel.visible = true

func _process_pvp_result(result: Dictionary) -> void:
	var won: bool = result.get("won", false)
	var total_wins: int = _player_data.get("total_wins", 0)
	var total_losses: int = _player_data.get("total_losses", 0)
	var current_coin: int = _player_data.get("mocheng_coin", 0)
	var today_wins: int = _player_data.get("pvp_wins_today", 0)
	var last_date: String = _player_data.get("last_pvp_date", "")

	var today_str: String = Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), true).split(" ")[0]
	if last_date != today_str:
		today_wins = 0
		last_date = today_str

	if won:
		total_wins += 1
		_player_data["total_wins"] = total_wins

		if today_wins < 5:
			current_coin += 20
			today_wins += 1
			print("[PvpLobby] 魔城币+20，今日胜利 %d/5" % today_wins)
			EventBus.emit_signal("mocheng_coin_changed", current_coin, 20, "pvp_reward")
		else:
			print("[PvpLobby] 今日PVP已达上限，不再发放魔城币")
	else:
		total_losses += 1
		_player_data["total_losses"] = total_losses
		print("[PvpLobby] PVP失败")

	var net_wins: int = maxi(0, total_wins - total_losses)
	_player_data["net_wins"] = net_wins
	_player_data["mocheng_coin"] = current_coin
	_player_data["pvp_wins_today"] = today_wins
	_player_data["last_pvp_date"] = last_date

	SaveManager.save_player_data(_player_data)
	_update_ui()

	print("[PvpLobby] PVP结算完成: 净胜场=%d, 魔城币=%d" % [net_wins, current_coin])

func _get_current_player_archive() -> Dictionary:
	var archives: Array[Dictionary] = SaveManager.load_archives("date", 1, "")
	if not archives.is_empty():
		return archives[0]
	return {
		"hero_config_id": 1,
		"attr_snapshot_vit": 20,
		"attr_snapshot_str": 20,
		"attr_snapshot_agi": 20,
		"attr_snapshot_tec": 20,
		"attr_snapshot_mnd": 20,
		"max_hp_reached": 100,
		"partners": [],
	}

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
