# 补充文档：战斗画面定义统一

> 补充日期：2026-05-09
> 补充到：04_battle_engine_design.md / 06_ui_flow_design.md / 01_module_breakdown.md
> 目的：统一Phase 1/2/3/4各阶段对"战斗画面"的定义，消除headless vs UI展示的文档矛盾

---

## 一、现状矛盾

| 文档 | 内容 | 倾向 |
|:---|:---|:---:|
| `04_battle_engine_design.md` 代码注释 | "同步执行模式（单帧内完成），适用于headless测试与后端推演" | headless |
| `04_battle_engine_design.md` 8.1节 | 定义 fast_forward / standard / replay 三种播放模式 | 要有画面 |
| `06_ui_flow_design.md` 1.1节 | 场景清单包含 `battle.tscn` | 要有画面 |
| `06_ui_flow_design.md` 5.1节 | fast_forward "2-3秒内完成，仅显示最终伤害数字和结果摘要" | 最低限度画面 |
| `04_battle_engine_design.md` 1.2节 | HERO_ACTION状态说"应用伤害并显示日志" | 应该有日志 |
| `06_ui_flow_design.md` 5.1.3节 | replay模式 "用于PVP回放、排行榜高光展示" | Phase 1/2无用 |

**核心矛盾**：
1. `04` 说BattleEngine是headless单帧执行 → UI来不及渲染
2. `06` 却设计了完整的 battle.tscn 场景（RoundLabel/HpBar/HeroRect/EnemyRect/BattleLog）
3. 两种定义互斥：单帧执行 = 无画面；有场景 = 需要帧同步

---

## 二、统一决策：按Phase分阶段定义

### Phase 1/2 最小集（当前已实现）

**目标**：功能正确、可测试，画面为最低限度占位。

| 元素 | Phase 1/2 标准 | 实现方式 |
|:---|:---|:---|
| 战斗执行 | **headless，单帧完成** | `execute_battle()` 同步执行20回合 |
| 画面展示 | **仅显示结果摘要** | 战斗结束后在HUD或结算界面显示战斗日志摘要 |
| 场景切换 | **不切换** | 养成循环中战斗节点直接返回结果，不进入battle.tscn |
| 日志输出 | **Console输出** | `_result.add_log()` 写入Console供调试 |
| 血条动画 | **无** | 直接修改数值 |
| 伤害数字 | **无** | 只有总伤害统计 |

**Phase 1/2 的 battle.tscn 用途**：
- 作为**终局战的可视化占位场景**（第30回合特殊处理）
- 显示战斗标题、回合计数、最终结果，但不播放逐回合动画
- 所有战斗类型（普通/精英/PVP）在养成循环中headless执行

### Phase 3 扩展集

**目标**：可观看的简化战斗回放。

| 元素 | Phase 3 标准 | 依赖 |
|:---|:---|:---|
| 战斗执行 | **逐回合异步** | `await get_tree().process_frame` 每回合/每动作间 |
| 画面展示 | **简化回放** | 进入battle.tscn，显示回合数、双方HP、动作摘要 |
| 场景切换 | **终局战和PVP进入battle.tscn** | 普通/精英战斗仍headless |
| 日志输出 | **UI实时更新** | RichTextLabel滚动显示 |
| 血条动画 | **简单Tween** | `create_tween().tween_property(hp_bar, "value", new_hp, 0.3)` |
| 伤害数字 | **可选** | ColorRect弹出数字（无动画） |

### Phase 4 完整集

**目标**：完整的战斗演出体验。

| 元素 | Phase 4 标准 | 依赖 |
|:---|:---|:---|
| 战斗执行 | **帧同步 + 动作调度** | ActionTimeline系统 |
| 画面展示 | **全动画** | 角色Sprite/敌人Sprite/背景/特效 |
| 场景切换 | **所有战斗类型进入battle.tscn** | 普通/精英/PVP/终局 |
| 日志输出 | **实时UI + 可回看** | 战斗日志支持暂停和回看 |
| 血条动画 | **平滑Tween + 伤害数字弹出** | 带缓冲效果的HP变化 |
| 伤害数字 | **必做** | 弹出数字+暴击特效+闪避文字 |
| 连锁展示 | **必做** | 连锁计数器+高亮+屏幕震动 |
| 必杀技 | **必做** | 特写动画+全屏特效+音效 |

---

## 三、Phase 1/2 的修正实现规范

### 3.1 战斗节点的处理方式

```gdscript
# RunController 中处理各类战斗节点

# 普通战斗（BATTLE）— headless，直接给金币奖励
func _resolve_battle_node(node_config: Dictionary) -> Dictionary:
    var result: Dictionary = _battle_engine.execute_battle_simple(node_config)
    # 直接返回：{success: true, gold_earned: int, logs: Array}
    return result

# 精英战（ELITE）— headless，完整战斗
func _resolve_elite_node(node_config: Dictionary) -> Dictionary:
    var battle_result: Dictionary = _run_battle_engine(node_config.enemy_id)
    # 精英战有胜负，失败可能结束本局
    return {
        "success": battle_result.winner == "player",
        "rewards": [...],
        "combat_summary": battle_result,
    }

# PVP（PVP_CHECK）— headless，完整战斗
func _resolve_pvp_node(turn: int) -> Dictionary:
    var pvp_result: Dictionary = _pvp_director.execute_pvp(pvp_config)
    return {
        "success": true,  # PVP失败不结束本局
        "rewards": [{"type": "pvp_result", "data": pvp_result}],
    }

# 终局战（FINAL）— 可进入battle.tscn做最低限度展示
func _execute_final_battle() -> void:
    # 方案A（当前）：headless执行，然后在结算界面显示摘要
    var battle_result: Dictionary = _run_battle_engine(2005)
    _settle(battle_result)
    
    # 方案B（Phase 3+）：切换场景到battle.tscn，异步播放简化回放
    # GameManager.change_scene("FINAL_BATTLE")
    # Battle场景接收battle_result并显示简化回放
```

### 3.2 战斗日志摘要的显示位置

Phase 1/2 不需要进入 `battle.tscn`，战斗日志摘要在**养成循环HUD**中显示：

```gdscript
# RunMain.gd — 节点执行完毕后显示战斗摘要
func _on_node_resolved(node_type: String, result_data: Dictionary) -> void:
    match node_type:
        "BATTLE", "ELITE", "PVP", "FINAL":
            var summary: Dictionary = result_data.get("combat_summary", {})
            _show_combat_summary_popup(summary)
            # 弹窗显示：
            # "战斗结果：胜利
            #  回合数：12/20
            #  造成伤害：1247
            #  受到伤害：356
            #  剩余HP：145/210
            #  [关闭]"
```

### 3.3 battle.tscn 在Phase 1/2 的定位

`battle.tscn` **存在但不用**：
- 文件保留，作为Phase 3+的占位基础
- Phase 1/2 不切换到此场景
- 如果测试需要，可单独运行 `test_battle_engine.tscn`（headless测试场景）

---

## 四、04_battle_engine_design.md 的修正

### 4.1 删除/修改矛盾内容

| 原文 | 修正 |
|:---|:---|
| "同步执行模式（单帧内完成），适用于headless测试与后端推演" | **保留**，但增加注释：`# Phase 1/2: headless模式。Phase 3+: 可改为await帧同步。` |
| "所有战斗类型共用一套逻辑，通过播放模式区分：普通战斗简化快进（2-3秒）、精英战/PVP检定/终局战标准播放（15-25秒）" | **修正为**：Phase 1/2 全部headless。Phase 3 终局战和PVP进入简化回放。Phase 4 全部进入完整回放。 |
| "0.3-0.5秒动画展示"（CHAIN_RESOLVE状态） | **标注**：Phase 1/2 无动画，Phase 4 实现。 |
| "应用伤害并显示日志"（HERO_ACTION/ENEMY_ACTION状态） | **修正为**："应用伤害并**记录日志**（Phase 1/2输出到Console，Phase 3+输出到UI）" |

### 4.2 新增Phase分阶段说明

在 `04_battle_engine_design.md` 的"战斗状态机"章节前增加：

```markdown
## 0. 战斗画面Phase规划

| Phase | 执行模式 | 画面展示 | 进入场景 |
|:---:|:---|:---|:---:|
| 1/2 | headless同步 | 结果摘要弹窗 | 不切换 |
| 3 | 逐回合异步 | 简化回放（回合数+HP+动作摘要） | 终局战/PVP进入battle.tscn |
| 4 | 帧同步动作调度 | 完整动画（Sprite/Tween/特效/音效） | 所有战斗进入battle.tscn |

**Phase 1/2 实现约束**：
- BattleEngine.execute_battle() 为同步调用，单帧内完成
- 返回结果Dictionary供养成循环直接使用
- UI层通过结果摘要弹窗展示战斗结果，不进入battle.tscn
```

### 4.3 信号发射规范修正

Phase 1/2 中 BattleEngine 的信号发射策略：

```gdscript
# Phase 1/2: 只发射必要信号（供测试和HUD摘要使用）
EventBus.battle_started.emit([hero], enemies, config)  # 已有
EventBus.battle_ended.emit(result)  # 已有

# 以下信号Phase 1/2不发射（因为UI不监听逐帧战斗）
# EventBus.battle_turn_started.emit(turn_number)  # Phase 3+启用
# EventBus.unit_damaged.emit(damage_packet)  # Phase 3+启用
# EventBus.action_executed.emit(action_data)  # Phase 3+启用
```

---

## 五、06_ui_flow_design.md 的修正

### 5.1 battle.tscn 描述修正

| 原文 | 修正 |
|:---|:---|
| "战斗主界面：所有战斗类型共用" | "战斗回放界面：Phase 3+用于终局战和PVP回放，Phase 1/2不使用" |
| "SpeedButton（速度: 1x）" | "Phase 1/2: 此按钮隐藏。Phase 3+: 用于控制回放速度。" |
| "BattleLog（战斗日志...）" | "Phase 1/2: 此Label显示固定文本'战斗摘要'，点击后弹出结果摘要。Phase 3+: 实时滚动战斗日志。" |

### 5.2 场景清单修正

```markdown
| # | 场景路径 | 适用Phase | 场景职责 |
|---|---------|----------|---------|
| 8 | `scenes/battle/battle.tscn` | **Phase 3+** | 战斗回放界面：终局战/PVP的简化回放 |
```

---

## 六、01_module_breakdown.md 的修正

### 6.1 BattleEngine 职责修正

```
BattleEngine 职责：
  - 回合制战斗引擎核心，20回合自动战斗
  - **Phase 1/2: headless同步执行，返回结果Dictionary**
  - **Phase 3+: 支持帧同步异步执行，发射逐帧信号供UI回放**
  - 伤害公式配置驱动
```

### 6.2 BattleUI 职责（新增/修正）

```
BattleUI 职责：
  - Phase 1/2: **不活跃**，battle.tscn场景存在但不使用
  - Phase 3: 接收battle_result并显示简化回放（回合数、HP变化、动作摘要）
  - Phase 4: 完整战斗演出（Sprite动画、Tween、特效、音效）
```

---

## 七、跨文档一致性检查清单

| 检查项 | 04_battle_engine | 06_ui_flow | 01_module_breakdown | 状态 |
|:---:|:---:|:---:|:---:|:---:|
| Phase 1/2 是否headless | ✅ 是（单帧执行） | 需修正：battle.tscn不使用 | 需修正：职责描述 | ⏳ |
| Phase 3 是否有画面 | ✅ 简化回放 | 需修正：终局战/PVP进入 | 需修正：BattleUI职责 | ⏳ |
| 战斗日志显示位置 | Console（Phase 1/2） | 需修正：HUD摘要弹窗 | — | ⏳ |
| battle.tscn用途 | 预留Phase 3+ | 需修正：Phase 1/2不使用 | — | ⏳ |
| 信号发射策略 | 仅started/ended | 需修正：不监听逐帧信号 | — | ⏳ |

---

*补充文档版本：v1.0*
*日期：2026-05-09*
