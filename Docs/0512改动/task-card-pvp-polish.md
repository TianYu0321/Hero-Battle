# 局内PVP完善任务卡（2项）

---

## 修复1：删除"事件透视+5次"空注释（避免歧义）

### 文件
`scripts/systems/run_controller.gd`

### 修改内容
找到 `_process_reward` 中 `"pvp_result"` 分支的失败处理：

```gdscript
# 旧代码（删除或注释掉事件透视部分）：
"pvp_result":
    ...
    if won:
        # 胜利：150金币 + 15全属性
        _run.gold_owned += 150
        _run.gold_earned_total += 150
        _character_manager.modify_hero_stats({1: 15, 2: 15, 3: 15, 4: 15, 5: 15})
        print("[RunController] 局内PVP胜利：金币+150，全属性+15")
    else:
        # 失败：50金币 + 5全属性 + 5次事件透视
        _run.gold_owned += 50
        _run.gold_earned_total += 50
        _character_manager.modify_hero_stats({1: 5, 2: 5, 3: 5, 4: 5, 5: 5})
        # TODO: 事件透视+5次（事件系统未实现，暂不支持）
        print("[RunController] 局内PVP失败：金币+50，全属性+5")
```

改为：
```gdscript
"pvp_result":
    ...
    if won:
        _run.gold_owned += 150
        _run.gold_earned_total += 150
        _character_manager.modify_hero_stats({1: 15, 2: 15, 3: 15, 4: 15, 5: 15})
        print("[RunController] 局内PVP胜利：金币+150，全属性+15")
    else:
        _run.gold_owned += 50
        _run.gold_earned_total += 50
        _character_manager.modify_hero_stats({1: 5, 2: 5, 3: 5, 4: 5, 5: 5})
        print("[RunController] 局内PVP失败：金币+50，全属性+5")
```

---

## 修复2：_end_run 中 final_grade 接入真实评分

### 文件
`scripts/systems/run_controller.gd`

### 问题
`_end_run` 用于死亡/放弃等提前结束的情况，此时 `final_grade` 硬编码为 "S"，Settlement 场景显示不准确。

### 修改内容
在 `_end_run` 方法中，在组装 `archive_data` 之前，调用 SettlementSystem 计算真实评分：

```gdscript
func _end_run() -> void:
    var partners: Array[RuntimePartner] = _character_manager.get_partners()
    
    # --- 计算真实评分（新增）---
    # 创建 RuntimeFinalBattle（简化，因为不是终局战结束）
    var fb := RuntimeFinalBattle.new()
    fb.result = 0  # 非终局
    fb.hero_remaining_hp = _hero.current_hp
    fb.hero_max_hp = _hero.max_hp
    fb.damage_dealt_to_enemy = 0
    fb.enemy_max_hp = 100
    
    var score: FighterArchiveScore = _settlement_system.calculate_score(_run, _hero, fb, partners)
    var real_grade: String = score.grade
    var real_score: int = int(score.total_score)
    print("[RunController] _end_run 计算评分: grade=%s, score=%d" % [real_grade, real_score])
    
    # --- 生成档案数据（修改 final_grade 和 final_score）---
    var archive_data: Dictionary = {
        "final_grade": real_grade,   # 从 "S" 改为真实评分
        "final_score": real_score,   # 从 _run.total_score 改为真实评分
        ... 其他字段保持不变 ...
    }
    
    ... 后续不变 ...
```

### 注意
- `RuntimeFinalBattle` 需要导入（如果还没导入的话）
- `_settlement_system` 在 `_ready` 中已初始化，可直接使用
- 死亡/放弃时的评分会比完整通关低，这是预期行为（ SettlementSystem 会根据层数/五维/金币综合计算）

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/systems/run_controller.gd` | 删除PVP失败奖励中的"事件透视+5次"注释 |
| 2 | `scripts/systems/run_controller.gd` | `_end_run` 中接入 SettlementSystem 真实评分 |

---

## 验收标准

- [ ] PVP失败后控制台输出 `[RunController] 局内PVP失败：金币+50，全属性+5`（无"事件透视"字样）
- [ ] 中途死亡/放弃后，Settlement 场景的评分显示为真实计算值（如C/B/A，不再是硬编码S）
- [ ] 完整通关后的评分仍由 `_settle` 分支的真实SettlementSystem计算，不受影响