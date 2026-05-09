## res://scripts/systems/node_resolver.gd
## 模块: NodeResolver
## 职责: 节点分发：根据node_type分发到子系统，执行完毕后返回NodeResult
## 依赖: TrainingSystem, ShopSystem, RescueSystem, EliteBattleSystem, PvpDirector, CharacterManager, EventBus
## class_name: NodeResolver

class_name NodeResolver
extends Node

var _training_system: TrainingSystem = null
var _shop_system: ShopSystem = null
var _rescue_system: RescueSystem = null
var _elite_battle_system: EliteBattleSystem = null
var _pvp_director: PvpDirector = null
var _character_manager: CharacterManager = null


func initialize(ts: TrainingSystem, ss: ShopSystem, rs: RescueSystem, ebs: EliteBattleSystem, pd: PvpDirector = null, cm: CharacterManager = null) -> void:
	_training_system = ts
	_shop_system = ss
	_rescue_system = rs
	_elite_battle_system = ebs
	_pvp_director = pd
	_character_manager = cm


func resolve_node(node_type: int, node_config: Dictionary, run: RuntimeRun, hero: RuntimeHero) -> Dictionary:
	EventBus.emit_signal("node_entered", _node_type_name(node_type), node_config)

	var result := {
		"success": true,
		"rewards": [],
		"combat_result": null,
		"logs": [],
	}

	match node_type:
		1:  # TRAINING
			var attr_type: int = node_config.get("attr_type", 1)
			var train_result: Dictionary = _training_system.execute_training(attr_type, run.current_turn)
			result["rewards"].append({"type": "attr_up", "data": train_result})
			result["logs"].append("第%d回合：锻炼%s，+%d" % [run.current_turn, train_result.get("attr_name", ""), train_result.get("gain_value", 0)])

		2, 3:  # BATTLE / ELITE
			if node_type == 3:
				var enemy_id: int = node_config.get("enemy_config_id", 2001)
				var battle_result: Dictionary = _elite_battle_system.execute_elite_battle(run, hero, enemy_id)
				result["combat_result"] = battle_result
				result["success"] = battle_result.get("success", false)
				if battle_result.get("success", false):
					result["rewards"].append({"type": "gold", "amount": battle_result.get("reward_gold", 0)})
					result["rewards"].append({"type": "elite_reward_choice", "options": _elite_battle_system.generate_elite_rewards(1)})
					result["logs"].append("第%d回合：精英战胜利" % run.current_turn)
				else:
					result["logs"].append("第%d回合：精英战失败，本局结束" % run.current_turn)
			else:
				# 普通战斗简化处理
				var gold_reward: int = 10 + run.current_turn
				result["rewards"].append({"type": "gold", "amount": gold_reward})
				result["logs"].append("第%d回合：普通战斗胜利，获得%d金币" % [run.current_turn, gold_reward])

		4:  # SHOP
			# 商店节点返回商店信息，实际购买由UI层触发shop_purchase_requested后再调用process_purchase
			var inventory: Array[Dictionary] = _shop_system.generate_shop_inventory(run.current_turn, run.gold_owned)
			result["rewards"].append({"type": "shop_inventory", "inventory": inventory})
			result["logs"].append("第%d回合：进入商店" % run.current_turn)

		5:  # RESCUE
			var candidates: Array[Dictionary] = _rescue_system.generate_candidates()
			result["rewards"].append({"type": "rescue_candidates", "candidates": candidates})
			result["logs"].append("第%d回合：触发救援事件" % run.current_turn)

		6:  # PVP_CHECK
			if _pvp_director != null and _character_manager != null:
				var team: Dictionary = _character_manager.get_battle_ready_team()
				var pvp_config: Dictionary = {
					"turn_number": run.current_turn,
					"player_hero": team.hero,
					"player_partners": team.partners,
					"player_gold": run.gold_owned,
					"player_hp": hero.current_hp,
					"player_max_hp": hero.max_hp,
					"run_seed": run.seed,
				}
				var pvp_result: Dictionary = _pvp_director.execute_pvp(pvp_config)
				result["rewards"].append({"type": "pvp_result", "data": pvp_result})
				result["success"] = true
				if pvp_result.won:
					result["logs"].append("第%d回合：PVP检定胜利" % run.current_turn)
				else:
					result["logs"].append("第%d回合：PVP检定失败，受到%s惩罚" % [run.current_turn, pvp_result.penalty_tier])
			else:
				# 降级为占位逻辑
				result["rewards"].append({"type": "pvp_result", "won": true, "opponent_name": "AI_OPPONENT", "rating_change": 0, "penalty_tier": "none"})
				result["logs"].append("第%d回合：PVP检定通过（占位）" % run.current_turn)

		7:  # FINAL
			result["logs"].append("第%d回合：进入终局战" % run.current_turn)

		_:
			push_warning("[NodeResolver] Unknown node type: %d" % node_type)
			result["success"] = false
			result["logs"].append("第%d回合：未知节点类型" % run.current_turn)

	EventBus.emit_signal("node_resolved", _node_type_name(node_type), result)
	return result


func process_shop_purchase(item_data: Dictionary, run: RuntimeRun) -> Dictionary:
	var purchase_result: Dictionary = _shop_system.process_purchase(item_data, run.gold_owned)
	if purchase_result.get("success", false):
		run.gold_owned = purchase_result.get("new_gold", run.gold_owned)
		run.gold_spent += item_data.get("price", 0)
		EventBus.emit_signal("gold_changed", run.gold_owned, -item_data.get("price", 0), "shop_purchase")
		EventBus.emit_signal("shop_item_purchased", item_data.get("item_id", ""), item_data.get("item_type", ""), item_data.get("target_id", ""), item_data.get("price", 0), run.gold_owned, 0)
	return purchase_result


func process_rescue_selection(partner_config_id: int, turn: int, run: RuntimeRun) -> RuntimePartner:
	var partner: RuntimePartner = _rescue_system.rescue_partner(partner_config_id, turn)
	if partner != null:
		run.rescue_success_count += 1
		EventBus.emit_signal("rescue_encountered", [], turn)
	return partner


# --- 私有方法 ---

func _node_type_name(node_type: int) -> String:
	match node_type:
		1: return "TRAIN"
		2: return "BATTLE"
		3: return "ELITE"
		4: return "SHOP"
		5: return "RESCUE"
		6: return "PVP"
		7: return "FINAL"
		_: return "UNKNOWN"
