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

enum SpecialFloorPhase {
	NONE,
	RESCUE_SELECT,
	SHOP_BROWSE,
	COMPLETE,
}

enum BattleResultPhase {
	NONE,
	BATTLE_RUNNING,
	BATTLE_ENDED,
	BATTLE_CONFIRMED,
}

const _MAX_TURNS: int = 30
const _RESCUE_TURNS: Array[int] = [5, 15, 25]
const _PVP_TURNS: Array[int] = [10, 20]
const _FINAL_TURN: int = 30

var _state: int = RunState.HERO_SELECT
var _run: RuntimeRun = null
var _hero: RuntimeHero = null

var _character_manager: CharacterManager = null
var _node_pool_system: NodePoolSystem = null
var _node_resolver: NodeResolver = null
var _settlement_system: SettlementSystem = null
var _training_system: TrainingSystem = null
var _boss_pool: FinalBossPool = null

var _current_node_options: Array[Dictionary] = []
var _pending_node_type: int = 0
var _pending_result: Dictionary = {}

var _special_floor_phase: SpecialFloorPhase = SpecialFloorPhase.NONE

var _battle_result_phase: BattleResultPhase = BattleResultPhase.NONE
var _pending_battle_result: Dictionary = {}


func _ready() -> void:
	# 初始化Boss池（配置驱动，零硬编码）
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_boss_pool = FinalBossPool.new(rng)

	# 子系统初始化
	_character_manager = CharacterManager.new()
	_character_manager.name = "CharacterManager"
	add_child(_character_manager)

	_node_pool_system = NodePoolSystem.new()
	_node_pool_system.name = "NodePoolSystem"
	add_child(_node_pool_system)

	_training_system = TrainingSystem.new()
	_training_system.name = "TrainingSystem"
	add_child(_training_system)
	_training_system.initialize(_character_manager)

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

	# v2: 初始化技能质变系统
	var skill_milestone_system := SkillMilestoneSystem.new()
	skill_milestone_system.name = "SkillMilestoneSystem"
	add_child(skill_milestone_system)
	skill_milestone_system.initialize(_character_manager)

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
		"run_seed": _run.seed,
	})

	_change_state(RunState.RUNNING_NODE_SELECT)


func continue_from_save(save_data: Dictionary) -> bool:
	print("[RunController] 恢复存档")
	if save_data.is_empty():
		push_error("[RunController] Cannot continue from empty save data")
		return false
	
	var snapshot = RunSnapshot.from_dict(save_data)
	print("[RunController] 存档解析: floor=%d, hero_id=%d, gold=%d" % [snapshot.current_floor, snapshot.hero_config_id, snapshot.gold])
	
	# 恢复 RuntimeRun
	_run = RuntimeRun.new()
	_run.hero_config_id = snapshot.hero_config_id
	_run.current_turn = snapshot.current_floor
	_run.gold_owned = snapshot.gold
	_run.node_history = snapshot.node_history.duplicate()
	_run.battle_win_count = snapshot.battle_win_count
	_run.elite_win_count = snapshot.elite_win_count
	
	# 恢复英雄（通过 CharacterManager 的公共接口，不直接操作私有字段）
	if _character_manager != null:
		_hero = _character_manager.load_hero_from_snapshot(snapshot)
	else:
		push_error("[RunController] CharacterManager not initialized")
		return false
	
	# 恢复伙伴
	_character_manager.clear_partners()
	for p in snapshot.partners:
		var partner = RuntimePartner.from_dict(p)
		_character_manager.add_partner_runtime(partner)
	
	print("[RunController] 英雄恢复: VIT=%d STR=%d AGI=%d TEC=%d MND=%d HP=%d/%d" % [
		_hero.current_vit, _hero.current_str, _hero.current_agi,
		_hero.current_tec, _hero.current_mnd, _hero.current_hp, _hero.max_hp
	])
	
	# 重置节点池
	_node_pool_system.reset()
	
	# 恢复状态
	_state = RunState.RUNNING_NODE_SELECT
	_change_state(RunState.RUNNING_NODE_SELECT)
	
	EventBus.emit_signal("run_continued", _run.current_turn)
	print("[RunController] 存档恢复完成，当前层=%d" % _run.current_turn)
	return true


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

	# 如果是战斗节点，预生成敌人信息供UI显示
	if _pending_node_type == NodePoolSystem.NodeType.BATTLE:
		var enemy_data: Dictionary = _node_resolver.generate_enemy_for_floor(_run.current_turn)
		EventBus.emit_signal("enemy_encountered", enemy_data)

	# 执行节点
	var context: Dictionary = {
		"hero": _hero,
		"run": _run,
		"turn": _run.current_turn,
		"partners": _character_manager.get_partners(),
	}
	var result: Dictionary = _node_resolver.resolve(selected, context)
	_process_node_result(result)


func purchase_shop_item(item_data: Dictionary) -> Dictionary:
	var shop_system: ShopSystem = get_node_or_null("ShopSystem")
	if shop_system == null:
		push_error("[RunController] ShopSystem not found")
		return {"success": false, "error": "ShopSystem not found"}
	return shop_system.process_purchase(item_data, _run.gold_owned)


func select_rescue_partner(partner_config_id: int) -> void:
	var rescue_system: RescueSystem = get_node_or_null("RescueSystem")
	if rescue_system != null:
		rescue_system.rescue_partner(partner_config_id, _run.current_turn)
	
	# 如果当前是救援层的救援阶段，进入商店阶段
	if _special_floor_phase == SpecialFloorPhase.RESCUE_SELECT:
		_special_floor_phase = SpecialFloorPhase.SHOP_BROWSE
		print("[RunController] 特殊层阶段: SHOP_BROWSE")
		var shop_system = get_node_or_null("ShopSystem")
		var shop_items = []
		if shop_system != null:
			shop_items = shop_system.generate_shop_inventory(_run.current_turn, _run.gold_owned)
		EventBus.emit_signal("panel_opened", "SHOP_PANEL", {"items": shop_items})
	else:
		# 非救援层的普通救援（如果有的话），直接完成
		_finish_node_execution(_pending_result)


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

	EventBus.emit_signal("floor_advanced", _run.current_turn, _get_phase_name(), _is_fixed_node_turn(_run.current_turn))
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


# --- 状态机处理 ---

func _change_state(new_state: int) -> void:
	var old_state: int = _state
	_state = new_state

	match new_state:
		RunState.RUNNING_NODE_SELECT:
			_generate_node_options()
			EventBus.emit_signal("floor_changed", _run.current_turn, _MAX_TURNS, _get_phase_name())

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
	print("[RunController] 生成节点选项: 层=%d, 类型=%s" % [turn, _get_phase_name()])

	# 固定节点检查
	if turn in _RESCUE_TURNS:
		_special_floor_phase = SpecialFloorPhase.RESCUE_SELECT
		print("[RunController] 特殊层阶段: RESCUE_SELECT")
		_current_node_options.clear()
		var rescue_system: RescueSystem = get_node_or_null("RescueSystem")
		var candidates: Array[Dictionary] = []
		if rescue_system != null:
			candidates = rescue_system.generate_candidates()
		# 不生成普通选项，直接打开救援面板
		EventBus.emit_signal("panel_opened", "RESCUE_PANEL", {"candidates": candidates})
		return

	if turn in _PVP_TURNS:
		_current_node_options = [{
			"node_type": NodePoolSystem.NodeType.PVP_CHECK,
			"node_name": "PVP检定",
			"description": "与其他斗士进行对战检定",
			"node_id": "pvp_%d" % turn,
		}]
		EventBus.emit_signal("node_options_presented", _current_node_options)
		return

	if turn == _FINAL_TURN:
		_current_node_options = [{
			"node_type": 7,
			"node_name": "终局战",
			"description": "最终决战",
			"node_id": "final_%d" % turn,
		}]
		EventBus.emit_signal("node_options_presented", _current_node_options)
		return

	# 普通回合：从节点池生成选项
	_current_node_options = _node_pool_system.generate_options(turn)
	EventBus.emit_signal("node_options_presented", _current_node_options)


func _process_node_result(result: Dictionary) -> void:
	_pending_result = result
	if not result.get("success", true):
		# 节点执行失败（如精英战败北）
		if _hero != null and not _hero.is_alive:
			_run.run_status = 3  # LOSE
			_end_run()
			return

	# 处理需要UI选择的节点（训练/救援/商店）
	if result.get("requires_ui_selection", false):
		# 暂停状态机，等待UI回调（select_training_attr / select_rescue_partner / purchase_shop_item）
		EventBus.emit_signal("panel_opened", _get_panel_name_from_node_type(_pending_node_type), result)
		return

	# 处理需要接入BattleEngine的战斗节点（保留完整战斗引擎路径）
	if result.get("requires_battle", false):
		var enemy_config_id: int = result.get("enemy_config_id", 2001)
		_battle_result_phase = BattleResultPhase.BATTLE_RUNNING
		var battle_result: Dictionary = _run_battle_engine(enemy_config_id)
		# 同步战斗后主角HP
		_hero.current_hp = battle_result.get("hero_remaining_hp", _hero.current_hp)
		_hero.is_alive = battle_result.get("winner", "") == "player"
		if not _hero.is_alive:
			_run.run_status = 3  # LOSE
			_end_run()
			_battle_result_phase = BattleResultPhase.NONE
			return
		# 战斗胜利奖励金币（从敌人配置读取）
		var enemy_cfg2: Dictionary = ConfigManager.get_enemy_config(str(enemy_config_id))
		var gold_reward: int = enemy_cfg2.get("reward_gold_min", 20)
		if enemy_cfg2.has("reward_gold_max"):
			var gold_max: int = enemy_cfg2.get("reward_gold_max", gold_reward)
			if gold_max > gold_reward:
				gold_reward = randi() % (gold_max - gold_reward + 1) + gold_reward
		_process_reward({"type": "gold", "amount": gold_reward})
		_battle_result_phase = BattleResultPhase.BATTLE_ENDED
		_pending_battle_result = battle_result
		EventBus.emit_signal("battle_ended", battle_result)
		return
	elif _pending_node_type == NodePoolSystem.NodeType.PVP_CHECK:
		# PVP检定节点
		var pvp_director: PvpDirector = get_node_or_null("PvpDirector")
		if pvp_director != null:
			var pvp_config: Dictionary = {
				"turn_number": _run.current_turn,
				"player_gold": _run.gold_owned,
				"player_hp": _hero.current_hp,
				"player_hero": _hero_to_battle_dict(),
				"run_seed": _run.seed,
			}
			var pvp_result: Dictionary = pvp_director.execute_pvp(pvp_config)
			var pvp_reward: Dictionary = {"type": "pvp_result", "data": pvp_result}
			_process_reward(pvp_reward)
		_finish_node_execution(result)
		return
	else:
		# 处理普通奖励（含简化战斗返回的hp_damage/gold）
		for reward in result.get("rewards", []):
			_process_reward(reward)
		# 如果战斗失败导致死亡，已触发_end_run，不再推进回合
		if _run != null and _run.run_status != 1:
			return

	_finish_node_execution(result)


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
		"hp_heal":
			var heal_amount: int = reward.get("amount", 0)
			if _hero != null and heal_amount > 0:
				var old_hp: int = _hero.current_hp
				_hero.current_hp = mini(_hero.current_hp + heal_amount, _hero.max_hp)
				EventBus.emit_signal("stats_changed", _hero.id, {
					0: {"old": old_hp, "new": _hero.current_hp, "delta": _hero.current_hp - old_hp, "max_hp": _hero.max_hp, "attr_code": 0}
				})
		"hp_damage":
			var damage_amount: int = reward.get("amount", 0)
			if _hero != null and damage_amount > 0:
				var old_hp: int = _hero.current_hp
				_hero.current_hp = maxi(0, _hero.current_hp - damage_amount)
				_hero.is_alive = _hero.current_hp > 0
				EventBus.emit_signal("stats_changed", _hero.id, {
					0: {"old": old_hp, "new": _hero.current_hp, "delta": old_hp - _hero.current_hp, "max_hp": _hero.max_hp, "attr_code": 0}
				})
			if _hero != null and not _hero.is_alive:
				_run.run_status = 3  # LOSE
				_end_run()
		"pvp_result":
			var pvp_data: Dictionary = reward.get("data", {})
			if pvp_data != null and not pvp_data.is_empty():
				# v2: PVP失败仅影响奖励，无HP/金币惩罚
				if _run.current_turn == 10:
					_run.pvp_10th_result = 1 if pvp_data.get("won", false) else 2
				elif _run.current_turn == 20:
					_run.pvp_20th_result = 1 if pvp_data.get("won", false) else 2
		"debuff":
			# 简化：记录debuff日志，实际效果待Buff系统完善
			var effect: String = reward.get("effect", "")
			var duration: int = reward.get("duration", 3)
			print("[RunController] 获得Debuff: %s, 持续%d层" % [effect, duration])


func _execute_final_battle() -> void:
	var fb := RuntimeFinalBattle.new()
	fb.run_id = _run.run_id

	# v2.0: 从Boss池随机选择（配置驱动，零硬编码）
	var selected_boss: Dictionary = _boss_pool.select_random_boss()
	fb.enemy_config_id = selected_boss.get("enemy_config_id", 2005)
	fb.hero_max_hp = _hero.max_hp
	print("[RunController] 终局Boss: %s (ID:%d)" % [selected_boss.get("name", "???"), fb.enemy_config_id])

	# 接入真实 BattleEngine
	var battle_result: Dictionary = _run_battle_engine(fb.enemy_config_id)
	fb.result = 1 if battle_result.get("winner", "") == "player" else 2
	fb.hero_remaining_hp = battle_result.get("hero_remaining_hp", _hero.current_hp)
	fb.damage_dealt_to_enemy = battle_result.get("total_damage_dealt", 0)
	fb.total_rounds = battle_result.get("turns_elapsed", 0)
	fb.ultimate_triggered = battle_result.get("ultimate_triggered", false)
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
		var pid: String = ConfigManager._PARTNER_ID_MAP.get(str(p.partner_config_id), str(p.partner_config_id))
		var pcfg: Dictionary = ConfigManager.get_partner_config(pid)
		var p_name: String = pcfg.get("name", pid)
		# v2: 伙伴属性从援助配置读取
		var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(pid)
		var pstats: Dictionary = {
			"physique": assist_cfg.get("base_physique", 10),
			"strength": assist_cfg.get("base_strength", 10),
			"agility": assist_cfg.get("base_agility", 10),
			"technique": assist_cfg.get("base_technique", 10),
			"spirit": assist_cfg.get("base_spirit", 10),
		}
		battle_partners.append(PartnerAssist.make_partner_battle_unit(pid, p_name, pstats))

	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)
	var config: Dictionary = {
		"hero": battle_hero,
		"enemies": [enemy],
		"partners": battle_partners,
		"battle_seed": randi(),
		"playback_mode": "standard",
	}
	var result: Dictionary = battle_engine.execute_battle(config)
	battle_engine.queue_free()

	# 同步战斗后的 HP 回写到 RuntimeHero
	_hero.current_hp = battle_hero.get("hp", _hero.current_hp)
	_hero.is_alive = battle_hero.get("is_alive", true)
	# 确保result包含hero_remaining_hp供调用方使用
	result["hero_remaining_hp"] = battle_hero.get("hp", 0)
	
	# 补充 battle_result 字段供 BattleSummaryPanel 使用
	if not result.has("gold_reward"):
		result["gold_reward"] = enemy_cfg.get("reward_gold_min", 20)
	if not result.has("hero_max_hp"):
		result["hero_max_hp"] = _hero.max_hp
	if not result.has("enemies"):
		result["enemies"] = [enemy]
	if not result.has("max_chain_count"):
		var chain_stats = result.get("chain_stats", {})
		result["max_chain_count"] = chain_stats.get("max_chain", 0)
	
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
	## 游戏结束：生成档案数据并传递
	var partners: Array[RuntimePartner] = _character_manager.get_partners()
	
	# --- 生成档案数据 ---
	var final_battle_data: Dictionary = _pending_battle_result if _pending_battle_result != null else {}
	var archive_data: Dictionary = {
		"hero_config_id": _run.hero_config_id,
		"final_turn": _run.current_turn,
		"final_score": _run.total_score,
		"final_grade": "S",
		"attr_snapshot_vit": _hero.current_vit,
		"attr_snapshot_str": _hero.current_str,
		"attr_snapshot_agi": _hero.current_agi,
		"attr_snapshot_tec": _hero.current_tec,
		"attr_snapshot_mnd": _hero.current_mnd,
		"initial_vit": _hero.current_vit,
		"initial_str": _hero.current_str,
		"initial_agi": _hero.current_agi,
		"initial_tec": _hero.current_tec,
		"initial_mnd": _hero.current_mnd,
		"battle_win_count": _run.battle_win_count,
		"elite_win_count": _run.elite_win_count,
		"elite_total_count": _run.elite_total_count,
		"pvp_10th_result": _run.pvp_10th_result,
		"pvp_20th_result": _run.pvp_20th_result,
		"training_count": _hero.total_training_count,
		"shop_visit_count": _run.shop_visit_count,
		"rescue_success_count": _run.rescue_success_count,
		"total_damage_dealt": _run.total_damage_dealt,
		"total_enemies_killed": _run.total_enemies_killed,
		"max_chain_reached": _run.max_chain_reached,
		"total_chain_count": _run.total_chain_count,
		"total_aid_trigger_count": _run.total_aid_trigger_count,
		"ultimate_triggered": _hero.ultimate_used,
		"gold_spent": _run.gold_spent,
		"gold_earned_total": _run.gold_earned_total,
		"partner_count": partners.size(),
		"max_hp_reached": _hero.max_hp,
		"ended_at": Time.get_unix_time_from_system(),
		"final_battle": {
			"result": 1 if final_battle_data.get("winner", "") == "player" else 0,
			"hero_remaining_hp": final_battle_data.get("hero_remaining_hp", 0),
			"hero_max_hp": final_battle_data.get("hero_max_hp", _hero.max_hp),
			"damage_dealt_to_enemy": final_battle_data.get("damage_dealt_to_enemy", 0),
			"enemy_max_hp": final_battle_data.get("enemy_max_hp", 0),
		},
		"partners": _get_partner_dicts(),
	}
	
	# 通过 GameManager 传递档案数据
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.pending_archive = archive_data
		print("[RunController] 档案数据已传给 GameManager")
	else:
		push_error("[RunController] GameManager not found, cannot pass archive")
	
	# 删除所有存档文件，防止已结束的局被"继续游戏"加载
	var dir: DirAccess = DirAccess.open(ConfigManager.SAVE_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if file_name.begins_with("save_") and file_name.ends_with(".json"):
				var save_path: String = ConfigManager.SAVE_DIR + file_name
				DirAccess.remove_absolute(save_path)
				print("[RunController] 已删除存档: %s" % save_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	EventBus.emit_signal("run_ended", _get_ending_type(), _run.total_score, archive_data)


func get_current_shop_items() -> Array[Dictionary]:
	var shop_system = get_node_or_null("ShopSystem")
	if shop_system != null:
		return shop_system.generate_shop_inventory(_run.current_turn, _run.gold_owned)
	return []


func _auto_save() -> void:
	if SaveManager != null and _run != null:
		var data = _run.to_dict()
		data["hero"] = _hero.to_dict() if _hero != null else {}
		data["partners"] = _get_partner_dicts()
		data["gold"] = _run.gold_owned
		SaveManager.save_run_state(data, true)


func confirm_battle_result() -> void:
	if _battle_result_phase == BattleResultPhase.BATTLE_ENDED:
		_battle_result_phase = BattleResultPhase.BATTLE_CONFIRMED
		_finish_node_execution(_pending_battle_result)
		_battle_result_phase = BattleResultPhase.NONE
		_pending_battle_result = {}


func close_shop_panel() -> void:
	if _special_floor_phase == SpecialFloorPhase.SHOP_BROWSE:
		_special_floor_phase = SpecialFloorPhase.COMPLETE
		_finish_node_execution({"success": true, "rewards": []})


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
	if _state == RunState.RUNNING_NODE_EXECUTE:
		var partner_bonus: int = _calculate_partner_bonus_for_attr(attr_type)
		_training_system.execute_training(attr_type, _run.current_turn, partner_bonus)
		_finish_node_execution(_pending_result)


func _finish_node_execution(result: Dictionary) -> void:
	## 统一完成节点执行：记录历史、更新计数器、推进层数
	# 记录节点历史
	_run.node_history.append({
		"turn": _run.current_turn,
		"node_type": _pending_node_type,
		"result": result,
	})

	# 显示日志
	for log in result.get("logs", []):
		EventBus.emit_signal("hud_log_appended", log, "event", int(Time.get_unix_time_from_system()))

	# 更新计数器
	match _pending_node_type:
		2:  # 普通战斗
			_run.battle_win_count += 1
		4:  # 外出事件
			if result.get("event", "") == "shop":
				_run.shop_visit_count += 1
		6:  # 商店（直接选择）
			_run.shop_visit_count += 1
		7:  # PVP
			# PVP结果由 _process_reward 中的 "pvp_result" 分支处理
			pass
	
	# 战斗节点统一计数（含普通战斗、外出精英战）
	if result.get("requires_battle", false):
		_run.battle_win_count += 1
		if result.get("is_elite", false):
			_run.elite_win_count += 1
			_run.elite_total_count += 1

	_node_pool_system.record_selection(_pending_node_type)
	_change_state(RunState.TURN_ADVANCE)
	advance_turn()


func _get_panel_name_from_node_type(node_type: int) -> String:
	match node_type:
		1: return "TRAINING_PANEL"
		4: return "SHOP_PANEL"  # 外出事件的商店
		5: return "RESCUE_PANEL"
		6: return "SHOP_PANEL"
		_: return "UNKNOWN_PANEL"


func _calculate_partner_bonus_for_attr(attr_type: int) -> int:
	## 计算该属性训练时伙伴提供的支援加成
	var bonus: int = 0
	for p in _character_manager.get_partners():
		if p.favored_attr == attr_type and p.is_active:
			bonus += 2  # 基础加成值，Lv3/Lv5时更高
	return bonus


func _hero_to_battle_dict() -> Dictionary:
	## 将 RuntimeHero 转换为 PvpOpponentGenerator 需要的 battle dict 格式
	var hero_id: String = ConfigManager.get_hero_id_by_config_id(_hero.hero_config_id)
	if hero_id.is_empty():
		hero_id = "hero_warrior"
	return {
		"hero_id": hero_id,
		"stats": {
			"physique": _hero.current_vit,
			"strength": _hero.current_str,
			"agility": _hero.current_agi,
			"technique": _hero.current_tec,
			"spirit": _hero.current_mnd,
		},
		"max_hp": _hero.max_hp,
		"hp": _hero.current_hp,
	}
