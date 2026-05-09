## res://scripts/systems/pvp_director.gd
## 模块: PvpDirector
## 职责: PVP系统主控：生成AI对手 → 调用BattleEngine → 返回真实胜负 + 惩罚应用
## 依赖: PvpOpponentGenerator, BattleEngine, EventBus
## class_name: PvpDirector

class_name PvpDirector
extends Node


func execute_pvp(pvp_config: Dictionary) -> Dictionary:
	var turn_number: int = pvp_config.get("turn_number", 0)

	# 1. 生成AI对手
	var opponent_generator: PvpOpponentGenerator = PvpOpponentGenerator.new()
	var battle_config: Dictionary = opponent_generator.generate_opponent(pvp_config, turn_number)

	# 2. 执行真实战斗
	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)

	EventBus.pvp_match_found.emit({
		"opponent_name": battle_config.hero.name,
		"opponent_hero_id": battle_config.hero.hero_id,
		"turn": turn_number,
	})
	EventBus.pvp_battle_started.emit([battle_config.hero], battle_config.enemies, "fast_forward")

	var battle_result: Dictionary = battle_engine.execute_battle(battle_config)
	var combat_log: Array[String] = battle_engine.get_combat_log()
	battle_engine.queue_free()

	# 3. 判断胜负（AI是hero，所以battle_result.winner=="player"表示AI赢）
	var player_won: bool = (battle_result.winner == "enemy")

	# 4. 计算惩罚
	var penalty_tier: String = "none"
	var penalty_value: int = 0

	if not player_won:
		if turn_number == 10:
			penalty_tier = "gold_50"
			var gold: int = pvp_config.get("player_gold", 0)
			penalty_value = int(gold * 0.5)
		elif turn_number == 20:
			penalty_tier = "hp_30"
			var hp: int = pvp_config.get("player_hp", 0)
			penalty_value = int(hp * 0.3)

	# 5. 组装PvpResult
	var opponent_hp_ratio: float = 0.0
	if battle_config.hero.max_hp > 0:
		opponent_hp_ratio = float(battle_config.hero.hp) / battle_config.hero.max_hp

	var player_hp_ratio: float = 0.0
	if battle_config.enemies.size() > 0:
		var player_unit: Dictionary = battle_config.enemies[0]
		if player_unit.get("max_hp", 0) > 0:
			player_hp_ratio = float(player_unit.get("hp", 0)) / player_unit.get("max_hp", 1)

	var pvp_result_data: Dictionary = {
		"won": player_won,
		"pvp_turn": turn_number,
		"opponent_name": battle_config.hero.name,
		"opponent_hero_id": battle_config.hero.get("hero_id", ""),
		"combat_summary": {
			"turns": battle_result.get("turns_elapsed", 0),
			"player_damage_dealt": battle_result.get("total_damage_dealt", 0),
			"player_damage_taken": battle_result.get("total_damage_taken", 0),
			"opponent_hp_ratio": opponent_hp_ratio,
			"player_hp_ratio": player_hp_ratio,
			"ultimate_triggered": battle_result.get("ultimate_triggered", false),
			"max_chain": battle_result.get("chain_stats", {}).get("max_chain", 0),
		},
		"penalty_tier": penalty_tier,
		"penalty_value": penalty_value,
		"rating_change": 0,
	}

	# 6. 发射信号
	var signal_result: Dictionary = {
		"won": player_won,
		"pvp_turn": turn_number,
		"rating_change": 0,
		"opponent_name": battle_config.hero.name,
		"combat_log_summary": combat_log,
		"penalty_tier": penalty_tier,
		"penalty_value": penalty_value,
	}
	EventBus.pvp_result.emit(signal_result)

	return pvp_result_data
