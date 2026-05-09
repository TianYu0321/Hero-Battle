## res://scripts/systems/training_system.gd
## 模块: TrainingSystem
## 职责: 锻炼系统：单次锻炼属性增加计算、熟练度晋升、边际递减、副属性共享
## 依赖: CharacterManager, EventBus
## class_name: TrainingSystem

class_name TrainingSystem
extends Node

const _BASE_GAIN: int = 5
const _MARGIN_THRESHOLD: float = 0.6
const _MARGIN_DECREASE: float = 0.2
const _SECONDARY_SHARE: float = 0.5

var _character_manager: CharacterManager = null


func initialize(cm: CharacterManager) -> void:
	_character_manager = cm


func execute_training(attr_type: int, turn: int) -> Dictionary:
	if _character_manager == null:
		push_error("[TrainingSystem] CharacterManager not initialized")
		return {}

	var hero: RuntimeHero = _character_manager.get_hero()
	var mastery: RuntimeMastery = _character_manager.get_mastery_by_attr(attr_type)
	if mastery == null:
		push_error("[TrainingSystem] Mastery not found for attr: %d" % attr_type)
		return {}

	# 步骤1-2: 获取熟练度阶段与加成
	var stage: int = mastery.stage
	var bonus: int = mastery.training_bonus

	# 步骤3: 基础增长值
	var base_gain: float = float(_BASE_GAIN)

	# 步骤4: 检查边际递减
	var total_train: int = _get_total_training_count()
	var is_marginal: bool = false
	if total_train > 0:
		var ratio: float = float(mastery.training_count) / float(total_train)
		if ratio > _MARGIN_THRESHOLD:
			base_gain *= (1.0 - _MARGIN_DECREASE)
			is_marginal = true

	# 步骤5: 计算最终增长值
	var final_gain: int = int(base_gain) + bonus

	# 步骤6: 更新属性值
	var old_attr: int = _get_attr_value(hero, attr_type)
	_character_manager.modify_hero_stats({attr_type: final_gain})
	var new_attr: int = _get_attr_value(hero, attr_type)
	final_gain = new_attr - old_attr  # 以实际变化为准

	# 步骤7: 更新锻炼计数
	mastery.training_count += 1
	_character_manager.update_mastery_stage(attr_type)

	# 步骤8: 副属性共享
	var secondary_attr: int = _character_manager.get_secondary_attr(attr_type)
	if secondary_attr > 0:
		var sec_mastery: RuntimeMastery = _character_manager.get_mastery_by_attr(secondary_attr)
		if sec_mastery != null:
			# 共享50%熟练度计数（累计到整数时生效）
			# 简化处理：每2次主属性锻炼，副属性+1计数
			# 这里用training_count的奇偶来模拟
			if mastery.training_count % 2 == 0:
				sec_mastery.training_count += 1
				_character_manager.update_mastery_stage(secondary_attr)

	# 更新主角总锻炼次数
	hero.total_training_count += 1

	# 步骤9: 记录日志
	var log := RuntimeTrainingLog.new()
	log.turn = turn
	log.attr_type = attr_type
	log.base_gain = int(base_gain)
	log.mastery_bonus = bonus
	log.partner_bonus = 0
	log.marginal_decrease_applied = is_marginal
	log.final_gain = final_gain

	EventBus.emit_signal("training_completed", attr_type, _attr_name(attr_type), final_gain, new_attr, _stage_name(stage), bonus)

	return {
		"attr_type": attr_type,
		"attr_name": _attr_name(attr_type),
		"gain_value": final_gain,
		"new_total": new_attr,
		"proficiency_stage": _stage_name(stage),
		"bonus_applied": bonus,
		"marginal_applied": is_marginal,
		"log": log,
	}


func _get_total_training_count() -> int:
	var hero: RuntimeHero = _character_manager.get_hero()
	return hero.total_training_count


func _get_attr_value(hero: RuntimeHero, attr_type: int) -> int:
	match attr_type:
		1: return hero.current_vit
		2: return hero.current_str
		3: return hero.current_agi
		4: return hero.current_tec
		5: return hero.current_mnd
		_: return 0


func _attr_name(attr_type: int) -> String:
	match attr_type:
		1: return "体魄"
		2: return "力量"
		3: return "敏捷"
		4: return "技巧"
		5: return "精神"
		_: return "未知"


func _stage_name(stage: int) -> String:
	match stage:
		1: return "NOVICE"
		2: return "FAMILIAR"
		3: return "PROFICIENT"
		4: return "EXPERT"
		_: return "UNKNOWN"
