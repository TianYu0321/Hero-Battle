## res://scripts/models/fighter_archive_main.gd
## 模块: FighterArchiveMain
## 职责: 斗士档案主表数据模型
## 依赖: RuntimeRun, RuntimeHero, RuntimePartner
## class_name: FighterArchiveMain

class_name FighterArchiveMain
extends RefCounted

var archive_id: String = ""
var account_id: String = ""
var run_id: String = ""
var hero_config_id: int = 0
var hero_name: String = ""
var run_status: int = 1
var final_turn: int = 30
var final_score: int = 0
var final_grade: String = ""
var partner_count: int = 0
var max_hp_reached: int = 0
var attr_snapshot_vit: int = 0
var attr_snapshot_str: int = 0
var attr_snapshot_agi: int = 0
var attr_snapshot_tec: int = 0
var attr_snapshot_mnd: int = 0
var initial_vit: int = 0
var initial_str: int = 0
var initial_agi: int = 0
var initial_tec: int = 0
var initial_mnd: int = 0
var battle_win_count: int = 0
var elite_win_count: int = 0
var elite_total_count: int = 0
var pvp_10th_result: int = 0
var pvp_20th_result: int = 0
var training_count: int = 0
var shop_visit_count: int = 0
var rescue_success_count: int = 0
var total_damage_dealt: int = 0
var total_enemies_killed: int = 0
var max_chain_reached: int = 0
var total_chain_count: int = 0
var total_aid_trigger_count: int = 0
var passive_skill_trigger_count: int = 0
var ultimate_triggered: bool = false
var gold_spent: int = 0
var gold_earned_total: int = 0
var is_pvp_eligible: bool = true
var is_fixed: bool = true
var client_version: String = "1.0.0"
var started_at: int = 0
var ended_at: int = 0
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"archive_id": archive_id,
		"account_id": account_id,
		"run_id": run_id,
		"hero_config_id": hero_config_id,
		"hero_name": hero_name,
		"run_status": run_status,
		"final_turn": final_turn,
		"final_score": final_score,
		"final_grade": final_grade,
		"partner_count": partner_count,
		"max_hp_reached": max_hp_reached,
		"attr_snapshot_vit": attr_snapshot_vit,
		"attr_snapshot_str": attr_snapshot_str,
		"attr_snapshot_agi": attr_snapshot_agi,
		"attr_snapshot_tec": attr_snapshot_tec,
		"attr_snapshot_mnd": attr_snapshot_mnd,
		"initial_vit": initial_vit,
		"initial_str": initial_str,
		"initial_agi": initial_agi,
		"initial_tec": initial_tec,
		"initial_mnd": initial_mnd,
		"battle_win_count": battle_win_count,
		"elite_win_count": elite_win_count,
		"elite_total_count": elite_total_count,
		"pvp_10th_result": pvp_10th_result,
		"pvp_20th_result": pvp_20th_result,
		"training_count": training_count,
		"shop_visit_count": shop_visit_count,
		"rescue_success_count": rescue_success_count,
		"total_damage_dealt": total_damage_dealt,
		"total_enemies_killed": total_enemies_killed,
		"max_chain_reached": max_chain_reached,
		"total_chain_count": total_chain_count,
		"total_aid_trigger_count": total_aid_trigger_count,
		"passive_skill_trigger_count": passive_skill_trigger_count,
		"ultimate_triggered": ultimate_triggered,
		"gold_spent": gold_spent,
		"gold_earned_total": gold_earned_total,
		"is_pvp_eligible": is_pvp_eligible,
		"is_fixed": is_fixed,
		"client_version": client_version,
		"started_at": started_at,
		"ended_at": ended_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> FighterArchiveMain:
	var archive := FighterArchiveMain.new()
	archive.archive_id = data.get("archive_id", "")
	archive.account_id = data.get("account_id", "")
	archive.run_id = data.get("run_id", "")
	archive.hero_config_id = data.get("hero_config_id", 0)
	archive.hero_name = data.get("hero_name", "")
	archive.run_status = data.get("run_status", 1)
	archive.final_turn = data.get("final_turn", 30)
	archive.final_score = data.get("final_score", 0)
	archive.final_grade = data.get("final_grade", "")
	archive.partner_count = data.get("partner_count", 0)
	archive.max_hp_reached = data.get("max_hp_reached", 0)
	archive.attr_snapshot_vit = data.get("attr_snapshot_vit", 0)
	archive.attr_snapshot_str = data.get("attr_snapshot_str", 0)
	archive.attr_snapshot_agi = data.get("attr_snapshot_agi", 0)
	archive.attr_snapshot_tec = data.get("attr_snapshot_tec", 0)
	archive.attr_snapshot_mnd = data.get("attr_snapshot_mnd", 0)
	archive.initial_vit = data.get("initial_vit", 0)
	archive.initial_str = data.get("initial_str", 0)
	archive.initial_agi = data.get("initial_agi", 0)
	archive.initial_tec = data.get("initial_tec", 0)
	archive.initial_mnd = data.get("initial_mnd", 0)
	archive.battle_win_count = data.get("battle_win_count", 0)
	archive.elite_win_count = data.get("elite_win_count", 0)
	archive.elite_total_count = data.get("elite_total_count", 0)
	archive.pvp_10th_result = data.get("pvp_10th_result", 0)
	archive.pvp_20th_result = data.get("pvp_20th_result", 0)
	archive.training_count = data.get("training_count", 0)
	archive.shop_visit_count = data.get("shop_visit_count", 0)
	archive.rescue_success_count = data.get("rescue_success_count", 0)
	archive.total_damage_dealt = data.get("total_damage_dealt", 0)
	archive.total_enemies_killed = data.get("total_enemies_killed", 0)
	archive.max_chain_reached = data.get("max_chain_reached", 0)
	archive.total_chain_count = data.get("total_chain_count", 0)
	archive.total_aid_trigger_count = data.get("total_aid_trigger_count", 0)
	archive.passive_skill_trigger_count = data.get("passive_skill_trigger_count", 0)
	archive.ultimate_triggered = data.get("ultimate_triggered", false)
	archive.gold_spent = data.get("gold_spent", 0)
	archive.gold_earned_total = data.get("gold_earned_total", 0)
	archive.is_pvp_eligible = data.get("is_pvp_eligible", true)
	archive.is_fixed = data.get("is_fixed", true)
	archive.client_version = data.get("client_version", "1.0.0")
	archive.started_at = data.get("started_at", 0)
	archive.ended_at = data.get("ended_at", 0)
	archive.updated_at = data.get("updated_at", 0)
	return archive


static func from_runtime(run: RuntimeRun, hero: RuntimeHero, partners: Array) -> FighterArchiveMain:
	var archive := FighterArchiveMain.new()
	archive.run_id = run.run_id
	archive.hero_config_id = run.hero_config_id
	archive.hero_name = ""  # 需要外部填入
	archive.run_status = run.run_status
	archive.final_turn = run.current_turn
	archive.final_score = run.total_score
	archive.partner_count = partners.size()
	archive.max_hp_reached = hero.max_hp
	archive.attr_snapshot_vit = hero.current_vit
	archive.attr_snapshot_str = hero.current_str
	archive.attr_snapshot_agi = hero.current_agi
	archive.attr_snapshot_tec = hero.current_tec
	archive.attr_snapshot_mnd = hero.current_mnd
	archive.battle_win_count = run.battle_win_count
	archive.elite_win_count = run.elite_win_count
	archive.elite_total_count = run.elite_total_count
	archive.pvp_10th_result = run.pvp_10th_result
	archive.pvp_20th_result = run.pvp_20th_result
	archive.training_count = hero.total_training_count
	archive.shop_visit_count = run.shop_visit_count
	archive.rescue_success_count = run.rescue_success_count
	archive.total_damage_dealt = run.total_damage_dealt
	archive.total_enemies_killed = run.total_enemies_killed
	archive.max_chain_reached = run.max_chain_reached
	archive.total_chain_count = run.total_chain_count
	archive.total_aid_trigger_count = run.total_aid_trigger_count
	archive.ultimate_triggered = hero.ultimate_used
	archive.gold_spent = run.gold_spent
	archive.gold_earned_total = run.gold_earned_total
	return archive
