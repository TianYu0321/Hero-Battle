# 架构解耦性审计报告 — 赛马娘版Q宠大乐斗

> 审计日期：2026-05-09
> 审计对象：D:\Hero Battle 全部代码
> 审计目标：验证"后续添加人物/伙伴是否只需改数据"

---

## 结论摘要

**当前状态：部分解耦，未达到"纯数据驱动"标准。**

添加新伙伴 → **可以** 仅通过JSON配置添加（伙伴援助系统已完全数据驱动）。  
添加新主角 → **不行**，需要修改 **4个核心代码文件**（SkillManager、UltimateManager、BattleEngine、hero_select.gd）。

**根本原因**：主角的战斗逻辑（普攻模板、必杀技、特殊机制）是用 `match hero_id` 硬编码在代码里的，而非从 `skill_configs.json` 驱动。

---

## 逐项审计

### ✅ 已解耦（加内容 = 只加JSON）

| 模块 | 审计结果 | 说明 |
|:---|:---:|:---|
| **ConfigManager** | ✅ 解耦 | 从JSON加载到Dictionary，按key查询。新增hero/partner只需在JSON加条目 |
| **PartnerAssist** | ✅ 解耦 | 完全由 `partner_assist_configs.json` 驱动。无硬编码伙伴ID |
| **DamageCalculator** | ✅ 解耦 | 纯公式计算，无角色特定逻辑 |
| **EnemyAI** | ✅ 解耦 | 由 `enemy_configs.json` 驱动 |
| **ShopSystem** | ✅ 解耦 | 商品列表由 `shop_configs.json` 驱动 |

### ❌ 未解耦（加内容 = 必须改代码）

#### 1. SkillManager — 主角普攻硬编码

**问题**：
```gdscript
# skill_manager.gd
func execute_hero_normal_attack(hero, target):
    match hero_id:
        "hero_warrior":           return brave_normal_attack(hero, target)
        "hero_shadow_dancer":     return shadow_dancer_normal_attack(hero, target)
        "hero_iron_guard":        return iron_guard_normal_attack(hero, target)
```

**添加术士需要**：
- [ ] 新增 `sorcerer_normal_attack()` 函数
- [ ] 在 `execute_hero_normal_attack()` 新增 match case

**关键发现**：`skill_configs.json` 已经有足够数据驱动通用实现！
```json
{
  "power_attr": 4,        // 技巧加成
  "power_scale": 0.6,     // 伤害倍率
  "base_trigger_prob": 0.3,  // 触发概率
  "prob_attr_bonus": 4,   // 概率加成属性
  "prob_attr_step": 10,   // 每10点+2%
  "prob_attr_inc": 0.02,
  "prob_max": 0.5
}
```
但 SkillManager **没有读取 skill config**，而是硬编码了勇者的 30% + 技巧每10点+2% 逻辑。

#### 2. UltimateManager — 必杀技硬编码

**问题**：
```gdscript
# ultimate_manager.gd
func check_and_trigger(hero, enemies, turn):
    match hero_id:
        "hero_warrior":       return _check_brave_ultimate(...)
        "hero_shadow_dancer": return _check_shadow_ultimate(...)
        "hero_iron_guard":    return _check_iron_ultimate(...)
```

**添加术士需要**：
- [ ] 新增 `_check_sorcerer_ultimate()` 函数
- [ ] 新增 match case

#### 3. BattleEngine — 铁卫特殊机制硬编码

**问题**（两处）：
```gdscript
# battle_engine.gd
# (1) ENEMY_ACTION 状态：铁卫反击硬编码
if hero_was_hit and _hero.get("hero_id", "") == "hero_iron_guard":
    var counter = _skill_mgr.check_iron_counter(...)

# (2) ROUND_START 状态：不动如山Buff硬编码
if _hero.get("iron_guard_buff", false):
    _hero.iron_guard_buff_turns -= 1
```

**添加术士需要**：如果术士有类似的战斗特殊机制，必须新增硬编码分支。

#### 4. UI 层 — ID列表硬编码

| 文件 | 硬编码内容 | 添加术士/伙伴需要 |
|:---|:---|:---|
| `hero_select.gd` | `const _HERO_IDS = ["hero_warrior", ...]` | 追加术士ID |
| `hero_select.gd` | 五维星级标注逻辑 (`hero_id == "hero_iron_guard"`) | 新增术士的星级规则 |
| `tavern.gd` | `const _PARTNER_IDS = ["partner_swordsman", ...]` | 追加新伙伴ID |
| `rescue_system.gd` | `const _ALL_PARTNER_IDS = [1001, 1002, ...]` | 追加新伙伴数字ID |
| `run_controller.gd` | `hero_id_map = {1: "hero_warrior", 2: ..., 3: ...}` | 追加术士映射 |

---

## 为什么伙伴系统解耦了，主角没有？

**伙伴援助** = 纯数据驱动：
- `partner_assist_configs.json` 定义了触发条件、效果倍率、等级成长
- `partner_assist.gd` 读取配置 → 通用执行，**不感知具体伙伴是谁**

**主角战斗** = 代码驱动：
- `skill_configs.json` 有数据，但 SkillManager 选择忽略它
- 每个主角的普攻/必杀/反击都是手写函数

---

## 修复方案（使主角也达到数据驱动）

### 方案A：最小改动（推荐，半天工作量）

**思路**：不改 JSON schema，让 SkillManager/UltimateManager 读取 skill config，按配置字段通用执行。

| 文件 | 改动 | 说明 |
|:---|:---|:---|
| `skill_manager.gd` | 重构 `execute_hero_normal_attack()` | 读取 `passive_skill_id` → 查 skill config → 按 `skill_type` + 数值字段通用执行 |
| `ultimate_manager.gd` | 重构 `check_and_trigger()` | 读取 `ultimate_skill_id` → 查 skill config → 按触发条件通用判定 |
| `battle_engine.gd` | 通用化 Buff 处理 | `iron_guard_buff` 改为 generic buff list，由 skill config 的 `special_effect` 驱动 |
| UI文件 | 改为动态读取 | `hero_select.gd` / `tavern.gd` / `rescue_system.gd` 从 ConfigManager 获取可用ID列表 |

**新增主角时仅需**：
1. `hero_configs.json` 加第4条
2. `skill_configs.json` 加术士的被动+必杀技能
3. **无需改任何 .gd 代码**

### 方案B：大重构（不推荐，工作量过大）

引入完整的 ECS 或 Behavior Tree 系统。对 Phase 2 来说过度设计。

---

## 建议

**在分发 Phase 2 任务之前，先做一轮"主角系统解耦"修复。**

理由：
1. 配置数据已经就位（`skill_configs.json` schema 很完整），只是代码没用它
2. 修复后 Phase 2/3 加术士/后6伙伴/新机制时，只需改JSON，工程效率大幅提升
3. 现在代码量还不大（Phase 1刚结束），重构成本最低
4. 否则每次加新主角都要改 SkillManager + UltimateManager + BattleEngine + UI，很快会债务累积

---

## 修复后的 Phase 2 新计划

| 波次 | 任务 | 说明 |
|:---:|:---|:---|
| **预修复** | 主角系统解耦重构 | SkillManager/UltimateManager/BattleEngine/UI 改为数据驱动 |
| **第一波** | PVP真实匹配 + 档案界面 + 排行榜 | 2个Agent并行 |
| **第二波** | 整合贯通 + 评分调优 | 1个Agent |
| **内容补充** | 术士 + 后6伙伴 | 纯JSON补丁，无需代码Agent |

---

*审计人：本地审核 Agent*  
*状态：建议先做解耦重构，再进入Phase 2功能开发*
