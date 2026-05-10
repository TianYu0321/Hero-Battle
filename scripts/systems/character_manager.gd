## res://scripts/systems/character_manager.gd
## 模块: CharacterManager
## 职责: 角色管理：主角/伙伴属性计算、Buff添加/移除、属性变化通知
## 依赖: EventBus, 数据模型类
## class_name: CharacterManager

class_name CharacterManager
extends Node

# --- 运行时引用 ---
var _hero: RuntimeHero = null
var _partners: Array[RuntimePartner] = []
var _masteries: Array[RuntimeMastery] = []
var _buffs: Array[RuntimeBuff] = []

# --- 常量 ---
const _SECONDARY_ATTR_MAP: Dictionary = {
	1: 5, # 体魄 -> 精神
	2: 4, # 力量 -> 技巧
	3: 2, # 敏捷 -> 力量
	4: 3, # 技巧 -> 敏捷
	5: 1, # 精神 -> 体魄
}


func initialize_hero(hero_config_id: int) -> RuntimeHero:
	var config: Dictionary = ConfigManager.get_hero_config(str(hero_config_id))
	if config.is_empty():
		push_error("[CharacterManager] Hero config not found: %d" % hero_config_id)
		return null

	_hero = RuntimeHero.new()
	_hero.hero_config_id = hero_config_id
	_hero.current_vit = config.get("base_physique", 10)
	_hero.current_str = config.get("base_strength", 10)
	_hero.current_agi = config.get("base_agility", 10)
	_hero.current_tec = config.get("base_technique", 10)
	_hero.current_mnd = config.get("base_spirit", 10)
	_hero.passive_skill_id = config.get("passive_skill_id", 0)
	_hero.ultimate_skill_id = config.get("ultimate_skill_id", 0)
	_hero.max_hp = _calculate_max_hp(_hero.current_vit)
	_hero.current_hp = _hero.max_hp
	_hero.is_alive = true

	# 初始化5属性熟练度
	_masteries.clear()
	for attr in range(1, 6):
		var m := RuntimeMastery.new()
		m.attr_type = attr
		m.stage = 1
		m.training_count = 0
		m.training_bonus = 0
		_masteries.append(m)

	EventBus.emit_signal("stats_changed", _hero.id, _get_hero_stat_changes())
	return _hero


func initialize_partners(partner_config_ids: Array[int]) -> Array[RuntimePartner]:
	_partners.clear()
	for pid in partner_config_ids:
		var config: Dictionary = ConfigManager.get_partner_config(str(pid))
		if config.is_empty():
			push_warning("[CharacterManager] Partner config not found: %d" % pid)
			continue
		var p := RuntimePartner.new()
		p.partner_config_id = pid
		p.current_level = 1
		p.is_active = true
		# Phase 1 伙伴基础属性占位（简化）
		# Phase 1: 伙伴不再拥有五维属性
		_partners.append(p)
	return _partners


func add_partner(partner_config_id: int, position: int) -> RuntimePartner:
	var config: Dictionary = ConfigManager.get_partner_config(str(partner_config_id))
	if config.is_empty():
		push_error("[CharacterManager] Partner config not found: %d" % partner_config_id)
		return null
	var p := RuntimePartner.new()
	p.partner_config_id = partner_config_id
	p.position = position
	p.current_level = 1
	p.is_active = true
	_partners.append(p)
	EventBus.emit_signal("partner_unlocked", str(partner_config_id), config.get("name", ""), position, 0, "")
	return p


func get_hero() -> RuntimeHero:
	return _hero


func get_partners() -> Array[RuntimePartner]:
	return _partners


func get_masteries() -> Array[RuntimeMastery]:
	return _masteries


func get_mastery_by_attr(attr_type: int) -> RuntimeMastery:
	for m in _masteries:
		if m.attr_type == attr_type:
			return m
	return null


func modify_hero_stats(stat_changes: Dictionary) -> void:
	if _hero == null:
		return
	var old_values: Dictionary = _get_hero_stats_dict()
	for attr_code in stat_changes.keys():
		var delta: int = stat_changes[attr_code]
		match int(attr_code):
			1: _hero.current_vit = maxi(1, _hero.current_vit + delta)
			2: _hero.current_str = maxi(1, _hero.current_str + delta)
			3: _hero.current_agi = maxi(1, _hero.current_agi + delta)
			4: _hero.current_tec = maxi(1, _hero.current_tec + delta)
			5: _hero.current_mnd = maxi(1, _hero.current_mnd + delta)
	_hero.max_hp = _calculate_max_hp(_hero.current_vit)
	_hero.current_hp = mini(_hero.current_hp, _hero.max_hp)
	var changes: Dictionary = _compute_stat_changes(old_values, _get_hero_stats_dict())
	if not changes.is_empty():
		EventBus.emit_signal("stats_changed", _hero.id, changes)


func upgrade_partner(partner_config_id: int) -> bool:
	for p in _partners:
		if p.partner_config_id == partner_config_id:
			if p.current_level < 5:
				var old_level: int = p.current_level
				p.current_level += 1
				var config: Dictionary = ConfigManager.get_partner_config(str(partner_config_id))
				# v2: 发射等级变更事件（事件驱动架构）
				EventBus.emit_signal("partner_level_changed", str(partner_config_id), old_level, p.current_level)
				if p.current_level == 3:
					EventBus.emit_signal("partner_evolved", str(partner_config_id), config.get("name", ""), p.current_level, "", "LV3_QUALITATIVE")
				return true
			return false
	return false


func apply_buff(buff: RuntimeBuff) -> void:
	_buffs.append(buff)
	EventBus.emit_signal("buff_applied", buff.target_id, buff.id, buff.buff_name, buff.duration_total, "", "BUFF")


func remove_buff(buff_id: String) -> void:
	for i in range(_buffs.size() - 1, -1, -1):
		if _buffs[i].id == buff_id:
			var b: RuntimeBuff = _buffs[i]
			_buffs.remove_at(i)
			EventBus.emit_signal("buff_removed", b.target_id, b.id, b.buff_name, "expired")


func update_mastery_stage(attr_type: int) -> void:
	var m: RuntimeMastery = get_mastery_by_attr(attr_type)
	if m == null:
		return
	var count: int = m.training_count
	var new_stage: int = 1
	var new_bonus: int = 0
	if count >= 7:
		new_stage = 4
		new_bonus = 5
	elif count >= 4:
		new_stage = 3
		new_bonus = 4
	elif count >= 1:
		new_stage = 2
		new_bonus = 2
	else:
		new_stage = 1
		new_bonus = 0
	if m.stage != new_stage:
		m.stage = new_stage
		m.training_bonus = new_bonus
		EventBus.emit_signal("proficiency_stage_changed", attr_type, _attr_name(attr_type), _stage_name(new_stage), count)


func get_secondary_attr(attr_type: int) -> int:
	return _SECONDARY_ATTR_MAP.get(attr_type, 0)


## 获取战斗准备数据（原始运行时数据，不构造战斗Dictionary）
## 战斗单位构造应由调用方（如BattleEngine或RunController）负责
func get_battle_ready_team() -> Dictionary:
	if _hero == null:
		return {"hero": null, "partners": []}
	return {
		"hero": _hero,
		"partners": _partners.duplicate(),
	}


# --- 私有方法 ---

func _calculate_max_hp(vit: int) -> int:
	# 每点体魄 = 10 HP
	return vit * 10


func _get_hero_stats_dict() -> Dictionary:
	return {
		1: _hero.current_vit,
		2: _hero.current_str,
		3: _hero.current_agi,
		4: _hero.current_tec,
		5: _hero.current_mnd,
	}


func _get_hero_stat_changes() -> Dictionary:
	return {
		1: {"old": 0, "new": _hero.current_vit, "delta": _hero.current_vit, "attr_code": 1},
		2: {"old": 0, "new": _hero.current_str, "delta": _hero.current_str, "attr_code": 2},
		3: {"old": 0, "new": _hero.current_agi, "delta": _hero.current_agi, "attr_code": 3},
		4: {"old": 0, "new": _hero.current_tec, "delta": _hero.current_tec, "attr_code": 4},
		5: {"old": 0, "new": _hero.current_mnd, "delta": _hero.current_mnd, "attr_code": 5},
	}


func _compute_stat_changes(old_values: Dictionary, new_values: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	for attr_code in new_values.keys():
		var old_v: int = old_values.get(attr_code, 0)
		var new_v: int = new_values[attr_code]
		if old_v != new_v:
			changes[attr_code] = {"old": old_v, "new": new_v, "delta": new_v - old_v, "attr_code": attr_code}
	return changes


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
