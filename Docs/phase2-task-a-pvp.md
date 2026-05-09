# Phase 2 任务卡 A — PVP真实匹配（本地AI对手池）

**项目路径**：`D:\Hero Battle`  
**引擎**：Godot 4.6.2 / GDScript  
**基准文档**：`02_interface_contracts.md`（信号R19-R21）、`05_run_loop_design.md`（5.3节PVP检定）  
**交付目录**：`res://scripts/systems/`、`res://resources/configs/`

---

## 目标

替换 Phase 1 的 `pvp_director.gd` 占位实现，使第 10/20 回合的 PVP 检定运行**真实战斗**：
1. 生成 AI 对手（基于玩家当前状态镜像+扰动）
2. 调用 `BattleEngine` 执行完整 20 回合战斗
3. 返回真实胜负结果
4. 失败时施加惩罚（扣金币/扣生命），但不结束本局

---

## 交付物清单

### 1. 配置层

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| A1 | `resources/configs/pvp_opponent_templates.json` **新增** | AI对手模板配置：前期(第10回)/中期(第20回)的属性乘数和队伍模板 |

**模板 Schema（单条记录）**：
```json
{
  "id": "pvp_template_early",
  "name": "前期PVP模板",
  "min_turn": 10,
  "max_turn": 10,
  "hero_stat_multiplier": 0.90,      // 对手主角属性 = 玩家属性 × 乘数
  "hero_stat_variance": 0.05,        // ±5% 随机波动
  "partner_count": 3,                // 对手带3个伙伴
  "partner_stat_multiplier": 0.85,
  "partner_stat_variance": 0.10,
  "enemy_difficulty_tier": 2         // 调用 enemy_configs 中 tier=2 的模板
}
```

### 2. 系统层

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| A2 | `scripts/systems/pvp_opponent_generator.gd` **新增** | AI对手生成器：复制玩家数据 → 应用乘数+扰动 → 生成可传入 BattleEngine 的对手队伍 |
| A3 | `scripts/systems/pvp_director.gd` **重写** | 替换占位：调用 PvpOpponentGenerator → 调用 BattleEngine → 返回真实胜负 + 惩罚应用 |
| A4 | `scripts/models/pvp_result.gd` **新增** | `PvpResult` 数据模型：胜负、对手信息、战斗摘要、惩罚等级、惩罚数值 |

### 3. 运行时数据层

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| A5 | `scripts/systems/run_controller.gd` **扩展** | PVP节点执行时传入真实玩家状态（hero/partners/gold/hp），接收结果后应用惩罚 |
| A6 | `scripts/systems/character_manager.gd` **扩展** | 提供 `get_battle_ready_team()` 接口，返回可直接传入 BattleEngine 的 Dictionary 格式 |

---

## 核心规则

### AI对手生成策略

```
1. 根据回合数选择模板（第10回=前期模板，第20回=中期模板）
2. 复制玩家主角数据：
   - 五维属性 = 玩家属性 × hero_stat_multiplier ± 随机波动
   - HP/MaxHP 同步缩放
   - 技能ID复制（被动+必杀）
3. 生成对手伙伴队伍：
   - 从 PartnerConfig 中随机选 N 个（不重复）
   - 属性 = 基础值 × partner_stat_multiplier ± 波动
   - 等级固定为 Lv1（简化）
4. 组装 battle_config 传入 BattleEngine
```

### 失败惩罚规则

| 回合 | 失败惩罚 | 说明 |
|:---:|:---|:---|
| 第10回 | 扣除 **50% 当前金币** | 金币不足时扣至0，不扣属性 |
| 第20回 | 扣除 **30% 当前生命** | 最低保留 10 点HP，不死 |
| 胜利 | 无惩罚，无奖励（Phase 2最小集） | 评分时计入 PVP 项得分 |

### PVP结果数据结构

```gdscript
{
  "won": bool,
  "pvp_turn": int,                    // 10 或 20
  "opponent_name": String,            // 如 "AI_挑战者_001"
  "opponent_hero_id": String,         // 对手使用的主角ID
  "combat_summary": {
    "turns": int,                     // 实际回合数
    "player_damage_dealt": int,
    "player_damage_taken": int,
    "opponent_hp_ratio": float,       // 终局时对手HP比例
    "player_hp_ratio": float,
    "ultimate_triggered": bool,
    "max_chain": int,
  },
  "penalty_tier": String,             // "gold_50" / "hp_30" / "none"
  "penalty_value": int,               // 实际扣除数值
  "rating_change": int                // 预留，Phase 2 固定为 0
}
```

---

## 接口契约

### 重写信号（EventBus）

信号签名**不变**，但参数内容变为真实战斗结果：

```gdscript
# 发射方：PvpDirector
# 接收方：RunHUD, RunController
EventBus.pvp_result.emit({
  "won": bool,
  "pvp_turn": int,
  "rating_change": 0,                 // Phase 2 固定为0
  "opponent_name": String,
  "combat_log_summary": Array[String], // 简化战斗日志（每回合摘要）
  "penalty_tier": String,
  "penalty_value": int,
})
```

### 函数契约

```gdscript
# PvpDirector（重写）
func execute_pvp(pvp_config: Dictionary) -> Dictionary
# pvp_config: {
#   turn_number: int,
#   player_hero: Dictionary,       // CharacterManager.get_battle_ready_team() 返回的hero
#   player_partners: Array[Dictionary],
#   player_gold: int,
#   player_hp: int,
#   player_max_hp: int,
#   run_seed: int
# }
# 返回: PvpResult Dictionary（见上表）

# PvpOpponentGenerator（新增）
func generate_opponent(player_state: Dictionary, turn_number: int) -> Dictionary
# 返回: battle_config 格式，可直接传入 BattleEngine.execute_battle()

# CharacterManager（扩展）
func get_battle_ready_team() -> Dictionary
# 返回: { hero: Dictionary, partners: Array[Dictionary] }
# hero 格式与 BattleEngine 期望的 Dictionary 一致
```

---

## 验收标准

### 必须项

- [ ] `pvp_opponent_templates.json` 能被 ConfigManager 解析，至少 2 条模板（前期/中期）
- [ ] 第10回合PVP运行真实 BattleEngine 战斗，胜负由战斗计算决定（不是固定true）
- [ ] 第20回合同上，对手属性比第10回合更强（乘数更高或伙伴更多）
- [ ] PVP胜利时：返回 `won=true`，`penalty_tier="none"`，游戏继续
- [ ] 第10回合PVP失败时：金币扣除50%（不足时扣至0），`penalty_tier="gold_50"`
- [ ] 第20回合PVP失败时：HP扣除30%（最低保留10），`penalty_tier="hp_30"`
- [ ] 惩罚应用后 HUD 实时更新（金币/生命数值变化）
- [ ] PVP不阻塞30回合流程，无论胜负游戏继续

### 加分项

- [ ] PVP战斗有简化日志输出到 Console（每回合关键动作摘要）
- [ ] 对手名称随机生成（如 "AI_挑战者_001" / "AI_竞技者_A7"）
- [ ] 提供 `test_pvp_real.tscn`：强制触发PVP → 输出胜负 + 对手属性 + 战斗摘要

---

## 禁止事项

- ❌ 不做网络PVP / 不做真实玩家匹配（Phase 3）
- ❌ PVP胜利不给额外奖励（Phase 2最小集，仅评分时计入）
- ❌ 不改 BattleEngine 核心状态机（BattleEngine 作为黑盒调用）
- ❌ 不改 Phase 1 已有的 EventBus 信号签名

---

## 备注

- BattleEngine 调用方式与精英战/终局战完全一致：`execute_battle(battle_config)`
- AI 对手的 `battle_config` 结构与玩家方对称：`{ hero, enemies, partners, battle_seed }`
- 这里 `enemies` 是玩家队伍（从AI视角看），`hero` + `partners` 是AI队伍
- PVP 战斗的 `battle_seed` 使用 `run_seed + turn_number` 保证可复现
- 简化处理：AI 对手伙伴不带援助配置（Phase 2 最小集，只让主角+基础伙伴参战）

---

*任务卡版本：v1.0*  
*日期：2026-05-09*
