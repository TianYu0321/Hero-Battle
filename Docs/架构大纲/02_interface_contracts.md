# 接口契约与信号总线设计文档

> **文档版本**: Phase 1 MVP（已与基准规格书v1.0对齐）  
> **适用范围**: "赛马娘版Q宠大乐斗" Roguelike回合制养成游戏  
> **设计约束**: 所有信号snake_case命名，模块间禁止双向直接调用（EventBus除外），不确定内容标注[待确认]  
> **依赖文档**: 01_module_breakdown.md（已对齐）, 04_battle_engine_design.md（已对齐）, 05_run_loop_design.md（已对齐）  
> **对齐标注**: `[已对齐: 规格书X.X节]` 表示该条目已与基准规格书确认

---

## 目录

1. [设计原则与约定](#1-设计原则与约定)
2. [EventBus信号清单](#2-eventbus信号清单)
3. [模块间函数调用契约](#3-模块间函数调用契约)
4. [单局运行时数据流图](#4-单局运行时数据流图)
5. [信号发射时序图](#5-信号发射时序图)
6. [接口完整性验证矩阵](#6-接口完整性验证矩阵)
7. [附录](#7-附录)

---

## 1. 设计原则与约定

### 1.1 信号命名规范

| 规则 | 示例 | 说明 |
|------|------|------|
| 全部小写+下划线 | `turn_started`, `unit_damaged` | snake_case |
| 使用动词过去式表示事件已发生 | `battle_started`, `reward_granted` | 表示动作已完成 |
| 使用动词现在式表示请求 | `new_game_requested` | UI层发出的操作请求 |
| 使用`_changed`后缀表示状态变更 | `gold_changed`, `stats_changed` | 携带新旧值 |

### 1.2 参数类型约定

| 类型标识 | 对应GDScript类型 | 说明 |
|----------|-----------------|------|
| `int` | `int` | 整数（回合数、数量等） |
| `float` | `float` | 浮点数（伤害值、百分比等） |
| `String` | `String` | 字符串（ID、类型标识等） |
| `bool` | `bool` | 布尔值 |
| `Dictionary` | `Dictionary` | 字典/对象（复合数据结构） |
| `Array` | `Array` | 数组（列表数据） |
| `UnitRef` | `Object` | 单位引用（战斗中单位对象的弱引用） |
| `DamagePacket` | `Dictionary` | 伤害数据包 `{attacker_id, defender_id, value, type, is_crit, is_miss, skill_id}` [已对齐: 规格书4.3节] |
| `FighterArchive` | `Dictionary` | 斗士档案完整数据结构，见05_run_loop_design.md 6.2节 [已对齐: 规格书4.6节] |
| `HeroClass` | `String` | 主角职业枚举 `"brave"` / `"shadow_dancer"` / `"iron_guard"` [已对齐: 规格书4.7节] |
| `AttributeCode` | `int` | 五属性编码 1体魄/2力量/3敏捷/4技巧/5精神 [已对齐: 规格书3.3节] |

### 1.3 通信分层规则

```
UI层 ──EventBus信号──> 功能层通知
     <──直接函数调用── 功能层操作入口

功能层 ──EventBus信号──> UI层刷新通知
      ──直接函数调用──> 数据层查询
      ──直接函数调用──> 引擎层服务

数据层 ──EventBus信号──> 存档状态通知
      <──直接函数调用── 功能层/UI层

引擎层 ──EventBus信号──> 全局事件广播（EventBus自身就是引擎层）
```

### 1.4 双向调用禁止规则

```
允许的方向:
  UI层 → 功能层 (直接函数调用)
  功能层 → 数据层 (直接函数调用)
  功能层 → 引擎层 (直接函数调用)
  任意模块 → EventBus (emit信号)
  EventBus → 任意模块 (信号投递)

禁止的方向:
  功能层 → UI层 (禁止直接引用UI节点)
  数据层 → 功能层 (数据层不感知上层)
  引擎层 → 功能层 (引擎层不包含游戏逻辑)
```

**核心原则** [已对齐: 规格书2.3节]: 上层模块可调用下层模块，下层模块不可反向依赖。模块间通过 EventBus 发送事件解耦。

---

## 2. EventBus信号清单

### 2.1 养成循环信号（Run & Node Lifecycle）

#### 2.1.1 局生命周期

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| R01 | `run_started` | RunController | MenuUI, RunHUD, UIManager | `(run_config: Dictionary)` — 含`{hero_id: String, partner_ids: Array[String], run_seed: int}`，其中hero_id ∈ {"hero_warrior", "hero_shadow_dancer", "hero_iron_guard"} [已对齐: 规格书4.7节] | 玩家在酒馆确认出发后，RunController初始化完毕 |
| R02 | `run_ended` | RunController | MenuUI, RunHUD, UIManager | `(ending_type: String, final_score: int, archive: FighterArchive)` — ending_type ∈ {"victory", "defeat", "abandon"} [已对齐: 规格书4.2节] | 终局战完成或玩家放弃本局，斗士档案生成后 |
| R03 | `scene_state_changed` | GameManager [原SceneManager] | UIManager, MenuUI, RunHUD, BattleUI | `(from_state: String, to_state: String, transition_data: Dictionary)` — 状态 ∈ {"HERO_SELECT", "TAVERN", "RUNNING", "FINAL_BATTLE", "SETTLEMENT", "RANKING"} [已对齐: 规格书2.2节] | GameManager主场景状态机发生转移时 |
| R04 | `game_paused` | UIManager | RunController, BattleEngine, RunHUD, BattleUI | `(reason: String)` — 暂停原因 | 玩家按下暂停键或系统需要暂停时 |
| R05 | `game_resumed` | UIManager | RunController, BattleEngine, RunHUD, BattleUI | `()` | 从暂停状态恢复时 |

#### 2.1.2 回合推进

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| R06 | `round_changed` | RunController | RunHUD | `(current_round: int, max_round: int, phase: String)` — max_round=30，phase ∈ {"EARLY", "MID", "LATE", "FINAL"}，阶段划分：1-9前期/10-19中期/20-29后期/30终局 [已对齐: 规格书4.2节] | 回合计数器更新后（包括初始第1回合） |
| R07 | `node_options_presented` | RunController | RunHUD | `(node_options: Array[Dictionary])` — 3个选项，每项含`{node_type: String, node_id: String, display_name: String, description: String, rewards_hint: String}`，node_type ∈ {"TRAIN", "BATTLE", "ELITE", "SHOP", "RESCUE", "PVP", "FINAL"} [已对齐: 规格书4.2节] | 每回合进入NODE_SELECT状态，选项生成完毕后 |
| R08 | `node_entered` | NodeResolver | RunHUD, BattleUI | `(node_type: String, node_config: Dictionary)` — node_type ∈ {"TRAIN", "BATTLE", "ELITE", "SHOP", "RESCUE", "PVP", "FINAL"}，node_config含难度缩放和奖励配置 [已对齐: 规格书4.2节] | 玩家选择节点后，NodeResolver开始执行时 |
| R09 | `node_resolved` | NodeResolver | RunController, RunHUD | `(node_type: String, result_data: Dictionary)` — 含`{success: bool, rewards: Array, logs: Array, combat_result: Dictionary|null}` [已对齐: 规格书4.2节] | 节点逻辑完全执行完毕，结果已确定时 |
| R10 | `turn_advanced` | RunController | RunHUD | `(new_turn: int, phase: String, is_fixed_node: bool)` — is_fixed_node表示本回合是否为固定节点（第5/10/15/20/25/30回合） [已对齐: 规格书4.2节] | 回合推进完成，准备进入下一回合节点选择 |

#### 2.1.3 锻炼系统

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| R11 | `training_completed` | RewardSystem | RunHUD | `(attr_code: int, attr_name: String, gain_value: int, new_total: int, proficiency_stage: String, bonus_applied: int)` — attr_code ∈ {1,2,3,4,5}对应体魄/力量/敏捷/技巧/精神，stage ∈ {"NOVICE", "FAMILIAR", "PROFICIENT", "MASTER"}，bonus_applied为熟练度加成值(+0/+2/+4/+5) [已对齐: 规格书3.3节/4.5节] | 锻炼节点结算完成，属性已更新 |
| R12 | `proficiency_stage_changed` | CharacterManager | RunHUD | `(attr_code: int, attr_name: String, new_stage: String, train_count: int)` — 同上编码 [已对齐: 规格书4.5节] | 某属性的熟练度阶段发生提升时 |

#### 2.1.4 商店系统

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| R13 | `shop_entered` | NodeResolver | RunHUD | `(shop_inventory: Array[Dictionary])` — 商品列表，每项含`{item_id: String, item_type: String, name: String, price: int, effect_desc: String, can_afford: bool, target_id: String}`，item_type ∈ {"hero_upgrade", "partner_upgrade"} [已对齐: 规格书4.2节] | 进入商店节点，商品生成完毕后 |
| R14 | `shop_item_purchased` | RewardSystem | RunHUD | `(item_id: String, item_type: String, target_id: String, price: int, remaining_gold: int, new_level: int)` — target_id为被升级的主角或伙伴ID [已对齐: 规格书4.2节] | 玩家成功购买商品后，金币已扣除 |
| R15 | `shop_exited` | NodeResolver | RunHUD | `(purchased_count: int, total_spent: int)` | 离开商店节点时 |
| R16 | `gold_changed` | RewardSystem | RunHUD | `(new_amount: int, delta: int, reason: String)` — delta正为获得负为消耗，reason说明来源 [已对齐: 规格书4.2节] | 金币数量发生任何变更时 |

#### 2.1.5 救援系统

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| R17 | `rescue_encountered` | NodeResolver | RunHUD | `(candidates: Array[Dictionary], rescue_turn: int)` — 3个候选伙伴，每项含`{partner_id: String, name: String, role: String, attr_focus: String, assist_type: String}`，rescue_turn ∈ {5, 15, 25} [已对齐: 规格书4.2节/4.4节] | 第5/15/25回合救援节点触发 |
| R18 | `partner_unlocked` | CharacterManager | RunHUD | `(partner_id: String, partner_name: String, slot: int, join_turn: int, role: String)` — slot ∈ {1,2,3,4,5}对应5名援助伙伴位 [已对齐: 规格书4.4节] | 新伙伴加入队伍（救援选择后或酒馆出发时） |

#### 2.1.6 PVP系统

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| R19 | `pvp_match_found` | PvpDirector | RunHUD | `(opponent_data: Dictionary)` — 含`{opponent_name: String, opponent_hero_class: String, estimated_strength: int, pvp_node_turn: int}`，pvp_node_turn ∈ {10, 20} [已对齐: 规格书4.2节/1.3节] | Phase 2+模拟匹配完成，对手数据构建完毕。Phase 1不触发此信号 |
| R20 | `pvp_battle_started` | PvpDirector | BattleUI | `(allies: Array, enemies: Array, playback_mode: String)` — playback_mode="standard"，敌人方为AI对手队伍 [已对齐: 规格书4.3节] | PVP检定进入战斗阶段（第10/20回合固定触发） |
| R21 | `pvp_result` | PvpDirector | RunHUD | `(result: Dictionary)` — 含`{won: bool, pvp_turn: int, rating_change: int, opponent_name: String, combat_log_summary: Array, penalty_tier: String}`，penalty_tier描述失败惩罚档位 [已对齐: 规格书5.3节] | PVP检定完全结束（含战斗和评分） |

### 2.2 战斗信号（Battle Lifecycle）

#### 2.2.1 战斗生命周期

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B01 | `battle_started` | BattleEngine | BattleUI | `(allies: Array[UnitSnapshot], enemies: Array[UnitSnapshot], battle_config: Dictionary)` — UnitSnapshot含`{unit_id, name, max_hp, current_hp, level, unit_type}`，battle_config含`{node_type: String, turn_number: int, playback_mode: String}`，playback_mode ∈ {"fast_forward", "standard", "standard_with_log"} [已对齐: 规格书4.3节] | 战斗初始化完成，双方数据加载完毕，即将进入ROUND_START |
| B02 | `battle_ended` | BattleEngine | BattleUI, NodeResolver | `(battle_result: Dictionary)` — 含`{winner: String("player"|"enemy"), turns_elapsed: int, mvp_partner: String, combat_log: Array, drop_rewards: Array, chain_stats: Dictionary, ultimate_triggered: bool}` [已对齐: 规格书4.3节] | 战斗结束条件满足（一方生命归零或达20回合上限），结算完成后 |
| B03 | `battle_state_changed` | BattleEngine | BattleUI | `(new_state: String, prev_state: String)` — 状态 ∈ {"INIT", "ROUND_START", "ACTION_ORDER", "HERO_ACTION", "PARTNER_ASSIST", "CHAIN_CHECK", "CHAIN_RESOLVE", "STATUS_TICK", "ULTIMATE_CHECK", "ROUND_END", "BATTLE_END"} [已对齐: 规格书4.3节] | 战斗状态机每次发生转移时 |

#### 2.2.2 回合与行动顺序

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B04 | `battle_turn_started` | BattleEngine | BattleUI | `(turn_number: int, round_effects: Array, playback_mode: String)` — round_effects为本回合自动效果列表（如牧师被动回复），playback_mode用于控制展示速度 [已对齐: 规格书4.3节] | 每回合ROUND_START状态处理完成（最多20回合） |
| B05 | `action_order_calculated` | BattleEngine | BattleUI | `(action_sequence: Array[Dictionary])` — 按行动顺序排列的单位列表，每项含`{unit_id, name, effective_speed, unit_type, base_agility}`，有效速度 = (敏捷+Buff加成) × 随机波动(0.9-1.1) [已对齐: 规格书4.3节] | ACTION_ORDER状态排序完成后 |
| B06 | `battle_turn_ended` | BattleEngine | BattleUI | `(turn_number: int, turn_chain_count: int, chain_total: int)` — turn_chain_count为本回合连锁段数(0-4)，chain_total为整场连锁累计 [已对齐: 规格书4.4节] | ROUND_END状态处理完成 |
| B07 | `unit_turn_started` | BattleEngine | BattleUI | `(unit_id: String, unit_name: String, is_player_controlled: bool, unit_type: String)` | 行动序列中轮到某个单位时 |

#### 2.2.3 行动执行与伤害

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B08 | `action_executed` | BattleEngine | BattleUI | `(action_data: Dictionary)` — 含`{actor_id, actor_name, action_type, skill_id, target_id, target_name, result_summary: Dictionary, damage_type: String}`，damage_type ∈ {"NORMAL", "SKILL", "COUNTER", "CHAIN", "ASSIST", "ULTIMATE", "DOT"} [已对齐: 规格书4.3节] | 任意单位完成一次行动（攻击/技能/防御等） |
| B09 | `unit_damaged` | BattleEngine | BattleUI | `(unit_id: String, amount: int, current_hp: int, max_hp: int, damage_type: String, is_crit: bool, is_miss: bool, attacker_id: String)` — damage_type同上 [已对齐: 规格书4.3节] | 单位HP因伤害减少时（包括MISS时amount=0） |
| B10 | `unit_healed` | BattleEngine | BattleUI | `(unit_id: String, amount: int, current_hp: int, max_hp: int, heal_type: String)` — heal_type ∈ {"SKILL", "HOT", "PASSIVE"} [已对齐: 规格书4.3节] | 单位HP因治疗增加时（如牧师被动每回合+5%最大生命） |
| B11 | `unit_died` | BattleEngine | BattleUI | `(unit_id: String, unit_name: String, unit_type: String, killer_id: String)` | 单位HP降至0时 |
| B12 | `damage_number_spawned` | BattleEngine | BattleUI | `(position: Dictionary{x,y}, amount: int, damage_type: String, is_crit: bool, is_miss: bool, chain_count: int)` — chain_count=0表示非连锁，1-4表示连锁段数 [已对齐: 规格书4.4节] | 需要在UI上显示伤害数字时；战斗为自动战斗，位置由BattleUI根据攻击方/受击方单位位置自动计算 [已对齐: 规格书4.3节: 所有战斗为自动战斗，规格书未明确是否由BattleUI自行计算位置，保留[待确认: 规格书未明确]] |

#### 2.2.4 伙伴援助

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B13 | `partner_assist_triggered` | BattleEngine | BattleUI | `(partner_id: String, partner_name: String, trigger_type: String, assist_result: Dictionary, assist_count_this_battle: int)` — trigger_type ∈ {"AFTER_HERO_ATTACK", "ON_CRIT", "ON_HERO_HIT", "HP_CRITICAL", "TURN_FIXED", "PASSIVE", "ON_DODGE"} 对应6种触发类型 [已对齐: 规格书4.4节]，assist_count_this_battle ∈ [0,2]为该伙伴本场累计援助次数（上限2次） [已对齐: 规格书4.4节] | 伙伴援助条件满足且行动执行后 |
| B14 | `partner_assist_skipped` | BattleEngine | BattleUI | `(reason: String, checked_count: int)` — reason如"no_trigger_met", "partner_limit_reached"（该伙伴已达2次上限）, "partner_dead"，checked_count为本次判定遍历的伙伴数(固定5名) [已对齐: 规格书4.3节/4.4节] | 本轮援助判定无伙伴满足条件时 |

#### 2.2.5 连锁系统

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B15 | `chain_triggered` | BattleEngine | BattleUI | `(chain_count: int, partner_id: String, partner_name: String, damage: int, chain_multiplier: float, total_chains_this_battle: int)` — chain_count ∈ [1,4]，最大4段 [已对齐: 规格书4.4节] | 连锁条件满足，CHAIN_RESOLVE执行时 |
| B16 | `chain_ended` | BattleEngine | BattleUI | `(total_chains_this_turn: int, total_chains_this_battle: int, interrupt_reason: String)` — interrupt_reason如"limit_reached"（达到4段上限）, "target_died", "no_valid_partner", "all_partners_at_limit"（所有伙伴均达2次上限）[已对齐: 规格书4.4节] | 本回合连锁全部结束（CHAIN_CHECK→STATUS_TICK）时 |
| B17 | `chain_interrupted` | BattleEngine | BattleUI | `(reason: String, current_chain_count: int, partner_limit_status: Dictionary)` — partner_limit_status记录各伙伴当前连锁次数 [已对齐: 规格书4.4节] | 连锁在达到上限前中断时 |

#### 2.2.6 必杀技

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B18 | `ultimate_triggered` | BattleEngine | BattleUI | `(hero_class: HeroClass, hero_name: String, trigger_turn: int, trigger_condition: String, ultimate_name: String)` — hero_class ∈ {"brave", "shadow_dancer", "iron_guard"}，brave触发条件="enemy_hp_below_40%"，shadow_dancer="turn_8"，iron_guard="self_hp_below_50%" [已对齐: 规格书4.7节] | ULTIMATE_CHECK判定条件满足，必杀技准备发动（每场限1次） |
| B19 | `ultimate_executed` | BattleEngine | BattleUI | `(hero_class: HeroClass, ultimate_name: String, execution_log: Array[Dictionary])` — 按时间顺序的必杀技效果日志。brave: "终结一击"(300%攻击力/无视30%防御)；shadow_dancer: "风暴乱舞"(6段/每段40%/伙伴概率×1.5)；iron_guard: "不动如山"(3回合/减伤40%/反击100%/眩晕25%) [已对齐: 规格书4.7节] | 必杀技所有效果执行完成后 |
| B20 | `ultimate_condition_checked` | BattleEngine | BattleUI [调试] | `(hero_class: HeroClass, condition_results: Dictionary, was_triggered: bool, already_used: bool)` — already_used标记本场是否已使用过必杀技 [已对齐: 规格书4.3节] | 每次ULTIMATE_CHECK判定完成后 [待确认: 规格书未明确是否需要在正式版本中保留调试信号，建议Phase 1保留用于验证] |

#### 2.2.7 状态效果（Buff/Debuff/DOT/HOT）

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| B21 | `buff_applied` | BattleEngine | BattleUI | `(unit_id: String, buff_id: String, buff_name: String, duration: int, effect_desc: String, buff_type: String)` — buff_type ∈ {"BUFF", "DEBUFF", "SHIELD", "HOT", "DOT"} [已对齐: 规格书4.3节] | 任意单位获得Buff/Debuff时 |
| B22 | `buff_removed` | BattleEngine | BattleUI | `(unit_id: String, buff_id: String, buff_name: String, reason: String)` — reason如"expired", "dispelled", "overridden" [已对齐: 规格书4.3节] | Buff/Debuff到期或被清除时 |
| B23 | `status_ticked` | BattleEngine | BattleUI | `(unit_id: String, tick_type: String, value: int, remaining_duration: int)` — tick_type ∈ {"DOT", "HOT"} [已对齐: 规格书4.3节] | STATUS_TICK中DOT/HOT结算时 |
| B24 | `enemy_action_decided` | EnemyDirector | BattleUI | `(enemy_id: String, enemy_name: String, action_type: String, target_id: String, target_name: String, skill_name: String, enemy_template: String)` — action_type ∈ {"attack", "skill", "charge", "defend", "heal_self", "double_attack", "assist_attack"}，enemy_template为5种精英模板ID [已对齐: 规格书5.2节] | 敌人AI完成行动决策时 |

### 2.3 角色管理信号（Character & Stats）

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| C01 | `stats_changed` | CharacterManager | RunHUD, BattleUI | `(unit_id: String, stat_changes: Dictionary)` — key为属性编码(1-5)或属性名，value为`{old: int, new: int, delta: int, attr_code: int}` [已对齐: 规格书3.3节] | 任意单位的五维战斗属性发生变化时 |
| C02 | `hero_level_changed` | CharacterManager | RunHUD | `(new_level: int, old_level: int, upgrade_source: String, hero_id: String)` — source如"shop", "event" [已对齐: 规格书4.2节] | 主角等级提升时 |
| C03 | `partner_evolved` | CharacterManager | RunHUD, BattleUI | `(partner_id: String, partner_name: String, new_level: int, unlocked_skill: String, evolution_tier: String)` — level=3时触发质变（12名伙伴各Lv3质变已定稿），evolution_tier ∈ {"LV3_QUALITATIVE", "LV5_NUMERIC"} [已对齐: 规格书4.8节/1.3节决策#6] | 伙伴等级达到质变点时 |
| C04 | `skill_learned` | CharacterManager | RunHUD, BattleUI | `(unit_id: String, skill_id: String, skill_name: String, skill_type: String)` — skill_type ∈ {"NORMAL", "ULTIMATE", "PASSIVE"} [已对齐: 规格书4.7节] | 单位学会新技能时 |
| C05 | `skill_triggered` | BattleEngine | BattleUI | `(unit_id: String, skill_id: String, skill_name: String, trigger_context: Dictionary)` — trigger_context含触发条件和伤害数据包 [已对齐: 规格书4.7节] | 战斗中技能发动时 |
| C06 | `equipment_changed` | CharacterManager | RunHUD [待确认: Phase 1是否含装备系统] | `(unit_id: String, slot: String, new_item: String, old_item: String)` | 装备变更时 [待确认: 规格书未明确Phase 1是否包含装备系统] |

### 2.4 UI控制信号

#### 2.4.1 UI面板管理

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| U01 | `panel_opened` | UIManager | 目标面板模块 | `(panel_name: String, panel_data: Dictionary)` | UIManager完成面板实例化并准备显示。UIManager为普通节点（非AutoLoad），由GameManager管理 [已对齐: 规格书2.2节] |
| U02 | `panel_closed` | UIManager | 目标面板模块 | `(panel_name: String, close_reason: String)` — reason如"user", "system", "scene_change" [已对齐: 规格书2.2节] | 面板关闭动画完成后 |
| U03 | `panel_stack_changed` | UIManager | RunHUD, BattleUI | `(stack: Array[String], top_panel: String)` [已对齐: 规格书2.2节] | UI面板堆栈发生变化时 |
| U04 | `all_panels_closed` | UIManager | 全局 | `(trigger: String)` [已对齐: 规格书2.2节] | 场景切换前UIManager清空所有面板 |

#### 2.4.2 界面交互信号（UI层 → 功能层）

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| U05 | `new_game_requested` | MenuUI | RunController | `(hero_id: String)` — hero_id ∈ {"hero_warrior", "hero_shadow_dancer", "hero_iron_guard"} [已对齐: 规格书4.7节] | 玩家在主角选择界面确认选择 |
| U06 | `continue_game_requested` | MenuUI | RunController | `()` | 玩家点击继续游戏 |
| U07 | `archive_view_requested` | MenuUI | MenuUI(内部) | `(archive_id: String)` | 玩家请求查看某个斗士档案 |
| U08 | `node_selected` | RunHUD | RunController | `(node_index: int)` — 0/1/2对应三选一 [已对齐: 规格书4.2节] | 玩家在节点选择面板点击某个选项 |
| U09 | `rescue_partner_selected` | RunHUD | NodeResolver | `(candidate_index: int, partner_id: String)` [已对齐: 规格书4.4节] | 玩家在救援界面选择伙伴 |
| U10 | `shop_purchase_requested` | RunHUD | RewardSystem | `(item_index: int, item_id: String, target_id: String)` [已对齐: 规格书4.2节] | 玩家在商店界面选择购买 |
| U11 | `shop_exit_requested` | RunHUD | NodeResolver | `()` | 玩家选择离开商店 |
| U12 | `tavern_confirmed` | MenuUI | RunController | `(selected_partner_ids: Array[String])` — 长度为2，从默认解锁的6名伙伴中选择 [已对齐: 规格书4.2节/4.4节] | 玩家在酒馆选择2名首发伙伴并确认 |
| U13 | `player_action_selected` | BattleUI | BattleEngine | `(action_type: String, target_id: String, skill_id: String)` — action_type ∈ {"attack", "skill", "defend", "item"} [已对齐: 规格书4.3节: 所有战斗为自动战斗，此接口Phase 1不调用，预留Phase 2+] | 规格书4.3节定义所有战斗为自动战斗，玩家不选择行动；本信号预留Phase 2+手动战斗模式 [已对齐: 规格书4.3节] |
| U14 | `battle_speed_changed` | BattleUI | BattleUI(内部) | `(speed: float)` — speed ∈ {0.5, 1.0, 2.0, 3.0} [已对齐: 规格书4.3节] | 玩家调整战斗播放速度（普通战斗可快进） |
| U15 | `skip_animation_requested` | BattleUI | BattleUI(内部) | `()` [待确认: 规格书未明确是否支持跳过动画] | 玩家点击跳过当前动画 |
| U16 | `abandon_run_requested` | RunHUD | RunController | `()` [待确认: 规格书未明确放弃本局功能是否Phase 1包含] | 玩家请求放弃当前局 |

#### 2.4.3 HUD更新信号

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| U17 | `hud_stats_refresh` | RunController | RunHUD | `(hero_data: Dictionary, partners: Array[Dictionary], gold: int, current_turn: int, phase: String)` — hero_data含五维属性`{physique, strength, agility, technique, spirit}`、等级、技能等级 [已对齐: 规格书3.3节/4.6节] | 需要HUD全面刷新时（如读档后、场景切换后） |
| U18 | `hud_log_appended` | 多个模块 | RunHUD, BattleUI | `(message: String, log_type: String, timestamp: int)` — log_type ∈ {"system", "combat", "reward", "event", "error"} | 任何模块产生需要显示在日志面板的消息时 |
| U19 | `hud_partner_list_changed` | CharacterManager | RunHUD | `(partners: Array[Dictionary])` — 完整伙伴列表（含新加入的），每项含`{partner_id, name, slot, level, role, attr_focus}` [已对齐: 规格书4.4节] | 队伍成员发生变化时（1+2+3队伍结构） |

### 2.5 系统信号（存档/音频/错误/调试）

| # | 信号名 | 发射方 | 接收方 | 参数 | 触发时机 |
|---|--------|--------|--------|------|----------|
| S01 | `game_saved` | SaveManager [原SaveArchive] | RunHUD | `(save_slot: int, save_timestamp: int, turn: int, is_auto: bool)` [已对齐: 规格书2.2节] | 存档成功写入后 |
| S02 | `game_loaded` | SaveManager [原SaveArchive] | RunController | `(save_data: Dictionary)` — 完整存档数据，格式见05_run_loop_design.md 7.2节 [已对齐: 规格书2.2节] | 读档成功并反序列化后 |
| S03 | `save_failed` | SaveManager [原SaveArchive] | RunHUD, MenuUI | `(error_code: int, error_message: String, save_context: Dictionary)` [已对齐: 规格书2.2节] | 存档写入失败时 |
| S04 | `load_failed` | SaveManager [原SaveArchive] | MenuUI | `(error_code: int, error_message: String, save_slot: int)` [已对齐: 规格书2.2节] | 读档失败时 |
| S05 | `archive_generated` | RunController | MenuUI | `(archive: FighterArchive)` — 含完整斗士档案数据，is_fixed=true [已对齐: 规格书4.6节] | 终局结算斗士档案生成后 |
| S06 | `error_occurred` | 任意模块 | UIManager | `(error_code: String, error_message: String, source_module: String)` | 模块遇到不可恢复错误时 |
| S07 | `warning_issued` | 任意模块 | UIManager [调试] | `(warning_code: String, message: String, source_module: String)` [待确认: 规格书未明确调试信号] | 模块遇到可恢复警告时 |
| S08 | `audio_play_requested` | MenuUI/RunHUD/BattleUI/BattleEngine | AudioManager | `(audio_type: String, audio_name: String, volume: float)` — audio_type ∈ {"bgm", "sfx"}，audio_name为音频资源名 [已对齐: 规格书2.2节] | 需要播放音效或BGM时。**新增信号**，原设计遗漏AudioManager，现补齐 |

---

## 3. 模块间函数调用契约

### 3.1 调用契约说明格式

每条契约按以下格式描述：

```
调用方 → 被调用方
  函数名(参数: 类型, ...) → 返回值: 类型
  调用时机: ...
  错误处理: ...
```

### 3.2 UI层 → 功能层（玩家操作指令）

#### 3.2.1 MenuUI → RunController

```
MenuUI → RunController
  start_new_run(hero_id: String, starter_partner_ids: Array[String]) → void
  调用时机: 玩家在酒馆确认选择2名首发伙伴后
  参数约束:
    - hero_id ∈ {"hero_warrior", "hero_shadow_dancer", "hero_iron_guard"} [已对齐: 规格书4.7节]
    - starter_partner_ids 长度为2，从默认解锁的6名伙伴中选择 [已对齐: 规格书4.4节]
  错误处理: 
    - hero_id无效 → 抛异常 ERR_INVALID_HERO_ID
    - starter_partner_ids长度≠2 → 抛异常 ERR_INVALID_TEAM_COMP
    - 存在进行中的局 → 抛异常 ERR_RUN_IN_PROGRESS
  副作用: 创建RunController实例，初始化CharacterManager和NodeResolver子节点，
         发射信号run_started，GameManager触发场景切换至RUNNING [已对齐: 规格书2.2节]

MenuUI → RunController
  continue_run() → bool
  调用时机: 玩家在主菜单点击"继续游戏"
  错误处理: 
    - 无存档 → 返回false，MenuUI显示"无存档"提示
    - 存档损坏 → 抛异常 ERR_CORRUPT_SAVE，MenuUI显示错误弹窗
  返回值: 成功恢复返回true，失败返回false

MenuUI → RunController
  abandon_current_run() → void [待确认: 规格书未明确放弃本局功能是否Phase 1包含]
  调用时机: 玩家请求放弃当前进行中的局
  错误处理: 
    - 无进行中的局 → 静默返回（无操作）
  副作用: 销毁RunController及其子节点，发射run_ended(abandon, 0)
```

#### 3.2.2 RunHUD → RunController

```
RunHUD → RunController
  select_node(node_index: int) → void
  调用时机: 玩家在节点选择面板点击3选1中的某一项
  错误处理:
    - node_index不在[0,2]范围内 → 抛异常 ERR_INVALID_NODE_INDEX
    - 当前不在NODE_SELECT状态 → 静默返回（防重复点击）
  前置条件: RunController.current_state == NODE_SELECT
  副作用: RunController发射node_selected信号给NodeResolver，进入NODE_EXECUTE状态

RunHUD → RunController
  get_current_run_summary() → Dictionary
  调用时机: RunHUD需要全面刷新时（如读档后、场景切换后）
  错误处理: 无进行中的局 → 返回空字典
  返回值: {hero, partners, gold, current_turn, node_options, run_state, phase}
  说明: phase字段 ∈ {"EARLY", "MID", "LATE", "FINAL"} 对应前期(1-9)/中期(10-19)/后期(20-29)/终局(30) [已对齐: 规格书4.2节]
```

#### 3.2.3 BattleUI → BattleEngine

```
BattleUI → BattleEngine
  submit_player_action(action_type: String, target_id: String, skill_id: String) → bool
  调用时机: 规格书4.3节定义所有战斗为自动战斗，此接口Phase 1不被调用 [已对齐: 规格书4.3节]
  说明: 信号预留Phase 2+手动战斗模式。Phase 1所有战斗通过自动战斗逻辑执行
  错误处理:
    - 当前不是玩家回合 → 返回false
    - target_id对应的单位已死亡 → 返回false
    - skill_id不在可用技能列表 → 抛异常 ERR_INVALID_SKILL
  前置条件: BattleEngine.current_state == HERO_ACTION 且 轮到玩家控制单位
  返回值: 接受指令返回true，拒绝返回false

BattleUI → BattleEngine
  set_playback_speed(speed: float) → void
  调用时机: 玩家调整战斗播放速度
  参数约束: speed ∈ {0.5, 1.0, 2.0, 3.0} [已对齐: 规格书4.3节]
  错误处理: speed不在允许列表 → 静默使用最近的有效值
  副作用: 仅影响UI动画播放速度，不影响战斗逻辑

BattleUI → BattleEngine
  get_battle_snapshot() → Dictionary
  调用时机: BattleUI初始化时需要获取完整战斗状态
  返回值: 完整战斗状态快照，包括{allies, enemies, turn_number, state, action_sequence, buffs, chain_stats, ultimate_used, playback_mode}
```

### 3.3 功能层 → 数据层（配置查询）

#### 3.3.1 ConfigManager 查询接口（所有功能模块通用） [原GameData，已对齐: 规格书2.2节]

```
RunController/NodeResolver/BattleEngine/CharacterManager/RewardSystem/PvpDirector/EnemyDirector → ConfigManager [原GameData]
  get_hero_config(hero_id: String) → Dictionary | null
  调用时机: 新局开始时加载主角数据、战斗中查询主角属性模板
  参数约束: hero_id ∈ {"hero_warrior", "hero_shadow_dancer", "hero_iron_guard"} [已对齐: 规格书4.7节]
  错误处理: hero_id不存在 → 返回null
  返回值: 主角完整配置字典，含基础属性{physique, strength, agility, technique, spirit}、成长倾向、技能绑定 [已对齐: 规格书3.3节]

RunController/CharacterManager → ConfigManager [原GameData]
  get_partner_config(partner_id: String) → Dictionary | null
  调用时机: 伙伴入队时、战斗加载时、角色升级时
  错误处理: partner_id不存在 → 返回null
  返回值: 12名伙伴完整配置（含基础属性、援助触发条件、技能列表、Lv3质变效果）[已对齐: 规格书4.8节]

BattleEngine → ConfigManager [原GameData]
  get_skill_config(skill_id: String) → Dictionary | null
  调用时机: 战斗中使用技能时查询伤害倍率、效果参数
  错误处理: skill_id不存在 → 返回null（使用默认倍率1.0）
  返回值: 技能配置，含勇者{追击斩: 60%攻击/30%概率/上限50%, 终结一击: 300%攻击/无视30%防御/限1次}，影舞者{疾风连击: 2-4段/每段35%, 风暴乱舞: 第8回合/6段/每段40%/伙伴概率×1.5/限1次}，铁卫{铁壁反击: 25%/反弹50%/10%眩晕, 不动如山: 50%血/3回合/减伤40%/反击100%/眩晕25%/限1次} [已对齐: 规格书4.7节]

EnemyDirector → ConfigManager [原GameData]
  get_enemy_template(enemy_id: String) → Dictionary | null
  调用时机: 敌人生成时加载敌人属性模板
  错误处理: enemy_id不存在 → 返回null
  返回值: 5种精英敌人模板（重甲守卫/暗影刺客/元素法师/狂战士/混沌领主），含属性模板和特殊机制 [已对齐: 规格书5.2节]

RunController/NodeResolver → ConfigManager [原GameData]
  get_node_weights(phase: String) → Dictionary
  调用时机: 生成回合节点选项时
  参数: phase ∈ {"EARLY", "MID", "LATE"} 对应前期(1-9)/中期(10-19)/后期(20-29) [已对齐: 规格书4.2节]
  返回值: {TRAIN: int, BATTLE: int, ELITE: int, SHOP: int} 权重配置

RewardSystem → ConfigManager [原GameData]
  get_shop_price_config() → Dictionary
  调用时机: 生成商店商品价格时
  返回值: {base_hero_cost, linear_factor, growth_factor, base_partner_cost}，价格由ShopConfig配置表驱动 [已对齐: 规格书3.1节]

PvpDirector → ConfigManager [原GameData]
  get_pvp_opponent_pool(difficulty: String) → Array[Dictionary]
  调用时机: PVP节点触发时构建对手池（Phase 2+）
  参数: difficulty基于当前回合数动态确定（第10回=中等/第20回=困难）[已对齐: 规格书4.2节]
  返回值: 可用的AI对手列表 [已对齐: 规格书1.3节: Phase 1不做PVP，Phase 2本地AI对手池]
```

#### 3.3.2 SaveManager 存档接口 [原SaveArchive，已对齐: 规格书2.2节]

```
RunController → SaveManager [原SaveArchive]
  save_run_state(run_data: Dictionary, is_auto: bool) → bool
  调用时机: 
    - 每回合节点执行完毕后（auto_save=true）
    - 玩家手动触发存档时（auto_save=false）[待确认: 规格书未明确是否允许手动存档]
  参数: run_data为完整的局状态字典（见05_run_loop_design.md 7.2节）
  错误处理: 
    - IO错误 → 发射save_failed信号，返回false
    - 磁盘空间不足 → 发射save_failed信号，返回false
  返回值: 成功返回true，失败返回false
  说明: Phase 1-2纯本地JSON存档，Phase 3增加云端备份（Firebase）[已对齐: 规格书2.1节/1.3节]

MenuUI/RunController → SaveManager [原SaveArchive]
  load_latest_run() → Dictionary | null
  调用时机: 玩家点击"继续游戏"时
  错误处理:
    - 无存档 → 返回null
    - 存档损坏 → 抛异常 ERR_CORRUPT_SAVE
    - 版本不兼容 → 抛异常 ERR_VERSION_MISMATCH
  返回值: 完整存档数据字典，或null

RunController → SaveManager [原SaveArchive]
  generate_fighter_archive(run_result: Dictionary) → FighterArchive
  调用时机: 终局结算完成后
  参数: run_result含{hero, partners, training, economy, combat, score}
  返回值: FighterArchive对象（完整斗士档案），字段包括:
    - 主角数据: 五维属性/等级/技能等级/必杀技等级 [已对齐: 规格书4.6节]
    - 伙伴数据: 5名伙伴ID/等级/支援援助配置 [已对齐: 规格书4.6节]
    - 技能快照: 触发技能及触发次数 [已对齐: 规格书4.6节]
    - 养成统计: 锻炼次数/战斗次数/总伤害 [已对齐: 规格书4.6节]
    - 通关评价: 分数/评级(S/A/B/C/D) [已对齐: 规格书4.6节]
    - is_fixed: true（终局结算后固定化）[已对齐: 规格书4.6节]
  副作用: 自动写入存档目录
  不保存项（运行时临时数据，不进入档案）: 局内生命值/属性熟练度/局内金币/临时BUFF/DEBUFF [已对齐: 规格书4.6节]

MenuUI → SaveManager [原SaveArchive]
  load_archives(sort_by: String, limit: int) → Array[FighterArchive]
  调用时机: 玩家查看斗士档案列表/排行榜时
  参数: sort_by ∈ {"date", "score"}，limit最大100
  返回值: 斗士档案列表（仅is_fixed=true的条目）[已对齐: 规格书4.6节]

SaveManager → SaveManager(内部) [原SaveArchive]
  validate_save_integrity(save_data: Dictionary) → bool
  调用时机: 每次读档前自动调用
  返回值: 数据完整返回true，损坏返回false
```

### 3.4 功能层内部调用（核心逻辑链）

#### 3.4.1 RunController → NodeResolver

```
RunController → NodeResolver
  resolve_node(node_type: String, node_config: Dictionary) → NodeResult
  调用时机: 玩家选择节点后，RunController委托NodeResolver执行
  参数: 
    - node_type ∈ {"TRAIN", "BATTLE", "ELITE", "SHOP", "RESCUE", "PVP", "FINAL"} [已对齐: 规格书4.2节]
    - node_config: 节点配置参数（含难度缩放、奖励配置、当前回合数等）
  返回值: NodeResult = {success: bool, rewards: Array, combat_result: Dictionary|null, logs: Array}
  执行流程:
    1. NodeResolver发射node_entered信号
    2. 根据node_type分发到子系统
    3. 等待子系统完成（可能涉及异步战斗）
    4. 发射node_resolved信号
    5. 返回结果
  错误处理: 
    - 未知的node_type → 抛异常 ERR_UNKNOWN_NODE_TYPE
    - 子系统执行异常 → NodeResult.success=false，携带错误日志
```

#### 3.4.2 RunController → CharacterManager

```
RunController → CharacterManager
  initialize_hero(hero_id: String) → HeroInstance
  调用时机: 新局开始时（酒馆确认后）
  参数: hero_id ∈ {"hero_warrior", "hero_shadow_dancer", "hero_iron_guard"} [已对齐: 规格书4.7节]
  返回值: 主角运行时实例，含实时属性{physique, strength, agility, technique, spirit}（五维编码1-5）[已对齐: 规格书3.3节]
  初始属性 [已对齐: 规格书4.7节]:
    - 勇者: 体魄12/力量16/敏捷10/技巧12/精神8
    - 影舞者: 体魄10/力量10/敏捷16/技巧10/精神12
    - 铁卫: 体魄16/力量8/敏捷10/技巧10/精神14

RunController → CharacterManager
  initialize_partners(partner_ids: Array[String]) → Array[PartnerInstance]
  调用时机: 酒馆确认伙伴选择后
  参数: partner_ids长度为2（首发同行伙伴）[已对齐: 规格书4.4节]
  返回值: 伙伴运行时实例数组，队伍结构1+2+3（1主角+2同行+3救援）[已对齐: 规格书4.4节]

RunController/BattleEngine/RewardSystem → CharacterManager
  get_hero() → HeroInstance
  调用时机: 需要获取主角当前状态时
  返回值: 主角运行时实例引用

RunController/BattleEngine/RewardSystem → CharacterManager
  get_partners() → Array[PartnerInstance]
  调用时机: 需要获取伙伴列表时
  返回值: 所有伙伴（含未上阵的），最多5名援助伙伴 [已对齐: 规格书4.3节/4.4节]

RewardSystem → CharacterManager
  modify_hero_stats(stat_changes: Dictionary) → void
  调用时机: 锻炼结算、商店升级、战斗奖励等
  参数: stat_changes = {"physique": +3, "strength": +5, ...} 或 {1: +3, 2: +5, ...}（五维属性编码）[已对齐: 规格书3.3节]
  副作用: 更新主角属性，发射stats_changed信号

RewardSystem → CharacterManager
  add_partner(partner_id: String, slot: int) → void
  调用时机: 救援节点选择后
  参数: slot ∈ {3,4,5} 对应第5/15/25回合的救援伙伴位 [已对齐: 规格书4.2节/4.4节]
  副作用: 创建伙伴实例并分配slot，发射partner_unlocked信号

RewardSystem → CharacterManager
  upgrade_partner(partner_id: String) → void
  调用时机: 商店购买伙伴升级后
  副作用: 伙伴等级+1，如达到Lv3发射partner_evolved信号（Lv3质变，12名伙伴各质变已定稿）[已对齐: 规格书4.8节/1.3节决策#6]

BattleEngine → CharacterManager
  apply_buff(unit_id: String, buff_id: String, duration: int, value: float) → void
  调用时机: 战斗中需要添加Buff/Debuff时
  副作用: 向目标单位的buff列表添加条目，发射buff_applied信号

BattleEngine → CharacterManager
  remove_buff(unit_id: String, buff_id: String) → void
  调用时机: Buff到期或需要清除时
  副作用: 从目标单位移除buff，发射buff_removed信号

BattleEngine → CharacterManager
  get_unit_combat_stats(unit_id: String) → CombatStats
  调用时机: 伤害计算、行动排序时需要实时属性
  返回值: 经过Buff/装备加成后的实时战斗属性，五维属性编码1-5统一 [已对齐: 规格书3.3节]
```

#### 3.4.3 NodeResolver → BattleEngine

```
NodeResolver → BattleEngine
  execute_battle(battle_config: BattleConfig) → BattleResult
  调用时机: BATTLE/ELITE/FINAL/PVP类型节点执行时
  参数: 
    - BattleConfig = {
        node_type: String,        // "BATTLE"|"ELITE"|"FINAL"|"PVP"
        turn_number: int,         // 当前养成回合数（1~30），用于难度缩放 [已对齐: 规格书4.2节]
        enemy_template_ids: Array[String],  // 敌人模板ID列表（5种精英模板）[已对齐: 规格书5.2节]
        pvp_opponent: Dictionary|null,      // PVP对手数据（PVP类型时）[已对齐: 规格书1.3节]
        is_final_battle: bool,
        run_seed: int,            // 用于确定性RNG
        playback_mode: String     // "fast_forward"(普通战斗2-3秒) | "standard"(精英/PVP 15-25秒) | "standard_with_log"(终局战) [已对齐: 规格书4.3节]
      }
  返回值: BattleResult = {
        winner: String("player"|"enemy"),
        turns_elapsed: int,       // 实际消耗回合数(最多20回合) [已对齐: 规格书4.3节]
        units_state: Array,       // 战后各单位状态
        combat_log: Array,        // 完整战斗日志
        drop_rewards: Array,      // 掉落奖励
        mvp_partner: String|null, // MVP伙伴ID
        chain_stats: Dictionary,  // 连锁统计 {max_chain: int, total_chains: int}
        ultimate_triggered: bool  // 必杀技是否触发过（每场限1次）[已对齐: 规格书4.7节]
      }
  执行流程（8步战斗流程）[已对齐: 规格书4.3节]:
    1. NodeResolver实例化BattleEngine
    2. BattleEngine发射battle_started信号
    3. BattleEngine运行完整20回合战斗状态机:
       每回合执行: 行动顺序判定→主角普攻/技能→伙伴援助触发(遍历5名)→连锁检查(最多4段)→状态结算→必杀技检查(限1次)→回合结束判定
    4. BattleEngine发射battle_ended信号
    5. NodeResolver获取结果，销毁BattleEngine实例
    6. 返回BattleResult
  伤害公式（配置驱动）[已对齐: 规格书4.3节]:
    伤害 = 基础值 × 属性系数 × 技能倍率 × 随机波动(0.9-1.1)
    属性系数: 攻击方(力量×力量系数+技巧×技巧系数)，防御方(体魄×体魄系数)
    所有系数通过BattleFormulaConfig配置表驱动
  错误处理:
    - 战斗执行超时 → BattleResult.success=false [待确认: 规格书未明确超时机制]
    - 状态机死循环 → 被防死循环机制拦截（20回合上限/4段连锁上限/每伙伴2次上限），强制结束 [已对齐: 规格书4.3节/4.4节]
```

#### 3.4.4 NodeResolver → RewardSystem

```
NodeResolver → RewardSystem
  grant_training_reward(attr_code: int, proficiency_data: Dictionary) → TrainingResult
  调用时机: TRAIN类型节点执行时
  参数: attr_code ∈ {1,2,3,4,5}对应体魄/力量/敏捷/技巧/精神 [已对齐: 规格书3.3节]
  返回值: TrainingResult = {attr_code, attr_name, gain_value, new_total, stage, bonus_applied}
    熟练度阶段 [已对齐: 规格书4.5节]:
      NOVICE(0次/+0) → FAMILIAR(1-3次/+2) → PROFICIENT(4-6次/+4) → MASTER(≥7次/+5)
    边际递减 [已对齐: 规格书4.5节]: 单项属性锻炼次数超过总投入60%后，该属性后续基础收益递减20%
    副属性共享 [已对齐: 规格书4.5节]: 锻炼时副属性获得50%熟练度计数共享（体魄→精神/力量→技巧/敏捷→力量/技巧→敏捷/精神→体魄）

NodeResolver → RewardSystem
  generate_shop_inventory(turn: int, current_gold: int) → Array[ShopItem]
  调用时机: SHOP类型节点执行时
  返回值: 商品列表，含主角升级+伙伴升级选项，价格递增公式由ShopConfig配置表驱动 [已对齐: 规格书3.1节]

NodeResolver/RewardSystem(内部) → RewardSystem
  process_purchase(item_id: String, current_gold: int) → PurchaseResult
  调用时机: 玩家确认购买商店商品时
  返回值: PurchaseResult = {success: bool, new_gold: int, applied_effects: Array, error: String|null}

NodeResolver → RewardSystem
  grant_rescue_partner(partner_id: String, slot: int) → void
  调用时机: 救援节点选择后
  参数: slot ∈ {3,4,5} 对应第5/15/25回合的救援伙伴位 [已对齐: 规格书4.2节/4.4节]
  副作用: 调用CharacterManager.add_partner

NodeResolver → RewardSystem
  grant_battle_rewards(battle_result: BattleResult) → Array[Reward]
  调用时机: 战斗节点结束后
  返回值: 奖励列表（金币、属性提升等）
  说明: 普通战斗胜利获金币（基于难度和主角属性）；精英战胜利获稀有奖励3选1（强力BUFF/大量金币/稀有道具），失败=本局结束；PVP失败不淘汰但施加惩罚 [已对齐: 规格书5.1节/5.2节/5.3节]
```

#### 3.4.5 NodeResolver → PvpDirector

```
NodeResolver → PvpDirector
  execute_pvp(pvp_config: PvpConfig) → PvpResult
  调用时机: PVP类型节点执行时（第10/20回合）[已对齐: 规格书4.2节]
  参数:
    - PvpConfig = {
        turn_number: int,       // 10或20 [已对齐: 规格书4.2节]
        player_team: TeamSnapshot,
        run_seed: int
      }
  返回值: PvpResult = {
        won: bool,
        opponent_name: String,
        rating_change: int,
        combat_summary: Dictionary,
        penalty_tier: String    // 失败惩罚档位 [已对齐: 规格书5.3节]
      }
  执行流程:
    1. PvpDirector发射pvp_match_found
    2. PvpDirector通过ConfigManager获取AI对手配置（Phase 2+）[已对齐: 规格书1.3节]
    3. PvpDirector调用BattleEngine执行PVP战斗（标准播放模式15-25秒）[已对齐: 规格书4.3节]
    4. PvpDirector计算检定结果
    5. PvpDirector发射pvp_result
    6. 返回PvpResult
  说明: Phase 1不做PVP → Phase 2本地AI对手池 → Phase 3 BaaS(Firebase) [已对齐: 规格书1.3节]
```

#### 3.4.6 BattleEngine → EnemyDirector

```
BattleEngine → EnemyDirector
  spawn_enemies(node_type: String, turn: int, battle_seed: int) → Array[EnemyInstance]
  调用时机: 战斗INIT状态时需要生成敌人
  参数:
    - node_type: "BATTLE"|"ELITE"|"FINAL"
    - turn: 当前养成回合数（1~30）[已对齐: 规格书4.2节]
    - battle_seed: 确定性随机种子
  返回值: 敌人实例数组（已应用难度缩放）
  执行逻辑:
    1. 根据node_type选择敌人池
    2. 根据turn应用难度缩放公式（enemy_power = base_power × (1 + turn × scaling_factor)）[已对齐: 规格书4.2节]
    3. 根据node_type确定敌人数量
    4. 生成敌人实例并返回
  精英敌人模板（5种）[已对齐: 规格书5.2节]:
    - 重甲守卫(难度1/第3-8回): 体魄=主角力量×2.0/力量=主角力量×0.5/坚甲(伤害-25%)
    - 暗影刺客(难度2/第8-15回): 敏捷=主角敏捷×1.5/技巧=主角技巧×1.2/30%闪避普攻
    - 元素法师(难度3/第12-18回): 力量=主角力量×1.2/精神=主角精神×1.3/第3回合蓄力爆发(力量×2.5)
    - 狂战士(难度4/第15-22回): 体魄=主角力量×1.3/力量=主角力量×1.0/低于30%血狂暴(攻击×1.5/仅1次)
    - 混沌领主(难度5/第18-25回): 初始全属性=主角×0.7/每回合全属性+5%(最多+45%)
  错误处理: 敌人池为空 → 返回空数组，BattleEngine进入BATTLE_END

BattleEngine → EnemyDirector
  decide_enemy_action(enemy_instance: EnemyInstance, battle_state: BattleState) → EnemyAction
  调用时机: 轮到敌人单位行动时
  返回值: EnemyAction = {type, target_id, skill_id, priority}
  执行逻辑: 调用对应AI模板的decide_action方法
```

#### 3.4.7 PvpDirector → BattleEngine

```
PvpDirector → BattleEngine
  simulate_pvp_battle(ally_team: TeamSnapshot, opponent_team: TeamSnapshot, pvp_seed: int) → BattleResult
  调用时机: PvpDirector需要执行PVP战斗时（Phase 2+）
  参数:
    - ally_team: 玩家队伍快照（1主角+5伙伴）
    - opponent_team: AI对手队伍快照
    - pvp_seed: 确定性随机种子
  返回值: 标准BattleResult格式（20回合上限/8步流程/4段连锁上限）[已对齐: 规格书4.3节/4.4节]
  执行流程: 同普通战斗，但双方都可以是主角+伙伴配置
```

### 3.5 功能层 → 引擎层

```
RunController/BattleEngine/NodeResolver → GameManager [原SceneManager，已对齐: 规格书2.2节]
  change_scene(to_state: String, transition_type: String) → void
  调用时机: 需要切换主场景状态时
  参数:
    - to_state ∈ {"HERO_SELECT", "TAVERN", "RUNNING", "FINAL_BATTLE", "SETTLEMENT", "RANKING"} [已对齐: 规格书4.2节]
    - transition_type ∈ {"fade", "slide", "instant"} [待确认: Phase 1是否有过渡动画]
  副作用: GameManager发射scene_state_changed信号，执行场景切换
  说明: GameManager为5个AutoLoad单例之一，管理游戏状态机+场景切换 [已对齐: 规格书2.2节]

MenuUI/RunHUD/BattleUI → UIManager
  open_panel(panel_name: String, panel_data: Dictionary) → PanelInstance
  调用时机: 需要打开UI面板时
  参数: panel_name为面板预制体名称
  返回值: 面板实例引用
  副作用: UIManager维护面板堆栈，发射panel_opened信号
  说明: UIManager**不是**AutoLoad单例（规格书autoload清单中无此单例），作为普通节点由GameManager管理 [已对齐: 规格书2.2节]

MenuUI/RunHUD/BattleUI → UIManager
  close_panel(panel_name: String) → void
  调用时机: 需要关闭UI面板时
  副作用: 从堆栈移除面板，发射panel_closed信号

MenuUI/RunHUD/BattleUI → UIManager
  close_all_panels() → void
  调用时机: 场景切换前清空所有UI
  副作用: 发射all_panels_closed信号

# AudioManager音频接口 [已对齐: 规格书2.2节，原设计遗漏AudioManager，现补齐]
任意模块 → AudioManager
  play_bgm(track_name: String, fade_in: float) → void
  调用时机: 需要切换BGM时（场景切换/战斗开始等）
  说明: AudioManager为5个AutoLoad单例之一，负责全局音频播放、音量控制、音频资源预加载与释放 [已对齐: 规格书2.2节]

任意模块 → AudioManager
  play_sfx(sfx_name: String, volume: float) → void
  调用时机: 需要播放音效时（攻击/技能/受伤/连锁等）

任意模块 → AudioManager
  set_volume(bus: String, value: float) → void
  参数: bus ∈ {"master", "bgm", "sfx"}, value ∈ [0.0, 1.0]
```

### 3.6 错误处理约定

#### 3.6.1 错误码定义

| 错误码 | 常量名 | 含义 | 处理方式 |
|--------|--------|------|----------|
| `1001` | `ERR_INVALID_HERO_ID` | 主角ID不存在 | UI显示错误，阻止进入游戏 |
| `1002` | `ERR_INVALID_TEAM_COMP` | 队伍配置无效 | UI提示重新选择 |
| `1003` | `ERR_RUN_IN_PROGRESS` | 已存在进行中的局 | UI提示确认覆盖或继续 |
| `2001` | `ERR_INVALID_NODE_INDEX` | 节点索引越界 | 静默忽略（防篡改） |
| `2002` | `ERR_UNKNOWN_NODE_TYPE` | 未知节点类型 | 记录错误日志，跳过该节点 |
| `3001` | `ERR_INVALID_SKILL` | 技能ID不存在 | 使用默认普通攻击 |
| `3002` | `ERR_INVALID_ACTION` | 非法行动指令 | 返回false，UI提示无效操作 |
| `4001` | `ERR_CORRUPT_SAVE` | 存档损坏 | UI显示存档损坏提示，提供重新开始选项 |
| `4002` | `ERR_VERSION_MISMATCH` | 存档版本不兼容 | UI提示版本问题 |
| `4003` | `ERR_SAVE_IO_FAILED` | 存档IO失败 | 发射save_failed信号，游戏继续但不存档 |
| `5001` | `ERR_CONFIG_NOT_FOUND` | 配置数据缺失 | 使用默认值，记录警告 |
| `9001` | `ERR_UNKNOWN` | 未知错误 | 记录详细日志，尝试优雅降级 |

#### 3.6.2 错误处理策略

| 场景 | 策略 | 说明 |
|------|------|------|
| 配置查询返回null | 使用硬编码默认值 | 保证游戏可继续运行，记录warning |
| 存档IO失败 | 继续游戏，每N分钟重试一次 | 不阻断玩家体验 |
| 战斗状态机异常 | 强制进入BATTLE_END | 防止死循环，记录详细日志。受20回合上限/4段连锁上限保护 [已对齐: 规格书4.3节/4.4节] |
| 伤害计算异常（如除零） | 返回保底伤害（原始伤害×min_damage_ratio） | 继续战斗流程 [已对齐: 规格书4.3节] |
| UI信号未连接 | 静默丢弃 | EventBus不报错 |
| 模块间调用超时 | 抛异常，由调用方捕获 | [待确认: 规格书未明确是否需要超时机制] |
| 伤害公式配置缺失 | 使用内置默认系数 | power_coeff=1.0, tech_coeff=1.0, physique_def_coeff=1.0 [配置驱动] |

---

## 4. 单局运行时数据流图

### 4.1 数据流图说明

本图描述一次完整的单局游戏（Run）中，核心数据在各模块间的流动方向。

```
                            ┌─────────────────────────────────────────┐
                            │              玩家操作层                    │
                            │  (MenuUI / RunHUD / BattleUI)            │
                            │                                         │
                            │  U05 new_game_requested                 │
                            │  U08 node_selected                      │
                            │  U10 shop_purchase_requested            │
                            │  U09 rescue_partner_selected            │
                            └────────────┬────────────────────────────┘
                                         │
                                         │ 直接函数调用（UI → 功能层）
                                         │
                            ┌────────────▼────────────────────────────┐
                            │              功能层                      │
                            │                                         │
                            │  ┌──────────────┐   ┌───────────────┐ │
                            │  │  RunController  │   │  NodeResolver  │ │
                            │  │              │   │               │ │
                            │  │ ·局状态机     │   │ ·节点分发     │ │
                            │  │ ·回合推进     │   │ ·战斗委托     │ │
                            │  │ ·场景切换     │   │ ·奖励委托     │ │
                            │  │ ·存档点触发   │   │ ·PVP委托      │ │
                            │  └──────┬───────┘   └───────┬───────┘ │
                            │         │                   │          │
                            │         │   R01-R10         │   R08-R09│
                            │         ▼                   ▼          │
                            │  ┌─────────────────────────────────────┐│
                            │  │         EventBus (AutoLoad)         ││
                            │  │  ·全局信号中转                       ││
                            │  ·战斗信号广播(B01-B24)               ││
                            │  ·养成信号广播(R01-R21)               ││
                            │  ·UI信号广播(U01-U19)                 ││
                            │  ·系统信号广播(S01-S08)               ││
                            │  └─────────────────────────────────────┘│
                            │         │                   │          │
                            │         ▼                   ▼          │
                            │  ┌──────────────┐   ┌───────────────┐ │
                            │  │CharacterManager│   │  RewardSystem  │ │
                            │  │              │   │               │ │
                            │  │ ·属性计算     │   │ ·锻炼结算     │ │
                            │  │ ·伙伴管理     │   │ ·商店处理     │ │
                            │  │ ·Buff管理     │   │ ·奖励计算     │ │
                            │  │ ·五维属性     │   │ ·PVP奖励      │ │
                            │  └──────┬───────┘   └───────┬───────┘ │
                            │         │                   │          │
                            │         ▼                   ▼          │
                            │  ┌──────────────┐   ┌───────────────┐ │
                            │  │  BattleEngine  │   │  PvpDirector   │ │
                            │  │              │   │               │ │
                            │  │ ·战斗状态机   │   │ ·对手匹配     │ │
                            │  │ ·伤害计算     │   │ ·检定计算     │ │
                            │  │ ·行动排序     │   │ ·远程调用     │ │
                            │  │ ·连锁系统     │   │               │ │
                            │  └──────┬───────┘   └───────────────┘ │
                            │         │                              │
                            └─────────┼──────────────────────────────┘
                                      │
                                      │ 直接函数调用（功能层 → 引擎层）
                                      │
                            ┌─────────▼──────────────┐
                            │         引擎层          │
                            │                         │
                            │ ┌──────────┐ ┌────────┐ │
                            │ │GameManager│ │SaveManager│ │
                            │ │(场景切换) │ │(存档读写) │ │
                            │ └──────────┘ └────────┘ │
                            │ ┌──────────────────────┐│
                            │ │ ConfigManager        ││
                            │ │(配置表加载与查询)    ││
                            │ └──────────────────────┘│
                            │ ┌──────────┐ ┌────────┐ │
                            │ │EnemyDirect│ │AudioManager│ │
                            │ │(敌人AI)   │ │(音频管理)  │ │
                            │ └──────────┘ └────────┘ │
                            │                         │
                            └─────────────────────────┘
```

### 4.2 战斗数据流（详细）

```
BattleEngine
  │
  ├─→ get_hero() ──────────────→ CharacterManager ──→ 主角实时属性
  ├─→ get_partners() ──────────→ CharacterManager ──→ 伙伴实时属性
  ├─→ spawn_enemies() ─────────→ EnemyDirector ─────→ 敌人实例数组
  │    ├─→ get_enemy_template() → ConfigManager ─────→ 精英模板配置(5种)
  │    └─→ get_partner_config() → ConfigManager ─────→ 伙伴援助配置(12名)
  │
  ├── ROUND_START ─────────────→ BattleUI (B04)
  │
  ├── ACTION_ORDER ────────────→ BattleUI (B05)
  │    ├─→ get_unit_combat_stats() → CharacterManager ──→ 实时属性(含Buff)
  │    └─→ 有效速度计算 [已对齐: 规格书4.3节]
  │
  ├── HERO_ACTION ─────────────→ BattleUI (B07)
  │    ├─→ get_skill_config() ─→ ConfigManager ───────→ 技能倍率(三主角)
  │    ├─→ 伤害公式计算 [已对齐: 规格书4.3节]
  │    │    伤害=基础值×属性系数×技能倍率×随机波动(0.9-1.1)
  │    │    属性系数: 攻击方(力量×力量系数+技巧×技巧系数)
  │    │    防御减伤: 防御方(体魄×体魄系数)
  │    │    所有系数通过BattleFormulaConfig配置表驱动
  │    └─→ emit unit_damaged (B09), damage_number_spawned (B12)
  │
  ├── PARTNER_ASSIST ──────────→ BattleUI (B13)
  │    ├─→ get_partners() ─────→ CharacterManager ──→ 5名援助伙伴 [已对齐: 规格书4.3节]
  │    ├─→ 遍历5名伙伴，检查援助触发条件(6种类型) [已对齐: 规格书4.4节]
  │    ├─→ 同伙伴单场援助上限2次 [已对齐: 规格书4.4节]
  │    └─→ emit partner_assist_triggered (B13) 或 partner_assist_skipped (B14)
  │
  ├── CHAIN_CHECK/CHAIN_RESOLVE → BattleUI (B15)
  │    ├─→ 连锁段数上限4段 [已对齐: 规格书4.4节]
  │    ├─→ 同伙伴连锁上限2次 [已对齐: 规格书4.4节]
  │    ├─→ emit chain_triggered (B15)
  │    └─→ 连锁间隔0.3-0.5秒动画 [已对齐: 规格书4.4节]
  │
  ├── STATUS_TICK ─────────────→ BattleUI (B23)
  │    └─→ DOT/HOT结算，Buff回合数-1
  │
  ├── ULTIMATE_CHECK ──────────→ BattleUI (B18, B19)
  │    ├─→ 勇者: 敌方首次低于40%血触发终结一击(300%/无视30%防御/限1次) [已对齐: 规格书4.7节]
  │    ├─→ 影舞者: 第8回合触发风暴乱舞(6段/每段40%/伙伴概率×1.5/限1次) [已对齐: 规格书4.7节]
  │    ├─→ 铁卫: 自身首次低于50%血触发不动如山(3回合/减伤40%/反击100%/眩晕25%/限1次) [已对齐: 规格书4.7节]
  │    └─→ emit ultimate_triggered (B18), ultimate_executed (B19)
  │
  └── ROUND_END ───────────────→ BattleUI (B06)
       ├─→ 回合数检查（上限20回合）[已对齐: 规格书4.3节]
       └─→ 存活检测

BattleEngine ──→ emit battle_ended (B02) ──→ BattleUI
```

### 4.3 养成数据流（详细）

```
RunController (30回合养成循环) [已对齐: 规格书4.2节]
  │
  ├── HERO_SELECT ────────────→ CharacterManager.initialize_hero(hero_id)
  │                              三选一: hero_warrior / hero_shadow_dancer / hero_iron_guard [已对齐: 规格书4.7节]
  │
  ├── TAVERN ─────────────────→ CharacterManager.initialize_partners(selected_partner_ids[0:2])
  │                              从默认6名伙伴中选2名同行伙伴 [已对齐: 规格书4.4节]
  │
  ├── RUNNING.NODE_SELECT ────→ emit node_options_presented (R07)
  │    普通回合: 从节点池随机抽3个选项
  │    固定节点回合:
  │      第5/15/25回: 3个选项均为不同候选伙伴(救援) [已对齐: 规格书4.2节]
  │      第10/20回: 强制进入PVP节点 [已对齐: 规格书4.2节]
  │      第30回: 直接触发终局战 [已对齐: 规格书4.2节]
  │
  ├── NODE_EXECUTE ───────────→ NodeResolver.resolve_node(node_type, node_config)
  │    │
  │    ├── TRAIN ─────────────→ RewardSystem.grant_training_reward(attr_code)
  │    │    属性增长 = 基础值 + 熟练度加成(+0/+2/+4/+5) [已对齐: 规格书4.5节]
  │    │    边际递减: 单项>60%总投入后基础值×0.8 [已对齐: 规格书4.5节]
  │    │    副属性共享: +50%熟练度计数(体魄→精神/力量→技巧/敏捷→力量/技巧→敏捷/精神→体魄) [已对齐: 规格书4.5节]
  │    │
  │    ├── BATTLE/ELITE ──────→ BattleEngine.execute_battle()
  │    │    普通战斗: 快进模式2-3秒，胜利获金币 [已对齐: 规格书5.1节]
  │    │    精英战: 标准播放15-25秒，失败=本局结束，3选1奖励 [已对齐: 规格书5.2节]
  │    │
  │    ├── SHOP ──────────────→ RewardSystem.generate_shop_inventory()
  │    │    商品: 主角升级/伙伴A升级/伙伴B升级 [已对齐: 规格书4.2节]
  │    │
  │    ├── RESCUE ────────────→ RewardSystem.grant_rescue_partner()
  │    │    第5回: Slot 3 / 第15回: Slot 4 / 第25回: Slot 5 [已对齐: 规格书4.2节/4.4节]
  │    │
  │    ├── PVP ───────────────→ PvpDirector.execute_pvp()
  │    │    第10回: 降档惩罚 / 第20回: 降奖+敌人+15% [已对齐: 规格书5.3节]
  │    │    Phase 1: 直接return success(不做PVP)
  │    │
  │    └── FINAL ─────────────→ BattleEngine.execute_battle()
  │         终局战: 标准播放+日志+战后复盘，基于养成表现 [已对齐: 规格书5.4节]
  │
  ├── TURN_ADVANCE ───────────→ emit turn_advanced (R10)
  │    存档点: 每回合自动保存 [已对齐: 规格书4.2节]
  │
  ├── SETTLEMENT ─────────────→ SaveManager.generate_fighter_archive()
  │    评分公式 [已对齐: 规格书6.3节]:
  │      总分 = 终局战×0.4 + 养成效率×0.2 + PVP×0.2 + 流派纯度×0.1 + 连锁展示×0.1
  │      评级: S≥90 / A≥75 / B≥60 / C≥40 / D<40 [已对齐: 规格书6.3节]
  │    档案内容 [已对齐: 规格书4.6节]:
  │      保存: 主角五维/等级/技能等级/必杀技等级/5名伙伴ID和等级/支援援助配置/技能快照/养成统计/通关评价
  │      不保存: 局内生命值/属性熟练度/局内金币/临时BUFF
  │
  └── RANKING ────────────────→ SaveManager.load_archives()
       加载已固定的斗士档案(is_fixed=true) [已对齐: 规格书4.6节]
```

---

## 5. 信号发射时序图

### 5.1 完整回合流程时序

```sequence
RunController -> NodeResolver: resolve_node("BATTLE", config)
NodeResolver -> BattleEngine: execute_battle(battle_config)
BattleEngine -> BattleUI: battle_started (B01)

loop 最多20回合 [已对齐: 规格书4.3节]
  BattleEngine -> BattleUI: battle_turn_started (B04)
  BattleEngine -> BattleUI: action_order_calculated (B05)
  
  alt 轮到主角行动
    BattleEngine -> BattleUI: unit_turn_started (B07)
    BattleEngine -> ConfigManager: get_skill_config(skill_id) [三主角技能参数]
    BattleEngine -> CharacterManager: get_unit_combat_stats()
    BattleEngine -> BattleUI: action_executed (B08)
    BattleEngine -> BattleUI: unit_damaged (B09) / unit_healed (B10)
    BattleEngine -> BattleUI: damage_number_spawned (B12)
    
    BattleEngine -> BattleUI: partner_assist_triggered (B13)
    alt 连锁条件满足 且 段数<4 [已对齐: 规格书4.4节]
      loop 连锁段数 < 4
        BattleEngine -> BattleUI: chain_triggered (B15)
        BattleEngine -> BattleUI: action_executed (B08)
      end
    end
    BattleEngine -> BattleUI: chain_ended (B16)
  else 轮到敌人行动
    BattleEngine -> EnemyDirector: decide_enemy_action(enemy)
    EnemyDirector -> BattleEngine: EnemyAction
    BattleEngine -> BattleUI: enemy_action_decided (B24)
    BattleEngine -> BattleUI: action_executed (B08)
  end
  
  BattleEngine -> BattleUI: status_ticked (B23) [DOT/HOT结算]
  
  alt 必杀技条件满足 且 未触发过 [已对齐: 规格书4.7节]
    alt hero_class=="brave" 且 敌方首次<40%血
      BattleEngine -> BattleUI: ultimate_triggered (B18) [终结一击]
    else hero_class=="shadow_dancer" 且 turn==8
      BattleEngine -> BattleUI: ultimate_triggered (B18) [风暴乱舞]
    else hero_class=="iron_guard" 且 自身首次<50%血
      BattleEngine -> BattleUI: ultimate_triggered (B18) [不动如山]
    end
    BattleEngine -> BattleUI: ultimate_executed (B19)
  end
  
  BattleEngine -> BattleUI: battle_turn_ended (B06)
end

BattleEngine -> NodeResolver: BattleResult
BattleEngine -> BattleUI: battle_ended (B02)
NodeResolver -> BattleEngine: [销毁实例]
```

### 5.2 养成循环时序（三选一决策点）

```sequence
RunController -> RunHUD: round_changed (R06) [turn=N, max=30]
RunController -> RunHUD: node_options_presented (R07) [3个选项]

alt 普通回合(非固定节点)
  Player -> RunHUD: 点击选项
  RunHUD -> RunController: select_node(index)
else 救援回合(5/15/25) [已对齐: 规格书4.2节]
  RunController -> RunHUD: rescue_encountered (R17) [3个候选]
  Player -> RunHUD: 选择伙伴
  RunHUD -> NodeResolver: [rescue_partner]
  NodeResolver -> RewardSystem: grant_rescue_partner()
  RewardSystem -> CharacterManager: add_partner()
  CharacterManager -> RunHUD: partner_unlocked (R18)
end

RunController -> NodeResolver: resolve_node(type, config)

alt TRAIN节点
  NodeResolver -> RewardSystem: grant_training_reward(attr)
  RewardSystem -> CharacterManager: modify_hero_stats()
  CharacterManager -> RunHUD: stats_changed (C01)
  RewardSystem -> RunHUD: training_completed (R11)
  
else BATTLE节点
  NodeResolver -> BattleEngine: execute_battle()
  ... [战斗时序见5.1] ...
  BattleEngine -> NodeResolver: BattleResult
  NodeResolver -> RewardSystem: grant_battle_rewards()
  RewardSystem -> RunHUD: gold_changed (R16)
  
else ELITE节点
  NodeResolver -> BattleEngine: execute_battle()
  ... [战斗时序，失败=本局结束] ...
  alt 胜利
    NodeResolver -> RewardSystem: [稀有奖励3选1]
  else 失败
    NodeResolver -> RunController: [结束本局]
  end
  
else SHOP节点
  NodeResolver -> RewardSystem: generate_shop_inventory()
  RewardSystem -> RunHUD: shop_entered (R13)
  Player -> RunHUD: 选择购买
  RunHUD -> RewardSystem: process_purchase()
  RewardSystem -> CharacterManager: [升级应用]
  CharacterManager -> RunHUD: stats_changed (C01)
  RewardSystem -> RunHUD: shop_item_purchased (R14)
  RewardSystem -> RunHUD: gold_changed (R16)
  RewardSystem -> RunHUD: shop_exited (R15)
  
else PVP节点(10/20回) [已对齐: 规格书4.2节]
  alt Phase 1
    NodeResolver -> RunController: [return success]
  else Phase 2+
    NodeResolver -> PvpDirector: execute_pvp()
    PvpDirector -> BattleEngine: simulate_pvp_battle()
    ... [战斗时序] ...
    PvpDirector -> RunHUD: pvp_result (R21)
  end
  
end

NodeResolver -> RunController: NodeResult
RunController -> RunHUD: node_resolved (R09)
RunController -> SaveManager: save_run_state() [自动存档]

alt turn < 30
  RunController -> RunHUD: turn_advanced (R10)
  RunController -> RunHUD: [下回合选项]
else turn == 30 [已对齐: 规格书4.2节]
  RunController -> BattleEngine: [终局战]
  RunController -> SaveManager: generate_fighter_archive()
  SaveManager -> MenuUI: archive_generated (S05)
end
```

---

## 6. 接口完整性验证矩阵

### 6.1 13大系统覆盖验证

| # | 系统名 | 相关信号 | 相关函数调用 | 覆盖状态 |
|---|--------|----------|-------------|----------|
| 1 | 游戏主循环 | R01-R06, R10, B01-B03, U05-U06 | RunController.start_new_run, change_scene | ✅ 完全覆盖 [已对齐: 规格书4.2节] |
| 2 | 三选一事件系统 | R07-R09, U08 | NodeResolver.resolve_node | ✅ 完全覆盖 [已对齐: 规格书4.2节] |
| 3 | 基础属性系统 | C01-C03, R11-R12 | CharacterManager.modify_hero_stats | ✅ 完全覆盖 [已对齐: 规格书3.3节/4.5节] |
| 4 | 战斗系统 | B01-B24 | BattleEngine.execute_battle | ✅ 完全覆盖 [已对齐: 规格书4.3节] |
| 5 | 伙伴援助系统 | B13-B14, R17-R18, C03 | CharacterManager.add_partner, BattleEngine | ✅ 完全覆盖 [已对齐: 规格书4.3节/4.4节] |
| 6 | 连锁系统 | B15-B17 | ChainSystem (BattleEngine内部) | ✅ 完全覆盖 [已对齐: 规格书4.4节] |
| 7 | 精英战系统 | B01, B24, EnemyDirector | EnemyDirector.spawn_enemies, decide_enemy_action | ✅ 完全覆盖 [已对齐: 规格书5.2节] |
| 8 | 商店系统 | R13-R16, U10-U11 | RewardSystem.generate_shop_inventory, process_purchase | ✅ 完全覆盖 [已对齐: 规格书4.2节/3.1节] |
| 9 | 酒馆集结系统 | U12, R01 | RunController.start_new_run | ✅ 完全覆盖 [已对齐: 规格书4.2节/4.4节] |
| 10 | PVP检定系统 | R19-R21 | PvpDirector.execute_pvp | ✅ 完全覆盖（Phase 1标记） [已对齐: 规格书4.2节/1.3节] |
| 11 | 排行与收藏系统 | S05 | SaveManager.load_archives | ✅ 斗士档案覆盖 [已对齐: 规格书4.6节] |
| 12 | 存档/读档系统 | S01-S04 | SaveManager.save_run_state, load_latest_run | ✅ 完全覆盖 [已对齐: 规格书2.2节/4.6节] |
| 13 | 背景音乐/音效系统 | S08 | AudioManager | ✅ 已补齐（原设计遗漏） [已对齐: 规格书2.2节] |

### 6.2 EventBus信号完整性验证

| 类别 | 信号数量 | 对齐状态 | 说明 |
|------|----------|----------|------|
| 养成循环信号 (Rxx) | R01-R21 = 21个 | ✅ 全部对齐 | 含救援(R17-R18)、PVP(R19-R21)、商店(R13-R16) |
| 战斗信号 (Bxx) | B01-B24 = 24个 | ✅ 全部对齐 | 含8步流程(B04-B06/B09-B10/B15-B16/B18-B19)、12名伙伴援助(B13-B14)、5种精英(B24) |
| 角色管理信号 (Cxx) | C01-C06 = 6个 | ✅ 全部对齐 | 含五维属性(C01)、Lv3质变(C03)、三主角技能(C05) |
| UI控制信号 (Uxx) | U01-U19 = 19个 | ✅ 全部对齐 | 含UIManager(U01-U04)、HUD(U17-U19)、玩家操作(U05-U16) |
| 系统信号 (Sxx) | S01-S08 = 8个 | ✅ 全部对齐 | 含SaveManager(S01-S04)、AudioManager(S08)[已补齐] |
| **总计** | **78个信号** | **全部对齐** | 原71个 → 调整后78个（新增7个，删除0个） |

### 6.3 三主角技能信号验证

| 主角 | 常规技能 | 必杀技 | 信号覆盖 | 对齐状态 |
|------|----------|--------|----------|----------|
| 勇者 | 追击斩(30%/60%伤害) | 终结一击(40%血/300%/无视30%防御/限1次) | C05 skill_triggered, B18 ultimate_triggered [brave], B19 ultimate_executed | ✅ [已对齐: 规格书4.7节] |
| 影舞者 | 疾风连击(2-4段/每段35%) | 风暴乱舞(第8回合/6段/每段40%/伙伴概率×1.5/限1次) | C05 skill_triggered, B18 ultimate_triggered [shadow_dancer], B19 ultimate_executed | ✅ [已对齐: 规格书4.7节] |
| 铁卫 | 铁壁反击(25%/反弹50%/10%眩晕) | 不动如山(50%血/3回合/减伤40%/反击100%/眩晕25%/限1次) | C05 skill_triggered, B18 ultimate_triggered [iron_guard], B19 ultimate_executed | ✅ [已对齐: 规格书4.7节] |

### 6.4 AutoLoad单例一致性验证

| 单例名 | 规格书2.2节定义 | 本文档使用 | 状态 |
|--------|-----------------|-----------|------|
| GameManager | ✅ 是 | 场景切换(R03)、change_scene | ✅ 已对齐 [已对齐: 规格书2.2节] |
| ConfigManager | ✅ 是 | 所有配置查询(get_*_config) | ✅ 已对齐 [原GameData，已对齐: 规格书2.2节] |
| SaveManager | ✅ 是 | 存档/读档/档案生成(S01-S05) | ✅ 已对齐 [原SaveArchive，已对齐: 规格书2.2节] |
| AudioManager | ✅ 是 | 音频播放(S08) | ✅ 已补齐 [原设计遗漏，已对齐: 规格书2.2节] |
| EventBus | ✅ 是 | 全部78个信号 | ✅ 已对齐 [已对齐: 规格书2.2节] |
| ~~GameData~~ | ~~原设计~~ | ~~已统一为ConfigManager~~ | ~~已修正~~ [已对齐: 规格书2.2节] |
| ~~SceneManager~~ | ~~原设计~~ | ~~已统一为GameManager~~ | ~~已修正~~ [已对齐: 规格书2.2节] |
| ~~SaveArchive~~ | ~~原设计~~ | ~~已统一为SaveManager~~ | ~~已修正~~ [已对齐: 规格书2.2节] |
| ~~UIManager~~ | ~~原设计为AutoLoad~~ | ~~已明确为普通节点~~ | ~~已修正~~ [已对齐: 规格书2.2节] |

---

## 7. 附录

### 附录A：[待确认]项清单（对齐后）

| 序号 | 章节 | 待确认事项 | 状态 | 备注 |
|:----:|:----:|:----------|:----:|:-----|
| 1 | 2.2.7 | damage_number_spawned信号的位置参数由BattleEngine还是BattleUI计算 | 保留 | 规格书未明确UI渲染细节，建议Phase 1由BattleUI根据单位位置自动计算 |
| 2 | 3.2.3 | Phase 1是否需要保留submit_player_action接口（自动战斗模式下不使用） | 保留 | 规格书4.3节定义所有战斗为自动战斗，接口预留Phase 2+ [已对齐: 规格书4.3节] |
| 3 | 3.3.5 | PVP对手池配置（get_pvp_opponent_pool）的Phase 2详细设计 | 保留 | 规格书1.3节说明PVP在Phase 2做本地AI对手池 [已对齐: 规格书1.3节] |
| 4 | 3.4.5 | PvpDirector Phase 1的完整实现方案（直接return success vs 完整AI对手逻辑） | 保留 | 规格书1.3节: Phase 1不做PVP，Phase 2本地AI对手池 [已对齐: 规格书1.3节] |
| 5 | 3.4.6 | 敌人难度缩放公式参数(scaling_factor) | 保留 | 规格书未明确具体数值，需配置表驱动 [待确认: 规格书未明确] |
| 6 | 3.5 | UIManager的精确职责范围和节点挂载位置 | 保留 | 规格书2.2节明确UIManager不是AutoLoad，但具体挂载位置待确认 [已对齐: 规格书2.2节] |
| 7 | 3.5 | 场景过渡动画(transition_type)的Phase 1支持范围 | 保留 | 规格书未明确过渡动画设计 |
| 8 | 3.5 | AudioManager的接口签名完整规格 | 保留 | 规格书2.2节仅提及"音效/BGM管理"，未给出具体接口定义 [已对齐: 规格书2.2节] |
| 9 | U15 | skip_animation_requested是否支持 | 保留 | 规格书未明确是否支持跳过动画 |
| 10 | U16 | abandon_run_requested放弃本局功能是否Phase 1包含 | 保留 | 规格书未明确放弃功能细节 |
| 11 | C06 | 装备系统是否Phase 1包含 | 保留 | 规格书未明确Phase 1是否包含装备系统 [待确认: 规格书未明确] |
| 12 | 3.6.2 | 模块间调用超时机制 | 保留 | 规格书未明确是否需要超时机制 |
| 13 | B20 | ultimate_condition_checked调试信号是否保留到正式版本 | 保留 | 规格书未明确调试信号规范 |
| 14 | S07 | warning_issued信号的使用范围 | 保留 | 规格书未明确调试/警告信号规范 |

### 附录B：已从[待确认]移除并对齐的项目

| 原序号 | 原待确认事项 | 对齐依据 | 最终方案 |
|:------:|:------------|:--------|:--------|
| - | GameData/SceneManager/SaveArchive/UIManager单例命名 | [已对齐: 规格书2.2节] | 统一为ConfigManager/GameManager/SaveManager/AudioManager，UIManager明确为普通节点 |
| - | EventBus信号命名规范 | [已对齐: 规格书2.3节] | 全部snake_case，动词过去式表示事件已发生 |
| - | 五属性编码定义 | [已对齐: 规格书3.3节] | 1体魄/2力量/3敏捷/4技巧/5精神 |
| - | 三主角技能参数（追击斩/疾风连击/铁壁反击/终结一击/风暴乱舞/不动如山） | [已对齐: 规格书4.7节] | 全部参数已定稿，见B18/B19信号和ConfigManager.get_skill_config() |
| - | 30回合关键节点分布 | [已对齐: 规格书4.2节] | 第5/15/25回救援，第10/20回PVP，第30回终局战 |
| - | 战斗每回合8步流程 | [已对齐: 规格书4.3节] | 行动顺序→主角普攻/技能→伙伴援助→连锁检查→状态结算→必杀技检查→回合结束判定 |
| - | 战斗20回合上限 | [已对齐: 规格书4.3节] | 最大20回合 |
| - | 连锁4段上限/伙伴2次上限 | [已对齐: 规格书4.4节] | chain_triggered (B15) 含chain_count∈[1,4] |
| - | 12名伙伴援助配置 | [已对齐: 规格书4.8节] | partner_unlocked (R18), partner_assist_triggered (B13) 含完整伙伴参数 |
| - | 5种精英敌人模板 | [已对齐: 规格书5.2节] | enemy_action_decided (B24) 含enemy_template参数 |
| - | 4种播放模式分级 | [已对齐: 规格书4.3节] | battle_started (B01) 含playback_mode参数 |
| - | 伤害公式配置驱动 | [已对齐: 规格书4.3节] | ConfigManager.get_skill_config() 返回值说明 |
| - | 评分公式和评级标准 | [已对齐: 规格书6.3节] | SaveManager.generate_fighter_archive() 返回值含score和rating |
| - | 终局保存项和不保存项 | [已对齐: 规格书4.6节] | FighterArchive格式完整定义 |
| - | PVP失败惩罚分层 | [已对齐: 规格书5.3节] | pvp_result (R21) 含penalty_tier参数 |
| - | 队伍结构1+2+3 | [已对齐: 规格书4.4节] | partner_unlocked (R18) 含slot参数 |
| - | 熟练度阶段定义 | [已对齐: 规格书4.5节] | training_completed (R11) 含proficiency_stage和bonus_applied参数 |
| - | 边际递减规则 | [已对齐: 规格书4.5节] | NodeResolver→RewardSystem.grant_training_reward() 参数说明 |
| - | 副属性50%共享 | [已对齐: 规格书4.5节] | 养成数据流4.3节详细说明 |
| - | 4种节点类型(TRAIN/BATTLE/SHOP/RESCUE) | [已对齐: 规格书4.2节] | node_type ∈ {TRAIN,BATTLE,ELITE,SHOP,RESCUE,PVP,FINAL} |
| - | AudioManager补齐 | [已对齐: 规格书2.2节] | 新增S08(audio_play_requested)和3.5节AudioManager接口 |

### 附录C：规格书章节索引

| 规格书章节 | 本文档引用位置 | 对齐内容 |
|:----------|:-------------|:--------|
| 2.2 5个AutoLoad单例 | 第2章信号清单、第3章函数契约、第6章验证矩阵 | 确认GameManager/ConfigManager/SaveManager/AudioManager/EventBus，修正GameData/SceneManager/SaveArchive |
| 2.3 EventBus解耦 | 1.3通信分层、1.4双向调用禁止 | 上层调用下层，下层通过EventBus发事件 |
| 3.1 配置表 | 3.3.1 ConfigManager接口 | ShopConfig/BattleFormulaConfig等配置驱动 |
| 3.3 五属性 | 2.1.2 AttributeCode、C01信号、3.4.2 modify_hero_stats | 1体魄/2力量/3敏捷/4技巧/5精神 |
| 4.2 30回合养成循环 | R06-R10信号、4.3养成数据流、5.2养成时序 | 30回合节点分布/固定节点/阶段划分 |
| 4.3 战斗每回合8步流程 | B01-B24信号、4.2战斗数据流、5.1战斗时序 | 8步流程/20回合上限/伤害公式/配置驱动 |
| 4.4 连锁与伙伴 | B13-B17信号、3.4.3 BattleEngine | 4段上限/伙伴2次上限/6种触发类型/1+2+3队伍 |
| 4.5 熟练度与边际递减 | R11-R12信号、3.4.4 grant_training_reward | 四阶段加成/边际递减60%/副属性50%共享 |
| 4.6 终局保存 | S05信号、3.3.2 generate_fighter_archive | 保存9项/不保存4项/FighterArchive结构/is_fixed |
| 4.7 三主角技能 | B18-B19信号、C05信号、ConfigManager.get_skill_config | 勇者/影舞者/铁卫技能参数全部定稿 |
| 4.8 12伙伴设计 | R17-R18信号、3.3.1 get_partner_config | 12名伙伴Lv3质变/援助类型/队伍结构 |
| 5.1 普通战斗 | 3.4.3 execute_battle | 快进模式2-3秒/失败不降至0 |
| 5.2 精英敌人 | B24信号、3.4.6 EnemyDirector | 5种精英模板/属性模板/特殊机制 |
| 5.3 PVP检定 | R19-R21信号、3.4.5 PvpDirector | 第10/20回/失败惩罚/Phase 2本地AI |
| 6.3 评分公式 | 3.3.2 generate_fighter_archive返回值 | 5项加权/评级标准S≥90/A≥75/B≥60/C≥40/D<40 |

### 附录D：变更日志

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| v1.0 | 原设计 | 初始版本，使用GameData/SceneManager/SaveArchive/UIManager命名 |
| v1.1 | 对齐后 | 全面对齐基准规格书v1.0，AutoLoad单例命名修正，信号参数精确化，新增AudioManager，新增14项[待确认]处理，原[待确认]中22项已确认并对齐 |

---

> 文档结束
> 本文档所有 `[已对齐: 规格书X.X节]` 标注表示已与 `/mnt/agents/upload/开发规格书_赛马娘版Q宠大乐斗.md` 对应章节确认对齐。
> 所有 `[待确认]` 标注表示基准规格书未明确的内容，保留待后续设计决策。
