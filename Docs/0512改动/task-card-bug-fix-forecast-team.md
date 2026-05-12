# Bug修复任务卡：事件透视显示 + 伙伴选择过滤

---

## Bug 1：赢了也有透视，且透视5层后一直存在

### 根因分析

**问题A：PVP胜利时也给了透视**
检查 `run_controller.gd` 的 `"pvp_result"` 分支，确认胜利时**没有**调用 `add_charges(5)`。如果代码正确，那问题B可能是主因。

**问题B：`is_active()` 判断失效，标注一直显示**
最可能的原因：`_apply_event_tag_style()` 在按钮上添加了子 Label 节点，但按钮被重用时（比如从训练面板返回选项时），旧标注没有被清理。因为 `option_buttons` 是复用的，`_apply_event_tag_style` 每次只检查 `existing_label` 并删除，但如果按钮被隐藏再显示，或者有其他代码路径绕过了清理逻辑，标注就会残留。

**问题C：`consume_charge()` 只在 `advance_floor()` 调用，但透视次数减到0后标注还在**
当 `_foresight_charges` 减到0时，`is_active()` 返回 false，`get_event_tag()` 返回空文本。但 `_apply_event_tag_style` 只在新标注非空时才清理旧标注。如果旧标注存在且新标注为空，代码没有清理旧标注。

### 修复步骤

#### Step 1：在 `_on_node_options_presented` 中强制清理旧标注

```gdscript
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    print("[RunMain] _on_node_options_presented: 选项数=%d" % node_options.size())
    _transition_ui_state(UISceneState.OPTION_SELECT)
    
    var forecast_system: EventForecastSystem = get_node_or_null("/root/RunController/EventForecastSystem")
    
    for i in range(option_buttons.size()):
        var btn: Button = option_buttons[i]
        
        # **新增**：强制清理按钮上的旧透视标注
        var old_tag = btn.get_node_or_null("EventTagLabel")
        if old_tag != null:
            old_tag.queue_free()
        
        # 恢复按钮默认颜色
        btn.remove_theme_color_override("font_color")
        
        if i < node_options.size():
            var opt = node_options[i]
            var btn_text: String = opt.get("node_name", "???")
            
            # 检查透视标注
            if forecast_system != null and forecast_system.is_active():
                var node_id: String = opt.get("node_id", "")
                var tag: Dictionary = forecast_system.get_event_tag(node_id)
                if not tag["text"].is_empty():
                    btn_text += "\n%s" % tag["text"]
                    _apply_event_tag_style(btn, tag)
            
            btn.text = btn_text
            btn.visible = true
            btn.disabled = false
        else:
            btn.text = ""
            btn.visible = false
            btn.disabled = true
    
    _update_monster_info(node_options)
```

#### Step 2：修正 `_apply_event_tag_style` 确保每次先清旧

```gdscript
func _apply_event_tag_style(btn: Button, tag: Dictionary) -> void:
    # 删除已有的标注
    var existing_label = btn.get_node_or_null("EventTagLabel")
    if existing_label != null:
        existing_label.queue_free()
    
    var tag_label := Label.new()
    tag_label.name = "EventTagLabel"
    tag_label.text = tag["text"]
    tag_label.modulate = tag["color"]
    tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    tag_label.position = Vector2(0, btn.size.y - 24)
    tag_label.custom_minimum_size = Vector2(btn.size.x, 24)
    btn.add_child(tag_label)
```

#### Step 3：确认PVP胜利时**不**给透视

检查 `run_controller.gd` 的 `"pvp_result"` 分支：

```gdscript
"pvp_result":
    ...
    if won:
        _run.gold_owned += 150
        _run.gold_earned_total += 150
        _character_manager.modify_hero_stats({1: 15, 2: 15, 3: 15, 4: 15, 5: 15})
        print("[RunController] 局内PVP胜利：金币+150，全属性+15")
        # **确保这里没有 add_charges 调用**
    else:
        _run.gold_owned += 50
        _run.gold_earned_total += 50
        _character_manager.modify_hero_stats({1: 5, 2: 5, 3: 5, 4: 5, 5: 5})
        
        var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
        if forecast_system != null:
            forecast_system.add_charges(5)
            print("[RunController] 局内PVP失败：金币+50，全属性+5，事件透视+5")
```

#### Step 4：在 `advance_floor()` 中加 print 调试

```gdscript
func advance_floor() -> void:
    _run.current_floor += 1
    print("[RunController] 推进到第%d层" % _run.current_floor)
    
    var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
    if forecast_system != null:
        print("[RunController] 透视消耗前: %d" % forecast_system.get_charges())
        forecast_system.consume_charge()
        print("[RunController] 透视消耗后: %d" % forecast_system.get_charges())
    
    EventBus.emit_signal("floor_changed", _run.current_floor, _MAX_TURNS, _get_phase_name())
```

---

## Bug 2：开局选择队友时显示未解锁伙伴

### 根因

队伍选择界面（`team_select.gd` 或类似）没有正确过滤未解锁伙伴，或者 `_load_available_partners()` 过滤逻辑失效。

### 修复步骤

#### Step 1：确认伙伴选择界面的过滤逻辑

```gdscript
func _load_available_partners() -> Array[Dictionary]:
    var player_data: Dictionary = SaveManager.load_player_data()
    var unlocked: Array = player_data.get("unlocked_partners", [])
    
    var all_partners: Array[Dictionary] = ConfigManager.get_all_partner_configs()
    var available: Array[Dictionary] = []
    
    for p in all_partners:
        var pid: String = str(p.get("id", ""))
        # 初始3个伙伴默认解锁
        var is_default: bool = pid in ["1001", "1002", "1003"]
        var is_unlocked: bool = pid in unlocked
        
        if is_default or is_unlocked:
            available.append(p)
        else:
            print("[TeamSelect] 过滤未解锁伙伴: %s" % pid)
    
    print("[TeamSelect] 可用伙伴: %d/%d" % [available.size(), all_partners.size()])
    return available
```

#### Step 2：如果伙伴选择界面渲染时绕过了过滤

检查 `_show_partner_selection` 或类似函数，确保只渲染 `available` 列表里的伙伴：

```gdscript
func _show_partner_selection() -> void:
    var available = _load_available_partners()
    
    # 清空旧按钮
    for child in partner_container.get_children():
        child.queue_free()
    
    for p in available:
        var btn := Button.new()
        btn.text = p.get("name", "???")
        ...
        partner_container.add_child(btn)
```

**禁止**：直接遍历 `ConfigManager.get_all_partner_configs()` 而不做过滤。

---

## 文件修改清单

| # | 文件 | 修改内容 | Bug |
|:---:|:---|:---|:---:|
| 1 | `scenes/run_main/run_main.gd` | `_on_node_options_presented` 强制清理旧标注 + 恢复默认颜色 | Bug 1 |
| 2 | `scenes/run_main/run_main.gd` | `_apply_event_tag_style` 确保每次先清旧 | Bug 1 |
| 3 | `scripts/systems/run_controller.gd` | `advance_floor` 加透视print调试 | Bug 1 |
| 4 | `scenes/run_main/run_main.gd` / 队伍选择脚本 | `_load_available_partners` 正确过滤未解锁伙伴 | Bug 2 |
| 5 | `scenes/run_main/run_main.gd` / 队伍选择脚本 | `_show_partner_selection` 只渲染过滤后的列表 | Bug 2 |

---

## 验收标准

### Bug 1
- [ ] PVP胜利后，透视次数不变（控制台没有"透视+"输出）
- [ ] PVP失败后，透视次数+5
- [ ] 有透视时，外出选项显示彩色标注；透视次数归0后，标注完全消失
- [ ] 从训练/救援/商店面板返回选项时，标注正确显示/隐藏（无残留）

### Bug 2
- [ ] 队伍选择界面只显示已解锁伙伴（默认3个 + 商店购买的）
- [ ] 未解锁伙伴不显示按钮
- [ ] 控制台有 `[TeamSelect] 过滤未解锁伙伴` 输出
