## res://scripts/models/battle_main.gd
## 模块: BattleMain
## 职责: 战斗主表数据模型
## 依赖: 无
## class_name: BattleMain

class_name BattleMain
extends RefCounted

var battle_id: String = ""
var run_id: String = ""
var battle_type: int = 1
var node_turn: int = 0
var enemy_config_id: int = 0
var enemy_name: String = ""
var battle_result: int = 0
var total_rounds: int = 0
var hero_start_hp: int = 0
var hero_end_hp: int = 0
var hero_max_hp: int = 0
var damage_dealt: int = 0
var damage_taken: int = 0
var ultimate_triggered: bool = false
var max_chain_reached: int = 0
var chain_trigger_count: int = 0
var aid_trigger_count: int = 0
var reward_gold: int = 0
var reward_buff_desc: String = ""
var started_at: int = 0
var ended_at: int = 0


func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"run_id": run_id,
		"battle_type": battle_type,
		"node_turn": node_turn,
		"enemy_config_id": enemy_config_id,
		"enemy_name": enemy_name,
		"battle_result": battle_result,
		"total_rounds": total_rounds,
		"hero_start_hp": hero_start_hp,
		"hero_end_hp": hero_end_hp,
		"hero_max_hp": hero_max_hp,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"ultimate_triggered": ultimate_triggered,
		"max_chain_reached": max_chain_reached,
		"chain_trigger_count": chain_trigger_count,
		"aid_trigger_count": aid_trigger_count,
		"reward_gold": reward_gold,
		"reward_buff_desc": reward_buff_desc,
		"started_at": started_at,
		"ended_at": ended_at,
	}


static func from_dict(data: Dictionary) -> BattleMain:
	var b := BattleMain.new()
	b.battle_id = data.get("battle_id", "")
	b.run_id = data.get("run_id", "")
	b.battle_type = data.get("battle_type", 1)
	b.node_turn = data.get("node_turn", 0)
	b.enemy_config_id = data.get("enemy_config_id", 0)
	b.enemy_name = data.get("enemy_name", "")
	b.battle_result = data.get("battle_result", 0)
	b.total_rounds = data.get("total_rounds", 0)
	b.hero_start_hp = data.get("hero_start_hp", 0)
	b.hero_end_hp = data.get("hero_end_hp", 0)
	b.hero_max_hp = data.get("hero_max_hp", 0)
	b.damage_dealt = data.get("damage_dealt", 0)
	b.damage_taken = data.get("damage_taken", 0)
	b.ultimate_triggered = data.get("ultimate_triggered", false)
	b.max_chain_reached = data.get("max_chain_reached", 0)
	b.chain_trigger_count = data.get("chain_trigger_count", 0)
	b.aid_trigger_count = data.get("aid_trigger_count", 0)
	b.reward_gold = data.get("reward_gold", 0)
	b.reward_buff_desc = data.get("reward_buff_desc", "")
	b.started_at = data.get("started_at", 0)
	b.ended_at = data.get("ended_at", 0)
	return b
