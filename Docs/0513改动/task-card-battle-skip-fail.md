# Bug修复任务卡：战斗动画只播放1次 + 跳过后再战斗必失败

---

## 问题分析

**问题1：战斗画面只有我方行动一次就停下来**
说明 `_play_turn()` 或事件播放逻辑有问题，只处理了第一个事件就中断了。

**问题2：点了跳过后再战斗必定失败**
说明跳过后面板关闭、游戏状态推进、但某些关键数据（如英雄HP）被异常修改，导致第二次战斗时英雄状态不对。

---

## 诊断步骤（加print定位）

### Step 1：确认 _play_turn 为什么只播放1次

**文件：`scenes/run_main/battle_animation_panel.gd`**

在 `_play_turn()` 和 `_process_event()` 中加详细print：

```gdscript
func _play_turn() -> void:
    print("[BattleAnim] _play_turn: _is_playing=%s, _current_turn_index=%d, _turn_keys.size=%d" % [
        _is_playing, _current_turn_index, _turn_keys.size()
    ])
    
    if not _is_playing or _current_turn_index >= _turn_keys.size():
        print("[BattleAnim] 播放结束条件触发")
        _show_result()
        return
    
    var turn: int = _turn_keys[_current_turn_index]
    var events: Array = _events_by_turn[turn]
    print("[BattleAnim] 回合 %d, 事件数=%d" % [turn, events.size()])
    
    # ... 现有代码 ...
    
    for evt in events:
        print("[BattleAnim] 处理事件: type=%s" % evt["type"])
        _process_event(evt)
    
    await get_tree().create_timer(duration).timeout
    print("[BattleAnim] 定时器结束，进入下一回合")
    _current_turn_index += 1
    _play_turn()
```

**如果只看到 "处理事件: type=turn_started" 后就停了**，说明 `await get_tree().create_timer(duration).timeout` 后没有继续。可能的原因：
- `battle_animation_panel` 被隐藏/释放了
- `_is_playing` 被设为 false
- `confirmed` 信号被意外触发

### Step 2：确认跳过按钮的行为

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
func _on_skip() -> void:
    print("[BattleAnim] 跳过按钮点击")
    _is_playing = false
    _show_result()

func _show_result() -> void:
    print("[BattleAnim] _show_result")
    _is_playing = false
    result_panel.visible = true
    bottom_hint.text = ""
    if _turn_keys.size() > 0:
        bottom_hint.text = "战斗结束"
    print("[BattleAnim] result_panel.visible=%s" % result_panel.visible)
```

**确认**：跳过按钮点击后，`result_panel` 是否正确显示？还是直接关闭了？

### Step 3：确认 RunMain 中 confirmed 的处理

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _on_battle_animation_confirmed() -> void:
    print("[RunMain] _on_battle_animation_confirmed 被调用")
    
    # 先推进游戏状态
    if _run_controller != null:
        print("[RunMain] 调用 confirm_battle_result")
        _run_controller.confirm_battle_result()
    
    await get_tree().process_frame
    
    print("[RunMain] 隐藏战斗面板")
    _hide_modal_panel(battle_animation_panel)
```

**确认**：`_on_battle_animation_confirmed` 是否在跳过时被正确调用？

### Step 4：确认 confirm_battle_result 中英雄HP的处理

**文件：`scripts/systems/run_controller.gd`**

```gdscript
func confirm_battle_result() -> void:
    print("[RunController] confirm_battle_result, _pending_battle_result=%s" % _pending_battle_result)
    
    if _pending_battle_result.is_empty():
        push_error("[RunController] _pending_battle_result 为空")
        return
    
    # 打印英雄HP变化
    var hero_hp_before: int = _hero.current_hp
    
    if _pending_battle_result.has("hero"):
        var hero_stats: Dictionary = _pending_battle_result["hero"]
        _hero.current_hp = hero_stats.get("hp", _hero.current_hp)
    
    print("[RunController] 英雄HP: %d -> %d" % [hero_hp_before, _hero.current_hp])
    
    _finish_node_execution(_pending_battle_result)
    _battle_result_phase = BattleResultPhase.NONE
    _pending_battle_result = {}
```

**确认**：
- `_pending_battle_result` 是否为空？（如果为空，说明战斗结果没被保存）
- `_hero.current_hp` 是否正确更新？（如果变成0或负数，下次战斗必定失败）

### Step 5：确认第二次战斗时英雄状态

**文件：`scripts/systems/run_controller.gd`**

```gdscript
func _run_battle_engine(enemy_config_id: int) -> Dictionary:
    print("[RunController] _run_battle_engine: hero_hp=%d/%d" % [_hero.current_hp, _hero.max_hp])
    # ... 现有代码 ...
```

**确认**：第二次战斗时，`_hero.current_hp` 是否正确？（如果第一次战斗后HP被异常减少，第二次就用残血打）

---

## 可能的根因和修复

### 根因A：_pending_battle_result 为空

如果 `_run_battle_engine` 中没有把 `battle_result` 保存到 `_pending_battle_result`，`confirm_battle_result` 就会发现为空，`_finish_node_execution` 传入空字典，导致英雄HP不更新、层数不推进。

**修复**：在 `_run_battle_engine` 末尾保存结果：
```gdscript
func _run_battle_engine(enemy_config_id: int) -> Dictionary:
    # ... 执行战斗 ...
    _pending_battle_result = result  # **确保这行存在**
    return result
```

### 根因B：_on_battle_ended 中 confirm_battle_result 被重复调用

如果 `_on_battle_ended` 中既调用了 `confirm_battle_result`，`_on_battle_animation_confirmed` 中又调用了一次，第二次调用时 `_pending_battle_result` 已经空了。

**修复**：确保 `confirm_battle_result` 只调用一次。

### 根因C：跳过按钮直接 emit confirmed，跳过了 result_panel

如果 `_on_skip` 直接 emit `confirmed`（而不是显示 result_panel 等用户点击确定），`confirmed` 信号会触发 `_on_battle_animation_confirmed`，此时 `_pending_battle_result` 还在，处理正常。

但如果 `_on_skip` 只是 `_show_result()`（显示 result_panel），而 `confirmed` 只在 result_panel 的确定按钮点击时 emit，那跳过后面板显示 result_panel，用户需要再点一次确定。这是预期行为。

但如果 result_panel 的确定按钮没有正确连接 `confirmed` 信号，面板就卡住了。

---

## 快速修复尝试

### 修复1：确保 _pending_battle_result 被保存

**文件：`scripts/systems/run_controller.gd`**

在 `_run_battle_engine` 末尾确认：
```gdscript
_pending_battle_result = result  # 保存战斗结果
return result
```

### 修复2：确保 _on_battle_ended 不重复调用 confirm

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    # 不要在这里调用 confirm_battle_result
    # 只在 _on_battle_animation_confirmed 中调用
    
    _update_hud()
    
    var recorder = battle_result.get("playback_recorder", null)
    if recorder != null and recorder.get_events().size() > 0:
        battle_animation_panel.start_playback(...)
        battle_animation_panel.confirmed.connect(_on_battle_animation_confirmed, CONNECT_ONE_SHOT)
    else:
        # 无动画，直接确认
        _on_battle_animation_confirmed()
```

### 修复3：_on_battle_animation_confirmed 中处理空 _pending_battle_result

```gdscript
func _on_battle_animation_confirmed() -> void:
    print("[RunMain] _on_battle_animation_confirmed")
    
    if _run_controller != null:
        # 如果 _pending_battle_result 为空，说明已经处理过了
        if not _run_controller._pending_battle_result.is_empty():
            _run_controller.confirm_battle_result()
        else:
            print("[RunMain] _pending_battle_result 已为空，跳过 confirm")
    
    await get_tree().process_frame
    _hide_modal_panel(battle_animation_panel)
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/run_main/battle_animation_panel.gd` | 加 print 调试 _play_turn / _process_event / _on_skip |
| 2 | `scenes/run_main/run_main.gd` | 加 print 调试 _on_battle_animation_confirmed |
| 3 | `scripts/systems/run_controller.gd` | 加 print 调试 confirm_battle_result / _run_battle_engine |
| 4 | `scripts/systems/run_controller.gd` | 确保 _run_battle_engine 末尾保存 _pending_battle_result |
| 5 | `scenes/run_main/run_main.gd` | _on_battle_ended 不调用 confirm，只留给 _on_battle_animation_confirmed |

---

## 验收标准

- [ ] 战斗动画播放完整的所有回合（不是只播放1次就停）
- [ ] 点击"跳过"后，正常显示结果面板或关闭面板
- [ ] 跳过后再点击"战斗"，英雄HP正确（不是0或异常值）
- [ ] 第二次战斗能正常进行，不会必定失败
- [ ] 控制台有完整的调试print输出，方便定位问题
