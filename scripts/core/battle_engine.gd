## res://scripts/core/battle_engine.gd
## 模块: BattleEngine
## 职责: 战斗主控，状态机驱动完整20回合自动战斗
## 依赖: ActionOrder, DamageCalculator, SkillManager, UltimateManager, PartnerAssist, ChainTrigger, EnemyAI, BattleResult
## 被依赖: NodeResolver, BattleUI
## class_name: BattleEngine

class_name BattleEngine
extends Node

enum BattleState {
	INIT,
	ROUND_START,
	ACTION_ORDER,
	HERO_ACTION,
	ENEMY_ACTION,
	HERO_COUNTER,
	PARTNER_ASSIST,
	CHAIN_CHECK,
	CHAIN_RESOLVE,
	STATUS_TICK,
	ULTIMATE_CHECK,
	ROUND_END,
	BATTLE_END,
}

var _state: BattleState = BattleState.INIT
var _hero: Dictionary = {}
var _enemies: Array = []
var _partners: Array = []
var _battle_seed: int = 0
var _rng: RandomNumberGenerator
var _dc: DamageCalculator
var _action_order: ActionOrder
var _attr_provider: IAttributeProvider = DefaultAttributeProvider.new()
var _skill_mgr: SkillManager
var _ultimate_mgr: UltimateManager
var _partner_assist: PartnerAssist
var _chain_trigger: ChainTrigger
var _enemy_ai: EnemyAI
var _result: BattleResult

var _turn_number: int = 0
var _turn_chain_count: int = 0
var _action_sequence: Array = []
var _current_action_index: int = 0
var _battle_config: Dictionary = {}

func execute_battle(battle_config: Dictionary) -> Dictionary:
	_battle_config = battle_config
	_hero = battle_config.hero
	_enemies = battle_config.enemies.duplicate()
	_partners = battle_config.get("partners", []).duplicate()
	_battle_seed = battle_config.get("battle_seed", hash(str(randi())))

	_rng = RandomNumberGenerator.new()
	_rng.seed = _battle_seed
	_dc = DamageCalculator.new(_battle_seed)
	_action_order = ActionOrder.new(_rng, _attr_provider)
	_skill_mgr = SkillManager.new(_dc, _rng)
	_ultimate_mgr = UltimateManager.new(_dc, _rng)
	_partner_assist = PartnerAssist.new(_dc, _rng)
	_chain_trigger = ChainTrigger.new(_dc, _rng)
	_enemy_ai = EnemyAI.new(_dc, _rng)
	_result = BattleResult.new()

	_state = BattleState.INIT
	_turn_number = 0

	# v2: 初始化敌人的 spawn_turn 和 base_stats（供混沌领主/元素法师计算使用）
	for enemy in _enemies:
		if not enemy.has("spawn_turn"):
			enemy["spawn_turn"] = _turn_number
		if not enemy.has("base_stats"):
			enemy["base_stats"] = enemy.get("stats", {}).duplicate()

	# 初始化伙伴的 assist_count / chain_count
	for p in _partners:
		p.assist_count = 0
		p.chain_count = 0

	EventBus.battle_started.emit([_hero], _enemies, battle_config)
	_result.add_log("战斗开始！")

	# 状态机主循环
	# NOTE: 当前为同步执行模式（单帧内完成），适用于 headless 测试与后端推演。
	# 未来如需 UI 帧同步回放，可在此恢复 await get_tree().process_frame。
	var step: int = 0
	while _state != BattleState.BATTLE_END:
		step += 1
		if step > 5000:
			push_error("BattleEngine: 战斗步数超过5000，强制结束")
			break
		_process_state()

		# 每步状态处理后检查胜负
		if _state == BattleState.ROUND_START or _state == BattleState.STATUS_TICK or _state == BattleState.ROUND_END:
			if _check_battle_end():
				_state = BattleState.BATTLE_END
				break

	_result.turns_elapsed = _turn_number
	_result.ultimate_triggered = _hero.get("ultimate_used", false)
	var final_result: Dictionary = _result.finalize(_hero, _enemies, _partners)
	# NOTE: battle_ended 信号由调用方（RunController）统一发射，避免重复触发
	return final_result


func get_combat_log() -> Array[String]:
	return _result.to_dict().combat_log.duplicate()


func _process_state() -> void:
	var old_state: BattleState = _state
	match _state:
		BattleState.INIT:
			_state = BattleState.ROUND_START

		BattleState.ROUND_START:
			_turn_number += 1
			_turn_chain_count = 0
			_current_action_index = 0
			if _turn_number > 20:
				_state = BattleState.BATTLE_END
				return
			EventBus.battle_turn_started.emit(_turn_number, [], _battle_config.get("playback_mode", "standard"))
			_result.add_log("=== 回合 %d ===" % _turn_number)
			# Buff回合减1（通用化）
			var buff_list: Array = _hero.get("buff_list", [])
			for i in range(buff_list.size() - 1, -1, -1):
				var buff = buff_list[i]
				buff.duration -= 1
				if buff.duration <= 0:
					buff_list.remove_at(i)
					if buff.get("buff_id", "") == "iron_guard_ultimate":
						_result.add_log("不动如山效果结束")
			_hero.buff_list = buff_list
			_state = BattleState.ACTION_ORDER

		BattleState.ACTION_ORDER:
			_action_sequence = _action_order.calculate_order(_hero, _enemies)
			var seq_info: Array = _action_sequence.map(func(e): return {"unit_id": e.unit.get("unit_id", ""), "name": e.unit.get("name", ""), "speed": e.effective_speed})
			EventBus.action_order_calculated.emit(seq_info)
			_current_action_index = 0
			_state = _next_action_state()

		BattleState.HERO_ACTION:
			var target = _get_front_enemy()
			if target == null:
				_state = BattleState.ROUND_END
				return
			EventBus.unit_turn_started.emit(_hero.unit_id, _hero.name, true, "HERO")
			var packets: Array = _skill_mgr.execute_hero_normal_attack(_hero, target)
			var was_crit: bool = false
			var was_hit: bool = false
			for pkt in packets:
				_emit_damage_signals(_hero, target, pkt, "HERO_ACTION")
				_dc.apply_damage_packet(target, pkt)
				if pkt.is_crit:
					was_crit = true
				if not pkt.is_miss:
					was_hit = true
			_result.total_damage_dealt += packets[0].value if not packets[0].is_miss else 0
			# 伙伴援助上下文
			var assist_ctx: Dictionary = {
				"hero": _hero, "enemies": _enemies, "partners": _partners,
				"last_action_was_crit": was_crit, "last_action_was_hit": was_hit,
				"hero_was_hit": false, "turn_number": _turn_number,
				"hero_attacked": true,
			}
			_state = BattleState.PARTNER_ASSIST
			_process_partner_assist(assist_ctx)
			_state = BattleState.CHAIN_CHECK
			_process_chain_check()
			_current_action_index += 1
			_state = _next_action_state()

		BattleState.ENEMY_ACTION:
			var entry = _action_sequence[_current_action_index]
			var enemy: Dictionary = entry.unit
			if not enemy.get("is_alive", false):
				_current_action_index += 1
				_state = _next_action_state()
				return
			EventBus.unit_turn_started.emit(enemy.unit_id, enemy.name, false, "ENEMY")
			var e_packets: Array = _enemy_ai.execute_enemy_turn(enemy, _hero, _turn_number)
			var received_dmg: int = 0
			var hero_was_hit: bool = false
			for pkt in e_packets:
				if pkt.get("is_stunned", false):
					_result.add_log(pkt.log)
					continue
				_emit_damage_signals(enemy, _hero, pkt, "ENEMY_ACTION")
				if not pkt.is_miss:
					received_dmg += pkt.value
					hero_was_hit = true
			_result.total_damage_taken += received_dmg
			# 反击检查（通用化）
			if hero_was_hit:
				var counter_pkt: Dictionary = _skill_mgr.check_iron_counter(_hero, enemy, received_dmg)
				if not counter_pkt.is_empty():
					_dc.apply_damage_packet(enemy, counter_pkt)
					_emit_damage_signals(_hero, enemy, counter_pkt, "HERO_COUNTER")
					_result.add_log("铁卫触发铁壁反击！反弹 %d 伤害" % counter_pkt.value)
					# 反击后连锁检查
					var assist_ctx2: Dictionary = {
						"hero": _hero, "enemies": _enemies, "partners": _partners,
						"last_action_was_crit": false, "last_action_was_hit": true,
						"hero_was_hit": true, "turn_number": _turn_number,
						"hero_attacked": false,
					}
					_process_partner_assist(assist_ctx2)
					_process_chain_check()
			_current_action_index += 1
			_state = _next_action_state()

		BattleState.PARTNER_ASSIST:
			# 此状态在 HERO_ACTION/HERO_COUNTER 内联处理
			_state = BattleState.CHAIN_CHECK

		BattleState.CHAIN_CHECK:
			# 此状态在 HERO_ACTION/HERO_COUNTER 内联处理
			_state = BattleState.STATUS_TICK

		BattleState.CHAIN_RESOLVE:
			# 此状态在内联处理
			_state = BattleState.STATUS_TICK

		BattleState.STATUS_TICK:
			# Buff/DOT/HOT 结算（简化）
			for e in _enemies:
				for i in range(e.buffs.size() - 1, -1, -1):
					var buff = e.buffs[i]
					buff.duration -= 1
					if buff.duration <= 0:
						e.buffs.remove_at(i)
			EventBus.status_ticked.emit(_hero.unit_id, "HOT", 0, 0)
			_state = BattleState.ULTIMATE_CHECK

		BattleState.ULTIMATE_CHECK:
			var ult_result: Dictionary = _ultimate_mgr.check_and_trigger(_hero, _enemies, _turn_number)
			if ult_result.triggered:
				_result.add_log(ult_result.log)
				EventBus.ultimate_triggered.emit(_hero.hero_id, _hero.name, _turn_number, "", ult_result.log)
				for pkt in ult_result.packets:
					var target = _get_front_enemy()
					if target:
						_emit_damage_signals(_hero, target, pkt, "ULTIMATE")
				EventBus.ultimate_executed.emit(_hero.hero_id, ult_result.log, [])
			# 必杀技击杀后检查战斗是否结束
			if _check_battle_end():
				_state = BattleState.BATTLE_END
			else:
				_state = BattleState.ROUND_END

		BattleState.ROUND_END:
			EventBus.battle_turn_ended.emit(_turn_number, _turn_chain_count, _result.chain_stats.total_chains)
			if _turn_number >= 20:
				_state = BattleState.BATTLE_END
			else:
				_state = BattleState.ROUND_START

		BattleState.BATTLE_END:
			pass

	if old_state != _state:
		EventBus.battle_state_changed.emit(_state_name(_state), _state_name(old_state))

func _next_action_state() -> BattleState:
	while _current_action_index < _action_sequence.size():
		var entry = _action_sequence[_current_action_index]
		if not entry.unit.get("is_alive", false):
			_current_action_index += 1
			continue
		if entry.unit_type == "HERO":
			return BattleState.HERO_ACTION
		else:
			return BattleState.ENEMY_ACTION
	return BattleState.STATUS_TICK

func _process_partner_assist(ctx: Dictionary) -> void:
	var assists: Array = _partner_assist.execute_assist(ctx)
	for a in assists:
		_result.record_partner_assist(a.partner_id)
		EventBus.partner_assist_triggered.emit(a.partner_id, a.partner_name, "AFTER_HERO_ATTACK", a, 0)
		_result.add_log(a.log)

func _process_chain_check() -> void:
	while true:
		var chain_result: Dictionary = _chain_trigger.try_trigger_chain(_hero, _enemies, _partners, _turn_chain_count)
		if not chain_result.triggered:
			break
		_turn_chain_count = chain_result.chain_count
		_result.record_chain(_turn_chain_count)
		var pkt: Dictionary = chain_result.packet
		var target = _get_front_enemy()
		if target:
			_emit_damage_signals(_get_partner_unit(chain_result.partner_id), target, pkt, "CHAIN")
		EventBus.chain_triggered.emit(_turn_chain_count, chain_result.partner_id, chain_result.partner_name, pkt.value, 1.0, _result.chain_stats.total_chains)
		_result.add_log("CHAIN x%d! %s 造成 %d 伤害" % [_turn_chain_count, chain_result.partner_name, pkt.value])
	if _turn_chain_count > 0:
		EventBus.chain_ended.emit(_turn_chain_count, _result.chain_stats.total_chains, "resolved")

func _get_front_enemy() -> Dictionary:
	for e in _enemies:
		if e.get("is_alive", false):
			return e
	return {}

func _get_partner_unit(partner_id: String) -> Dictionary:
	for p in _partners:
		if p.get("partner_id", "") == partner_id:
			return p
	return {}

func _check_battle_end() -> bool:
	var hero_alive: bool = _hero.get("is_alive", false)
	var any_enemy_alive: bool = false
	for e in _enemies:
		if e.get("is_alive", false):
			any_enemy_alive = true
			break
	if not hero_alive or not any_enemy_alive or _turn_number >= 20:
		_result.determine_winner(_hero, _enemies, _turn_number, 20)
		return true
	return false

func _emit_damage_signals(attacker: Dictionary, defender: Dictionary, pkt: Dictionary, action_type: String) -> void:
	if pkt.get("is_stunned", false):
		return
	EventBus.action_executed.emit({
		"actor_id": attacker.get("unit_id", ""),
		"actor_name": attacker.get("name", ""),
		"action_type": action_type,
		"skill_id": "",
		"target_id": defender.get("unit_id", ""),
		"target_name": defender.get("name", ""),
		"result_summary": pkt,
		"damage_type": pkt.get("damage_type", "NORMAL"),
	})
	var def_id: String = defender.get("unit_id", "")
	var def_hp: int = defender.get("hp", 0)
	var def_max_hp: int = defender.get("max_hp", 0)
	var atk_id: String = attacker.get("unit_id", "")
	var dmg_type: String = pkt.get("damage_type", "NORMAL")
	if pkt.get("is_miss", false):
		EventBus.unit_damaged.emit(def_id, 0, def_hp, def_max_hp, dmg_type, false, true, atk_id)
	else:
		EventBus.unit_damaged.emit(def_id, pkt.get("value", 0), def_hp, def_max_hp, dmg_type, pkt.get("is_crit", false), false, atk_id)
		if not defender.get("is_alive", false):
			EventBus.unit_died.emit(def_id, defender.get("name", ""), defender.get("unit_type", ""), atk_id)

func _state_name(s: BattleState) -> String:
	match s:
		BattleState.INIT: return "INIT"
		BattleState.ROUND_START: return "ROUND_START"
		BattleState.ACTION_ORDER: return "ACTION_ORDER"
		BattleState.HERO_ACTION: return "HERO_ACTION"
		BattleState.ENEMY_ACTION: return "ENEMY_ACTION"
		BattleState.HERO_COUNTER: return "HERO_COUNTER"
		BattleState.PARTNER_ASSIST: return "PARTNER_ASSIST"
		BattleState.CHAIN_CHECK: return "CHAIN_CHECK"
		BattleState.CHAIN_RESOLVE: return "CHAIN_RESOLVE"
		BattleState.STATUS_TICK: return "STATUS_TICK"
		BattleState.ULTIMATE_CHECK: return "ULTIMATE_CHECK"
		BattleState.ROUND_END: return "ROUND_END"
		BattleState.BATTLE_END: return "BATTLE_END"
		_: return "UNKNOWN"
