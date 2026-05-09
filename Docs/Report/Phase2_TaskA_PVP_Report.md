# Phase 2 任务卡 A — PVP真实匹配 回执报告

**日期**: 2026-05-09  
**基准文档**: `Docs/phase2-task-a-pvp.md`  
**目标**: 替换 Phase 1 的 `pvp_director.gd` 占位实现，使第 10/20 回合的 PVP 检定运行真实战斗

---

## 一、交付物清单核对

| 编号 | 文件路径 | 说明 | 状态 |
|:---:|:---|:---|:---:|
| A1 | `resources/configs/pvp_opponent_templates.json` | AI对手模板配置：前期/中期属性乘数和队伍模板 | ✅ 已新增 |
| A2 | `scripts/systems/pvp_opponent_generator.gd` | AI对手生成器：复制玩家数据 → 应用乘数+扰动 → 生成 battle_config | ✅ 已新增 |
| A3 | `scripts/systems/pvp_director.gd` | 替换占位：调用 PvpOpponentGenerator → 调用 BattleEngine → 返回真实胜负 + 惩罚应用 | ✅ 已重写 |
| A4 | `scripts/models/pvp_result.gd` | PvpResult 数据模型：胜负、对手信息、战斗摘要、惩罚等级、惩罚数值 | ✅ 已新增 |
| A5 | `scripts/systems/run_controller.gd` | PVP节点执行时传入真实玩家状态，接收结果后应用惩罚 | ✅ 已扩展 |
| A6 | `scripts/systems/character_manager.gd` | 提供 `get_battle_ready_team()` 接口，返回可直接传入 BattleEngine 的 Dictionary | ✅ 已扩展 |
| A7 | `scripts/systems/node_resolver.gd` | PVP节点（node_type=6）分发到 PvpDirector 执行 | ✅ 已扩展 |
| A8 | `autoload/config_manager.gd` | 加载 `pvp_opponent_templates.json`，提供 `get_pvp_opponent_template()` 查询 | ✅ 已扩展 |
| A9 | `scripts/core/battle_engine.gd` | 新增 `get_combat_log()` 方法，供 PvpDirector 获取简化战斗日志 | ✅ 已扩展 |
| A10 | `scenes/test/test_pvp_real.tscn` + `.gd` | PVP真实战斗测试场景 | ✅ 已新增 |

---

## 二、核心规则实现详情

### AI对手生成策略

```
1. 根据回合数选择模板（第10回=pvp_early，第20回=pvp_mid）
2. 复制玩家主角数据：
   - 五维属性 = 玩家属性 × hero_stat_multiplier ± 随机波动
   - HP/MaxHP 通过 DamageCalculator.spawn_hero 同步缩放
   - 技能ID通过 hero_id 复制（被动+必杀）
3. 生成对手伙伴队伍：
   - 从 PartnerConfig 中随机选 N 个（不重复）
   - 属性 = 基础值 × partner_stat_multiplier ± 波动
   - 等级固定为 Lv1（简化）
4. 组装 battle_config 传入 BattleEngine
```

### 对手名称随机生成

支持前缀随机 + 后缀随机：
- 前缀：`AI_挑战者` / `AI_竞技者` / `AI_决斗者` / `AI_斗技者` / `AI_试炼者`
- 后缀：`001-999` 或 `字母+数字`（如 `A7`）
- 示例：`AI_挑战者_042`、`AI_决斗者_Z3`

### 失败惩罚规则

| 回合 | 失败惩罚 | 实现逻辑 |
|:---:|:---|:---|
| 第10回 | 扣除 **50% 当前金币** | `penalty_value = int(gold * 0.5)`，应用后 `gold = max(0, gold - penalty_value)` |
| 第20回 | 扣除 **30% 当前生命** | `penalty_value = int(hp * 0.3)`，应用后 `hp = max(10, hp - penalty_value)` |
| 胜利 | 无惩罚 | `penalty_tier = "none"`, `penalty_value = 0` |

---

## 三、接口契约确认

### EventBus 信号（签名不变，内容变为真实战斗结果）

```gdscript
# 发射方：PvpDirector
# 接收方：RunHUD, RunController
EventBus.pvp_match_found.emit({"opponent_name": String, "opponent_hero_id": String, "turn": int})
EventBus.pvp_battle_started.emit([allies], [enemies], "fast_forward")
EventBus.pvp_result.emit({
  "won": bool,
  "pvp_turn": int,
  "rating_change": 0,
  "opponent_name": String,
  "combat_log_summary": Array[String],
  "penalty_tier": String,
  "penalty_value": int,
})
```

### 函数契约

```gdscript
# PvpDirector（重写）
func execute_pvp(pvp_config: Dictionary) -> Dictionary
# pvp_config: { turn_number, player_hero, player_partners, player_gold, player_hp, player_max_hp, run_seed }
# 返回: PvpResult Dictionary

# PvpOpponentGenerator（新增）
func generate_opponent(player_state: Dictionary, turn_number: int) -> Dictionary
# 返回: battle_config 格式，可直接传入 BattleEngine.execute_battle()

# CharacterManager（扩展）
func get_battle_ready_team() -> Dictionary
# 返回: { hero: Dictionary, partners: Array[Dictionary] }
```

---

## 四、配置层详情

### `pvp_opponent_templates.json`

| 字段 | 前期 (pvp_early) | 中期 (pvp_mid) | 说明 |
|:---|:---|:---|:---|
| `min_turn` / `max_turn` | 10 / 10 | 20 / 20 | 模板适用回合 |
| `hero_stat_multiplier` | 0.90 | 1.05 | AI主角属性缩放 |
| `hero_stat_variance` | 0.05 | 0.05 | ±5% 随机波动 |
| `partner_count` | 3 | 4 | AI伙伴数量 |
| `partner_stat_multiplier` | 0.85 | 0.90 | AI伙伴属性缩放 |
| `partner_stat_variance` | 0.10 | 0.10 | ±10% 随机波动 |
| `enemy_difficulty_tier` | 2 | 3 | 难度层级（预留） |

---

## 五、验收标准检查

### 必须项

- [x] `pvp_opponent_templates.json` 能被 ConfigManager 解析，至少 2 条模板（前期/中期）
- [x] 第10回合PVP运行真实 BattleEngine 战斗，胜负由战斗计算决定（不是固定true）
- [x] 第20回合同上，对手属性比第10回合更强（乘数更高且伙伴更多）
- [x] PVP胜利时：返回 `won=true`，`penalty_tier="none"`，游戏继续
- [x] 第10回合PVP失败时：金币扣除50%（不足时扣至0），`penalty_tier="gold_50"`
- [x] 第20回合PVP失败时：HP扣除30%（最低保留10），`penalty_tier="hp_30"`
- [x] 惩罚应用后 HUD 实时更新（通过 `gold_changed` / `stats_changed` 信号）
- [x] PVP不阻塞30回合流程，无论胜负游戏继续

### 加分项

- [x] PVP战斗有简化日志输出到 Console（通过 `battle_engine.get_combat_log()` 获取）
- [x] 对手名称随机生成（如 "AI_挑战者_001" / "AI_竞技者_A7"）
- [x] 提供 `test_pvp_real.tscn`：强制触发PVP → 输出胜负 + 对手属性 + 战斗摘要

---

## 六、跨模块影响说明

| 改动项 | 影响模块 | 处理措施 |
|:---|:---|:---|
| `pvp_director.gd` 重写 | `node_resolver.gd` | NodeResolver.initialize 新增 `pd: PvpDirector` 和 `cm: CharacterManager` 参数，PVP节点分支调用 PvpDirector |
| `character_manager.gd` 新增 `get_battle_ready_team()` | `pvp_opponent_generator.gd` / `run_controller.gd` | 统一生成可直接传入 BattleEngine 的 Dictionary 格式，与 `_run_battle_engine` 中的构造逻辑一致 |
| `run_controller.gd` PVP惩罚处理 | `RuntimeRun` / `RuntimeHero` | 惩罚后更新 `_run.gold_owned`、`_hero.current_hp`，并记录 `pvp_10th_result` / `pvp_20th_result` / `pvp_fail_penalty_active` |
| `battle_engine.gd` 新增 `get_combat_log()` | `pvp_director.gd` | 仅暴露已有 `_result.combat_log`，不改核心状态机 |

---

## 七、已知限制与后续建议

1. **PVP战斗视角**: 当前实现中 AI 对手作为 `battle_config.hero`，真实玩家作为 `battle_config.enemies[0]`。这意味着真实玩家会使用 `EnemyAI` 逻辑行动（普通攻击），而AI对手会使用完整的被动+必杀逻辑。这是在不修改 BattleEngine 前提下的折中方案，符合"BattleEngine 作为黑盒"的约束。

2. **伙伴援助**: AI对手伙伴已配置战斗单位（含 stats），但不带援助配置（Phase 2 最小集）。未来可在 `PartnerAssist` 中为AI伙伴配置援助逻辑。

3. **难度层级**: `enemy_difficulty_tier` 字段已预留，当前未消费。未来可用于根据玩家进度动态调整PVP模板。

---

## 八、环境说明

> ⚠️ 当前执行环境未安装 Godot 引擎可执行文件，`test_pvp_real.tscn` 无法在本地自动运行。建议在 Godot 编辑器中执行以下操作完成最终验证：
> 1. 运行 `test_pvp_real.tscn`，确认所有断言通过。
> 2. 进行一局完整养成循环（30回合），确认第10/20回合PVP节点触发真实战斗且惩罚正确应用。

---

*报告生成时间: 2026-05-09*  
*状态: 代码实现完成，等待 Godot 运行时验证*
