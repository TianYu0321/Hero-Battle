# 架构解耦重构任务卡

**项目路径**：`D:\Hero Battle`  
**引擎**：Godot 4.6.2 / GDScript  
**目标**：将主角系统从"代码硬编码"重构为"配置驱动+少量特殊分支"，使后续添加新主角仅需修改 JSON 配置。

**输入基准**：`D:\Hero Battle\Docs\architecture-decoupling-audit.md`  
**禁止**：不可改变任何现有战斗数值、不可改变 Phase 1 战斗结果。

---

## 一、问题现状

当前添加新主角（如术士）需要修改 4+ 个代码文件，因为：

1. `skill_manager.gd` — 普攻逻辑用 `match hero_id` 硬编码了 3 套函数
2. `ultimate_manager.gd` — 必杀技用 `match hero_id` 硬编码了 3 套触发+执行
3. `battle_engine.gd` — 铁卫反击和不动如山 Buff 硬编码在状态机中
4. UI 层多处 — 主角/伙伴 ID 列表写死在 `const` 里

---

## 二、重构策略：分两步

### 第一步（高优先级）：UI 层 + 运行时映射 动态化
**这一步改动小、收益大、零风险。**

### 第二步（核心）：战斗逻辑 配置驱动化
**保留特殊机制分支，但数值参数全部从 `skill_configs.json` 读取。**

---

## 三、交付物清单

### Step 1 — UI 层与运行时映射动态化

| # | 文件 | 改动说明 | 重构前 → 重构后 |
|:---:|:---|:---|:---|
| S1-1 | `scenes/hero_select/hero_select.gd` | `_HERO_IDS` 常量硬编码 → 从 `ConfigManager` 动态读取 `is_default_unlock=true` 的主角 | `const _HERO_IDS = ["hero_warrior", ...]` → `var _hero_ids = ConfigManager.get_unlocked_hero_ids()` |
| S1-2 | `scenes/hero_select/hero_select.gd` | 星级标注逻辑硬编码 → 从 hero config 读取 `favored_attr` | `hero_id == "hero_iron_guard"` → `hero_id == config.get("favored_attr", 0)` |
| S1-3 | `scenes/tavern/tavern.gd` | `_PARTNER_IDS` 常量硬编码 → 从 `ConfigManager` 动态读取 | `const _PARTNER_IDS = [...]` → `var _partner_ids = ConfigManager.get_all_partner_ids()` |
| S1-4 | `scripts/systems/rescue_system.gd` | `_ALL_PARTNER_IDS` 硬编码 → 从 `ConfigManager` 动态读取 | `const _ALL_PARTNER_IDS = [1001, ...]` → `var _all_partner_ids = ConfigManager.get_all_partner_config_ids()` |
| S1-5 | `scripts/systems/run_controller.gd` | `hero_id_map` 硬编码映射 → 从 `ConfigManager` 动态查询 | `var hero_id_map = {1: "hero_warrior", ...}` → `var hero_id = ConfigManager.get_hero_id_by_config_id(_hero.hero_config_id)` |
| S1-6 | `autoload/config_manager.gd` | 新增查询接口 | 新增：`get_unlocked_hero_ids()`、`get_all_partner_ids()`、`get_hero_id_by_config_id(int)` |

### Step 2 — 战斗逻辑配置驱动化

#### 2.1 `skill_configs.json` 新增字段

在现有 Schema 上**新增 `trigger_params` Dictionary**，不删除任何现有字段：

```json
"trigger_params": {
    // --- 触发条件参数 ---
    "hp_threshold": 0.40,        // 敌方/自身HP阈值（勇者必杀/铁卫必杀）
    "fixed_turn": 8,              // 固定回合触发（影舞者必杀）
    "segment_count": 6,           // 多段攻击段数（影舞者必杀）
    "segment_attr_bonus": 3,      // 段数加成属性编码（敏捷=3）
    "segment_attr_step": 20,      // 每N点属性+1段
    "segment_min": 2,             // 多段最小段数（影舞者普攻）
    "segment_max": 4,             // 多段最大段数

    // --- 效果参数 ---
    "buff_duration": 3,           // Buff持续回合（铁卫必杀）
    "damage_reduction": 0.40,     // 减伤比例
    "counter_prob_override": 1.0, // 反击概率覆盖值
    "stun_prob": 0.25,            // 眩晕概率（覆盖基础值）
    "ignore_def_ratio": 0.30,     // 无视防御比例（勇者必杀）
    "partner_boost": 1.5        // 伙伴援助概率倍率（影舞者必杀）
}
```

为 8001-8006 共 6 条主角技能补充 `trigger_params`（见下表）。

#### 2.2 `skill_manager.gd` 重构

**目标**：保留 `execute_hero_normal_attack()` 的 match 结构（特殊机制仍需分支），但**分支内数值全部从 skill config 读取**。

| # | 改动 | 说明 |
|:---:|:---|:---|
| S2-1 | 新增 `_get_passive_skill_config(hero)` | 读取 `hero.passive_skill_id` → 查 `skill_configs.json` |
| S2-2 | `brave_normal_attack()` 重构 | 概率计算从硬编码 → 读取 `passive_cfg.trigger_params`：`base_trigger_prob` + `prob_attr_bonus`/`prob_attr_step`/`prob_attr_inc`/`prob_max` |
| S2-3 | `shadow_dancer_normal_attack()` 重构 | 段数计算从硬编码 → 读取 `segment_min`/`segment_max`/`segment_attr_bonus`/`segment_attr_step`；伤害倍率从 `power_scale` 读取 |
| S2-4 | `iron_guard_normal_attack()` 重构 | 无需特殊参数，保持原样（普通1段） |
| S2-5 | `check_iron_counter()` 重构 | 概率和眩晕从硬编码 → 读取 `passive_cfg.trigger_params`：`base_trigger_prob` + `prob_attr_bonus` 等 |
| S2-6 | 新增 `execute_hero_normal_attack()` 通用入口 | 原有 match 结构保留，但 match 后调用已重构的分支函数 |

**重构后新增主角的工作量**：
1. 在 `skill_configs.json` 新增被动 + 必杀配置（含 `trigger_params`）
2. 在 `SkillManager` 新增 1 个 match case（只需写特殊机制，数值全配置）

#### 2.3 `ultimate_manager.gd` 重构

| # | 改动 | 说明 |
|:---:|:---|:---|
| S2-7 | 新增 `_get_ultimate_skill_config(hero)` | 读取 `hero.ultimate_skill_id` → 查 skill config |
| S2-8 | `check_and_trigger()` 通用化 | 触发条件从 `match hero_id` 改为 `match trigger_code`（从 skill config 读取） |
| S2-9 | `_check_brave_ultimate()` 重构 | HP 阈值从 0.40 硬编码 → `trigger_params.hp_threshold`；伤害倍率从 3.0 硬编码 → `power_scale`；无视防御从 0.30 硬编码 → `trigger_params.ignore_def_ratio` |
| S2-10 | `_check_shadow_ultimate()` 重构 | 固定回合从 8 硬编码 → `trigger_params.fixed_turn`；段数从 6 硬编码 → `trigger_params.segment_count`；伤害倍率从 `power_scale` 读取 |
| S2-11 | `_check_iron_ultimate()` 重构 | HP 阈值从 0.50 硬编码 → `trigger_params.hp_threshold`；Buff参数全部从 `trigger_params` 读取 |

#### 2.4 `battle_engine.gd` Buff 通用化

| # | 改动 | 说明 |
|:---:|:---|:---|
| S2-12 | `iron_guard_buff` → `buff_list` | `_hero` 新增 `buff_list: Array[Dictionary]`，替代 `iron_guard_buff` bool + `iron_guard_buff_turns` int |
| S2-13 | Buff 结构标准化 | `{"buff_id": String, "name": String, "duration": int, "effects": Dictionary}` |
| S2-14 | `ROUND_START` 状态 Buff 结算通用化 | 遍历 `buff_list`，所有 `duration-- <= 0` 的自动移除 |
| S2-15 | 铁卫反击检查通用化 | 不再硬编码 `hero_id == "hero_iron_guard"`，改为检查 `hero.buffs` 中是否有 `counter_prob_override` 效果 |

#### 2.5 `character_manager.gd` / `runtime_hero.gd` 扩展

| # | 改动 | 说明 |
|:---:|:---|:---|
| S2-16 | `runtime_hero.gd` | 删除 `iron_guard_buff` / `iron_guard_buff_turns`，新增 `buff_list: Array` |
| S2-17 | `models_serializer.gd` | 序列化/反序列化同步更新 buff_list |

---

## 四、skill_configs.json trigger_params 填充表

| 技能ID | 名称 | trigger_params（新增） |
|:---:|:---|:---|
| 8001 | 追击斩 | `{"base_trigger_prob": 0.3, "prob_attr_bonus": 4, "prob_attr_step": 10, "prob_attr_inc": 0.02, "prob_max": 0.5}` |
| 8002 | 终结一击 | `{"hp_threshold": 0.40, "ignore_def_ratio": 0.30}` |
| 8003 | 疾风连击 | `{"segment_min": 2, "segment_max": 4, "segment_attr_bonus": 3, "segment_attr_step": 20}` |
| 8004 | 风暴乱舞 | `{"fixed_turn": 8, "segment_count": 6, "partner_boost": 1.5}` |
| 8005 | 铁壁反击 | `{"base_trigger_prob": 0.25, "prob_attr_bonus": 5, "prob_attr_step": 10, "prob_attr_inc": 0.02, "prob_max": 0.5, "stun_prob": 0.10}` |
| 8006 | 不动如山 | `{"hp_threshold": 0.50, "buff_duration": 3, "damage_reduction": 0.40, "counter_prob_override": 1.0, "stun_prob": 0.25}` |

---

## 五、接口契约

### ConfigManager 新增查询

```gdscript
# 返回已解锁主角ID数组（is_default_unlock=true 或 unlock_condition已满足）
get_unlocked_hero_ids() -> Array[String]

# 返回全部伙伴ID数组
get_all_partner_ids() -> Array[String]

# 返回全部伙伴数字ID数组
get_all_partner_config_ids() -> Array[int]

# 通过数字ID查找hero_id字符串
get_hero_id_by_config_id(config_id: int) -> String
```

### SkillManager 重构后接口（不变）

```gdscript
# 接口签名不变，内部实现改为配置驱动
execute_hero_normal_attack(hero: Dictionary, target: Dictionary) -> Array[Dictionary]
check_iron_counter(hero: Dictionary, attacker: Dictionary, received_damage: int) -> Dictionary
```

### UltimateManager 重构后接口（不变）

```gdscript
check_and_trigger(hero: Dictionary, enemies: Array, turn_number: int) -> Dictionary
```

---

## 六、验收标准

### Step 1 验收

- [ ] `hero_select.gd` 删除硬编码 `_HERO_IDS`，改为从 ConfigManager 读取
- [ ] `tavern.gd` 删除硬编码 `_PARTNER_IDS`，改为动态读取
- [ ] `rescue_system.gd` 删除硬编码 `_ALL_PARTNER_IDS`，改为动态读取
- [ ] `run_controller.gd` 删除硬编码 `hero_id_map`，改为动态查询
- [ ] 主菜单 → 主角选择 → 酒馆 流程无报错，显示内容与重构前一致

### Step 2 验收

- [ ] `skill_configs.json` 8001-8006 新增 `trigger_params` 字段，JSON 解析无报错
- [ ] SkillManager 重构后，勇者普攻追击概率、影舞者段数、铁卫反击概率**与重构前数值一致**
- [ ] UltimateManager 重构后，勇者必杀触发条件、影舞者第8回合、铁卫半血触发**与重构前行为一致**
- [ ] BattleEngine Buff 通用化后，铁卫不动如山效果（减伤40%/反击100%/3回合）与重构前一致
- [ ] `runtime_hero.gd` 序列化/反序列化包含 `buff_list`，字段无损
- [ ] **回归测试**：3主角各跑 1 次完整战斗，每回合输出与重构前对比，伤害数值差异 < 1%
- [ ] 提供 `test_decoupling.tscn`：验证 ConfigManager 动态查询 + SkillManager 配置读取 + UltimateManager 配置读取

---

## 七、禁止事项

- ❌ **不可改变任何战斗数值**：重构后伤害/概率/段数必须与重构前一致
- ❌ **不可删除 `skill_configs.json` 现有字段**：只新增 `trigger_params`
- ❌ **不可改变 Phase 1 验收过的战斗结果**：`test_battle_engine.tscn` 必须仍通过
- ❌ **不引入新机制**：只做重构，不扩展功能
- ❌ **不改 EventBus 信号签名**：保持向后兼容

---

## 八、跨模块影响检查清单（Agent执行时必须逐项确认）

重构改动可能引发连锁影响，执行前通读此清单：

| # | 改动项 | 连锁影响 | 检查动作 |
|:---:|:---|:---|:---|
| 1 | `runtime_hero.gd` 删除 `iron_guard_buff`/`iron_guard_buff_turns` | `models_serializer.gd` 序列化/反序列化会缺失字段 | 同步更新 `to_dict()`/`from_dict()`，确保旧存档读取时 `buff_list` 为空数组 |
| 2 | `skill_configs.json` 新增 `trigger_params` | ConfigManager 解析时旧JSON没有此字段 | 代码中使用 `.get("trigger_params", {})` 提供空字典 fallback |
| 3 | `ConfigManager` 新增 `get_unlocked_hero_ids()` 等接口 | UI层调用前必须接口已就绪 | 先改 ConfigManager → 再改 UI 层，不能反序 |
| 4 | `battle_engine.gd` Buff 通用化 | `enemy_ai.gd` / `damage_calculator.gd` 是否读取 `iron_guard_buff`？ | 全文搜索 `iron_guard_buff`，所有引用点改为 `buff_list` 查询 |
| 5 | `skill_manager.gd` / `ultimate_manager.gd` 重构 | BattleEngine 调用接口签名是否变化？ | 保持接口签名不变，只改内部实现 |
| 6 | `hero_configs.json` 字段变更 | `hero_select.gd` 的星级标注从硬编码改为读取 `favored_attr` | 确认 hero config 中 3名主角都已填写 `favored_attr`（勇者=2力量/影舞者=3敏捷/铁卫=1体魄） |

**搜索命令**：执行重构前，先用以下命令确认 `iron_guard_buff` 的引用点：
```bash
grep -r "iron_guard_buff" scripts/ scenes/ autoload/
```

---

## 九、新增主角时的流程（重构后验证目标）

1. `hero_configs.json` 新增第4条（术士）
2. `skill_configs.json` 新增术士的被动 + 必杀（含 `trigger_params`）
3. **SkillManager 新增 1 个 match case**（仅特殊机制，数值全配置）
4. **UltimateManager 新增 1 个 match case**（同上）
5. **UI 层无需改动**（已动态化）
6. **BattleEngine 无需改动**（Buff 已通用化）

---

*任务卡版本：v1.0*  
*日期：2026-05-09*
