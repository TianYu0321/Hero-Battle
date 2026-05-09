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

# 阶段权重配置（从ConfigManager读取，硬编码仅作为fallback）
var _phase_weights: Dictionary = {
	_PHASE_EARLY: { NodeType.TRAINING: 300, NodeType.BATTLE: 400, NodeType.ELITE: 50, NodeType.SHOP: 200 },
	_PHASE_MID:   { NodeType.TRAINING: 250, NodeType.BATTLE: 350, NodeType.ELITE: 150, NodeType.SHOP: 200 },
	_PHASE_LATE:  { NodeType.TRAINING: 200, NodeType.BATTLE: 300, NodeType.ELITE: 200, NodeType.SHOP: 200 },
}

func _ready() -> void:
	# 尝试从配置表加载阶段权重
	var node_cfg: Dictionary = ConfigManager.get_node_weights("")
	if not node_cfg.is_empty():
		# 按 stage 分组构建权重字典
		var loaded_weights: Dictionary = {}
		for k in node_cfg:
			var item: Dictionary = node_cfg[k]
			var stage: int = item.get("stage", 1)
			var ntype: int = item.get("node_type", 1)
			var weight: int = item.get("weight", 100)
			if not loaded_weights.has(stage):
				loaded_weights[stage] = {}
			loaded_weights[stage][ntype] = weight
		if loaded_weights.has(_PHASE_EARLY):
			_phase_weights[_PHASE_EARLY] = loaded_weights[_PHASE_EARLY]
		if loaded_weights.has(_PHASE_MID):
			_phase_weights[_PHASE_MID] = loaded_weights[_PHASE_MID]
		if loaded_weights.has(_PHASE_LATE):
			_phase_weights[_PHASE_LATE] = loaded_weights[_PHASE_LATE]

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

	var temp_weights: Dictionary = weights.duplicate()
	for i in range(3):
		var node_type: int = _weighted_pick(temp_weights)
		# 保底替换
		if force_battle and i == 0 and node_type != NodeType.BATTLE and node_type != NodeType.ELITE:
			node_type = NodeType.BATTLE
		options.append(_build_option(node_type, turn))
		temp_weights.erase(node_type)

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
