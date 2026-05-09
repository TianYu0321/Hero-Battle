## res://scripts/models/player_account.gd
## 模块: PlayerAccount
## 职责: 玩家账号局外存档数据模型
## 依赖: 无
## class_name: PlayerAccount

class_name PlayerAccount
extends RefCounted

var account_id: String = ""
var nickname: String = "Player"
var created_at: int = 0
var last_login_at: int = 0
var total_play_time_sec: int = 0
var total_runs_completed: int = 0
var total_runs_win: int = 0
var total_runs_lose: int = 0
var highest_score: int = 0
var highest_grade: String = ""
var unlocked_hero_id_list: Array = [1]
var unlocked_partner_id_list: Array = [1001, 1002, 1003, 1004, 1005, 1006]
var outgame_gold: int = 0
var is_tutorial_completed: bool = false
var client_version: String = "1.0.0"
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"account_id": account_id,
		"nickname": nickname,
		"created_at": created_at,
		"last_login_at": last_login_at,
		"total_play_time_sec": total_play_time_sec,
		"total_runs_completed": total_runs_completed,
		"total_runs_win": total_runs_win,
		"total_runs_lose": total_runs_lose,
		"highest_score": highest_score,
		"highest_grade": highest_grade,
		"unlocked_hero_id_list": unlocked_hero_id_list.duplicate(),
		"unlocked_partner_id_list": unlocked_partner_id_list.duplicate(),
		"outgame_gold": outgame_gold,
		"is_tutorial_completed": is_tutorial_completed,
		"client_version": client_version,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> PlayerAccount:
	var acc := PlayerAccount.new()
	acc.account_id = data.get("account_id", "")
	acc.nickname = data.get("nickname", "Player")
	acc.created_at = data.get("created_at", 0)
	acc.last_login_at = data.get("last_login_at", 0)
	acc.total_play_time_sec = data.get("total_play_time_sec", 0)
	acc.total_runs_completed = data.get("total_runs_completed", 0)
	acc.total_runs_win = data.get("total_runs_win", 0)
	acc.total_runs_lose = data.get("total_runs_lose", 0)
	acc.highest_score = data.get("highest_score", 0)
	acc.highest_grade = data.get("highest_grade", "")
	var uhl = data.get("unlocked_hero_id_list", [1])
	acc.unlocked_hero_id_list = uhl.duplicate() if uhl is Array else [1]
	var upl = data.get("unlocked_partner_id_list", [1001, 1002, 1003, 1004, 1005, 1006])
	acc.unlocked_partner_id_list = upl.duplicate() if upl is Array else [1001, 1002, 1003, 1004, 1005, 1006]
	acc.outgame_gold = data.get("outgame_gold", 0)
	acc.is_tutorial_completed = data.get("is_tutorial_completed", false)
	acc.client_version = data.get("client_version", "1.0.0")
	acc.updated_at = data.get("updated_at", 0)
	return acc
