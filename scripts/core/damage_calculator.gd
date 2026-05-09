## res://scripts/core/damage_calculator.gd
## 模块: DamageCalculator
## 职责: 伤害计算管道，从属性系数到最终扣血的全流程
## 依赖: ConfigManager
## 被依赖: BattleEngine, SkillManager, PartnerAssist, ChainTrigger, EnemyAI
## class_name: DamageCalculator

class_name DamageCalculator
extends RefCounted

var _rng: RandomNumberGenerator
var _formula: Dictionary = {}

func _init(battle_seed: int):
	_rng = RandomNumberGenerator.new()
	_rng.seed = battle_seed
	_formula = ConfigManager.get_battle_formula_config()
	if _formula.is_empty():
		push_warning("[DamageCalculator] No formula config found, using defaults")
		_formula = _default_formula()

static func _default_formula() -> Dictionary:
	return {
		"atk_from_str": 1.0,
		"def_from_vit": 1.0,
		"hp_from_vit": 10.0,
		"speed_from_agi": 1.0,
		"crit_rate_base": 0.05,
		"crit_dmg_multiplier": 1.5,
		"dmg_rand_min": 0.9,
		"dmg_rand_max": 1.1,
	}

## 计算单位的 Max HP（基于体魄）
func calc_max_hp(physique: int) -> int:
	var hp_per_vit: float = _formula.get("hp_from_vit", 10.0)
	return int(physique * hp_per_vit)

## 主伤害计算入口
## 返回 DamagePacket Dictionary
func compute_damage(attacker: Dictionary, defender: Dictionary, skill_scale: float = 1.0, damage_type: String = "NORMAL", ignore_def_ratio: float = 0.0) -> Dictionary:
	var pkt: Dictionary = {
		"attacker_id": attacker.get("unit_id", ""),
		"defender_id": defender.get("unit_id", ""),
		"damage_type": damage_type,
		"skill_scale": skill_scale,
		"value": 0,
		"is_crit": false,
		"is_miss": false,
		"is_dodge": false,
	}

	var atk_stats: Dictionary = attacker.get("stats", {})
	var def_stats: Dictionary = defender.get("stats", {})

	# ---- 阶段0-1: 属性系数 ----
	var power_coeff: float = _formula.get("atk_from_str", 1.0)
	var tech_coeff: float = _formula.get("atk_from_str", 1.0)  # 同力量系数
	var str_val: int = atk_stats.get("strength", 0)
	var tec_val: int = atk_stats.get("technique", 0)
	var attr_coeff: float = str_val * power_coeff + tec_val * tech_coeff

	# ---- 阶段2: 技能倍率 (已传入) ----
	# ---- 阶段3: 随机波动 ----
	var fluctuation: float = _rng.randf_range(
		_formula.get("dmg_rand_min", 0.9),
		_formula.get("dmg_rand_max", 1.1)
	)

	var raw_damage: float = attr_coeff * skill_scale * fluctuation
	if raw_damage <= 0.0:
		raw_damage = 1.0

	# ---- 阶段4: 命中判定 ----
	var hit_rate: float = _calc_hit_rate(atk_stats, def_stats)
	var hit_roll: float = _rng.randf()
	if hit_roll > hit_rate:
		pkt.is_miss = true
		return pkt

	# ---- 暗影刺客特殊闪避 (30%闪避普攻) ----
	if damage_type == "NORMAL" and defender.get("special_mechanic", "").begins_with("闪避"):
		if _rng.randf() < 0.30:
			pkt.is_miss = true
			pkt.is_dodge = true
			return pkt

	# ---- 阶段5: 暴击判定 ----
	var crit_rate: float = _calc_crit_rate(atk_stats)
	var crit_roll: float = _rng.randf()
	if crit_roll < crit_rate:
		raw_damage *= _formula.get("crit_dmg_multiplier", 1.5)
		pkt.is_crit = true

	# ---- 阶段6: 防御减伤 ----
	var vit_def: int = def_stats.get("physique", 0)
	var def_coeff: float = _formula.get("def_from_vit", 1.0)
	var def_value: float = vit_def * def_coeff * (1.0 - ignore_def_ratio)

	# 保底机制: 至少造成5%原始伤害
	var min_damage: float = raw_damage * 0.05
	var final_damage: float = max(raw_damage - def_value, min_damage)
	final_damage = max(final_damage, 1.0)

	# 检查 defender 的 buff 中是否有 damage_reduction（铁卫不动如山等）
	var buff_list: Array = defender.get("buff_list", [])
	for buff in buff_list:
		var effects: Dictionary = buff.get("effects", {})
		if effects.has("damage_reduction"):
			final_damage *= (1.0 - effects.damage_reduction)
			break

	# 重甲守卫减伤25%
	if defender.get("special_mechanic", "").begins_with("坚甲"):
		final_damage *= 0.75

	# 混沌领主成长加成 (在战斗引擎中通过 stats 更新实现，这里只读 stats)

	pkt.value = int(round(final_damage))
	return pkt

## 计算铁壁反击伤害 (反弹受到伤害的50%)
func compute_counter_damage(original_damage: int, attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var counter_dmg: int = max(int(original_damage * 0.5), 1)
	var pkt: Dictionary = {
		"attacker_id": defender.get("unit_id", ""),
		"defender_id": attacker.get("unit_id", ""),
		"damage_type": "COUNTER",
		"skill_scale": 0.5,
		"value": counter_dmg,
		"is_crit": false,
		"is_miss": false,
		"is_dodge": false,
	}
	return pkt

## 计算治疗量
func compute_heal(caster: Dictionary, target: Dictionary, heal_scale: float, base_attr: String = "spirit") -> int:
	var caster_stats: Dictionary = caster.get("stats", {})
	var base_val: int = caster_stats.get(base_attr, 0)
	var heal_val: float = base_val * heal_scale * _rng.randf_range(0.9, 1.1)
	return max(int(round(heal_val)), 1)

## 应用伤害到目标
func apply_damage_packet(target: Dictionary, pkt: Dictionary) -> void:
	if pkt.is_miss:
		return
	var new_hp: int = target.get("hp", 0) - pkt.value
	new_hp = max(new_hp, 0)
	target.hp = new_hp
	if new_hp <= 0:
		target.is_alive = false

## 应用治疗
func apply_heal(target: Dictionary, amount: int) -> void:
	var new_hp: int = min(target.get("hp", 0) + amount, target.get("max_hp", 0))
	target.hp = new_hp

func _calc_hit_rate(atk_stats: Dictionary, def_stats: Dictionary) -> float:
	var base: float = 0.95
	var diff: int = atk_stats.get("technique", 0) - def_stats.get("agility", 0)
	var bonus: float = diff * 0.005
	return clampf(base + bonus, 0.1, 1.0)

func _calc_crit_rate(atk_stats: Dictionary) -> float:
	var base: float = _formula.get("crit_rate_base", 0.05)
	var tec: int = atk_stats.get("technique", 0)
	var bonus: float = tec * 0.002
	return clampf(base + bonus, 0.0, 1.0)

## 生成敌人实例属性（从配置 + 主角属性缩放）
static func spawn_enemy(enemy_config: Dictionary, hero_stats: Dictionary) -> Dictionary:
	var enemy: Dictionary = {
		"unit_id": "enemy_%s" % str(enemy_config.get("id", 0)),
		"name": enemy_config.get("name", "敌人"),
		"unit_type": "ENEMY",
		"is_alive": true,
		"buffs": [],
		"special_mechanic": enemy_config.get("special_mechanic", ""),
	}
	var stats: Dictionary = {}
	var attr_map: Dictionary = {
		"physique": ["vit_base", "vit_scale_hero_attr", "vit_scale_hero_coeff"],
		"strength": ["str_base", "str_scale_hero_attr", "str_scale_hero_coeff"],
		"agility": ["agi_base", "agi_scale_hero_attr", "agi_scale_hero_coeff"],
		"technique": ["tec_base", "tec_scale_hero_attr", "tec_scale_hero_coeff"],
		"spirit": ["spi_base", "spi_scale_hero_attr", "spi_scale_hero_coeff"],
	}
	var hero_attr_keys: Array[String] = ["", "physique", "strength", "agility", "technique", "spirit"]
	for attr in attr_map:
		var keys: Array = attr_map[attr]
		var base: int = enemy_config.get(keys[0], 0)
		var hero_attr_idx: int = enemy_config.get(keys[1], 0)
		var coeff: float = enemy_config.get(keys[2], 0.0)
		var scaled: int = 0
		if hero_attr_idx >= 1 and hero_attr_idx <= 5:
			scaled = int(hero_stats.get(hero_attr_keys[hero_attr_idx], 0) * coeff)
		stats[attr] = base + scaled
	enemy.stats = stats
	var dc: DamageCalculator = DamageCalculator.new(randi())
	enemy.max_hp = dc.calc_max_hp(stats.get("physique", 10))
	enemy.hp = enemy.max_hp
	return enemy

## 生成主角战斗实例
static func spawn_hero(hero_id: String, hero_stats: Dictionary) -> Dictionary:
	var dc: DamageCalculator = DamageCalculator.new(randi())
	var hero: Dictionary = {
		"unit_id": "hero",
		"name": hero_id,
		"unit_type": "HERO",
		"hero_id": hero_id,
		"stats": hero_stats.duplicate(),
		"is_alive": true,
		"hp": 0,
		"max_hp": 0,
		"buffs": [],
		"ultimate_used": false,
		"buff_list": [],
	}
	hero.max_hp = dc.calc_max_hp(hero_stats.get("physique", 10))
	hero.hp = hero.max_hp
	return hero
