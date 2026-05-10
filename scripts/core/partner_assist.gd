## res://scripts/core/partner_assist.gd
## 模块: PartnerAssist
## 职责: 伙伴援助判定器，遍历5名援助伙伴，检查触发条件并执行援助
## 依赖: DamageCalculator, ConfigManager
## 被依赖: BattleEngine
## class_name: PartnerAssist

class_name PartnerAssist
extends RefCounted

var _dc: DamageCalculator
var _rng: RandomNumberGenerator

func _init(dc: DamageCalculator, rng: RandomNumberGenerator):
	_dc = dc
	_rng = rng

## 执行伙伴援助判定
## context: {hero, enemies, partners, last_action_was_crit, last_action_was_hit, hero_was_hit, turn_number}
## 返回 Array[Dictionary] 援助结果列表
func execute_assist(context: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var partners: Array = context.get("partners", [])
	var hero: Dictionary = context.get("hero", {})
	var enemies: Array = context.get("enemies", [])

	for partner in partners:
		if not partner.get("is_alive", true):
			continue
		## v2.0: 不限制伙伴援助触发次数

		var assist_cfg: Dictionary = _get_assist_config(partner)
		if assist_cfg.is_empty():
			continue

		if _check_trigger_condition(assist_cfg, context):
			var result: Dictionary = _execute_assist_action(partner, assist_cfg, hero, enemies)
			if not result.is_empty():
				result.partner_id = partner.get("partner_id", "")
				result.partner_name = partner.get("partner_name", "")
				results.append(result)
	return results

func _get_assist_config(partner: Dictionary) -> Dictionary:
	var pid: String = partner.get("partner_id", "")
	return ConfigManager.get_partner_assist_by_partner_id(pid)

func _check_trigger_condition(cfg: Dictionary, ctx: Dictionary) -> bool:
	var condition: String = cfg.get("trigger_condition", "")
	var prob: float = cfg.get("trigger_prob", 0.0)

	# 检查影舞者必杀技的伙伴概率提升
	var hero: Dictionary = ctx.get("hero", {})
	var boost_mult: float = 1.0
	if hero.get("partner_boost_active", false):
		boost_mult = hero.get("partner_boost_multiplier", 1.0)
		hero["partner_boost_active"] = false  # 一次性效果

	# 固定概率触发 (剑士30%/术士30%)
	if condition == "主角攻击后" or condition == "每回合概率触发":
		if ctx.get("hero_attacked", false):
			return _rng.randf() < prob * boost_mult
		return false

	# 暴击后触发 (斥候)
	if condition == "主角暴击后":
		return ctx.get("last_action_was_crit", false)

	# 受击后触发 (盾卫)
	if condition == "主角受击后":
		return ctx.get("hero_was_hit", false)

	# 低血条件触发 (药师30%/猎人40%)
	if condition.begins_with("主角HP<"):
		var threshold: float = 0.30
		if "40%" in condition:
			threshold = 0.40
		var hero_hp_ratio: float = float(ctx.hero.get("hp", 0)) / max(ctx.hero.get("max_hp", 1), 1)
		return hero_hp_ratio < threshold

	# 敌方低血触发 (猎人)
	if condition == "敌方HP<40%":
		for e in ctx.enemies:
			var ratio: float = float(e.get("hp", 0)) / max(e.get("max_hp", 1), 1)
			if ratio < 0.40 and e.get("is_alive", false):
				return true
		return false

	return false

func _execute_assist_action(partner: Dictionary, cfg: Dictionary, hero: Dictionary, enemies: Array) -> Dictionary:
	var effect_type: int = cfg.get("effect_type", 1)
	var scale: float = cfg.get("effect_scale_lv1", 0.5)
	var attr: int = cfg.get("effect_attr", 2)
	var attr_key: String = _attr_code_to_key(attr)
	var result: Dictionary = {"type": "damage", "value": 0, "target": "", "log": ""}

	# v2: 伙伴援助效果基于主角属性，而非伙伴自身属性
	var hero_stats: Dictionary = hero.get("stats", {})
	var hero_as_attacker: Dictionary = {
		"unit_id": hero.get("unit_id", "hero"),
		"name": hero.get("name", "主角"),
		"stats": hero_stats,
		"is_alive": hero.get("is_alive", true),
	}
	var hero_max_hp: int = hero.get("max_hp", 100)

	match effect_type:
		1:  # 造成伤害
			var target = _get_front_enemy(enemies)
			if target == null:
				return {}
			# 剑气斩等 = 主角攻击力 × scale
			var pkt: Dictionary = _dc.compute_damage(hero_as_attacker, target, scale, "ASSIST")
			_dc.apply_damage_packet(target, pkt)
			result.type = "damage"
			result.value = pkt.value
			result.target = target.get("unit_id", "")
			result.log = "%s 触发援助【%s】造成 %d 伤害" % [partner.get("partner_name", ""), cfg.get("trigger_condition", ""), pkt.value]
		2:  # 治疗
			# 药师等 = 主角最大生命 × scale（如15%）
			var heal_val: int = max(int(hero_max_hp * scale), 1)
			_dc.apply_heal(hero, heal_val)
			result.type = "heal"
			result.value = heal_val
			result.target = hero.get("unit_id", "")
			result.log = "%s 触发治疗，回复 %d HP" % [partner.get("partner_name", ""), heal_val]
		3:  # 护盾
			# 盾卫等 = 主角最大生命 × scale（如30%吸收量）
			var shield_val: int = max(int(hero_max_hp * scale), 1)
			# 护盾简化为治疗（实际应在BattleEngine中实现护盾buff）
			_dc.apply_heal(hero, shield_val)
			result.type = "shield"
			result.value = shield_val
			result.target = hero.get("unit_id", "")
			result.log = "%s 提供护盾，吸收 %d 伤害" % [partner.get("partner_name", ""), shield_val]
		5:  # DEBUFF (简化为伤害)
			var target = _get_front_enemy(enemies)
			if target == null:
				return {}
			var debuff_pkt: Dictionary = _dc.compute_damage(hero_as_attacker, target, scale, "ASSIST")
			_dc.apply_damage_packet(target, debuff_pkt)
			result.type = "debuff_damage"
			result.value = debuff_pkt.value
			result.target = target.get("unit_id", "")
			result.log = "%s 施加干扰，造成 %d 伤害" % [partner.get("partner_name", ""), debuff_pkt.value]
	return result

func _attr_code_to_key(code: int) -> String:
	match code:
		1: return "physique"
		2: return "strength"
		3: return "agility"
		4: return "technique"
		5: return "spirit"
		_: return "strength"

func _get_front_enemy(enemies: Array) -> Dictionary:
	for e in enemies:
		if e.get("is_alive", false):
			return e
	return {}

## 为伙伴生成战斗用 Dictionary（简化版）
static func make_partner_battle_unit(partner_id: String, partner_name: String, stats: Dictionary) -> Dictionary:
	return {
		"unit_id": "partner_%s" % partner_id,
		"partner_id": partner_id,
		"partner_name": partner_name,
		"unit_type": "PARTNER",
		"stats": stats.duplicate(),
		"is_alive": true,
		"assist_count": 0,
		"chain_count": 0,
	}
