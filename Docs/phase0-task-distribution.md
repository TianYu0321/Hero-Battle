# Phase 0 集群任务分发总控

> 日期：2026-05-08  
> 引擎：Godot 4.6.2  
> 语言：GDScript  
> Phase 1 主角：勇者 / 影舞者 / 铁卫（3名，术士进 Phase 2）  
> 设计文档基准：`开发规格书_赛马娘版Q宠大乐斗.md` v1.0

---

## 任务依赖图

```
A(项目骨架) ──┬── E(UI框架+主流程)
              │
B(配置表框架) ──┬── C(数据模型层)
              │
              ├── D(战斗引擎核心)
              │
              └── F(养成节点逻辑)

C ──> F
```

**可并行的第一波**：A + B（无依赖）  
**第二波**：C + D + E（等 B 或 A）  
**第三波**：F（等 B + C 完成）

---

## 通用规范（所有 Agent 必须遵守）

### 1. 目录结构
```
res://
├── autoload/           # AutoLoad 单例脚本
├── resources/          # 自定义 Resource 类 + JSON 配置
│   ├── configs/        # 导出的 JSON 占位数据
│   └── scripts/        # Resource 类定义（.gd）
├── scenes/             # .tscn 场景文件
│   ├── main_menu/
│   ├── hero_select/
│   ├── tavern/
│   ├── training/
│   ├── battle/
│   ├── shop/
│   ├── rescue/
│   ├── settlement/
│   └── shared/         # 共享 UI 组件
├── scripts/            # 逻辑脚本
│   ├── core/           # 核心系统
│   ├── systems/        # 子系统
│   ├── models/         # 数据模型
│   └── utils/          # 工具类
└── assets/             # 美术占位
    ├── characters/     # 色块占位（ColorRect + Label）
    ├── backgrounds/
    └── ui/
```

### 2. 占位美术策略
- **所有角色/伙伴/敌人**：用 `ColorRect`（64×64 纯色块）+ `Label`（显示名称）占位
- **背景**：纯色填充 + 文字标注场景名
- **UI 面板**：基础 Control 节点 + 按钮/标签可用即可
- **特效**：跳过，Phase 1 不做任何粒子/动画特效
- **音效**：跳过

### 3. 代码规范
- 全项目使用 **GDScript**
- 类名：`PascalCase`
- 函数/变量：`snake_case`
- 常量：`UPPER_SNAKE_CASE`
- 信号：用 `EventBus` 全局事件解耦，禁止模块间直接反向依赖
- 所有配置表字段名与规格书完全一致（英文，snake_case）

### 4. 数值占位
- 所有配置表先用 **最小占位数据集** 填充，确保能跑通即可
- 例如：HeroConfig 只需要 3 条记录（勇者/影舞者/铁卫）
- PartnerConfig 先填 6 条（前 6 名默认解锁伙伴）
- 占位 JSON 中的数值可以简化，但字段结构必须完整

### 5. 交付标准
- 每个任务交付时，必须附带一份 `验收清单.md`
- 必须能在 Godot 编辑器中 **无报错运行**（至少能打开场景）
- 核心逻辑必须附带 **单元测试场景**（一个 .tscn 用按钮触发测试输出到 Output）

---

## 各任务详细需求

### 任务 A：项目骨架（Agent 1）
**输入**：设计文档 2.1、2.2、7.2  
**输出目录**：`res://autoload/`、`res://scenes/shared/`、`project.godot`

| # | 交付项 | 说明 |
|:---:|:---|:---|
| A1 | `project.godot` | 正确配置，窗口 1280×720，2D 像素渲染 |
| A2 | `autoload/game_manager.gd` | 全局状态机（MENU → HERO_SELECT → TAVERN → RUNNING → SETTLEMENT），场景切换方法 |
| A3 | `autoload/event_bus.gd` | 全局信号总线，预定义常用信号：`turn_advanced`, `battle_started`, `battle_ended`, `hero_selected`, `partner_selected`, `gold_changed`, `hp_changed` |
| A4 | `autoload/save_manager.gd` | 本地 JSON 存档读写接口（Phase 1 只需本地文件） |
| A5 | `autoload/audio_manager.gd` | 占位：空壳，预留 BGM/音效接口 |
| A6 | `autoload/config_manager.gd` | 占位：空壳，等任务 B 完成后接入 |
| A7 | `scenes/shared/transition_screen.tscn` | 场景切换淡入淡出过渡 |
| A8 | `scenes/main_menu/main_menu.tscn` | 主菜单：标题 + "开始游戏" 按钮 + "继续" 按钮 → 跳转到 hero_select |
| A9 | `scenes/hero_select/hero_select.tscn` | 主角选择：3 个色块占位（显示勇者/影舞者/铁卫名称 + 初始属性文字），点击后记录选择并跳转 tavern |
| A10 | `scenes/tavern/tavern.tscn` | 酒馆：显示 6 个伙伴色块占位（前6名），玩家选 2 个后进入养成主循环 |

**验收清单**：
- [ ] 能从主菜单 → 主角选择 → 酒馆，流程无报错
- [ ] 主角选择后能正确记录到 GameManager 的全局状态
- [ ] 酒馆选 2 伙伴后能正确记录
- [ ] 场景切换有过渡动画
- [ ] 所有 AutoLoad 单例在 `project.godot` 中正确注册

---

### 任务 B：配置表框架（Agent 2）
**输入**：设计文档 3.1、3.2、3.3、五属性编码  
**输出目录**：`res://resources/scripts/`、`res://resources/configs/`

| # | 交付项 | 说明 |
|:---:|:---|:---|
| B1 | `resources/scripts/hero_config.gd` | `HeroConfig` Resource 类：id, name, desc, initial_stats(体魄/力量/敏捷/技巧/精神), skill_id, ultimate_skill_id |
| B2 | `resources/scripts/partner_config.gd` | `PartnerConfig` Resource 类：id, name, position_type(输出/防御/辅助/控场/斩杀/爆发/经济), favored_attribute(1-5), assist_trigger_type, support_bonus_lv1/lv3/lv5, assist_desc, lv3_breakthrough, synergy_hero |
| B3 | `resources/scripts/skill_config.gd` | `SkillConfig` Resource 类：id, name, trigger_type, base_chance, effect_type, damage_formula, chain_tag, max_per_battle |
| B4 | `resources/scripts/enemy_config.gd` | `EnemyConfig` Resource 类：id, name, difficulty_tier, min_round, max_round, stat_multipliers, special_mechanic, mechanic_desc |
| B5 | `resources/scripts/battle_formula_config.gd` | `BattleFormulaConfig` Resource 类：公式参数，伤害 = base × attr_coeff × skill_mult × random(0.9-1.1)，各属性系数配置 |
| B6 | `resources/scripts/shop_config.gd` | `ShopConfig` Resource 类：upgrade_cost_curve（主角升级价格递增、伙伴升级价格递增） |
| B7 | `resources/scripts/node_config.gd` | `NodeConfig` Resource 类：7种节点类型定义（锻炼/普通战斗/精英战/商店/救援/PVP/终局战） |
| B8 | `resources/scripts/node_pool_config.gd` | `NodePoolConfig` Resource 类：按阶段（前期1-9/中期10-19/后期20-29/终局30）的节点生成权重规则 |
| B9 | `resources/scripts/attribute_mastery_config.gd` | `AttributeMasteryConfig` Resource 类：生疏/熟悉/精通/专精四阶段阈值和加成值 |
| B10 | `resources/scripts/scoring_config.gd` | `ScoringConfig` Resource 类：通关分数 5 项权重和计算公式 |
| B11 | `resources/configs/heroes.json` | 3 条占位数据（勇者/影舞者/铁卫），字段完整，数值按规格书 |
| B12 | `resources/configs/partners.json` | 6 条占位数据（前6名默认解锁伙伴），字段完整 |
| B13 | `resources/configs/enemies.json` | 5 条占位数据（5种精英敌人），字段完整 |
| B14 | `resources/configs/skills.json` | 主角技能 + 伙伴技能占位（至少勇者/影舞者/铁卫的常规技能和必杀技） |
| B15 | `resources/configs/formulas.json` | 伤害公式参数占位 |
| B16 | `resources/configs/shop.json` | 升级价格曲线占位 |
| B17 | `resources/configs/node_pools.json` | 节点池生成规则占位 |
| B18 | `resources/configs/mastery.json` | 属性熟练度阶段配置占位 |
| B19 | `resources/configs/scoring.json` | 评分公式配置占位 |
| B20 | `resources/config_loader.gd` | JSON → Resource 的加载器，提供 `load_config(path) -> Resource` 接口 |

**验收清单**：
- [ ] 所有 Resource 类能在 Godot 中 `preload` 无报错
- [ ] JSON 占位数据能被 `config_loader.gd` 正确解析为 Resource 对象
- [ ] 5 属性编码统一为数字 1-5，无字符串混用
- [ ] 字段命名与规格书一致，文档中有字段对照表
- [ ] 提供一个测试场景 `test_config_loader.tscn`，点击按钮输出解析后的英雄数据到 Output

---

### 任务 C：数据模型层（Agent 3）
**输入**：设计文档 3.1（局内运行时数据表）、3.2（数据关系图）  
**依赖**：任务 B 完成后启动  
**输出目录**：`res://scripts/models/`

| # | 交付项 | 说明 |
|:---:|:---|:---|
| C1 | `scripts/models/runtime_run.gd` | `RuntimeRun`：单局运行主表，含 turn, phase, seed, selected_hero_id, partner_ids[6], gold, hp, max_hp |
| C2 | `scripts/models/runtime_hero.gd` | `RuntimeHero`：主角运行时数据，五维属性、等级、生命、金币、技能等级 |
| C3 | `scripts/models/runtime_partner.gd` | `RuntimePartner`：伙伴运行时数据，config_id, level, slot_index(0=同行/1-5=援助) |
| C4 | `scripts/models/runtime_mastery.gd` | `RuntimeMastery`：属性熟练度运行时，5属性 × 锻炼次数/阶段 |
| C5 | `scripts/models/runtime_buff.gd` | `RuntimeBuff`：临时 BUFF/DEBUFF，含 type, value, remaining_turns |
| C6 | `scripts/models/runtime_battle_log.gd` | `RuntimeBattleLog`：战斗记录，回合数、行动、伤害、触发事件 |
| C7 | `scripts/models/fighter_archive.gd` | `FighterArchive`：终局斗士档案，主角快照、5伙伴快照、技能快照、养成统计、评分 |
| C8 | `scripts/models/player_account.gd` | `PlayerAccount`：局外持久化，已解锁主角/伙伴、局外金币 |
| C9 | `scripts/models/models_serializer.gd` | 所有 Runtime 模型的序列化/反序列化（JSON 互转），用于存档和斗士档案生成 |
| C10 | `scripts/models/game_state.gd` | 单局全局状态容器，聚合 RuntimeRun + RuntimeHero + RuntimePartners + RuntimeMastery + Buffs |

**验收清单**：
- [ ] 所有模型类能正确实例化，默认值合理
- [ ] 模型间关系正确（Run 包含 Hero + Partners + Mastery）
- [ ] 序列化/反序列化测试通过：对象 → JSON → 对象，字段无损
- [ ] FighterArchive 能正确从 GameState 生成快照
- [ ] 提供一个测试场景 `test_models.tscn`，创建完整 GameState 并输出到 Console

---

### 任务 D：战斗引擎核心（Agent 4）
**输入**：设计文档 4.3、4.4、4.5、5.1-5.4  
**依赖**：任务 B 完成后启动  
**输出目录**：`res://scripts/core/`

| # | 交付项 | 说明 |
|:---:|:---|:---|
| D1 | `scripts/core/battle_engine.gd` | 自动战斗引擎主控：20 回合流程驱动 |
| D2 | `scripts/core/action_order.gd` | 行动顺序判定：基于敏捷 + 随机波动的排序算法 |
| D3 | `scripts/core/damage_calculator.gd` | 伤害计算：伤害 = 基础值 × 属性系数 × 技能倍率 × random(0.9-1.1)，公式从 BattleFormulaConfig 读取 |
| D4 | `scripts/core/partner_assist.gd` | 伙伴援助判定器：遍历 5 名援助伙伴，检查触发条件（固定回合/条件/概率/被动/连锁/敌方触发），执行效果 |
| D5 | `scripts/core/chain_trigger.gd` | 连锁触发管理：链长上限 4 段，每段 0.3-0.5 秒间隔（Phase 1 用定时器占位），同伙伴单场最多 2 次 |
| D6 | `scripts/core/skill_manager.gd` | 主角技能 + 必杀技管理：触发检查（勇者追击斩概率、影舞者疾风连击被动、铁卫铁壁反击概率），必杀技整局限1次 |
| D7 | `scripts/core/battle_round.gd` | 单回合控制器：行动顺序 → 主角行动 → 伙伴援助 → 连锁 → 状态结算 → 必杀检查 → 回合结束判定 |
| D8 | `scripts/core/battle_result.gd` | 战斗结果：胜负判定、伤害统计、回合数统计 |
| D9 | `scripts/core/play_mode.gd` | 播放模式接口：简化快进/标准播放 两种模式的基础框架（Phase 1 逻辑层可用，表现层占位） |
| D10 | `scripts/core/enemy_ai.gd` | 敌人 AI 模板：5 种精英敌人的特殊机制（坚甲/闪避/蓄力爆发/狂暴/成长进化） |

**核心规则必须正确实现**：
- 勇者：普攻后 30% 触发追击斩（技巧加成），敌方 40% 血以下触发终结一击（限1次）
- 影舞者：每次普攻分裂 2-4 段（敏捷加成），第 8 回合风暴乱舞（限1次）
- 铁卫：受击后 25% 触发反击（精神加成），半血以下触发不动如山（限1次）
- 连锁：最多 4 段，同伙伴单场最多触发 2 次
- 敌人 AI：5 种模板按难度层递进

**验收清单**：
- [ ] 提供一个 `test_battle_engine.tscn` 测试场景：选择主角 + 预设敌人 → 运行完整 20 回合战斗 → 输出每回合行动和结果到 Output
- [ ] 勇者/影舞者/铁卫 3 种主角各跑 1 次测试，无报错
- [ ] 连锁触发被正确限制在 4 段以内
- [ ] 必杀技整场只触发 1 次
- [ ] 伤害数值在合理范围内（不溢出/不 NaN）

---

### 任务 E：UI 框架 + 主流程（Agent 5）
**输入**：设计文档 4.2（30 回合节点分布）、1.2（单局体验）  
**依赖**：任务 A 完成后启动  
**输出目录**：`res://scenes/`

| # | 交付项 | 说明 |
|:---:|:---|:---|
| E1 | `scenes/run_main/run_main.tscn` | 养成主界面：顶部 HUD（回合数/金币/生命/五维属性条），中间节点选择区域，底部伙伴状态 |
| E2 | `scenes/run_main/turn_controller.gd` | 回合推进控制器：管理 30 回合流程，在第 5/15/25 回合触发救援，第 10/20 回合触发 PVP，第 30 回合触发终局战 |
| E3 | `scenes/run_main/hud_panel.gd` | HUD 面板：实时更新金币、生命、五维属性数值 |
| E4 | `scenes/run_main/node_choice_panel.tscn` | 节点选择 UI：每回合显示 3 个可选节点（锻炼/战斗/商店等），点击后进入对应场景 |
| E5 | `scenes/training/training_scene.tscn` | 锻炼界面：显示 5 个属性按钮（体魄/力量/敏捷/技巧/精神），点击后执行锻炼并返回主界面 |
| E6 | `scenes/shop/shop_scene.tscn` | 商店界面：显示主角升级 + 伙伴升级选项，价格递增，购买后返回 |
| E7 | `scenes/rescue/rescue_scene.tscn` | 救援界面：3 选 1 显示伙伴，选择后加入队伍并返回 |
| E8 | `scenes/battle/battle_scene.tscn` | 战斗界面：双方色块占位 + 血条 + 回合数，调用 BattleEngine 运行，显示简化结果 |
| E9 | `scenes/settlement/settlement_scene.tscn` | 终局结算界面：显示评分（S/A/B/C/D）、分数明细、生成斗士档案按钮 |
| E10 | `scenes/shared/hero_status_bar.tscn` | 共享组件：主角状态条（生命 + 五维属性），多处复用 |
| E11 | `scenes/shared/partner_slot.tscn` | 共享组件：伙伴槽位显示（头像占位 + 等级 + 支援/援助标识） |

**验收清单**：
- [ ] 主界面能正确推进 30 回合，固定节点（5/10/15/20/25/30）正确触发
- [ ] 锻炼界面点击属性后，对应属性数值正确增加
- [ ] 商店升级后价格递增，金币正确扣除
- [ ] 救援 3 选 1 后伙伴正确加入队伍
- [ ] 战斗界面能调用 BattleEngine 并显示胜负结果
- [ ] 结算界面能显示评分和斗士档案（占位数据即可）

---

### 任务 F：养成节点逻辑（Agent 6）
**输入**：设计文档 4.2、4.5、4.6、5.1、6.1  
**依赖**：任务 B + C 完成后启动  
**输出目录**：`res://scripts/systems/`

| # | 交付项 | 说明 |
|:---:|:---|:---|
| F1 | `scripts/systems/training_system.gd` | 锻炼系统：五属性锻炼收益计算，熟练度阶段判定（生疏/熟悉/精通/专精），边际递减（单项超 60% 递减 20%），副属性 50% 熟练度共享 |
| F2 | `scripts/systems/shop_system.gd` | 商店系统：主角升级（属性+3）、伙伴升级（支援/援助加成提升），价格递增曲线 |
| F3 | `scripts/systems/rescue_system.gd` | 救援系统：根据当前回合和队伍状态，从 PartnerConfig 中生成 3 个候选伙伴（半随机，优先补全缺失定位） |
| F4 | `scripts/systems/node_pool_system.gd` | 节点池生成：按阶段（前期/中期/后期）从 NodePoolConfig 读取权重，生成 3 个可选节点 |
| F5 | `scripts/systems/run_loop_system.gd` | 养成循环调度器：驱动 30 回合流程，管理阶段切换，协调节点生成 → 玩家选择 → 系统执行 → 下一回合 |
| F6 | `scripts/systems/settlement_system.gd` | 终局结算：调用评分公式计算 5 项分数，生成评级，创建 FighterArchive 快照 |
| F7 | `scripts/systems/elite_battle_system.gd` | 精英战系统：根据回合数选择难度层敌人，胜利后 3 选 1 奖励，失败 = 本局结束 |
| F8 | `scripts/systems/pvp_check_system.gd` | PVP 检定系统（Phase 1 占位）：匹配 AI 对手，运行完整战斗，记录胜负，应用失败惩罚 |

**验收清单**：
- [ ] 锻炼系统测试：连续锻炼同一属性 10 次，熟练度阶段正确晋升，边际递减生效
- [ ] 商店系统测试：连续升级 5 次，价格正确递增，属性正确提升
- [ ] 救援系统测试：运行 10 次救援，生成的 3 候选不重复，优先补全队伍缺失定位
- [ ] 节点池测试：前期/中期/后期的节点类型分布符合权重配置
- [ ] 结算系统测试：提供预设 GameState，输出正确评分和评级
- [ ] 提供 `test_systems.tscn`，每个子系统一个测试按钮，输出结果到 Console

---

## 审核标准（我验收时用）

每个 Agent 交付后，我会按以下标准审核：

1. **结构合规**：目录结构、命名规范、AutoLoad 注册是否正确
2. **接口契约**：与上下游模块的接口是否匹配（例如 C 的模型是否能被 F 正确使用）
3. **逻辑正确性**：核心算法（伤害公式、熟练度、连锁限制等）是否与规格书一致
4. **可运行性**：能在 Godot 4.6.2 中无报错打开，测试场景能输出预期结果
5. **占位策略**：美术占位是否遵循统一策略（色块+Label），无遗漏
6. **文档完整**：是否附带验收清单，关键代码是否有注释

---

## 下一步

用户将以上 6 份需求分发给 6 个集群 Agent。  
Agent 完成后提交各自目录的代码，我来审核、合并、整合。

**第一波可立即下发**：任务 A + 任务 B（无依赖，完全并行）
