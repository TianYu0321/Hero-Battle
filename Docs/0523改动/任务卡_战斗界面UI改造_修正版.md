# 任务卡：战斗界面UI改造（修正版）

## 说明

经确认，战斗系统为**纯自动回合制**，所有单位卡片化显示。

- **CHAIN**：仅指"队友援助攻击"的计数机制，**不是独立攻击动画**，无需竖条UI
- **援助攻击**：自动触发，仅在战斗日志中文字记录（如"影舞者发动援助攻击！造成15点伤害"）
- **无特殊飞出动画**：所有攻击统一为卡片前移+受击抖动+伤害飘字

---

## 参考来源

1. **gdquest-demos/godot-open-rpg** — Godot 4回合制RPG，经典横版双方阵容布局
2. **balbonits/infinite-dungeon-game** — Diablo-style HUD（状态条+底部操作栏）
3. **Robin Fischer论文** — Battle Scene：status-HUD per participant + dialogue box + battle menu
4. **chun92/card-framework** — Tween动画 + hover效果
5. **IYanel-DEV/MainMenu-MP** — StyleBoxFlat shadow系统（已下载）

---

## Step 0：场景切换（爬塔→战斗→返回）

```gdscript
# run_main.gd 中
func _enter_battle(node_data: Dictionary) -> void:
    AudioManager.play_ui("battle_start")
    
    _transition_overlay.visible = true
    _transition_overlay.color = Color(0, 0, 0, 0)
    
    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(_transition_overlay, "color:a", 1.0, 0.4)
    await tween.finished
    
    GameManager.current_battle = {
        "node_id": node_data.get("id", ""),
        "node_type": node_data.get("type", "BATTLE"),
        "is_boss": node_data.get("is_boss", false),
    }
    
    get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
```

---

## Step 1：战斗场景节点结构

```
BattleScene (Node2D/Control)
├── BackgroundLayer (CanvasLayer, layer=0)
│   ├── ColorRect                    # 战斗背景色（根据普通/精英/BOSS变化）
│   └── BattleBackground             # TextureRect 背景图
├── BattleLayer (CanvasLayer, layer=1)  # 攻击飞行动画层（飘字/特效）
├── HUDLayer (CanvasLayer, layer=5)
│   ├── TopInfoBar (PanelContainer)    # 顶部：回合数 + 敌方信息 + 暂停
│   ├── LeftSide (VBoxContainer)       # 我方阵容
│   │   ├── HeroCard (PanelContainer)  # 主角卡片
│   │   └── PartnerCards (VBoxContainer)  # 2个伙伴卡片（如有）
│   ├── CenterArea (VBoxContainer)     # 中央
│   │   ├── VSLabel (Label)            # VS标志
│   │   └── BattleLog (RichTextLabel)  # 战斗日志
│   ├── RightSide (VBoxContainer)      # 敌方阵容
│   │   └── EnemyCards (VBoxContainer) # 1~3个敌方卡片
│   └── BottomBar (HBoxContainer)      # 底部操作栏
│       ├── SpeedControl (HBoxContainer) # 1x/2x/跳过
│       └── BattleProgress (Label)     # 战斗进度提示
├── PopupLayer (CanvasLayer, layer=10)
│   ├── VictoryPanel (PanelContainer)
│   ├── DefeatPanel (PanelContainer)
│   └── PauseMenu (PanelContainer)
└── TransitionOverlay (ColorRect, z_index=100)
```

---

## Step 2：全局配置

```gdscript
class_name BattleUISettings
extends RefCounted

## ========== 动画时长 ==========
const ENTRANCE_DURATION := 0.4
const ATTACK_MOVE_DURATION := 0.15      # 攻击前移时间
const ATTACK_RETURN_DURATION := 0.2     # 攻击弹回时间
const HIT_FLASH_DURATION := 0.12        # 受击闪红时间
const HIT_SHAKE_DURATION := 0.2         # 受击抖动时间
const DAMAGE_FLOAT_DURATION := 0.6      # 伤害飘字时间
const LOG_FLASH_DURATION := 0.3         # 日志新消息提示
const VICTORY_DELAY := 0.5

## ========== 颜色 ==========
const COLOR_BG := Color(0.96, 0.97, 0.99, 1.0)
const COLOR_BG_CARD := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_BG_CARD_ENEMY := Color(0.98, 0.92, 0.92, 1.0)  # 敌方微红底
const COLOR_BORDER := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_BORDER_HERO := Color(0.25, 0.55, 0.95, 1.0)   # 主角蓝边框
const COLOR_BORDER_ENEMY := Color(0.9, 0.35, 0.35, 1.0)    # 敌方红边框
const COLOR_TEXT_MAIN := Color(0.2, 0.2, 0.2, 1.0)
const COLOR_TEXT_SECOND := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_HP_BAR := Color(0.3, 0.8, 0.4, 1.0)
const COLOR_HP_BAR_LOW := Color(0.9, 0.3, 0.3, 1.0)
const COLOR_HP_BAR_BG := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_DAMAGE := Color(0.9, 0.2, 0.2, 1.0)            # 普通伤害红
const COLOR_DAMAGE_CRIT := Color(0.9, 0.5, 0.1, 1.0)      # 暴击橙
const COLOR_HEAL := Color(0.3, 0.7, 0.4, 1.0)              # 治疗绿
const COLOR_ASSIST := Color(0.4, 0.6, 1.0, 1.0)            # 援助攻击蓝（日志用）
const COLOR_VS := Color(0.85, 0.65, 0.15, 1.0)            # VS金色

## ========== 尺寸 ==========
const HERO_CARD_SIZE := Vector2(200, 260)
const PARTNER_CARD_SIZE := Vector2(180, 220)
const ENEMY_CARD_SIZE := Vector2(180, 220)
const AVATAR_SIZE_HERO := 120
const AVATAR_SIZE_PARTNER := 100
const AVATAR_SIZE_ENEMY := 100
const HP_BAR_HEIGHT := 8
const TOP_BAR_HEIGHT := 48
const BOTTOM_BAR_HEIGHT := 56
const CARD_RADIUS := 12

## ========== 阴影 ==========
const SHADOW_CARD := {"size": 8, "offset": Vector2(0, 3), "color": Color(0, 0, 0, 0.1)}
const SHADOW_TOP_BAR := {"size": 6, "offset": Vector2(0, 2), "color": Color(0, 0, 0, 0.08)}
```

---

## Step 3：顶部信息栏

```gdscript
func _setup_top_bar() -> void:
    var top_bar: PanelContainer = $HUDLayer/TopInfoBar
    top_bar.custom_minimum_size = Vector2(0, BattleUISettings.TOP_BAR_HEIGHT)
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 0.95)
    style.border_color = BattleUISettings.COLOR_BORDER
    style.border_width_left = 0
    style.border_width_top = 0
    style.border_width_right = 0
    style.border_width_bottom = 2
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = BattleUISettings.SHADOW_TOP_BAR.color
    style.shadow_size = BattleUISettings.SHADOW_TOP_BAR.size
    style.shadow_offset = BattleUISettings.SHADOW_TOP_BAR.offset
    top_bar.add_theme_stylebox_override("panel", style)
    
    var hbox := HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 24)
    top_bar.add_child(hbox)
    
    # 回合指示器
    var round_label := Label.new()
    round_label.name = "RoundLabel"
    round_label.text = "回合 1"
    round_label.add_theme_font_size_override("font_size", 18)
    round_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_MAIN)
    hbox.add_child(round_label)
    
    # 敌方阵容信息
    var enemy_info := Label.new()
    enemy_info.name = "EnemyInfoLabel"
    enemy_info.text = "敌方阵容"
    enemy_info.add_theme_font_size_override("font_size", 14)
    enemy_info.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    hbox.add_child(enemy_info)
    
    # 暂停按钮
    var pause_btn := Button.new()
    pause_btn.text = "||"
    pause_btn.custom_minimum_size = Vector2(36, 36)
    pause_btn.add_theme_font_size_override("font_size", 14)
    _apply_icon_button_style(pause_btn)
    pause_btn.pressed.connect(_on_pause_pressed)
    hbox.add_child(pause_btn)

func _update_round_display(round_num: int) -> void:
    var label: Label = $HUDLayer/TopInfoBar/HBoxContainer/RoundLabel
    label.text = "回合 %d" % round_num
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(label, "scale", Vector2.ONE, 0.2)
```

---

## Step 4：战斗卡片（统一创建函数）

```gdscript
enum CardType { HERO, PARTNER, ENEMY }

func _create_battle_card(entity_data: Dictionary, card_type: CardType) -> PanelContainer:
    var card := PanelContainer.new()
    card.set_meta("entity_id", entity_data.get("id", ""))
    card.set_meta("entity_type", card_type)
    card.set_meta("entity_data", entity_data)
    
    # 尺寸
    match card_type:
        CardType.HERO:
            card.custom_minimum_size = BattleUISettings.HERO_CARD_SIZE
        CardType.PARTNER:
            card.custom_minimum_size = BattleUISettings.PARTNER_CARD_SIZE
        CardType.ENEMY:
            card.custom_minimum_size = BattleUISettings.ENEMY_CARD_SIZE
    
    # 样式
    var style := StyleBoxFlat.new()
    match card_type:
        CardType.HERO:
            style.bg_color = BattleUISettings.COLOR_BG_CARD
            style.border_color = BattleUISettings.COLOR_BORDER_HERO
            style.border_width_left = 3
            style.border_width_top = 3
            style.border_width_right = 3
            style.border_width_bottom = 4
        CardType.PARTNER:
            style.bg_color = BattleUISettings.COLOR_BG_CARD
            style.border_color = BattleUISettings.COLOR_BORDER
            style.border_width_left = 2
            style.border_width_top = 2
            style.border_width_right = 2
            style.border_width_bottom = 3
        CardType.ENEMY:
            style.bg_color = BattleUISettings.COLOR_BG_CARD_ENEMY
            style.border_color = BattleUISettings.COLOR_BORDER_ENEMY
            style.border_width_left = 2
            style.border_width_top = 2
            style.border_width_right = 2
            style.border_width_bottom = 3
    
    style.corner_radius_top_left = BattleUISettings.CARD_RADIUS
    style.corner_radius_top_right = BattleUISettings.CARD_RADIUS
    style.corner_radius_bottom_left = BattleUISettings.CARD_RADIUS
    style.corner_radius_bottom_right = BattleUISettings.CARD_RADIUS
    style.shadow_color = BattleUISettings.SHADOW_CARD.color
    style.shadow_size = BattleUISettings.SHADOW_CARD.size
    style.shadow_offset = BattleUISettings.SHADOW_CARD.offset
    card.add_theme_stylebox_override("panel", style)
    
    # 内部布局
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 4)
    card.add_child(vbox)
    
    # 名字行（主角带★标记）
    var name_hbox := HBoxContainer.new()
    name_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(name_hbox)
    
    var name_label := Label.new()
    name_label.text = entity_data.get("name", "???")
    name_label.add_theme_font_size_override("font_size", 15 if card_type == CardType.HERO else 14)
    name_label.add_theme_color_override("font_color", 
        Color(0.6, 0.2, 0.2, 1) if card_type == CardType.ENEMY else BattleUISettings.COLOR_TEXT_MAIN)
    name_hbox.add_child(name_label)
    
    if card_type == CardType.HERO:
        var star := Label.new()
        star.text = "★"
        star.add_theme_font_size_override("font_size", 12)
        star.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15, 1))
        name_hbox.add_child(star)
    
    # 等级
    var lv_label := Label.new()
    lv_label.text = "Lv.%d" % entity_data.get("level", 1)
    lv_label.add_theme_font_size_override("font_size", 11)
    lv_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(lv_label)
    
    # 头像
    var avatar_size := BattleUISettings.AVATAR_SIZE_HERO if card_type == CardType.HERO else BattleUISettings.AVATAR_SIZE_PARTNER
    var avatar := _create_avatar(entity_data.get("avatar_path", ""), avatar_size, card_type == CardType.ENEMY)
    vbox.add_child(avatar)
    
    # HP条
    var max_hp: int = entity_data.get("max_hp", 100)
    var hp: int = entity_data.get("hp", max_hp)
    var hp_bar := _create_hp_bar(hp, max_hp)
    hp_bar.name = "HPBar"
    vbox.add_child(hp_bar)
    
    # HP数值
    var hp_text := Label.new()
    hp_text.name = "HPText"
    hp_text.text = "%d/%d" % [hp, max_hp]
    hp_text.add_theme_font_size_override("font_size", 10)
    hp_text.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(hp_text)
    
    # 简版属性（攻/防）
    var stats_label := Label.new()
    stats_label.text = "攻:%d 防:%d" % [entity_data.get("atk", 0), entity_data.get("def", 0)]
    stats_label.add_theme_font_size_override("font_size", 10)
    stats_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(stats_label)
    
    return card

func _create_avatar(avatar_path: String, size: int, is_silhouette: bool = false) -> Control:
    var container := PanelContainer.new()
    container.custom_minimum_size = Vector2(size, size)
    
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.9, 0.3, 0.3, 0.15) if is_silhouette else Color(0.95, 0.95, 0.97, 1)
    bg.corner_radius_top_left = 8
    bg.corner_radius_top_right = 8
    bg.corner_radius_bottom_left = 8
    bg.corner_radius_bottom_right = 8
    container.add_theme_stylebox_override("panel", bg)
    
    var avatar := TextureRect.new()
    avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    avatar.custom_minimum_size = Vector2(size, size)
    
    if not avatar_path.is_empty() and not is_silhouette:
        var tex: Texture2D = load(avatar_path)
        if tex != null:
            avatar.texture = tex
    elif is_silhouette:
        # 未解锁敌方显示剪影：灰色占位
        avatar.modulate = Color(0.5, 0.4, 0.4, 0.3)
    
    container.add_child(avatar)
    return container

func _create_hp_bar(current: int, maximum: int) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(120, BattleUISettings.HP_BAR_HEIGHT)
    bar.max_value = maximum
    bar.value = current
    bar.show_percentage = false
    
    var hp_ratio := float(current) / maximum
    
    var fg := StyleBoxFlat.new()
    fg.bg_color = BattleUISettings.COLOR_HP_BAR_LOW if hp_ratio < 0.3 else BattleUISettings.COLOR_HP_BAR
    fg.corner_radius_top_left = 4
    fg.corner_radius_top_right = 4
    fg.corner_radius_bottom_left = 4
    fg.corner_radius_bottom_right = 4
    bar.add_theme_stylebox_override("fill", fg)
    
    var bg := StyleBoxFlat.new()
    bg.bg_color = BattleUISettings.COLOR_HP_BAR_BG
    bg.corner_radius_top_left = 4
    bg.corner_radius_top_right = 4
    bg.corner_radius_bottom_left = 4
    bg.corner_radius_bottom_right = 4
    bar.add_theme_stylebox_override("background", bg)
    
    return bar

func _update_hp_bar(card: PanelContainer, new_hp: int, max_hp: int) -> void:
    var bar: ProgressBar = card.get_node("HPBar")
    var hp_text: Label = card.get_node("HPText")
    
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(bar, "value", new_hp, 0.3)
    
    hp_text.text = "%d/%d" % [new_hp, max_hp]
    
    # 颜色变化
    var hp_ratio := float(new_hp) / max_hp
    var fg: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
    fg.bg_color = BattleUISettings.COLOR_HP_BAR_LOW if hp_ratio < 0.3 else BattleUISettings.COLOR_HP_BAR
    bar.add_theme_stylebox_override("fill", fg)
```

---

## Step 5：中央区（VS + 战斗日志）

```gdscript
func _setup_center_area() -> void:
    var center: VBoxContainer = $HUDLayer/CenterArea
    center.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_theme_constant_override("separation", 12)
    
    # VS标志
    var vs_label := Label.new()
    vs_label.text = "VS"
    vs_label.add_theme_font_size_override("font_size", 32)
    vs_label.add_theme_color_override("font_color", BattleUISettings.COLOR_VS)
    vs_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
    vs_label.add_theme_constant_override("shadow_offset_x", 2)
    vs_label.add_theme_constant_override("shadow_offset_y", 2)
    vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(vs_label)
    
    # 战斗日志
    var log_box := RichTextLabel.new()
    log_box.name = "BattleLog"
    log_box.custom_minimum_size = Vector2(220, 180)
    log_box.scroll_active = true
    log_box.scroll_following = true
    log_box.bbcode_enabled = true
    
    var log_bg := StyleBoxFlat.new()
    log_bg.bg_color = Color(0.98, 0.98, 0.99, 0.9)
    log_bg.border_color = BattleUISettings.COLOR_BORDER
    log_bg.border_width_left = 1
    log_bg.border_width_top = 1
    log_bg.border_width_right = 1
    log_bg.border_width_bottom = 1
    log_bg.corner_radius_top_left = 8
    log_bg.corner_radius_top_right = 8
    log_bg.corner_radius_bottom_left = 8
    log_bg.corner_radius_bottom_right = 8
    log_box.add_theme_stylebox_override("normal", log_bg)
    log_box.add_theme_font_size_override("normal_font_size", 11)
    log_box.add_theme_color_override("default_color", BattleUISettings.COLOR_TEXT_MAIN)
    center.add_child(log_box)

func _add_battle_log(text: String, log_type: String = "normal") -> void:
    var log: RichTextLabel = $HUDLayer/CenterArea/BattleLog
    
    var color_hex := BattleUISettings.COLOR_TEXT_MAIN.to_html()
    match log_type:
        "damage":
            color_hex = BattleUISettings.COLOR_DAMAGE.to_html()
        "heal":
            color_hex = BattleUISettings.COLOR_HEAL.to_html()
        "crit":
            color_hex = BattleUISettings.COLOR_DAMAGE_CRIT.to_html()
        "assist":
            color_hex = BattleUISettings.COLOR_ASSIST.to_html()
        "enemy":
            color_hex = BattleUISettings.COLOR_BORDER_ENEMY.to_html()
    
    log.append_text("[color=%s]%s[/color]\n" % [color_hex, text])
    log.scroll_to_line(log.get_line_count())
    
    # 新消息边框闪烁提示
    var flash_border := StyleBoxFlat.new()
    flash_border.bg_color = Color(0.98, 0.98, 0.99, 0.9)
    flash_border.border_color = Color(0.4, 0.6, 1.0, 0.5)
    flash_border.border_width_left = 2
    flash_border.border_width_top = 2
    flash_border.border_width_right = 2
    flash_border.border_width_bottom = 2
    flash_border.corner_radius_top_left = 8
    flash_border.corner_radius_top_right = 8
    flash_border.corner_radius_bottom_left = 8
    flash_border.corner_radius_bottom_right = 8
    log.add_theme_stylebox_override("normal", flash_border)
    
    await get_tree().create_timer(0.3).timeout
    
    var normal_bg := StyleBoxFlat.new()
    normal_bg.bg_color = Color(0.98, 0.98, 0.99, 0.9)
    normal_bg.border_color = BattleUISettings.COLOR_BORDER
    normal_bg.border_width_left = 1
    normal_bg.border_width_top = 1
    normal_bg.border_width_right = 1
    normal_bg.border_width_bottom = 1
    normal_bg.corner_radius_top_left = 8
    normal_bg.corner_radius_top_right = 8
    normal_bg.corner_radius_bottom_left = 8
    normal_bg.corner_radius_bottom_right = 8
    log.add_theme_stylebox_override("normal", normal_bg)
```

---

## Step 6：入场动画（双方滑入）

```gdscript
func _play_battle_entrance() -> void:
    var left_cards := _get_all_left_cards()   # 我方所有卡片
    var right_cards := _get_all_right_cards()  # 敌方所有卡片
    
    # 初始状态
    for card in left_cards:
        card.modulate.a = 0.0
        card.position.x -= 60
    for card in right_cards:
        card.modulate.a = 0.0
        card.position.x += 60
    
    # 左侧卡片从左滑入（主角先，然后伙伴依次）
    for i in range(left_cards.size()):
        var card: Control = left_cards[i]
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
        tween.tween_property(card, "modulate:a", 1.0, BattleUISettings.ENTRANCE_DURATION)
        tween.parallel().tween_property(card, "position:x", card.position.x + 60, BattleUISettings.ENTRANCE_DURATION + 0.05)
    
    # 右侧卡片从右滑入（延迟0.2s）
    for i in range(right_cards.size()):
        var card: Control = right_cards[i]
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.2 + i * 0.12)
        tween.tween_property(card, "modulate:a", 1.0, BattleUISettings.ENTRANCE_DURATION)
        tween.parallel().tween_property(card, "position:x", card.position.x - 60, BattleUISettings.ENTRANCE_DURATION + 0.05)
    
    # VS标志弹跳入场
    var vs_label: Label = $HUDLayer/CenterArea/VSLabel
    vs_label.scale = Vector2(0.5, 0.5)
    vs_label.modulate.a = 0.0
    
    var vs_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.4)
    vs_tween.tween_property(vs_label, "scale", Vector2.ONE, 0.35)
    vs_tween.parallel().tween_property(vs_label, "modulate:a", 1.0, 0.3)
    
    # 日志框淡入
    var log_box: RichTextLabel = $HUDLayer/CenterArea/BattleLog
    log_box.modulate.a = 0.0
    var log_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.6)
    log_tween.tween_property(log_box, "modulate:a", 1.0, 0.3)
```

---

## Step 7：攻击动画（统一模式：前移→弹回 + 受击抖动 + 飘字）

```gdscript
## ========== 统一攻击动画 ==========
func _play_attack(attacker_card: PanelContainer, target_card: PanelContainer, 
                  damage: int, is_crit: bool = false, is_assist: bool = false) -> void:
    
    # 1. 攻击者前移（朝目标方向）
    var is_attacker_left := attacker_card in _get_all_left_cards()
    var move_direction := 1 if is_attacker_left else -1
    var original_x := attacker_card.position.x
    
    var move_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    move_tween.tween_property(attacker_card, "position:x", 
                              original_x + move_direction * 20, 
                              BattleUISettings.ATTACK_MOVE_DURATION)
    
    await move_tween.finished
    
    # 2. 攻击者弹回
    var return_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    return_tween.tween_property(attacker_card, "position:x", 
                                original_x, 
                                BattleUISettings.ATTACK_RETURN_DURATION)
    
    # 3. 目标受击（与弹回同时进行）
    _play_hit_effect(target_card, damage, is_crit)
    
    # 4. 战斗日志
    var attacker_name: String = attacker_card.get_meta("entity_data", {}).get("name", "???")
    var target_name: String = target_card.get_meta("entity_data", {}).get("name", "???")
    
    if is_assist:
        _add_battle_log("%s发动援助攻击！%s受到%d点伤害" % [attacker_name, target_name, damage], "assist")
    elif is_crit:
        _add_battle_log("%s暴击！%s受到%d点伤害" % [attacker_name, target_name, damage], "crit")
    else:
        _add_battle_log("%s攻击%s，造成%d点伤害" % [attacker_name, target_name, damage], "damage")

## ========== 受击效果（闪红 + 抖动 + 飘字 + HP条更新） ==========
func _play_hit_effect(target_card: PanelContainer, damage: int, is_crit: bool = false) -> void:
    # 闪红
    var flash_tween := create_tween()
    flash_tween.tween_property(target_card, "modulate", Color(1, 0.5, 0.5, 1), 0.05)
    flash_tween.tween_property(target_card, "modulate", Color.WHITE, BattleUISettings.HIT_FLASH_DURATION)
    
    # 抖动
    var original_x := target_card.position.x
    var shake_tween := create_tween()
    shake_tween.tween_property(target_card, "position:x", original_x - 4, 0.03)
    shake_tween.tween_property(target_card, "position:x", original_x + 4, 0.03)
    shake_tween.tween_property(target_card, "position:x", original_x - 2, 0.03)
    shake_tween.tween_property(target_card, "position:x", original_x, 0.03)
    
    # 伤害飘字
    var float_pos := target_card.global_position + Vector2(
        target_card.size.x * 0.5, 
        target_card.size.y * 0.3
    )
    _show_damage_number(float_pos, damage, is_crit)

## ========== 伤害/治疗飘字 ==========
func _show_damage_number(pos: Vector2, amount: int, is_crit: bool = false, is_heal: bool = false) -> void:
    var label := Label.new()
    
    if is_heal:
        label.text = "+%d" % amount
        label.add_theme_color_override("font_color", BattleUISettings.COLOR_HEAL)
        label.add_theme_font_size_override("font_size", 22)
    elif is_crit:
        label.text = "-%d!" % amount
        label.add_theme_color_override("font_color", BattleUISettings.COLOR_DAMAGE_CRIT)
        label.add_theme_font_size_override("font_size", 32)
    else:
        label.text = "-%d" % amount
        label.add_theme_color_override("font_color", BattleUISettings.COLOR_DAMAGE)
        label.add_theme_font_size_override("font_size", 24)
    
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.position = pos - Vector2(20, 0)
    label.z_index = 200
    $BattleLayer.add_child(label)
    
    # 飘字动画：向上飘 + 淡出
    var float_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    float_tween.tween_property(label, "position:y", pos.y - 50, BattleUISettings.DAMAGE_FLOAT_DURATION)
    float_tween.parallel().tween_property(label, "modulate:a", 0.0, BattleUISettings.DAMAGE_FLOAT_DURATION)
    
    await float_tween.finished
    label.queue_free()

## ========== 治疗动画 ==========
func _play_heal(target_card: PanelContainer, amount: int) -> void:
    # 绿光闪烁
    var heal_tween := create_tween()
    heal_tween.tween_property(target_card, "modulate", Color(0.7, 1.0, 0.7, 1), 0.1)
    heal_tween.tween_property(target_card, "modulate", Color.WHITE, 0.2)
    
    # 飘字
    var pos := target_card.global_position + Vector2(target_card.size.x * 0.5, target_card.size.y * 0.3)
    _show_damage_number(pos, amount, false, true)
    
    # 更新HP
    var entity_data: Dictionary = target_card.get_meta("entity_data", {})
    var new_hp := min(entity_data.get("max_hp", 100), int(entity_data.get("hp", 0)) + amount)
    entity_data["hp"] = new_hp
    target_card.set_meta("entity_data", entity_data)
    _update_hp_bar(target_card, new_hp, entity_data.get("max_hp", 100))
```

---

## Step 8：底部操作栏

```gdscript
func _setup_bottom_bar() -> void:
    var bar: HBoxContainer = $HUDLayer/BottomBar
    bar.alignment = BoxContainer.ALIGNMENT_CENTER
    bar.add_theme_constant_override("separation", 16)
    bar.custom_minimum_size = Vector2(0, BattleUISettings.BOTTOM_BAR_HEIGHT)
    bar.position = Vector2(0, 620)
    
    # 背景
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(1.0, 1.0, 1.0, 0.9)
    bg.border_color = BattleUISettings.COLOR_BORDER
    bg.border_width_left = 0
    bg.border_width_top = 2
    bg.border_width_right = 0
    bg.border_width_bottom = 0
    bg.corner_radius_top_left = 12
    bg.corner_radius_top_right = 12
    bg.shadow_color = Color(0, 0, 0, 0.06)
    bg.shadow_size = -6
    
    var bg_panel := PanelContainer.new()
    bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg_panel.add_theme_stylebox_override("panel", bg)
    bar.add_child(bg_panel)
    
    # 速度控制
    var speed_group := HBoxContainer.new()
    speed_group.alignment = BoxContainer.ALIGNMENT_CENTER
    speed_group.add_theme_constant_override("separation", 4)
    bar.add_child(speed_group)
    
    for speed in [1.0, 2.0]:
        var btn := Button.new()
        btn.text = "%.0fx" % speed
        btn.toggle_mode = true
        btn.button_pressed = speed == 1.0
        btn.custom_minimum_size = Vector2(48, 36)
        _apply_speed_button_style(btn, speed == 1.0)
        btn.pressed.connect(_on_speed_changed.bind(speed))
        speed_group.add_child(btn)
    
    # 跳过按钮
    var skip_btn := Button.new()
    skip_btn.text = "跳过"
    skip_btn.custom_minimum_size = Vector2(80, 40)
    _apply_secondary_button_style(skip_btn)
    skip_btn.pressed.connect(_on_skip_animation)
    bar.add_child(skip_btn)
    
    # 战斗进度提示
    var progress_label := Label.new()
    progress_label.name = "ProgressLabel"
    progress_label.text = "战斗中..."
    progress_label.add_theme_font_size_override("font_size", 12)
    progress_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    bar.add_child(progress_label)

func _apply_speed_button_style(button: Button, is_active: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.94, 0.94, 0.96, 1)
    normal.border_color = BattleUISettings.COLOR_BORDER
    normal.border_width_left = 1
    normal.border_width_top = 1
    normal.border_width_right = 1
    normal.border_width_bottom = 1
    normal.corner_radius_top_left = 6
    normal.corner_radius_top_right = 6
    normal.corner_radius_bottom_left = 6
    normal.corner_radius_bottom_right = 6
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    
    var pressed := StyleBoxFlat.new()
    pressed.bg_color = BattleUISettings.COLOR_ASSIST
    pressed.border_color = BattleUISettings.COLOR_ASSIST
    pressed.corner_radius_top_left = 6
    pressed.corner_radius_top_right = 6
    pressed.corner_radius_bottom_left = 6
    pressed.corner_radius_bottom_right = 6
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    
    if is_active:
        button.add_theme_stylebox_override("normal", pressed)
        button.add_theme_color_override("font_color", Color.WHITE)

func _on_speed_changed(speed: float) -> void:
    _animation_speed = speed
    AudioManager.play_ui("click")
    
    # 更新按钮状态
    for child in $HUDLayer/BottomBar/HBoxContainer.get_children():
        if child is Button and child.text.ends_with("x"):
            var btn_speed := float(child.text.replace("x", ""))
            _apply_speed_button_style(child, btn_speed == speed)

func _on_skip_animation() -> void:
    _skip_requested = true
    AudioManager.play_ui("click")
```

---

## Step 9：战斗结算界面

### 胜利面板

```gdscript
func _show_victory_panel(rewards: Dictionary) -> void:
    var panel: PanelContainer = $PopupLayer/VictoryPanel
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
    style.border_color = Color(0.3, 0.7, 0.4, 1)  # 胜利绿
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    style.shadow_color = Color(0.3, 0.7, 0.4, 0.2)
    style.shadow_size = 20
    style.shadow_offset = Vector2(0, 10)
    panel.add_theme_stylebox_override("panel", style)
    
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(400, 300)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 16)
    panel.add_child(vbox)
    
    var title := Label.new()
    title.text = "胜利!"
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4, 1))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    var gold_label := Label.new()
    gold_label.text = "获得金币: %d" % rewards.get("gold", 0)
    gold_label.add_theme_font_size_override("font_size", 16)
    gold_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_MAIN)
    gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(gold_label)
    
    var exp_label := Label.new()
    exp_label.text = "获得经验: %d" % rewards.get("exp", 0)
    exp_label.add_theme_font_size_override("font_size", 16)
    exp_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_MAIN)
    exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(exp_label)
    
    var continue_btn := Button.new()
    continue_btn.text = "继续"
    continue_btn.custom_minimum_size = Vector2(160, 48)
    _apply_primary_button_style(continue_btn)
    continue_btn.pressed.connect(_on_victory_continue)
    vbox.add_child(continue_btn)
    
    _popup_entrance(panel)
```

### 失败面板

```gdscript
func _show_defeat_panel() -> void:
    var panel: PanelContainer = $PopupLayer/DefeatPanel
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
    style.border_color = Color(0.8, 0.3, 0.3, 1)  # 失败红
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    style.shadow_color = Color(0.8, 0.3, 0.3, 0.2)
    style.shadow_size = 20
    style.shadow_offset = Vector2(0, 10)
    panel.add_theme_stylebox_override("panel", style)
    
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(400, 280)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 16)
    panel.add_child(vbox)
    
    var title := Label.new()
    title.text = "战斗失败"
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    var desc := Label.new()
    desc.text = "你的队伍被击败了..."
    desc.add_theme_font_size_override("font_size", 14)
    desc.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(desc)
    
    var restart_btn := Button.new()
    restart_btn.text = "重新开始"
    restart_btn.custom_minimum_size = Vector2(160, 48)
    _apply_primary_button_style(restart_btn)
    restart_btn.pressed.connect(_on_defeat_restart)
    vbox.add_child(restart_btn)
    
    var quit_btn := Button.new()
    quit_btn.text = "返回主菜单"
    quit_btn.custom_minimum_size = Vector2(160, 48)
    _apply_secondary_button_style(quit_btn)
    quit_btn.pressed.connect(_on_defeat_quit)
    vbox.add_child(quit_btn)
    
    _popup_entrance(panel)
```

### 弹窗通用入场

```gdscript
func _popup_entrance(panel: PanelContainer) -> void:
    panel.visible = true
    panel.scale = Vector2(0.85, 0.85)
    panel.modulate.a = 0.0
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(panel, "scale", Vector2.ONE, 0.35)
    tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
```

---

## Step 10：通用按钮样式

```gdscript
func _apply_primary_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.25, 0.55, 0.95, 1)
    normal.border_color = Color(0.2, 0.45, 0.85, 1)
    normal.corner_radius_top_left = 8
    normal.corner_radius_top_right = 8
    normal.corner_radius_bottom_left = 8
    normal.corner_radius_bottom_right = 8
    normal.shadow_color = Color(0.25, 0.55, 0.95, 0.2)
    normal.shadow_size = 6
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_color_override("font_color", Color.WHITE)
    
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.35, 0.65, 1.0, 1)
    hover.corner_radius_top_left = 8
    hover.corner_radius_top_right = 8
    hover.corner_radius_bottom_left = 8
    hover.corner_radius_bottom_right = 8
    hover.shadow_size = 10
    button.add_theme_stylebox_override("hover", hover)
    
    button.pressed.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
        tween.tween_property(button, "scale", Vector2.ONE, 0.15)
    )

func _apply_secondary_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
    normal.border_color = BattleUISettings.COLOR_BORDER
    normal.border_width_left = 2
    normal.border_width_top = 2
    normal.border_width_right = 2
    normal.border_width_bottom = 2
    normal.corner_radius_top_left = 8
    normal.corner_radius_top_right = 8
    normal.corner_radius_bottom_left = 8
    normal.corner_radius_bottom_right = 8
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.96, 0.98, 1.0, 1)
    hover.border_color = BattleUISettings.COLOR_ASSIST
    hover.corner_radius_top_left = 8
    hover.corner_radius_top_right = 8
    hover.corner_radius_bottom_left = 8
    hover.corner_radius_bottom_right = 8
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_color_override("font_hover_color", BattleUISettings.COLOR_ASSIST)

func _apply_icon_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.96, 0.96, 0.98, 1)
    normal.border_color = BattleUISettings.COLOR_BORDER
    normal.border_width_left = 1
    normal.border_width_top = 1
    normal.border_width_right = 1
    normal.border_width_bottom = 1
    normal.corner_radius_top_left = 8
    normal.corner_radius_top_right = 8
    normal.corner_radius_bottom_left = 8
    normal.corner_radius_bottom_right = 8
    normal.shadow_color = Color(0, 0, 0, 0.06)
    normal.shadow_size = 4
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(1.0, 1.0, 1.0, 1)
    hover.border_color = BattleUISettings.COLOR_ASSIST
    hover.corner_radius_top_left = 8
    hover.corner_radius_top_right = 8
    hover.corner_radius_bottom_left = 8
    hover.corner_radius_bottom_right = 8
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_color_override("font_hover_color", BattleUISettings.COLOR_ASSIST)
```

---

## 测试验收标准

- [ ] 进入战斗：爬塔场景淡入切到战斗场景（0.4s黑屏过渡）
- [ ] 背景：根据战斗类型（普通/精英/BOSS）显示不同背景色调
- [ ] 顶部栏：白底+底部灰边+下圆角+阴影，显示"回合 X"+敌方信息+暂停按钮
- [ ] 回合变化："回合 X"scale弹跳1.2x动画
- [ ] 我方阵容：主角蓝色粗边框（3px）+★标记，伙伴普通灰边框，卡片200x260/180x220
- [ ] 敌方阵容：微红底+红边框，卡片180x220
- [ ] 所有卡片：白底/红底+圆角12px+8px阴影，头像正方形+8px圆角，HP条绿色（<30%变红）+灰色背景+4px圆角
- [ ] HP数值显示在HP条下方（"120/200"），更新时Tween过渡0.3s+颜色变化
- [ ] 入场动画：我方从左滑入（主角先，伙伴间隔0.12s），敌方从右滑入（延迟0.2s）
- [ ] VS标志：金色32px，入场scale0.5→1.0弹跳+淡入
- [ ] 战斗日志：RichTextLabel支持BBCode，普通/伤害/暴击/治疗/援助不同颜色
- [ ] 新日志：边框闪烁蓝色0.3s后恢复
- [ ] 攻击动画：攻击者前移20px（0.15s）→弹回（0.2s，TRANS_BACK）
- [ ] 受击效果：目标闪红0.05s+左右抖动4px（0.03s×4次）
- [ ] 伤害飘字：红色"-X"向上飘50px+淡出0.6s，暴击橙色"-X!"大字号32px
- [ ] 治疗飘字：绿色"+X"向上飘+淡出
- [ ] 援助攻击：日志蓝色文字"XX发动援助攻击！XX受到X点伤害"
- [ ] HP条更新：新数值Tween过渡0.3s，<30%自动变红
- [ ] 底部栏：白底+顶部灰边+上圆角，速度按钮1x/2x（选中=蓝底白字），跳过按钮
- [ ] 胜利面板：绿色边框+"胜利!"+金币/经验奖励+"继续"蓝色按钮
- [ ] 失败面板：红色边框+"战斗失败"+"重新开始"/"返回主菜单"按钮
- [ ] 结算面板入场：scale0.85→1.0弹跳+淡入
- [ ] 暂停菜单：半透明遮罩+白底面板+"继续"/"返回爬塔"/"退出"
- [ ] 1280x720 和 1920x1080 布局正常
- [ ] Tween资源正确清理，切换场景无内存泄漏
