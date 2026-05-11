# Bug修复任务卡：Phase 2测试报告（终版）

> 来源：Phase 2全流程测试报告（2026-05-11）
> 用户确认：影子舞者步数上限=20 | v2.0取消PVP惩罚（不考虑1.0版本数据）

---

## 🔴 BUG-001 | P0 | PVP战斗回合数为0（阻塞验收）

**一句话**：PVP敌人镜像没设 `is_alive=true`，BattleEngine检查到无存活敌人，战斗开局即结束，turns=0。

### 修复文件
`scripts/systems/pvp_opponent_generator.gd`

### 修复内容
在 `_generate_player_enemy()` 中，构造敌人镜像后添加：
```gdscript
unit["is_alive"] = true
```

### 验证
运行 `test_pvp_real.tscn`，`combat_summary.turns >= 1`。

---

## 🟡 BUG-003 | P2 | Skill配置键float形式查找失败

**一句话**：skill_id从JSON反序列化后是float（8001.0），`str()`转字符串变成"8001.0"，匹配不到配置键"8001"。

### 修复文件
`autoload/config_manager.gd` → `get_skill_config()`

### 修复内容
```gdscript
func get_skill_config(skill_id) -> Dictionary:
    var normalized_id: String
    if skill_id is float:
        normalized_id = str(int(skill_id))
    elif skill_id is int:
        normalized_id = str(skill_id)
    else:
        normalized_id = str(skill_id)
        if normalized_id.ends_with(".0"):
            normalized_id = normalized_id.left(normalized_id.length() - 2)
    return _skill_configs.get(normalized_id, {})
```

---

## 🟡 BUG-002 | P2 | DamagePredictor空属性输入警告

**一句话**：训练/救援/事件节点调用了伤害预测，但这些节点没有敌人数据，触发WARNING。

### 修复文件
`scenes/run_main/run_main.gd` → `_update_monster_info()`

### 修复内容
调用 `DamagePredictor` 前增加判断：
```gdscript
if not has_enemy or enemy_stats.is_empty():
    enemy_info_panel.visible = false
    return
```

---

## 🟡 BUG-004 | P3 | 影子舞者步数配置与测试不匹配

**用户确认：影子舞者步数上限 = 20**

**一句话**：配置表里写15，测试期望20。用户确认20。

### 修复文件
`resources/configs/hero_configs.json`（或 node_pool_configs.json）

### 修复内容
找到 `shadow_dancer` 配置，将 `max_steps` 改为 20。

---

## 🟡 BUG-005 | P2 | PVP惩罚策略规格冲突

**用户确认：v2.0取消PVP失败惩罚，不考虑1.0版本数据**

**一句话**：实现用了NullPenaltyStrategy（无惩罚），但测试还按旧规格断言有惩罚。

### 修复文件
`scenes/test/test_phase2_full_run.gd`

### 修复内容
**删除**以下惩罚相关断言（约第160-164行）：
```gdscript
# 删除这段：
if not result.won:
    assert(result.penalty_tier == "gold_50")
    # 或 assert(result.penalty_tier == "hp_30")
```

改为：
```gdscript
# v2.0取消PVP失败惩罚，penalty_tier始终为"none"
assert(result.penalty_tier == "none")
```

---

## 🟢 BUG-006 | P3 | test_battle_core测试未执行

**一句话**：文件编码问题导致测试场景无法加载。

### 处理方式
1. 检查 `scripts/core/test_battle_core.gd` 文件编码（应为UTF-8无BOM）
2. 如编码正常但仍无法加载，检查脚本路径是否与 `.tscn` 引用一致
3. 如已废弃，删除 `scenes/test/test_battle_core.tscn`

---

## 文件修改清单

| # | 文件 | 修改内容 | Bug |
|:---:|:---|:---|:---:|
| 1 | `scripts/systems/pvp_opponent_generator.gd` | `_generate_player_enemy()` 添加 `unit["is_alive"] = true` | BUG-001 |
| 2 | `autoload/config_manager.gd` | `get_skill_config()` 增加类型归一化 | BUG-003 |
| 3 | `scenes/run_main/run_main.gd` | `_update_monster_info()` 增加空判断 | BUG-002 |
| 4 | `resources/configs/hero_configs.json` | `shadow_dancer.max_steps` 改为 20 | BUG-004 |
| 5 | `scenes/test/test_phase2_full_run.gd` | 删除惩罚断言，改为 `penalty_tier == "none"` | BUG-005 |
| 6 | `scenes/test/test_battle_core.tscn` | 修复编码或删除 | BUG-006 |

---

## 回归测试命令（修复后执行）

```bash
Godot --path . --headless --scene "res://scenes/test/test_pvp_real.tscn"
Godot --path . --headless --scene "res://scenes/test/test_phase2_full_run.tscn"
```

---

## 验收标准

- [ ] BUG-001：test_pvp_real 通过，turns > 0
- [ ] BUG-003：test_decoupling 不再输出 `skill_id not found: XXXX.0`
- [ ] BUG-002：test_run_main_integration / test_full_run_30_turns 不再输出 DamagePredictor WARNING
- [ ] BUG-004：test_decoupling 通过，shadow_dancer 步数=20
- [ ] BUG-005：test_phase2_full_run 通过，惩罚断言不失败
- [ ] BUG-006：test_battle_core 可执行或已删除
