## res://scripts/models/battle_round.gd
## 模块: BattleRound
## 职责: 战斗回合记录数据模型
## 依赖: 无
## class_name: BattleRound

class_name BattleRound
extends RefCounted

var round_id: String = ""
var battle_id: String = ""
var round_number: int = 1
var hero_hp_start: int = 0
var enemy_hp_start: int = 0
var hero_hp_end: int = 0
var enemy_hp_end: int = 0
var hero_action: String = ""
var enemy_action: String = ""
var chain_triggered: bool = false
var chain_count: int = 0
var aid_triggered: bool = false
var ultimate_triggered: bool = false
var buff_changes: String = ""


func to_dict() -> Dictionary:
	return {
		"round_id": round_id,
		"battle_id": battle_id,
		"round_number": round_number,
		"hero_hp_start": hero_hp_start,
		"enemy_hp_start": enemy_hp_start,
		"hero_hp_end": hero_hp_end,
		"enemy_hp_end": enemy_hp_end,
		"hero_action": hero_action,
		"enemy_action": enemy_action,
		"chain_triggered": chain_triggered,
		"chain_count": chain_count,
		"aid_triggered": aid_triggered,
		"ultimate_triggered": ultimate_triggered,
		"buff_changes": buff_changes,
	}


static func from_dict(data: Dictionary) -> BattleRound:
	var r := BattleRound.new()
	r.round_id = data.get("round_id", "")
	r.battle_id = data.get("battle_id", "")
	r.round_number = data.get("round_number", 1)
	r.hero_hp_start = data.get("hero_hp_start", 0)
	r.enemy_hp_start = data.get("enemy_hp_start", 0)
	r.hero_hp_end = data.get("hero_hp_end", 0)
	r.enemy_hp_end = data.get("enemy_hp_end", 0)
	r.hero_action = data.get("hero_action", "")
	r.enemy_action = data.get("enemy_action", "")
	r.chain_triggered = data.get("chain_triggered", false)
	r.chain_count = data.get("chain_count", 0)
	r.aid_triggered = data.get("aid_triggered", false)
	r.ultimate_triggered = data.get("ultimate_triggered", false)
	r.buff_changes = data.get("buff_changes", "")
	return r
