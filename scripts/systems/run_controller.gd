## res://scripts/systems/run_controller.gd
## 模块: RunController
## 职责: 养成循环主控：30回合状态机，固定节点，回合推进，存档触发
## 依赖: CharacterManager, NodePoolSystem, NodeResolver, SettlementSystem, EventBus, SaveManager
## class_name: RunController

class_name RunController
extends Node

enum RunState {
	HERO_SELECT,
	TAVERN,
	RUNNING_NODE_SELECT,
	RUNNING_NODE_EXECUTE,
	TURN_ADVANCE,
	FINAL_BATTLE,
	SETTLEMENT,
}

const _MAX_TURNS: int = 30
const _RESCUE_TURNS: Array[int] = [5, 15, 25]
const _PVP_TURNS: Array[int] = [10, 20]
const _FINAL_TURN: int = 30

var _state: int = RunState.HERO_SELECT
var _run: RuntimeRun = null
var _hero: RuntimeHero = null
var _last_battle_summary: Dictionary = {}

var _character_manager: CharacterManager = null
var _node_pool_system: NodePoolSystem = null
var _node_resolver: NodeResolver = null
var _settlement_system: SettlementSystem = null

var _current_node_options: Array[Dictionary] = []
var _pending_node_type: int = 0


func _ready() -> void:
	# 子系统初始化
	_character_manager = CharacterManager.new()
	_character_manager.name = "CharacterManager"
	add_child(_character_manager)

	_node_pool_system = NodePoolSystem.new()
	_node_pool_system.name = "NodePoolSystem"
	add_child(_node_pool_system)

	var training_system := TrainingSystem.new()
	training_system.name = "TrainingSystem"
	add_child(training_system)
	training_system.initialize(_character_manager)

	var shop_system := ShopSystem.new()
	shop_system.name = "ShopSystem"
	add_child(shop_system)
	shop_system.initialize(_character_manager)

	var rescue_system := RescueSystem.new()
	rescue_system.name = "RescueSystem"
	add_child(rescue_system)
	rescue_system.initialize(_character_manager)

	var elite_battle_system := EliteBattleSystem.new()
	elite_battle_system.name = "EliteBattleSystem"
	add_child(elite_battle_system)

	var pvp_director := PvpDirector.new()
	pvp_director.name = "PvpDirector"
	add_child(pvp_director)

	_node_resolver = NodeResolver.new()
	_node_resolver.name = "NodeResolver"
	add_child(_node_resolver)

	_settlement_system = SettlementSystem.new()
	_settlement_system.name = "SettlementSystem"
	add_child(_settlement_system)


func start_new_run(hero_config_id: int, starter_partner_ids: Array[int]) -> void:
	_run = RuntimeRun.new()
	_run.hero_config_id = hero_config_id
	_run.run_status = 1  # ONGOING
	_run.current_turn = 1
	_run.started_at = int(Time.get_unix_time_from_system())

	_hero = _character_manager.initialize_hero(hero_config_id)
	_character_manager.initialize_partners(starter_partner_ids)

	# 记录初始属性总和
	_run.initial_attr_sum = _hero.current_vit + _hero.current_str + _hero.current_agi + _hero.current_tec + _hero.current_mnd

	_node_pool_system.reset()

	EventBus.emit_signal("run_started", {
		"hero_id": hero_config_id,
		"partner_ids": starter_partner_ids,
		"run_seed": _run.run_seed,
	})

	_change_state(RunState.RUNNING_NODE_SELECT)


func continue_run(save_data: Dictionary) -> bool:
	# TODO: 从存档恢复完整状态
	return false


func select_node(node_index: int) -> void:
	if _state != RunState.RUNNING_NODE_SELECT:
		push_warning("[RunController] Not in NODE_SELECT state")
		return
	if node_index < 0 or node_index >= _current_node_options.size():
		push_warning("[RunController] Invalid node index: %d" % node_index)
		return

	var selected: Dictionary = _current_node_options[node_index]
	_pending_node_type = selected.get("node_type", 0)

	EventBus.emit_signal("node_selected", node_index)
	_change_state(RunState.RUNNING_NODE_EXECUTE)

	# 执行节点
	var context: Dictionary = {
		"hero": _hero,
		"run": _run,
		"turn": _run.current_turn,
		"partners": _character_manager.get_partners()
	}
	var result: Dictionary = _node_resolver.resolve_node(_pending_node_type, selected, context)
	_process_node_result(result)


func purchase_shop_item(item_data: Dictionary) -> Dictionary:
	return _node_resolver.process_shop_purchase(item_data, _run)


func select_rescue_partner(partner_config_id: int) -> void:
	_node_resolver.process_rescue_selection(partner_config_id, _run.current_turn, _run)


func advance_turn() -> void:
	if _state != RunState.TURN_ADVANCE:
		return

	# 检查终局
	if _run.current_turn >= _MAX_TURNS:
		_change_state(RunState.FINAL_BATTLE)
		_execute_final_battle()
		return

	_run.current_turn += 1

	# 自动存档
	_auto_save()

	EventBus.emit_signal("turn_advanced", _run.current_turn, _get_phase_name(), _is_fixed_node_turn(_run.current_turn))
	_change_state(RunState.RUNNING_NODE_SELECT)


func abandon_run() -> void:
	_run.run_status = 4  # ABANDON
	_end_run()


func get_current_run_summary() -> Dictionary:
	if _run == null:
		return {}
	return {
		"hero": _hero.to_dict() if _hero != null else {},
		"partners": _get_partner_dicts(),
		"gold": _run.gold_owned,
		"current_turn": _run.current_turn,
		"node_options": _current_node_options,
		"run_state": _state,
		"phase": _get_phase_name(),
	}


func get_current_node_options() -> Array[Dictionary]:
	return _current_node_options


func get_current_battle_summary() -> Dictionary:
	return _last_battle_summary


# --- 状态机处理 ---

func _change_state(new_state: int) -> void:
	var old_state: int = _state
	_state = new_state

	match new_state:
		RunState.RUNNING_NODE_SELECT:
			_generate_node_options()
			EventBus.emit_signal("node_options_presented", _current_node_options)
			EventBus.emit_signal("round_changed", _run.current_turn, _MAX_TURNS, _get_phase_name())

		RunState.RUNNING_NODE_EXECUTE:
			pass

		RunState.TURN_ADVANCE:
			pass

		RunState.FINAL_BATTLE:
			EventBus.emit_signal("scene_state_changed", "RUNNING", "FINAL_BATTLE", {})

		RunState.SETTLEMENT:
			EventBus.emit_signal("scene_state_changed", "FINAL_BATTLE", "SETTLEMENT", {})


func _generate_node_options() -> void:
	var turn: int = _run.current_turn

	# 固定节点检查
	if turn in _RESCUE_TURNS:
		# 救援：3个候选伙伴（只生成一次，避免与NodeResolver重复生成导致不一致）
		var candidates: Array[Dictionary] = _node_resolver._rescue_system.generate_candidates()
		_current_node_options.clear()
		for c in candidates:
			_current_node_options.append({
				"node_type": 5,
				"node_name": "救援：" + c.get("name", ""),
				"description": c.get("role", ""),
				"node_id": "rescue_%d_%s" % [turn, c.get("partner_id", "")],
				"partner_config_id": int(c.get("partner_id", "0")),
				"candidates": candidates,
			})
		return

	if turn in _PVP_TURNS:
		_current_node_options = [{
			"node_type": 6,
			"node_name": "PVP检定",
			"description": "与其他斗士进行对战检定",
			"node_id": "pvp_%d" % turn,
		}]
		return

	if turn == _FINAL_TURN:
		_current_node_options = [{
			"node_type": 7,
			"node_name": "终局战",
			"description": "最终决战",
			"node_id": "final_%d" % turn,
		}]
		return

	# 普通回合：从节点池生成3个选项
	_current_node_options = _node_pool_system.generate_options(turn)


func _process_node_result(result: Dictionary) -> void:
	if not result.get("success", true):
		# 节点执行失败（如精英战败北）
		if _hero != null and not _hero.is_alive:
			_run.run_status = 3  # LOSE
			_end_run()
			return

	# 处理奖励
	for reward in result.get("rewards", []):
		_process_reward(reward)

	# 记录节点历史
	_run.node_history.append({
		"turn": _run.current_turn,
		"node_type": _pending_node_type,
		"result": result,
	})

	# 如果是战斗节点，保存战斗摘要供UI回放
	if _pending_node_type == NodePoolSystem.NodeType.BATTLE or _pending_node_type == NodePoolSystem.NodeType.FINAL_BOSS:
		var battle_result: Dictionary = result.get("battle_result", {})
		if battle_result.is_empty() and result.has("winner"):
			battle_result = result
		var hero_name: String = _hero.hero_name if _hero != null else "英雄"
		var enemy_name: String = "敌人"
		if result.has("enemy_config"):
			enemy_name = result["enemy_config"].get("name", "敌人")
		_last_battle_summary = {
			"hero_name": hero_name,
			"enemy_name": enemy_name,
			"hero_max_hp": _hero.max_hp if _hero != null else 100,
			"enemy_max_hp": 100,
			"hero_final_hp": battle_result.get("hero_remaining_hp", _hero.current_hp if _hero != null else 100),
			"enemy_final_hp": 0 if battle_result.get("winner", "") == "player" else 100,
			"rounds": battle_result.get("turns_elapsed", 1),
			"log": result.get("log", ""),
			"winner": battle_result.get("winner", "player"),
		}

	# 更新计数器
	match _pending_node_type:
		2, 3:
			_run.battle_win_count += 1
			if _pending_node_type == 3:
				_run.elite_win_count += 1
				_run.elite_total_count += 1
		4:
			_run.shop_visit_count += 1
		6:
			# PVP结果由 _process_reward 中的 "pvp_result" 分支处理
			pass

	_node_pool_system.record_selection(_pending_node_type)
	_change_state(RunState.TURN_ADVANCE)
	advance_turn()


func _process_reward(reward: Dictionary) -> void:
	var rtype: String = reward.get("type", "")
	match rtype:
		"gold":
			var amount: int = reward.get("amount", 0)
			_run.gold_owned += amount
			_run.gold_earned_total += amount
			EventBus.emit_signal("gold_changed", _run.gold_owned, amount, "battle_reward")
		"attr_up":
			pass  # 属性提升已在TrainingSystem中通过CharacterManager应用
		"elite_reward_choice":
			pass  # 3选1奖励由UI层处理
		"pvp_result":
			var pvp_data: Dictionary = reward.get("data", {})
			if pvp_data != null and not pvp_data.is_empty():
				if not pvp_data.get("won", true):
					var penalty_tier: String = pvp_data.get("penalty_tier", "none")
					var penalty_value: int = pvp_data.get("penalty_value", 0)
					match penalty_tier:
						"gold_50":
							var old_gold: int = _run.gold_owned
							_run.gold_owned = maxi(0, _run.gold_owned - penalty_value)
							_run.gold_earned_total = maxi(0, _run.gold_earned_total - penalty_value)
							EventBus.emit_signal("gold_changed", _run.gold_owned, _run.gold_owned - old_gold, "pvp_penalty")
						"hp_30":
							var old_hp: int = _hero.current_hp
							_hero.current_hp = maxi(10, _hero.current_hp - penalty_value)
							if _hero.current_hp <= 0:
								_hero.current_hp = 10
							_hero.is_alive = _hero.current_hp > 0
							EventBus.emit_signal("stats_changed", _hero.id, {
								0: {"old": old_hp, "new": _hero.current_hp, "delta": old_hp - _hero.current_hp, "attr_code": 0}
							})
				# 记录PVP结果到RuntimeRun
				if _run.current_turn == 10:
					_run.pvp_10th_result = 1 if pvp_data.get("won", false) else 2
				elif _run.current_turn == 20:
					_run.pvp_20th_result = 1 if pvp_data.get("won", false) else 2
				if not pvp_data.get("won", false):
					_run.pvp_fail_penalty_active = true


func _execute_final_battle() -> void:
	var fb := RuntimeFinalBattle.new()
	fb.run_id = _run.run_id
	fb.enemy_config_id = 2005  # 混沌领主
	fb.hero_max_hp = _hero.max_hp

	# 接入真实 BattleEngine
	var battle_result: Dictionary = _run_battle_engine(2005)
	fb.result = 1 if battle_result.winner == "player" else 2
	fb.hero_remaining_hp = battle_result.hero_remaining_hp if battle_result.has("hero_remaining_hp") else _hero.current_hp
	fb.damage_dealt_to_enemy = battle_result.total_damage_dealt
	fb.total_rounds = battle_result.turns_elapsed
	fb.ultimate_triggered = battle_result.ultimate_triggered
	_run.final_enemy_cleared = (fb.result == 1)
	_run.run_status = 2 if fb.result == 1 else 3

	_settle(fb)


func _run_battle_engine(enemy_config_id: int) -> Dictionary:
	var hero_stats: Dictionary = {
		"physique": _hero.current_vit,
		"strength": _hero.current_str,
		"agility": _hero.current_agi,
		"technique": _hero.current_tec,
		"spirit": _hero.current_mnd,
	}
	var hero_id: String = ConfigManager.get_hero_id_by_config_id(_hero.hero_config_id)
	if hero_id.is_empty():
		hero_id = "hero_warrior"
	var battle_hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)
	battle_hero.hp = _hero.current_hp
	battle_hero.max_hp = _hero.max_hp

	var enemy_cfg: Dictionary = ConfigManager.get_enemy_config(str(enemy_config_id))
	var enemy: Dictionary = DamageCalculator.spawn_enemy(enemy_cfg, hero_stats)

	var battle_partners: Array = []
	for p in _character_manager.get_partners():
		var pstats: Dictionary = {
			"physique": p.current_vit, "strength": p.current_str,
			"agility": p.current_agi, "technique": p.current_tec, "spirit": p.current_mnd,
		}
		var pid: String = ConfigManager._PARTNER_ID_MAP.get(str(p.partner_config_id), str(p.partner_config_id))
		var pcfg: Dictionary = ConfigManager.get_partner_config(pid)
		var p_name: String = pcfg.get("name", pid)
		battle_partners.append(PartnerAssist.make_partner_battle_unit(pid, p_name, pstats))

	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)
	var config: Dictionary = {
		"hero": battle_hero,
		"enemies": [enemy],
		"partners": battle_partners,
		"battle_seed": randi(),
		"playback_mode": "fast_forward",
	}
	var result: Dictionary = battle_engine.execute_battle(config)
	battle_engine.queue_free()

	# 同步战斗后的 HP 回写到 RuntimeHero
	_hero.current_hp = battle_hero.get("hp", _hero.current_hp)
	_hero.is_alive = battle_hero.get("is_alive", true)
	return result


func _settle(final_battle: RuntimeFinalBattle) -> void:
	var partners: Array[RuntimePartner] = _character_manager.get_partners()
	var score: FighterArchiveScore = _settlement_system.calculate_score(_run, _hero, final_battle, partners)
	_run.total_score = int(score.total_score)
	var archive: FighterArchiveMain = _settlement_system.generate_fighter_archive(_run, _hero, partners, score)

	var archive_dict: Dictionary = archive.to_dict()
	var score_dict: Dictionary = score.to_dict()
	# 合并评分详情到档案字典，供后续UI使用
	for key in score_dict:
		if not archive_dict.has(key):
			archive_dict[key] = score_dict[key]
	EventBus.emit_signal("run_ended", _get_ending_type(), _run.total_score, archive_dict)
	EventBus.emit_signal("archive_generated", archive_dict)
	_change_state(RunState.SETTLEMENT)


func _end_run() -> void:
	# 清理或返回主菜单
	EventBus.emit_signal("run_ended", _get_ending_type(), _run.total_score, {})


func _auto_save() -> void:
	if SaveManager != null and _run != null:
		SaveManager.save_run_state(_run.to_dict(), true)


# --- 辅助方法 ---

func _get_phase_name() -> String:
	var turn: int = _run.current_turn if _run != null else 1
	if turn <= 9:
		return "EARLY"
	elif turn <= 19:
		return "MID"
	elif turn <= 29:
		return "LATE"
	else:
		return "FINAL"


func _is_fixed_node_turn(turn: int) -> bool:
	return turn in _RESCUE_TURNS or turn in _PVP_TURNS or turn == _FINAL_TURN


func _get_ending_type() -> String:
	match _run.run_status:
		2: return "victory"
		3: return "defeat"
		4: return "abandon"
		_: return "ongoing"


func _get_partner_dicts() -> Array:
	var result: Array = []
	for p in _character_manager.get_partners():
		result.append(p.to_dict())
	return result

func select_training_attr(attr_type: int) -> void:
	## 玩家从训练面板选择了具体属性
	if _state == RunState.RUNNING_NODE_SELECT:
		var gain: int = 5 + randi() % 3
		_hero.current_vit += gain if attr_type == 1 else 0
		_hero.current_str += gain if attr_type == 2 else 0
		_hero.current_agi += gain if attr_type == 3 else 0
		_hero.current_tec += gain if attr_type == 4 else 0
		_hero.current_mnd += gain if attr_type == 5 else 0
		EventBus.emit_signal("stats_changed", "hero", {
			str(attr_type): {"new": _hero.get_attr_value(attr_type), "delta": gain}
		})
		_change_state(RunState.TURN_ADVANCE)
		advance_turn()
