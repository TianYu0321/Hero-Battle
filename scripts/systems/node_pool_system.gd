## res://scripts/systems/node_pool_system.gd
## 模块: NodePoolSystem
## 职责: 节点池生成：按阶段抽3个选项，保底机制
## 依赖: ConfigManager
## class_name: NodePoolSystem

class_name NodePoolSystem
extends Node

enum NodeType {
	TRAINING = 1,
	BATTLE = 2,
	ELITE = 3,
	SHOP = 4,
	RESCUE = 5,
	PVP_CHECK = 6,
	FINAL = 7,
}

const _PHASE_EARLY: int = 1
const _PHASE_MID: int = 2
const _PHASE_LATE: int = 3

# 阶段权重配置（前期/中期/后期）
var _phase_weights: Dictionary = {
	_PHASE_EARLY: { NodeType.TRAINING: 300, NodeType.BATTLE: 400, NodeType.ELITE: 50, NodeType.SHOP: 200 },
	_PHASE_MID:   { NodeType.TRAINING: 250, NodeType.BATTLE: 350, NodeType.ELITE: 150, NodeType.SHOP: 200 },
	_PHASE_LATE:  { NodeType.TRAINING: 200, NodeType.BATTLE: 300, NodeType.ELITE: 200, NodeType.SHOP: 200 },
}

var _no_battle_streak: int = 0


func get_phase(turn: int) -> int:
	if turn >= 1 and turn <= 9:
		return _PHASE_EARLY
	elif turn >= 10 and turn <= 19:
		return _PHASE_MID
	elif turn >= 20 and turn <= 29:
		return _PHASE_LATE
	return _PHASE_EARLY


func generate_options(turn: int) -> Array[Dictionary]:
	var phase: int = get_phase(turn)
	var weights: Dictionary = _phase_weights.get(phase, {})
	var options: Array[Dictionary] = []

	# 保底机制：连续3回合无战斗，强制至少1个战斗选项
	var force_battle: bool = _no_battle_streak >= 3

	for i in range(3):
		var node_type: int = _weighted_pick(weights)
		# 保底替换
		if force_battle and i == 0 and node_type != NodeType.BATTLE and node_type != NodeType.ELITE:
			node_type = NodeType.BATTLE
		options.append(_build_option(node_type, turn))

	return options


func record_selection(node_type: int) -> void:
	if node_type == NodeType.BATTLE or node_type == NodeType.ELITE:
		_no_battle_streak = 0
	else:
		_no_battle_streak += 1


func reset() -> void:
	_no_battle_streak = 0


# --- 私有方法 ---

func _weighted_pick(weights: Dictionary) -> int:
	var total_weight: int = 0
	for w in weights.values():
		total_weight += w
	if total_weight <= 0:
		return NodeType.TRAINING

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for node_type in weights.keys():
		cumulative += weights[node_type]
		if roll < cumulative:
			return node_type
	return NodeType.TRAINING


func _build_option(node_type: int, turn: int) -> Dictionary:
	match node_type:
		NodeType.TRAINING:
			var attr_type: int = (turn % 5) + 1  # 轮流分配5属性
			var attr_names: Dictionary = {1: "体魄", 2: "力量", 3: "敏捷", 4: "技巧", 5: "精神"}
			return {
				"node_type": NodeType.TRAINING,
				"node_name": "锻炼：%s" % attr_names.get(attr_type, "体魄"),
				"description": "锻炼%s属性" % attr_names.get(attr_type, "体魄"),
				"node_id": "train_%d_%d" % [turn, attr_type],
				"attr_type": attr_type,
			}
		NodeType.BATTLE:
			return {
				"node_type": NodeType.BATTLE,
				"node_name": "普通战斗",
				"description": "与普通敌人战斗，获得金币",
				"node_id": "battle_%d" % turn,
			}
		NodeType.ELITE:
			return {
				"node_type": NodeType.ELITE,
				"node_name": "精英战",
				"description": "与精英敌人战斗，高风险高回报",
				"node_id": "elite_%d" % turn,
			}
		NodeType.SHOP:
			return {
				"node_type": NodeType.SHOP,
				"node_name": "商店",
				"description": "购买升级强化自身和伙伴",
				"node_id": "shop_%d" % turn,
			}
		_:
			return {
				"node_type": NodeType.TRAINING,
				"node_name": "锻炼",
				"description": "选择一项属性进行锻炼",
				"node_id": "train_%d" % turn,
			}
