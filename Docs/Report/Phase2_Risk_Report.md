# Phase 2 架构解耦重构 — 隐患与风险报告

**日期**: 2026-05-09  
**基准文档**: `Docs/phase2-precursor-decoupling.md`

---

## 一、跨模块影响检查清单逐项确认

| # | 改动项 | 连锁影响 | 检查动作 | 状态 |
|:---:|:---|:---|:---|:---:|
| 1 | `runtime_hero.gd` 删除 `iron_guard_buff`/`iron_guard_buff_turns` | `models_serializer.gd` 序列化/反序列化会缺失字段 | 经核查，`runtime_hero.gd` 中**从未存在过** `iron_guard_buff`/`iron_guard_buff_turns` 字段；`buff_list` 早已存在且 `to_dict()`/`from_dict()` 已包含。旧存档读取时 `buff_list` 会回退为 `[]`。 | ✅ 安全 |
| 2 | `skill_configs.json` 新增 `trigger_params` | ConfigManager 解析时旧JSON没有此字段 | 所有代码中均使用 `.get("trigger_params", {})` 提供空字典 fallback，不会报错。 | ✅ 安全 |
| 3 | `ConfigManager` 新增接口 | UI层调用前必须接口已就绪 | 修改顺序：先改 ConfigManager → 再改 UI 层，符合要求。 | ✅ 安全 |
| 4 | `battle_engine.gd` Buff 通用化 | `enemy_ai.gd` / `damage_calculator.gd` 是否读取 `iron_guard_buff`？ | 全文搜索确认：`enemy_ai.gd` 未引用 `iron_guard_buff`；`damage_calculator.gd` 的 `spawn_hero` 已同步改为 `buff_list: []`；`scripts/` / `scenes/` / `autoload/` 中 `iron_guard_buff` 引用已清零。 | ✅ 安全 |
| 5 | `skill_manager.gd` / `ultimate_manager.gd` 重构 | BattleEngine 调用接口签名是否变化？ | 接口签名**完全不变**，仅内部实现改为配置驱动。 | ✅ 安全 |
| 6 | `hero_configs.json` 字段变更 | `hero_select.gd` 的星级标注从硬编码改为读取 `favored_attr` | 已确认 3 名主角都已填写 `favored_attr`（勇者=2力量/影舞者=3敏捷/铁卫=1体魄），且 Fallback 数据已同步。 | ✅ 安全 |

---

## 二、潜在运行时风险

### 风险 1：旧存档兼容性问题（低危）

**描述**: 如果存在包含 `iron_guard_buff`/`iron_guard_buff_turns` 的旧存档 battle hero Dictionary（`DamageCalculator.spawn_hero` 生成），这些字段现在不再被 `spawn_hero` 初始化，也不会被战斗引擎读取。

**影响**: 
- 旧存档中的战斗 hero 对象若包含 `iron_guard_buff=true`，在重构后会被忽略，因为战斗引擎现在只读取 `buff_list`。
- 如果旧存档是在**战斗中**保存的（ mid-battle save），且当时铁卫正在享受不动如山 buff，重启后该 buff 会丢失。

**缓解措施**: 
- 当前项目为 Phase 2，尚无生产环境 mid-battle 存档机制（`SaveManager.save_run_state` 保存的是 `RuntimeRun`，不是战斗中的 Dictionary）。
- 若未来实现 mid-battle 存档，需在反序列化时将旧字段 `iron_guard_buff`/`iron_guard_buff_turns` 迁移为 `buff_list` 中的标准化 buff 结构。

**建议**: 在存档版本号中记录 schema 版本，加载旧版本存档时执行一次数据迁移。

---

### 风险 2：ConfigManager Fallback 数据不完整（低危）

**描述**: `config_manager.gd` 中的 `_FALLBACK_HERO_CONFIGS` 原本缺少 `favored_attr`、`passive_skill_id`、`ultimate_skill_id`、`is_default_unlock`。本次已补齐，但如果未来新增字段而忘记更新 Fallback，JSON 加载失败时代码行为可能不一致。

**影响**: 仅在 `resources/configs/hero_configs.json` 文件缺失或损坏时触发 Fallback。

**缓解措施**: Fallback 数据已同步更新。建议将 Fallback 维护纳入新增字段的 checklist。

---

### 风险 3：`check_iron_counter` 通过 `chain_tags` 判断反击身份（中危）

**描述**: 重构后 `check_iron_counter` 不再检查 `hero_id == "hero_iron_guard"`，而是检查被动技能的 `chain_tags` 是否包含 `"反击"`。如果未来某非铁卫英雄的被动技能也包含 `"反击"` 标签，该英雄也会触发铁壁反击逻辑（反弹伤害 + 眩晕）。

**影响**: 如果策划/配置误用 `"反击"` 标签，可能导致非铁卫英雄获得反击能力。

**缓解措施**: 
- 当前只有 8005（铁壁反击）和 8006（不动如山）包含 `"反击"` 标签，且 8006 是必杀技不是被动技，不会被 `_get_passive_skill_config` 读取。
- 建议未来在 `skill_configs.json` 的 Schema 中增加 `skill_sub_type` 字段（如 `"counter"` / `"pursuit"` / `"multihit"`），替代 `chain_tags` 作为代码分支的判断依据。

---

### 风险 4：`run_controller.gd` 中的 `hero_id` 回退（低危）

**描述**: `run_controller.gd` 中若 `ConfigManager.get_hero_id_by_config_id()` 返回空字符串，会回退到 `"hero_warrior"`。

**影响**: 如果 `hero_configs.json` 中某主角的 `id` 字段与代码中的 config_id 不一致，会导致错误的主角被选中。

**缓解措施**: 
- 当前 hero_configs.json 中 id=1/2/3 与代码预期完全一致。
- 新增第4名主角时，需确保 `id` 字段连续且唯一，并在 `get_hero_id_by_config_id` 的遍历中能被正确匹配。

---

### 风险 5：影舞者必杀 `partner_boost` 参数当前未生效（低危）

**描述**: `skill_configs.json` 8004 的 `trigger_params` 中新增了 `partner_boost: 1.5`，但 `UltimateManager._check_shadow_ultimate()` 中未读取或使用该参数。原代码也没有这个逻辑。

**影响**: 这是一个**预留参数**。当前影舞者必杀期间伙伴援助概率不会被 `partner_boost` 放大，与重构前行为一致（重构前也没有这个逻辑）。

**缓解措施**: 已确认未改变现有行为。若 Phase 3 需要实现该效果，需在 `PartnerAssist` 或 `BattleEngine` 中增加对 `partner_boost` 的读取逻辑。

---

### 风险 6：`test_decoupling.gd` 依赖运行时 Godot 引擎（信息）

**描述**: 当前执行环境缺少 Godot 可执行文件，`test_decoupling.tscn` 和 `test_battle_engine.tscn` 无法在本地自动执行。

**影响**: 无法通过自动化脚本验证战斗数值差异 < 1% 的回归测试要求。

**缓解措施**: 
- 已在验收报告中列出手动验证步骤。
- 建议接入 CI/CD 时配置 Godot headless 模式运行测试场景。

---

## 三、需要后续跟进的代码点

| 位置 | 说明 | 优先级 |
|:---|:---|:---:|
| `scripts/core/ultimate_manager.gd` `_check_shadow_ultimate` | 预留参数 `partner_boost` 未消费 | 低 |
| `scripts/core/battle_engine.gd` `ROUND_START` | 当前只有不动如山有 Buff 到期日志；未来多 Buff 时建议统一日志 | 低 |
| `autoload/config_manager.gd` `_FALLBACK_HERO_CONFIGS` | 需与 JSON Schema 保持同步 | 中 |
| 存档系统 | 若未来支持战斗中存档，需增加 `iron_guard_buff` → `buff_list` 的迁移逻辑 | 低 |

---

## 四、总结

| 风险等级 | 数量 | 说明 |
|:---|:---:|:---|
| 高危 | 0 | 无 |
| 中危 | 1 | `chain_tags` 误用可能导致非预期英雄获得反击能力 |
| 低危 | 4 | 旧存档兼容、Fallback 同步、hero_id 回退、partner_boost 预留 |
| 信息 | 1 | 需 Godot 运行时完成最终回归验证 |

**整体评估**: 本次重构改动范围可控，接口契约保持向后兼容，无破坏性变更。主要风险集中在**配置标签规范**和**运行时回归验证**两个环节，建议在 Godot 编辑器中完成最终战斗数值回归测试后，方可视为完全验收通过。

---

*报告生成时间: 2026-05-09*
