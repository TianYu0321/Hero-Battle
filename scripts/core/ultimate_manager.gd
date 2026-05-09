## res://scripts/core/ultimate_manager.gd
## 模块: UltimateManager
## 职责: 必杀技管理（勇者终结一击/影舞者风暴乱舞/铁卫不动如山）
## 依赖: DamageCalculator, ConfigManager
## 被依赖: BattleEngine
## class_name: UltimateManager

class_name UltimateManager
extends RefCounted

var _dc: DamageCalculator
var _rng: RandomNumberGenerator

func _init(dc: DamageCalculator, rng: RandomNumberGenerator):
	_dc = dc
	_rng = rng

func _get_ultimate_skill_config(hero: Dictionary) -> Dictionary:
	var hero_id: String = hero.get("hero_id", "")
	var hero_cfg: Dictionary = ConfigManager.get_hero_config(hero_id)
	var skill_id: String = str(hero_cfg.get("ultimate_skill_id", 0))
	return ConfigManager.get_skill_config(skill_id)

## 检查并触发必杀技
## 返回 {triggered: bool, packets: Array[Dictionary], log: String}
func check_and_trigger(hero: Dictionary, enemies: Array, turn_number: int) -> Dictionary:
	if hero.get("ultimate_used", false):
		return {"triggered": false, "packets": [], "log": ""}

	var hero_id: String = hero.get("hero_id", "")
	var result: Dictionary = {"triggered": false, "packets": [], "log": ""}
	var ult_cfg: Dictionary = _get_ultimate_skill_config(hero)

	match hero_id:
		"hero_warrior":
			result = _check_brave_ultimate(hero, enemies, ult_cfg)
		"hero_shadow_dancer":
			result = _check_shadow_ultimate(hero, enemies, turn_number, ult_cfg)
		"hero_iron_guard":
			result = _check_iron_ultimate(hero, enemies, ult_cfg)

	if result.triggered:
		hero.ultimate_used = true
	return result

## 勇者: 敌方首次低于阈值血触发
func _check_brave_ultimate(hero: Dictionary, enemies: Array, ult_cfg: Dictionary) -> Dictionary:
	var target = _get_lowest_hp_enemy(enemies)
	if target == null:
		return {"triggered": false, "packets": [], "log": ""}
	var trigger_params: Dictionary = ult_cfg.get("trigger_params", {})
	var hp_threshold: float = trigger_params.get("hp_threshold", 0.40)
	var hp_ratio: float = float(target.get("hp", 0)) / max(target.get("max_hp", 1), 1)
	if hp_ratio > hp_threshold:
		return {"triggered": false, "packets": [], "log": ""}

	var power_scale: float = ult_cfg.get("power_scale", 3.0)
	var ignore_def_ratio: float = trigger_params.get("ignore_def_ratio", 0.30)
	var pkt: Dictionary = _dc.compute_damage(hero, target, power_scale, "ULTIMATE", ignore_def_ratio)
	_dc.apply_damage_packet(target, pkt)
	return {
		"triggered": true,
		"packets": [pkt],
		"log": "勇者发动【终结一击】！",
	}

## 影舞者: 固定回合触发，多段攻击
func _check_shadow_ultimate(hero: Dictionary, enemies: Array, turn_number: int, ult_cfg: Dictionary) -> Dictionary:
	var trigger_params: Dictionary = ult_cfg.get("trigger_params", {})
	var fixed_turn: int = trigger_params.get("fixed_turn", 8)
	if turn_number != fixed_turn:
		return {"triggered": false, "packets": [], "log": ""}
	var target = _get_front_enemy(enemies)
	if target == null:
		return {"triggered": false, "packets": [], "log": ""}

	var segment_count: int = trigger_params.get("segment_count", 6)
	var power_scale: float = ult_cfg.get("power_scale", 0.4)
	var packets: Array[Dictionary] = []
	for i in range(segment_count):
		if not target.get("is_alive", false):
			break
		var pkt: Dictionary = _dc.compute_damage(hero, target, power_scale, "ULTIMATE")
		packets.append(pkt)
		_dc.apply_damage_packet(target, pkt)
	return {
		"triggered": true,
		"packets": packets,
		"log": "影舞者发动【风暴乱舞】！%d段连击！" % segment_count,
	}

## 铁卫: 自身首次低于阈值血触发，获得Buff
func _check_iron_ultimate(hero: Dictionary, _enemies: Array, ult_cfg: Dictionary) -> Dictionary:
	var trigger_params: Dictionary = ult_cfg.get("trigger_params", {})
	var hp_threshold: float = trigger_params.get("hp_threshold", 0.50)
	var hp_ratio: float = float(hero.get("hp", 0)) / max(hero.get("max_hp", 1), 1)
	if hp_ratio > hp_threshold:
		return {"triggered": false, "packets": [], "log": ""}

	var buff_duration: int = trigger_params.get("buff_duration", 3)
	var damage_reduction: float = trigger_params.get("damage_reduction", 0.40)
	var counter_prob_override: float = trigger_params.get("counter_prob_override", 1.0)
	var stun_prob: float = trigger_params.get("stun_prob", 0.25)

	var buff: Dictionary = {
		"buff_id": "iron_guard_ultimate",
		"name": "不动如山",
		"duration": buff_duration,
		"effects": {
			"damage_reduction": damage_reduction,
			"counter_prob_override": counter_prob_override,
			"stun_prob": stun_prob,
		}
	}
	var buff_list: Array = hero.get("buff_list", [])
	buff_list.append(buff)
	hero.buff_list = buff_list
	return {
		"triggered": true,
		"packets": [],
		"log": "铁卫发动【不动如山】！%d回合减伤%d%%，反击100%%！" % [buff_duration, int(damage_reduction * 100)],
	}

func _get_lowest_hp_enemy(enemies: Array) -> Dictionary:
	var lowest: Dictionary = {}
	for e in enemies:
		if e.get("is_alive", false):
			if lowest.is_empty() or e.get("hp", 0) < lowest.get("hp", 0):
				lowest = e
	return lowest

func _get_front_enemy(enemies: Array) -> Dictionary:
	for e in enemies:
		if e.get("is_alive", false):
			return e
	return {}
