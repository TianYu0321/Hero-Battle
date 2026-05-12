# 战斗动画面板布局修复任务卡（基于实际代码）

> 基于最新代码状态的精确修复，不是重写。

---

## 当前代码状态分析

### 问题1：底层UI露出（层数/金币/生命/五维属性全可见）

**根因**：`BattleAnimationPanel` 是 `RunMain` 的子节点，和其他UI（HudContainer/PlayerInfoPanel/PartnerContainer）是**兄弟节点**。`BattleAnimationPanel` 自身**没有全屏背景**（所有子节点都是透明的），`_show_modal_panel` 只隐藏了 `option_container/training_panel/rescue_panel/shop_panel/enemy_info_panel`，但**没有隐藏** `HudContainer`（层数/金币/生命）和 `PlayerInfoPanel`（五维属性）和 `PartnerContainer`（伙伴方块）。

### 问题2：回合数显示为"回合 1"（没有更新）

**根因**：`turn_label.text = "回合 %d" % turn` 中 `turn` 从 `_turn_keys` 取，但 `_turn_keys` 是事件按回合分组的键。如果 BattleEngine 的事件里没有 `turn_started` 事件，或者 `turn` 字段为0，就会显示"回合 0"或"回合 1"不变化。

实际上看代码，`_play_turn` 里：`turn_label.text = "回合 %d" % turn`，`turn` 是从 `_turn_keys[_current_turn_index]` 取的，这应该是正确的。但如果 `_turn_keys` 只有1个元素（比如[0]），那就会一直显示"回合 0"。

### 问题3：援助提示竖排/重叠

**根因**：`bottom_hint` 是 `RichTextLabel`，`append_text` 用了 `\n` 换行，导致多行文本竖向排列。且 `_show_damage_number` 的位置固定 `Vector2(450, 300)`，不会随敌人位置变化。

---

## 精确修复步骤

### Step 1：给 BattleAnimationPanel 加全屏背景（解决底层UI露出）

**文件：`scenes/run_main/battle_animation_panel.tscn`**

在 `BattleAnimationPanel` 下添加一个全屏背景节点（作为第一个子节点，在最底层）：

```
[node name="FullScreenBg" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.08, 0.08, 0.12, 1.0)    # 深蓝灰色背景
mouse_filter = 2                        # STOP，拦截所有点击
```

**关键**：
- `mouse_filter = 2`（STOP）确保点击不会穿透到底层UI
- 颜色用深蓝灰 `Color(0.08, 0.08, 0.12)`，不是纯黑，有质感
- 这是 BattleAnimationPanel 的**第一个子节点**，z-order 最低，作为背景

### Step 2：修正 _show_modal_panel，增加隐藏底层未管理的UI

**文件：`scenes/run_main/run_main.gd`**

```gdscript
func _show_modal_panel(panel: Control) -> void:
    print("[RunMain] _show_modal_panel: panel=%s" % panel.name)
    ui_modal_blocker.visible = true
    ui_modal_blocker.z_index = panel.z_index - 1 if panel.z_index > 0 else 50
    _current_ui_state = UISceneState.LOADING
    
    # 隐藏所有底层UI（包括之前没管理的）
    option_container.visible = false
    training_panel.visible = false
    rescue_panel.visible = false
    shop_panel.visible = false
    enemy_info_panel.visible = false
    
    # **新增**：隐藏之前没管理的底层UI
    $HudContainer.visible = false          # 层数/金币/生命
    $PlayerInfoPanel.visible = false       # 五维属性
    $PartnerContainer.visible = false      # 伙伴方块
    $MenuButton.visible = false            # 菜单按钮
    
    panel.visible = true
    panel.z_index = 100
    print("[RunMain] 底层UI已隐藏")
```

### Step 3：修正 _hide_modal_panel，恢复底层UI

```gdscript
func _hide_modal_panel(panel: Control) -> void:
    print("[RunMain] _hide_modal_panel: panel=%s" % panel.name)
    panel.visible = false
    ui_modal_blocker.visible = false
    
    # **新增**：恢复之前隐藏的底层UI
    $HudContainer.visible = true
    $PlayerInfoPanel.visible = true
    $PartnerContainer.visible = true
    $MenuButton.visible = true
    
    _transition_ui_state(UISceneState.OPTION_SELECT)
```

### Step 4：修正回合数显示（确保从1开始）

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
func _play_turn() -> void:
    if not _is_playing or _current_turn_index >= _turn_keys.size():
        _show_result()
        return
    
    var turn: int = _turn_keys[_current_turn_index]
    
    # **修正**：确保回合数从1开始显示，不是从0
    var display_turn: int = turn + 1 if turn == 0 else turn
    turn_label.text = "回合 %d" % display_turn
    
    ...
```

**或者更简单的方案**：如果 `_turn_keys` 里的值本身就是从1开始的（BattleEngine 的回合数从1开始），那不需要+1。如果 `turn` 是0，说明 BattleEngine 的 `turn_started` 事件里 `turn` 字段传的是0。

让我查一下 BattleEngine 的 `turn_started` 信号：

```gdscript
# battle_engine.gd 中的 _process_turn
EventBus.emit_signal("battle_turn_started", _turn_count, action_order, _playback_mode)
```

如果 `_turn_count` 初始为0，第一回合就是0。应该+1显示：

```gdscript
turn_label.text = "回合 %d" % (turn + 1)
```

### Step 5：修正伤害数字位置（从敌人/英雄头顶飘出）

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool) -> void:
    var label := Label.new()
    label.text = str(damage)
    label.add_theme_font_size_override("font_size", 32 if is_crit else 24)
    label.modulate = Color(1, 0.2, 0.2) if is_crit else Color(1, 1, 1)
    
    # **修正**：从角色占位图位置飘出，不是固定坐标
    var target_sprite: Control = enemy_sprite if is_enemy_side else hero_sprite
    var sprite_pos: Vector2 = target_sprite.global_position
    var sprite_size: Vector2 = target_sprite.size
    
    # 在角色头顶位置
    label.position = Vector2(
        sprite_pos.x + sprite_size.x / 2 - 20,  # 居中偏左
        sprite_pos.y - 10                        # 头顶上方
    )
    damage_container.add_child(label)
    
    var tween := create_tween()
    tween.tween_property(label, "position:y", label.position.y - 60, 0.6)
    tween.tween_property(label, "modulate:a", 0, 0.3)
    tween.tween_callback(label.queue_free)
```

### Step 6：修正底部提示为单行大字（不换行）

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
func _process_event(evt: Dictionary) -> void:
    ...
    match type:
        "partner_assist":
            var pname: String = data.get("partner_name", "???")
            # 用空格分隔，不用换行，保持在同一行
            bottom_hint.append_text("[color=cyan]%s 援助！[/color]  " % pname)
        
        "chain_triggered":
            var chain_count: int = data.get("chain_count", 0)
            var pname: String = data.get("partner_name", "???")
            var dmg: int = data.get("damage", 0)
            bottom_hint.append_text("[color=purple]CHAIN x%d! %s %d[/color]  " % [chain_count, pname, dmg])
```

**同时设置 BottomHint 的属性**（单行显示）：

```gdscript
# 在 tscn 中设置，或在 _ready 中设置
bottom_hint.fit_content = true
bottom_hint.scroll_active = false     # 不滚动
```

如果事件太多一行放不下，可以在每回合开始时清空：

```gdscript
func _play_turn() -> void:
    ...
    # 每回合开始时清空底部提示
    bottom_hint.text = ""
    
    for evt in events:
        _process_event(evt)
    ...
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/run_main/battle_animation_panel.tscn` | 添加 `FullScreenBg` ColorRect 全屏背景节点 |
| 2 | `scenes/run_main/run_main.gd` | `_show_modal_panel` 增加隐藏 `HudContainer`/`PlayerInfoPanel`/`PartnerContainer`/`MenuButton` |
| 3 | `scenes/run_main/run_main.gd` | `_hide_modal_panel` 增加恢复上述节点 |
| 4 | `scenes/run_main/battle_animation_panel.gd` | `_play_turn` 回合数 `turn + 1` 显示 |
| 5 | `scenes/run_main/battle_animation_panel.gd` | `_show_damage_number` 从角色占位图头顶飘出 |
| 6 | `scenes/run_main/battle_animation_panel.gd` | `_play_turn` 每回合开始时清空 `bottom_hint` |

---

## 验收标准

- [ ] 点击"战斗"后，整个屏幕被深蓝灰色背景覆盖，看不到底层任何UI（层数/金币/生命/五维/伙伴/4选项）
- [ ] 鼠标点击不会穿透到底层UI（因为 FullScreenBg 的 mouse_filter=STOP）
- [ ] 回合数正确显示（回合 1、回合 2...），不是"回合 0"
- [ ] 伤害数字从角色头顶飘出（不是固定位置）
- [ ] 底部提示单行横排，每回合开始时清空旧内容
- [ ] 点击"跳过"或战斗结束后，恢复底层所有UI
- [ ] 战斗结果面板最后才显示（不是一开始就挡住）
