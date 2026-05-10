# Hero-Battle Bug修复报告

> 修复日期: 2026-05-10
> 基准: 开发规格书 v2.0 (2026-05-09)
> 修复原则: **解耦优先，结构优先，最小侵入**

---

## 一、修复概览

本次修复共涉及 **11个文件**，覆盖 **9个致命运行时错误** + **6个架构耦合问题** + **4个数据模型/逻辑错误**。

| 类别 | 数量 | 说明 |
|:----|:----:|:-----|
| 致命运行时错误 | 9 | 编译失败、启动崩溃、核心功能失效 |
| 架构解耦问题 | 6 | 循环依赖、越层调用、职责混乱 |
| 数据模型错误 | 4 | v1/v2混合、字段缺失、评分维度错误 |

---

## 二、致命运行时错误修复（P0）

### P0-1: runtime_partner.gd 缩进错误 → Parser Error

**文件**: `scripts/models/runtime_partner.gd`  
**根因**: 第55行 `partner.aid_trigger_count` 使用 **6个制表符** 缩进，与其他行的1个制表符不一致，导致GDScript解析器无法解析整个类。  
**修复**: 统一缩进为1个制表符。  
**解耦考量**: 无（纯语法错误）

---

### P0-2: run_main.gd 信号回调缺失

**文件**: `scenes/run_main/run_main.gd`  
**根因**: v1→v2重构时，信号从 `turn_advanced`/`round_changed` 改为 `floor_advanced`/`floor_changed`，但回调函数名未同步更新。  
**修复**:
- `_on_turn_advanced` → `_on_floor_advanced`
- `_on_round_changed` → `_on_floor_changed`
- 参数签名同步调整为 v2 规格

---

### P0-3: RunController.select_training_attr() 未定义标识符

**文件**: `scripts/systems/run_controller.gd`  
**根因**: 函数引用了不存在的 `STATE`、`_run_hero`、`_advance_floor()`。  
**修复**:
- 添加 `RuntimeHero.get_attr_value()` 方法
- `select_training_attr()` 改为调用 `TrainingSystem.execute_training()`，不再直接操作属性
- 新增 `_training_system` 引用，保持父子节点关系（合理耦合）

---

### P0-4: TrainingSystem hero.get() 参数数量错误

**文件**: `scripts/systems/training_system.gd`  
**根因**: `Object.get()` 在Godot 4中只接受1个参数，但代码传了2个（属性名+默认值）。同时 `RuntimeHero` 不存在 `_training_count_*` 动态属性。  
**修复**:
- `RuntimeHero` 新增 `training_counts: Dictionary` 字段
- `to_dict()` / `from_dict()` 同步序列化该字段
- TrainingSystem 改为字典操作：`hero.training_counts.get(attr_key, 0)`

---

### P0-5: NodeResolver.initialize() 不存在

**文件**: `scripts/systems/run_controller.gd`  
**根因**: v2.0 `NodeResolver` 已移除 `initialize()` 方法，但 `RunController._ready()` 仍尝试调用。  
**修复**: 删除对 `_node_resolver.initialize(...)` 的调用。  
**解耦考量**: `NodeResolver` v2.0 为无状态解析器，无需初始化子系统引用。

---

### P0-6: NodeResolver.resolve_node() 接口不匹配

**文件**: `scripts/systems/node_resolver.gd`, `scripts/systems/run_controller.gd`  
**根因**: `RunController` 调用 `resolve_node(node_type, option, run, hero)`，但 `NodeResolver` 只有 `resolve(node_option, run_controller)`。  
**修复**（解耦重构）:
- 彻底重构 `NodeResolver` 接口：移除对 `RunController` 的依赖
- `resolve(node_option: Dictionary, context: Dictionary)` — context 包含 `{hero, run, turn, partners}`
- `resolve_node()` 保留为兼容薄层
- 所有 `_resolve_*` 方法改为接收 `context` 而非 `run_controller`

**解耦收益**: `NodeResolver`（下层）不再依赖 `RunController`（上层），消除循环依赖风险。

---

### P0-7: CharacterManager 访问 RuntimePartner 不存在字段

**文件**: `scripts/systems/character_manager.gd`  
**根因**: v2.0 `RuntimePartner` 已移除五维属性字段，但 `add_partner()` 仍给 `p.current_vit/str/agi/tec/mnd` 赋值。  
**修复**: 删除 `add_partner()` 中对不存在字段的赋值。  
**解耦考量**: `CharacterManager` 只管理运行时数据，不再构造战斗单位。

---

### P0-8: partner_assist.gd 伤害/治疗恒为 1

**文件**: `scripts/core/partner_assist.gd`, `scripts/systems/character_manager.gd`  
**根因**: `get_battle_ready_team()` 读取 `RuntimePartner` 不存在的字段 → stats全为0 → `compute_damage()` 中 `raw_damage=0` → 触发保底 `raw_damage=1.0`。  
**修复**（分层解耦）:
- `CharacterManager.get_battle_ready_team()` 不再构造战斗 Dictionary，只返回原始 `{"hero": RuntimeHero, "partners": Array[RuntimePartner]}`
- `RunController._run_battle_engine()` 负责调用 `PartnerAssist.make_partner_battle_unit()` 构造战斗单位
- 伙伴属性从 `partner_assist_configs.json` 读取 `base_physique/strength/agility/technique/spirit`
- `partner_assist.gd._execute_assist_action()` 中，伤害/治疗基于**主角属性**计算（而非伙伴属性），符合 v2 规格

---

### P0-9: _execute_final_battle() Dictionary 点语法访问

**文件**: `scripts/systems/run_controller.gd`  
**根因**: `battle_result` 是 `Dictionary`，但代码使用 `battle_result.winner`（点语法），这在GDScript中对Dictionary不合法。  
**修复**: 全部改为 `battle_result.get("winner", "")` 等安全访问。

---

## 三、架构解耦修复

### 解耦-1: NodeResolver ↔ RunController 循环依赖

**问题**: `NodeResolver` 接收 `RunController` 实例作为参数，下层模块依赖上层模块。  
**方案**: 改为 `context: Dictionary` 数据传递模式。  
**影响文件**:
- `node_resolver.gd`: 移除所有 `RunController` 类型引用
- `run_controller.gd`: 调用时构造 `context` Dictionary

---

### 解耦-2: CharacterManager → PartnerAssist 越层依赖

**问题**: `CharacterManager`（功能模块层）直接调用 `PartnerAssist.make_partner_battle_unit()`（战斗核心层）。  
**方案**: `CharacterManager` 只返回原始角色数据，战斗单位构造由 `RunController._run_battle_engine()` 负责。  
**架构原则**: 数据管理层不依赖战斗逻辑层。

---

### 解耦-3: RunController → NodeResolver._rescue_system 直接访问内部成员

**问题**: `RunController._generate_node_options()` 直接访问 `_node_resolver._rescue_system.generate_candidates()`。  
**方案**: 改为通过 `get_node_or_null("RescueSystem")` 获取子系统。  
**同时修复**: `purchase_shop_item()` 和 `select_rescue_partner()` 改为直接调用 `ShopSystem` 和 `RescueSystem`，不再经过 `NodeResolver` 转发。

---

### 解耦-4: NodeResolver 职责过重

**问题**: `NodeResolver` 同时承担节点解析 + 商店购买处理 + 救援选择处理。  
**方案**: `process_shop_purchase()` 和 `process_rescue_selection()` 标记为 **deprecated**，由调用方直接访问 `ShopSystem` / `RescueSystem`。  
`NodeResolver` 职责收敛为：**纯节点类型解析**。

---

### 解耦-5: BattleEngine 调用分散

**问题**: 普通战斗在 `NodeResolver._resolve_battle()` 中直接返回金币（跳过 `BattleEngine`），而精英战/终局战走 `BattleEngine`。  
**方案**: `NodeResolver` 统一返回 `requires_battle` 标记，`RunController._process_node_result()` 统一调度 `BattleEngine`。所有战斗（普通/精英/PVP/终局）统一走 `_run_battle_engine()`。

---

## 四、数据模型与逻辑修复

### 修复-1: 伙伴等级上限 3→5

**文件**: `character_manager.gd`, `shop_system.gd`  
**根因**: v2.0 伙伴等级上限为5（Lv3和Lv5都是质变），但代码仍硬编码为3。  
**修复**:
- `character_manager.gd`: `p.current_level < 3` → `p.current_level < 5`
- `shop_system.gd`: `>= 3` → `>= 5`, `mini(3, ...)` → `mini(5, ...)`

---

### 修复-2: PVP 失败惩罚逻辑删除

**文件**: `scripts/systems/run_controller.gd`  
**根因**: v2.0 PVP失败仅影响奖励，无HP/金币惩罚，但代码仍执行 `hp_30` 和 `gold_50` 惩罚。  
**修复**: 删除PVP失败时的HP扣减和金币扣减逻辑。

---

### 修复-3: 信号名 v1→v2 统一

**文件**: `scripts/systems/run_controller.gd`  
**修复**:
- `turn_advanced` → `floor_advanced`
- `round_changed` → `floor_changed`
- `playback_mode`: `"fast_forward"` → `"standard"`

---

### 修复-4: v2.0 四维度评分系统

**文件**: `scripts/systems/settlement_system.gd`, `scripts/models/fighter_archive_score.gd`  
**根因**: v1 使用5维度评分（终局/养成/PVP/纯度/连锁），v2.0 改为4维度（终局/属性/等级/金币）。  
**修复**:
- `FighterArchiveScore` 重写为 v2 四维度字段
- `settlement_system.gd` 重写 `calculate_score()` 为4维度计算
- 删除 `_weight_training`/`_weight_pvp`/`_weight_purity`/`_weight_chain` 兼容变量

---

### 修复-5: 外出事件奖励格式统一

**文件**: `scripts/systems/node_resolver.gd`, `scripts/systems/run_controller.gd`  
**根因**: `NodeResolver` 返回的 `rewards` 有些是 `Dictionary`，有些是 `Array`，`RunController` 统一按 `Array` 遍历导致运行时错误。  
**修复**: 统一 `NodeResolver` 中所有 `rewards` 为 `Array[Dictionary]` 格式；`RunController._process_reward()` 新增 `"hp_heal"` / `"hp_damage"` 处理。

---

### 修复-6: 精英战计数器逻辑修正

**文件**: `scripts/systems/run_controller.gd`  
**根因**: 原代码用 `_pending_node_type == 3` 判断精英战，但 `NodeType.REST = 3`，精英战实际通过 `OUTING(4)` 触发。  
**修复**:
- `NodeResolver` 在精英战结果中标记 `"is_elite": true`
- `RunController` 通过 `result.get("is_elite", false)` 判断，不再依赖 `node_type`

---

## 五、代码修改清单

| 文件 | 修改类型 | 说明 |
|:-----|:--------:|:-----|
| `scripts/models/runtime_partner.gd` | 修复 | 缩进错误 |
| `scripts/models/runtime_hero.gd` | 新增 | `get_attr_value()` + `training_counts` |
| `scripts/models/fighter_archive_score.gd` | 重写 | v2.0 四维度字段 |
| `autoload/config_manager.gd` | 新增 | `get_all_enemy_configs()` |
| `scripts/systems/node_resolver.gd` | 重构 | 解耦RunController，统一rewards格式 |
| `scripts/systems/run_controller.gd` | 重构 | 解耦NodeResolver，统一战斗调度，修正信号 |
| `scripts/systems/character_manager.gd` | 重构 | 解耦PartnerAssist，删除不存在字段赋值 |
| `scripts/systems/training_system.gd` | 修复 | `training_counts` 字典操作 |
| `scripts/systems/shop_system.gd` | 修复 | 等级上限 3→5 |
| `scripts/systems/settlement_system.gd` | 重写 | v2.0 四维度评分 |
| `scripts/core/partner_assist.gd` | 修复 | 伤害/治疗基于主角属性 |
| `scenes/run_main/run_main.gd` | 修复 | 信号回调名同步 v2 |

---

## 六、剩余已知问题

以下问题在本次修复中**识别但未修复**，需在后续迭代中处理：

| # | 问题 | 文件 | 严重度 | 说明 |
|:--|:-----|:-----|:------:|:-----|
| R1 | 主角 Lv3/Lv5 质变系统未实现 | 全局 | P1 | v2.0 规格要求主角也有 Lv3/Lv5 质变，当前仅伙伴有等级 |
| R2 |  scoring_configs.json 仍为 v1 格式 | 配置表 | P1 | 含已删除的5维度字段，与 v2 结算逻辑不匹配 |
| R3 | 终局战 Boss 固定为 2005 | run_controller.gd | P2 | v2 要求从 Boss 池随机，当前硬编码混沌领主 |
| R4 | 战斗后 HP 同步机制待完善 | run_controller.gd | P2 | 普通战斗后HP回写逻辑已添加，但精英战/PVP的HP同步未完全覆盖 |
| R5 | PartnerAssist 护盾未实现 Buff 机制 | partner_assist.gd | P2 | 当前护盾简化为治疗，实际应在 BattleEngine 中实现护盾 buff |
| R6 | RuntimeMastery 死代码 | 全局 | P3 | v1 四阶段熟练度系统残留，v2 已改用 `training_counts` |
| R7 | 训练面板 UI 未按 v2 纵向布局 | run_main.gd | P3 | 当前仍为简化实现，未显示 LV:x 和伙伴头像 |

---

## 七、架构验证

修复后，模块依赖关系如下：

```
RunController (上层协调)
  ├─ CharacterManager (数据管理) ──→ RuntimeHero / RuntimePartner
  ├─ TrainingSystem (训练逻辑) ──→ CharacterManager
  ├─ ShopSystem (商店逻辑) ──→ CharacterManager
  ├─ RescueSystem (救援逻辑) ──→ CharacterManager
  ├─ NodeResolver (节点解析) ──→ ConfigManager  ❌ 不再依赖 RunController
  ├─ BattleEngine (战斗引擎) ──→ DamageCalculator / PartnerAssist / ...
  └─ SettlementSystem (结算) ──→ FighterArchiveMain / FighterArchiveScore

PartnerAssist (战斗核心)
  ├─ DamageCalculator
  └─ ConfigManager
  ❌ 不再被 CharacterManager 依赖
```

**核心原则验证**:
- ✅ 上层可调用下层，下层不反向依赖上层
- ✅ NodeResolver 不再依赖 RunController
- ✅ CharacterManager 不再依赖 PartnerAssist
- ✅ 模块间通过 EventBus 或数据传递通信

---

*报告结束 — 共修复 19 项问题，涉及 12 个文件*
