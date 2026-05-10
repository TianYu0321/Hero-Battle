## res://scripts/systems/final_boss_pool.gd
## 模块: FinalBossPool
## 职责: 终局Boss池管理 — 配置驱动，支持随机/按难度选择
## 规格依据: v2.0(1) "从Boss池随机抽取一个"
## 设计原则: 配置驱动，所有可变数据来自配置表；纯函数计算，无副作用

class_name FinalBossPool
extends RefCounted

## 默认Boss配置 — 防御式编程，配置缺失时使用
const _DEFAULT_BOSS: Dictionary = {
    "enemy_config_id": 2005,
    "weight": 1,
    "name": "混沌领主·终局",
    "difficulty": 5,
}

var _boss_configs: Dictionary = {}
var _boss_list: Array = []
var _rng: RandomNumberGenerator = null

## 构造时注入RNG，确保可测试性
func _init(rng: RandomNumberGenerator) -> void:
    if rng == null:
        push_error("[FinalBossPool] RNG cannot be null")
        return
    _rng = rng
    _load_configs()

## 从ConfigManager加载配置
func _load_configs() -> void:
    _boss_configs = ConfigManager.get_final_boss_configs()
    if _boss_configs.is_empty():
        push_warning("[FinalBossPool] 配置为空，使用默认Boss池")
        _boss_configs = {
            "boss_pool": [_DEFAULT_BOSS.duplicate()],
            "selection_mode": "random",
        }
    _boss_list = _boss_configs.get("boss_pool", [])
    if _boss_list.is_empty():
        push_warning("[FinalBossPool] Boss池列表为空，使用默认Boss")
        _boss_list = [_DEFAULT_BOSS.duplicate()]

## 随机选择一个Boss（按权重加权随机）
## @return: {enemy_config_id, name, difficulty} — 返回duplicate防止外部修改
func select_random_boss() -> Dictionary:
    if _boss_list.is_empty():
        push_warning("[FinalBossPool] Boss池为空，使用默认Boss")
        return _DEFAULT_BOSS.duplicate()

    ## 防御式：验证每个Boss条目完整性
    var valid_bosses: Array = []
    for boss in _boss_list:
        if boss is Dictionary and boss.has("enemy_config_id") and boss.has("weight"):
            valid_bosses.append(boss)
    if valid_bosses.is_empty():
        push_warning("[FinalBossPool] 无有效Boss配置，使用默认Boss")
        return _DEFAULT_BOSS.duplicate()

    ## 按权重加权随机
    var total_weight: int = 0
    for boss in valid_bosses:
        total_weight += maxi(1, int(boss.get("weight", 1)))

    if total_weight <= 0:
        return valid_bosses[0].duplicate()

    var roll: int = _rng.randi_range(1, total_weight)
    var cumulative: int = 0
    for boss in valid_bosses:
        cumulative += maxi(1, int(boss.get("weight", 1)))
        if roll <= cumulative:
            return boss.duplicate()

    ## 兜底：返回最后一个
    return valid_bosses[-1].duplicate()


## 按难度选择Boss
## @param target_difficulty: 目标难度等级
## @return: Boss配置字典
func select_by_difficulty(target_difficulty: int) -> Dictionary:
    if _boss_list.is_empty():
        push_warning("[FinalBossPool] Boss池为空，回退到随机选择")
        return select_random_boss()

    var candidates: Array = _boss_list.filter(
        func(b):
            return b is Dictionary and b.get("difficulty", 0) == target_difficulty
    )
    if candidates.is_empty():
        push_warning("[FinalBossPool] 难度%d无对应Boss，回退到随机选择" % target_difficulty)
        return select_random_boss()
    return candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate()


## 获取Boss池大小
func get_pool_size() -> int:
    return _boss_list.size()


## 获取所有Boss名称列表（用于日志/调试）
func get_boss_names() -> Array[String]:
    var names: Array[String] = []
    for boss in _boss_list:
        if boss is Dictionary:
            names.append(boss.get("name", "???"))
    return names
