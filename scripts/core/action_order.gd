## res://scripts/core/action_order.gd
## 模块: ActionOrder
## 职责: 每回合行动顺序计算（有效速度 + 随机波动 + 同速优先级）
## 依赖: DamageCalculator
## 被依赖: BattleEngine
## class_name: ActionOrder

class_name ActionOrder
extends RefCounted

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator):
	_rng = rng

## 计算行动顺序
## 返回 Array[Dictionary] 按行动顺序排列，每项含 {unit, effective_speed, base_agility, unit_type}
func calculate_order(hero: Dictionary, enemies: Array) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	if hero.get("is_alive", false):
		units.append({
			"unit": hero,
			"unit_type": "HERO",
			"base_agility": hero.get("stats", {}).get("agility", 0),
		})
	for e in enemies:
		if e.get("is_alive", false):
			units.append({
				"unit": e,
				"unit_type": "ENEMY",
				"base_agility": e.get("stats", {}).get("agility", 0),
			})

	# 计算有效速度
	for entry in units:
		var agi: int = entry.base_agility
		var fluctuation: float = _rng.randf_range(0.9, 1.1)
		entry.effective_speed = float(agi) * fluctuation

	# 排序: 有效速度降序 → 类型优先级(HERO>ENEMY) → 基础敏捷降序 → 随机
	units.sort_custom(_compare_action_order)
	return units

func _compare_action_order(a: Dictionary, b: Dictionary) -> bool:
	var speed_a: int = int(a.effective_speed)
	var speed_b: int = int(b.effective_speed)
	if speed_a != speed_b:
		return speed_a > speed_b
	# 同速: HERO > ENEMY
	var type_prio: Dictionary = {"HERO": 2, "ENEMY": 1}
	var pa: int = type_prio.get(a.unit_type, 0)
	var pb: int = type_prio.get(b.unit_type, 0)
	if pa != pb:
		return pa > pb
	# 同类型: 基础敏捷降序
	if a.base_agility != b.base_agility:
		return a.base_agility > b.base_agility
	# 完全相同: 随机（使用实例化RNG保证可复现性）
	return _rng.randf() < 0.5
