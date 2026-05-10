class_name NodeResolver
extends Node

## NodeResolver — 节点解析器
## v2.0: 职责单一，只负责根据节点类型生成解析结果，不依赖任何上层模块
## 所有需要的数据通过 context Dictionary 传入，实现与 RunController 的解耦

signal node_resolved(node_type: int, result_data: Dictionary)

const _OUTING_EVENTS: Array[Dictionary] = [
	{"event": "rest", "weight": 20, "desc": "休息恢复"},
	{"event": "shop", "weight": 15, "desc": "发现商店"},
	{"event": "trap", "weight": 10, "desc": "遭遇陷阱"},
	{"event": "heal", "weight": 10, "desc": "发现回复泉"},
	{"event": "special", "weight": 20, "desc": "特殊事件"},
	{"event": "elite", "weight": 25, "desc": "精英战"},
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


func _resolve_battle(context: Dictionary) -> Dictionary:
	## 普通战斗 — 根据当前层数选择敌人，返回战斗标记由调用方执行
	var turn: int = context.get("turn", 1)
	var enemy_id: int = _select_enemy_for_turn(turn)
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.BATTLE,
		"requires_battle": true,
		"is_elite": false,
		"enemy_config_id": enemy_id,
		"rewards": [],
	}


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
	var total_weight: int = 0
	for evt in _OUTING_EVENTS:
		total_weight += evt.get("weight", 0)
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	var selected_event: String = "rest"
	for evt in _OUTING_EVENTS:
		cumulative += evt.get("weight", 0)
		if roll < cumulative:
			selected_event = evt.get("event", "rest")
			break

	## 精英战需要返回战斗标记
	if selected_event == "elite":
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

	## 商店事件
	if selected_event == "shop":
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"requires_ui_selection": true,
			"rewards": [],
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

	## 休息/回复泉事件
	if selected_event in ["rest", "heal"]:
		var hero: RuntimeHero = context.get("hero")
		var heal_amount: int = int(hero.max_hp * 0.15) if hero != null else 15
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"event": selected_event,
			"rewards": [{"type": "hp_heal", "amount": heal_amount}],
		}

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
