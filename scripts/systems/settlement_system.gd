## res://scripts/systems/settlement_system.gd
## 模块: SettlementSystem
## 职责: 终局结算：从GameState提取数据生成FighterArchive，评分5项权重+评级
## 依赖: RuntimeRun, RuntimeHero, RuntimePartner, RuntimeFinalBattle, FighterArchiveMain, FighterArchiveScore
## class_name: SettlementSystem

class_name SettlementSystem
extends Node

# 权重从配置表读取，硬编码仅作为fallback
var _weight_final: float = 0.40
var _weight_attr: float = 0.25
var _weight_level: float = 0.20
var _weight_gold: float = 0.15
## var _weight_chain: float = 0.10  ## v2.0已删除

var _grade_s: int = 85
var _grade_a: int = 70
var _grade_b: int = 55
var _grade_c: int = 35

func _ready() -> void:
	var scoring_cfg: Dictionary = ConfigManager.get_scoring_config()
	for k in scoring_cfg:
		var cfg: Dictionary = scoring_cfg[k]
		_weight_final = cfg.get("weight_final_performance", _weight_final)
		_weight_training = cfg.get("weight_training_efficiency", _weight_training)
		_weight_pvp = cfg.get("weight_pvp_performance", _weight_pvp)
		_weight_purity = cfg.get("weight_build_purity", _weight_purity)
		_weight_chain = cfg.get("weight_chain_showcase", _weight_chain)
		_grade_s = cfg.get("grade_s_threshold", _grade_s)
		_grade_a = cfg.get("grade_a_threshold", _grade_a)
		_grade_b = cfg.get("grade_b_threshold", _grade_b)
		_grade_c = cfg.get("grade_c_threshold", _grade_c)
		break


func calculate_score(run: RuntimeRun, hero: RuntimeHero, final_battle: RuntimeFinalBattle) -> FighterArchiveScore:
	var score := FighterArchiveScore.new()
	var attrs: Array[int] = [hero.current_vit, hero.current_str, hero.current_agi, hero.current_tec, hero.current_mnd]

	# 1. 终局战表现分 (0-100)
	var final_perf: float = 0.0
	if final_battle.result == 1:  # 胜利
		final_perf += 50.0
	var hp_ratio: float = 0.0
	if final_battle.hero_max_hp > 0:
		hp_ratio = float(final_battle.hero_remaining_hp) / float(final_battle.hero_max_hp)
	final_perf += hp_ratio * 30.0
	var dmg_ratio: float = 0.0
	if final_battle.enemy_max_hp > 0:
		dmg_ratio = float(final_battle.damage_dealt_to_enemy) / float(final_battle.enemy_max_hp)
	final_perf += minf(dmg_ratio, 1.0) * 20.0
	final_perf = clampf(final_perf, 0.0, 100.0)

	# 2. 养成效率分 (0-100) — Phase 2调优：放大成长感
	var training_eff: float = 0.0
	if run.initial_attr_sum > 0 and run.current_turn > 0:
		var current_sum: int = hero.current_vit + hero.current_str + hero.current_agi + hero.current_tec + hero.current_mnd
		# 调优：从"总和/初始-1"改为"(当前-初始)/回合数 × 2"
		var growth_per_turn: float = float(current_sum - run.initial_attr_sum) / float(run.current_turn)
		training_eff += clampf(growth_per_turn * 2.0, 0.0, 40.0)
	var gold_eff: float = 0.0
	if run.gold_earned_total > 0:
		gold_eff = clampf(float(run.gold_spent) / float(run.gold_earned_total) * 30.0, 0.0, 30.0)
	# 属性均衡度（简化：标准差倒数映射）
	var std_dev: float = _std_dev(attrs)
	var balance_score: float = clampf((1.0 / maxf(std_dev, 1.0)) * 100.0, 0.0, 20.0)
	# 精英战胜率
	var elite_wr: float = 0.0
	if run.elite_total_count > 0:
		elite_wr = clampf(float(run.elite_win_count) / float(run.elite_total_count) * 20.0, 0.0, 20.0)
	training_eff = clampf(training_eff + gold_eff + balance_score + elite_wr, 0.0, 100.0)

	# 3. PVP表现分 (0-100)
	var pvp_score: float = 0.0
	if run.pvp_10th_result == 1:
		pvp_score += 40.0
	elif run.pvp_10th_result == 2:
		pvp_score += 15.0
	if run.pvp_20th_result == 1:
		pvp_score += 40.0
	elif run.pvp_20th_result == 2:
		pvp_score += 15.0
	pvp_score = clampf(pvp_score, 0.0, 100.0)

	# 4. 流派纯度分 (0-100) — Phase 2调优：鼓励极端build
	var purity: float = 0.0
	var sorted_attrs: Array[int] = attrs.duplicate()
	sorted_attrs.sort()
	sorted_attrs.reverse()
	var max_attr: int = sorted_attrs[0] if sorted_attrs.size() > 0 else 0
	var second_max_attr: int = sorted_attrs[1] if sorted_attrs.size() > 1 else 0
	var sum_attrs: int = 0
	for a in attrs:
		sum_attrs += a
	if sum_attrs > 0:
		# 调优：从"最高属性占比"改为"（最高-次高）/ 总属性 × 100"
		purity += clampf(float(max_attr - second_max_attr) / float(sum_attrs) * 100.0, 0.0, 50.0)
	# 技能触发次数（简化占位）
	purity += clampf(float(hero.total_enemies_killed) / 10.0 * 30.0, 0.0, 30.0)
	# 伙伴协同（简化占位）
	purity += clampf(float(run.total_aid_trigger_count) / 10.0 * 20.0, 0.0, 20.0)
	purity = clampf(purity, 0.0, 100.0)

	# 5. 连锁展示分 (0-100) — Phase 2调优：放大连锁收益
	var chain_score: float = 0.0
	# 调优：最高连锁段数×10
	chain_score += float(run.max_chain_reached) * 10.0
	# 调优：总连锁次数×2
	chain_score += float(run.total_chain_count) * 2.0
	# 援助触发次数（保持不变）
	chain_score += clampf(float(run.total_aid_trigger_count) / 10.0 * 30.0, 0.0, 30.0)
	chain_score = clampf(chain_score, 0.0, 100.0)

	# 加权总分
	var total: float = (
		final_perf * _weight_final
		+ training_eff * _weight_training
		+ pvp_score * _weight_pvp
		+ purity * _weight_purity
		+ chain_score * _weight_chain
	)

	score.final_performance_raw = final_perf
	score.final_performance_weighted = final_perf * _weight_final
	score.training_efficiency_raw = training_eff
	score.training_efficiency_weighted = training_eff * _weight_training
	score.pvp_performance_raw = pvp_score
	score.pvp_performance_weighted = pvp_score * _weight_pvp
	score.build_purity_raw = purity
	score.build_purity_weighted = purity * _weight_purity
	score.chain_showcase_raw = chain_score
	score.chain_showcase_weighted = chain_score * _weight_chain
	score.total_score = total
	score.grade = _calculate_grade(int(total))

	return score


func generate_fighter_archive(run: RuntimeRun, hero: RuntimeHero, partners: Array[RuntimePartner], score: FighterArchiveScore) -> FighterArchiveMain:
	var archive := FighterArchiveMain.from_runtime(run, hero, partners)
	archive.final_score = int(score.total_score)
	archive.final_grade = score.grade
	archive.is_fixed = true
	return archive


# --- 私有方法 ---

# 评级阈值从配置表读取，硬编码仅作为fallback
func _calculate_grade(total_score: int) -> String:
	if total_score >= _grade_s:
		return "S"
	elif total_score >= _grade_a:
		return "A"
	elif total_score >= _grade_b:
		return "B"
	elif total_score >= _grade_c:
		return "C"
	else:
		return "D"


func _std_dev(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var sum: int = 0
	for v in values:
		sum += v
	var mean: float = float(sum) / float(values.size())
	var variance: float = 0.0
	for v in values:
		var diff: float = float(v) - mean
		variance += diff * diff
	variance /= float(values.size())
	return sqrt(variance)
