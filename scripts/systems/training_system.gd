## res://scripts/systems/training_system.gd
## 模块: TrainingSystem
## 职责: 训练系统：属性等级制，每次训练给主属性+固定副属性配比
## 依赖: CharacterManager, EventBus
## class_name: TrainingSystem

class_name TrainingSystem
extends Node

## 每属性训练5次升1级
const _LEVEL_UP_COUNT: int = 5
## 训练等级上限
const _MAX_TRAINING_LEVEL: int = 5

## 基础主属性加成 (LV1)
const _BASE_MAIN_GAIN: int = 5
## 每级主属性额外加成 (+2 per level)
const _MAIN_GAIN_INCREMENT: int = 2
## 基础副属性加成 (LV1)
const _BASE_SUB_GAIN: int = 1
## 每级副属性额外加成 (+1 per level)
const _SUB_GAIN_INCREMENT: int = 1

## 属性对应关系：主属性 -> [副属性1, 副属性2]
const _ATTR_SECONDARY: Dictionary = {
	1: [2, 5],  # 体魄 -> 力量, 精神
	2: [3, 4],  # 力量 -> 敏捷, 技巧
	3: [4, 1],  # 敏捷 -> 技巧, 体魄
	4: [5, 2],  # 技巧 -> 精神, 力量
	5: [1, 3],  # 精神 -> 体魄, 敏捷
}

var _character_manager: CharacterManager = null


func initialize(cm: CharacterManager) -> void:
	_character_manager = cm


## 执行训练
## attr_type: 1=体魄, 2=力量, 3=敏捷, 4=技巧, 5=精神
## _floor: 当前层数
## partner_bonus: 伙伴支援加成（固定值，不影响副属性）
## force_level: 强制训练等级（0=按当前等级，5=强制LV5）
## extra_bonus: 额外主属性加成（如外出事件训练加成）
func execute_training(attr_type: int, _floor: int, partner_bonus: int = 0, force_level: int = 0, extra_bonus: int = 0) -> Dictionary:
	if _character_manager == null:
		push_error("[TrainingSystem] CharacterManager not initialized")
		return {}

	var hero: RuntimeHero = _character_manager.get_hero()
	
	# 获取该属性的训练等级
	var training_level: int = force_level if force_level > 0 else _get_training_level(hero, attr_type)
	
	# 应用训练类 Buff（训练等级+1、训练熟练度+1）
	var buff_extra_level: int = 0
	var buff_extra_gain: int = 0
	var training_buffs: Array = _get_training_buffs(hero)
	for buff in training_buffs:
		var be: int = buff.get("buff_effect", 0)
		if be == 5:
			buff_extra_level += int(buff.get("effect_value", 0))
		elif be == 4:
			buff_extra_gain += int(buff.get("effect_value", 0))
	training_level = clampi(training_level + buff_extra_level, 1, _MAX_TRAINING_LEVEL)
	
	# 计算主属性加成
	var main_gain: int = _BASE_MAIN_GAIN + (training_level - 1) * _MAIN_GAIN_INCREMENT + partner_bonus + buff_extra_gain + extra_bonus
	
	# 计算副属性加成
	var sub_gain: int = _BASE_SUB_GAIN + (training_level - 1) * _SUB_GAIN_INCREMENT
	
	# 训练效果减半减益
	if _has_training_half_debuff(hero):
		main_gain = maxi(1, int(main_gain * 0.5))
		sub_gain = maxi(1, int(sub_gain * 0.5))
	
	# 获取副属性列表
	var secondary_attrs: Array = _ATTR_SECONDARY.get(attr_type, [])
	
	# 应用主属性加成
	var old_main: int = _get_attr_value(hero, attr_type)
	_character_manager.modify_hero_stats({attr_type: main_gain})
	var new_main: int = _get_attr_value(hero, attr_type)
	var actual_main_gain: int = new_main - old_main
	
	# 应用副属性加成
	var sub_gains: Dictionary = {}
	for sub_attr in secondary_attrs:
		var old_sub: int = _get_attr_value(hero, sub_attr)
		_character_manager.modify_hero_stats({sub_attr: sub_gain})
		var new_sub: int = _get_attr_value(hero, sub_attr)
		sub_gains[sub_attr] = new_sub - old_sub
	
	# 检查是否升级（强制训练不提升该属性的训练等级）
	var new_level: int = training_level
	var level_up: bool = false
	
	# 强制训练：只获得收益，不增加该属性的训练计数（避免破坏后续等级成长曲线）
	if force_level <= 0:
		# 更新该属性的训练计数
		var attr_key: String = _get_attr_key(attr_type)
		var current_count: int = hero.training_counts.get(attr_key, 0)
		hero.training_counts[attr_key] = current_count + 1
		# 检查是否升级
		new_level = _get_training_level(hero, attr_type)
		level_up = new_level > training_level
	
	# 训练类 Buff 持续次数 -1
	_consume_training_buffs(hero)
	
	# 训练效果减半减益持续次数 -1
	_consume_training_half_debuff(hero)
	
	# 更新总训练次数
	hero.total_training_count += 1
	
	# 记录日志
	var log := RuntimeTrainingLog.new()
	log.turn = _floor
	log.attr_type = attr_type
	log.base_gain = main_gain
	log.mastery_bonus = partner_bonus
	log.partner_bonus = partner_bonus
	log.marginal_decrease_applied = false
	log.final_gain = actual_main_gain

	EventBus.emit_signal("training_completed", attr_type, _attr_name(attr_type), actual_main_gain, new_main, "LV%d" % new_level, partner_bonus)

	return {
		"attr_type": attr_type,
		"attr_name": _attr_name(attr_type),
		"gain_value": actual_main_gain,
		"new_total": new_main,
		"training_level": training_level,
		"new_level": new_level,
		"level_up": level_up,
		"sub_gains": sub_gains,
		"partner_bonus": partner_bonus,
		"log": log,
	}


## 获取某属性的训练等级
func _get_training_level(hero: RuntimeHero, attr_type: int) -> int:
	var attr_key: String = _get_attr_key(attr_type)
	var count: int = hero.training_counts.get(attr_key, 0)
	var level: int = (count / _LEVEL_UP_COUNT) + 1
	return mini(level, _MAX_TRAINING_LEVEL)


## 获取属性字段名
func _get_attr_key(attr_type: int) -> String:
	match attr_type:
		1: return "vit"
		2: return "str"
		3: return "agi"
		4: return "tec"
		5: return "mnd"
		_: return ""


## 获取属性当前值
func _get_attr_value(hero: RuntimeHero, attr_type: int) -> int:
	match attr_type:
		1: return hero.current_vit
		2: return hero.current_str
		3: return hero.current_agi
		4: return hero.current_tec
		5: return hero.current_mnd
		_: return 0


## 检查是否存在训练效果减半的减益
func _has_training_half_debuff(hero: RuntimeHero) -> bool:
	for buff in hero.buff_list:
		if buff.get("buff_effect", 0) == 2 and buff.get("debuff_type", "") == "training_half":
			return true
	return false


## 获取属性名称
func _attr_name(attr_type: int) -> String:
	match attr_type:
		1: return "体魄"
		2: return "力量"
		3: return "敏捷"
		4: return "技巧"
		5: return "精神"
		_: return "未知"


## 获取主角身上的训练类 Buff（buff_effect 4=熟练度+1, 5=训练等级+1）
func _get_training_buffs(hero: RuntimeHero) -> Array:
	var result: Array = []
	for buff in hero.buff_list:
		var be: int = buff.get("buff_effect", 0)
		if be == 4 or be == 5:
			result.append(buff)
	return result


## 消耗一次训练效果减半减益的剩余层数
func _consume_training_half_debuff(hero: RuntimeHero) -> void:
	for i in range(hero.buff_list.size() - 1, -1, -1):
		var buff = hero.buff_list[i]
		if buff.get("buff_effect", 0) == 2 and buff.get("debuff_type", "") == "training_half":
			buff.duration -= 1
			if buff.duration <= 0:
				hero.buff_list.remove_at(i)
			return


## 消耗一次训练类 Buff 的剩余层数
func _consume_training_buffs(hero: RuntimeHero) -> void:
	for i in range(hero.buff_list.size() - 1, -1, -1):
		var buff = hero.buff_list[i]
		var be: int = buff.get("buff_effect", 0)
		if be == 4 or be == 5:
			buff.duration -= 1
			if buff.duration <= 0:
				hero.buff_list.remove_at(i)


## 计算训练面板显示的加成值（预览用）
func get_training_preview(attr_type: int, hero: RuntimeHero, partner_bonus: int = 0) -> Dictionary:
	var level: int = _get_training_level(hero, attr_type)
	var main_gain: int = _BASE_MAIN_GAIN + (level - 1) * _MAIN_GAIN_INCREMENT + partner_bonus
	var sub_gain: int = _BASE_SUB_GAIN + (level - 1) * _SUB_GAIN_INCREMENT
	var secondary: Array = _ATTR_SECONDARY.get(attr_type, [])
	return {
		"attr_type": attr_type,
		"attr_name": _attr_name(attr_type),
		"training_level": level,
		"main_gain": main_gain,
		"sub_gain": sub_gain,
		"sub_attr_1": _attr_name(secondary[0]) if secondary.size() > 0 else "",
		"sub_attr_2": _attr_name(secondary[1]) if secondary.size() > 1 else "",
		"partner_bonus": partner_bonus,
	}
