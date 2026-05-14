## res://scripts/systems/pvp_opponent_generator.gd
## 模块: PvpOpponentGenerator
## 职责: AI对手生成器：复制玩家数据 → 应用乘数+扰动 → 生成可传入 BattleEngine 的对手队伍
## 依赖: DamageCalculator, ConfigManager, PartnerAssist
## class_name: PvpOpponentGenerator

class_name PvpOpponentGenerator
extends RefCounted


func generate_opponent(player_state: Dictionary, turn_number: int, use_archive: bool = true, archive_pool: VirtualArchivePool = null) -> Dictionary:
	# 防御性检查
	if not player_state is Dictionary:
		push_error("[PvpOpponentGenerator] player_state 不是 Dictionary")
		player_state = {}

	if use_archive and archive_pool != null:
		var opponent_archive = archive_pool.find_opponent_for_floor(turn_number)
		# opponent_archive 可能是 {}（空Dictionary）或有效的Dictionary
		if opponent_archive is Dictionary and not opponent_archive.is_empty():
			return generate_opponent_from_archive(opponent_archive, turn_number, player_state)
		print("[PvpOpponentGenerator] 无档案匹配，fallback到AI生成")

	# fallback：原来的AI生成逻辑
	var template: Dictionary = _select_template(turn_number)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = player_state.get("run_seed", 0) + turn_number

	var raw_hero = player_state.get("player_hero", {})
	var player_hero: Dictionary
	if raw_hero is RuntimeHero:
		var hero_id: String = ConfigManager.get_hero_id_by_config_id(raw_hero.hero_config_id)
		if hero_id.is_empty():
			hero_id = "hero_warrior"
		player_hero = {
			"hero_id": hero_id,
			"stats": {
				"physique": raw_hero.current_vit,
				"strength": raw_hero.current_str,
				"agility": raw_hero.current_agi,
				"technique": raw_hero.current_tec,
				"spirit": raw_hero.current_mnd,
			},
			"max_hp": raw_hero.max_hp,
			"hp": raw_hero.current_hp,
			"buff_list": raw_hero.buff_list.duplicate(),
		}
	else:
		player_hero = raw_hero
	var ai_hero: Dictionary = _generate_ai_hero(player_hero, template, rng)
	var ai_partners: Array = _generate_ai_partners(template, rng)
	var player_battle_unit: Dictionary = _generate_player_enemy(player_hero)

	return {
		"hero": ai_hero,
		"enemies": [player_battle_unit],
		"partners": ai_partners,
		"battle_seed": player_state.get("run_seed", 0) + turn_number,
		"playback_mode": "fast_forward",
		"opponent_name": ai_hero.get("name", "AI挑战者"),
		"opponent_source": "ai",
	}


func generate_opponent_from_archive(archive_data: Dictionary, turn_number: int, player_state: Dictionary) -> Dictionary:
	# 防御性检查
	if not archive_data is Dictionary:
		push_error("[PvpOpponentGenerator] archive_data 不是 Dictionary，fallback到AI生成")
		return generate_opponent(player_state, turn_number, false)

	print("[PvpOpponentGenerator] 从档案生成对手: %s" % archive_data.get("hero_name", "???"))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = archive_data.get("archive_id", "").hash() + turn_number

	# 从档案提取英雄属性
	var hero_stats: Dictionary = {
		"physique": archive_data.get("attr_snapshot_vit", 10),
		"strength": archive_data.get("attr_snapshot_str", 10),
		"agility": archive_data.get("attr_snapshot_agi", 10),
		"technique": archive_data.get("attr_snapshot_tec", 10),
		"spirit": archive_data.get("attr_snapshot_mnd", 10),
	}
	var hero_config_id: int = archive_data.get("hero_config_id", 1)
	var hero_id: String = ConfigManager.get_hero_id_by_config_id(hero_config_id)
	if hero_id.is_empty():
		hero_id = "hero_warrior"

	var ai_hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)
	ai_hero.hp = ai_hero.max_hp
	ai_hero.name = archive_data.get("hero_name", "影子斗士")

	# 从档案提取伙伴
	var archive_partners: Array = archive_data.get("partners", [])
	var ai_partners: Array = []
	for p_data in archive_partners:
		# 防御性检查：跳过非 Dictionary 的伙伴数据
		if not p_data is Dictionary:
			push_warning("[PvpOpponentGenerator] 伙伴数据格式错误（非Dictionary），跳过")
			continue
		var pid: int = p_data.get("partner_config_id", 1001)
		var pcfg: Dictionary = ConfigManager.get_partner_config(str(pid))
		var p_name: String = pcfg.get("name", "伙伴")
		var p_level: int = p_data.get("current_level", 1)
		# 伙伴属性按等级缩放（Lv1基准 × 等级系数）
		var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(str(pid))
		var base_stats: Dictionary = {
			"physique": assist_cfg.get("base_physique", 10),
			"strength": assist_cfg.get("base_strength", 10),
			"agility": assist_cfg.get("base_agility", 10),
			"technique": assist_cfg.get("base_technique", 10),
			"spirit": assist_cfg.get("base_spirit", 10),
		}
		var level_multiplier: float = 1.0 + (p_level - 1) * 0.2
		for key in base_stats.keys():
			base_stats[key] = int(base_stats[key] * level_multiplier)
		ai_partners.append(PartnerAssist.make_partner_battle_unit(str(pid), p_name, base_stats))

	# 生成玩家镜像
	var raw_hero = player_state.get("player_hero", {})
	var player_hero: Dictionary
	if raw_hero is RuntimeHero:
		var ph_id: String = ConfigManager.get_hero_id_by_config_id(raw_hero.hero_config_id)
		if ph_id.is_empty():
			ph_id = "hero_warrior"
		player_hero = {
			"hero_id": ph_id,
			"stats": {
				"physique": raw_hero.current_vit,
				"strength": raw_hero.current_str,
				"agility": raw_hero.current_agi,
				"technique": raw_hero.current_tec,
				"spirit": raw_hero.current_mnd,
			},
			"max_hp": raw_hero.max_hp,
			"hp": raw_hero.current_hp,
			"buff_list": raw_hero.buff_list.duplicate(),
		}
	else:
		player_hero = raw_hero
	var player_battle_unit: Dictionary = _generate_player_enemy(player_hero)

	return {
		"hero": ai_hero,
		"enemies": [player_battle_unit],
		"partners": ai_partners,
		"battle_seed": rng.seed,
		"playback_mode": "fast_forward",
		"opponent_name": archive_data.get("hero_name", "影子斗士"),
		"opponent_source": "archive",
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
	unit["is_alive"] = true
	if not unit.has("buffs"):
		unit["buffs"] = []
	return unit


func _generate_opponent_name(rng: RandomNumberGenerator) -> String:
	var prefixes: Array[String] = ["AI_挑战者", "AI_竞技者", "AI_决斗者", "AI_斗技者", "AI_试炼者"]
	var prefix: String = prefixes[rng.randi() % prefixes.size()]
	var suffix: String = "%03d" % (rng.randi() % 1000)
	if rng.randf() < 0.3:
		var letters: Array[String] = ["A", "B", "C", "X", "Y", "Z"]
		suffix = letters[rng.randi() % letters.size()] + str(rng.randi() % 10)
	return "%s_%s" % [prefix, suffix]


# ==================== 影子对手生成 (Shadow PVP) ====================

func generate_pvp_opponent(player_floor: int, player_user_id: String, pool: VirtualArchivePool = null) -> Dictionary:
	if pool == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			pool = tree.root.get_node_or_null("VirtualArchivePool")
			if pool == null:
				pool = tree.root.get_node_or_null("RunController/VirtualArchivePool")

	if pool != null:
		var shadow = pool.get_random_shadow_for_floor(player_floor, player_user_id)
		if shadow != null:
			print("[PvpOpponentGenerator] 使用影子对手: user=%s, floor=%d" % [shadow.user_id, shadow.floor])
			return _build_opponent_from_shadow(shadow)

	print("[PvpOpponentGenerator] 影子池为空，使用固定AI")
	return _build_default_ai_opponent(player_floor)

func _build_opponent_from_shadow(shadow) -> Dictionary:
	var hero_cfg: Dictionary = shadow.hero_config
	var hero_id: String = ConfigManager.get_hero_id_by_config_id(hero_cfg.get("hero_config_id", 1))
	if hero_id.is_empty():
		hero_id = "hero_warrior"

	var hero_stats: Dictionary = {
		"physique": hero_cfg.get("current_vit", 10),
		"strength": hero_cfg.get("current_str", 10),
		"agility": hero_cfg.get("current_agi", 10),
		"technique": hero_cfg.get("current_tec", 10),
		"spirit": hero_cfg.get("current_mnd", 10),
	}
	var ai_hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)
	ai_hero.hp = hero_cfg.get("current_hp", ai_hero.max_hp)
	ai_hero.name = "影子_%s" % shadow.user_id.substr(0, 8)

	# 从影子提取伙伴
	var ai_partners: Array = []
	for p_data in shadow.partner_configs:
		if not p_data is Dictionary:
			continue
		var pid: int = p_data.get("partner_config_id", 1001)
		var pcfg: Dictionary = ConfigManager.get_partner_config(str(pid))
		var p_name: String = pcfg.get("name", "伙伴")
		var p_level: int = p_data.get("current_level", 1)
		var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(str(pid))
		var base_stats: Dictionary = {
			"physique": assist_cfg.get("base_physique", 10),
			"strength": assist_cfg.get("base_strength", 10),
			"agility": assist_cfg.get("base_agility", 10),
			"technique": assist_cfg.get("base_technique", 10),
			"spirit": assist_cfg.get("base_spirit", 10),
		}
		var level_multiplier: float = 1.0 + (p_level - 1) * 0.2
		for key in base_stats.keys():
			base_stats[key] = int(base_stats[key] * level_multiplier)
		ai_partners.append(PartnerAssist.make_partner_battle_unit(str(pid), p_name, base_stats))

	return {
		"hero": ai_hero,
		"enemies": [],
		"partners": ai_partners,
		"battle_seed": shadow.timestamp + shadow.floor,
		"playback_mode": "fast_forward",
		"opponent_name": ai_hero.name,
		"opponent_source": "shadow",
		"shadow_data": shadow.to_dict(),
	}

func _build_default_ai_opponent(floor: int) -> Dictionary:
	var template: Dictionary = _select_template(floor)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = floor * 1000

	var default_stats: Dictionary = {
		"physique": 20,
		"strength": 20,
		"agility": 20,
		"technique": 20,
		"spirit": 20,
	}
	var ai_hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", default_stats)
	ai_hero.name = _generate_opponent_name(rng)

	var ai_partners: Array = _generate_ai_partners(template, rng)

	return {
		"hero": ai_hero,
		"enemies": [],
		"partners": ai_partners,
		"battle_seed": rng.seed,
		"playback_mode": "fast_forward",
		"opponent_name": ai_hero.name,
		"opponent_source": "default_ai",
	}
