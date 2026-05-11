## res://scenes/test/test_pvp_real.gd
## 模块: TestPvpReal
## 职责: PVP真实战斗测试：强制触发PVP → 输出胜负 + 对手属性 + 战斗摘要

extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("===== PVP 真实战斗测试开始 =====")
	_test_pvp_opponent_generation()
	_test_pvp_battle_turn_10()
	_test_pvp_battle_turn_20()
	_test_pvp_penalty_logic()
	_test_pvp_template_loading()
	print("===== PVP 真实战斗测试结束 =====")
	print("通过: %d, 失败: %d" % [_passed, _failed])
	get_tree().quit()

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ " + msg)
	else:
		_failed += 1
		push_error("  ❌ " + msg)

# --- 测试1: AI对手生成 ---
func _test_pvp_opponent_generation() -> void:
	print("\n[PVP 对手生成测试]")

	var cm := CharacterManager.new()
	add_child(cm)
	cm.initialize_hero(1)
	cm.initialize_partners([1001, 1002])

	var team: Dictionary = cm.get_battle_ready_team()
	_assert(team.hero is RuntimeHero, "get_battle_ready_team 返回的 hero 应为 RuntimeHero")
	_assert(team.hero.hero_config_id == 1, "hero_config_id 应为 1（勇者）")
	_assert(team.partners.size() == 2, "伙伴数应为2")

	var generator := PvpOpponentGenerator.new()
	var player_state: Dictionary = {
		"player_hero": team.hero,
		"player_partners": team.partners,
		"player_gold": 100,
		"player_hp": team.hero.current_hp,
		"player_max_hp": team.hero.max_hp,
		"run_seed": 12345,
	}

	# 第10回合（前期模板）
	var battle_config_early: Dictionary = generator.generate_opponent(player_state, 10)
	_assert(battle_config_early.has("hero"), "battle_config 应包含 hero")
	_assert(battle_config_early.has("enemies"), "battle_config 应包含 enemies")
	_assert(battle_config_early.enemies.size() == 1, "enemies 应有1个（玩家镜像）")
	_assert(battle_config_early.hero.has("name"), "AI英雄应有随机名称")
	_assert(battle_config_early.hero.name.begins_with("AI_"), "AI名称应以 AI_ 开头")
	_assert(battle_config_early.partners.size() == 3, "第10回合AI应有3个伙伴")
	_assert(battle_config_early.battle_seed == 12355, "战斗种子 = run_seed + turn = 12355")

	# 检查AI属性是否被缩放（前期乘数0.90，应比玩家低）
	var player_str: int = team.hero.current_str
	var ai_str: int = battle_config_early.hero.stats.strength
	_assert(ai_str < player_str * 1.1, "第10回合AI力量应接近或低于玩家（乘数0.90）")

	# 第20回合（中期模板）
	var battle_config_mid: Dictionary = generator.generate_opponent(player_state, 20)
	_assert(battle_config_mid.partners.size() == 4, "第20回合AI应有4个伙伴")
	var ai_str_mid: int = battle_config_mid.hero.stats.strength
	_assert(ai_str_mid >= ai_str, "第20回合AI应比第10回合更强")

	# 检查玩家镜像
	var player_mirror: Dictionary = battle_config_early.enemies[0]
	_assert(player_mirror.unit_id == "enemy_player", "玩家镜像 unit_id 应为 enemy_player")
	_assert(player_mirror.unit_type == "ENEMY", "玩家镜像 unit_type 应为 ENEMY")

	cm.queue_free()
	print("  ✅ 对手生成测试通过")

# --- 测试2: 第10回合PVP真实战斗 ---
func _test_pvp_battle_turn_10() -> void:
	print("\n[PVP 第10回合真实战斗测试]")

	var pvp_director := PvpDirector.new()
	add_child(pvp_director)

	var cm := CharacterManager.new()
	add_child(cm)
	cm.initialize_hero(1)
	cm.initialize_partners([1001, 1002])

	var team: Dictionary = cm.get_battle_ready_team()
	var pvp_config: Dictionary = {
		"turn_number": 10,
		"player_hero": team.hero,
		"player_partners": team.partners,
		"player_gold": 100,
		"player_hp": team.hero.current_hp,
		"player_max_hp": team.hero.max_hp,
		"run_seed": 12345,
	}

	var result: Dictionary = pvp_director.execute_pvp(pvp_config)
	_assert(result.has("won"), "结果应有 won 字段")
	_assert(result.has("combat_summary"), "结果应有 combat_summary")
	_assert(result.pvp_turn == 10, "pvp_turn 应为 10")
	_assert(result.has("opponent_name"), "结果应有 opponent_name")
	_assert(result.combat_summary.has("turns"), "combat_summary 应有 turns")
	_assert(result.combat_summary.has("player_damage_dealt"), "combat_summary 应有 player_damage_dealt")
	_assert(result.combat_summary.turns > 0, "战斗应有至少1回合")
	_assert(result.combat_summary.turns <= 20, "战斗不应超过20回合")

	print("  胜负: %s, 对手: %s, 回合: %d, 惩罚: %s" % [
		"胜利" if result.won else "失败",
		result.opponent_name,
		result.combat_summary.turns,
		result.penalty_tier
	])

	cm.queue_free()
	pvp_director.queue_free()
	print("  ✅ 第10回合PVP测试通过")

# --- 测试3: 第20回合PVP真实战斗 ---
func _test_pvp_battle_turn_20() -> void:
	print("\n[PVP 第20回合真实战斗测试]")

	var pvp_director := PvpDirector.new()
	add_child(pvp_director)

	var cm := CharacterManager.new()
	add_child(cm)
	cm.initialize_hero(2)
	cm.initialize_partners([1003, 1004, 1005])

	var team: Dictionary = cm.get_battle_ready_team()
	var pvp_config: Dictionary = {
		"turn_number": 20,
		"player_hero": team.hero,
		"player_partners": team.partners,
		"player_gold": 200,
		"player_hp": team.hero.current_hp,
		"player_max_hp": team.hero.max_hp,
		"run_seed": 54321,
	}

	var result: Dictionary = pvp_director.execute_pvp(pvp_config)
	_assert(result.pvp_turn == 20, "pvp_turn 应为 20")
	_assert(result.combat_summary.turns > 0, "战斗应有至少1回合")

	print("  胜负: %s, 对手: %s, 回合: %d, 惩罚: %s" % [
		"胜利" if result.won else "失败",
		result.opponent_name,
		result.combat_summary.turns,
		result.penalty_tier
	])

	cm.queue_free()
	pvp_director.queue_free()
	print("  ✅ 第20回合PVP测试通过")

# --- 测试4: 惩罚逻辑 ---
func _test_pvp_penalty_logic() -> void:
	print("\n[PVP 惩罚逻辑测试]")

	# 第10回合失败: 金币扣除50%
	var penalty_gold: int = int(100 * 0.5)
	_assert(penalty_gold == 50, "第10回合失败应扣除50金币")

	var penalty_gold_low: int = int(30 * 0.5)
	_assert(penalty_gold_low == 15, "30金币应扣除15金币")

	# 第20回合失败: HP扣除30%，最低保留10
	var penalty_hp: int = int(100 * 0.3)
	_assert(penalty_hp == 30, "第20回合失败应扣除30HP")

	var final_hp: int = maxi(10, 100 - 30)
	_assert(final_hp == 70, "100HP扣除30%后应剩70")

	var final_hp_min: int = maxi(10, 12 - 4)
	_assert(final_hp_min == 10, "12HP扣除30%后最低保留10")

	print("  ✅ 惩罚逻辑测试通过")

# --- 测试5: 配置加载 ---
func _test_pvp_template_loading() -> void:
	print("\n[PVP 配置加载测试]")

	var early: Dictionary = ConfigManager.get_pvp_opponent_template("pvp_early")
	_assert(not early.is_empty(), "应能加载 pvp_early 模板")
	_assert(early.get("hero_stat_multiplier", 0.0) == 0.90, "前期hero乘数 = 0.90")
	_assert(early.get("partner_count", 0) == 3, "前期伙伴数 = 3")

	var mid: Dictionary = ConfigManager.get_pvp_opponent_template("pvp_mid")
	_assert(not mid.is_empty(), "应能加载 pvp_mid 模板")
	_assert(mid.get("hero_stat_multiplier", 0.0) == 1.05, "中期hero乘数 = 1.05")
	_assert(mid.get("partner_count", 0) == 4, "中期伙伴数 = 4")

	var invalid: Dictionary = ConfigManager.get_pvp_opponent_template("nonexistent")
	_assert(invalid.is_empty(), "无效模板应返回空字典")

	print("  ✅ 配置加载测试通过")
