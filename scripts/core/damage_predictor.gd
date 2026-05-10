## res://scripts/core/damage_predictor.gd
## 模块: DamagePredictor
## 职责: 预计损失血量计算 — 纯函数，无副作用
## 规格依据: v2补充说明 "基于玩家五维和怪物属性计算预计损失血量"
## 设计原则: 纯函数，输入确定则输出确定，便于单元测试

class_name DamagePredictor
extends RefCounted

## 默认属性值 — 防御式编程
const _DEFAULT_STAT: float = 10.0

## 基础伤害倍率
const _BASE_DAMAGE_MULTIPLIER: float = 1.0

## 防御减免系数
const _DEFENSE_VIT_MULTIPLIER: float = 0.4
const _DEFENSE_TEC_MULTIPLIER: float = 0.2

## 保守波动系数
const _CONSERVATIVE_VARIANCE: float = 0.9

## 最小每击伤害
const _MIN_PER_HIT: float = 1.0

## 估算战斗回合数
const _ESTIMATED_ROUNDS: int = 20

## 最低命中率
const _MIN_HIT_RATE: float = 0.3

## 最高命中率
const _MAX_HIT_RATE: float = 0.9


## 预测单次攻击损失血量（纯函数）
## @param hero_stats: {vit, str, agi, tec, mnd} — 玩家五维
## @param enemy_stats: {str, agi, ...} — 怪物属性
## @return: 预计损失血量（最低1）
static func predict_damage_taken(hero_stats: Dictionary, enemy_stats: Dictionary) -> int:
    ## 防御式：空检查
    if hero_stats.is_empty() or enemy_stats.is_empty():
        push_warning("[DamagePredictor] 空属性输入，返回最小伤害1")
        return 1

    ## 标准化读取属性 — 支持多种键名
    var enemy_str: float = float(enemy_stats.get("str", enemy_stats.get("strength", _DEFAULT_STAT)))
    var hero_vit: float = float(hero_stats.get("vit", hero_stats.get("physique", _DEFAULT_STAT)))
    var hero_tec: float = float(hero_stats.get("tec", hero_stats.get("technique", _DEFAULT_STAT)))

    ## 防御式：非负检查
    enemy_str = maxf(0.0, enemy_str)
    hero_vit = maxf(0.0, hero_vit)
    hero_tec = maxf(0.0, hero_tec)

    ## 基础伤害: 敌人力量 × 倍率
    var base_damage: float = enemy_str * _BASE_DAMAGE_MULTIPLIER

    ## 防御减免: 玩家体魄 × 0.4 + 技巧 × 0.2
    var defense: float = hero_vit * _DEFENSE_VIT_MULTIPLIER + hero_tec * _DEFENSE_TEC_MULTIPLIER

    ## 保守估计（取波动下限）
    var raw_damage: float = (base_damage - defense) * _CONSERVATIVE_VARIANCE
    var damage: float = maxf(raw_damage, _MIN_PER_HIT)

    return int(damage)


## 预测战斗总损失血量（20回合估算，纯函数）
## @param hero_stats: 玩家五维
## @param enemy_stats: 怪物属性
## @return: 预计总损失血量
static func predict_total_damage(hero_stats: Dictionary, enemy_stats: Dictionary) -> int:
    var per_hit: int = predict_damage_taken(hero_stats, enemy_stats)

    ## 估算被击中次数（考虑闪避和速度）
    var hero_agi: float = float(hero_stats.get("agi", hero_stats.get("agility", _DEFAULT_STAT)))
    var enemy_agi: float = float(enemy_stats.get("agi", enemy_stats.get("agility", _DEFAULT_STAT)))

    hero_agi = maxf(0.0, hero_agi)
    enemy_agi = maxf(0.0, enemy_agi)

    ## 命中率 = 敌人敏捷 / (玩家敏捷 + 敌人敏捷 + 极小值)
    var hit_rate: float = clampf(
        enemy_agi / (hero_agi + enemy_agi + 0.1),
        _MIN_HIT_RATE,
        _MAX_HIT_RATE
    )

    var estimated_hits: int = int(_ESTIMATED_ROUNDS * hit_rate)
    ## 防御式：至少被击中1次
    estimated_hits = maxi(1, estimated_hits)

    return per_hit * estimated_hits


## 预测战斗结果（纯函数）
## @param hero_hp: 玩家当前血量
## @param hero_stats: 玩家五维
## @param enemy_stats: 怪物属性
## @return: {
##   per_hit: int — 每击预计损失,
##   total_estimated: int — 总预计损失,
##   survival_rate: float — 生存率(0-1),
##   risk_level: String — "low"/"medium"/"high"/"extreme",
##   recommendation: String — 建议文本
## }
static func predict_battle_outcome(hero_hp: int, hero_stats: Dictionary, enemy_stats: Dictionary) -> Dictionary:
    ## 防御式：空检查
    if hero_hp <= 0:
        return {
            "per_hit": 0,
            "total_estimated": 0,
            "survival_rate": 0.0,
            "risk_level": "extreme",
            "recommendation": _get_recommendation("extreme"),
        }

    var total_damage: int = predict_total_damage(hero_stats, enemy_stats)

    ## 防御式：避免除零
    var denominator: float = float(total_damage) + 1.0
    var survival_rate: float = clampf(float(hero_hp) / denominator, 0.0, 1.0)

    var risk_level: String = _calculate_risk_level(survival_rate)

    return {
        "per_hit": predict_damage_taken(hero_stats, enemy_stats),
        "total_estimated": total_damage,
        "survival_rate": survival_rate,
        "risk_level": risk_level,
        "recommendation": _get_recommendation(risk_level),
    }


## 根据生存率计算风险等级（纯函数）
static func _calculate_risk_level(survival_rate: float) -> String:
    if survival_rate >= 0.8:
        return "low"
    elif survival_rate >= 0.5:
        return "medium"
    elif survival_rate >= 0.3:
        return "high"
    else:
        return "extreme"


## 根据风险等级获取建议文本（纯函数）
static func _get_recommendation(risk: String) -> String:
    match risk:
        "low":
            return "可以挑战"
        "medium":
            return "建议休息后再战"
        "high":
            return "风险较高，建议训练提升"
        "extreme":
            return "极度危险，请避免战斗"
        _:
            return "未知"


## 获取风险等级的颜色（纯函数工具方法）
static func get_risk_color(risk: String) -> Color:
    match risk:
        "low":
            return Color.GREEN
        "medium":
            return Color.YELLOW
        "high":
            return Color.ORANGE
        "extreme":
            return Color.RED
        _:
            return Color.GRAY


## 获取风险等级的显示文本（纯函数工具方法，含颜色标记）
static func get_risk_display_text(risk: String) -> String:
    match risk:
        "low":
            return "低风险"
        "medium":
            return "中等风险"
        "high":
            return "高风险"
        "extreme":
            return "极度危险"
        _:
            return "未知"
