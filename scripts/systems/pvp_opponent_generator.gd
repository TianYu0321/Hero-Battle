## res://scripts/systems/pvp_opponent_generator.gd
## 模块: PvpOpponentGenerator
## 职责: AI对手生成器：复制玩家数据 → 应用乘数+扰动 → 生成可传入 BattleEngine 的对手队伍
## 依赖: DamageCalculator, ConfigManager, PartnerAssist
## class_name: PvpOpponentGenerator

class_name PvpOpponentGenerator
extends RefCounted


func generate_opponent(player_state: Dictionary, turn_number: int) -> Dictionary:
	var template: Dictionary = _select_template(turn_number)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = player_state.get("run_seed", 0) + turn_number

	var player_hero: Dictionary = player_state.get("player_hero", {})
	var ai_hero: Dictionary = _generate_ai_hero(player_hero, template, rng)
	var ai_partners: Array = _generate_ai_partners(template, rng)
	var player_battle_unit: Dictionary = _generate_player_enemy(player_hero)

	return {
		"hero": ai_hero,
		"enemies": [player_battle_unit],
		"partners": ai_partners,
		"battle_seed": player_state.get("run_seed", 0) + turn_number,
		"playback_mode": "fast_forward",
	}


func _select_template(turn_number: int) -> Dictionary:
	var template_id: String = "pvp_early"
	if turn_number >= 20:
		template_id = "pvp_mid"
	var template: Dictionary = ConfigManager.get_pvp_opponent_template(template_id)
	if template.is_empty():
		push_warning("[PvpOpponentGenerator] Template not found: %s, using defaults" % template_id)
		return {
			"hero_stat_multiplier": 0.90,
			"hero_stat_variance": 0.05,
			"partner_count": 3,
			"partner_stat_multiplier": 0.85,
			"partner_stat_variance": 0.10,
		}
	return template


func _generate_ai_hero(player_hero: Dictionary, template: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var multiplier: float = template.get("hero_stat_multiplier", 0.90)
	var variance: float = template.get("hero_stat_variance", 0.05)

	var stats: Dictionary = player_hero.get("stats", {}).duplicate()
	for key in stats.keys():
		var base: int = int(stats[key])
		var scaled: float = base * multiplier
		var v: float = scaled * variance
		var final_val: int = int(round(scaled + rng.randf_range(-v, v)))
		stats[key] = maxi(1, final_val)

	var hero_id: String = player_hero.get("hero_id", "hero_warrior")
	var ai_hero: Dictionary = DamageCalculator.spawn_hero(hero_id, stats)
	ai_hero.hp = ai_hero.max_hp
	ai_hero.name = _generate_opponent_name(rng)
	return ai_hero


func _generate_ai_partners(template: Dictionary, rng: RandomNumberGenerator) -> Array:
	var partner_count: int = template.get("partner_count", 3)
	var multiplier: float = template.get("partner_stat_multiplier", 0.85)
	var variance: float = template.get("partner_stat_variance", 0.10)

	var all_partner_ids: Array[String] = ConfigManager.get_all_partner_ids()
	if all_partner_ids.is_empty():
		return []

	var selected: Array[String] = []
	while selected.size() < partner_count and selected.size() < all_partner_ids.size():
		var pid: String = all_partner_ids[rng.randi() % all_partner_ids.size()]
		if not selected.has(pid):
			selected.append(pid)

	var partners: Array = []
	for pid in selected:
		var pcfg: Dictionary = ConfigManager.get_partner_config(pid)
		var stats: Dictionary = {
			"physique": pcfg.get("base_physique", 10),
			"strength": pcfg.get("base_strength", 10),
			"agility": pcfg.get("base_agility", 10),
			"technique": pcfg.get("base_technique", 10),
			"spirit": pcfg.get("base_spirit", 10),
		}
		for key in stats.keys():
			var base: int = int(stats[key])
			var scaled: float = base * multiplier
			var v: float = scaled * variance
			stats[key] = maxi(1, int(round(scaled + rng.randf_range(-v, v))))
		var p_name: String = pcfg.get("name", pid)
		partners.append(PartnerAssist.make_partner_battle_unit(pid, p_name, stats))
	return partners


func _generate_player_enemy(player_hero: Dictionary) -> Dictionary:
	var unit: Dictionary = player_hero.duplicate(true)
	unit["unit_id"] = "enemy_player"
	unit["unit_type"] = "ENEMY"
	unit["name"] = "玩家镜像"
	unit["special_mechanic"] = ""
	return unit


func _generate_opponent_name(rng: RandomNumberGenerator) -> String:
	var prefixes: Array[String] = ["AI_挑战者", "AI_竞技者", "AI_决斗者", "AI_斗技者", "AI_试炼者"]
	var prefix: String = prefixes[rng.randi() % prefixes.size()]
	var suffix: String = "%03d" % (rng.randi() % 1000)
	if rng.randf() < 0.3:
		var letters: Array[String] = ["A", "B", "C", "X", "Y", "Z"]
		suffix = letters[rng.randi() % letters.size()] + str(rng.randi() % 10)
	return "%s_%s" % [prefix, suffix]
