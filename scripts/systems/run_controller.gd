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
var _last_battle_summary: Dictionary = {}

var _character_manager: CharacterManager = null
var _node_pool_system: NodePoolSystem = null
var _node_resolver: NodeResolver = null
var _settlement_system: SettlementSystem = null
var _training_system: TrainingSystem = null
var _rescue_system: RescueSystem = null
var _boss_pool: FinalBossPool = null

var _current_node_options: Array = []
var _pending_node_type: int = 0
var _pending_result: Dictionary = {}
var _pending_battle_result: Dictionary = {}

var _special_floor_phase: SpecialFloorPhase = SpecialFloorPhase.NONE
var _battle_result_phase: BattleResultPhase = BattleResultPhase.NONE


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

	# 初始化事件透视系统
	var forecast_system := EventForecastSystem.new()
	forecast_system.name = "EventForecastSystem"
	add_child(forecast_system)
	print("[RunController] EventForecastSystem 已初始化")

	_training_system = TrainingSystem.new()
	_training_system.name = "TrainingSystem"
	add_child(_training_system)
	_training_system.initialize(_character_manager)

	var shop_system := ShopSystem.new()
	shop_system.name = "ShopSystem"
	add_child(shop_system)
	shop_system.initialize(_character_manager)

	_rescue_system = RescueSystem.new()
	_rescue_system.name = "RescueSystem"
	add_child(_rescue_system)
	_rescue_system.initialize(_character_manager)

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

	var virtual_archive_pool := VirtualArchivePool.new()
	virtual_archive_pool.name = "VirtualArchivePool"
	add_child(virtual_archive_pool)

	_node_resolver = NodeResolver.new()
	_node_resolver.name = "NodeResolver"
	add_child(_node_resolver)

	_settlement_system = SettlementSystem.new()
	_settlement_system.name = "SettlementSystem"
	add_child(_settlement_system)


func continue_from_save(save_data: Dictionary) -> bool:
	print("[RunController] 恢复存档")
	if save_data.is_empty():
		push_error("[RunController] Cannot continue from empty save data")
		return false
	
	var snapshot = RunSnapshot.from_dict(save_data)
	print("[RunController] 存档解析: floor=%d, hero_id=%d, gold=%d" % [snapshot.current_floor, snapshot.hero_config_id, snapshot.gold])
	
	# 恢复 RuntimeRun（手动逐个字段恢复，更可控）
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
	
	# 恢复事件透视次数
	var forecast_charges: int = save_data.get("event_forecast_charges", 0)
	if forecast_charges > 0:
		var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
		if forecast_system != null:
			forecast_system.set_charges(forecast_charges)
			print("[RunController] 恢复事件透视次数: %d" % forecast_charges)
	
	# 恢复状态
	_state = RunState.RUNNING_NODE_SELECT
	
	# 恢复当前层的选项（如果有）—— 关键：SL后选项不变
	var saved_options: Array = save_data.get("node_options", [])
	if not saved_options.is_empty():
		_current_node_options = saved_options.duplicate(true)
		EventBus.emit_signal("floor_changed", _run.current_turn, _MAX_TURNS, _get_phase_name())
		EventBus.emit_signal("node_options_presented", _current_node_options)
		print("[RunController] 恢复存档选项: %d 个" % _current_node_options.size())
	else:
		# 没有保存的选项，重新生成
		_change_state(RunState.RUNNING_NODE_SELECT)
	
	EventBus.emit_signal("run_started", {
		"hero_id": _run.hero_config_id,
		"partner_ids": [],
		"run_seed": _run.run_seed,
	})
	EventBus.emit_signal("gold_changed", _run.gold_owned, 0, "continue_from_save")
	EventBus.emit_signal("run_continued", _run.current_turn)
	print("[RunController] 存档恢复完成，当前层=%d" % _run.current_turn)
	return true

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
	var shop_system: ShopSystem = get_node_or_null("ShopSystem")
	if shop_system == null:
		push_error("[RunController] ShopSystem not found")
		return {"success": false, "error": "ShopSystem not found"}
	var result = shop_system.process_purchase(item_data, _run.gold_owned)
	if result.get("success", false):
		_run.gold_owned = result.get("new_gold", _run.gold_owned)
		print("[RunController] 购买成功，扣除金币，剩余: %d" % _run.gold_owned)
	return result


func get_current_shop_items() -> Array[Dictionary]:
	var shop_system = get_node_or_null("ShopSystem")
	if shop_system != null:
		return shop_system.generate_shop_inventory(_run.current_turn, _run.gold_owned)
	return []


func select_rescue_partner(partner_config_id: int) -> void:
	print("[RunController] select_rescue_partner 被调用: partner_config_id=%d, turn=%d, phase=%d" % [partner_config_id, _run.current_turn if _run != null else -1, _special_floor_phase])
	var rescued: RuntimePartner = _rescue_system.rescue_partner(partner_config_id, _run.current_turn)
	if rescued != null:
		var pcfg: Dictionary = ConfigManager.get_partner_config(str(partner_config_id))
		EventBus.emit_signal("partner_unlocked", str(partner_config_id), pcfg.get("name", ""), _rescue_system.get_rescue_slot(_run.current_turn), _run.current_turn, pcfg.get("role", ""))
	
	# 如果当前是救援层的救援阶段，进入商店阶段
	if _special_floor_phase == SpecialFloorPhase.RESCUE_SELECT:
		_special_floor_phase = SpecialFloorPhase.SHOP_BROWSE
		print("[RunController] 特殊层阶段: SHOP_BROWSE")
		var shop_system = get_node_or_null("ShopSystem")
		var shop_items = []
		if shop_system != null:
			shop_items = shop_system.generate_shop_inventory(_run.current_turn, _run.gold_owned)
			print("[RunController] 生成商店商品: %d 个" % shop_items.size())
		EventBus.emit_signal("panel_opened", "SHOP_PANEL", {"items": shop_items})
	else:
		# 非救援层的普通救援，直接完成
		EventBus.emit_signal("panel_closed", "RESCUE_PANEL", "completed" if rescued != null else "failed")
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


func get_current_node_options() -> Array:
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
		_save_at_floor_entrance()
		return

	if turn in _PVP_TURNS:
		_current_node_options = [{
			"node_type": NodePoolSystem.NodeType.PVP_CHECK,
			"node_name": "PVP检定",
			"description": "与其他斗士进行对战检定",
			"node_id": "pvp_%d" % turn,
		}]
		EventBus.emit_signal("node_options_presented", _current_node_options)
		_save_at_floor_entrance()
		return

	if turn == _FINAL_TURN:
		_current_node_options = [{
			"node_type": NodePoolSystem.NodeType.FINAL_BOSS,
			"node_name": "终局战",
			"description": "最终决战",
			"node_id": "final_%d" % turn,
		}]
		EventBus.emit_signal("node_options_presented", _current_node_options)
		_save_at_floor_entrance()
		return

	# 普通回合：从节点池生成3个选项
	_current_node_options = _node_pool_system.generate_options(turn)
	
	# 为战斗节点预生成敌人配置，供UI层预览使用
	for opt in _current_node_options:
		if opt.get("node_type", 0) == NodePoolSystem.NodeType.BATTLE:
			var enemy_cfg: Dictionary = _node_resolver.generate_enemy_for_floor(turn)
			opt["enemy_config"] = enemy_cfg
	
	# 缓存外出事件到事件透视系统
	var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
	if forecast_system != null:
		forecast_system.cache_outgoing_events(_current_node_options)
	
	print("[RunController] 发射 node_options_presented: options=%d" % _current_node_options.size())
	EventBus.emit_signal("node_options_presented", _current_node_options)
	_save_at_floor_entrance()


func _process_node_result(result: Dictionary) -> void:
	_pending_result = result
	if not result.get("success", true):
		# 节点执行失败（如精英战败北）
		if _hero != null and not _hero.is_alive:
			_run.run_status = 3  # LOSE
			_end_run()
			return

	# 处理需要UI选择的节点，发射 panel_opened 并暂停状态推进
	if result.get("requires_ui_selection", false):
		EventBus.emit_signal("panel_opened", _get_panel_name_from_node_type(_pending_node_type), result)
		return  # 等待用户交互完成后再推进

	# 处理战斗节点
	if result.get("requires_battle", false):
		var enemy_config_id: int = result.get("enemy_config_id", 2001)
		_battle_result_phase = BattleResultPhase.BATTLE_RUNNING
		
		var battle_result: Dictionary = result.get("battle_result", {})
		if battle_result.is_empty() and result.has("winner"):
			battle_result = result
		# 若 battle_result 仍为空（普通战斗未执行 BattleEngine），补执行
		if battle_result.is_empty():
			battle_result = _run_battle_engine(enemy_config_id)
			result["battle_result"] = battle_result
		
		# 同步战斗后主角HP
		_hero.current_hp = battle_result.get("hero_remaining_hp", _hero.current_hp)
		_hero.is_alive = battle_result.get("winner", "") == "player"
		if not _hero.is_alive:
			_run.run_status = 3  # LOSE
		
		# 战斗胜利奖励金币（从敌人配置读取）
		if _hero.is_alive:
			var enemy_cfg2: Dictionary = ConfigManager.get_enemy_config(str(enemy_config_id))
			var gold_reward: int = enemy_cfg2.get("reward_gold_min", 20)
			if enemy_cfg2.has("reward_gold_max"):
				var gold_max: int = enemy_cfg2.get("reward_gold_max", gold_reward)
				if gold_max > gold_reward:
					gold_reward = randi() % (gold_max - gold_reward + 1) + gold_reward
			_process_reward({"type": "gold", "amount": gold_reward})
		
		# 构造 battle summary 供 UI 回放
		var hero_name: String = "英雄"
		if _hero != null:
			var hero_cfg: Dictionary = ConfigManager.get_hero_config(ConfigManager.get_hero_id_by_config_id(_hero.hero_config_id))
			hero_name = hero_cfg.get("name", "英雄")
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
		
		_battle_result_phase = BattleResultPhase.BATTLE_ENDED
		_pending_battle_result = battle_result
		EventBus.emit_signal("battle_ended", battle_result)
		return

	# PVP检定节点
	if _pending_node_type == NodePoolSystem.NodeType.PVP_CHECK:
		var pvp_director: PvpDirector = get_node_or_null("PvpDirector")
		if pvp_director != null:
			var pvp_config: Dictionary = {
				"turn_number": _run.current_turn,
				"player_gold": _run.gold_owned,
				"player_hp": _hero.current_hp,
				"player_hero": _hero_to_battle_dict(),
				"run_seed": _run.run_seed,
				"use_archive": true,
			}
			var pvp_result: Dictionary = pvp_director.execute_pvp(pvp_config)
			var pvp_reward: Dictionary = {"type": "pvp_result", "data": pvp_result}
			_process_reward(pvp_reward)
			_battle_result_phase = BattleResultPhase.BATTLE_ENDED
			_pending_battle_result = pvp_result
			EventBus.emit_signal("battle_ended", pvp_result)
			return
		_finish_node_execution(result)
		return

	# 处理普通奖励
	for reward in result.get("rewards", []):
		_process_reward(reward)
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
		"hp_heal":
			var amount: int = reward.get("amount", 0)
			if _hero != null and amount > 0:
				var old_hp: int = _hero.current_hp
				_hero.current_hp = mini(_hero.max_hp, _hero.current_hp + amount)
				EventBus.emit_signal("stats_changed", _hero.id, {
					0: {"old": old_hp, "new": _hero.current_hp, "delta": _hero.current_hp - old_hp, "attr_code": 0}
				})
		"hp_damage":
			var amount: int = reward.get("amount", 0)
			if _hero != null and amount > 0:
				var old_hp: int = _hero.current_hp
				_hero.current_hp = maxi(0, _hero.current_hp - amount)
				if _hero.current_hp <= 0:
					_hero.current_hp = 10
				_hero.is_alive = _hero.current_hp > 0
				EventBus.emit_signal("stats_changed", _hero.id, {
					0: {"old": old_hp, "new": _hero.current_hp, "delta": old_hp - _hero.current_hp, "attr_code": 0}
				})
		"level_up":
			var partners: Array = _character_manager.get_partners()
			if partners.size() > 0:
				var random_partner = partners[randi() % partners.size()]
				_character_manager.upgrade_partner(random_partner.partner_config_id)
		"train_lv5":
			var attr_type: int = reward.get("attr", -1)
			if attr_type > 0 and _training_system != null:
				_training_system.execute_training(attr_type, _run.current_turn)


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
		var p_level: int = p.current_level
		var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(str(p.partner_config_id))
		var base_stats: Dictionary = {
			"physique": assist_cfg.get("base_physique", 10),
			"strength": assist_cfg.get("base_strength", 10),
			"agility": assist_cfg.get("base_agility", 10),
			"technique": assist_cfg.get("base_technique", 10),
			"spirit": assist_cfg.get("base_spirit", 10),
		}
		var level_multiplier: float = 1.0 + (p_level - 1) * 0.2
		for key in base_stats.keys():
			base_stats[key] = int(base_stats[key] * level_multiplier)
		var pid: String = ConfigManager._PARTNER_ID_MAP.get(str(p.partner_config_id), str(p.partner_config_id))
		var pcfg: Dictionary = ConfigManager.get_partner_config(pid)
		var p_name: String = pcfg.get("name", pid)
		battle_partners.append(PartnerAssist.make_partner_battle_unit(pid, p_name, base_stats))

	var recorder: BattlePlaybackRecorder = BattlePlaybackRecorder.new()
	recorder.start_recording()
	add_child(recorder)
	
	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)
	var config: Dictionary = {
		"hero": battle_hero,
		"enemies": [enemy],
		"partners": battle_partners,
		"battle_seed": randi(),
		"playback_mode": "fast_forward",
		"playback_recorder": recorder,
	}
	var result: Dictionary = battle_engine.execute_battle(config)
	battle_engine.queue_free()
	
	recorder.stop_recording()
	result["playback_recorder"] = recorder

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
	
	# 检查是否解锁新英雄
	_check_hero_unlocks()
	
	EventBus.emit_signal("run_ended", _get_ending_type(), _run.total_score, archive_dict)
	EventBus.emit_signal("archive_generated", archive_dict)
	_change_state(RunState.SETTLEMENT)


func _end_run() -> void:
	# 检查是否解锁新英雄
	_check_hero_unlocks()
	# 清理或返回主菜单
	EventBus.emit_signal("run_ended", _get_ending_type(), _run.total_score, {})


func _check_hero_unlocks() -> void:
	if _run == null or _hero == null:
		return
	var current_hero_id: String = ConfigManager.get_hero_id_by_config_id(_hero.hero_config_id)
	if current_hero_id.is_empty():
		return
	var is_cleared: bool = (_run.run_status == 2) or (_run.current_turn >= _MAX_TURNS)
	if not is_cleared:
		return
	
	var all_configs: Dictionary = ConfigManager.get_all_hero_configs()
	for hero_id in all_configs.keys():
		var cfg: Dictionary = all_configs[hero_id]
		var condition: String = cfg.get("unlock_condition", "")
		if condition.is_empty() or condition == "none":
			continue
		match condition:
			"clear_with_hero_warrior":
				if current_hero_id == "hero_warrior":
					SaveManager.unlock_hero(hero_id)
			"clear_with_hero_shadow_dancer":
				if current_hero_id == "hero_shadow_dancer":
					SaveManager.unlock_hero(hero_id)


func _save_at_floor_entrance() -> void:
	## 层入口存档：包含当前层的选项（种子模式，确保SL后选项不变）
	if SaveManager != null and _run != null:
		var data = _run.to_dict()
		data["hero"] = _hero.to_dict() if _hero != null else {}
		data["partners"] = _get_partner_dicts()
		data["gold"] = _run.gold_owned
		data["node_options"] = _current_node_options.duplicate(true)
		
		# 额外跨局字段
		var player_data = SaveManager.load_player_data()
		data["pvp_net_wins"] = player_data.get("net_wins", 0)
		data["mocheng_coin"] = player_data.get("mocheng_coin", 0)
		var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
		if forecast_system != null:
			data["event_forecast_charges"] = forecast_system.get_charges()
		
		SaveManager.save_run_state(data, true)
		print("[RunController] 层入口存档: 第%d层, 选项数=%d" % [_run.current_turn, _current_node_options.size()])


func _auto_save() -> void:
	## 保留旧接口兼容，统一调用层入口存档
	_save_at_floor_entrance()


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


func _finish_node_execution(result: Dictionary) -> void:
	## 统一完成节点执行：记录历史、更新计数器、推进层数
	# 记录节点历史
	_run.node_history.append({
		"turn": _run.current_turn,
		"node_type": _pending_node_type,
		"result": result,
	})

	# 显示日志
	for _log in result.get("logs", []):
		EventBus.emit_signal("hud_log_appended", _log, "event", int(Time.get_unix_time_from_system()))

	# 更新计数器
	match _pending_node_type:
		NodePoolSystem.NodeType.BATTLE:
			_run.battle_win_count += 1
		NodePoolSystem.NodeType.SHOP:
			_run.shop_visit_count += 1
		NodePoolSystem.NodeType.PVP_CHECK:
			# PVP结果由 _process_reward 中的 "pvp_result" 分支处理
			pass

	# 战斗节点统一计数（含普通战斗、外出精英战）
	if result.get("requires_battle", false):
		_run.battle_win_count += 1
		if result.get("is_elite", false):
			_run.elite_win_count += 1
			_run.elite_total_count += 1

	# 战斗节点完成后保存影子到虚拟档案池（用于异步PVP镜像）
	if result.get("requires_battle", false):
		_save_shadow_to_pool()

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


## 保存影子到虚拟档案池（PVP异步镜像）
func _save_shadow_to_pool() -> void:
	if _character_manager == null:
		return
	var pool: VirtualArchivePool = get_node_or_null("VirtualArchivePool")
	if pool == null:
		return

	var shadow := ShadowData.new()
	shadow.user_id = SaveManager.get_user_id()
	shadow.floor = _run.current_floor
	shadow.hero_config = _character_manager.get_hero_snapshot()
	shadow.partner_configs = _character_manager.get_partners_snapshot()
	shadow.combat_style_tags = _derive_combat_style()
	shadow.win_rate = _calculate_recent_win_rate()
	shadow.timestamp = Time.get_unix_time_from_system()

	pool.add_shadow(shadow)
	pool.save_shadows_to_disk()
	print("[RunController] 影子已保存: user=%s, floor=%d" % [shadow.user_id, shadow.floor])

func _derive_combat_style() -> Array[String]:
	var tags: Array[String] = []
	if _hero == null:
		return tags
	if _hero.current_str > _hero.current_vit:
		tags.append("aggressive")
	elif _hero.current_vit > _hero.current_str:
		tags.append("defensive")
	else:
		tags.append("balanced")
	return tags

func _calculate_recent_win_rate() -> float:
	var total_battles: int = _run.battle_win_count + maxi(0, _run.current_turn - _run.battle_win_count)
	if total_battles <= 0:
		return 0.5
	return float(_run.battle_win_count) / float(total_battles)


func confirm_battle_result() -> void:
	print("[RunController] confirm_battle_result 被调用, phase=%d" % _battle_result_phase)
	if _battle_result_phase == BattleResultPhase.BATTLE_ENDED:
		_battle_result_phase = BattleResultPhase.BATTLE_CONFIRMED
		if not _hero.is_alive:
			_end_run()
		else:
			_finish_node_execution(_pending_battle_result)
		_battle_result_phase = BattleResultPhase.NONE
		_pending_battle_result = {}
		print("[RunController] confirm_battle_result 完成, 状态已重置")
	else:
		print("[RunController] confirm_battle_result 跳过, phase 不是 BATTLE_ENDED")

func close_shop_panel() -> void:
	## 商店面板关闭后推进回合
	if _special_floor_phase == SpecialFloorPhase.SHOP_BROWSE:
		_special_floor_phase = SpecialFloorPhase.COMPLETE
		EventBus.emit_signal("panel_closed", "SHOP_PANEL", "closed")
		_finish_node_execution({"success": true, "rewards": []})
	else:
		EventBus.emit_signal("panel_closed", "SHOP_PANEL", "closed")
		_finish_node_execution(_pending_result)

func select_training_attr(attr_type: int) -> void:
	## 玩家从训练面板选择了具体属性
	if _state == RunState.RUNNING_NODE_EXECUTE:
		var partner_bonus: int = _calculate_partner_bonus_for_attr(attr_type)
		_training_system.execute_training(attr_type, _run.current_turn, partner_bonus)
		_finish_node_execution(_pending_result)
