# Bug修复任务卡：战斗动画卡住 + 跳过导致异常

> 问题1：动画只播放1回合就停
> 问题2：跳过14回合战斗后，15回合UI异常

---

## 根因分析

### 问题1：_play_turn 的 await 机制不可靠

当前用 `await get_tree().create_timer(duration).timeout` 创建**无法取消**的异步定时器。即使加了 `_playback_generation` 隔离，GDScript 的 `await` 在节点隐藏/场景切换/信号冲突时仍可能行为异常。

**更深层问题**：`await` 创建的协程如果被打断，`_play_turn()` 不会继续执行，动画就"卡住"在第1回合。

### 问题2：跳过后旧状态残留

跳过后面板关闭，但：
- `result_panel.visible` 可能仍保持 true
- `bottom_hint.text` 残留"战斗结束"
- 旧战斗的 `confirmed` 信号连接可能没被正确断开
- 新战斗开始时这些残留状态覆盖了正常UI

---

## 修复方案：用 Timer 节点替代 await

**核心改动**：把 `await get_tree().create_timer(...)` 改成场景内的 `Timer` 节点，可以被显式 `stop()`。

### Step 1：tscn 添加 Timer 节点

**文件：`scenes/run_main/battle_animation_panel.tscn`**

在 `BattleAnimationPanel` 下添加：

```
[node name="TurnTimer" type="Timer" parent="."]
one_shot = true
```

### Step 2：gd 改用 Timer 节点

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
@onready var turn_timer: Timer = $TurnTimer

func _ready() -> void:
    # ... 现有代码 ...
    turn_timer.timeout.connect(_on_turn_timer_timeout)

func start_playback(...) -> void:
    _recorder = recorder
    _events_by_turn = recorder.get_events_by_turn()
    _turn_keys = _events_by_turn.keys()
    _current_turn_index = 0
    _is_playing = true
    visible = true
    
    # **关键**：完全重置面板状态
    result_panel.visible = false
    bottom_hint.text = ""
    _clear_damage_numbers()  # 清理残留的伤害数字
    
    # ... 其他初始化 ...
    _play_turn()

func _play_turn() -> void:
    if not _is_playing or _current_turn_index >= _turn_keys.size():
        _show_result()
        return
    
    var turn: int = _turn_keys[_current_turn_index]
    var events: Array = _events_by_turn[turn]
    turn_label.text = "回合 %d" % (turn + 1 if turn == 0 else turn)
    
    # 计算时长
    var partner_events: int = 0
    for evt in events:
        if evt["type"] in ["partner_assist", "chain_triggered"]:
            partner_events += 1
    var duration: float = _turn_duration + partner_events * 0.5
    
    # 播放本回合事件
    for evt in events:
        _process_event(evt)
    
    # **关键**：用 Timer 节点，可以被 stop()
    turn_timer.start(duration)

func _on_turn_timer_timeout() -> void:
    if not _is_playing:
        return
    _current_turn_index += 1
    _play_turn()

func _on_skip() -> void:
    print("[BattleAnim] 跳过")
    _is_playing = false
    turn_timer.stop()  # **关键**：停止定时器
    _show_result()

func _show_result() -> void:
    _is_playing = false
    turn_timer.stop()  # 保险：再次停止
    result_panel.visible = true
    bottom_hint.text = ""
    if _turn_keys.size() > 0:
        bottom_hint.text = "战斗结束"

# **新增**：清理残留的伤害数字节点
func _clear_damage_numbers() -> void:
    for child in damage_container.get_children():
        child.queue_free()

# **新增**：完全重置面板（新战斗开始前调用）
func reset_panel() -> void:
    _is_playing = false
    turn_timer.stop()
    _current_turn_index = 0
    _turn_keys = []
    _events_by_turn = {}
    result_panel.visible = false
    bottom_hint.text = ""
    turn_label.text = "回合 1"
    _clear_damage_numbers()
    # 重置血条到满血（由 start_playback 重新设置）
```

### Step 3：RunMain 新战斗前调用 reset_panel

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    _update_hud()
    
    var recorder = battle_result.get("playback_recorder", null)
    
    if recorder != null and recorder.get_events().size() > 0:
        # **关键**：新战斗前完全重置面板
        battle_animation_panel.reset_panel()
        
        battle_animation_panel.start_playback(
            recorder,
            battle_result.get("hero", {}).get("name", "英雄"),
            battle_result.get("enemies", [{}])[0].get("name", "敌人"),
            battle_result.get("hero", {}).get("max_hp", 100),
            battle_result.get("enemies", [{}])[0].get("max_hp", 100),
            [], []
        )
        battle_animation_panel.confirmed.connect(_on_battle_animation_confirmed, CONNECT_ONE_SHOT)
    else:
        battle_summary_panel.show_result(battle_result)
        battle_summary_panel.confirmed.connect(_on_battle_summary_confirmed, CONNECT_ONE_SHOT)
```

### Step 4：_on_battle_animation_confirmed 中确保信号只连接一次

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _on_battle_animation_confirmed() -> void:
    print("[RunMain] _on_battle_animation_confirmed")
    
    # 断开信号（保险）
    if battle_animation_panel.confirmed.is_connected(_on_battle_animation_confirmed):
        battle_animation_panel.confirmed.disconnect(_on_battle_animation_confirmed)
    
    if _run_controller != null:
        _run_controller.confirm_battle_result()
    
    await get_tree().process_frame
    _hide_modal_panel(battle_animation_panel)
```

### Step 5：result_panel 的确定按钮确保只 emit 一次 confirmed

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
var _result_emitted: bool = false  # 标记 confirmed 是否已发射

func _show_result() -> void:
    _is_playing = false
    turn_timer.stop()
    
    if _result_emitted:
        return  # 已发射过，不再重复
    _result_emitted = true
    
    result_panel.visible = true
    bottom_hint.text = ""
    if _turn_keys.size() > 0:
        bottom_hint.text = "战斗结束"

func start_playback(...) -> void:
    _result_emitted = false  # 新播放时重置
    # ...
```

---

## 验收标准

- [ ] 普通战斗（非精英）显示完整动画，所有回合依次播放
- [ ] 动画不卡顿，每回合2秒基础时长正常
- [ ] 点击"跳过"后，动画立即停止，显示结果面板
- [ ] 跳过后进入下一层，4个选项正常显示
- [ ] 再次遇到战斗（同一局或新局），动画从头正常播放
- [ ] 连续跳过多次战斗，游戏状态正常（HP、金币、层数正确）
