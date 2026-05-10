## res://scripts/systems/settlement_system.gd
## 模块: SettlementSystem
## 职责: 终局结算：从GameState提取数据生成FighterArchive，v2.0四维度评分
## 依赖: RuntimeRun, RuntimeHero, RuntimePartner, RuntimeFinalBattle, FighterArchiveMain, FighterArchiveScore
## class_name: SettlementSystem

class_name SettlementSystem
extends Node

# v2.0 四维度权重
var _weight_final: float = 0.40
var _weight_attr: float = 0.25
var _weight_level: float = 0.20
var _weight_gold: float = 0.15

# 参考值（用于归一化评分）
var _ref_attr_total: int = 500       # 五维总和参考值
var _ref_level_score: int = 100      # 等级分参考值

var _grade_s: int = 90
var _grade_a: int = 75
var _grade_b: int = 60
var _grade_c: int = 40

func _ready() -> void:
	var scoring_cfg: Dictionary = ConfigManager.get_scoring_config()
	for k in scoring_cfg:
		var cfg: Dictionary = scoring_cfg[k]
		_weight_final = cfg.get("weight_final_performance", _weight_final)
		_grade_s = cfg.get("grade_s_threshold", _grade_s)
		_grade_a = cfg.get("grade_a_threshold", _grade_a)
		_grade_b = cfg.get("grade_b_threshold", _grade_b)
		_grade_c = cfg.get("grade_c_threshold", _grade_c)
		break


func calculate_score(run: RuntimeRun, hero: RuntimeHero, final_battle: RuntimeFinalBattle, partners: Array[RuntimePartner]) -> FighterArchiveScore:
	var score := FighterArchiveScore.new()
	var attrs: Array[int] = [hero.current_vit, hero.current_str, hero.current_agi, hero.current_tec, hero.current_mnd]
	var attr_sum: int = 0
	for a in attrs:
		attr_sum += a

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

	# 2. 五维属性分 (0-100)
	var attr_score: float = clampf(float(attr_sum) / float(_ref_attr_total) * 100.0, 0.0, 100.0)

	# 3. 伙伴/主角等级分 (0-100)
	var partner_level_sum: int = 0
	for p in partners:
		partner_level_sum += p.current_level
	var level_raw: float = float(hero.hero_config_id * 5 + partner_level_sum * 3)
	var level_score: float = clampf(level_raw / float(_ref_level_score) * 100.0, 0.0, 100.0)

	# 4. 剩余金币分 (0-100)
	var gold_score: float = 0.0
	if run.gold_earned_total > 0:
		gold_score = clampf(float(run.gold_owned) / float(run.gold_earned_total) * 100.0, 0.0, 100.0)

	# 加权总分
	var total: float = (
		final_perf * _weight_final
		+ attr_score * _weight_attr
		+ level_score * _weight_level
		+ gold_score * _weight_gold
	)

	score.final_performance_raw = final_perf
	score.final_performance_weighted = final_perf * _weight_final
	score.attr_total_raw = attr_score
	score.attr_total_weighted = attr_score * _weight_attr
	score.level_score_raw = level_score
	score.level_score_weighted = level_score * _weight_level
	score.gold_score_raw = gold_score
	score.gold_score_weighted = gold_score * _weight_gold
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
