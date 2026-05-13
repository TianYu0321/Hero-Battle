## res://scripts/systems/pvp_director.gd
## 模块: PvpDirector
## 职责: PVP系统主控：生成AI对手 → 调用BattleEngine → 返回真实胜负 + 惩罚应用
## 依赖: PvpOpponentGenerator, BattleEngine, EventBus
## class_name: PvpDirector

class_name PvpDirector
extends Node

# v2.0: 惩罚策略（策略模式 -- 行为变化用策略而非if-else）
var _penalty_strategy: IPVPPenaltyStrategy = NullPenaltyStrategy.new()


func execute_pvp(pvp_config: Dictionary) -> Dictionary:
	var turn_number: int = pvp_config.get("turn_number", 0)
	var use_archive: bool = pvp_config.get("use_archive", true)

	# 1. 生成对手
	var opponent_generator: PvpOpponentGenerator = PvpOpponentGenerator.new()
	var archive_pool: VirtualArchivePool = get_node_or_null("/root/RunController/VirtualArchivePool")
	var battle_config: Dictionary
	if use_archive:
		# 优先使用传入的 opponent_archive（局外PVP大厅传入）
		var opponent_archive: Dictionary = pvp_config.get("opponent_archive", {})
		if not opponent_archive.is_empty():
			battle_config = opponent_generator.generate_opponent_from_archive(opponent_archive, turn_number, pvp_config)
		elif archive_pool != null:
			battle_config = opponent_generator.generate_opponent(pvp_config, turn_number, true, archive_pool)
		else:
			battle_config = opponent_generator.generate_opponent(pvp_config, turn_number, false, null)
	else:
		battle_config = opponent_generator.generate_opponent(pvp_config, turn_number, false, null)

	# 2. 执行真实战斗（附带回放记录器）
	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)

	var recorder := BattlePlaybackRecorder.new()
	recorder.name = "PvpPlaybackRecorder"
	add_child(recorder)
	recorder.start_recording()

	var _on_turn_started = func(turn, _order, _mode):
		recorder.record_event("turn_started", {"turn": turn, "order": []})
	EventBus.battle_turn_started.connect(_on_turn_started)

	var _on_action_executed = func(action_data):
		recorder.record_event("action_executed", action_data)
	EventBus.action_executed.connect(_on_action_executed)

	var _on_unit_damaged = func(unit_id, amount, hp, max_hp, _dmg_type, is_crit, is_miss, attacker_id):
		recorder.record_event("unit_damaged", {
			"unit_id": unit_id, "damage": amount, "hp": hp, "max_hp": max_hp,
			"is_crit": is_crit, "is_miss": is_miss, "attacker_id": attacker_id,
		})
	EventBus.unit_damaged.connect(_on_unit_damaged)

	var _on_unit_died = func(unit_id, uname, _unit_type, killer_id):
		recorder.record_event("unit_died", {"unit_id": unit_id, "name": uname, "killer_id": killer_id})
	EventBus.unit_died.connect(_on_unit_died)

	var _on_partner_assist = func(_pid, pname, _trigger_type, _assist_data, _assist_count):
		recorder.record_event("partner_assist", {"partner_name": pname})
	EventBus.partner_assist_triggered.connect(_on_partner_assist)

	var _on_chain_triggered = func(chain_count, _partner_id, partner_name, damage, _multiplier, _total_chains):
		recorder.record_event("chain_triggered", {
			"chain_count": chain_count, "partner_name": partner_name, "damage": damage,
		})
	EventBus.chain_triggered.connect(_on_chain_triggered)

	var _on_ultimate_triggered = func(_hero_class, hero_name, trigger_turn, _condition, ultimate_name):
		recorder.record_event("ultimate_triggered", {"hero_name": hero_name, "turn": trigger_turn, "log": ultimate_name})
	EventBus.ultimate_triggered.connect(_on_ultimate_triggered)

	EventBus.pvp_match_found.emit({
		"opponent_name": battle_config.hero.name,
		"opponent_hero_id": battle_config.hero.hero_id,
		"turn": turn_number,
	})
	EventBus.pvp_battle_started.emit([battle_config.hero], battle_config.enemies, "fast_forward")

	var battle_result: Dictionary = battle_engine.execute_battle(battle_config)
	var combat_log: Array[String] = battle_engine.get_combat_log()

	EventBus.battle_turn_started.disconnect(_on_turn_started)
	EventBus.action_executed.disconnect(_on_action_executed)
	EventBus.unit_damaged.disconnect(_on_unit_damaged)
	EventBus.unit_died.disconnect(_on_unit_died)
	EventBus.partner_assist_triggered.disconnect(_on_partner_assist)
	EventBus.chain_triggered.disconnect(_on_chain_triggered)
	EventBus.ultimate_triggered.disconnect(_on_ultimate_triggered)

	recorder.stop_recording()
	battle_engine.queue_free()

	# 3. 判断胜负（"player"=玩家获胜，"enemy"=敌人获胜）
	var player_won: bool = (battle_result.winner == "player")

	# 4. 计算惩罚（策略模式 -- v2.0无惩罚）
	var penalty_result: Dictionary = _penalty_strategy.calculate_penalty(pvp_config, turn_number, player_won)
	var penalty_tier: String = penalty_result.get("penalty_tier", "none")
	var penalty_value: int = penalty_result.get("penalty_value", 0)

	# 5. 组装PvpResult（penalty相关字段保留用于日志和UI展示，但不修改玩家状态）
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
		"opponent_name": battle_config.get("opponent_name", "AI挑战者"),
		"opponent_hero_id": battle_config.hero.get("hero_id", ""),
		"opponent_source": battle_config.get("opponent_source", "ai"),
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
		# 供 BattleAnimationPanel 使用的字段
		"playback_recorder": recorder,
		"hero": battle_config.hero,
		"enemies": battle_config.enemies,
		"winner": battle_result.get("winner", ""),
		"turns_elapsed": battle_result.get("turns_elapsed", 0),
	}

	# 6. 发射信号
	var signal_result: Dictionary = {
		"won": player_won,
		"pvp_turn": turn_number,
		"rating_change": 0,
		"opponent_name": battle_config.get("opponent_name", "AI挑战者"),
		"opponent_source": battle_config.get("opponent_source", "ai"),
		"combat_log_summary": combat_log,
		"penalty_tier": penalty_tier,
		"penalty_value": penalty_value,
	}
	EventBus.pvp_result.emit(signal_result)

	return pvp_result_data
