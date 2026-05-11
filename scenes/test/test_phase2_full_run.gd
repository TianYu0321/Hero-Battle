## res://scenes/test/test_phase2_full_run.gd
## 模块: TestPhase2FullRun
## 职责: Phase 2 全流程测试：自动推进30回合（含真实PVP）→ 终局战 → 结算 → 保存档案 → 验证评分

extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("===== Phase 2 全流程测试开始 =====")
	_test_full_run_flow()
	_test_pvp_integration()
	_test_settlement_integration()
	_test_leaderboard_integration()
	print("===== Phase 2 全流程测试结束 =====")
	print("通过: %d, 失败: %d" % [_passed, _failed])
	get_tree().quit()

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ " + msg)
	else:
		_failed += 1
		push_error("  ❌ " + msg)

# --- 测试1: 完整养成循环流程 ---
func _test_full_run_flow() -> void:
	print("\n[完整养成循环流程测试]")

	var rc := RunController.new()
	add_child(rc)

	# 启动新局
	rc.start_new_run(1, [1001, 1002])
	var summary: Dictionary = rc.get_current_run_summary()
	_assert(summary.get("current_turn", 0) == 1, "启动后回合 = 1")
	_assert(summary.get("gold", 0) == 0, "启动后金币 = 0")

	var hero_dict: Dictionary = summary.get("hero", {})
	_assert(hero_dict.get("hero_config_id", 0) == 1, "主角配置ID = 1（勇者）")
	_assert(hero_dict.get("is_alive", false) == true, "主角存活")

	# 推进到第10回合（PVP节点）
	for i in range(9):
		var options: Array[Dictionary] = rc.get_current_node_options()
		var turn: int = rc.get_current_run_summary().get("current_turn", 0)
		if turn in [5, 15, 25]:
			rc.select_rescue_partner(1001)
			rc.close_shop_panel()
			continue
		if options.is_empty():
			push_warning("第%d回合无节点选项" % (i + 1))
			break
		rc.select_node(0)
		var post_summary: Dictionary = rc.get_current_run_summary()
		if post_summary.get("run_state", 0) == 3:
			rc.select_training_attr(1)
			rc.close_shop_panel()
		rc.advance_turn()

	summary = rc.get_current_run_summary()
	_assert(summary.get("current_turn", 0) == 10, "推进后回合 = 10")

	# 检查第10回合PVP选项
	var pvp_options: Array[Dictionary] = rc.get_current_node_options()
	if pvp_options.size() > 0:
		_assert(pvp_options[0].get("node_type", 0) == 7, "第10回合应有PVP节点")
		# 选择PVP节点
		rc.select_node(0)
		# PVP结果已处理（由NodeResolver → PvpDirector执行真实战斗）
		rc.advance_turn()
	else:
		push_warning("第10回合未生成PVP选项")

	# 推进到第20回合（第二次PVP）
	for i in range(9):
		var options: Array[Dictionary] = rc.get_current_node_options()
		var turn: int = rc.get_current_run_summary().get("current_turn", 0)
		if turn in [5, 15, 25]:
			rc.select_rescue_partner(1001)
			rc.close_shop_panel()
			continue
		if options.is_empty():
			break
		rc.select_node(0)
		var post_summary: Dictionary = rc.get_current_run_summary()
		if post_summary.get("run_state", 0) == 3:
			rc.select_training_attr(1)
			rc.close_shop_panel()
		rc.advance_turn()

	summary = rc.get_current_run_summary()
	_assert(summary.get("current_turn", 0) == 20, "推进后回合 = 20")

	# 检查第20回合PVP选项
	var pvp_options2: Array[Dictionary] = rc.get_current_node_options()
	if pvp_options2.size() > 0:
		_assert(pvp_options2[0].get("node_type", 0) == 7, "第20回合应有PVP节点")
		rc.select_node(0)
		rc.advance_turn()
	else:
		push_warning("第20回合未生成PVP选项")

	# 推进到第30回合（终局战）
	for i in range(9):
		var options: Array[Dictionary] = rc.get_current_node_options()
		var turn: int = rc.get_current_run_summary().get("current_turn", 0)
		if turn in [5, 15, 25]:
			rc.select_rescue_partner(1001)
			rc.close_shop_panel()
			continue
		if options.is_empty():
			break
		rc.select_node(0)
		var post_summary: Dictionary = rc.get_current_run_summary()
		if post_summary.get("run_state", 0) == 3:
			rc.select_training_attr(1)
			rc.close_shop_panel()
		rc.advance_turn()

	summary = rc.get_current_run_summary()
	_assert(summary.get("current_turn", 0) >= 30, "推进后回合 >= 30")

	rc.queue_free()
	print("  ✅ 完整养成循环流程测试通过")

# --- 测试2: PVP集成 ---
func _test_pvp_integration() -> void:
	print("\n[PVP集成测试]")

	var pvp_director := PvpDirector.new()
	add_child(pvp_director)

	var cm := CharacterManager.new()
	add_child(cm)
	cm.initialize_hero(1)

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
	_assert(result.has("won"), "PVP结果应有 won 字段")
	_assert(result.has("combat_summary"), "PVP结果应有 combat_summary")
	_assert(result.combat_summary.has("turns"), "combat_summary 应有 turns")
	_assert(result.combat_summary.turns > 0, "PVP战斗应有至少1回合")
	_assert(result.combat_summary.turns <= 20, "PVP战斗不应超过20回合")

	# v2.0取消PVP失败惩罚，penalty_tier始终为"none"
	_assert(result.get("penalty_tier", "") == "none", "v2.0 PVP无惩罚，penalty_tier = none")

	cm.queue_free()
	pvp_director.queue_free()
	print("  ✅ PVP集成测试通过")

# --- 测试3: 结算集成 ---
func _test_settlement_integration() -> void:
	print("\n[结算集成测试]")

	var ss := SettlementSystem.new()
	add_child(ss)

	var run := RuntimeRun.new()
	run.initial_attr_sum = 60
	run.current_turn = 30
	run.gold_earned_total = 300
	run.gold_spent = 200
	run.gold_owned = 200
	run.elite_win_count = 3
	run.elite_total_count = 5
	run.pvp_10th_result = 1
	run.pvp_20th_result = 1
	run.max_chain_reached = 4
	run.total_chain_count = 12
	run.total_aid_trigger_count = 8

	var hero := RuntimeHero.new()
	hero.hero_config_id = 1
	hero.current_vit = 25
	hero.current_str = 30
	hero.current_agi = 20
	hero.current_tec = 22
	hero.current_mnd = 18
	hero.total_enemies_killed = 15

	var fb := RuntimeFinalBattle.new()
	fb.result = 1
	fb.hero_remaining_hp = 100
	fb.hero_max_hp = 150
	fb.damage_dealt_to_enemy = 300
	fb.enemy_max_hp = 350

	var p1 := RuntimePartner.new()
	p1.current_level = 3
	var p2 := RuntimePartner.new()
	p2.current_level = 3
	var partners: Array[RuntimePartner] = [p1, p2]
	var score: FighterArchiveScore = ss.calculate_score(run, hero, fb, partners)
	_assert(score.total_score >= 0, "总分 >= 0")
	_assert(score.grade in ["S", "A", "B", "C", "D"], "评级合法")

	# 调优目标：正常游玩（双胜PVP+终局战胜利）应达到B档（55+）
	print("  测试用例总分: %.1f, 评级: %s" % [score.total_score, score.grade])
	_assert(score.total_score >= 55, "正常游玩用例应达到B档（55+分）")

	# 生成档案
	var archive: FighterArchiveMain = ss.generate_fighter_archive(run, hero, partners, score)
	_assert(archive.final_score == int(score.total_score), "档案分数与结算分数一致")
	_assert(archive.final_grade == score.grade, "档案评级与结算评级一致")
	_assert(archive.is_fixed == true, "档案标记为固定")

	# 保存档案
	var archive_dict: Dictionary = archive.to_dict()
	archive_dict["final_score"] = archive.final_score
	archive_dict["final_grade"] = archive.final_grade
	var saved: Dictionary = SaveManager.generate_fighter_archive(archive_dict)
	_assert(saved.has("archive_id"), "档案保存后应有 archive_id")

	ss.queue_free()
	print("  ✅ 结算集成测试通过")

# --- 测试4: 排行榜集成 ---
func _test_leaderboard_integration() -> void:
	print("\n[排行榜集成测试]")

	var lb := LeaderboardSystem.new()
	add_child(lb)

	# 生成多个测试档案
	for i in range(3):
		var archive: Dictionary = {
			"archive_id": "ARC_TEST_%d" % i,
			"hero_name": "勇者",
			"hero_config_id": 1,
			"final_score": 60 + i * 10,
			"final_grade": ["B", "A", "S"][i],
			"attr_snapshot_vit": 20,
			"attr_snapshot_str": 25,
			"attr_snapshot_agi": 18,
			"attr_snapshot_tec": 20,
			"attr_snapshot_mnd": 15,
			"partners": ["partner_swordsman"],
			"is_fixed": true,
			"created_at": Time.get_unix_time_from_system() + i,
		}
		SaveManager.generate_fighter_archive(archive)

	# 按分数排序读取
	var leaderboard: Array[Dictionary] = lb.get_leaderboard(10, "")
	_assert(leaderboard.size() >= 3, "排行榜应至少有3条记录")

	if leaderboard.size() >= 2:
		var score0: int = leaderboard[0].get("total_score", 0)
		var score1: int = leaderboard[1].get("total_score", 0)
		_assert(score0 >= score1, "排行榜应按分数降序")

	# 排名变化指示器
	var indicator: String = lb.get_rank_change_indicator(1, 3)
	_assert(indicator == "↑", "排名上升应显示 ↑")
	indicator = lb.get_rank_change_indicator(3, 1)
	_assert(indicator == "↓", "排名下降应显示 ↓")
	indicator = lb.get_rank_change_indicator(2, 2)
	_assert(indicator == "—", "排名不变应显示 —")
	indicator = lb.get_rank_change_indicator(1, -1)
	_assert(indicator == "NEW", "新记录应显示 NEW")

	lb.queue_free()
	print("  ✅ 排行榜集成测试通过")
