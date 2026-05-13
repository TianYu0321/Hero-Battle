# Bug修复任务卡：精英战斗后选项消失

> 问题：外出碰到精英 → 战斗动画 → 点击跳过 → 结果面板 → 点击确定 → 4个选项消失

---

## 根因分析

执行顺序问题：

当前 `_on_battle_animation_confirmed`：
```
1. _hide_modal_panel(battle_animation_panel)
   → option_container.visible = true（按钮显示，但text仍是上一层的"..."）
2. confirm_battle_result()
   → _finish_node_execution → advance_turn()
   → floor_advanced信号 → _on_floor_advanced
   → 按钮text = "...", disabled = true（覆盖第1步的内容）
   → _generate_node_options → node_options_presented → _on_node_options_presented
   → 按钮恢复正常
```

正常情况下 `_on_node_options_presented` 会在1帧内恢复按钮。但如果：
1. `_generate_node_options` 因为某种原因延迟执行
2. 或者 `_on_node_options_presented` 没有收到信号
3. 按钮就会一直保持 "..." + disabled，看起来像"消失了"

另一个可能：`result_panel` 的确定按钮点击后，`confirmed` 信号触发 `_on_battle_animation_confirmed`。但 `result_panel` 在 `battle_animation_panel` 内部。如果 `result_panel` 的确定按钮和 `skip_button` 同时存在交互冲突，可能导致 `confirmed` 信号异常。

## 修复方案

### 修复1：调整 _on_battle_animation_confirmed 执行顺序

先推进游戏状态（生成新选项），再隐藏面板。这样按钮在面板隐藏前就已经恢复正常。

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _on_battle_animation_confirmed() -> void:
    print("[RunMain] 战斗动画确认关闭")
    
    # **修正**：先推进游戏状态，再隐藏面板
    if _run_controller != null:
        _run_controller.confirm_battle_result()
    
    # 等一帧确保 node_options_presented 信号处理完成
    await get_tree().process_frame
    
    _hide_modal_panel(battle_animation_panel)
```

### 修复2：在 _on_node_options_presented 中增加强制刷新

确保即使 `_transition_ui_state` 被多次调用，按钮最终状态正确。

```gdscript
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    print("[RunMain] _on_node_options_presented: 选项数=%d" % node_options.size())
    _transition_ui_state(UISceneState.OPTION_SELECT)
    
    # ... 现有代码 ...
    
    # **新增**：强制确保按钮最终状态正确（防御性）
    for i in range(option_buttons.size()):
        if i < node_options.size():
            var opt = node_options[i]
            option_buttons[i].text = opt.get("node_name", "???")
            option_buttons[i].visible = true
            option_buttons[i].disabled = false
        else:
            option_buttons[i].text = ""
            option_buttons[i].visible = false
            option_buttons[i].disabled = true
    
    option_container.visible = true
    print("[RunMain] 按钮强制刷新完成")
```

### 修复3：在 _on_floor_advanced 中不要覆盖按钮文本

`_on_floor_advanced` 设置 `btn.text = "..."` 是为了提示"正在加载新选项"。但如果 `_on_node_options_presented` 很快会被调用，这个中间状态很短。如果 `_on_node_options_presented` 没有调用，按钮就会一直显示 "..."。

改为不覆盖文本，只禁用按钮：

```gdscript
func _on_floor_advanced(_new_floor: int, _floor_type: String, _is_special: bool) -> void:
    # 只禁用按钮，不覆盖文本（保留上一层的文本，避免闪烁）
    for btn in option_buttons:
        btn.disabled = true
```

### 修复4：增加调试输出确认信号链路

在关键位置加 print，确认 `_on_node_options_presented` 是否被调用：

```gdscript
# run_controller.gd 的 advance_turn
func advance_turn() -> void:
    if _state != RunState.TURN_ADVANCE:
        return
    _run.current_turn += 1
    ...
    EventBus.emit_signal("floor_advanced", _run.current_turn, _MAX_TURNS, _get_phase_name())
    print("[RunController] floor_advanced 信号已发射")
    _change_state(RunState.RUNNING_NODE_SELECT)
    print("[RunController] RUNNING_NODE_SELECT, _generate_node_options 即将调用")

# run_controller.gd 的 _generate_node_options
func _generate_node_options() -> void:
    ...
    print("[RunController] _generate_node_options: 选项数=%d" % _current_node_options.size())
    EventBus.emit_signal("node_options_presented", _current_node_options)
    print("[RunController] node_options_presented 信号已发射")
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/run_main/run_main.gd` | `_on_battle_animation_confirmed` 先 `confirm_battle_result` 再 `_hide_modal_panel` |
| 2 | `scenes/run_main/run_main.gd` | `_on_node_options_presented` 末尾增加按钮强制刷新 |
| 3 | `scenes/run_main/run_main.gd` | `_on_floor_advanced` 不覆盖按钮文本，只禁用 |
| 4 | `scripts/systems/run_controller.gd` | `advance_turn` / `_generate_node_options` 增加调试print |

---

## 验收标准

- [ ] 外出碰到精英 → 战斗动画 → 点击跳过 → 结果面板 → 点击确定
- [ ] 确定后4个选项正常显示（不是 "..."）
- [ ] 控制台有 `[RunController] node_options_presented 信号已发射` 输出
- [ ] 控制台有 `[RunMain] _on_node_options_presented: 选项数=4` 输出
