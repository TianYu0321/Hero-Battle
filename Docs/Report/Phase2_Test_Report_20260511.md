# Phase 2 全流程测试报告

> 报告日期: 2026-05-11
> 测试基准: 开发规格书 v2.0 + Phase1/Phase2 解耦补丁
> 测试范围: `scenes/test/` 目录下 13 个测试场景
> 测试环境: Godot 4.6.2-stable (mono), headless 模式

---

## 一、测试执行概览

| 编号 | 测试场景 | 脚本文件 | 状态 | 通过/断言数 | 失败/断言数 |
|:---:|:---|:---|:---:|:---:|:---:|
| T01 | `test_save_load` | `test_save_load.gd` | ✅ 通过 | 29 | 0 |
| T02 | `test_decoupling` | `test_decoupling.gd` | ✅ 通过 | 58 | 0 |
| T03 | `test_score_formula` | `test_score_formula.gd` | ✅ 通过 | 32 | 0 |
| T04 | `test_run_loop` | `test_run_loop.gd` | ✅ 通过 | — | — |
| T05 | `test_models` | `test_models.gd` | ✅ 通过 | — | — |
| T06 | `test_training_init` | `test_training_init.gd` | ✅ 通过 | — | — |
| T07 | `test_battle_engine` | `test_battle_engine.gd` | ⚠️ 通过(有警告) | — | — |
| T08 | `test_run_main_integration` | `test_run_main_integration.gd` | ⚠️ 通过(有警告) | — | — |
| T09 | `test_full_run_30_turns` | `test_full_run_30_turns.gd` | ⚠️ 通过(有警告) | — | — |
| T10 | `test_full_run` | `test_full_run.gd` | ✅ 通过 | — | — |
| T11 | `test_phase2_full_run` | `test_phase2_full_run.gd` | ❌ 部分失败 | 24 | 4 |
| T12 | `test_pvp_real` | `test_pvp_real.gd` | ❌ 部分失败 | 30 | 2 |
| T13 | `test_battle_core` | `scripts/core/test_battle_core.gd` | ❓ 未执行 | — | — |

**统计**: 13个测试场景中，**10个通过**（含3个有警告），**2个部分失败**，**1个未执行**。

---

## 二、Bug 详情（按严重度排序）

### 🔴 BUG-001 | PVP 真实战斗回合数为 0

| 字段 | 内容 |
|:---|:---|
| **Bug 编号** | BUG-001 |
| **严重度** | P0（阻塞验收） |
| **现象** | `test_pvp_real` 和 `test_phase2_full_run` 中，PVP 战斗的 `combat_summary.turns == 0`，断言 `turns > 0` 失败。BattleEngine 在 `ROUND_START` 阶段即判定战斗结束，未执行任何战斗动作。 |
| **涉及文件** | `scripts/systems/pvp_opponent_generator.gd` → `scripts/core/battle_engine.gd` |
| **根因分析** | `PvpOpponentGenerator._generate_player_enemy()` 将玩家数据复制为敌人镜像时，**未设置 `is_alive: true`** 字段。`BattleEngine._check_battle_end()` 检查 `enemy.get("is_alive", false)` 时，玩家镜像因缺少该字段返回 `false`，导致 `any_enemy_alive = false`，战斗在第一个 `ROUND_START` 检查点立即结束。此时 `_turn_number` 尚未自增（仍为 0），故 `turns_elapsed = 0`。 |
| **复现步骤** | 1. 运行 `test_pvp_real.tscn` 或 `test_phase2_full_run.tscn`<br>2. 观察 PVP 战斗结果输出<br>3. 检查 `result.combat_summary.turns` 值为 0<br>4. 断言 `combat_summary.turns > 0` 失败 |
| **期望结果** | PVP 战斗应至少进行 1 个完整回合（`turns >= 1`），双方正常行动后根据 HP 判定胜负。 |
| **修复建议** | 在 `_generate_player_enemy()` 中添加 `unit["is_alive"] = true`，并确保 `hp` 和 `max_hp` 字段已正确设置。 |

---

### 🟡 BUG-002 | DamagePredictor 空属性输入警告

| 字段 | 内容 |
|:---|:---|
| **Bug 编号** | BUG-002 |
| **严重度** | P2（警告污染） |
| **现象** | `test_run_main_integration`、`test_full_run_30_turns` 等测试中，控制台反复出现 `WARNING: [DamagePredictor] 空属性输入，返回最小伤害1`。 |
| **涉及文件** | `scripts/core/damage_predictor.gd` → `scenes/run_main/run_main.gd` |
| **根因分析** | `run_main.gd:449` 调用 `DamagePredictor.predict_battle_outcome()` 时传入的 `enemy_stats` 来自节点选项数据。部分节点（如训练节点、救援节点、事件节点）不携带 `enemy_stats`，或 `enemy_stats` 为空字典 `{}`。`DamagePredictor.predict_damage_taken()` 的空检查触发警告。 |
| **复现步骤** | 1. 运行 `test_run_main_integration.tscn`<br>2. 观察控制台 WARNING 输出<br>3. 或运行 `test_full_run_30_turns.tscn` 并在训练/救援回合观察警告 |
| **期望结果** | 非战斗节点不应触发伤害预测；战斗节点应确保 `enemy_stats` 包含有效属性（`str`/`agi` 等）。 |
| **修复建议** | 方案 A：在 `run_main.gd` 调用预测前增加前置判断，仅当 `node_type == BATTLE` 且 `enemy_stats` 非空时才调用。<br>方案 B：在 `DamagePredictor` 中降级空输入的日志级别（`push_warning` → `push_debug`）。 |

---

### 🟡 BUG-003 | Skill 配置键以 float 形式查找失败

| 字段 | 内容 |
|:---|:---|
| **Bug 编号** | BUG-003 |
| **严重度** | P2（功能降级） |
| **现象** | 运行测试时出现 `WARNING: [ConfigManager] skill_id not found: 8001.0` / `8002.0` / `8004.0` / `8006.0`。技能被动/必杀效果未生效，战斗退化为纯普攻。 |
| **涉及文件** | `scripts/models/runtime_hero.gd` → `autoload/config_manager.gd` |
| **根因分析** | `RuntimeHero.passive_skill_id` 和 `ultimate_skill_id` 声明为 `int` 类型，但在某些代码路径（如 JSON 反序列化、`data.get("passive_skill_id", 0)`）中，值被 Godot 解析为 `float`。当该值被 `str()` 转换为字符串后，得到 `"8001.0"` 而非 `"8001"`，与 `ConfigManager` 中配置键 `"8001"` 不匹配。 |
| **复现步骤** | 1. 运行 `test_battle_engine.tscn` 或 `test_decoupling.tscn`<br>2. 观察控制台中 `skill_id not found: XXXX.0` 的 WARNING<br>3. 或检查 `ConfigManager.get_skill_config("8001.0")` 返回空字典 |
| **期望结果** | `skill_id` 无论以 `int`、`float` 或 `String` 形式传入，都能正确匹配配置表中的字符串键。 |
| **修复建议** | 在 `ConfigManager.get_skill_config()` 入口增加类型归一化：`skill_id = str(int(float(skill_id)))`，去除 `.0` 后缀。或在 `RuntimeHero.from_dict()` 中显式强制转换为 `int`。 |

---

### 🟡 BUG-004 | 影子舞者步数配置与测试期望不匹配

| 字段 | 内容 |
|:---|:---|
| **Bug 编号** | BUG-004 |
| **严重度** | P3（数据不一致） |
| **现象** | `test_decoupling` 测试通过（58/0），但测试输出显示影子舞者（shadow_dancer）的 `max_steps` 配置值为 15，而测试用例断言期望值为 20。该断言在数据不匹配时仍通过，说明测试逻辑存在漏洞。 |
| **涉及文件** | `resources/configs/node_pool_configs.json`（或等效配置源）→ `scenes/test/test_decoupling.gd` |
| **根因分析** | 配置表中影子舞者的步数上限为 15，但测试代码中硬编码期望值为 20。可能是 v1→v2 重构时配置调整未同步更新测试，或测试断言使用了宽松条件（如 `>=` 而非 `==`）。 |
| **复现步骤** | 1. 运行 `test_decoupling.tscn`<br>2. 在输出日志中搜索 `shadow_dancer` 或 `max_steps`<br>3. 对比配置值 15 与测试期望值 20 |
| **期望结果** | 配置值与测试期望值一致；或测试明确使用配置读取值而非硬编码值。 |
| **修复建议** | 确认 v2.0 规格中影子舞者的步数上限应为 15 还是 20，统一配置和测试代码。 |

---

### 🟡 BUG-005 | PVP 惩罚策略未按回合区分

| 字段 | 内容 |
|:---|:---|
| **Bug 编号** | BUG-005 |
| **严重度** | P2（规格冲突） |
| **现象** | `PvpDirector` 中 `_penalty_strategy = NullPenaltyStrategy.new()`，无论 PVP 胜负和回合数，始终返回 `penalty_tier = "none"`。`test_phase2_full_run` 中 `if not result.won: penalty_tier == "gold_50"` / `"hp_30"` 断言可能因此不触发（若玩家胜利则跳过该分支）。 |
| **涉及文件** | `scripts/systems/pvp_director.gd` → `scripts/systems/null_penalty_strategy.gd` |
| **根因分析** | `null_penalty_strategy.gd` 的注释说明 "v2.0(1) 明确'失败不处罚，只影响奖励'"，但 `test_phase2_full_run.gd` 的测试用例仍按旧规格（第10回合金币-50%，第20回合HP-30%）编写。这是测试代码与实现代码之间的规格冲突。 |
| **复现步骤** | 1. 运行 `test_pvp_real.tscn`<br>2. 观察所有 PVP 结果的 `penalty_tier` 均为 `"none"`<br>3. 对比 `test_phase2_full_run.gd` 第160-164行的惩罚断言 |
| **期望结果** | **需产品确认**：v2.0 规格是否确实取消 PVP 失败惩罚？若取消，则应更新测试用例移除惩罚断言；若保留，则应恢复 `GoldPenaltyStrategy` / `HPPenaltyStrategy` 并注入 `PvpDirector`。 |
| **修复建议** | 待规格确认后统一修改测试或实现。 |

---

### 🟢 BUG-006 | test_battle_core 测试场景未纳入执行

| 字段 | 内容 |
|:---|:---|
| **Bug 编号** | BUG-006 |
| **严重度** | P3（测试覆盖缺口） |
| **现象** | `scenes/test/test_battle_core.tscn` 引用 `res://scripts/core/test_battle_core.gd`，该脚本存在但文件编码可能有问题（UTF-8 BOM 或 GBK），且该测试从未在本次回归测试中被执行。 |
| **涉及文件** | `scenes/test/test_battle_core.tscn` / `scripts/core/test_battle_core.gd` |
| **根因分析** | 该测试可能为 Phase 1 遗留，或脚本路径/编码问题导致 Godot 无法正确加载。 |
| **复现步骤** | 1. 检查 `scenes/test/test_battle_core.tscn` 内容<br>2. 尝试在 Godot 编辑器中运行该场景<br>3. 观察是否报错或乱码 |
| **期望结果** | 所有 `scenes/test/` 下的测试场景都应可执行并纳入 CI/回归测试。 |
| **修复建议** | 修复脚本编码问题，验证该测试能否正常运行；若已过时则删除场景文件。 |

---

## 三、已修复问题（本次测试前已解决）

| 编号 | 问题 | 涉及文件 | 修复方式 |
|:---|:---|:---|:---|
| FIXED-001 | 存档字段名 v1→v2 不匹配（`hero_id`/`current_round`/`agi`） | `test_save_load.gd` | 更新为 `hero_config_id`/`current_floor`/`current_agi` |
| FIXED-002 | `RunController.select_training_attr()` 访问不存在字段 | `run_controller.gd` | 改用 `TrainingSystem.execute_training()` |
| FIXED-003 | `CharacterManager.add_partner()` 赋值 `RuntimePartner` 不存在字段 | `character_manager.gd` | 删除无效赋值 |
| FIXED-004 | `get_battle_ready_team()` 越层调用 `PartnerAssist` | `character_manager.gd` | 改为返回原始 `RuntimeHero`/`RuntimePartner` |
| FIXED-005 | 救援楼层流程不匹配 v2.0（按钮式→面板式） | `test_full_run_30_turns.gd`, `test_phase2_full_run.gd` | 改为 `select_rescue_partner()` + `close_shop_panel()` |
| FIXED-006 | SettlementSystem 评分维度未更新为 v2.0 四维度 | `test_score_formula.gd` | 重写为 `final_performance`/`attr_total`/`level_score`/`gold_score` |
| FIXED-007 | `RuntimePartner` 测试数据包含不存在字段 `current_vit`/`current_str` | `test_models.gd` | 移除无效字段 |
| FIXED-008 | `test_run_loop` 按钮节点路径错误 | `test_run_loop.gd` | 更新为 `VBoxContainer/HBoxContainer/BtnTrainVit` |
| FIXED-009 | 测试场景未设置 headless 自动退出 | `test_models.gd`, `test_run_loop.gd` 等 | 添加 `get_tree().quit()` |

---

## 四、架构验证状态

| 验证项 | 状态 | 说明 |
|:---|:---:|:---|
| 上层→下层单向依赖 | ✅ | `NodeResolver` 不再依赖 `RunController` |
| `CharacterManager` 不依赖 `PartnerAssist` | ✅ | 战斗单位构造移至 `RunController._run_battle_engine()` |
| `EventBus` 信号驱动通信 | ✅ | 救援/商店/训练面板通过 `panel_opened` 信号打开 |
| `SaveManager` 字段完整性校验 | ✅ | `_REQUIRED_SAVE_FIELDS` 已更新为 v2.0 字段名 |
| `RunSnapshot` 序列化/反序列化 | ✅ | `from_dict()` 兼容 `current_turn` 别名 |
| PVP 真实战斗集成 | ❌ | 因 **BUG-001** 战斗立即结束，未验证真实战斗逻辑 |
| 结算四维度评分 | ✅ | `test_score_formula` 32/0 通过 |
| 排行榜排序 | ✅ | `test_phase2_full_run` 排行榜断言通过 |

---

## 五、后续行动建议

### 立即执行（阻塞 Phase 2 验收）

1. **修复 BUG-001（PVP 0 回合）**：在 `_generate_player_enemy()` 中添加 `is_alive = true`，并验证 `_turn_number` 正确递增。
2. **确认 BUG-005（PVP 惩罚规格）**：与产品确认 v2.0 是否取消 PVP 失败惩罚，统一测试与实现。

### 建议执行（提升质量）

3. **修复 BUG-003（Skill float key）**：在 `ConfigManager.get_skill_config()` 入口统一做 `str(int(float(skill_id)))` 归一化。
4. **修复 BUG-002（DamagePredictor 空输入）**：非战斗节点跳过预测调用，或降级日志级别。
5. **修复 BUG-004（影子舞者步数）**：统一配置值与测试期望值。
6. **修复 BUG-006（test_battle_core）**：修复编码问题或移除废弃测试。

### 回归测试命令

```bash
# 全量回归（headless）
Godot --path . --headless --scene "res://scenes/test/test_pvp_real.tscn"
Godot --path . --headless --scene "res://scenes/test/test_phase2_full_run.tscn"
Godot --path . --headless --scene "res://scenes/test/test_save_load.tscn"
Godot --path . --headless --scene "res://scenes/test/test_score_formula.tscn"
Godot --path . --headless --scene "res://scenes/test/test_full_run_30_turns.tscn"
Godot --path . --headless --scene "res://scenes/test/test_decoupling.tscn"
```

---

*报告生成时间: 2026-05-11*
*状态: 待修复 BUG-001 后重新验收 PVP 链路*
