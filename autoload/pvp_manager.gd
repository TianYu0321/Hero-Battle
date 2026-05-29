## pvp_manager.gd — Autoload
## 职责: PVP 数据管理、匹配、结算、排行榜
## 注意: 魔城币奖励保持 20/次，每日上限 5 次（无连胜额外奖励）
extends Node

signal match_found(opponent: Dictionary)
signal match_result(won: bool, net_wins: int, magic_coins_earned: int)
signal daily_reward_updated(remaining: int)

const DAILY_MAX_REWARDS := 5
const MAGIC_COINS_PER_WIN := 20
const HISTORY_MAX := 10

## 预置 AI 对手库（按净胜场分布）
const AI_OPPONENTS: Array[Dictionary] = [
	{
		"name": "见习冒险者",
		"net_wins": 0,
		"wins": 2, "losses": 2,
		"hero_id": "hero_warrior", "hero_level": 1,
		"partner_ids": ["partner_swordsman"],
		"partner_levels": {"partner_swordsman": 1},
		"ai_difficulty": 0.2,
	},
	{
		"name": "丛林猎人",
		"net_wins": 3,
		"wins": 8, "losses": 5,
		"hero_id": "hero_shadow_dancer", "hero_level": 3,
		"partner_ids": ["partner_scout", "partner_hunter"],
		"partner_levels": {"partner_scout": 2, "partner_hunter": 2},
		"ai_difficulty": 0.4,
	},
	{
		"name": "王国骑士",
		"net_wins": 8,
		"wins": 20, "losses": 12,
		"hero_id": "hero_iron_guard", "hero_level": 6,
		"partner_ids": ["partner_shieldguard", "partner_sorcerer", "partner_pharmacist"],
		"partner_levels": {"partner_shieldguard": 4, "partner_sorcerer": 3, "partner_pharmacist": 4},
		"ai_difficulty": 0.6,
	},
	{
		"name": "大魔法师",
		"net_wins": 15,
		"wins": 35, "losses": 20,
		"hero_id": "hero_shadow_dancer", "hero_level": 8,
		"partner_ids": ["partner_pharmacist", "partner_hunter", "partner_sorcerer"],
		"partner_levels": {"partner_pharmacist": 5, "partner_hunter": 5, "partner_sorcerer": 4},
		"ai_difficulty": 0.75,
	},
	{
		"name": "传说勇者",
		"net_wins": 30,
		"wins": 60, "losses": 30,
		"hero_id": "hero_iron_guard", "hero_level": 10,
		"partner_ids": ["partner_sorcerer", "partner_hunter", "partner_shieldguard"],
		"partner_levels": {"partner_sorcerer": 5, "partner_hunter": 5, "partner_shieldguard": 5},
		"ai_difficulty": 0.9,
	},
]

var _current_opponent: Dictionary = {}
var _pvp_deck: Dictionary = {}

func _ready() -> void:
	_load_pvp_data()
	_check_daily_reset()


## ========== 日重置检查 ==========

func _check_daily_reset() -> void:
	var data: Dictionary = SaveManager.load_player_data()
	var last_date: String = data.get("last_pvp_date", "")
	var today := _get_date_string()

	if last_date != today:
		data["pvp_wins_today"] = 0
		data["last_pvp_date"] = today
		SaveManager.save_player_data(data)
		daily_reward_updated.emit(DAILY_MAX_REWARDS)
		print("[PVPManager] 日重置完成，pvp_wins_today 归零")

func _get_date_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


## ========== 加载/保存 ==========

func _load_pvp_data() -> void:
	var data: Dictionary = SaveManager.load_player_data()
	var has_pvp_fields: bool = data.has("net_wins") and data.has("total_wins") and data.has("total_losses")
	if not has_pvp_fields:
		data["net_wins"] = 0
		data["total_wins"] = 0
		data["total_losses"] = 0
		SaveManager.save_player_data(data)


## ========== 队伍快照 ==========

func update_deck_snapshot() -> void:
	var archive: Dictionary = GameManager.get_pvp_archive()
	var snapshot: Dictionary = {}
	if not archive.is_empty():
		snapshot = {
			"hero_config_id": archive.get("hero_config_id", 1),
			"hero_name": archive.get("hero_name", "???"),
			"hero_level": archive.get("final_grade", 1),
			"partner_ids": archive.get("partner_ids", []),
			"max_hp": archive.get("max_hp_reached", 100),
		}
	else:
		## 无档案时使用当前运行配置
		snapshot = {
			"hero_config_id": GameManager.selected_hero_config_id,
			"hero_name": "???",
			"hero_level": 1,
			"partner_ids": GameManager.selected_partner_config_ids,
			"max_hp": 100,
		}

	var data: Dictionary = SaveManager.load_player_data()
	data["pvp_deck"] = snapshot
	SaveManager.save_player_data(data)
	_pvp_deck = snapshot
	print("[PVPManager] 队伍快照已更新: %s" % snapshot.get("hero_name", "???"))

func get_deck_snapshot() -> Dictionary:
	if _pvp_deck.is_empty():
		var data: Dictionary = SaveManager.load_player_data()
		_pvp_deck = data.get("pvp_deck", {})
		## 如果没有快照但有出战档案，自动创建
		if _pvp_deck.is_empty():
			update_deck_snapshot()
	return _pvp_deck

func has_deck_snapshot() -> bool:
	return not get_deck_snapshot().is_empty()


## ========== 匹配系统（按净胜场） ==========

func find_match() -> Dictionary:
	var candidates: Array[Dictionary] = []

	## 1. 预置 AI 对手
	candidates.append_array(AI_OPPONENTS.duplicate(true))

	## 2. 其他档案作为候选对手
	var all_archives: Array[Dictionary] = SaveManager.load_archives("date", 100, "")
	for archive in all_archives:
		var net: int = archive.get("net_wins", 0)
		candidates.append({
			"name": archive.get("hero_name", "影子斗士"),
			"net_wins": net,
			"wins": net + randi() % 5,
			"losses": randi() % 5,
			"hero_id": ConfigManager.get_hero_id_by_config_id(archive.get("hero_config_id", 1)),
			"hero_level": archive.get("final_grade", 1),
			"partner_ids": archive.get("partner_ids", []),
			"partner_levels": {},
			"ai_difficulty": clampf(0.3 + net * 0.02, 0.2, 0.95),
			"is_real_player": false,
			"_source": "archive",
			"_archive": archive,
		})

	## 3. 按净胜场接近程度排序
	var my_net: int = get_net_wins()
	candidates.sort_custom(func(a, b):
		var diff_a: int = abs(a.get("net_wins", 0) - my_net)
		var diff_b: int = abs(b.get("net_wins", 0) - my_net)
		return diff_a < diff_b
	)

	## 4. 从最接近的 3 个中随机选
	var top_n := mini(3, candidates.size())
	var top: Array = candidates.slice(0, top_n)
	var opponent: Dictionary = top[randi() % top_n] as Dictionary if not top.is_empty() else AI_OPPONENTS[0].duplicate(true)

	_current_opponent = opponent
	match_found.emit(opponent)
	return opponent


## ========== 战斗结算 ==========

func calculate_match_result(won: bool) -> Dictionary:
	var data: Dictionary = SaveManager.load_player_data()

	var magic_coins_earned: int = 0
	var today_wins: int = data.get("pvp_wins_today", 0)
	var last_date: String = data.get("last_pvp_date", "")
	var today_str: String = _get_date_string()

	## 日重置检查
	if last_date != today_str:
		today_wins = 0
		last_date = today_str

	var can_claim_reward: bool = today_wins < DAILY_MAX_REWARDS

	if won:
		data["total_wins"] = data.get("total_wins", 0) + 1

		## 发放魔城币（每日限 5 次，每次 20）
		if can_claim_reward:
			magic_coins_earned = MAGIC_COINS_PER_WIN
			SaveManager.add_mocheng_coin(magic_coins_earned)
			today_wins += 1
	else:
		data["total_losses"] = data.get("total_losses", 0) + 1

	## 重新计算净胜场
	var wins: int = data.get("total_wins", 0)
	var losses: int = data.get("total_losses", 0)
	data["net_wins"] = maxi(0, wins - losses)

	## 历史记录
	var history: Array = data.get("pvp_history", [])
	history.push_front({
		"opponent_name": _current_opponent.get("name", "???"),
		"opponent_net_wins": _current_opponent.get("net_wins", 0),
		"result": "win" if won else "loss",
		"magic_coins": magic_coins_earned,
		"timestamp": _get_timestamp(),
	})
	while history.size() > HISTORY_MAX:
		history.pop_back()
	data["pvp_history"] = history

	## 保存
	data["pvp_wins_today"] = today_wins
	data["last_pvp_date"] = last_date
	SaveManager.save_player_data(data)

	match_result.emit(won, data["net_wins"], magic_coins_earned)
	daily_reward_updated.emit(DAILY_MAX_REWARDS - today_wins)

	return {
		"won": won,
		"net_wins": data["net_wins"],
		"wins": wins,
		"losses": losses,
		"magic_coins_earned": magic_coins_earned,
		"remaining_rewards": DAILY_MAX_REWARDS - today_wins,
	}


## ========== 查询 API ==========

func get_net_wins() -> int:
	var data: Dictionary = SaveManager.load_player_data()
	return data.get("net_wins", 0)

func get_stats() -> Dictionary:
	var data: Dictionary = SaveManager.load_player_data()
	var wins: int = data.get("total_wins", 0)
	var losses: int = data.get("total_losses", 0)
	var today_wins: int = data.get("pvp_wins_today", 0)
	return {
		"net_wins": data.get("net_wins", 0),
		"wins": wins,
		"losses": losses,
		"magic_coins": data.get("mocheng_coin", 0),
		"daily_reward_count": today_wins,
		"remaining_rewards": DAILY_MAX_REWARDS - today_wins,
		"history": data.get("pvp_history", []),
	}


## ========== 排行榜（按净胜场） ==========

func get_leaderboard() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	## 自己
	var my_stats := get_stats()
	entries.append({
		"rank": 0,
		"name": "我",
		"net_wins": my_stats["net_wins"],
		"wins": my_stats["wins"],
		"losses": my_stats["losses"],
		"is_player": true,
	})

	## AI 对手
	for opp in AI_OPPONENTS:
		entries.append({
			"rank": 0,
			"name": opp["name"],
			"net_wins": opp["net_wins"],
			"wins": opp.get("wins", 0),
			"losses": opp.get("losses", 0),
			"is_player": false,
		})

	## 其他档案
	var all_archives: Array[Dictionary] = SaveManager.load_archives("date", 50, "")
	for archive in all_archives:
		var net: int = archive.get("net_wins", 0)
		entries.append({
			"rank": 0,
			"name": archive.get("hero_name", "影子斗士"),
			"net_wins": net,
			"wins": net + randi() % 3,
			"losses": randi() % 3,
			"is_player": false,
		})

	## 按净胜场降序
	entries.sort_custom(func(a, b): return a["net_wins"] > b["net_wins"])

	## 分配排名
	for i in range(entries.size()):
		entries[i]["rank"] = i + 1

	return entries


## ========== 辅助 ==========

func _get_timestamp() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
