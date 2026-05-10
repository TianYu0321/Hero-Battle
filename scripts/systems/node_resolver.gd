class_name NodeResolver
extends Node

## NodeResolver — 节点解析器
## v2.0: 职责单一，只负责根据节点类型生成解析结果，不依赖任何上层模块
## 所有需要的数据通过 context Dictionary 传入，实现与 RunController 的解耦

signal node_resolved(node_type: int, result_data: Dictionary)

## v2.0 外出事件池：3大类 4:3:3 比例
const _OUTING_EVENTS: Array[Dictionary] = [
	## 奖励类 40%
	{"event": "gold_bonus",       "weight": 10, "category": "reward", "desc": "大量金币"},
	{"event": "random_level_up",  "weight": 10, "category": "reward", "desc": "随机角色等级+1"},
	{"event": "full_heal",        "weight": 10, "category": "reward", "desc": "生命完全恢复"},
	{"event": "lv5_training",     "weight": 10, "category": "reward", "desc": "LV5训练机会"},
	## 惩罚类 30%
	{"event": "trap",             "weight": 7.5, "category": "penalty", "desc": "遭遇陷阱"},
	{"event": "weakness",         "weight": 7.5, "category": "penalty", "desc": "训练效果减半(3层)"},
	{"event": "thief",            "weight": 7.5, "category": "penalty", "desc": "偷走20%金币"},
	{"event": "weaken_potion",    "weight": 7.5, "category": "penalty", "desc": "受到伤害+20%(3层)"},
	## 精英类 30%
	{"event": "elite_battle",     "weight": 30, "category": "elite", "desc": "精英战斗"},
]


## 解析节点
## node_option: 节点选项数据
## context: {
##   hero: RuntimeHero,
##   run: RuntimeRun,
##   turn: int,
##   partners: Array[RuntimePartner]
## }
func resolve(node_option: Dictionary, context: Dictionary) -> Dictionary:
	var node_type: int = node_option.get("node_type", 0)
	var result: Dictionary = {"success": true, "rewards": []}

	match node_type:
		NodePoolSystem.NodeType.TRAINING:
			result = _resolve_training()
		NodePoolSystem.NodeType.BATTLE:
			result = _resolve_battle(context)
		NodePoolSystem.NodeType.REST:
			result = _resolve_rest(context)
		NodePoolSystem.NodeType.OUTING:
			result = _resolve_outing(context)
		NodePoolSystem.NodeType.RESCUE:
			result = _resolve_rescue()
		NodePoolSystem.NodeType.SHOP:
			result = _resolve_shop()
		NodePoolSystem.NodeType.PVP_CHECK:
			result = _resolve_pvp()
		NodePoolSystem.NodeType.FINAL_BOSS:
			result = _resolve_final_boss()
		_:
			result = {"success": true, "rewards": []}

	node_resolved.emit(node_type, result)
	EventBus.node_resolved.emit(_get_node_type_name(node_type), result)
	return result


## v1 兼容接口：直接按节点类型解析
func resolve_node(node_type: int, node_option: Dictionary, context: Dictionary) -> Dictionary:
	return resolve(node_option, context)


func _resolve_training() -> Dictionary:
	## 训练节点 — 返回需要UI选择属性的标记
	return {
		"success": true,
		"requires_ui_selection": true,
		"node_type": NodePoolSystem.NodeType.TRAINING,
		"rewards": {},
	}


func generate_enemy_for_floor(floor: int) -> Dictionary:
	## 根据层数生成敌人信息（供UI预显示和简化战斗）
	var enemy_cfgs: Dictionary = ConfigManager.get_all_enemy_configs()
	var candidates: Array[Dictionary] = []
	for k in enemy_cfgs:
		var cfg: Dictionary = enemy_cfgs[k]
		if cfg.is_empty() or not cfg.has("id"):
			continue
		var min_turn: int = cfg.get("appear_turn_min", 0)
		var max_turn: int = cfg.get("appear_turn_max", 999)
		if floor >= min_turn and floor <= max_turn:
			candidates.append(cfg)

	if candidates.is_empty():
		## 默认敌人（层数越高越强）
		var base_hp: int = 30 + floor * 5
		var base_atk: int = 5 + floor * 2
		return {
			"name": "第%d层怪物" % floor,
			"max_hp": base_hp,
			"current_hp": base_hp,
			"attack": base_atk,
			"gold_drop": 10 + floor,
			"estimated_damage": maxi(1, int(base_atk * 0.5)),
		}
	else:
		var cfg: Dictionary = candidates[randi() % candidates.size()]
		var base_hp: int = 50 + floor * 3
		var base_atk: int = 5 + floor * 2
		return {
			"name": cfg.get("name", "???"),
			"max_hp": base_hp,
			"current_hp": base_hp,
			"attack": base_atk,
			"gold_drop": cfg.get("reward_gold_min", 20),
			"estimated_damage": maxi(1, int(base_atk * 0.5)),
			"enemy_config_id": cfg.get("id", 2001),
		}


func _resolve_battle(context: Dictionary) -> Dictionary:
	## 简化回合制战斗：hero_attack vs enemy_hp，20回合上限
	var turn: int = context.get("turn", 1)
	var hero = context.get("hero")

	## 生成敌人
	var enemy: Dictionary = generate_enemy_for_floor(turn)
	EventBus.emit_signal("enemy_encountered", enemy)

	var result: Dictionary = {
		"success": true,
		"node_type": NodePoolSystem.NodeType.BATTLE,
		"requires_battle": false,
		"is_elite": false,
		"enemy_data": enemy,
		"rewards": [],
		"logs": [],
	}

	if hero == null:
		push_error("[NodeResolver] BATTLE node requires hero in context")
		return result

	## 简化攻击计算
	var hero_attack: int = hero.current_str * 2 + hero.current_tec
	var battle_rounds: int = 0
	var hero_hp_loss: int = 0
	var enemy_hp: int = enemy.get("current_hp", 50)
	var enemy_atk: int = enemy.get("attack", 10)

	while enemy_hp > 0 and battle_rounds < 20:
		## 玩家攻击
		enemy_hp -= hero_attack
		battle_rounds += 1

		## 敌人反击
		if enemy_hp > 0:
			var damage: int = maxi(1, enemy_atk - hero.current_vit)
			hero_hp_loss += damage

			## 检查玩家死亡（累计伤害是否超过当前HP）
			if hero_hp_loss >= hero.current_hp:
				result["success"] = false
				result["logs"].append("第%d层：战斗失败，生命耗尽" % turn)
				result["rewards"].append({"type": "hp_damage", "amount": hero_hp_loss})
				return result

	## 战斗胜利
	if enemy_hp <= 0:
		var gold_reward: int = enemy.get("gold_drop", 20)
		result["rewards"].append({"type": "gold", "amount": gold_reward})
		result["rewards"].append({"type": "hp_damage", "amount": hero_hp_loss})
		result["logs"].append("第%d层：战斗胜利，获得%d金币，损失%d生命" % [turn, gold_reward, hero_hp_loss])

	return result


func _resolve_rest(context: Dictionary) -> Dictionary:
	## 休息 — 恢复15%最大生命
	var hero: RuntimeHero = context.get("hero")
	if hero == null:
		push_error("[NodeResolver] REST node requires hero in context")
		return {"success": false, "rewards": []}
	var max_hp: int = hero.max_hp
	var heal: int = int(max_hp * 0.15)
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.REST,
		"rewards": [{"type": "hp_heal", "amount": heal}],
	}


func _resolve_outing(context: Dictionary) -> Dictionary:
	## 外出 — 触发随机事件池
	var total_weight: float = 0.0
	for evt in _OUTING_EVENTS:
		total_weight += evt.get("weight", 0.0)
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	var selected_event: String = "gold_bonus"
	for evt in _OUTING_EVENTS:
		cumulative += evt.get("weight", 0.0)
		if roll < cumulative:
			selected_event = evt.get("event", "gold_bonus")
			break

	## 精英战需要返回战斗标记
	if selected_event == "elite_battle":
		var turn: int = context.get("turn", 1)
		var enemy_id: int = _select_enemy_for_turn(turn)
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"requires_battle": true,
			"is_elite": true,
			"enemy_config_id": enemy_id,
			"rewards": [],
		}

	## 金币奖励
	if selected_event == "gold_bonus":
		var gold_amount: int = randi() % 30 + 20
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"rewards": [{"type": "gold", "amount": gold_amount}],
		}

	## 完全恢复
	if selected_event == "full_heal":
		var hero: RuntimeHero = context.get("hero")
		var heal_amount: int = hero.max_hp - hero.current_hp if hero != null else 50
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"rewards": [{"type": "hp_heal", "amount": heal_amount}],
		}

	## 陷阱事件（简化：损失10%生命）
	if selected_event == "trap":
		var hero: RuntimeHero = context.get("hero")
		var trap_damage: int = int(hero.max_hp * 0.1) if hero != null else 10
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"rewards": [{"type": "hp_damage", "amount": trap_damage}],
		}

	## 小偷事件（损失20%金币）
	if selected_event == "thief":
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"rewards": [{"type": "gold_theft", "ratio": 0.2}],
		}

	## 其他事件（random_level_up, lv5_training, weakness, weaken_potion）
	## 简化处理：无即时效果，仅记录事件类型
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.OUTING,
		"event": selected_event,
		"rewards": {},
	}


func _resolve_rescue() -> Dictionary:
	## 救援 — 生成候选伙伴
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.RESCUE,
		"requires_ui_selection": true,
		"rewards": {},
	}


func _resolve_shop() -> Dictionary:
	## 商店 — 生成商品列表
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.SHOP,
		"requires_ui_selection": true,
		"rewards": {},
	}


func _resolve_pvp() -> Dictionary:
	## PVP检定 — 返回标记由调用方执行
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.PVP_CHECK,
		"rewards": {},
	}


func _resolve_final_boss() -> Dictionary:
	## 终局Boss战
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.FINAL_BOSS,
		"rewards": {},
	}


func _get_node_type_name(node_type: int) -> String:
	match node_type:
		NodePoolSystem.NodeType.TRAINING: return "TRAINING"
		NodePoolSystem.NodeType.BATTLE: return "BATTLE"
		NodePoolSystem.NodeType.REST: return "REST"
		NodePoolSystem.NodeType.OUTING: return "OUTING"
		NodePoolSystem.NodeType.RESCUE: return "RESCUE"
		NodePoolSystem.NodeType.SHOP: return "SHOP"
		NodePoolSystem.NodeType.PVP_CHECK: return "PVP_CHECK"
		NodePoolSystem.NodeType.FINAL_BOSS: return "FINAL_BOSS"
		_: return "UNKNOWN"


func _select_enemy_for_turn(turn: int) -> int:
	## 根据层数选择合适的敌人配置ID
	var enemy_cfgs: Dictionary = ConfigManager.get_all_enemy_configs()
	var candidates: Array[int] = []
	for k in enemy_cfgs:
		var cfg: Dictionary = enemy_cfgs[k]
		if cfg.is_empty() or not cfg.has("id"):
			continue
		var min_turn: int = cfg.get("appear_turn_min", 0)
		var max_turn: int = cfg.get("appear_turn_max", 999)
		if turn >= min_turn and turn <= max_turn:
			candidates.append(cfg.get("id", 2001))
	if candidates.is_empty():
		return 2001  # 默认敌人
	return candidates[randi() % candidates.size()]


## 商店购买处理（由ShopSystem处理具体逻辑，这里只保留接口兼容）
func process_shop_purchase(item_data: Dictionary, run_data: RuntimeRun) -> Dictionary:
	push_warning("[NodeResolver] process_shop_purchase is deprecated, use ShopSystem directly")
	return {"success": false, "error": "deprecated"}


## 救援选择处理（由RescueSystem处理具体逻辑，这里只保留接口兼容）
func process_rescue_selection(partner_config_id: int, turn: int, run_data: RuntimeRun) -> void:
	push_warning("[NodeResolver] process_rescue_selection is deprecated, use RescueSystem directly")
