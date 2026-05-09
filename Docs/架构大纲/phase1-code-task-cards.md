# 本地代码 Agent — Phase 1 MVP 代码任务卡总控

**基准设计文档**（已通过审核）：
- `01_module_breakdown.md` — 模块架构
- `02_interface_contracts.md` — 信号总线 + 函数契约
- `03_data_schema.md` — 27 张数据表 Schema
- `04_battle_engine_design.md` — 自动战斗引擎
- `05_run_loop_design.md` — 30 回合养成循环
- `06_ui_flow_design.md` — UI 场景 + HUD
- `07_technical_spec.md` — 命名/编码规范

**引擎**：Godot 4.6.2  
**语言**：GDScript（唯一）  
**目标**：Phase 1 结束时，能完整跑通一局 30 回合 → 终局战 → 生成斗士档案

---

## 任务依赖图

```
任务1(项目骨架) ──┬── 任务7(整合贯通)
                  │
任务2(配置+模型) ──┬── 任务4(战斗引擎)
                  │    └── 任务7
                  ├── 任务5(养成循环)
                  │    └── 任务7
                  └── 任务6(PVP占位)

任务3(UI占位场景) ──→ 任务7

任务7(整合) ──→ 交付
```

---

## 任务 1：项目骨架 + 全局单例 + 入口场景

**优先级**：第一波（无依赖，立即启动）  
**输入**：`01_module_breakdown.md`（2.2 节）、`06_ui_flow_design.md`（场景 1-3）、`07_technical_spec.md`  
**交付目录**：`res://autoload/`、`res://scenes/main_menu/`、`res://scenes/hero_select/`、`res://scenes/tavern/`

### 交付物清单

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| 1 | `project.godot` | 窗口 1280×720，像素 2D 渲染，5 个 AutoLoad 注册 |
| 2 | `autoload/game_manager.gd` | 场景状态机（MENU→HERO_SELECT→TAVERN→RUNNING→FINAL_BATTLE→SETTLEMENT→MENU），`change_scene(to_state, transition_type)` |
| 3 | `autoload/event_bus.gd` | 全局信号总线，预定义 Phase 1 全部信号（参考 02_interface_contracts.md 2.1-2.5 节），信号携带参数加类型注解 |
| 4 | `autoload/config_manager.gd` | 配置加载器：加载 `resources/configs/*.json` 到 Dictionary，提供 `get_hero_config(id)` 等查询接口，常量区存放全局游戏常量（MAX_ROUNDS=30, MAX_CHAIN_SEGMENTS=4 等） |
| 5 | `autoload/save_manager.gd` | 本地 JSON 存档读写，`user://saves/` 目录，提供 `save_run_state(run_data)`、`load_latest_run()`、`generate_fighter_archive(run_result)` |
| 6 | `autoload/audio_manager.gd` | 空壳占位，预定义 `play_bgm(track, fade_in)`、`play_sfx(name, volume)` 接口 |
| 7 | `scenes/main_menu/menu.tscn` + `.gd` | 主菜单：开始新局/继续游戏/退出，纯色块背景 `#2C3E50`，按钮 200×50 |
| 8 | `scenes/hero_select/hero_select.tscn` + `.gd` | 3 主角选择：色块 120×120（勇者红 `#C0392B`/影舞者紫 `#8E44AD`/铁卫蓝 `#2980B9`），显示五维数值，选择后发射 `hero_selected(id)` |
| 9 | `scenes/tavern/tavern.tscn` + `.gd` | 酒馆：6 伙伴色块（按 06 文档颜色），选 2 人后确认，发射 `team_confirmed([partner_id1, partner_id2])` |

### 接口契约

- `GameManager.change_scene(to_state: String, transition_type: String = "fade") -> void`
- `EventBus.hero_selected(hero_id: String)` — hero_id ∈ {"hero_warrior", "hero_shadow_dancer", "hero_iron_guard"}
- `EventBus.team_confirmed(partner_ids: Array[String])` — 长度为 2
- `ConfigManager.get_hero_config(hero_id: String) -> Dictionary | null`
- `SaveManager.load_latest_run() -> Dictionary | null`

### 验收标准

- [ ] Godot 编辑器中打开项目无报错
- [ ] 5 个 AutoLoad 在 `项目设置 → AutoLoad` 中正确注册
- [ ] 主菜单 → 主角选择 → 酒馆，场景切换有淡入淡出过渡
- [ ] 主角选择后 `ConfigManager` 能正确返回英雄数据
- [ ] 酒馆选 2 伙伴后确认按钮才可用，选中数<2 时禁用

---

## 任务 2：配置表框架 + 数据模型层

**优先级**：第一波（无依赖，与任务 1 并行）  
**输入**：`03_data_schema.md`（全部 27 张表）、`07_technical_spec.md`  
**交付目录**：`res://resources/configs/`、`res://resources/scripts/`、`res://scripts/models/`

### 交付物清单

#### 静态配置 JSON（按 03_data_schema.md 字段精确填充）

| # | 文件名 | 说明 | 占位数据量 |
|:---:|:---|:---|:---:|
| 1 | `resources/configs/hero_configs.json` | 3 主角（勇者/影舞者/铁卫）完整字段 | 3 条 |
| 2 | `resources/configs/partner_configs.json` | 6 默认解锁伙伴 | 6 条 |
| 3 | `resources/configs/skill_configs.json` | 主角技能 + 伙伴援助技 | ~20 条 |
| 4 | `resources/configs/partner_assist_configs.json` | 6 伙伴战斗援助配置 | 6 条 |
| 5 | `resources/configs/partner_support_configs.json` | 6 伙伴锻炼支援配置 | 6 条 |
| 6 | `resources/configs/attribute_mastery_configs.json` | 5 属性×4 阶段 | 20 条 |
| 7 | `resources/configs/node_configs.json` | 7 种节点类型 | 7 条 |
| 8 | `resources/configs/node_pool_configs.json` | 前期/中期/后期节点权重 | ~7 条 |
| 9 | `resources/configs/enemy_configs.json` | 5 种精英敌人（数值型系数，非字符串公式） | 5 条 |
| 10 | `resources/configs/battle_formula_configs.json` | 伤害公式参数 | 1 条 |
| 11 | `resources/configs/shop_configs.json` | 主角升级/伙伴升级商品 | ~8 条 |
| 12 | `resources/configs/scoring_configs.json` | 评分权重 + 评级阈值 | 1 条 |

#### 数据模型类（GDScript class，含序列化/反序列化）

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| 13 | `scripts/models/runtime_run.gd` | `RuntimeRun`：单局运行主表 |
| 14 | `scripts/models/runtime_hero.gd` | `RuntimeHero`：主角运行时状态（无 level/xp/equipment） |
| 15 | `scripts/models/runtime_partner.gd` | `RuntimePartner`：伙伴运行时（position 1=同行, 2-4=救援，max_level=3） |
| 16 | `scripts/models/runtime_mastery.gd` | `RuntimeMastery`：属性熟练度（stage 1-4，training_count，边际递减标记） |
| 17 | `scripts/models/runtime_buff.gd` | `RuntimeBuff`：临时 Buff/Debuff |
| 18 | `scripts/models/runtime_training_log.gd` | `RuntimeTrainingLog`：锻炼日志 |
| 19 | `scripts/models/runtime_final_battle.gd` | `RuntimeFinalBattle`：终局战数据 |
| 20 | `scripts/models/player_account.gd` | `PlayerAccount`：局外存档（初始解锁勇者+6 伙伴） |
| 21 | `scripts/models/fighter_archive_main.gd` | `FighterArchiveMain`：档案主表（is_fixed=true） |
| 22 | `scripts/models/fighter_archive_partner.gd` | `FighterArchivePartner`：档案伙伴快照 |
| 23 | `scripts/models/fighter_archive_score.gd` | `FighterArchiveScore`：档案评分明细 |
| 24 | `scripts/models/battle_main.gd` | `BattleMain`：战斗主表 |
| 25 | `scripts/models/battle_round.gd` | `BattleRound`：回合记录 |
| 26 | `scripts/models/battle_action.gd` | `BattleAction`：行动记录 |
| 27 | `scripts/models/battle_final_result.gd` | `BattleFinalResult`：战斗结果 |
| 28 | `scripts/models/models_serializer.gd` | 全局序列化器：所有模型 ↔ JSON 互转 |

### 全局约定（编码必须遵守）

- **五属性编码统一为 1-5**：1=体魄, 2=力量, 3=敏捷, 4=技巧, 5=精神。**禁止用 0 表示生疏阶段**，stage 枚举 1=生疏(NOVICE), 2=熟悉(FAMILIAR), 3=精通(PROFICIENT), 4=专精(EXPERT)
- **熟练度阶段配置**：按 `attribute_mastery_configs.json` 的 20 条记录，stage=1 时 training_bonus=0，stage=2 时 +2，stage=3 时 +4，stage=4 时 +5
- **主角初始属性**：勇者(12/16/10/12/8)，影舞者(10/10/16/10/12)，铁卫(16/8/10/10/14)

### 验收标准

- [ ] 所有 JSON 配置能被 `ConfigManager` 正确解析，无字段缺失
- [ ] 每个模型类能正确实例化，默认值合理
- [ ] 序列化测试：`RuntimeRun` → JSON → `RuntimeRun`，字段无损
- [ ] `FighterArchiveMain` 能从 `RuntimeRun` + `RuntimeHero` + `RuntimePartner` 聚合生成
- [ ] 提供一个测试场景 `test_models.tscn`，点击按钮输出所有模型序列化结果到 Output

---

## 任务 3：UI 占位场景（纯布局，无业务逻辑）

**优先级**：第一波（无依赖，与任务 1/2 并行）  
**输入**：`06_ui_flow_design.md`（场景 4-9）、`07_technical_spec.md`  
**交付目录**：`res://scenes/`

### 交付物清单

| # | 场景路径 | 说明 |
|:---:|:---|:---|
| 1 | `scenes/run_main/run_main.tscn` + `.gd` | 养成主界面：顶部 HUD（回合/金币/生命/五维属性条），中间节点选择区（3 个按钮占位），底部伙伴状态槽 |
| 2 | `scenes/training/training_popup.tscn` + `.gd` | 锻炼弹窗：5 个属性按钮（体魄/力量/敏捷/技巧/精神），结果预览 |
| 3 | `scenes/shop/shop_popup.tscn` + `.gd` | 商店弹窗：商品列表（主角升级/伙伴升级），价格显示，购买按钮，离开按钮 |
| 4 | `scenes/rescue/rescue_popup.tscn` + `.gd` | 救援弹窗：3 个伙伴候选色块，名称/定位/擅长属性，选择按钮 |
| 5 | `scenes/battle/battle.tscn` + `.gd` | 战斗界面：双方色块占位（64×64）+ 血条（ProgressBar）+ 回合数标签 + 日志文本区 + 速度调节按钮 |
| 6 | `scenes/settlement/settlement.tscn` + `.gd` | 终局结算：评分显示（S/A/B/C/D）+ 五维快照 + 档案生成按钮 + 返回主菜单按钮 |

### 占位美术规范（严格遵循）

- 角色/伙伴/敌人：`ColorRect` 64×64，纯色填充（参考 06 文档颜色编码），正中叠加 `Label` 显示名称
- HUD 元素：基础 `Control` + `Label`，字体大小 14-20px
- 弹窗：`PanelContainer` 覆盖，背景半透明黑 `#000000CC`
- 分辨率锚点：全部使用 `Anchor` 系统适应 1280×720
- 无动画/无粒子/无音效

### 验收标准

- [ ] 每个场景能在 Godot 中独立打开，无节点报错
- [ ] `run_main.tscn` HUD 区域布局清晰，能容纳 5 个属性条 + 回合数 + 金币 + 生命
- [ ] `battle.tscn` 能同时显示主角方（左）和敌方（右），血条可更新
- [ ] `settlement.tscn` 能显示大字号评分字母（S/A/B/C/D）
- [ ] 所有场景使用 `snake_case` 命名，与绑定脚本同名

---

## 任务 4：战斗引擎核心

**优先级**：第二波（依赖任务 2 完成）  
**输入**：`04_battle_engine_design.md`、`02_interface_contracts.md`（战斗信号 B01-B24）、`03_data_schema.md`（battle_formula_config / enemy_config / skill_config）  
**交付目录**：`res://scripts/core/`

### 交付物清单

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| 1 | `scripts/core/battle_engine.gd` | 战斗主控：状态机驱动（INIT→ROUND_START→ACTION_ORDER→HERO_ACTION→PARTNER_ASSIST→CHAIN_CHECK→CHAIN_RESOLVE→STATUS_TICK→ULTIMATE_CHECK→ROUND_END→BATTLE_END），20 回合上限 |
| 2 | `scripts/core/action_order.gd` | 行动顺序：有效速度 = (敏捷 + buff) × random(0.9, 1.1)，同速按主角>伙伴>敌人排序 |
| 3 | `scripts/core/damage_calculator.gd` | 伤害计算：伤害 = 基础值 × 属性系数 × 技能倍率 × random(0.9, 1.1)，从 `battle_formula_configs.json` 读取系数 |
| 4 | `scripts/core/partner_assist.gd` | 伙伴援助判定器：遍历 5 名援助伙伴，6 种触发类型（固定回合/条件/概率/被动/连锁/敌方触发），同伙伴单场上限 2 次 |
| 5 | `scripts/core/chain_trigger.gd` | 连锁系统：段数上限 4，同伙伴单场上限 2 次，连锁伤害类型标记为 CHAIN |
| 6 | `scripts/core/skill_manager.gd` | 三主角技能管理：勇者追击斩(30%概率/60%伤害)、影舞者疾风连击(2-4 段/每段 35%)、铁卫铁壁反击(25%/反弹 50%/10%眩晕) |
| 7 | `scripts/core/ultimate_manager.gd` | 必杀技管理：勇者终结一击(敌方<40%血/300%/无视 30%防御)、影舞者风暴乱舞(第 8 回合/6 段/每段 40%)、铁卫不动如山(自身<50%血/3 回合/减伤 40%/反击 100%)。**整局限 1 次**，用过标记 `ultimate_used=true` |
| 8 | `scripts/core/enemy_ai.gd` | 敌人 AI：5 种精英模板（重甲守卫-25%伤/暗影刺客 30%闪避/元素法师第 3 回蓄力/狂战士<30%血狂暴/混沌领主每回合+5%属性），属性按 enemy_config 的数值系数从主角实时属性计算 |
| 9 | `scripts/core/battle_result.gd` | 战斗结果：胜负判定、回合数统计、MVP 伙伴、连锁统计、必杀技标记 |

### 核心规则（不可违背）

| 规则 | 来源 |
|:---|:---|
| 勇者：普攻后 30% 触发追击斩（技巧每+10 点+2%，上限 50%） | 规格书 4.7 节 |
| 影舞者：普攻分裂 2-4 段（敏捷加成），第 8 回合风暴乱舞 | 规格书 4.7 节 |
| 铁卫：受击后 25% 反击（精神加成），半血以下触发不动如山 | 规格书 4.7 节 |
| 铁卫反击插入点：ENEMY_ACTION → HERO_COUNTER → CHAIN_CHECK → STATUS_TICK | 04 文档修正 M1 |
| 连锁上限 4 段，同伙伴单场 2 次 | 规格书 4.4 节 |
| 战斗 20 回合上限，到限按血量比例判胜负 | 规格书 4.3 节 |

### 验收标准

- [ ] 测试场景 `test_battle_engine.tscn`：选择主角 + 预设敌人 → 运行完整战斗 → 输出每回合行动和结果
- [ ] 勇者/影舞者/铁卫各跑 1 次测试，无报错，伤害数值合理
- [ ] 连锁被正确限制在 4 段以内
- [ ] 必杀技整场只触发 1 次，触发后 `ultimate_used` 标记为 true
- [ ] 敌人属性按 `enemy_config` 的数值系数正确计算（例如重甲守卫体魄=主角力量×2.0）

---

## 任务 5：养成循环系统

**优先级**：第二波（依赖任务 2 完成，可与任务 4 并行）  
**输入**：`05_run_loop_design.md`、`02_interface_contracts.md`（养成信号 R01-R21）、`03_data_schema.md`（node_pool_config / shop_config / attribute_mastery_config）  
**交付目录**：`res://scripts/systems/`

### 交付物清单

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| 1 | `scripts/systems/run_controller.gd` | 养成循环主控：30 回合状态机（HERO_SELECT→TAVERN→RUNNING.NODE_SELECT→RUNNING.NODE_EXECUTE→TURN_ADVANCE→FINAL_BATTLE→SETTLEMENT），固定节点（第 5/15/25 回救援，第 10/20 回 PVP，第 30 回终局战） |
| 2 | `scripts/systems/node_resolver.gd` | 节点分发：根据 node_type 分发到子系统，执行完毕后返回 NodeResult |
| 3 | `scripts/systems/training_system.gd` | 锻炼系统：单次锻炼属性增加 = 基础值 + 熟练度加成(stage 1-4) + 伙伴支援加成。边际递减：单项>60%总投入后收益-20%。副属性共享 50%熟练度计数 |
| 4 | `scripts/systems/shop_system.gd` | 商店系统：主角升级(属性+3)/伙伴升级(支援/援助加成提升)，价格递增曲线从 `shop_configs.json` 读取 |
| 5 | `scripts/systems/rescue_system.gd` | 救援系统：第 5/15/25 回合生成 3 个候选伙伴（半随机，优先补全缺失定位），选择后入队 slot=position(2/3/4) |
| 6 | `scripts/systems/node_pool_system.gd` | 节点池生成：按阶段（前期 1-9/中期 10-19/后期 20-29）从 `node_pool_configs.json` 读取权重，抽 3 个选项，保底机制（连续 3 回合无战斗则强制出现战斗节点） |
| 7 | `scripts/systems/settlement_system.gd` | 终局结算：从 GameState 提取数据生成 FighterArchive，评分 5 项权重（终局战 40%/养成效率 20%/PVP 20%/流派纯度 10%/连锁展示 10%），评级 S≥90/A≥75/B≥60/C≥40/D<40 |
| 8 | `scripts/systems/elite_battle_system.gd` | 精英战：调用 BattleEngine，胜利后 3 选 1 奖励，失败 = 本局结束（run_status=LOSE） |
| 9 | `scripts/systems/character_manager.gd` | 角色管理：主角/伙伴属性计算（base + 锻炼 + 伙伴支援 + 熟练度），Buff 添加/移除，属性变化发射 `stats_changed` |

### 核心规则

| 规则 | 来源 |
|:---|:---|
| 熟练度阶段：1=生疏(0 次/+0)，2=熟悉(1-3 次/+2)，3=精通(4-6 次/+4)，4=专精(≥7 次/+5) | 规格书 4.5 节 |
| 边际递减：单项锻炼次数>总投入 60% 后，该属性后续收益×0.8 | 规格书 4.5 节 |
| 副属性共享：体魄↔精神/力量↔技巧/敏捷↔力量/技巧↔敏捷/精神↔体魄（+50%熟练度计数） | 规格书 4.5 节 |
| 固定节点：第 5/15/25 回=救援，第 10/20 回=PVP，第 30 回=终局战 | 规格书 4.2 节 |
| 队伍结构：1 主角 + 2 同行（酒馆选）+ 3 救援（第 5/15/25 回）= 最多 6 人 | 规格书 4.4 节 |

### 验收标准

- [ ] 测试场景 `test_run_loop.tscn`：手动推进 30 回合，每回合显示节点选项，固定节点正确触发
- [ ] 锻炼 10 次同属性，熟练度阶段正确晋升，边际递减在第 7 次后生效（假设总投入 10 次，单项 7 次>60%）
- [ ] 商店连续升级 5 次，价格正确递增，属性正确提升
- [ ] 救援生成 10 次，候选不重复，优先补全缺失定位
- [ ] 终局结算从预设 GameState 输出正确评分和评级
- [ ] 存档/读档测试：回合推进后存档 → 关闭游戏 → 读档 → 继续同一回合

---

## 任务 6：PVP 系统（Phase 1 占位）

**优先级**：第二波（依赖任务 2，可与任务 4/5 并行）  
**输入**：`05_run_loop_design.md`（5.3 节 PVP 检定）、`02_interface_contracts.md`（R19-R21）  
**交付目录**：`res://scripts/systems/`

### 交付物

| # | 文件 | 说明 |
|:---:|:---|:---|
| 1 | `scripts/systems/pvp_director.gd` | Phase 1 占位实现：第 10/20 回合被调用时，直接返回 `PvpResult{won: true, opponent_name: "AI_OPPONENT", rating_change: 0, penalty_tier: "none"}`，发射 `pvp_result` 信号。不执行真实战斗 |

### 验收标准

- [ ] 第 10/20 回合 PVP 节点不报错，不阻塞流程
- [ ] 发射 `pvp_result` 信号，携带正确参数

---

## 任务 7：整合贯通 + 全流程测试

**优先级**：第三波（依赖任务 1+2+3+4+5+6 全部完成）  
**输入**：全部设计文档  
**交付目录**：`res://` 根目录整合

### 交付物

| # | 说明 |
|:---:|:---|
| 1 | 全局信号连接：所有 UI 场景订阅 EventBus 信号并刷新显示 |
| 2 | 主菜单 → 主角选择 → 酒馆 → 养成主界面 流程贯通 |
| 3 | 养成主界面 HUD 实时更新：回合/金币/生命/五维/伙伴状态 |
| 4 | 节点选择 → 节点执行 → 回合推进 闭环 |
| 5 | 战斗界面调用 BattleEngine，显示简化战斗过程（色块 + 血条 + 日志） |
| 6 | 终局结算界面显示评分和斗士档案 |
| 7 | `README.md`：项目结构说明 + 如何运行测试 |

### 验收标准（Phase 1 最终交付标准）

- [ ] **全流程无报错**：从主菜单开始新局 → 选主角 → 酒馆选 2 伙伴 → 完成 30 回合 → 终局战 → 结算 → 返回主菜单
- [ ] **关键机制验证**：至少触发 1 次必杀技、1 次连锁、1 次伙伴援助、1 次救援、1 次精英战
- [ ] **存档验证**：中途退出后可继续
- [ ] **评分验证**：终局结算输出 S/A/B/C/D 评级之一
- [ ] **MVP 范围合规**：无术士主角、无后 6 伙伴、无装备系统、无真实 PVP、无档案查看界面、无动画特效音效

---

## 全局编码禁令（所有任务必须遵守）

1. **语言**：只写 GDScript，不碰 C#
2. **装备系统**：代码中不出现任何 equipment/equip/gear 相关逻辑或字段
3. **等级系统**：主角无 level/xp，属性纯由锻炼+伙伴+熟练度决定
4. **编码**：五属性 stage 统一 1-4，禁止用 0
5. **命名**：全部 `snake_case`（文件/函数/变量），类名 `PascalCase`，常量 `UPPER_SNAKE_CASE`
6. **信号**：全部走 EventBus，模块间禁止直接反向依赖
7. **占位美术**：ColorRect + Label 即可，禁止花时间做动画/粒子/音效
8. **PVP**：Phase 1 直接 return success，不做真实匹配和战斗
