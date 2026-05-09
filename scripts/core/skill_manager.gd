## res://scripts/core/skill_manager.gd
## 模块: SkillManager
## 职责: 主角被动技能管理（勇者追击斩/影舞者疾风连击/铁卫铁壁反击）
## 依赖: DamageCalculator, ConfigManager
## 被依赖: BattleEngine
## class_name: SkillManager

class_name SkillManager
extends RefCounted

var _dc: DamageCalculator
var _rng: RandomNumberGenerator

func _init(dc: DamageCalculator, rng: RandomNumberGenerator):
	_dc = dc
	_rng = rng

func _get_passive_skill_config(hero: Dictionary) -> Dictionary:
	var hero_id: String = hero.get("hero_id", "")
	var hero_cfg: Dictionary = ConfigManager.get_hero_config(hero_id)
	var skill_id: String = str(hero_cfg.get("passive_skill_id", 0))
	return ConfigManager.get_skill_config(skill_id)

func _get_attr_value(stats: Dictionary, attr_code: int) -> int:
	match attr_code:
		1: return stats.get("physique", 0)
		2: return stats.get("strength", 0)
		3: return stats.get("agility", 0)
		4: return stats.get("technique", 0)
		5: return stats.get("spirit", 0)
		_: return 0

## 勇者普攻: 1段，可能触发追击斩
func brave_normal_attack(hero: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	var passive_cfg: Dictionary = _get_passive_skill_config(hero)
	var trigger_params: Dictionary = passive_cfg.get("trigger_params", {})

	# 普通攻击 1段 100%
	var pkt1: Dictionary = _dc.compute_damage(hero, target, 1.0, "NORMAL")
	packets.append(pkt1)
	_dc.apply_damage_packet(target, pkt1)

	# 追击斩判定
	if pkt1.is_miss:
		return packets

	var stats: Dictionary = hero.get("stats", {})
	var base_prob: float = trigger_params.get("base_trigger_prob", 0.3)
	var prob_attr_bonus: int = trigger_params.get("prob_attr_bonus", 4)
	var prob_attr_step: int = trigger_params.get("prob_attr_step", 10)
	var prob_attr_inc: float = trigger_params.get("prob_attr_inc", 0.02)
	var prob_max: float = trigger_params.get("prob_max", 0.5)

	var attr_val: int = _get_attr_value(stats, prob_attr_bonus)
	var prob: float = base_prob + float(attr_val / prob_attr_step) * prob_attr_inc
	prob = min(prob, prob_max)
	if _rng.randf() < prob:
		var chase_pkt: Dictionary = _dc.compute_damage(hero, target, passive_cfg.get("power_scale", 0.6), "SKILL")
		packets.append(chase_pkt)
		_dc.apply_damage_packet(target, chase_pkt)
	return packets

## 影舞者普攻: 分裂多段
func shadow_dancer_normal_attack(hero: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	var passive_cfg: Dictionary = _get_passive_skill_config(hero)
	var trigger_params: Dictionary = passive_cfg.get("trigger_params", {})

	var stats: Dictionary = hero.get("stats", {})
	var segment_min: int = trigger_params.get("segment_min", 2)
	var segment_max: int = trigger_params.get("segment_max", 4)
	var segment_attr_bonus: int = trigger_params.get("segment_attr_bonus", 3)
	var segment_attr_step: int = trigger_params.get("segment_attr_step", 20)

	var attr_val: int = _get_attr_value(stats, segment_attr_bonus)
	var segments: int = clampi(segment_min + int(attr_val / segment_attr_step), segment_min, segment_max)
	var power_scale: float = passive_cfg.get("power_scale", 0.35)
	for i in range(segments):
		var pkt: Dictionary = _dc.compute_damage(hero, target, power_scale, "NORMAL")
		packets.append(pkt)
		_dc.apply_damage_packet(target, pkt)
		if not target.get("is_alive", false):
			break
	return packets

## 铁卫普攻: 1段 100%
func iron_guard_normal_attack(hero: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	var pkt: Dictionary = _dc.compute_damage(hero, target, 1.0, "NORMAL")
	packets.append(pkt)
	_dc.apply_damage_packet(target, pkt)
	return packets

## 铁壁反击判定（铁卫受击后）
func check_iron_counter(hero: Dictionary, attacker: Dictionary, received_damage: int) -> Dictionary:
	var passive_cfg: Dictionary = _get_passive_skill_config(hero)
	var chain_tags: Array = passive_cfg.get("chain_tags", [])
	if not "反击" in chain_tags:
		return {}

	var trigger_params: Dictionary = passive_cfg.get("trigger_params", {})
	var base_prob: float = trigger_params.get("base_trigger_prob", 0.25)
	var prob_attr_bonus: int = trigger_params.get("prob_attr_bonus", 5)
	var prob_attr_step: int = trigger_params.get("prob_attr_step", 10)
	var prob_attr_inc: float = trigger_params.get("prob_attr_inc", 0.02)
	var prob_max: float = trigger_params.get("prob_max", 0.5)
	var stun_prob: float = trigger_params.get("stun_prob", 0.10)

	var prob: float = base_prob
	var buff_list: Array = hero.get("buff_list", [])
	var counter_override: float = -1.0
	for buff in buff_list:
		if buff.get("effects", {}).has("counter_prob_override"):
			counter_override = buff.effects.counter_prob_override
			break

	if counter_override >= 0.0:
		prob = counter_override
	else:
		var stats: Dictionary = hero.get("stats", {})
		var attr_val: int = _get_attr_value(stats, prob_attr_bonus)
		prob += float(attr_val / prob_attr_step) * prob_attr_inc
		prob = min(prob, prob_max)

	if _rng.randf() >= prob:
		return {}

	var counter_pkt: Dictionary = _dc.compute_counter_damage(received_damage, attacker, hero)
	# 检查 buff 中是否有眩晕概率覆盖
	for buff in buff_list:
		if buff.get("effects", {}).has("stun_prob"):
			stun_prob = buff.effects.stun_prob
			break

	if _rng.randf() < stun_prob:
		counter_pkt.stun_applied = true
		if not attacker.buffs.has("stun"):
			attacker.buffs.append({"id": "stun", "name": "眩晕", "duration": 1, "effect_desc": "下回合跳过行动"})
	return counter_pkt

## 根据主角职业执行普攻
func execute_hero_normal_attack(hero: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var hero_id: String = hero.get("hero_id", "")
	match hero_id:
		"hero_warrior":
			return brave_normal_attack(hero, target)
		"hero_shadow_dancer":
			return shadow_dancer_normal_attack(hero, target)
		"hero_iron_guard":
			return iron_guard_normal_attack(hero, target)
		_:
			return iron_guard_normal_attack(hero, target)
