## res://scripts/systems/elite_battle_system.gd
## 模块: EliteBattleSystem
## 职责: 精英战：调用BattleEngine，胜利后3选1奖励，失败=本局结束
## 依赖: EventBus
## class_name: EliteBattleSystem

class_name EliteBattleSystem
extends Node

# Phase 1占位：模拟精英战结果
# 真实战斗由任务4的BattleEngine实现，此处提供接口占位

func execute_elite_battle(_run: RuntimeRun, hero: RuntimeHero, enemy_config_id: int) -> Dictionary:
	var result := {
		"success": true,
		"winner": "player",
		"turns_elapsed": 0,
		"hero_remaining_hp": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"ultimate_triggered": false,
		"max_chain_reached": 0,
		"chain_trigger_count": 0,
		"aid_trigger_count": 0,
		"reward_gold": 0,
		"reward_buff_desc": "",
		"run_status": 1,
	}

	# 接入真实 BattleEngine
	var hero_stats: Dictionary = {
		"physique": hero.current_vit, "strength": hero.current_str,
		"agility": hero.current_agi, "technique": hero.current_tec, "spirit": hero.current_mnd,
	}
	var hero_id_map: Dictionary = {1: "hero_warrior", 2: "hero_shadow_dancer", 3: "hero_iron_guard"}
	var hero_id: String = hero_id_map.get(hero.hero_config_id, "hero_warrior")
	var battle_hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)
	battle_hero.hp = hero.current_hp
	battle_hero.max_hp = hero.max_hp

	var enemy_cfg: Dictionary = ConfigManager.get_enemy_config(str(enemy_config_id))
	var enemy: Dictionary = DamageCalculator.spawn_enemy(enemy_cfg, hero_stats)

	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)
	var config: Dictionary = {
		"hero": battle_hero,
		"enemies": [enemy],
		"partners": [],
		"battle_seed": randi(),
		"playback_mode": "fast_forward",
	}
	var battle_result: Dictionary = battle_engine.execute_battle(config)
	battle_engine.queue_free()

	# 同步 HP
	hero.current_hp = battle_hero.get("hp", hero.current_hp)
	hero.is_alive = battle_hero.get("is_alive", true)

	result["success"] = (battle_result.winner == "player")
	result["winner"] = battle_result.winner
	result["turns_elapsed"] = battle_result.turns_elapsed
	result["hero_remaining_hp"] = hero.current_hp
	result["damage_dealt"] = battle_result.total_damage_dealt
	result["damage_taken"] = battle_result.total_damage_taken
	result["ultimate_triggered"] = battle_result.ultimate_triggered
	result["max_chain_reached"] = battle_result.chain_stats.get("max_chain", 0) if battle_result.has("chain_stats") else 0
	result["reward_gold"] = 30 + enemy_cfg.get("difficulty_tier", 1) * 15 if result["success"] else 0

	if not result["success"]:
		result["run_status"] = 3  # LOSE

	return result


func generate_elite_rewards(difficulty_tier: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = [
		{
			"type": "buff",
			"name": "攻击提升",
			"description": "攻击力+10%[3回合]",
			"effect": {"buff_name": "攻击提升", "buff_effect": 1, "effect_value": 0.1, "duration": 3},
		},
		{
			"type": "gold",
			"name": "大量金币",
			"description": "获得%d金币" % (30 + difficulty_tier * 20),
			"amount": 30 + difficulty_tier * 20,
		},
		{
			"type": "attr",
			"name": "属性强化",
			"description": "全属性+2",
			"effect": {"vit": 2, "str": 2, "agi": 2, "tec": 2, "mnd": 2},
		},
	]
	return rewards
