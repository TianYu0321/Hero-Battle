## res://scripts/models/runtime_run.gd
## 模块: RuntimeRun
## 职责: 单次养成运行的主表数据模型
## 依赖: 无
## class_name: RuntimeRun

class_name RuntimeRun
extends RefCounted

var run_id: String = ""
var run_status: int = 1
var player_account_id: String = ""
var hero_config_id: int = 0
var current_turn: int = 1
var current_floor: int = 1
var max_turn: int = 30
var current_node_type: int = 0
var node_history: Array = []
var total_score: int = 0
var gold_owned: int = 0
var formula_config_id: int = 1
var seed: int = 0
var started_at: int = 0
var ended_at: int = 0
var final_enemy_cleared: bool = false
var pvp_10th_result: int = 0
var pvp_20th_result: int = 0
var pvp_fail_penalty_active: bool = false
var battle_win_count: int = 0
var battle_lose_count: int = 0
var elite_win_count: int = 0
var elite_total_count: int = 0
var shop_visit_count: int = 0
var rescue_success_count: int = 0
var gold_spent: int = 0
var gold_earned_total: int = 0
var max_chain_reached: int = 0
var total_chain_count: int = 0
var total_aid_trigger_count: int = 0
var total_damage_dealt: int = 0
var total_enemies_killed: int = 0
var training_count_per_attr: Array = [0, 0, 0, 0, 0]
var initial_attr_sum: int = 0
var created_at: int = 0
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"run_status": run_status,
		"player_account_id": player_account_id,
		"hero_config_id": hero_config_id,
		"current_turn": current_turn,
		"current_floor": current_floor,
		"max_turn": max_turn,
		"current_node_type": current_node_type,
		"node_history": node_history.duplicate(),
		"total_score": total_score,
		"gold_owned": gold_owned,
		"formula_config_id": formula_config_id,
		"seed": seed,
		"started_at": started_at,
		"ended_at": ended_at,
		"final_enemy_cleared": final_enemy_cleared,
		"pvp_10th_result": pvp_10th_result,
		"pvp_20th_result": pvp_20th_result,
		"pvp_fail_penalty_active": pvp_fail_penalty_active,
		"battle_win_count": battle_win_count,
		"battle_lose_count": battle_lose_count,
		"elite_win_count": elite_win_count,
		"elite_total_count": elite_total_count,
		"shop_visit_count": shop_visit_count,
		"rescue_success_count": rescue_success_count,
		"gold_spent": gold_spent,
		"gold_earned_total": gold_earned_total,
		"max_chain_reached": max_chain_reached,
		"total_chain_count": total_chain_count,
		"total_aid_trigger_count": total_aid_trigger_count,
		"total_damage_dealt": total_damage_dealt,
		"total_enemies_killed": total_enemies_killed,
		"training_count_per_attr": training_count_per_attr.duplicate(),
		"initial_attr_sum": initial_attr_sum,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> RuntimeRun:
	var run := RuntimeRun.new()
	run.run_id = data.get("run_id", "")
	run.run_status = data.get("run_status", 1)
	run.player_account_id = data.get("player_account_id", "")
	run.hero_config_id = data.get("hero_config_id", 0)
	run.current_turn = data.get("current_turn", 1)
	run.current_floor = data.get("current_floor", 1)
	run.max_turn = data.get("max_turn", 30)
	run.current_node_type = data.get("current_node_type", 0)
	run.node_history = data.get("node_history", []).duplicate()
	run.total_score = data.get("total_score", 0)
	run.gold_owned = data.get("gold_owned", 0)
	run.formula_config_id = data.get("formula_config_id", 1)
	run.seed = data.get("seed", 0)
	run.started_at = data.get("started_at", 0)
	run.ended_at = data.get("ended_at", 0)
	run.final_enemy_cleared = data.get("final_enemy_cleared", false)
	run.pvp_10th_result = data.get("pvp_10th_result", 0)
	run.pvp_20th_result = data.get("pvp_20th_result", 0)
	run.pvp_fail_penalty_active = data.get("pvp_fail_penalty_active", false)
	run.battle_win_count = data.get("battle_win_count", 0)
	run.battle_lose_count = data.get("battle_lose_count", 0)
	run.elite_win_count = data.get("elite_win_count", 0)
	run.elite_total_count = data.get("elite_total_count", 0)
	run.shop_visit_count = data.get("shop_visit_count", 0)
	run.rescue_success_count = data.get("rescue_success_count", 0)
	run.gold_spent = data.get("gold_spent", 0)
	run.gold_earned_total = data.get("gold_earned_total", 0)
	run.max_chain_reached = data.get("max_chain_reached", 0)
	run.total_chain_count = data.get("total_chain_count", 0)
	run.total_aid_trigger_count = data.get("total_aid_trigger_count", 0)
	run.total_damage_dealt = data.get("total_damage_dealt", 0)
	run.total_enemies_killed = data.get("total_enemies_killed", 0)
	var tpa = data.get("training_count_per_attr", [0, 0, 0, 0, 0])
	if tpa is Array:
		var tpa_int: Array = []
		for v in tpa:
			tpa_int.append(int(v))
		run.training_count_per_attr = tpa_int
	else:
		run.training_count_per_attr = [0, 0, 0, 0, 0]
	run.initial_attr_sum = data.get("initial_attr_sum", 0)
	run.created_at = data.get("created_at", 0)
	run.updated_at = data.get("updated_at", 0)
	return run
