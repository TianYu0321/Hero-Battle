## res://scripts/systems/rescue_system.gd
## 模块: RescueSystem
## 职责: 救援系统：第5/15/25回合生成3个候选伙伴，优先补全缺失定位
## 依赖: CharacterManager, ConfigManager
## class_name: RescueSystem

class_name RescueSystem
extends Node

const _RESCUE_TURNS: Array[int] = [5, 15, 25]

var _character_manager: CharacterManager = null
var _rng: RandomNumberGenerator = null


func initialize(cm: CharacterManager) -> void:
	_character_manager = cm


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func is_rescue_turn(turn: int) -> bool:
	return turn in _RESCUE_TURNS


func get_rescue_slot(turn: int) -> int:
	match turn:
		5: return 2
		15: return 3
		25: return 4
		_: return 0


func generate_candidates() -> Array[Dictionary]:
	var partners: Array[RuntimePartner] = _character_manager.get_partners()
	var existing_ids: Array[int] = []
	for p in partners:
		existing_ids.append(p.partner_config_id)

	# 获取当前队伍的定位集合
	var existing_roles: Array[int] = []
	for pid in existing_ids:
		var config: Dictionary = ConfigManager.get_partner_config(str(pid))
		if not config.is_empty():
			existing_roles.append(config.get("favored_attr", 0))

	# 所有可用定位
	var all_partner_ids: Array[int] = ConfigManager.get_all_partner_config_ids()
	var all_roles: Dictionary = {}
	for pid in all_partner_ids:
		var config: Dictionary = ConfigManager.get_partner_config(str(pid))
		if not config.is_empty():
			all_roles[pid] = config.get("favored_attr", 0)

	# 找出缺失的定位
	var available: Array[int] = []
	var missing_roles: Array[int] = []
	for pid in all_partner_ids:
		if pid not in existing_ids:
			available.append(pid)
		var role: int = all_roles.get(pid, 0)
		if role > 0 and role not in existing_roles and role not in missing_roles:
			missing_roles.append(role)

	var candidates: Array[int] = []

	# 补全位：优先从缺失定位中选
	if not missing_roles.is_empty() and not available.is_empty():
		var fill_role: int = _array_pick_random(missing_roles)
		for pid in available:
			if all_roles.get(pid, 0) == fill_role:
				candidates.append(pid)
				available.erase(pid)
				break

	# 填充剩余位（随机，去重）
	while candidates.size() < 3 and not available.is_empty():
		var pid: int = _array_pick_random(available)
		candidates.append(pid)
		available.erase(pid)

	# 转换为详细信息
	var result: Array[Dictionary] = []
	for pid in candidates:
		var config: Dictionary = ConfigManager.get_partner_config(str(pid))
		result.append({
			"partner_id": str(pid),
			"name": config.get("name", "未知伙伴"),
			"role": config.get("role", ""),
			"attr_focus": _attr_name(config.get("favored_attr", 1)),
			"assist_type": _trigger_name(config.get("aid_trigger_type", 1)),
		})
	return result


func rescue_partner(partner_config_id: int, turn: int, floor: int = 1) -> RuntimePartner:
	print("[RescueSystem] rescue_partner 被调用: partner_config_id=%d, turn=%d, floor=%d" % [partner_config_id, turn, floor])
	var slot: int = get_rescue_slot(turn)
	## 营救等级：1-10层Lv.1，11-20层Lv.2，21-30层Lv.3
	var rescue_level: int = 1
	if floor >= 21:
		rescue_level = 3
	elif floor >= 11:
		rescue_level = 2
	print("[RescueSystem] 计算 slot=%d, rescue_level=%d" % [slot, rescue_level])
	var result = _character_manager.add_partner(partner_config_id, slot, rescue_level)
	if result == null:
		print("[RescueSystem] 警告: add_partner 返回 null")
	else:
		print("[RescueSystem] add_partner 成功: instance_id=%d, config_id=%d, level=%d, is_active=%s" % [result.instance_id, result.partner_config_id, result.current_level, str(result.is_active)])
	return result


# --- 私有方法 ---

func _array_pick_random(arr: Array):
	if arr.is_empty():
		return null
	if _rng != null:
		return arr[_rng.randi() % arr.size()]
	return arr.pick_random()


func _attr_name(attr_type: int) -> String:
	match attr_type:
		1: return "体魄"
		2: return "力量"
		3: return "敏捷"
		4: return "技巧"
		5: return "精神"
		_: return "未知"


func _trigger_name(trigger_type: int) -> String:
	match trigger_type:
		1: return "固定回合"
		2: return "条件触发"
		3: return "概率触发"
		4: return "被动常驻"
		5: return "连锁触发"
		6: return "敌方触发"
		_: return "未知"
