# 任务卡：爬塔场景旧UI残留清理 + 顶部HUD现代化改造

## 背景

战斗面板已改为独立 `battle_scene.tscn`，所有战斗相关UI（战斗确认、战斗动画回放、战斗结算）都已迁移出 `run_main`。但 `run_main.gd` 和 `run_main.tscn` 中仍残留大量旧的战斗相关节点引用和旧的HUD样式（深色底色）。

同时，旧的 `PlayerInfoPanel`（五维标签垂直排列）已被新的顶部信息栏 + 底部伙伴CHAIN条替代。

本任务清理残留、统一风格为明亮纸片剧场。

---

## 当前残留节点分析

```
RunMain (Control)
├── HudContainer              # 顶部信息栏（层数/金币/生命）— 保留，改样式
├── PlayerInfoPanel           # 左侧五维属性 — 删除，功能合并到顶部HUD
├── EnemyInfoPanel            # 敌人信息 — 保留（剪影预览用），确保正确隐藏
├── OptionContainer           # 4个选项按钮 — 保留
├── CombatConfirmPanel        # 旧战斗确认 — 删除（已迁移到battle_scene）
├── BattleAnimationPanel      # 旧战斗动画回放 — 删除（已迁移到battle_scene）
├── BattleSummaryPanel        # 旧战斗结算 — 删除（已迁移到battle_scene）
├── PartnerHUDLayer/PartnerPanel  # 伙伴CHAIN — 保留，改明亮样式
├── TrainingPanel             # 训练面板 — 保留
├── ShopPanel                 # 商店面板 — 保留
├── RescuePopup               # 营救弹窗 — 保留
├── OutingPopup               # 外出事件 — 保留
├── PauseMenu                 # 暂停菜单 — 保留
└── UIModalBlocker            # 模态遮罩 — 保留
```

---

## Step 1：删除/注释旧战斗节点引用

### run_main.gd — 删除以下 @onready 引用

```gdscript
## 删除这些已迁移到 battle_scene 的引用：
# @onready var battle_animation_panel: BattleAnimationPanel = $BattleAnimationPanel
# @onready var battle_summary_panel = $BattleSummaryPanel
# @onready var combat_confirm_panel: Panel = $CombatConfirmPanel
# @onready var enter_combat_button: Button = $CombatConfirmPanel/EnterCombatButton
# @onready var return_button: Button = $CombatConfirmPanel/ReturnButton

## 删除战斗确认相关的信号绑定（在 _ready() 中）：
# enter_combat_button.pressed.disconnect(_on_combat_confirmed)
# return_button.pressed.disconnect(_on_combat_cancelled)

## 删除 _on_combat_confirmed() 和 _on_combat_cancelled() 函数
## 删除 _show_combat_preview() 中关于 combat_confirm_panel 的操作
## 删除 _on_battle_ended() 中关于 battle_animation_panel 和 battle_summary_panel 的操作
```

### 具体修改 `_show_combat_preview()`

```gdscript
## 原 _show_combat_preview 保留 EnemyInfoPanel 剪影预览
## 但删除 CombatConfirmPanel 相关操作，改为直接触发战斗

func _show_combat_preview(opt: Dictionary, index: int) -> void:
    _combat_selected_index = index
    option_container.visible = false
    
    ## 显示敌人剪影预览（半透明）
    var enemy_cfg: Dictionary = opt.get("enemy_config", {})
    if enemy_cfg.is_empty() and not _cached_enemy_data.is_empty():
        enemy_cfg = _cached_enemy_data
    
    if not enemy_cfg.is_empty():
        enemy_info_panel.visible = true
        enemy_info_panel.modulate = Color(1, 1, 1, 0.6)
        update_enemy_info(enemy_cfg)
        enemy_hp_label.text = "HP: ???"
        predicted_damage_label.text = ""
        
        ## 风险预测
        var hero_stats: Dictionary = _get_current_hero_stats()
        var prediction: Dictionary = DamagePredictor.predict_battle_outcome(
            _get_current_hero_hp(), hero_stats, enemy_cfg
        )
        var risk: String = prediction.get("risk_level", "unknown")
        risk_label.text = DamagePredictor.get_risk_display_text(risk)
        risk_label.modulate = DamagePredictor.get_risk_color(risk)
    else:
        enemy_info_panel.visible = false
    
    ## 删除：partner_panel.visible = false
    ## 删除：combat_confirm_panel.visible = true
    
    ## 新增：直接确认并进入战斗（不需要确认面板）
    ## 或者添加一个简单确认对话框（可用ConfirmationDialog）
    _enter_combat_directly(index)

func _enter_combat_directly(index: int) -> void:
    ## 先隐藏敌人信息面板
    enemy_info_panel.visible = false
    
    ## 使用 TransitionManager 切换到战斗场景
    _combat_selected_index = index
    
    ## 缓存敌人数据供 battle_scene 使用
    GameManager.current_battle = {
        "node_index": index,
        "enemy_config": _cached_enemy_data,
    }
    
    ## 调用 RunController 处理战斗逻辑
    _run_controller.select_node(index)
    _combat_selected_index = -1
```

### 具体修改 `_on_battle_ended()`

```gdscript
## 原 _on_battle_ended 处理战斗动画回放和结算面板
## 现在 battle_scene 已处理完所有战斗表现和结算
## run_main 只需要接收结果并更新HUD

func _on_battle_ended(battle_result: Dictionary) -> void:
    partner_panel.visible = true  # 恢复伙伴面板显示
    
    print("[RunMain] 战斗结束: winner=%s, turns=%d" % [
        battle_result.get("winner", "???"),
        battle_result.get("turns_elapsed", 0)
    ])
    
    ## 更新HUD（战斗后的最终状态）
    _update_hud()
    
    ## 推进游戏状态
    if _run_controller != null:
        _run_controller.confirm_battle_result()
    
    ## 清理
    _pending_battle_result = {}
    
    ## 处理缓存的选项
    if _cached_node_options.size() > 0:
        var cached = _cached_node_options.duplicate()
        _cached_node_options.clear()
        _on_node_options_presented(cached)

## 删除以下函数：
# func _on_battle_animation_finished()
# func _show_battle_summary()
# func _on_battle_summary_confirmed()
```

---

## Step 2：删除 PlayerInfoPanel（五维标签）

```gdscript
## 删除 @onready 引用：
# @onready var player_vit_label: Label = $PlayerInfoPanel/PlayerVitLabel
# @onready var player_str_label: Label = $PlayerInfoPanel/PlayerStrLabel
# @onready var player_agi_label: Label = $PlayerInfoPanel/PlayerAgiLabel
# @onready var player_tec_label: Label = $PlayerInfoPanel/PlayerTecLabel
# @onready var player_mnd_label: Label = $PlayerInfoPanel/PlayerMndLabel

## 删除 _update_hud() 中的五维更新：
## 原：
## player_vit_label.text = "体魄: %d" % hero_data.get("current_vit", 0)
## player_str_label.text = "力量: %d" % hero_data.get("current_str", 0)
## ...

## 改为：五维信息只在战斗场景显示，或只在训练/详情弹窗中显示
## 爬塔主场景只显示：层数、金币、生命、伙伴CHAIN
```

---

## Step 3：HudContainer 现代化改造（明亮纸片剧场风格）

```gdscript
## _update_hud() 改造：只保留核心信息

func _update_hud() -> void:
    if _run_controller == null:
        return
    
    var summary: Dictionary = _run_controller.get_current_run_summary()
    var current_turn: int = summary.get("current_turn", 1)
    var gold: int = summary.get("gold", 0)
    var hero_data: Dictionary = summary.get("hero", {})
    var current_hp: int = hero_data.get("current_hp", 100)
    var max_hp: int = hero_data.get("max_hp", 100)
    
    ## 更新顶部HUD文本
    floor_label.text = "第 %d 层" % current_turn
    gold_label.text = "%d" % gold
    hp_label.text = "%d / %d" % [current_hp, max_hp]
    
    ## 删除五维标签更新
    
    ## 更新伙伴CHAIN
    _update_partner_hud()

## 更新 _on_stats_changed：只更新HP（其他属性在训练面板中查看）
func _on_stats_changed(_unit_id: String, stat_changes: Dictionary) -> void:
    for attr_code in stat_changes.keys():
        var change: Dictionary = stat_changes[attr_code]
        match int(attr_code):
            0:  # HP
                var new_hp: int = change.get("new", 0)
                var max_hp: int = change.get("max_hp", 0)
                if max_hp <= 0:
                    var summary = _run_controller.get_current_run_summary() if _run_controller != null else {}
                    var hero_data = summary.get("hero", {})
                    max_hp = hero_data.get("max_hp", 100)
                hp_label.text = "%d / %d" % [new_hp, max_hp]
            ## 删除：1~5（五维属性）不在主HUD更新
```

### HudContainer 节点结构改造

```
HudContainer (PanelContainer) — 改为HBoxContainer横向排列
├── FloorGroup (HBoxContainer)
│   ├── FloorIcon (TextureRect) — 小图标
│   └── FloorLabel (Label) — "第 X 层"
├── Spacer — 弹性空间
├── HpGroup (HBoxContainer)
│   ├── HeartIcon (TextureRect) — 心形HP图标
│   ├── HpLabel (Label) — "120 / 200"
│   └── HpBar (ProgressBar) — 可选，小血条
├── Spacer — 弹性空间
├── GoldGroup (HBoxContainer)
│   ├── GoldIcon (TextureRect) — 金币图标
│   └── GoldLabel (Label) — "150"
└── PauseButton (Button) — "||"
```

### HudContainer 样式改造（明亮风格）

```gdscript
func _setup_hud_style() -> void:
    var hud: PanelContainer = $HudContainer
    
    ## 白底+灰边+下圆角+阴影
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 0.95)
    style.border_color = Color(0.85, 0.85, 0.85, 1.0)
    style.border_width_left = 0
    style.border_width_top = 0
    style.border_width_right = 0
    style.border_width_bottom = 2
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = Color(0, 0, 0, 0.08)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0, 2)
    hud.add_theme_stylebox_override("panel", style)
    
    hud.custom_minimum_size = Vector2(0, 48)
    
    ## 各标签字体颜色
    floor_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
    floor_label.add_theme_font_size_override("font_size", 16)
    
    hp_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))  # 红色HP
    hp_label.add_theme_font_size_override("font_size", 14)
    
    gold_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15, 1))  # 金色
    gold_label.add_theme_font_size_override("font_size", 16)
```

---

## Step 4：EnemyInfoPanel 清理和更新

```gdscript
## EnemyInfoPanel 只在 _show_combat_preview 时短暂显示剪影
## 确保进入战斗后、返回选项后、面板打开时都被隐藏

## _transition_ui_state 中已有：
## enemy_info_panel.visible = false ✅

## _on_panel_opened 中已有：
## enemy_info_panel.visible = false ✅

## 战斗结束后恢复：
## _on_battle_ended 中已有 partner_panel.visible = true
## 添加 enemy_info_panel.visible = false（确保）

## EnemyInfoPanel 样式改为明亮：
func _setup_enemy_info_style() -> void:
    var panel: VBoxContainer = $EnemyInfoPanel
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 0.9)
    style.border_color = Color(0.85, 0.85, 0.85, 1.0)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = Color(0, 0, 0, 0.1)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 3)
    panel.add_theme_stylebox_override("panel", style)
```

---

## Step 5：PartnerPanel 伙伴CHAIN改为明亮风格

```gdscript
func _init_partner_slots() -> void:
    var partner_list: HBoxContainer = partner_panel.get_node("PartnerList")
    for child in partner_list.get_children():
        if child.name != "PartnerTitle":
            child.queue_free()
    _partner_slots.clear()
    
    for i in range(_max_partner_slots):
        var slot := _create_partner_slot(i)
        partner_list.add_child(slot)
        _partner_slots.append(slot)
        slot.visible = false
    
    ## PartnerPanel 背景样式 — 改为明亮纸片剧场
    var panel_bg := StyleBoxFlat.new()
    panel_bg.bg_color = Color(1.0, 1.0, 1.0, 0.92)       ## 纯白底（替代旧的深色 0.18,0.14,0.10）
    panel_bg.border_color = Color(0.85, 0.85, 0.85, 1.0)
    panel_bg.border_width_left = 2
    panel_bg.border_width_top = 2
    panel_bg.border_width_right = 2
    panel_bg.border_width_bottom = 3                      ## 底部加粗 = 贴纸厚度
    panel_bg.corner_radius_top_left = 12
    panel_bg.corner_radius_top_right = 12
    panel_bg.corner_radius_bottom_left = 12
    panel_bg.corner_radius_bottom_right = 12
    panel_bg.shadow_color = Color(0, 0, 0, 0.1)
    panel_bg.shadow_size = 8
    panel_bg.shadow_offset = Vector2(0, 3)
    partner_panel.add_theme_stylebox_override("panel", panel_bg)
    
    partner_panel.visible = false

## 伙伴slot内部样式也要改为明亮：
func _fill_partner_slot(slot: Control, partner) -> void:
    ## ...
    
    ## 名字颜色：改为深灰（替代旧的亮金 0.95,0.72,0.25）
    name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
    
    ## 等级+职业颜色：改为中灰
    level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
    
    ## CHAIN徽章颜色：改为蓝色（与主色调一致）
    chain_badge.add_theme_color_override("font_color", Color(0.25, 0.55, 0.95, 1))
```

---

## Step 6：删除旧的 _show_floating_text

```gdscript
## 旧的 _show_floating_text 简单飘字已被 FeedbackManager 替代
## 删除 _show_floating_text() 函数

## 替换所有调用点：
## _show_floating_text("+%s 加入队伍！" % partner_name, Color(...))
## → FeedbackManager.play_sfx_only(ComicSFXData.SFXType.HEAL, position)
## 或者直接用新的浮动文字系统

## 替换 _show_rest_feedback 中的 _show_floating_text：
## → 使用 FeedbackManager.play_damage_only() 或 play_sfx_only()
```

### 具体替换

```gdscript
func _on_partner_unlocked(_config_id: String, partner_name: String, _slot_index: int, _turn: int, _role: String) -> void:
    _update_partner_hud()
    
    ## 删除：_show_floating_text("+%s 加入队伍！" % partner_name, Color(0.35, 0.75, 0.45))
    ## 改为使用 FeedbackManager：
    var slot_pos := _partner_slots[_partner_slots.size() - 1].global_position if _partner_slots.size() > 0 else Vector2.ZERO
    FeedbackManager.play_sfx_only(ComicSFXData.SFXType.HEAL, slot_pos + Vector2(70, 90))
    
    ## 缩放弹出动画保留 ✅
    var last_visible_index: int = -1
    for i in range(_partner_slots.size()):
        if _partner_slots[i].visible:
            last_visible_index = i
    
    if last_visible_index >= 0:
        var slot: Control = _partner_slots[last_visible_index]
        slot.pivot_offset = Vector2(70, 90)
        slot.scale = Vector2(0.5, 0.5)
        slot.modulate.a = 0.0
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(slot, "scale", Vector2.ONE, 0.4)
        tween.parallel().tween_property(slot, "modulate:a", 1.0, 0.3)

func _on_partner_skill_triggered(_config_id: String, skill_name: String, effect_desc: String) -> void:
    ## 删除：_show_floating_text("%s: %s" % [skill_name, effect_desc], Color(0.95, 0.72, 0.25))
    ## 改为：
    var pos := partner_panel.global_position + Vector2(0, -30)
    FeedbackManager.play_sfx_only(ComicSFXData.SFXType.MAGIC, pos)

func _show_rest_feedback(heal_amount: int) -> void:
    ## 删除旧的 _show_floating_text 和 hp_label modulate 动画
    ## 改为使用 FeedbackManager：
    var hp_pos := hp_label.global_position + Vector2(hp_label.size.x / 2, 0)
    FeedbackManager.play_damage_only(hp_pos, heal_amount, false, true)  ## is_heal=true
```

---

## Step 7：run_main.tscn 节点清理

```
RunMain (Control)
├── HudContainer (保留，改样式)
│   ├── FloorLabel (保留)
│   ├── GoldLabel (保留)
│   └── HpLabel (保留)
├── PlayerInfoPanel (删除 ❌)
│   ├── PlayerVitLabel (删除)
│   ├── PlayerStrLabel (删除)
│   ├── PlayerAgiLabel (删除)
│   ├── PlayerTecLabel (删除)
│   └── PlayerMndLabel (删除)
├── OptionContainer (保留)
│   ├── TrainButton
│   ├── BattleButton
│   ├── RestButton
│   └── OutingButton
├── CombatConfirmPanel (删除 ❌)
│   ├── EnterCombatButton (删除)
│   └── ReturnButton (删除)
├── BattleAnimationPanel (删除 ❌)
├── BattleSummaryPanel (删除 ❌)
├── EnemyInfoPanel (保留，改样式)
│   ├── EnemyNameLabel
│   ├── EnemyHpLabel
│   ├── EstimatedDamageLabel
│   └── RiskLabel
├── PartnerHUDLayer/PartnerPanel (保留，改明亮样式)
├── TrainingPanel (保留)
├── ShopPanel (保留)
├── RescuePopup (保留)
├── OutingPopup (保留)
├── PauseMenu (保留)
└── UIModalBlocker (保留)
```

---

## Step 8：统一 _transition_ui_state

```gdscript
func _transition_ui_state(new_state: UISceneState) -> void:
    print("[RunMain] UI状态: %s → %s" % [_get_ui_state_name(_current_ui_state), _get_ui_state_name(new_state)])
    _current_ui_state = new_state
    
    ## 先全部隐藏（确保没有残留）
    option_container.visible = false
    training_panel.visible = false
    rescue_popup.visible = false
    shop_panel.visible = false
    enemy_info_panel.visible = false          ## 确保敌人信息隐藏
    outing_popup.visible = false
    
    ## 删除：
    # combat_confirm_panel.visible = false
    # battle_animation_panel.visible = false
    # battle_summary_panel.visible = false
    
    ## 删除：
    # player_info_panel.visible = false  ## PlayerInfoPanel已删除
    
    ## 恢复伙伴面板（除非在战斗预览状态）
    if new_state != UISceneState.BATTLE_PREVIEW:
        partner_panel.visible = (_run_controller != null and _run_controller.get_partners().size() > 0)
    
    ## 再按需显示
    match new_state:
        UISceneState.OPTION_SELECT:
            option_container.visible = true
        UISceneState.TRAINING_SELECT:
            training_panel.visible = true
        UISceneState.RESCUE_SELECT:
            rescue_popup.visible = true
        UISceneState.SHOP_BROWSE:
            shop_panel.visible = true
        UISceneState.EVENT_RESULT:
            outing_popup.visible = true
        UISceneState.BATTLE_PREVIEW:
            ## 敌人剪影预览已显示，伙伴面板保持可见
            pass
```

---

## 测试验收标准

### 节点清理
- [ ] `run_main.tscn` 中已删除 `PlayerInfoPanel` 节点及其所有子节点
- [ ] `run_main.tscn` 中已删除 `CombatConfirmPanel` 节点
- [ ] `run_main.tscn` 中已删除 `BattleAnimationPanel` 节点
- [ ] `run_main.tscn` 中已删除 `BattleSummaryPanel` 节点
- [ ] `run_main.gd` 中无上述节点的 `@onready` 引用
- [ ] `run_main.gd` 中无 `_on_combat_confirmed()` / `_on_combat_cancelled()` 函数
- [ ] `run_main.gd` 中无 `_on_battle_animation_finished()` / `_show_battle_summary()` / `_on_battle_summary_confirmed()` 函数
- [ ] `run_main.gd` 中无 `_show_floating_text()` 函数

### HUD现代化
- [ ] `HudContainer` 白底+灰边+下圆角12px+阴影6px
- [ ] `floor_label` 显示 "第 X 层"，16px深灰字
- [ ] `gold_label` 只显示数字（带金币图标），16px金色
- [ ] `hp_label` 显示 "120 / 200"，14px红色
- [ ] 五维属性不再在爬塔主场景显示（只在训练面板/战斗场景中显示）
- [ ] `_on_stats_changed` 只更新HP标签

### EnemyInfoPanel
- [ ] 样式改为白底+灰边框+圆角+阴影（明亮风格）
- [ ] 只在 `_show_combat_preview` 时显示（剪影模式，半透明0.6）
- [ ] 进入战斗后、返回选项后、打开任何面板后自动隐藏
- [ ] `_transition_ui_state` 中设置 `enemy_info_panel.visible = false`
- [ ] `_on_battle_ended` 中设置 `enemy_info_panel.visible = false`

### PartnerPanel
- [ ] 背景改为白底 `Color(1,1,1,0.92)` + 灰边框 + 底部3px加粗 + 圆角12px + 阴影8px
- [ ] 伙伴名字深灰色 `Color(0.2,0.2,0.2,1)`
- [ ] 等级+职业中灰色 `Color(0.5,0.5,0.5,1)`
- [ ] CHAIN徽章蓝色 `Color(0.25,0.55,0.95,1)`
- [ ] 无伙伴时 `partner_panel.visible = false`
- [ ] 有伙伴时正确显示CHAIN计数

### 战斗流程
- [ ] 点击战斗选项 → 显示敌人剪影预览 → 直接调用 `_run_controller.select_node()` 进入战斗
- [ ] 战斗在独立 `battle_scene` 中进行
- [ ] 战斗结束后返回爬塔，`_update_hud()` 正确更新
- [ ] 旧 `battle_animation_panel` 不再显示
- [ ] 旧 `battle_summary_panel` 不再显示

### 其他面板
- [ ] 训练面板打开时 `enemy_info_panel` 隐藏
- [ ] 商店面板打开时 `enemy_info_panel` 隐藏
- [ ] 营救弹窗打开时 `enemy_info_panel` 隐藏
- [ ] 暂停菜单打开时 `enemy_info_panel` 隐藏

### 飘字替换
- [ ] 伙伴加入队伍时使用 `FeedbackManager.play_sfx_only()`（HEAL类型）
- [ ] 伙伴技能触发时使用 `FeedbackManager.play_sfx_only()`（MAGIC类型）
- [ ] 休息恢复HP时使用 `FeedbackManager.play_damage_only()`（is_heal=true）

### 无残留
- [ ] 启动游戏进入爬塔，没有旧战斗面板闪烁
- [ ] 选项选择界面干净，无多余元素
- [ ] 1280x720 和 1920x1080 下布局正常
