## res://scripts/models/runtime_final_battle.gd
## 模块: RuntimeFinalBattle
## 职责: 终局战数据模型
## 依赖: 无
## class_name: RuntimeFinalBattle

class_name RuntimeFinalBattle
extends RefCounted

var run_id: String = ""
var enemy_config_id: int = 0
var result: int = 0              # 0=失败, 1=胜利
var hero_remaining_hp: int = 0
var hero_max_hp: int = 0
var damage_dealt_to_enemy: int = 0
var enemy_max_hp: int = 0
var total_rounds: int = 0
var ultimate_triggered: bool = false

func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"enemy_config_id": enemy_config_id,
		"result": result,
		"hero_remaining_hp": hero_remaining_hp,
		"hero_max_hp": hero_max_hp,
		"damage_dealt_to_enemy": damage_dealt_to_enemy,
		"enemy_max_hp": enemy_max_hp,
		"total_rounds": total_rounds,
		"ultimate_triggered": ultimate_triggered,
	}

static func from_dict(data: Dictionary) -> RuntimeFinalBattle:
	var fb := RuntimeFinalBattle.new()
	fb.run_id = data.get("run_id", "")
	fb.enemy_config_id = int(data.get("enemy_config_id", 0))
	fb.result = data.get("result", 0)
	fb.hero_remaining_hp = data.get("hero_remaining_hp", 0)
	fb.hero_max_hp = data.get("hero_max_hp", 0)
	fb.damage_dealt_to_enemy = data.get("damage_dealt_to_enemy", 0)
	fb.enemy_max_hp = data.get("enemy_max_hp", 0)
	fb.total_rounds = data.get("total_rounds", 0)
	fb.ultimate_triggered = data.get("ultimate_triggered", false)
	return fb
