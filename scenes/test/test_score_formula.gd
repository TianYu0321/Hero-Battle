## res://scenes/test/test_score_formula.gd
## 模块: TestScoreFormula
## 职责: 评分公式专项测试：输入预设GameState → 输出4项分数明细 → 验证总分和评级

extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("===== 评分公式调优测试开始 =====")
	_test_grade_thresholds()
	_test_score_formula_basic()
	_test_score_formula_attr_growth()
	_test_score_formula_level_score()
	_test_score_formula_gold_score()
	_test_score_formula_final_performance()
	print("===== 评分公式调优测试结束 =====")
	print("通过: %d, 失败: %d" % [_passed, _failed])
	get_tree().quit()

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ " + msg)
	else:
		_failed += 1
		push_error("  ❌ " + msg)

# --- 测试1: 评级阈值 ---
func _test_grade_thresholds() -> void:
	print("\n[评级阈值测试]")
	var ss := SettlementSystem.new()

	var grade_s: String = ss._calculate_grade(90)
	var grade_a: String = ss._calculate_grade(75)
	var grade_b: String = ss._calculate_grade(60)
	var grade_c: String = ss._calculate_grade(40)
	var grade_d: String = ss._calculate_grade(39)
	var grade_d2: String = ss._calculate_grade(0)

	_assert(grade_s == "S", "90分 = S")
	_assert(grade_a == "A", "75分 = A")
	_assert(grade_b == "B", "60分 = B")
	_assert(grade_c == "C", "40分 = C")
	_assert(grade_d == "D", "39分 = D")
	_assert(grade_d2 == "D", "0分 = D")
	_assert(ss._calculate_grade(89) == "A", "89分 = A（边界）")
	_assert(ss._calculate_grade(74) == "B", "74分 = B（边界）")
	_assert(ss._calculate_grade(59) == "C", "59分 = C（边界）")
	_assert(ss._calculate_grade(41) == "C", "41分 = C（边界）")

# --- 测试2: 基础评分计算 ---
func _test_score_formula_basic() -> void:
	print("\n[基础评分计算测试]")
	var ss := SettlementSystem.new()
	var run := _make_test_run()
	var hero := _make_test_hero()
	var fb := _make_test_final_battle()

	var score: FighterArchiveScore = ss.calculate_score(run, hero, fb, [])
	_assert(score.total_score > 0, "总分应大于0")
	_assert(score.grade != "", "评级不应为空")
	_assert(score.final_performance_raw >= 0, "终局战原始分 >= 0")
	_assert(score.attr_total_raw >= 0, "属性总分原始分 >= 0")
	_assert(score.level_score_raw >= 0, "等级分原始分 >= 0")
	_assert(score.gold_score_raw >= 0, "金币分原始分 >= 0")

	# 验证加权分 = 原始分 × 权重
	_assert(abs(score.final_performance_weighted - score.final_performance_raw * 0.40) < 0.1, "终局战加权 = 原始 × 0.40")
	_assert(abs(score.attr_total_weighted - score.attr_total_raw * 0.25) < 0.1, "属性加权 = 原始 × 0.25")
	_assert(abs(score.level_score_weighted - score.level_score_raw * 0.20) < 0.1, "等级加权 = 原始 × 0.20")
	_assert(abs(score.gold_score_weighted - score.gold_score_raw * 0.15) < 0.1, "金币加权 = 原始 × 0.15")

	print("  总分: %.1f, 评级: %s" % [score.total_score, score.grade])
	print("  终局战: %.1f | 属性: %.1f | 等级: %.1f | 金币: %.1f" % [
		score.final_performance_raw, score.attr_total_raw,
		score.level_score_raw, score.gold_score_raw
	])

# --- 测试3: 属性成长对评分的影响 ---
func _test_score_formula_attr_growth() -> void:
	print("\n[属性成长评分测试]")
	var ss := SettlementSystem.new()

	# 高属性英雄
	var hero1 := _make_test_hero()
	hero1.current_vit = 50; hero1.current_str = 50; hero1.current_agi = 50; hero1.current_tec = 50; hero1.current_mnd = 50
	var score1: FighterArchiveScore = ss.calculate_score(_make_test_run(), hero1, _make_test_final_battle(), [])
	_assert(score1.attr_total_raw > 0, "高属性英雄属性分 > 0")

	# 低属性英雄
	var hero2 := _make_test_hero()
	hero2.current_vit = 10; hero2.current_str = 10; hero2.current_agi = 10; hero2.current_tec = 10; hero2.current_mnd = 10
	var score2: FighterArchiveScore = ss.calculate_score(_make_test_run(), hero2, _make_test_final_battle(), [])
	_assert(score2.attr_total_raw > 0, "低属性英雄属性分 > 0")
	_assert(score1.attr_total_raw > score2.attr_total_raw, "高属性分应高于低属性分")

	print("  高属性: %.1f | 低属性: %.1f" % [score1.attr_total_raw, score2.attr_total_raw])

# --- 测试4: 伙伴等级分 ---
func _test_score_formula_level_score() -> void:
	print("\n[等级分测试]")
	var ss := SettlementSystem.new()

	var p1 := RuntimePartner.new()
	p1.current_level = 5
	var p2 := RuntimePartner.new()
	p2.current_level = 5
	var partners: Array[RuntimePartner] = [p1, p2]

	var score1: FighterArchiveScore = ss.calculate_score(_make_test_run(), _make_test_hero(), _make_test_final_battle(), partners)
	_assert(score1.level_score_raw > 0, "有伙伴时等级分 > 0")

	var score2: FighterArchiveScore = ss.calculate_score(_make_test_run(), _make_test_hero(), _make_test_final_battle(), [])
	_assert(score2.level_score_raw >= 0, "无伙伴时等级分 >= 0")
	_assert(score1.level_score_raw > score2.level_score_raw, "有伙伴等级分应高于无伙伴")

	print("  有伙伴: %.1f | 无伙伴: %.1f" % [score1.level_score_raw, score2.level_score_raw])

# --- 测试5: 金币分 ---
func _test_score_formula_gold_score() -> void:
	print("\n[金币分测试]")
	var ss := SettlementSystem.new()

	var run1 := _make_test_run()
	run1.gold_earned_total = 300
	run1.gold_owned = 200
	var score1: FighterArchiveScore = ss.calculate_score(run1, _make_test_hero(), _make_test_final_battle(), [])
	_assert(score1.gold_score_raw > 0, "有剩余金币时金币分 > 0")

	var run2 := _make_test_run()
	run2.gold_earned_total = 300
	run2.gold_owned = 0
	var score2: FighterArchiveScore = ss.calculate_score(run2, _make_test_hero(), _make_test_final_battle(), [])
	_assert(score2.gold_score_raw == 0, "无剩余金币时金币分 = 0")
	_assert(score1.gold_score_raw > score2.gold_score_raw, "有剩余金币应高于无剩余")

	print("  有剩余: %.1f | 无剩余: %.1f" % [score1.gold_score_raw, score2.gold_score_raw])

# --- 测试6: 终局战表现分 ---
func _test_score_formula_final_performance() -> void:
	print("\n[终局战表现分测试]")
	var ss := SettlementSystem.new()

	# 胜利+满血+满伤害
	var fb1 := _make_test_final_battle()
	fb1.result = 1
	fb1.hero_remaining_hp = 120
	fb1.hero_max_hp = 120
	fb1.damage_dealt_to_enemy = 250
	fb1.enemy_max_hp = 250
	var score1: FighterArchiveScore = ss.calculate_score(_make_test_run(), _make_test_hero(), fb1, [])
	_assert(score1.final_performance_raw == 100, "完美终局战 = 100分")

	# 失败
	var fb2 := _make_test_final_battle()
	fb2.result = 2
	var score2: FighterArchiveScore = ss.calculate_score(_make_test_run(), _make_test_hero(), fb2, [])
	_assert(score2.final_performance_raw < 50, "失败终局战 < 50分")
	_assert(score1.final_performance_raw > score2.final_performance_raw, "胜利应高于失败")

	print("  完美: %.1f | 失败: %.1f" % [score1.final_performance_raw, score2.final_performance_raw])

# --- 辅助方法：构造测试数据 ---

func _make_test_run() -> RuntimeRun:
	var run := RuntimeRun.new()
	run.initial_attr_sum = 60
	run.current_turn = 30
	run.gold_earned_total = 300
	run.gold_owned = 150
	run.elite_win_count = 3
	run.elite_total_count = 5
	run.pvp_10th_result = 1
	run.pvp_20th_result = 1
	run.max_chain_reached = 3
	run.total_chain_count = 8
	run.total_aid_trigger_count = 5
	return run

func _make_test_hero() -> RuntimeHero:
	var hero := RuntimeHero.new()
	hero.hero_config_id = 1
	hero.current_vit = 20
	hero.current_str = 25
	hero.current_agi = 18
	hero.current_tec = 22
	hero.current_mnd = 15
	hero.total_enemies_killed = 8
	return hero

func _make_test_final_battle() -> RuntimeFinalBattle:
	var fb := RuntimeFinalBattle.new()
	fb.result = 1
	fb.hero_remaining_hp = 80
	fb.hero_max_hp = 120
	fb.damage_dealt_to_enemy = 200
	fb.enemy_max_hp = 250
	return fb
