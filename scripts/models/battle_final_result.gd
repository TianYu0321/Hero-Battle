## res://scripts/models/battle_final_result.gd
## 模块: BattleFinalResult
## 职责: 战斗最终结果数据模型
## 依赖: 无
## class_name: BattleFinalResult

class_name BattleFinalResult
extends RefCounted

var result_id: String = ""
var battle_id: String = ""
var hero_total_damage: int = 0
var hero_max_single_hit: int = 0
var enemy_total_damage: int = 0
var total_healing: int = 0
var skill_trigger_count: int = 0
var ultimate_trigger_count: int = 0
var aid_trigger_count: int = 0
var max_chain_length: int = 0
var crit_count: int = 0
var evade_count: int = 0
var turn_count: int = 0
var review_summary: String = ""


func to_dict() -> Dictionary:
	return {
		"result_id": result_id,
		"battle_id": battle_id,
		"hero_total_damage": hero_total_damage,
		"hero_max_single_hit": hero_max_single_hit,
		"enemy_total_damage": enemy_total_damage,
		"total_healing": total_healing,
		"skill_trigger_count": skill_trigger_count,
		"ultimate_trigger_count": ultimate_trigger_count,
		"aid_trigger_count": aid_trigger_count,
		"max_chain_length": max_chain_length,
		"crit_count": crit_count,
		"evade_count": evade_count,
		"turn_count": turn_count,
		"review_summary": review_summary,
	}


static func from_dict(data: Dictionary) -> BattleFinalResult:
	var r := BattleFinalResult.new()
	r.result_id = data.get("result_id", "")
	r.battle_id = data.get("battle_id", "")
	r.hero_total_damage = data.get("hero_total_damage", 0)
	r.hero_max_single_hit = data.get("hero_max_single_hit", 0)
	r.enemy_total_damage = data.get("enemy_total_damage", 0)
	r.total_healing = data.get("total_healing", 0)
	r.skill_trigger_count = data.get("skill_trigger_count", 0)
	r.ultimate_trigger_count = data.get("ultimate_trigger_count", 0)
	r.aid_trigger_count = data.get("aid_trigger_count", 0)
	r.max_chain_length = data.get("max_chain_length", 0)
	r.crit_count = data.get("crit_count", 0)
	r.evade_count = data.get("evade_count", 0)
	r.turn_count = data.get("turn_count", 0)
	r.review_summary = data.get("review_summary", "")
	return r
