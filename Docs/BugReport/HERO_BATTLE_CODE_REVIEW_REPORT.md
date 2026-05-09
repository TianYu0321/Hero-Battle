# Hero-Battle 代码审查报告

> 审查日期: 2026-05-10  
> 仓库: https://github.com/TianYu0321/Hero-Battle  
> 审查范围: 72个GDScript脚本 + 26个场景 + 14个JSON配置 + project.godot  
> 审查维度: 核心引擎层 / 系统层 / UI层 / 架构层(AutoLoad+模型+配置) / MVP合规性  
> 基准: 设计文档 + 开发规格书《赛马娘版Q宠大乐斗》v1.0

---

## 一、审查总览

| 维度 | 审查文件数 | 严重 | 警告 | 建议 | 合计 |
|------|----------:|:----:|:----:|:----:|:----:|
| 核心引擎层 | 8 + 3 JSON | 4 | 10 | 9 | 23 |
| 系统层+UI层 | 8 + 6场景 + 5 JSON | 7 | 11 | 8 | 26 |
| 架构层(AutoLoad+模型+配置) | 5 + 8模型 + 11 JSON | 6 | 12 | 6 | 24 |
| **合计** | **全部72脚本+26场景+14配置** | **17** | **33** | **23** | **73** |

**整体评估**: 项目架构清晰，三层架构和EventBus解耦基本合规，30回合养成循环核心流程已正确实现。但存在 **17个严重问题** 需优先修复，主要集中在：配置表加载遗漏/硬编码、战斗可复现性破坏、场景切换死锁、功能性BUG（候选双次生成、权重不一致）。

---

## 二、严重问题（17项）—— 必须修复

### 2.1 架构层严重问题（6项）

#### [严重-A1] ConfigManager 遗漏加载3个配置文件 ⭐ P0

**文件**: `autoload/config_manager.gd`  
**问题**: `_load_all_configs()` 声明了 `_shop_configs`、`_node_configs`、`_scoring_configs` 三个缓存字典，但从**未加载对应的JSON文件**。调用 `get_shop_price_config()`、`get_node_weights()`、`get_scoring_config()` 永远返回空字典。  
**影响**: 商店系统、节点池系统、评分系统全部回退到硬编码默认值。  
**修复**: 在 `_load_all_configs()` 中补充：
```gdscript
_shop_configs = _load_json_safe("res://resources/configs/shop_configs.json", {}).get("entries", {})
_node_configs = _load_json_safe("res://resources/configs/node_pool_configs.json", {}).get("entries", {})
_scoring_configs = _load_json_safe("res://resources/configs/scoring_configs.json", {}).get("entries", {})
```

---

#### [严重-A2] GameManager 场景切换失败死锁 ⭐ P0

**文件**: `autoload/game_manager.gd` 第99-107行  
**问题**: `_do_instant_transition()` 中如果 `change_scene_to_file()` 返回错误，`return` 前未重置 `_is_transitioning = false`。该标记在 `change_scene()` 第77行才被清除。错误发生后标记永远为 `true`，**后续所有场景切换请求都被拒绝**。  
**修复**: 在 `change_scene()` 中使用 `try/finally` 模式确保 `_is_transitioning` 无论成功失败都重置。

---

#### [严重-A3] SaveManager 缺少版本兼容性检查

**文件**: `autoload/save_manager.gd`  
**问题**: 有 `_current_version = 1` 且 `save_run_state()` 写入 `data["version"]`，但 `load_latest_run()` 完全**不检查版本号**。未来存档格式变更时旧存档会导致数据解析错误。  
**修复**: 在 `_validate_save_integrity()` 中加入版本检查：
```gdscript
const _SUPPORTED_VERSIONS: Array[int] = [1]
# 检查: if not version in _SUPPORTED_VERSIONS: return false
```

---

#### [严重-A4] ModelsSerializer 引用9个不存在的模型类 ⭐ P0

**文件**: `scripts/models/models_serializer.gd` 第41-76行  
**问题**: `deserialize_from_dict()` match分支引用了以下不存在/未定义的类：  
- `RuntimeBuff`、`RuntimeTrainingLog`、`RuntimeFinalBattle`
- `FighterArchivePartner`、`FighterArchiveScore`
- `BattleMain`、`BattleRound`、`BattleAction`、`BattleFinalResult`  
**影响**: 反序列化到这些类型时**运行时崩溃**。  
**修复**: 改为安全降级：先检查类是否存在，不存在时返回null并报警告。

---

#### [严重-A5] SaveManager 直接调用 ConfigManager 私有方法

**文件**: `autoload/save_manager.gd` 第81行  
**问题**: 直接调用 `ConfigManager._load_json_safe()`（以下划线开头的私有方法），破坏封装。  
**修复**: 在 ConfigManager 中提供公共静态方法 `load_json_config()`。

---

#### [严重-A6] partner_support_configs.json 未被加载

**文件**: `autoload/config_manager.gd`  
**问题**: `_load_all_configs()` 加载了 `partner_assist_configs.json`，但**未加载** `partner_support_configs.json`（锻炼支援配置）。  
**修复**: 补充加载逻辑并暴露getter。

---

### 2.2 系统+UI层严重问题（7项）

#### [严重-S1] 评分权重硬编码与JSON配置不一致 ⭐

**文件**: `scripts/systems/settlement_system.gd` 第9-13行  
**问题**: 代码硬编码权重（30/25/20/15/10）与 `scoring_configs.json`（40/20/20/10/10）完全不符。评级阈值也不同（S>=85 vs S>=90）。实际使用硬编码值计算，JSON配置形同虚设。  
**对比**:

| 维度 | JSON配置 | 代码硬编码 | 差异 |
|------|---------|-----------|------|
| 终局战 | 40% | 30% | -10% |
| 养成效率 | 20% | 25% | +5% |
| PVP | 20% | 20% | 0% |
| 流派纯度 | 10% | 15% | +5% |
| 连锁展示 | 10% | 10% | 0% |

**修复**: 从 `ConfigManager.get_scoring_config()` 读取权重和阈值。

---

#### [严重-S2] 救援候选生成被调用两次 — 候选不一致BUG ⭐

**文件**: `scripts/systems/run_controller.gd` 第177行 + `scripts/systems/node_resolver.gd` 第62行  
**问题**: 救援回合 `generate_candidates()` 被调用两次：第一次生成UI展示选项，第二次在 `resolve_node()` 中再次生成。由于使用 `pick_random()`，**两次结果可能完全不同**，玩家看到的选项与实际可选的不一致。  
**修复**: 将候选结果通过 `node_config` 参数传递给 `resolve_node()`，避免二次生成。

---

#### [严重-S3] 主菜单保留"斗士档案"按钮 — MVP范围外

**文件**: `scenes/main_menu/menu.gd` 第14、27、36-37行  
**问题**: 保留 `%BtnArchive` 按钮和 `archive_view_requested` 信号。Phase 1不应有斗士档案查看UI（终局结算后直接展示本局档案即可）。  
**修复**: 注释/删除按钮及相关逻辑。

---

#### [严重-S4] 节点池有放回抽样 — 可能产生3个相同选项

**文件**: `scripts/systems/node_pool_system.gd` 第44-52行  
**问题**: `generate_options()` 循环调用 `_weighted_pick()`，选中的节点类型**不放回移除**，同一回合可能出现3个完全相同的选项。  
**修复**: 选中后 `weights.erase(node_type)` 实现不放回抽样。

---

#### [严重-S5] 商店系统完全未读取JSON配置

**文件**: `scripts/systems/shop_system.gd` 第100-110行  
**问题**: 全部使用硬编码价格（基础20/30，递增+10），未读取 `shop_configs.json` 中定义的商品配置、库存限制、出现回合限制、递增步长差异（属性+10/伙伴+15/生命+5/全属性+25）。

---

#### [严重-S6] 节点池系统完全未读取JSON配置

**文件**: `scripts/systems/node_pool_system.gd` 第21-27行  
**问题**: 使用硬编码权重字典，未读取 `node_pool_configs.json` 中定义的阶段权重、max_consecutive限制、enemy_pool、shop_item_pool等。

> **关联**: S5+S6 与 [严重-A1] ConfigManager遗漏加载 是同一问题的两面。修复A1后，S5和S6需要同步修改代码使用ConfigManager getter。

---

#### [严重-S7] HUD硬编码显示值

**文件**: `scenes/run_main/run_main.gd` 第44-51行  
**问题**: `_update_hud()` 全部使用硬编码值（回合1/30、金币100、生命100/100、属性条50），未从 `RunController` 获取实际数据。  
**修复**: 从 `_run_controller.get_current_run_summary()` 获取实际运行时数据。

---

### 2.3 核心引擎层严重问题（4项）

#### [严重-E1] 同速决胜破坏战斗可复现性 ⭐

**文件**: `scripts/core/action_order.gd` 第59行  
**问题**: 同速决胜使用全局 `randf()` 而非实例化的 `_rng`，破坏战斗可复现性（不同运行环境产生不同序列）。  
**修复**: 改用 `_rng.randf()`。

---

#### [严重-E2] 追击/反击概率整数除法BUG ⭐

**文件**: `scripts/core/skill_manager.gd` 第56、123行  
**问题**: `float(attr_val / prob_attr_step)` 中 `attr_val / prob_attr_step` 是**整数除法**（GDScript默认），例：`15/10=1` 而非 `1.5`，属性加成完全丢失。  
**修复**: 改为 `float(attr_val) / float(prob_attr_step)`。

---

#### [严重-E3] 混沌领主成长指数增长（应为线性）

**文件**: `scripts/core/enemy_ai.gd` 第47-48行  
**问题**: `stats[key] *= 1.05` 每回合在当前值上乘1.05，20回合后属性变为**2.65倍**（指数增长）。规格书定义"每回合全属性+5%"是线性增长（最多+45%）。  
**修复**: 改为 `stats[key] = base_stats[key] * (1.0 + 0.05 * turn_count)`。

---

#### [严重-E4] ULTIMATE_CHECK后未执行战斗结束检查

**文件**: `scripts/core/battle_engine.gd` 第89-92行  
**问题**: `_check_battle_end()` 未在 `ULTIMATE_CHECK` 状态后执行，必杀技击杀敌人后可能继续进入下一回合而非正确结束战斗。  
**修复**: 在ULTIMATE_CHECK状态的execute后添加 `_check_battle_end()` 调用。

---

## 三、警告问题（33项）—— 建议修复

### 3.1 引擎层警告（10项）

| # | 文件 | 问题 | 影响 |
|---|------|------|------|
| W-E1 | `battle_engine.gd` | `HERO_COUNTER` 状态枚举定义但**从未作为独立状态使用**，铁卫反击未正确集成到状态机 | 铁卫反击机制不完整 |
| W-E2 | `battle_engine.gd` | 伙伴援助触发类型 hardcoded 为 `"AFTER_HERO_ATTACK"`，未遍历6种触发类型 | 援助触发不完整 |
| W-E3 | `damage_calculator.gd` | `spawn_enemy`/`spawn_hero` 使用不可控 `randi()` 而非确定性RNG | 敌人属性生成不可复现 |
| W-E4 | `damage_calculator.gd` | `technique` 攻击力系数与 `strength` 共用 `atk_from_str` 配置 | 技巧属性对攻击的贡献未独立配置 |
| W-E5 | `chain_trigger.gd` | 伙伴存活检查默认 `true`，可能让已阵亡伙伴参与连锁 | 幽灵伙伴参与连锁 |
| W-E6 | `skill_manager.gd` | 铁卫反击眩晕概率只取第一个buff检查，未遍历全部 | 多buff时眩晕判定不准确 |
| W-E7 | `ultimate_manager.gd` | 不动如山 buff 的 `damage_reduction: 0.40`**从未被 `compute_damage` 实际使用** | 减伤40%不生效 |
| W-E8 | `ultimate_manager.gd` | 影舞者风暴乱舞的 `partner_boost: 1.5` **完全未实现** | 伙伴概率×1.5倍不生效 |
| W-E9 | `enemy_ai.gd` | 元素法师 `turn_number == 3` 为全局第3回合，与出场回合(12-18)冲突，**蓄力永不触发** | 元素法师核心机制失效 |
| W-E10 | `partner_assist.gd` | 低血条件解析只支持硬编码的30%/40%，不支持规格书的"生命<50%" | 条件触发不灵活 |

### 3.2 系统+UI层警告（11项）

| # | 文件 | 问题 | 影响 |
|---|------|------|------|
| W-S1 | 6个UI场景 | `_ready()` 中连接EventBus信号，但**无 `_exit_tree()` 中断开** | 场景切换后悬空引用/内存泄漏 |
| W-S2 | `run_controller.gd` | `continue_run()` 返回 `false`，TODO占位，存档恢复未实现 | 续局功能不可用 |
| W-S3 | `run_controller.gd` | `HERO_SELECT` 和 `TAVERN` 状态枚举定义但从未使用 | 状态机设计不完整 |
| W-S4 | `battle.gd` | 极简实现，未集成EventBus信号和战斗引擎回调 | 战斗UI与引擎未连接 |
| W-S5 | `node_resolver.gd` | PVP降级路径返回的数据结构与正常路径不一致（缺`data`包装层） | PVP降级处理时崩溃 |
| W-S6 | `node_resolver.gd` | 普通战斗节点直接发金币奖励，**无实际战斗引擎调用** | 普通战斗100%胜利无风险 |
| W-S7 | `run_controller.gd` | `_auto_save()` 用裸引用检查非 `is_instance_valid()` | 空指针风险 |
| W-S8 | `character_manager.gd` | 熟练度阶段英文命名（NOVICE→FAMILIAR→PROFICIENT→EXPERT）与需求"生疏→熟悉→精通→专精"不对应 | UI展示需额外映射 |
| W-S9 | `settlement.gd` | `archive_saved` 信号防重复机制有竞态窗口 | 快速点击可能重复处理 |
| W-S10 | `shop_system.gd` | 伙伴等级上限Lv3多处硬编码 | 可维护性差 |
| W-S11 | `node_pool_configs.json` | 只配置了4种节点类型，缺RESCUE(5)/PVP_CHECK(6)/FINAL(7) | 配置表不完整（注：这些是固定触发非池子生成） |

### 3.3 架构层警告（12项）

| # | 文件 | 问题 | 影响 |
|---|------|------|------|
| W-A1 | `game_manager.gd` | `_SCENE_PATHS` 含 `"ARCHIVE_VIEW"` 但 `GameState` 枚举未定义 | 类型不安全 |
| W-A2 | `save_manager.gd` | 存档位硬编码为1，忽略 `SAVE_SLOT_COUNT=3` | 只支持单存档位 |
| W-A3 | `save_manager.gd` | 直接覆盖写入，无滚动备份（保留最近5份） | 写入中崩溃=存档损坏 |
| W-A4 | `save_manager.gd` | 存档损坏检测后直接返回空，无备份恢复尝试 | 无法恢复损坏存档 |
| W-A5 | `runtime_hero.gd`/`runtime_partner.gd` | 属性命名与JSON不统一（`current_vit` vs `base_physique`，`mnd` vs `spirit`） | 映射混乱 |
| W-A6 | `event_bus.gd` | `save_loaded` 和 `game_loaded` 两信号语义高度重叠 | 信号冗余 |
| W-A7 | `game_manager.gd` | `_on_continue_game_requested()` 标记"未实现"但信号已连接 | 用户点击无反馈 |
| W-A8 | `fighter_archive_main.gd` | `from_runtime()` 缺少 `archive_id/account_id/client_version/is_fixed` 等字段复制 | 档案字段不完整 |
| W-A9 | `config_manager.gd` | 配置只在 `_ready()` 加载一次，无运行时热更新方法 | 配置变更需重启 |
| W-A10 | `audio_manager.gd` | Phase 1 占位不完整，只打印warning无实际播放器状态 | 音频系统空壳 |
| W-A11 | `project.godot`/`fighter_archive_main.gd` | 版本号不一致（0.1.0 vs 1.0.0） | 存档版本混乱 |
| W-A12 | `enemy_configs.json` | 精神属性用 `spi` 缩写，其他配置用 `mnd`/`spirit` | 命名不统一 |

---

## 四、建议问题（23项）—— 持续改进

### 4.1 引擎层建议（9项）

| # | 问题 | 文件 |
|---|------|------|
| T-E1 | 伤害公式应添加防御方为0时的除零保护 | `damage_calculator.gd` |
| T-E2 | 概率计算结果应 clamp 到 [0,1] 范围 | `skill_manager.gd` |
| T-E3 | 随机数种子应在战斗开始时固定，保证可复现 | `battle_engine.gd` |
| T-E4 | 连锁计数器应在战斗INIT时重置为0 | `chain_trigger.gd` |
| T-E5 | 必杀技标记位应使用独立变量而非嵌在buff中 | `ultimate_manager.gd` |
| T-E6 | 伙伴援助的6种触发类型应配置化而非hardcoded | `partner_assist.gd` |
| T-E7 | 敌人AI应支持配置驱动的行为树而非纯代码 | `enemy_ai.gd` |
| T-E8 | 铁卫反击触发条件应统一使用 HERO_COUNTER 状态 | `battle_engine.gd` |
| T-E9 | 伤害类型标记（普攻/技能/反击/连锁/援助）应添加到BattleAction | `battle_action.gd` |

### 4.2 系统+UI层建议（8项）

| # | 问题 | 文件 |
|---|------|------|
| T-S1 | 统一使用 ConfigManager 读取所有配置（消除硬编码/JSON双轨制） | 多个 |
| T-S2 | 为 `node_resolver.gd` match分支添加详细注释 | `node_resolver.gd` |
| T-S3 | 边际递减生效时通过EventBus通知UI显示警告 | `training_system.gd` |
| T-S4 | `run_controller.gd` 公共方法添加空值检查 | `run_controller.gd` |
| T-S5 | `hero_select.gd` 卡片索引添加越界检查 | `hero_select.gd` |
| T-S6 | EventBus信号使用类型安全定义（TypedDictionary） | `event_bus.gd` |
| T-S7 | `settlement.gd` 的 `populate()` 方法未被调用，应删除或统一入口 | `settlement.gd` |
| T-S8 | 启动时添加配置校验（JSON结构 vs 代码期望） | `game_manager.gd` |

### 4.3 架构层建议（6项）

| # | 问题 | 文件 |
|---|------|------|
| T-A1 | `RuntimeMastery.stage` 应使用枚举而非裸int | `runtime_mastery.gd` |
| T-A2 | 所有模型 `from_dict()` 添加字段类型校验 | 全部model |
| T-A3 | `RuntimeRun.training_count_per_attr` Array 改为 Dictionary | `runtime_run.gd` |
| T-A4 | `get_battle_formula_config()` 脆弱实现（for循环break） | `config_manager.gd` |
| T-A5 | EventBus信号添加文档注释（触发方/消费方/参数） | `event_bus.gd` |
| T-A6 | `project.godot` 添加游戏特定输入映射（加速/跳过/暂停） | `project.godot` |

---

## 五、MVP合规性检查

### 5.1 Phase 1 范围冻结检查

| 检查项 | 要求 | 实际 | 状态 |
|--------|------|------|:----:|
| RANKING状态 | 不应存在 | 不存在 | ✅ |
| 斗士档案查看UI | 不应存在 | `menu.gd` 中仍保留按钮 | ❌ [严重-S3] |
| PVP | 本地AI对手池 | 降级路径返回AI，无在线对战 | ✅ |
| 装备系统 | 不应存在 | 代码中无装备引用 | ✅ |
| 30回合节点分布 | 5/10/15/20/25/30 | 正确实现 | ✅ |
| 3主角 | 勇者/影舞者/铁卫 | 已实现 | ✅ |
| 6伙伴 | 剑士/斥候/盾卫/药师/术士伙伴/猎人 | 已实现 | ✅ |
| 7节点类型 | 锻炼/战斗/精英/商店/救援/PVP/终局 | 已实现 | ✅ |
| 评分公式 | 5项加权和=100% | 权重硬编码与配置不一致 [S1] | ⚠️ |
| 存档系统 | 极简本地JSON | 已实现，但缺版本检查 [A3] | ⚠️ |
| 纯色块占位 | 无像素画/动画 | 基本实现 | ✅ |

### 5.2 设计文档一致性检查

| 检查项 | 设计文档 | 代码 | 状态 |
|--------|---------|------|:----:|
| AutoLoad数量(5个) | GameManager/ConfigManager/SaveManager/AudioManager/EventBus | 5个，匹配 | ✅ |
| 三层架构单向依赖 | 功能层→引擎层→数据配置层 | EventBus解耦，无反向依赖 | ✅ |
| 五属性编码 | 1=体魄,2=力量,3=敏捷,4=技巧,5=精神 | 全局int编码，无字符串混用 | ✅ |
| 伤害公式 | 基础×属性系数×技能倍率×随机波动(0.9-1.1) | 已实现 | ✅ |
| 连锁规则 | 4段上限/伙伴2次/0.3-0.5秒间隔 | 4段和2次已实现，间隔未检查 | ⚠️ |
| 必杀技限1次 | 每场限1次标记 | buff内标记，[E4] ULTIMATE_CHECK后未检查结束 | ⚠️ |
| 铁卫不动如山 | 50%血/3回合/减伤40%/反击100%/眩晕25% | 触发正确，但[E7]减伤40%未生效，[E8]伙伴概率×1.5未实现 | ❌ |
| 评分权重 | 终局战40/养成20/PVP20/流派10/连锁10 | 代码硬编码30/25/20/15/10 | ❌ [S1] |
| 评级阈值 | S≥90/A≥75/B≥60/C≥40/D<40 | 代码S≥85/A≥70/B≥55/C≥35 | ❌ [S1] |
| 熟练度阈值 | 生疏0→熟悉1-3→精通4-6→专精≥7 | 代码实现0→≥1→≥4→≥7（熟悉阈值偏早） | ⚠️ |
| 锻炼边际递减 | >60%总投入时-20% | 已实现 | ✅ |
| 副属性50%共享 | 每2次主属性锻炼副属性+1计数 | 已实现 | ✅ |

---

## 六、修复优先级

### P0 — 立即修复（阻塞性功能/崩溃风险）

| 优先级 | 问题 | 原因 |
|:------:|------|------|
| 1 | [严重-A1] ConfigManager遗漏3个配置加载 | 商店/节点池/评分系统全部回退硬编码 |
| 2 | [严重-A2] GameManager场景切换死锁 | 一次失败后永远卡死 |
| 3 | [严重-A4] ModelsSerializer引用不存在类 | 运行时反序列化崩溃 |
| 4 | [严重-S2] 救援候选双次生成 | 功能性BUG，选项不一致 |
| 5 | [严重-E2] 整数除法概率BUG | 属性加成完全丢失 |
| 6 | [严重-E3] 混沌领主指数增长 | 敌人强度失控 |

### P1 — 本周修复（核心体验影响）

| 优先级 | 问题 |
|:------:|------|
| 7 | [严重-S1] 评分权重不一致 |
| 8 | [严重-E1] 同速决胜破坏可复现性 |
| 9 | [严重-S4] 节点池有放回抽样 |
| 10 | [严重-E4] ULTIMATE_CHECK后未检查结束 |
| 11 | [严重-S7] HUD硬编码 |
| 12 | [严重-S3] 斗士档案按钮未删除 |
| 13 | [严重-A3] SaveManager版本检查 |
| 14 | [严重-S5+S6] 商店+节点池读配置 |
| 15 | [严重-A5] 封装破坏 |
| 16 | [严重-A6] partner_support配置未加载 |
| 17 | W-E7/E8 铁卫减伤+影舞者伙伴概率未生效 |

### P2 — 后续迭代（警告+建议）

全部33个警告问题和23个建议问题，按模块分批处理。

---

## 七、总体评价

### 达标项 ✅
- 三层架构（功能层/引擎层/数据配置层）单向依赖合规
- EventBus全局信号总线解耦模式正确实现
- 5个AutoLoad单例初始化顺序正确（EventBus最先）
- 30回合养成循环核心流程（5/10/15/20/25/30固定节点）正确实现
- 锻炼系统（熟练度四阶段+边际递减+副属性共享）已实现
- 五属性编码全局统一（1=体魄,2=力量,3=敏捷,4=技巧,5=精神）
- 命名规范（snake_case/PascalCase）整体合规
- Phase 1范围基本冻结（无RANKING、无装备系统）
- 存档/读档基础设施已建立

### 未达标项 ❌
- **配置表驱动vs硬编码**：大量系统（商店、节点池、评分）使用硬编码值，与JSON配置表不同步，ConfigManager遗漏加载3个配置文件
- **战斗引擎完整性**：铁卫反击状态HERO_COUNTER定义未使用、不动如山减伤40%未生效、影舞者伙伴概率×1.5未实现、元素法师蓄力永不触发
- **数值准确性**：整数除法导致概率加成丢失、混沌领主指数增长、评分权重偏离设计值
- **场景切换健壮性**：错误路径死锁
- **MVP范围合规**：斗士档案按钮未删除

### 综合评分
| 维度 | 评分 | 说明 |
|------|:----:|------|
| 架构设计 | B+ | 三层架构+EventBus正确，但封装有破坏 |
| 状态机实现 | B | 30回合循环正确，战斗状态机有遗漏状态 |
| 数值实现 | C+ | 整数除法BUG、指数增长、权重偏离 |
| 配置驱动 | D+ | 大量硬编码，ConfigManager有遗漏 |
| UI实现 | B- | 场景结构正确，HUD硬编码，信号未断开 |
| 健壮性 | C | 死锁、崩溃风险、版本检查缺失 |
| **综合** | **C+** | **核心流程可跑通，但数值和配置问题需优先修复** |
