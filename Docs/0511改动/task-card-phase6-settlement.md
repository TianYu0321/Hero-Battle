# Phase 6 任务卡：终局评分完善

> 目标：Settlement 场景显示真实的四维度评分，不再硬编码 "S"。

---

## 当前问题

1. `settlement.gd` 的 `_populate_from_data` 直接取 `data.get("final_grade", "S")`，_grade 是 RunController 硬编码传过来的
2. `SettlementSystem.calculate_score()` 需要 `RuntimeFinalBattle` 对象，但该模型类不存在
3. `BattleEngine.execute_battle()` 返回的 result 缺少 `damage_dealt_to_enemy` 和 `enemy_max_hp`，SettlementSystem 计算终局战表现分需要这两个字段

---

## 修复步骤

### Step 1：新建 `scripts/models/runtime_final_battle.gd`

```gdscript
class_name RuntimeFinalBattle
extends RefCounted

var result: int = 0              # 0=失败, 1=胜利
var hero_remaining_hp: int = 0
var hero_max_hp: int = 0
var damage_dealt_to_enemy: int = 0
var enemy_max_hp: int = 0

func to_dict() -> Dictionary:
    return {
        "result": result,
        "hero_remaining_hp": hero_remaining_hp,
        "hero_max_hp": hero_max_hp,
        "damage_dealt_to_enemy": damage_dealt_to_enemy,
        "enemy_max_hp": enemy_max_hp,
    }

static func from_dict(data: Dictionary) -> RuntimeFinalBattle:
    var fb := RuntimeFinalBattle.new()
    fb.result = data.get("result", 0)
    fb.hero_remaining_hp = data.get("hero_remaining_hp", 0)
    fb.hero_max_hp = data.get("hero_max_hp", 0)
    fb.damage_dealt_to_enemy = data.get("damage_dealt_to_enemy", 0)
    fb.enemy_max_hp = data.get("enemy_max_hp", 0)
    return fb
```

### Step 2：修改 `scripts/core/battle_engine.gd` 的 `finalize()`

在 `finalize()` 返回的 result 中增加 `damage_dealt_to_enemy` 和 `enemy_max_hp`：

```gdscript
# 在 finalize() 末尾，构造 result 时：
var result := {
    "winner": winner,
    "enemies": enemy_snapshots,
    "hero": hero_snapshot,
    "turns_elapsed": _turn_count,
    "max_chain_count": _max_chain,
    "total_chain_count": _total_chain_count,
    "hero_remaining_hp": hero_snapshot.get("hp", 0),
    "hero_max_hp": hero_snapshot.get("max_hp", 100),
    "gold_reward": 0,  # 由 RunController 补充
    # **新增**：
    "damage_dealt_to_enemy": enemy_snapshot.get("max_hp", 0) - enemy_snapshot.get("hp", 0),
    "enemy_max_hp": enemy_snapshot.get("max_hp", 0),
}
```

### Step 3：修改 `scripts/systems/run_controller.gd` 的 archive_data

在 FINISHED 分支，补充终局战数据（damage_dealt_to_enemy、enemy_max_hp）：

```gdscript
# 从 _pending_battle_result（终局战的 battle_result）取数据
var final_battle_data: Dictionary = _pending_battle_result if _pending_battle_result != null else {}

var archive_data: Dictionary = {
    # ... 已有字段 ...
    "final_battle": {
        "result": 1 if final_battle_data.get("winner", "") == "player" else 0,
        "hero_remaining_hp": final_battle_data.get("hero_remaining_hp", 0),
        "hero_max_hp": final_battle_data.get("hero_max_hp", _hero.max_hp),
        "damage_dealt_to_enemy": final_battle_data.get("damage_dealt_to_enemy", 0),
        "enemy_max_hp": final_battle_data.get("enemy_max_hp", 0),
    },
}
```

**注意**：`_pending_battle_result` 是 RunController 在 `_run_battle_engine` 中保存的。如果变量名不同，请在 RunController 中搜索 "pending" 或 "battle_result" 确认。

### Step 4：修改 `scenes/settlement/settlement.gd`，调用 SettlementSystem 计算真实评分

```gdscript
func _ready() -> void:
    ...
    var gm = get_node_or_null("/root/GameManager")
    if gm != null and not gm.pending_archive.is_empty():
        _archive_data = gm.pending_archive.duplicate()
        _calculate_real_score()   # **新增**
        _populate_from_data(_archive_data)
    else:
        ...

func _calculate_real_score() -> void:
    # 从 archive_data 反序列化 RuntimeRun / RuntimeHero / RuntimeFinalBattle / RuntimePartner
    var run_data: Dictionary = _archive_data.get("run", {})
    var hero_data: Dictionary = _archive_data.get("hero", {})
    var final_battle_data: Dictionary = _archive_data.get("final_battle", {})
    var partners_data: Array = _archive_data.get("partners", [])
    
    var run := RuntimeRun.new()
    run.current_turn = _archive_data.get("final_turn", 30)
    run.hero_config_id = _archive_data.get("hero_config_id", 0)
    run.battle_win_count = _archive_data.get("battle_win_count", 0)
    run.elite_win_count = _archive_data.get("elite_win_count", 0)
    run.gold_earned_total = _archive_data.get("gold_earned_total", 0)
    run.gold_owned = _archive_data.get("gold_earned_total", 0)  # 结算时 gold_owned = gold_earned_total（没有剩余概念）
    run.gold_spent = _archive_data.get("gold_spent", 0)
    
    var hero := RuntimeHero.new()
    hero.hero_config_id = _archive_data.get("hero_config_id", 0)
    hero.current_vit = _archive_data.get("attr_snapshot_vit", 0)
    hero.current_str = _archive_data.get("attr_snapshot_str", 0)
    hero.current_agi = _archive_data.get("attr_snapshot_agi", 0)
    hero.current_tec = _archive_data.get("attr_snapshot_tec", 0)
    hero.current_mnd = _archive_data.get("attr_snapshot_mnd", 0)
    hero.max_hp = _archive_data.get("max_hp_reached", 0)
    hero.total_training_count = _archive_data.get("training_count", 0)
    
    var final_battle := RuntimeFinalBattle.from_dict(final_battle_data)
    
    var partners: Array[RuntimePartner] = []
    for p_dict in partners_data:
        partners.append(RuntimePartner.from_dict(p_dict))
    
    # 计算评分
    var settlement_system := SettlementSystem.new()
    var score := settlement_system.calculate_score(run, hero, final_battle, partners)
    
    # 把真实评分写回 _archive_data
    _archive_data["final_score"] = int(score.total_score)
    _archive_data["final_grade"] = score.grade
    _archive_data["score_breakdown"] = {
        "final_performance_raw": score.final_performance_raw,
        "final_performance_weighted": score.final_performance_weighted,
        "attr_total_raw": score.attr_total_raw,
        "attr_total_weighted": score.attr_total_weighted,
        "level_score_raw": score.level_score_raw,
        "level_score_weighted": score.level_score_weighted,
        "gold_score_raw": score.gold_score_raw,
        "gold_score_weighted": score.gold_score_weighted,
    }
```

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scripts/models/runtime_final_battle.gd` | 新建 | 终局战数据模型 |
| 2 | `scripts/core/battle_engine.gd` | 修改 | finalize() 增加 damage_dealt_to_enemy + enemy_max_hp |
| 3 | `scripts/systems/run_controller.gd` | 修改 | FINISHED 分支 archive_data 增加 final_battle 字典 |
| 4 | `scenes/settlement/settlement.gd` | 修改 | _ready() 中调用 _calculate_real_score() |
| 5 | `scenes/settlement/settlement.gd` | 新增 | _calculate_real_score() 函数 |

---

## 验收标准

- [ ] 完成一局游戏 → Settlement 场景显示的 _grade 是计算出来的（A/B/C/D/S），不是硬编码 S
- [ ] 如果主角五维很低、终局战惨败，显示的 grade 应该是 D 或 C
- [ ] Settlement 显示五维属性与游戏中实际一致
- [ ] 点击"生成档案"后，档案文件中的 final_score 和 final_grade 与 Settlement 显示一致
