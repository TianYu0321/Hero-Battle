class_name NodeResolver
extends Node

## NodeResolver — 节点解析器
## v2.0: 从随机解析改为直接处理4种选项类型

signal node_resolved(node_type: int, result_data: Dictionary)

const _OUTING_EVENTS: Array[Dictionary] = [
	{"event": "rest", "weight": 30, "desc": "休息恢复"},
	{"event": "shop", "weight": 20, "desc": "发现商店"},
	{"event": "trap", "weight": 15, "desc": "遭遇陷阱"},
	{"event": "heal", "weight": 15, "desc": "发现回复泉"},
	{"event": "special", "weight": 15, "desc": "特殊事件"},
	{"event": "elite", "weight": 5, "desc": "精英战"},
]

func resolve(node_option: Dictionary, run_controller: RunController) -> Dictionary:
	var node_type: int = node_option.get("node_type", 0)
	var result: Dictionary = {"success": true, "rewards": {}}

	match node_type:
		NodePoolSystem.NodeType.TRAINING:
			result = _resolve_training(run_controller)
		NodePoolSystem.NodeType.BATTLE:
			result = _resolve_battle(run_controller)
		NodePoolSystem.NodeType.REST:
			result = _resolve_rest(run_controller)
		NodePoolSystem.NodeType.OUTING:
			result = _resolve_outing(run_controller)
		NodePoolSystem.NodeType.RESCUE:
			result = _resolve_rescue(run_controller)
		NodePoolSystem.NodeType.SHOP:
			result = _resolve_shop(run_controller)
		NodePoolSystem.NodeType.PVP_CHECK:
			result = _resolve_pvp(run_controller)
		NodePoolSystem.NodeType.FINAL_BOSS:
			result = _resolve_final_boss(run_controller)
		_:
			result = {"success": true, "rewards": {}}

	node_resolved.emit(node_type, result)
	return result

func _resolve_training(run_controller: RunController) -> Dictionary:
	## 训练节点 — 返回需要UI选择属性的标记
	return {
		"success": true,
		"requires_ui_selection": true,
		"node_type": NodePoolSystem.NodeType.TRAINING,
		"rewards": {},
	}

func _resolve_battle(run_controller: RunController) -> Dictionary:
	## 普通战斗 — 产出金币
	var gold_reward: int = randi() % 20 + 10
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.BATTLE,
		"rewards": {"gold": gold_reward},
	}

func _resolve_rest(run_controller: RunController) -> Dictionary:
	## 休息 — 恢复15%最大生命
	var hero = run_controller.get_hero()
	var max_hp = hero.get("max_hp", 100)
	var heal = int(max_hp * 0.15)
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.REST,
		"rewards": {"hp_heal": heal},
	}

func _resolve_outing(run_controller: RunController) -> Dictionary:
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

	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.OUTING,
		"event": selected_event,
		"rewards": {},
	}

func _resolve_rescue(run_controller: RunController) -> Dictionary:
	## 救援 — 生成候选伙伴
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.RESCUE,
		"requires_ui_selection": true,
		"rewards": {},
	}

func _resolve_shop(run_controller: RunController) -> Dictionary:
	## 商店 — 生成商品列表
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.SHOP,
		"requires_ui_selection": true,
		"rewards": {},
	}

func _resolve_pvp(run_controller: RunController) -> Dictionary:
	## PVP检定 — 调用PvpDirector
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.PVP_CHECK,
		"rewards": {},
	}

func _resolve_final_boss(run_controller: RunController) -> Dictionary:
	## 终局Boss战
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.FINAL_BOSS,
		"rewards": {},
	}
