## res://scripts/core/battle_result.gd
## 模块: BattleResult
## 职责: 战斗结果统计与胜负判定
## 依赖: 无
## 被依赖: BattleEngine
## class_name: BattleResult

class_name BattleResult
extends RefCounted

var winner: String = ""  # "player" | "enemy"
var turns_elapsed: int = 0
var mvp_partner: String = ""
var combat_log: Array[String] = []
var drop_rewards: Array = []
var chain_stats: Dictionary = {"max_chain": 0, "total_chains": 0}
var ultimate_triggered: bool = false
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var partner_assist_count: Dictionary = {}
var hero_remaining_hp: int = 0
var enemy_remaining_hp: int = 0

func determine_winner(hero: Dictionary, enemies: Array, turn_count: int, max_turns: int) -> String:
	var hero_alive: bool = hero.get("is_alive", false)
	var any_enemy_alive: bool = false
	var total_enemy_hp: int = 0
	for e in enemies:
		if e.get("is_alive", false):
			any_enemy_alive = true
			total_enemy_hp += e.get("hp", 0)

	if not hero_alive:
		winner = "enemy"
		return winner
	if not any_enemy_alive:
		winner = "player"
		return winner
	if turn_count >= max_turns:
		# 按血量比例判定
		var hero_hp_ratio: float = float(hero.get("hp", 0)) / max(hero.get("max_hp", 1), 1)
		var enemy_hp_ratio: float = float(total_enemy_hp)
		var enemy_max_hp_total: int = 0
		for e in enemies:
			enemy_max_hp_total += e.get("max_hp", 1)
		enemy_hp_ratio /= max(enemy_max_hp_total, 1)
		winner = "player" if hero_hp_ratio >= enemy_hp_ratio else "enemy"
		return winner
	winner = ""
	return winner

func finalize(hero: Dictionary, enemies: Array, partners: Array) -> Dictionary:
	# 计算 MVP 伙伴（援助次数最多）
	var max_assists: int = 0
	for pid in partner_assist_count:
		if partner_assist_count[pid] > max_assists:
			max_assists = partner_assist_count[pid]
			mvp_partner = pid

	hero_remaining_hp = hero.get("hp", 0)
	for e in enemies:
		enemy_remaining_hp += e.get("hp", 0)

	# 计算对敌人造成的伤害和敌人最大HP（取第一个敌人）
	var damage_dealt_to_enemy: int = 0
	var enemy_max_hp: int = 0
	if enemies.size() > 0:
		var first_enemy: Dictionary = enemies[0]
		enemy_max_hp = first_enemy.get("max_hp", 0)
		damage_dealt_to_enemy = enemy_max_hp - first_enemy.get("hp", 0)

	return {
		"winner": winner,
		"turns_elapsed": turns_elapsed,
		"mvp_partner": mvp_partner,
		"combat_log": combat_log.duplicate(),
		"drop_rewards": drop_rewards.duplicate(),
		"chain_stats": chain_stats.duplicate(),
		"ultimate_triggered": ultimate_triggered,
		"total_damage_dealt": total_damage_dealt,
		"total_damage_taken": total_damage_taken,
		"hero_remaining_hp": hero_remaining_hp,
		"hero_max_hp": hero.get("max_hp", 100),
		"damage_dealt_to_enemy": damage_dealt_to_enemy,
		"enemy_max_hp": enemy_max_hp,
	}

## 转换为字典（供调用方使用）
func to_dict() -> Dictionary:
	return {
		"winner": winner,
		"turns_elapsed": turns_elapsed,
		"mvp_partner": mvp_partner,
		"combat_log": combat_log.duplicate(),
		"drop_rewards": drop_rewards.duplicate(),
		"chain_stats": chain_stats.duplicate(),
		"ultimate_triggered": ultimate_triggered,
		"total_damage_dealt": total_damage_dealt,
		"total_damage_taken": total_damage_taken,
		"partner_assist_count": partner_assist_count.duplicate(),
		"hero_remaining_hp": hero_remaining_hp,
		"enemy_remaining_hp": enemy_remaining_hp,
	}

func add_log(msg: String) -> void:
	combat_log.append(msg)

func record_chain(chain_length: int) -> void:
	chain_stats.total_chains += 1
	if chain_length > chain_stats.max_chain:
		chain_stats.max_chain = chain_length

func record_partner_assist(partner_id: String) -> void:
	if not partner_assist_count.has(partner_id):
		partner_assist_count[partner_id] = 0
	partner_assist_count[partner_id] += 1
