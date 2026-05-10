## res://scripts/core/enemy_ai.gd
## 模块: EnemyAI
## 职责: 敌人AI：5种精英模板行为决策
## 依赖: DamageCalculator
## 被依赖: BattleEngine
## class_name: EnemyAI

class_name EnemyAI
extends RefCounted

var _dc: DamageCalculator
var _rng: RandomNumberGenerator

func _init(dc: DamageCalculator, rng: RandomNumberGenerator):
	_dc = dc
	_rng = rng

## 敌人行动决策与执行
## 返回 Array[Dictionary] 伤害包列表
func execute_enemy_turn(enemy: Dictionary, hero: Dictionary, turn_number: int) -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	var mechanic: String = enemy.get("special_mechanic", "")

	# 检查眩晕
	for i in range(enemy.buffs.size() - 1, -1, -1):
		var buff = enemy.buffs[i]
		if buff.get("id", "") == "stun":
			buff.duration -= 1
			if buff.duration <= 0:
				enemy.buffs.remove_at(i)
			return [{"is_stunned": true, "log": "%s 眩晕中，跳过行动" % enemy.get("name", "")}]

	# 元素法师：出场后第3回合力×2.5
	var skill_scale: float = 1.0
	var spawn_turn: int = enemy.get("spawn_turn", 1)
	var turns_since_spawn: int = max(turn_number - spawn_turn, 0)
	if mechanic.begins_with("蓄力爆发") and turns_since_spawn == 3:
		skill_scale = 2.5

	# 狂战士低血狂暴
	if mechanic.begins_with("狂暴"):
		var hp_ratio: float = float(enemy.get("hp", 0)) / max(enemy.get("max_hp", 1), 1)
		if hp_ratio < 0.30:
			skill_scale = 1.5

	# 混沌领主：每回合+5%全属性（线性增长，上限+45%，基于出场后回合数）
	if mechanic.begins_with("成长进化"):
		var stats: Dictionary = enemy.get("stats", {})
		var base_stats: Dictionary = enemy.get("base_stats", {})
		if base_stats.is_empty():
			# 首次调用，保存基准值
			base_stats = stats.duplicate()
			enemy["base_stats"] = base_stats
		var _spawn_turn: int = enemy.get("spawn_turn", 1)
		var _turns_since_spawn: int = max(turn_number - _spawn_turn, 0)
		var growth: float = min(0.05 * _turns_since_spawn, 0.45)  # 上限+45%
		for key in stats:
			stats[key] = int(base_stats.get(key, stats[key]) * (1.0 + growth))

	var pkt: Dictionary = _dc.compute_damage(enemy, hero, skill_scale, "NORMAL")
	packets.append(pkt)
	_dc.apply_damage_packet(hero, pkt)

	return packets
