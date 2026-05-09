# Phase 2 架构解耦重构 — 验收报告

**日期**: 2026-05-09  
**基准文档**: `Docs/phase2-precursor-decoupling.md`  
**目标**: 将主角系统从"代码硬编码"重构为"配置驱动+少量特殊分支"

---

## 一、交付物清单核对

### Step 1 — UI 层与运行时映射动态化

| 编号 | 文件 | 改动说明 | 状态 |
|:---:|:---|:---|:---:|
| S1-1 | `scenes/hero_select/hero_select.gd` | 删除 `_HERO_IDS` 常量，改为 `ConfigManager.get_unlocked_hero_ids()` | ✅ 已完成 |
| S1-2 | `scenes/hero_select/hero_select.gd` | 星级标注逻辑改为读取 `config.favored_attr` | ✅ 已完成 |
| S1-3 | `scenes/tavern/tavern.gd` | 删除 `_PARTNER_IDS`，改为 `ConfigManager.get_all_partner_ids()` | ✅ 已完成 |
| S1-4 | `scripts/systems/rescue_system.gd` | 删除 `_ALL_PARTNER_IDS`，改为 `ConfigManager.get_all_partner_config_ids()` | ✅ 已完成 |
| S1-5 | `scripts/systems/run_controller.gd` | 删除 `hero_id_map`，改为 `ConfigManager.get_hero_id_by_config_id()` | ✅ 已完成 |
| S1-6 | `autoload/config_manager.gd` | 新增 `get_unlocked_hero_ids()` / `get_all_partner_ids()` / `get_all_partner_config_ids()` / `get_hero_id_by_config_id()` | ✅ 已完成 |

### Step 2 — 战斗逻辑配置驱动化

| 编号 | 文件 | 改动说明 | 状态 |
|:---:|:---|:---|:---:|
| S2-1 | `scripts/core/skill_manager.gd` | 新增 `_get_passive_skill_config(hero)` | ✅ 已完成 |
| S2-2 | `scripts/core/skill_manager.gd` | `brave_normal_attack()` 概率计算从硬编码 → `trigger_params` | ✅ 已完成 |
| S2-3 | `scripts/core/skill_manager.gd` | `shadow_dancer_normal_attack()` 段数/倍率从硬编码 → `trigger_params` / `power_scale` | ✅ 已完成 |
| S2-4 | `scripts/core/skill_manager.gd` | `iron_guard_normal_attack()` 无需特殊参数，保持原样 | ✅ 已完成 |
| S2-5 | `scripts/core/skill_manager.gd` | `check_iron_counter()` 概率和眩晕从硬编码 → `trigger_params` | ✅ 已完成 |
| S2-6 | `scripts/core/skill_manager.gd` | `execute_hero_normal_attack()` 保留 match，调用已重构分支 | ✅ 已完成 |
| S2-7 | `scripts/core/ultimate_manager.gd` | 新增 `_get_ultimate_skill_config(hero)` | ✅ 已完成 |
| S2-8 | `scripts/core/ultimate_manager.gd` | `check_and_trigger()` 保留 match hero_id，内部数值配置化 | ✅ 已完成 |
| S2-9 | `scripts/core/ultimate_manager.gd` | `_check_brave_ultimate()` HP阈值/倍率/无视防御 → 配置读取 | ✅ 已完成 |
| S2-10 | `scripts/core/ultimate_manager.gd` | `_check_shadow_ultimate()` 固定回合/段数/倍率 → 配置读取 | ✅ 已完成 |
| S2-11 | `scripts/core/ultimate_manager.gd` | `_check_iron_ultimate()` HP阈值/Buff参数 → 配置读取 | ✅ 已完成 |
| S2-12 | `scripts/core/battle_engine.gd` | `iron_guard_buff` → `buff_list` | ✅ 已完成 |
| S2-13 | `scripts/core/battle_engine.gd` | Buff 结构标准化为 `{"buff_id", "name", "duration", "effects"}` | ✅ 已完成 |
| S2-14 | `scripts/core/battle_engine.gd` | `ROUND_START` Buff 结算通用化（遍历 `buff_list`，duration-- 自动移除） | ✅ 已完成 |
| S2-15 | `scripts/core/battle_engine.gd` | 铁卫反击检查通用化（不再硬编码 hero_id，改为无条件调用 check_iron_counter） | ✅ 已完成 |
| S2-16 | `scripts/models/runtime_hero.gd` | 已有 `buff_list: Array`，无需新增；已确认 `iron_guard_buff` 字段从未在此文件中存在 | ✅ 无需修改 |
| S2-17 | `scripts/models/models_serializer.gd` | `to_dict()`/`from_dict()` 已包含 `buff_list`，无需修改 | ✅ 无需修改 |

---

## 二、配置变更核对

### `resources/configs/hero_configs.json`

| 主角 | 新增字段 | 值 | 说明 |
|:---|:---|:---|:---|
| hero_warrior | `favored_attr` | 2 | 力量 |
| hero_shadow_dancer | `favored_attr` | 3 | 敏捷 |
| hero_iron_guard | `favored_attr` | 1 | 体魄 |

同时 Fallback 数据（`config_manager.gd` 内 `_FALLBACK_HERO_CONFIGS`）已同步补充 `favored_attr`、`passive_skill_id`、`ultimate_skill_id`、`is_default_unlock`。

### `resources/configs/skill_configs.json`（8001-8006 新增 `trigger_params`）

| 技能ID | 名称 | trigger_params |
|:---:|:---|:---|
| 8001 | 追击斩 | `base_trigger_prob:0.3, prob_attr_bonus:4, prob_attr_step:10, prob_attr_inc:0.02, prob_max:0.5` |
| 8002 | 终结一击 | `hp_threshold:0.40, ignore_def_ratio:0.30` |
| 8003 | 疾风连击 | `segment_min:2, segment_max:4, segment_attr_bonus:3, segment_attr_step:20` |
| 8004 | 风暴乱舞 | `fixed_turn:8, segment_count:6, partner_boost:1.5` |
| 8005 | 铁壁反击 | `base_trigger_prob:0.25, prob_attr_bonus:5, prob_attr_step:10, prob_attr_inc:0.02, prob_max:0.5, stun_prob:0.10` |
| 8006 | 不动如山 | `hp_threshold:0.50, buff_duration:3, damage_reduction:0.40, counter_prob_override:1.0, stun_prob:0.25` |

---

## 三、数值一致性验证

### 勇者追击斩概率

**重构前**: `prob = 0.3 + float(tec / 10) * 0.02`, 上限 `0.5`  
**重构后**: `prob = trigger_params.base_trigger_prob + float(tec / prob_attr_step) * prob_attr_inc`, 上限 `prob_max`

- 技巧=12 时：0.3 + float(12/10)*0.02 = **0.32** ✅

### 影舞者疾风连击段数

**重构前**: `segments = clampi(2 + int(agi / 20), 2, 4)`  
**重构后**: `segments = clampi(segment_min + int(agi / segment_attr_step), segment_min, segment_max)`

- 敏捷=16 时：clampi(2 + 16/20, 2, 4) = **2** ✅
- 敏捷=40 时：clampi(2 + 40/20, 2, 4) = **4** ✅

### 铁卫铁壁反击概率

**重构前**: `prob = 0.25 + float(mnd / 10) * 0.02`, 上限 `0.5`; 不动如山期间固定 `1.0`  
**重构后**: 同上逻辑，从 `trigger_params` 读取；不动如山 buff 提供 `counter_prob_override: 1.0`

- 精神=14 时：0.25 + float(14/10)*0.02 = **0.27** ✅
- 不动如山期间：**1.0** ✅

### 铁卫反击眩晕概率

**重构前**: 普通 `0.10`，不动如山期间 `0.25`  
**重构后**: 从 `trigger_params.stun_prob` 读取（0.10），buff 中若有 `stun_prob` 则覆盖（0.25） ✅

### 勇者终结一击

- HP 阈值：**0.40** ✅
- 伤害倍率：**3.0** ✅
- 无视防御：**0.30** ✅

### 影舞者风暴乱舞

- 固定回合：**8** ✅
- 段数：**6** ✅
- 每段倍率：**0.4** ✅

### 铁卫不动如山

- HP 阈值：**0.50** ✅
- Buff 持续回合：**3** ✅
- 减伤比例：**0.40** ✅
- 反击概率覆盖：**1.0** ✅
- 眩晕概率：**0.25** ✅

---

## 四、回归测试

### 静态代码检查

- [x] 全文搜索 `iron_guard_buff`：`scripts/` / `scenes/` / `autoload/` 中**已零引用**（仅在测试脚本中用于断言其不存在）。
- [x] `skill_configs.json` 保留所有现有字段，仅新增 `trigger_params`。
- [x] `hero_configs.json` 保留所有现有字段，仅新增 `favored_attr`。
- [x] `runtime_hero.gd` 已包含 `buff_list` 的序列化/反序列化。

### 自动化测试场景

交付 `scenes/test/test_decoupling.tscn` + `scenes/test/test_decoupling.gd`，测试覆盖：

1. **ConfigManager 动态查询**（解锁主角、伙伴ID、config_id 映射、 favored_attr）
2. **SkillManager 配置读取**（被动配置存在性、概率/段数计算一致性、buff_list 替代 iron_guard_buff）
3. **UltimateManager 配置读取**（必杀配置存在性、触发行为、buff 结构标准化）
4. **Buff 通用化**（duration 递减、到期自动移除）
5. **UI 动态映射间接验证**

> ⚠️ **环境限制说明**：当前执行环境未安装 Godot 引擎可执行文件，因此无法运行 `test_battle_engine.tscn` 和 `test_decoupling.tscn` 进行运行时验证。建议在 Godot 编辑器中执行以下操作完成最终回归：
> 1. 运行 `test_decoupling.tscn`，确认所有断言通过。
> 2. 运行 `test_battle_engine.tscn`，对 3 名主角各执行 1 次战斗，确认伤害数值差异 < 1%。
> 3. 运行 `test_battle_core.tscn`（Phase 1 测试），确认仍通过。

---

## 五、接口契约确认

### ConfigManager 新增查询

```gdscript
get_unlocked_hero_ids() -> Array[String]          # ✅ 已实现
get_all_partner_ids() -> Array[String]              # ✅ 已实现
get_all_partner_config_ids() -> Array[int]          # ✅ 已实现
get_hero_id_by_config_id(config_id: int) -> String  # ✅ 已实现
```

### SkillManager / UltimateManager 接口签名

```gdscript
execute_hero_normal_attack(hero: Dictionary, target: Dictionary) -> Array[Dictionary]  # ✅ 签名不变
check_iron_counter(hero: Dictionary, attacker: Dictionary, received_damage: int) -> Dictionary  # ✅ 签名不变
check_and_trigger(hero: Dictionary, enemies: Array, turn_number: int) -> Dictionary  # ✅ 签名不变
```

---

## 六、新增主角流程验证（重构后目标）

重构后，新增第4名主角（如术士）仅需：

1. `hero_configs.json` 新增第4条（含 `passive_skill_id`、`ultimate_skill_id`、`favored_attr`、`is_default_unlock`）
2. `skill_configs.json` 新增术士的被动 + 必杀（含 `trigger_params`）
3. `SkillManager` 新增 1 个 match case（仅特殊机制，数值全配置）
4. `UltimateManager` 新增 1 个 match case（同上）
5. **UI 层无需改动**（已动态化）✅
6. **BattleEngine 无需改动**（Buff 已通用化）✅

---

*报告生成时间: 2026-05-09*  
*状态: 等待 Godot 运行时回归测试确认*
