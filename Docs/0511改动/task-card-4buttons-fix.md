# 紧急修复：四个主按钮无法点击

> 这是新回归Bug，必须优先处理。只修改 run_main.gd 和 run_main.tscn，不改其他文件。

---

## 根因分析

四个按钮同时失效，说明不是单个按钮的问题，而是**OptionContainer 整体被遮挡**或**UIModalBlocker 拦截了全部点击**。

### 可能原因1：UIModalBlocker  stuck 在 visible=true

`_show_modal_panel()` 设 `ui_modal_blocker.visible = true`，`_hide_modal_panel()` 设 `false`。但如果 `_hide_modal_panel` 因异常未执行完，或信号未触发，blocker 就永远拦截所有点击。

### 可能原因2：ShopPanel 遮挡了 OptionContainer

ShopPanel (440,140→840,540) 和 OptionContainer (240,280→640,470) 在 X:440~640、Y:280~470 区域**大面积重叠**。如果 ShopPanel 或其子节点意外保持 visible=true，会覆盖住按钮的右侧一半到全部区域。

### 可能原因3：按钮被意外 disabled

`_on_floor_advanced()` 设 `btn.disabled = true`，但 `_on_node_options_presented()` 设 `disabled = false`。如果后者未触发或触发失败，按钮保持 disabled。

---

## 修复步骤

### Step 1：在 run_main.gd 添加 _process 安全检测

每帧检查：如果没有模态面板打开，但 UIModalBlocker 是 visible，自动隐藏它。

```gdscript
func _process(_delta: float) -> void:
    # 安全检测：UIModalBlocker 不应该在没有任何面板打开时保持 visible
    if ui_modal_blocker.visible:
        var any_modal_visible: bool = shop_panel.visible or battle_summary_panel.visible or rescue_panel.visible or training_panel.visible
        if not any_modal_visible:
            print("[RunMain] 安全检测：UIModalBlocker 异常可见，自动隐藏")
            ui_modal_blocker.visible = false
            # 同时恢复选项状态
            if _current_ui_state == UISceneState.LOADING:
                _transition_ui_state(UISceneState.OPTION_SELECT)
```

### Step 2：在 _show_modal_panel 和 _hide_modal_panel 加 print

```gdscript
func _show_modal_panel(panel: Control) -> void:
    print("[RunMain] _show_modal_panel 开始: panel=%s, blocker当前visible=%s" % [panel.name, ui_modal_blocker.visible])
    ui_modal_blocker.visible = true
    ui_modal_blocker.z_index = panel.z_index - 1 if panel.z_index > 0 else 50
    _current_ui_state = UISceneState.LOADING
    option_container.visible = false
    training_panel.visible = false
    rescue_panel.visible = false
    enemy_info_panel.visible = false
    panel.visible = true
    panel.z_index = 100
    print("[RunMain] _show_modal_panel 完成: blocker=%s, panel=%s" % [ui_modal_blocker.visible, panel.visible])

func _hide_modal_panel(panel: Control) -> void:
    print("[RunMain] _hide_modal_panel 开始: panel=%s" % panel.name)
    panel.visible = false
    ui_modal_blocker.visible = false
    _transition_ui_state(UISceneState.OPTION_SELECT)
    print("[RunMain] _hide_modal_panel 完成: blocker=%s, option_container=%s" % [ui_modal_blocker.visible, option_container.visible])
```

### Step 3：在按钮回调里加 print

```gdscript
func _on_node_button_pressed(index: int) -> void:
    print("[RunMain] 按钮被点击: index=%d, RunController=%s" % [index, _run_controller != null])
    if _run_controller == null:
        push_warning("[RunMain] RunController not available")
        return
    _run_controller.select_node(index)
```

### Step 4：在 _on_node_options_presented 里加 print 并强制启用按钮

```gdscript
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    print("[RunMain] _on_node_options_presented: 选项数=%d, 当前blocker=%s" % [node_options.size(), ui_modal_blocker.visible])
    _transition_ui_state(UISceneState.OPTION_SELECT)
    
    for i in range(option_buttons.size()):
        if i < node_options.size():
            var opt = node_options[i]
            option_buttons[i].text = opt.get("node_name", "???")
            option_buttons[i].visible = true
            option_buttons[i].disabled = false
        else:
            option_buttons[i].visible = false
            option_buttons[i].disabled = true
    
    # 强制确保 OptionContainer 和按钮可见且可交互
    option_container.visible = true
    for btn in option_buttons:
        btn.visible = true
        btn.disabled = false
    
    print("[RunMain] 按钮状态: option_container=%s, 按钮1disabled=%s, 按钮2disabled=%s" % [
        option_container.visible,
        option_buttons[0].disabled,
        option_buttons[1].disabled
    ])
    
    _update_monster_info(node_options)
```

### Step 5：确保 _transition_ui_state 恢复按钮时不受 LOADING 状态影响

当前 `_transition_ui_state` 在 state=OPTION_SELECT 时只设 `option_container.visible = true`，不控制按钮 disabled 状态。这没问题。但如果 `_current_ui_state` 已经是 LOADING（被 `_show_modal_panel` 设置），`_hide_modal_panel` 调 `_transition_ui_state(OPTION_SELECT)` 会正确恢复。

问题是：如果 `_hide_modal_panel` 没被调用，`_current_ui_state` 永远卡在 LOADING，而 `_process` 安全检测会自动恢复。

---

## 备选方案：如果上述修复后仍有问题

如果 Step 1~5 加完后按钮仍然无法点击，请检查控制台输出：

1. 如果看到 `_show_modal_panel` 的输出但没有对应的 `_hide_modal_panel`，说明某个面板打开后没关闭
2. 如果看到 `按钮被点击` 的 print 但 RunController 为 null，说明 RunController 未初始化
3. 如果看不到 `按钮被点击`，说明点击事件根本没到达按钮

如果点击事件没到达按钮，在 `_input` 里加全局点击检测：

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        print("[RunMain] 全局点击检测: pos=%s, blocker=%s, shop=%s, option=%s" % [
            event.position,
            ui_modal_blocker.visible,
            shop_panel.visible,
            option_container.visible
        ])
    if event.is_action_pressed("ui_cancel"):
        ...
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/run_main/run_main.gd` | 添加 `_process` 安全检测 |
| 2 | `scenes/run_main/run_main.gd` | `_show_modal_panel` / `_hide_modal_panel` 加 print |
| 3 | `scenes/run_main/run_main.gd` | `_on_node_button_pressed` 加 print |
| 4 | `scenes/run_main/run_main.gd` | `_on_node_options_presented` 加 print + 强制启用按钮 |
| 5 | `scenes/run_main/run_main.gd` | `_input` 加全局点击检测（备选） |

---

## 验收标准

- [ ] 启动游戏后，4个选项按钮可见且可点击
- [ ] 点击按钮后控制台有 `[RunMain] 按钮被点击: index=X` 输出
- [ ] 如果 blocker 异常可见，`_process` 自动检测并恢复
