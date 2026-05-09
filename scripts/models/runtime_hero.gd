## res://scripts/models/runtime_hero.gd
## 模块: RuntimeHero
## 职责: 主角运行时状态数据模型
## 依赖: 无
## class_name: RuntimeHero

class_name RuntimeHero
extends RefCounted

var id: String = ""
var run_id: String = ""
var hero_config_id: int = 0
var max_hp: int = 0
var current_hp: int = 0
var current_vit: int = 0
var current_str: int = 0
var current_agi: int = 0
var current_tec: int = 0
var current_mnd: int = 0
var passive_skill_id: int = 0
var ultimate_skill_id: int = 0
var ultimate_used: bool = false
var buff_list: Array = []
var total_training_count: int = 0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var total_enemies_killed: int = 0
var is_alive: bool = true
var created_at: int = 0
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"run_id": run_id,
		"hero_config_id": hero_config_id,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"current_vit": current_vit,
		"current_str": current_str,
		"current_agi": current_agi,
		"current_tec": current_tec,
		"current_mnd": current_mnd,
		"passive_skill_id": passive_skill_id,
		"ultimate_skill_id": ultimate_skill_id,
		"ultimate_used": ultimate_used,
		"buff_list": buff_list.duplicate(),
		"total_training_count": total_training_count,
		"total_damage_dealt": total_damage_dealt,
		"total_damage_taken": total_damage_taken,
		"total_enemies_killed": total_enemies_killed,
		"is_alive": is_alive,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> RuntimeHero:
	var hero := RuntimeHero.new()
	hero.id = data.get("id", "")
	hero.run_id = data.get("run_id", "")
	hero.hero_config_id = data.get("hero_config_id", 0)
	hero.max_hp = data.get("max_hp", 0)
	hero.current_hp = data.get("current_hp", 0)
	hero.current_vit = data.get("current_vit", 0)
	hero.current_str = data.get("current_str", 0)
	hero.current_agi = data.get("current_agi", 0)
	hero.current_tec = data.get("current_tec", 0)
	hero.current_mnd = data.get("current_mnd", 0)
	hero.passive_skill_id = data.get("passive_skill_id", 0)
	hero.ultimate_skill_id = data.get("ultimate_skill_id", 0)
	hero.ultimate_used = data.get("ultimate_used", false)
	hero.buff_list = data.get("buff_list", []).duplicate()
	hero.total_training_count = data.get("total_training_count", 0)
	hero.total_damage_dealt = data.get("total_damage_dealt", 0)
	hero.total_damage_taken = data.get("total_damage_taken", 0)
	hero.total_enemies_killed = data.get("total_enemies_killed", 0)
	hero.is_alive = data.get("is_alive", true)
	hero.created_at = data.get("created_at", 0)
	hero.updated_at = data.get("updated_at", 0)
	return hero
