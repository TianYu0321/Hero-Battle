## res://scripts/core/test_battle_core.gd
## 模块: TestBattleCore
## 职责: 战斗引擎纯逻辑单元测试，不依赖UI
## 依赖: 所有 core 模块
## 被依赖: 无

extends Node

func _ready() -> void:
	print("===== 战斗引擎核心测试开始 =====")
	_test_damage_calculator()
	_test_action_order()
	_test_skill_manager()
	_test_ultimate_manager()
	_test_partner_assist()
	_test_chain_trigger()
	_test_enemy_ai()
	await _test_full_battle()
	print("===== 战斗引擎核心测试结束 =====")
	get_tree().quit()

func _test_damage_calculator() -> void:
	print("\n[DamageCalculator 测试]")
	var dc: DamageCalculator = DamageCalculator.new(12345)
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	print("  勇者 HP: %d/%d" % [hero.hp, hero.max_hp])
	print("  重甲守卫 HP: %d/%d" % [enemy.hp, enemy.max_hp])
	var pkt: Dictionary = dc.compute_damage(hero, enemy, 1.0, "NORMAL")
	print("  普攻伤害: %d (暴击:%s 闪避:%s)" % [pkt.value, str(pkt.is_crit), str(pkt.is_miss)])
	assert(pkt.value >= 1 or pkt.is_miss, "伤害应>=1或为闪避")
	print("  ✅ DamageCalculator 通过")

func _test_action_order() -> void:
	print("\n[ActionOrder 测试]")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var ao: ActionOrder = ActionOrder.new(rng)
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 10, "strength": 10, "agility": 20, "technique": 10, "spirit": 10})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var seq: Array = ao.calculate_order(hero, [enemy])
	assert(seq.size() == 2, "应有2个行动单位")
	print("  行动顺序: %s -> %s" % [seq[0].unit.name, seq[1].unit.name])
	print("  ✅ ActionOrder 通过")

func _test_skill_manager() -> void:
	print("\n[SkillManager 测试]")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var sm: SkillManager = SkillManager.new(dc, rng)
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	
	# 勇者普攻
	var pkts1: Array = sm.execute_hero_normal_attack(hero, enemy)
	print("  勇者攻击: %d 段" % pkts1.size())
	assert(pkts1.size() >= 1, "勇者至少1段")
	
	# 影舞者普攻
	hero.hero_id = "hero_shadow_dancer"
	hero.stats = {"physique": 10, "strength": 10, "agility": 16, "technique": 10, "spirit": 12}
	var enemy2: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var pkts2: Array = sm.execute_hero_normal_attack(hero, enemy2)
	print("  影舞者攻击: %d 段" % pkts2.size())
	assert(pkts2.size() >= 2 and pkts2.size() <= 4, "影舞者2-4段")
	
	# 铁卫普攻
	hero.hero_id = "hero_iron_guard"
	hero.stats = {"physique": 16, "strength": 8, "agility": 10, "technique": 10, "spirit": 14}
	var enemy3: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var pkts3: Array = sm.execute_hero_normal_attack(hero, enemy3)
	print("  铁卫攻击: %d 段" % pkts3.size())
	assert(pkts3.size() == 1, "铁卫1段")
	
	print("  ✅ SkillManager 通过")

func _test_ultimate_manager() -> void:
	print("\n[UltimateManager 测试]")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var um: UltimateManager = UltimateManager.new(dc, rng)
	
	# 勇者必杀: 敌人<40%血
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	enemy.hp = int(enemy.max_hp * 0.3)
	var result1: Dictionary = um.check_and_trigger(hero, [enemy], 5)
	print("  勇者必杀触发: %s" % str(result1.triggered))
	assert(result1.triggered, "勇者应在敌人<40%血时触发必杀")
	
	# 影舞者必杀: 第8回合
	hero = DamageCalculator.spawn_hero("hero_shadow_dancer", {"physique": 10, "strength": 10, "agility": 16, "technique": 10, "spirit": 12})
	var enemy2: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var result2: Dictionary = um.check_and_trigger(hero, [enemy2], 8)
	print("  影舞者必杀触发: %s" % str(result2.triggered))
	assert(result2.triggered, "影舞者应在第8回合触发必杀")
	
	# 铁卫必杀: 自身<50%血
	hero = DamageCalculator.spawn_hero("hero_iron_guard", {"physique": 16, "strength": 8, "agility": 10, "technique": 10, "spirit": 14})
	hero.hp = int(hero.max_hp * 0.3)
	var result3: Dictionary = um.check_and_trigger(hero, [], 5)
	print("  铁卫必杀触发: %s" % str(result3.triggered))
	assert(result3.triggered, "铁卫应在自身<50%血时触发必杀")
	
	print("  ✅ UltimateManager 通过")

func _test_partner_assist() -> void:
	print("\n[PartnerAssist 测试]")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var pa: PartnerAssist = PartnerAssist.new(dc, rng)
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var partners: Array = [
		PartnerAssist.make_partner_battle_unit("partner_swordsman", "剑士", {"physique": 10, "strength": 14, "agility": 10, "technique": 10, "spirit": 8}),
	]
	var ctx: Dictionary = {"hero": hero, "enemies": [enemy], "partners": partners, "last_action_was_crit": false, "last_action_was_hit": true, "hero_was_hit": false, "turn_number": 1, "hero_attacked": true}
	var results: Array = pa.execute_assist(ctx)
	print("  伙伴援助次数: %d" % results.size())
	print("  ✅ PartnerAssist 通过")

func _test_chain_trigger() -> void:
	print("\n[ChainTrigger 测试]")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var ct: ChainTrigger = ChainTrigger.new(dc, rng)
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var partners: Array = [
		PartnerAssist.make_partner_battle_unit("partner_swordsman", "剑士", {"physique": 10, "strength": 14, "agility": 10, "technique": 10, "spirit": 8}),
		PartnerAssist.make_partner_battle_unit("partner_scout", "斥候", {"physique": 8, "strength": 10, "agility": 14, "technique": 12, "spirit": 8}),
	]
	var turn_chain: int = 0
	var total_chains: int = 0
	while turn_chain < 4:
		var result: Dictionary = ct.try_trigger_chain(hero, [enemy], partners, turn_chain)
		if not result.triggered:
			break
		turn_chain = result.chain_count
		total_chains += 1
	print("  本回合连锁段数: %d" % turn_chain)
	assert(turn_chain <= 4, "连锁不超过4段")
	print("  ✅ ChainTrigger 通过")

func _test_enemy_ai() -> void:
	print("\n[EnemyAI 测试]")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var ai: EnemyAI = EnemyAI.new(dc, rng)
	var hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), hero.stats)
	var pkts: Array = ai.execute_enemy_turn(enemy, hero, 1)
	print("  敌人行动伤害: %d" % (pkts[0].value if pkts.size() > 0 and not pkts[0].get("is_stunned", false) else 0))
	print("  ✅ EnemyAI 通过")

func _test_full_battle() -> void:
	print("\n[完整战斗测试]")
	var battle_engine: BattleEngine = BattleEngine.new()
	add_child(battle_engine)
	
	for hero_id in ["hero_warrior", "hero_shadow_dancer", "hero_iron_guard"]:
		for enemy_id in ["2001", "2002"]:
			var hero_cfg: Dictionary = ConfigManager.get_hero_config(hero_id)
			var hero_stats: Dictionary = {
				"physique": hero_cfg.get("base_physique", 10),
				"strength": hero_cfg.get("base_strength", 10),
				"agility": hero_cfg.get("base_agility", 10),
				"technique": hero_cfg.get("base_technique", 10),
				"spirit": hero_cfg.get("base_spirit", 10),
			}
			var hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)
			var enemy_cfg: Dictionary = ConfigManager.get_enemy_config(enemy_id)
			var enemy: Dictionary = DamageCalculator.spawn_enemy(enemy_cfg, hero_stats)
			var partners: Array = []
			for pid in ["partner_swordsman", "partner_scout", "partner_shieldguard", "partner_pharmacist", "partner_sorcerer", "partner_hunter"]:
				var pcfg: Dictionary = ConfigManager.get_partner_config(pid)
				var pstats: Dictionary = {
					"physique": pcfg.get("base_physique", 10),
					"strength": pcfg.get("base_strength", 10),
					"agility": pcfg.get("base_agility", 10),
					"technique": pcfg.get("base_technique", 10),
					"spirit": pcfg.get("base_spirit", 10),
				}
				partners.append(PartnerAssist.make_partner_battle_unit(pid, pcfg.get("partner_name", pid), pstats))
			
			var config: Dictionary = {
				"hero": hero,
				"enemies": [enemy],
				"partners": partners,
				"battle_seed": randi(),
				"playback_mode": "fast_forward",
			}
			var result: Dictionary = await battle_engine.execute_battle(config)
			print("  %s vs %s -> 胜者: %s, 回合: %d, 伤害: %d, 连锁: %s, 必杀: %s" % [
				hero_id, enemy_id, result.winner, result.turns_elapsed,
				result.total_damage_dealt, str(result.chain_stats),
				str(result.ultimate_triggered)
			])
			assert(result.winner != "", "战斗应有胜负结果")
	
	battle_engine.queue_free()
	print("  ✅ 完整战斗测试通过")
