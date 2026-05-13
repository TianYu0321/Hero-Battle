# Bug修复任务卡：普通战斗/PVP没有战斗动画

> 问题：只有精英战斗有动画，普通战斗和PVP没有

---

## 根因分析

战斗动画的触发链路：

```
1. 玩家点击"战斗"或"PVP"
2. RunController._process_node_result → _run_battle_engine()
3. _run_battle_engine 中创建 BattlePlaybackRecorder，订阅信号
4. BattleEngine.execute_battle() 执行战斗（同步）
5. battle_result 中附带 playback_recorder
6. RunMain._on_battle_ended 读取 playback_recorder
7. 如果有 recorder → 播放 BattleAnimationPanel
8. 如果没有 recorder → fallback 到 BattleSummaryPanel
```

**只有精英战斗有动画**，说明：
- 精英战斗走了不同的代码路径（可能是 `node_resolver.gd` 的 `_resolve_battle`），这个路径直接发射了 `battle_ended` 信号，或者绕过了 `_run_battle_engine`
- 普通战斗和PVP可能走了 `_run_battle_engine`，但 `battle_result` 中没有 `playback_recorder` 字段，导致 RunMain fallback 到摘要面板

**最可能的原因**：
1. `_run_battle_engine` 中没有创建 `BattlePlaybackRecorder`
2. 或者创建了但没有把 `recorder` 放进 `battle_result`
3. 或者 `_on_battle_ended` 中 `battle_result.get("playback_recorder")` 返回 null

---

## 检查清单（代码端Agent执行）

### 检查1：_run_battle_engine 中是否创建了 Recorder

**文件：`scripts/systems/run_controller.gd`**

搜索 `_run_battle_engine` 方法，确认以下内容存在：

```gdscript
func _run_battle_engine(enemy_config_id: int) -> Dictionary:
    ...
    var battle_engine: BattleEngine = BattleEngine.new()
    add_child(battle_engine)
    
    # 必须有这段代码：
    var recorder := BattlePlaybackRecorder.new()
    recorder.name = "PlaybackRecorder"
    add_child(recorder)
    recorder.start_recording()
    
    # 必须有信号订阅：
    EventBus.battle_turn_started.connect(...)
    EventBus.action_executed.connect(...)
    EventBus.unit_damaged.connect(...)
    ...
    
    var result = battle_engine.execute_battle(battle_config)
    
    # 必须有这段代码：
    recorder.stop_recording()
    result["playback_recorder"] = recorder
    
    battle_engine.queue_free()
    return result
```

**如果缺少**：补充 Recorder 创建和信号订阅代码。

### 检查2：_on_battle_ended 中是否正确读取 recorder

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    var recorder: BattlePlaybackRecorder = battle_result.get("playback_recorder", null)
    
    if recorder != null and recorder.get_events().size() > 0:
        # 播放动画
        battle_animation_panel.start_playback(...)
    else:
        # fallback 到摘要
        battle_summary_panel.show_result(battle_result)
```

**在 recorder 为 null 的位置加 print 调试**：

```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    print("[RunMain] _on_battle_ended, keys=%s" % battle_result.keys())
    var recorder = battle_result.get("playback_recorder", null)
    print("[RunMain] recorder=%s, is_null=%s" % [recorder, recorder == null])
```

### 检查3：普通战斗和精英战斗的路径差异

**精英战斗路径**（外出碰到精英）：
- `node_resolver.gd` → `_resolve_battle()` → 可能直接调用了 `BattleEngine`，绕过了 `run_controller.gd` 的 `_run_battle_engine`
- 如果精英战斗有动画，说明精英战斗的路径创建了 Recorder

**普通战斗/PVP路径**：
- `run_controller.gd` → `_process_node_result` → `_run_battle_engine()`
- 检查这两个路径是否一致

---

## 修复步骤

### 修复1：确保 _run_battle_engine 创建 Recorder

如果 `_run_battle_engine` 缺少 Recorder 创建代码，补充：

```gdscript
func _run_battle_engine(enemy_config_id: int) -> Dictionary:
    var battle_engine: BattleEngine = BattleEngine.new()
    battle_engine.name = "BattleEngine"
    add_child(battle_engine)
    
    # --- 创建回放记录器 ---
    var recorder := BattlePlaybackRecorder.new()
    recorder.name = "PlaybackRecorder"
    add_child(recorder)
    recorder.start_recording()
    
    # --- 订阅信号 ---
    var _on_turn_started = func(turn, order, mode):
        recorder.record_event("turn_started", {"turn": turn, "order": order})
    EventBus.battle_turn_started.connect(_on_turn_started)
    
    var _on_action_executed = func(action_data):
        recorder.record_event("action_executed", action_data)
    EventBus.action_executed.connect(_on_action_executed)
    
    var _on_unit_damaged = func(unit_id, damage, hp, max_hp, dmg_type, is_crit, is_miss, attacker_id):
        recorder.record_event("unit_damaged", {
            "unit_id": unit_id, "damage": damage, "hp": hp, "max_hp": max_hp,
            "is_crit": is_crit, "is_miss": is_miss, "attacker_id": attacker_id,
        })
    EventBus.unit_damaged.connect(_on_unit_damaged)
    
    var _on_unit_died = func(unit_id, name, unit_type, killer_id):
        recorder.record_event("unit_died", {"unit_id": unit_id, "name": name})
    EventBus.unit_died.connect(_on_unit_died)
    
    var _on_partner_assist = func(pid, pname, trigger_type, assist_data, chain_count):
        recorder.record_event("partner_assist", {"partner_name": pname})
    EventBus.partner_assist_triggered.connect(_on_partner_assist)
    
    var _on_chain_triggered = func(chain_count, partner_id, partner_name, damage, multiplier, total_chains):
        recorder.record_event("chain_triggered", {
            "chain_count": chain_count, "partner_name": partner_name, "damage": damage,
        })
    EventBus.chain_triggered.connect(_on_chain_triggered)
    
    var _on_ultimate_triggered = func(hero_id, hero_name, turn, skill_id, log_text):
        recorder.record_event("ultimate_triggered", {"hero_name": hero_name, "log": log_text})
    EventBus.ultimate_triggered.connect(_on_ultimate_triggered)
    
    # 执行战斗
    var result = battle_engine.execute_battle(battle_config)
    
    # --- 断开信号 ---
    EventBus.battle_turn_started.disconnect(_on_turn_started)
    EventBus.action_executed.disconnect(_on_action_executed)
    EventBus.unit_damaged.disconnect(_on_unit_damaged)
    EventBus.unit_died.disconnect(_on_unit_died)
    EventBus.partner_assist_triggered.disconnect(_on_partner_assist)
    EventBus.chain_triggered.disconnect(_on_chain_triggered)
    EventBus.ultimate_triggered.disconnect(_on_ultimate_triggered)
    
    recorder.stop_recording()
    result["playback_recorder"] = recorder
    
    battle_engine.queue_free()
    return result
```

### 修复2：统一所有战斗路径

如果精英战斗走了不同的路径（比如 `node_resolver.gd` 直接调 BattleEngine），需要：
- **方案A**：把精英战斗也接入 `_run_battle_engine`（推荐，统一入口）
- **方案B**：在精英战斗路径中也创建 Recorder（重复代码，不推荐）

检查 `node_resolver.gd` 的 `_resolve_battle` 或 `resolve_node` 中，精英战斗是如何调用的：

```gdscript
# node_resolver.gd
func _resolve_battle(node_data, hero, config_id, turn_number):
    # 如果这里直接 new BattleEngine() 并 execute_battle
    # 改为调用 run_controller 的 _run_battle_engine
    # 或者在这里也创建 Recorder
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/systems/run_controller.gd` | 确认/补充 `_run_battle_engine` 中 Recorder 创建和信号订阅 |
| 2 | `scenes/run_main/run_main.gd` | `_on_battle_ended` 中加 print 调试 recorder 状态 |
| 3 | `scripts/systems/node_resolver.gd`（如需要）| 精英战斗路径统一接入 `_run_battle_engine` |

---

## 验收标准

- [ ] 普通战斗点击"战斗"后，弹出 BattleAnimationPanel（不是直接显示摘要）
- [ ] PVP 点击"PVP对战"后，弹出 BattleAnimationPanel
- [ ] 精英战斗保持有动画（不要破坏已有功能）
- [ ] 控制台有 `[RunMain] recorder=...` 输出（验证 recorder 存在）
