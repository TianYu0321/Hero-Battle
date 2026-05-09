## res://scripts/models/battle_action.gd
## 模块: BattleAction
## 职责: 战斗行动记录数据模型
## 依赖: 无
## class_name: BattleAction

class_name BattleAction
extends RefCounted

var action_id: String = ""
var battle_id: String = ""
var round_number: int = 1
var actor_type: int = 1
var partner_id: String = ""
var action_type: int = 1
var skill_id: int = 0
var target_type: int = 1
var damage_value: int = 0
var is_crit: bool = false
var is_evade: bool = false
var buff_applied: String = ""
var chain_sequence: int = 0
var action_order: int = 1
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"action_id": action_id,
		"battle_id": battle_id,
		"round_number": round_number,
		"actor_type": actor_type,
		"partner_id": partner_id,
		"action_type": action_type,
		"skill_id": skill_id,
		"target_type": target_type,
		"damage_value": damage_value,
		"is_crit": is_crit,
		"is_evade": is_evade,
		"buff_applied": buff_applied,
		"chain_sequence": chain_sequence,
		"action_order": action_order,
		"created_at": created_at,
	}


static func from_dict(data: Dictionary) -> BattleAction:
	var a := BattleAction.new()
	a.action_id = data.get("action_id", "")
	a.battle_id = data.get("battle_id", "")
	a.round_number = data.get("round_number", 1)
	a.actor_type = data.get("actor_type", 1)
	a.partner_id = data.get("partner_id", "")
	a.action_type = data.get("action_type", 1)
	a.skill_id = data.get("skill_id", 0)
	a.target_type = data.get("target_type", 1)
	a.damage_value = data.get("damage_value", 0)
	a.is_crit = data.get("is_crit", false)
	a.is_evade = data.get("is_evade", false)
	a.buff_applied = data.get("buff_applied", "")
	a.chain_sequence = data.get("chain_sequence", 0)
	a.action_order = data.get("action_order", 1)
	a.created_at = data.get("created_at", 0)
	return a
