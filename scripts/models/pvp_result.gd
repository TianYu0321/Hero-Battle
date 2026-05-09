## res://scripts/models/pvp_result.gd
## 模块: PvpResult
## 职责: PVP对战结果数据模型
## 依赖: 无
## class_name: PvpResult

class_name PvpResult
extends RefCounted

var won: bool = false
var pvp_turn: int = 0
var opponent_name: String = ""
var opponent_hero_id: String = ""
var combat_summary: Dictionary = {}
var penalty_tier: String = "none"
var penalty_value: int = 0
var rating_change: int = 0


func to_dict() -> Dictionary:
	return {
		"won": won,
		"pvp_turn": pvp_turn,
		"opponent_name": opponent_name,
		"opponent_hero_id": opponent_hero_id,
		"combat_summary": combat_summary.duplicate(),
		"penalty_tier": penalty_tier,
		"penalty_value": penalty_value,
		"rating_change": rating_change,
	}


static func from_dict(data: Dictionary) -> PvpResult:
	var pr := PvpResult.new()
	pr.won = data.get("won", false)
	pr.pvp_turn = data.get("pvp_turn", 0)
	pr.opponent_name = data.get("opponent_name", "")
	pr.opponent_hero_id = data.get("opponent_hero_id", "")
	pr.combat_summary = data.get("combat_summary", {}).duplicate()
	pr.penalty_tier = data.get("penalty_tier", "none")
	pr.penalty_value = data.get("penalty_value", 0)
	pr.rating_change = data.get("rating_change", 0)
	return pr
