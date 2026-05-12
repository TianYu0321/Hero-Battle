class_name NodePoolSystem
extends Node

## NodePoolSystem — 30层爬塔节点生成器
## v2.0: 从随机权重池改为固定层类型

enum NodeType {
	TRAINING = 1,
	BATTLE = 2,
	REST = 3,
	OUTING = 4,
	RESCUE = 5,
	SHOP = 6,
	PVP_CHECK = 7,
	FINAL_BOSS = 8,
}

const _MAX_FLOOR: int = 30
const _RESCUE_FLOORS: Array[int] = [5, 15, 25]
const _PVP_FLOORS: Array[int] = [10, 20]
const _FINAL_FLOOR: int = 30

const _NORMAL_OPTION_NAMES: Dictionary = {
	NodeType.TRAINING: "训练",
	NodeType.BATTLE: "战斗",
	NodeType.REST: "休息",
	NodeType.OUTING: "外出",
}

const _NORMAL_OPTION_DESC: Dictionary = {
	NodeType.TRAINING: "选择一项属性进行锻炼提升",
	NodeType.BATTLE: "与普通敌人战斗，获得金币",
	NodeType.REST: "休息恢复15%生命值",
	NodeType.OUTING: "外出触发随机事件",
}


func reset() -> void:
	pass

func get_floor_type(floor: int) -> String:
	if floor in _RESCUE_FLOORS:
		return "rescue"
	elif floor in _PVP_FLOORS:
		return "pvp"
	elif floor == _FINAL_FLOOR:
		return "final"
	else:
		return "normal"

func generate_options(floor: int) -> Array[Dictionary]:
	var floor_type: String = get_floor_type(floor)
	match floor_type:
		"normal":
			return _generate_normal_options(floor)
		"rescue":
			return _generate_rescue_options(floor)
		"pvp":
			return _generate_pvp_options(floor)
		"final":
			return _generate_final_options(floor)
		_:
			return _generate_normal_options(floor)

func record_selection(_node_type: int) -> void:
	pass

func _generate_normal_options(floor: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for ntype in [NodeType.TRAINING, NodeType.BATTLE, NodeType.REST, NodeType.OUTING]:
		var option: Dictionary = {
			"node_type": ntype,
			"node_name": _NORMAL_OPTION_NAMES.get(ntype, "未知"),
			"description": _NORMAL_OPTION_DESC.get(ntype, ""),
			"node_id": "%s_%d" % [_node_id_prefix(ntype), floor],
		}
		# 为外出节点预生成事件类型（用于事件透视）
		if ntype == NodeType.OUTING:
			var roll: int = randi() % 10
			if roll < 4:
				option["pool_type"] = "reward"
			elif roll < 7:
				option["pool_type"] = "penalty"
			else:
				option["pool_type"] = "elite"
		options.append(option)
	return options

func _generate_rescue_options(floor: int) -> Array[Dictionary]:
	return [{
		"node_type": NodeType.RESCUE,
		"node_name": "救援",
		"description": "发现遇险伙伴",
		"node_id": "rescue_%d" % floor,
	}]

func _generate_pvp_options(floor: int) -> Array[Dictionary]:
	return [{
		"node_type": NodeType.PVP_CHECK,
		"node_name": "PVP检定",
		"description": "与其他斗士进行对战检定",
		"node_id": "pvp_%d" % floor,
	}]

func _generate_final_options(floor: int) -> Array[Dictionary]:
	return [{
		"node_type": NodeType.FINAL_BOSS,
		"node_name": "终局Boss战",
		"description": "最终决战",
		"node_id": "final_%d" % floor,
	}]

func _node_id_prefix(node_type: int) -> String:
	match node_type:
		1: return "train"
		2: return "battle"
		3: return "rest"
		4: return "outing"
		5: return "rescue"
		6: return "shop"
		7: return "pvp"
		8: return "final"
		_: return "unknown"
