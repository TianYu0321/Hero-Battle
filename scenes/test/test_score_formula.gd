## res://scenes/test/test_score_formula.gd
## 模块: TestScoreFormula
## 职责: 评分公式专项测试：输入预设GameState → 输出5项分数明细 → 验证总分和评级

extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("===== 评分公式调优测试开始 =====")
	_test_grade_thresholds()
	_test_score_formula_basic()
	_test_score_formula_training_efficiency()
	_test_score_formula_build_purity()
	_test_score_formula_chain_showcase()
	_test_score_formula_pvp()
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

	# 通过反射调用私有方法 _calculate_grade
	var grade_s: String = ss._calculate_grade(85)
	var grade_a: String = ss._calculate_grade(70)
	var grade_b: String = ss._calculate_grade(55)
	var grade_c: String = ss._calculate_grade(35)
	var grade_d: String = ss._calculate_grade(34)
	var grade_d2: String = ss._calculate_grade(0)

	_assert(grade_s == "S", "85分 = S")
	_assert(grade_a == "A", "70分 = A")
	_assert(grade_b == "B", "55分 = B")
	_assert(grade_c == "C", "35分 = C")
	_assert(grade_d == "D", "34分 = D")
	_assert(grade_d2 == "D", "0分 = D")
	_assert(ss._calculate_grade(84) == "A", "84分 = A（边界）")
	_assert(ss._calculate_grade(69) == "B", "69分 = B（边界）")
	_assert(ss._calculate_grade(54) == "C", "54分 = C（边界）")
	_assert(ss._calculate_grade(36) == "C", "36分 = C（边界）")

# --- 测试2: 基础评分计算 ---
func _test_score_formula_basic() -> void:
	print("\n[基础评分计算测试]")
	var ss := SettlementSystem.new()
	var run := _make_test_run()
	var hero := _make_test_hero()
	var fb := _make_test_final_battle()

	var score: FighterArchiveScore = ss.calculate_score(run, hero, fb)
	_assert(score.total_score > 0, "总分应大于0")
	_assert(score.grade != "", "评级不应为空")
	_assert(score.final_performance_raw >= 0, "终局战原始分 >= 0")
	_assert(score.training_efficiency_raw >= 0, "养成效率原始分 >= 0")
	_assert(score.pvp_performance_raw >= 0, "PVP原始分 >= 0")
	_assert(score.build_purity_raw >= 0, "流派纯度原始分 >= 0")
	_assert(score.chain_showcase_raw >= 0, "连锁展示原始分 >= 0")

	# 验证加权分 = 原始分 × 权重
	_assert(abs(score.final_performance_weighted - score.final_performance_raw * 0.30) < 0.1, "终局战加权 = 原始 × 0.30")
	_assert(abs(score.training_efficiency_weighted - score.training_efficiency_raw * 0.25) < 0.1, "养成效率加权 = 原始 × 0.25")
	_assert(abs(score.pvp_performance_weighted - score.pvp_performance_raw * 0.20) < 0.1, "PVP加权 = 原始 × 0.20")
	_assert(abs(score.build_purity_weighted - score.build_purity_raw * 0.15) < 0.1, "流派纯度加权 = 原始 × 0.15")
	_assert(abs(score.chain_showcase_weighted - score.chain_showcase_raw * 0.10) < 0.1, "连锁展示加权 = 原始 × 0.10")

	print("  总分: %.1f, 评级: %s" % [score.total_score, score.grade])
	print("  终局战: %.1f | 养成效率: %.1f | PVP: %.1f | 纯度: %.1f | 连锁: %.1f" % [
		score.final_performance_raw, score.training_efficiency_raw,
		score.pvp_performance_raw, score.build_purity_raw, score.chain_showcase_raw
	])

# --- 测试3: 养成效率公式调优 ---
func _test_score_formula_training_efficiency() -> void:
	print("\n[养成效率公式调优测试]")
	var ss := SettlementSystem.new()

	# 场景：初始60，当前150，30回合 -> 每回合成长3 -> 得分约6（被clamp前）
	var run1 := _make_test_run()
	run1.initial_attr_sum = 60
	run1.current_turn = 30
	var hero1 := _make_test_hero()
	hero1.current_vit = 30; hero1.current_str = 30; hero1.current_agi = 30; hero1.current_tec = 30; hero1.current_mnd = 30

	var score1: FighterArchiveScore = ss.calculate_score(run1, hero1, _make_test_final_battle())
	_assert(score1.training_efficiency_raw > 0, "成长应为正，养成效率 > 0")

	# 场景：无成长（初始=当前）
	var run2 := _make_test_run()
	run2.initial_attr_sum = 60
	run2.current_turn = 10
	var hero2 := _make_test_hero()
	hero2.current_vit = 12; hero2.current_str = 12; hero2.current_agi = 12; hero2.current_tec = 12; hero2.current_mnd = 12

	var score2: FighterArchiveScore = ss.calculate_score(run2, hero2, _make_test_final_battle())
	# 成长为0，属性成长部分应为0，但金币效率/均衡度/精英战可能有分
	_assert(score2.training_efficiency_raw >= 0, "无成长时养成效率 >= 0")

# --- 测试4: 流派纯度公式调优 ---
func _test_score_formula_build_purity() -> void:
	print("\n[流派纯度公式调优测试]")
	var ss := SettlementSystem.new()

	# 极端build：最高50，次高10，总和100 -> 差=40 -> 40/100*100=40分（被clamp到50上限内）
	var hero1 := _make_test_hero()
	hero1.current_vit = 50; hero1.current_str = 10; hero1.current_agi = 10; hero1.current_tec = 10; hero1.current_mnd = 20
	var score1: FighterArchiveScore = ss.calculate_score(_make_test_run(), hero1, _make_test_final_battle())
	var purity1: float = score1.build_purity_raw
	_assert(purity1 > 0, "极端build纯度应 > 0")

	# 均衡build：所有属性相同 -> 差=0 -> 纯度属性部分=0
	var hero2 := _make_test_hero()
	hero2.current_vit = 20; hero2.current_str = 20; hero2.current_agi = 20; hero2.current_tec = 20; hero2.current_mnd = 20
	var score2: FighterArchiveScore = ss.calculate_score(_make_test_run(), hero2, _make_test_final_battle())
	var purity2_attr_part: float = score2.build_purity_raw
	# 虽然属性部分为0，但技能触发和伙伴协同可能有分
	_assert(purity2_attr_part >= 0, "均衡build纯度 >= 0")

	print("  极端build纯度: %.1f | 均衡build纯度: %.1f" % [purity1, purity2_attr_part])
	_assert(purity1 > purity2_attr_part, "极端build纯度应高于均衡build")

# --- 测试5: 连锁展示公式调优 ---
func _test_score_formula_chain_showcase() -> void:
	print("\n[连锁展示公式调优测试]")
	var ss := SettlementSystem.new()

	var run1 := _make_test_run()
	run1.max_chain_reached = 4
	run1.total_chain_count = 10
	var score1: FighterArchiveScore = ss.calculate_score(run1, _make_test_hero(), _make_test_final_battle())
	# 4*10 + 10*2 = 60，加上援助最多30，总计最多90
	var chain1: float = score1.chain_showcase_raw
	_assert(chain1 >= 40, "max_chain=4, total_chain=10 应至少得40分")

	var run2 := _make_test_run()
	run2.max_chain_reached = 0
	run2.total_chain_count = 0
	var score2: FighterArchiveScore = ss.calculate_score(run2, _make_test_hero(), _make_test_final_battle())
	var chain2: float = score2.chain_showcase_raw
	_assert(chain2 >= 0, "无连锁时 >= 0")
	_assert(chain1 > chain2, "有连锁应高于无连锁")

	print("  有连锁: %.1f | 无连锁: %.1f" % [chain1, chain2])

# --- 测试6: PVP评分 ---
func _test_score_formula_pvp() -> void:
	print("\n[PVP评分测试]")
	var ss := SettlementSystem.new()

	var run_win := _make_test_run()
	run_win.pvp_10th_result = 1
	run_win.pvp_20th_result = 1
	var score_win: FighterArchiveScore = ss.calculate_score(run_win, _make_test_hero(), _make_test_final_battle())
	_assert(score_win.pvp_performance_raw == 80, "双胜PVP = 80分")

	var run_lose := _make_test_run()
	run_lose.pvp_10th_result = 2
	run_lose.pvp_20th_result = 2
	var score_lose: FighterArchiveScore = ss.calculate_score(run_lose, _make_test_hero(), _make_test_final_battle())
	_assert(score_lose.pvp_performance_raw == 30, "双败PVP = 30分")

	var run_mixed := _make_test_run()
	run_mixed.pvp_10th_result = 1
	run_mixed.pvp_20th_result = 2
	var score_mixed: FighterArchiveScore = ss.calculate_score(run_mixed, _make_test_hero(), _make_test_final_battle())
	_assert(score_mixed.pvp_performance_raw == 55, "一胜一败PVP = 55分")

# --- 辅助方法：构造测试数据 ---

func _make_test_run() -> RuntimeRun:
	var run := RuntimeRun.new()
	run.initial_attr_sum = 60
	run.current_turn = 30
	run.gold_earned_total = 200
	run.gold_spent = 150
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
