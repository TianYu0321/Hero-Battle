# Hero-Battle 规格书 v1→v2 变更运行时影响与 Bug 分析报告

> 分析日期: 2026-05-10  
> 仓库: https://github.com/TianYu0321/Hero-Battle  
> 分析范围: 72个GDScript脚本 + 26个场景 + 14个JSON配置 + project.godot  
> 基准: 开发规格书 v1.0 (2026-05-08) → v2.0 (2026-05-09)  
> 差异项: 40处变更（含35处修正 + 5项保持）

---

## 一、执行摘要

**总体判断: 当前代码处于 v1/v2 混合状态，存在 9 个致命运行时错误，游戏无法正常启动或核心功能完全失效。**

代码呈现明显的"部分重写"特征：训练系统、节点池系统、连锁触发、伙伴援助等模块已按 v2 正确实现，但 **结算系统、UI 层、角色管理器** 存在致命级别的运行时错误，导致：

1. **游戏启动即崩溃**（结算系统 4 个未声明变量、UI 变量名不匹配）
2. **伙伴系统完全失效**（援助伤害/治疗恒为 1）
3. **普通战斗完全跳过**（未接入 BattleEngine）
4. **评分系统崩溃**（引用已删除的评分维度）

| 级别 | 数量 | 说明 |
|:----:|:----:|------|
| **致命 (P0)** | **9** | 运行时 crash 或核心功能完全失效 |
| **严重 (P1)** | **14** | 功能逻辑错误，行为与 v2 规格不符 |
| **中等 (P2)** | **12** | 不会 crash 但行为有显著偏差 |
| **轻微 (P3)** | **8** | 遗留代码/命名不一致，可延后处理 |

**修复工作量估算: 42~50 小时**（含 2h 紧急修复使游戏可启动）

---

## 二、致命运行时错误（9项）— 游戏无法正常运行

### P0-1: 结算系统 _ready() 引用 4 个未声明变量 → 启动崩溃 ⭐

**文件**: `scripts/systems/settlement_system.gd`  
**触发**: 游戏启动时实例化 SettlementSystem 即 crash  
**根因**: v2 评分公式从 5 项改为 4 项，开发者只更新了类顶部的 4 个变量声明，但 `_ready()` 方法仍尝试读取已删除的 v1 权重变量。

```gdscript
# 类顶部 — 只声明了 4 个 v2 变量（正确）
var _weight_final: float = 0.40
var _weight_attr: float = 0.25
var _weight_level: float = 0.20
var _weight_gold: float = 0.15

# _ready() — 仍引用 4 个已删除的 v1 变量（致命错误）
_weight_training = cfg.get("weight_training_efficiency", _weight_training)  # ❌ 未声明!
_weight_pvp = cfg.get("weight_pvp_performance", _weight_pvp)                # ❌ 未声明!
_weight_purity = cfg.get("weight_build_purity", _weight_purity)              # ❌ 未声明!
_weight_chain = cfg.get("weight_chain_showcase", _weight_chain)              # ❌ 未声明!
```

**同样错误**: `calculate_score()` 第 119-134 行也使用这 4 个未声明变量，结算时再次 crash。  
**修复**: 删除这 4 行引用，统一使用 v2 的 4 个权重变量。`30 分钟`

---

### P0-2: run_main.gd 变量名不匹配 → 启动崩溃 ⭐

**文件**: `scenes/run_main/run_main.gd` 第 16-21 行声明 vs 第 36/108/123 行引用  
**触发**: 游戏启动时解析该脚本即报错  
**根因**: 声明为 `option_buttons` 但实际全篇引用 `node_buttons`。

```gdscript
# 声明
@onready var option_buttons: Array[Button] = []    # 声明为 option_buttons

# 引用（第36行、108行、123行）
for btn in node_buttons:                             # ❌ 引用 node_buttons — 未声明!
```

**修复**: 统一变量名为 `option_buttons`。`10 分钟`

---

### P0-3: run_main.gd 引用不存在的 round_label → 运行时崩溃 ⭐

**文件**: `scenes/run_main/run_main.gd` 第 164 行  
**触发**: 回合/层数变更时调用 `_on_round_changed()`  
**根因**: v1 概念"回合(round)"改为 v2 "层(floor)"后，UI 变量名未同步。

```gdscript
round_label.text = "第 %d 层" % current_floor    # ❌ round_label 不存在，应为 floor_label
```

**修复**: 改为 `floor_label`。`10 分钟`

---

### P0-4: RunController.select_training_attr() 使用未定义符号 → 编译错误 ⭐

**文件**: `scripts/systems/run_controller.gd`  
**触发**: 编译/加载该脚本时  
**根因**: `select_training_attr()` 方法引用了不存在的常量 `STATE`、不存在的变量 `_run_hero` 和不存在的私有方法 `_advance_floor`。

**修复**: 检查方法是否为死代码（从未被调用），若是则直接删除；若需要则补充定义。`1 小时`

---

### P0-5: 伙伴援助伤害恒为 1 → 伙伴系统完全失效 ⭐

**文件**: `scripts/systems/character_manager.gd` 第 207-216 行 + `scripts/core/partner_assist.gd` 第 117 行  
**触发**: 任何伙伴援助触发时  
**根因**: v2 伙伴已移除五维属性（`RuntimePartner` 无 `current_vit/str/agi/tec/mnd`），但 `get_battle_ready_team()` 仍尝试读取这些字段，返回默认值 0。

```gdscript
# character_manager.gd — 读取不存在的字段 → 全为 0
"physique": p.current_vit,   # RuntimePartner 无此字段 → 0
"strength": p.current_str,   # 同上 → 0
# ... 全部属性为 0

# damage_calculator.gd — stats 全为 0 时的保底
if raw_damage <= 0.0: raw_damage = 1.0   # 伤害恒为 1
```

**结果**: 剑士的追击斩(攻击力×0.5)、药师的回复(最大生命×15%)等全部失效，伤害/治疗恒为 1。  
**修复**: 重写 `get_battle_ready_team()`，伙伴属性改为从 `partner_assist_configs.json` 读取援助配置（倍率/固定值），而非五维属性。`3 小时`

---

### P0-6: 伙伴援助治疗恒为 1 → 治疗伙伴完全失效 ⭐

**文件**: `scripts/core/partner_assist.gd` + `scripts/core/damage_calculator.gd`  
**触发**: 药师等治疗型伙伴触发援助时  
**根因**: `compute_heal()` 使用伙伴的 `spirit` 属性计算治疗量，但伙伴 stats 全为 0，触发 `max(..., 1)` 保底。

```gdscript
# compute_heal — caster_stats.get("spirit", 0) = 0
var heal_val = base_val * heal_scale * rand(0.9, 1.1)  # 0 * ... = 0
return int(max(heal_val, 1.0))                          # 恒为 1
```

**修复**: 治疗量改为基于主角最大生命百分比（如药师 = 主角最大生命 × 15%），从援助配置读取。`2 小时`

---

### P0-7: damage_calculator.gd 技巧系数 bug → 全角色伤害公式错误 ⭐

**文件**: `scripts/core/damage_calculator.gd` 第 28 行  
**触发**: 任何伤害计算  
**根因**: 技巧系数错误地使用了力量系数的配置键。

```gdscript
var power_coeff: float = _formula.get("atk_from_str", 1.0)   # ✓ 正确
var tech_coeff: float  = _formula.get("atk_from_str", 1.0)   # ❌ 应为 atk_from_tec!
```

**影响**: 技巧属性对伤害加成完全丢失（使用力量系数代替），勇者（技巧初始12）和影舞者（技巧10）的伤害低于设计值。  
**修复**: 改为 `"atk_from_tec"`。`5 分钟`

---

### P0-8: 普通战斗完全跳过 BattleEngine → 战斗系统缺失 ⭐

**文件**: `scripts/systems/node_resolver.gd` 第 54-61 行  
**触发**: 玩家选择"战斗"选项时  
**根因**: `_resolve_battle()` 直接返回随机金币，从未调用 `BattleEngine`。

```gdscript
func _resolve_battle(_hero, config, _run_data):
    # ❌ 完全跳过了 BattleEngine，只是随机给金币
    var gold_reward: int = randi() % 20 + 10
    return {"success": true, "data": {"gold_earned": gold_reward}}
```

**影响**: 普通战斗 100%"胜利"且无风险，v2 要求的"失败=死亡"永不触发，战斗系统形同虚设。  
**修复**: 接入 `BattleEngine`，传入敌人和主角数据，根据战斗结果决定生死和奖励。`4 小时`

---

### P0-9: PVP 惩罚逻辑仍生效 → v2 应无累积惩罚

**文件**: `scripts/systems/run_controller.gd` 第 294-321 行  
**触发**: PVP 检定时失败  
**根因**: v2 已删除 PVP 累积惩罚（生命上限降低/敌人变强），改为"失败仅影响奖励"，但代码仍执行 `hp_30` 和 `gold_50` 惩罚。

```gdscript
if not result.success:
    _hero.current_hp = maxi(1, int(_hero.current_hp * 0.7))   # ❌ v2不应扣HP
    _hero.gold_owned = maxi(0, _hero.gold_owned - 50)          # ❌ v2不应扣金币
```

**修复**: 删除 PVP 失败时的 HP/金币惩罚逻辑，保留"仅影响奖励"逻辑。`30 分钟`

---

## 三、严重错误（14项）— 功能逻辑错误

| # | 变更 | 文件 | 问题 | 修复估时 |
|:--:|:----:|------|------|:--------:|
| S1 | C13 | `character_manager.gd` 第134行 | 伙伴等级上限硬编码 `< 3`，v2 应为 `< 5` | 30m |
| S2 | C13 | `shop_system.gd` 第49行 | 商店伙伴等级上限 `>= 3`，v2 应为 `>= 5` | 30m |
| S3 | C13 | `shop_system.gd` 第55行 | 升级描述硬编码 `mini(3, ...)`，上限应为 5 | 30m |
| S4 | O1 | `settlement_system.gd` 第56-114行 | 仍计算已删除的 4 个评分维度（养成效率/PVP/流派纯度/连锁展示） | 4h |
| S5 | C15 | `character_manager.gd` 第86-90行 | `add_partner()` 赋值给不存在字段，数据静默丢失 | 1h |
| S6 | C15 | `partner_assist.gd` 第117行 | 护盾计算基于可能为空的 stats 字典，护盾值恒为 0 或 10 | 2h |
| S7 | B2 | `node_resolver.gd` | 精英战奖励未按 v2 实现（应为随机 2 种 + 固定高额金币） | 2h |
| S8 | B5 | `run_controller.gd` 第327行 | 终局战 Boss 固定为 `2005`（混沌领主），v2 应从 Boss 池随机 | 30m |
| S9 | B1 | `run_controller.gd` 第247行 | 战斗失败死亡处理因 P0-8 而永远不会触发（死代码） | 1h |
| S10 | G1 | `run_controller.gd` 第137行 | 仍发射 v1 信号 `turn_advanced`，应改为 `floor_advanced` | 30m |
| S11 | G1 | `run_main.gd` 第121行 | `_on_turn_advanced` 订阅 v1 信号，UI 不更新 | 2h |
| S12 | C2 | `character_manager.gd` 第160行 | `update_mastery_stage()` 仍使用 v1 四阶段逻辑，可能重复发射信号 | 1h |
| S13 | — | `scoring_configs.json` | 仍是 v1 格式（含已删除字段），与 v2 结算逻辑不匹配 | 1h |
| S14 | C13 | 全局 | **主角 Lv3/Lv5 质变系统完全未实现**（v2 要求主角也有质变） | 8h |

---

## 四、中等偏差（12项）— 行为与 v2 规格不符

| # | 变更 | 文件 | 问题 | 严重度 |
|:--:|:----:|------|------|:------:|
| M1 | C6 | `action_order.gd` 第24行 | 仍基于 `agility` 而非 v2 独立 `speed` 属性 | 中 |
| M2 | C4 | `run_main.gd` | 训练面板仍为横向布局，v2 需纵向 5 行 + LV:x + 伙伴头像 | 中 |
| M3 | B3 | `run_controller.gd` | PVP 对手匹配为占位实现，v2 需异步匹配玩家影子→AI | 中 |
| M4 | C1 | `run_controller.gd` 第20行 | 常量名仍为 `_MAX_TURNS` 等 v1 命名 | 低 |
| M5 | C11 | `run_controller.gd` 第379行 | `playback_mode` 仍传 `"fast_forward"`，v2 应统一 `"standard"` | 低 |
| M6 | C14 | `runtime_mastery.gd` | v1 数据模型残留，`TrainingSystem` 不再使用（死代码） | 低 |
| M7 | C8 | `battle_engine.gd` 第70行 | `assist_count`/`chain_count` 计数器仍在累加但不用于限制（v1 残留） | 低 |
| M8 | G2 | `run_main.gd` 第74行 | UI 仍显示"金币"，v2 应改为"魔城币" | 低 |
| M9 | C3 | `node_pool_system.gd` 第44行 | 有放回抽样，可能产生 3 个相同选项 | 中 |
| M10 | C7 | `chain_trigger.gd` | 连锁 scale 线性增长，100+ 次后达 10.4，可能导致数值溢出 | 低 |
| M11 | — | `event_bus.gd` | `save_loaded` 和 `game_loaded` 信号语义重叠 | 低 |
| M12 | — | `config_manager.gd` | `MAX_STAT_VALUE=999` 常量存在但不再使用（v2 无上限） | 低 |

---

## 五、数据兼容性分析

### v1 存档 → v2 代码读取

| 数据 | 兼容性 | 说明 |
|------|:------:|------|
| `RuntimeRun` | ⚠️ | `current_turn` 仍在，v2 `current_floor` 有默认值 1，层数可能不正确 |
| `RuntimeHero` | ✅ | 五维属性字段不变，v2 直接沿用 |
| `RuntimePartner` | ❌ | v1 存档含五维属性字段，v2 模型已移除，读取时静默丢弃 |
| `RuntimeMastery` | ❌ | v1 四阶段数据，v2 改用 `_training_count_*` 动态属性，旧数据完全丢失 |
| `FighterArchiveScore` | ⚠️ | 旧 5 维度数据可读取，但 v2 只使用 4 维度，总分计算错误 |
| `FighterArchiveMain` | ✅ | 快照类数据，字段无变更 |

---

## 六、已正确实现 v2 的模块（无需修改）

以下模块经代码审查确认已按 v2 规格正确实现：

| 模块 | 文件 | v2 特性验证 |
|------|------|:-----------:|
| **ChainTrigger** | `chain_trigger.gd` | 不限制段数 ✓ |
| **PartnerAssist** | `partner_assist.gd` | 不限制触发次数 ✓ |
| **TrainingSystem** | `training_system.gd` | 训练等级制(5次升1级,上限LV5) ✓ |
| **NodePoolSystem** | `node_pool_system.gd` | 4选项(训练/战斗/休息/外出) ✓ |
| **NodeResolver** | `node_resolver.gd` | 4选项解析 + 外出事件池 ✓ |
| **BattleEngine** | `battle_engine.gd` | 20回合状态机 + 回合内全部行动完毕切换 ✓ |
| **DamageCalculator** | `damage_calculator.gd` | 伤害公式核心（含 P0-7 技巧系数 bug） |
| **UltimateManager** | `ultimate_manager.gd` | 必杀技触发逻辑 ✓ |
| **EnemyAI** | `enemy_ai.gd` | 敌人行为模板（含 P0 之前审查的指数增长 bug） |

---

## 七、修复优先级与工作量

### 第一波: 致命错误修复（2 小时 → 游戏可启动）

| 序号 | 文件 | 修复内容 | 估时 |
|:----:|------|----------|:----:|
| 1 | `settlement_system.gd` | 删除 4 个未声明变量引用，统一使用 v2 权重 | 30m |
| 2 | `run_main.gd` | `node_buttons` → `option_buttons` | 10m |
| 3 | `run_main.gd` | `round_label` → `floor_label` | 10m |
| 4 | `run_controller.gd` | 删除或修复 `select_training_attr()` 未定义引用 | 1h |
| 5 | `damage_calculator.gd` | `atk_from_str` → `atk_from_tec`（技巧系数） | 5m |
| 6 | `run_controller.gd` | 删除 PVP 失败惩罚逻辑 | 30m |

### 第二波: 严重错误修复（16 小时 → 功能正确）

| 序号 | 文件 | 修复内容 | 估时 |
|:----:|------|----------|:----:|
| 7 | `character_manager.gd` | 重写 `get_battle_ready_team()`，伙伴属性从援助配置读取 | 3h |
| 8 | `partner_assist.gd` | 重写伤害/治疗/护盾计算，使用援助配置倍率 | 2h |
| 9 | `character_manager.gd` + `shop_system.gd` | 伙伴等级上限 3→5 | 1h |
| 10 | `node_resolver.gd` | 普通战斗接入 BattleEngine | 4h |
| 11 | `settlement_system.gd` | 重写评分公式为 v2 四维度 | 4h |
| 12 | `scoring_configs.json` | 更新为 v2 格式 | 1h |
| 13 | `character_manager.gd` | 清理 `add_partner()` 不存在字段赋值 | 1h |

### 第三波: 中等偏差修复（20 小时 → 体验完整）

| 序号 | 文件 | 修复内容 | 估时 |
|:----:|------|----------|:----:|
| 14 | `action_order.gd` | 实现 v2 独立 `speed` 属性计算 | 3h |
| 15 | `run_main.gd` | 信号 `turn_advanced` → `floor_advanced` 全量替换 | 2h |
| 16 | `run_main.gd` | 训练面板 UI 重构（纵向 5 行 + LV + 伙伴头像） | 4h |
| 17 | `run_controller.gd` | 终局战 Boss 从 Boss 池随机 | 30m |
| 18 | `node_resolver.gd` | 精英战奖励改为 v2（随机 2 种 + 固定高额金币） | 2h |
| 19 | 全局 | 主角 Lv3/Lv5 质变系统设计与实现 | 8h |
| 20 | `node_pool_system.gd` | 有放回 → 无放回抽样 | 30m |

### 第四波: 清理与优化（4 小时）

- 删除 `update_mastery_stage()` 及相关 v1 死代码
- 清理休息计数器等无用逻辑
- 常量重命名 `_MAX_TURNS` → `_MAX_FLOORS` 等
- 货币显示"金币" → "魔城币"
- 废弃配置字段清理

| 波次 | 内容 | 工作量 |
|:----:|------|:------:|
| 第一波 | 致命错误修复 | **2h** |
| 第二波 | 严重错误修复 | **16h** |
| 第三波 | 中等偏差修复 | **20h** |
| 第四波 | 清理与优化 | **4h** |
| **合计** | | **42h** |

---

## 八、Top 5 最关键 Bug（按影响排序）

| 排名 | Bug | 影响 | 修复优先级 |
|:----:|-----|------|:----------:|
| 1 | **结算系统 4 个未声明变量** | 游戏启动即崩溃，完全无法运行 | P0 第一波 |
| 2 | **伙伴援助伤害/治疗恒为 1** | 伙伴系统完全失效，战斗变成纯主角单挑 | P0 第二波 |
| 3 | **普通战斗跳过 BattleEngine** | 战斗系统形同虚设，100%胜利无风险 | P0 第二波 |
| 4 | **UI 变量名不匹配** | 启动崩溃 | P0 第一波 |
| 5 | **技巧系数使用力量系数** | 全角色伤害公式错误，勇者/影舞者输出偏低 | P0 第一波 |

---

## 九、v2 配置表适配清单

| 配置文件 | 当前状态 | v2 需求 | 工作量 |
|----------|:--------:|---------|:------:|
| `scoring_configs.json` | V1 格式 | **完全重写**（删除旧字段，新增 V2 权重） | 1h |
| `attribute_mastery_configs.json` | V1 四阶段 | **废弃**（训练系统不再使用） | 标记删除 |
| `battle_formula_configs.json` | V1 | **部分更新**（删除 `mastery_margin_*` / `chain_max_length` 等废弃字段） | 30m |
| `partner_assist_configs.json` | V1 | **部分更新**（删除 `max_trigger_per_battle` / `chain_max` 等废弃字段） | 30m |
| `partner_configs.json` | 已兼容 | 无需变更 | — |
| `hero_configs.json` | 已兼容 | 无需变更 | — |
| `node_configs.json` | 已兼容 | 无需变更（含 4 选项 + 外出事件池） | — |
| `node_pool_configs.json` | 已兼容 | 无需变更（含阶段权重） | — |

---

*报告结束 — 共分析 40 处规格变更，识别 9 个致命错误 + 14 个严重错误 + 12 个中等偏差 + 8 个轻微问题*
