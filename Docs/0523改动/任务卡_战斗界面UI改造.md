# 任务卡：战斗界面UI改造

## 参考来源

1. **gdquest-demos/godot-open-rpg** — Godot 4回合制RPG演示，经典回合制战斗UI结构
2. **balbonits/infinite-dungeon-game** — Diablo-style HUD（HP/MP orbs + bottom skill hotbar）
3. **StephenMRicks85/turn-based-deckbuilder-godot** — combat_scene三层分离（state/UI/resolution）
4. **statico/godot-roguelike-example** — Modal system + D20 combat + status effects
5. **Robin Fischer论文** — Battle Scene：status-HUD per participant + dialogue box + battle menu
6. **chun92/card-framework** — Tween动画 + hover效果 + z-index管理
7. **IYanel-DEV/MainMenu-MP** — StyleBoxFlat shadow系统（已下载）

---

## 战斗场景定位

**触发**：爬塔中遇到战斗节点 → 进入 `battle_scene.tscn`
**退出**：战斗结束（胜利/失败）→ 返回爬塔主场景 / 游戏结束
**类型**：自动回合制（非手动操作卡牌），但允许跳过动画/加速

---

## Step 0：场景切换（爬塔→战斗→返回）

```gdscript
# run_main.gd 中
func _enter_battle(node_data: Dictionary) -> void:
    AudioManager.play_ui("battle_start")
    
    # 淡入切场景
    _transition_overlay.visible = true
    _transition_overlay.color = Color(0, 0, 0, 0)
    
    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(_transition_overlay, "color:a", 1.0, 0.4)
    await tween.finished
    
    # 存储战斗上下文
    GameManager.current_battle = {
        "node_id": node_data.get("id", ""),
        "node_type": node_data.get("type", "BATTLE"),
        "enemies": _generate_enemies(node_data),
        "is_boss": node_data.get("is_boss", false),
    }
    
    get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
```

---

## Step 1：战斗场景节点结构

```
BattleScene (Node2D/Control)
├── BackgroundLayer (CanvasLayer, layer=0)
│   ├── ColorRect                    # 战斗背景色（根据场景类型变化）
│   ├── BattleBackground             # TextureRect 战斗背景图
│   └── AmbientEffects (Node2D)      # 战斗氛围粒子（火花/尘埃）
├── BattleLayer (CanvasLayer, layer=1)
│   └── BattleField (Control)        # 战斗动画区域（非UI层，放攻击飞行动画）
├── HUDLayer (CanvasLayer, layer=5)
│   ├── TopInfoBar (PanelContainer)    # 顶部回合/敌方信息
│   ├── LeftChainColumn (VBoxContainer)  # 1-4级伙伴CHAIN竖条
│   ├── CenterBattleArea (HBoxContainer) # 中央双方阵容
│   │   ├── LeftSide (VBoxContainer)   # 我方
│   │   │   ├── HeroCard (PanelContainer)
│   │   │   └── PartnerCards (VBoxContainer)
│   │   ├── VSCenter (VBoxContainer)   # VS + 战斗信息
│   │   │   ├── VSLabel (Label)
│   │   │   └── BattleLog (RichTextLabel)
│   │   └── RightSide (VBoxContainer)  # 敌方
│   │       └── EnemyCards (VBoxContainer)
│   ├── BottomActionBar (HBoxContainer)  # 底部操作栏
│   │   ├── SpeedControl (HBoxContainer) # 速度控制（1x/2x/跳过）
│   │   └── AutoToggle (Button)        # 自动/手动（如有手动操作）
│   └── Level5FlyZone (Control)        # 5级伙伴飞出动画目标区域
├── PopupLayer (CanvasLayer, layer=10)
│   ├── VictoryPanel (PanelContainer)
│   ├── DefeatPanel (PanelContainer)
│   ├── RewardsPanel (PanelContainer)
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
const CARD_HOVER_DURATION := 0.12
const ATTACK_FLY_DURATION := 0.5          # 飞出攻击飞行时间
const HIT_SHAKE_DURATION := 0.25          # 受击抖动时间
const DAMAGE_FLOAT_DURATION := 0.6        # 伤害数字飘字时间
const VICTORY_DELAY := 0.5

## ========== 颜色（明亮纸片剧场）==========
const COLOR_BG := Color(0.96, 0.97, 0.99, 1.0)       # 极浅蓝白底
const COLOR_BG_CARD := Color(1.0, 1.0, 1.0, 1.0)       # 纯白卡片
const COLOR_BG_CARD_ENEMY := Color(0.98, 0.92, 0.92, 1.0)  # 敌方微红底
const COLOR_BORDER := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_BORDER_HERO := Color(0.25, 0.55, 0.95, 1.0)   # 主角蓝边框
const COLOR_BORDER_ENEMY := Color(0.9, 0.35, 0.35, 1.0)   # 敌方红边框
const COLOR_TEXT_MAIN := Color(0.2, 0.2, 0.2, 1.0)
const COLOR_TEXT_SECOND := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_HP_BAR := Color(0.3, 0.8, 0.4, 1.0)           # 绿色HP
const COLOR_HP_BAR_LOW := Color(0.9, 0.3, 0.3, 1.0)      # 低血量红
const COLOR_HP_BAR_BG := Color(0.85, 0.85, 0.85, 1.0)     # HP条背景
const COLOR_CHAIN_ACTIVE := Color(0.4, 0.6, 1.0, 1.0)     # CHAIN激活蓝
const COLOR_CHAIN_INACTIVE := Color(0.85, 0.85, 0.85, 1.0) # CHAIN未激活灰

## ========== 尺寸 ==========
const CARD_WIDTH := 180
const CARD_HEIGHT := 240
const CARD_AVATAR_SIZE := 120
const CHAIN_CARD_SIZE := Vector2(64, 80)
const ENEMY_CARD_WIDTH := 160
const ENEMY_CARD_HEIGHT := 200
const ENEMY_AVATAR_SIZE := 100
const HP_BAR_HEIGHT := 8
const TOP_BAR_HEIGHT := 48
const BOTTOM_BAR_HEIGHT := 56

## ========== 阴影 ==========
const SHADOW_CARD := {"size": 8, "offset": Vector2(0, 3), "color": Color(0, 0, 0, 0.1)}
const SHADOW_PANEL := {"size": 15, "offset": Vector2(0, 8), "color": Color(0, 0, 0, 0.12)}

## ========== 圆角 ==========
const RADIUS_CARD := 12
const RADIUS_BAR := 4      # HP条圆角
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
    style.shadow_color = Color(0, 0, 0, 0.08)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0, 2)
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
    
    # 敌方波次/BOSS标记
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
    
    # 变化动画
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(label, "scale", Vector2.ONE, 0.2)
```

---

## Step 4：左侧CHAIN竖条（1-4级伙伴）

```gdscript
func _setup_chain_column() -> void:
    var column: VBoxContainer = $HUDLayer/LeftChainColumn
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 8)
    column.position = Vector2(20, 200)
    column.custom_minimum_size = Vector2(80, 0)
    
    # 标题
    var title := Label.new()
    title.text = "CHAIN"
    title.add_theme_font_size_override("font_size", 11)
    title.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    
    # 4个CHAIN槽位
    for i in range(4):
        var slot := _create_chain_slot(i)
        column.add_child(slot)

func _create_chain_slot(index: int) -> PanelContainer:
    var slot := PanelContainer.new()
    slot.name = "ChainSlot_%d" % index
    slot.custom_minimum_size = BattleUISettings.CHAIN_CARD_SIZE
    slot.set_meta("slot_index", index)
    
    # 默认未激活样式
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.94, 0.94, 0.96, 1)
    style.border_color = BattleUISettings.COLOR_CHAIN_INACTIVE
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    slot.add_theme_stylebox_override("panel", style)
    
    # 内部
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    slot.add_child(vbox)
    
    # 占位文字
    var placeholder := Label.new()
    placeholder.text = "?"
    placeholder.add_theme_font_size_override("font_size", 20)
    placeholder.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
    placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(placeholder)
    
    return slot

func _update_chain_display(partners: Array[Dictionary]) -> void:
    # 填入实际伙伴
    for i in range(min(partners.size(), 4)):
        var slot: PanelContainer = get_node("HUDLayer/LeftChainColumn/ChainSlot_%d" % i)
        var partner := partners[i]
        
        # 清除占位
        for child in slot.get_children():
            child.queue_free()
        
        # 激活样式
        var active_style := StyleBoxFlat.new()
        active_style.bg_color = BattleUISettings.COLOR_BG_CARD
        active_style.border_color = BattleUISettings.COLOR_CHAIN_ACTIVE
        active_style.border_width_left = 2
        active_style.border_width_top = 2
        active_style.border_width_right = 2
        active_style.border_width_bottom = 3
        active_style.corner_radius_top_left = 8
        active_style.corner_radius_top_right = 8
        active_style.corner_radius_bottom_left = 8
        active_style.corner_radius_bottom_right = 8
        active_style.shadow_color = Color(0.4, 0.6, 1.0, 0.15)
        active_style.shadow_size = 6
        slot.add_theme_stylebox_override("panel", active_style)
        
        # 小头像
        var avatar := TextureRect.new()
        avatar.custom_minimum_size = Vector2(48, 48)
        avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        var path: String = partner.get("avatar_path", "")
        if not path.is_empty():
            var tex: Texture2D = load(path)
            if tex != null:
                avatar.texture = tex
        slot.add_child(avatar)
        
        # 等级
        var lv_label := Label.new()
        lv_label.text = "Lv.%d" % partner.get("level", 1)
        lv_label.add_theme_font_size_override("font_size", 9)
        lv_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
        lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        slot.add_child(lv_label)
        
        # 激活入场动画
        slot.modulate.a = 0.0
        slot.scale = Vector2(0.8, 0.8)
        
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)
        tween.tween_property(slot, "modulate:a", 1.0, 0.25)
        tween.parallel().tween_property(slot, "scale", Vector2.ONE, 0.3)
```

---

## Step 5：中央战斗区 — 我方阵容卡片

```gdscript
func _create_hero_card(hero_data: Dictionary) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(BattleUISettings.CARD_WIDTH, BattleUISettings.CARD_HEIGHT)
    card.set_meta("entity_id", hero_data.get("id", ""))
    card.set_meta("entity_type", "hero")
    
    # 主角特殊边框（蓝色）
    var style := StyleBoxFlat.new()
    style.bg_color = BattleUISettings.COLOR_BG_CARD
    style.border_color = BattleUISettings.COLOR_BORDER_HERO
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 4
    style.corner_radius_top_left = BattleUISettings.RADIUS_CARD
    style.corner_radius_top_right = BattleUISettings.RADIUS_CARD
    style.corner_radius_bottom_left = BattleUISettings.RADIUS_CARD
    style.corner_radius_bottom_right = BattleUISettings.RADIUS_CARD
    style.shadow_color = BattleUISettings.SHADOW_CARD.color
    style.shadow_size = BattleUISettings.SHADOW_CARD.size
    style.shadow_offset = BattleUISettings.SHADOW_CARD.offset
    card.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 4)
    card.add_child(vbox)
    
    # 名字 + 主角标记
    var name_hbox := HBoxContainer.new()
    name_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(name_hbox)
    
    var name_label := Label.new()
    name_label.text = hero_data.get("name", "主角")
    name_label.add_theme_font_size_override("font_size", 15)
    name_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_MAIN)
    name_hbox.add_child(name_label)
    
    var leader_badge := Label.new()
    leader_badge.text = "★"
    leader_badge.add_theme_font_size_override("font_size", 12)
    leader_badge.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15, 1))
    name_hbox.add_child(leader_badge)
    
    # 等级
    var lv_label := Label.new()
    lv_label.text = "Lv.%d" % hero_data.get("level", 1)
    lv_label.add_theme_font_size_override("font_size", 11)
    lv_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(lv_label)
    
    # 头像
    var avatar := _create_battle_avatar(hero_data, BattleUISettings.CARD_AVATAR_SIZE)
    vbox.add_child(avatar)
    
    # HP条
    var hp_bar := _create_hp_bar(hero_data.get("hp", 100), hero_data.get("max_hp", 100))
    hp_bar.name = "HPBar"
    vbox.add_child(hp_bar)
    
    # 属性简版
    var stats_label := Label.new()
    stats_label.text = "攻:%d 防:%d" % [hero_data.get("atk", 0), hero_data.get("def", 0)]
    stats_label.add_theme_font_size_override("font_size", 10)
    stats_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(stats_label)
    
    return card

func _create_partner_battle_card(partner: Dictionary) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(BattleUISettings.CARD_WIDTH, BattleUISettings.CARD_HEIGHT - 20)
    card.set_meta("entity_id", partner.get("id", ""))
    card.set_meta("entity_type", "partner")
    
    # 普通伙伴边框（灰色）
    var style := StyleBoxFlat.new()
    style.bg_color = BattleUISettings.COLOR_BG_CARD
    style.border_color = BattleUISettings.COLOR_BORDER
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 3
    style.corner_radius_top_left = BattleUISettings.RADIUS_CARD
    style.corner_radius_top_right = BattleUISettings.RADIUS_CARD
    style.corner_radius_bottom_left = BattleUISettings.RADIUS_CARD
    style.corner_radius_bottom_right = BattleUISettings.RADIUS_CARD
    style.shadow_color = BattleUISettings.SHADOW_CARD.color
    style.shadow_size = BattleUISettings.SHADOW_CARD.size
    style.shadow_offset = BattleUISettings.SHADOW_CARD.offset
    card.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 4)
    card.add_child(vbox)
    
    # 名字
    var name_label := Label.new()
    name_label.text = partner.get("name", "伙伴")
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_MAIN)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(name_label)
    
    # 等级
    var lv_label := Label.new()
    lv_label.text = "Lv.%d" % partner.get("level", 1)
    lv_label.add_theme_font_size_override("font_size", 10)
    lv_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(lv_label)
    
    # 头像（略小）
    var avatar := _create_battle_avatar(partner, 100)
    vbox.add_child(avatar)
    
    # HP条
    var hp_bar := _create_hp_bar(partner.get("hp", 50), partner.get("max_hp", 50))
    hp_bar.name = "HPBar"
    vbox.add_child(hp_bar)
    
    return card

func _create_battle_avatar(entity_data: Dictionary, size: int) -> TextureRect:
    var container := PanelContainer.new()
    container.custom_minimum_size = Vector2(size, size)
    
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.95, 0.95, 0.97, 1)
    bg.corner_radius_top_left = 8
    bg.corner_radius_top_right = 8
    bg.corner_radius_bottom_left = 8
    bg.corner_radius_bottom_right = 8
    container.add_theme_stylebox_override("panel", bg)
    
    var avatar := TextureRect.new()
    avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    avatar.custom_minimum_size = Vector2(size, size)
    var path: String = entity_data.get("avatar_path", "")
    if not path.is_empty():
        var tex: Texture2D = load(path)
        if tex != null:
            avatar.texture = tex
    container.add_child(avatar)
    
    return container

func _create_hp_bar(current: int, maximum: int) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(120, BattleUISettings.HP_BAR_HEIGHT)
    bar.max_value = maximum
    bar.value = current
    bar.show_percentage = false
    
    # 自定义样式
    var fg := StyleBoxFlat.new()
    var hp_ratio := float(current) / maximum
    fg.bg_color = BattleUISettings.COLOR_HP_BAR_LOW if hp_ratio < 0.3 else BattleUISettings.COLOR_HP_BAR
    fg.corner_radius_top_left = BattleUISettings.RADIUS_BAR
    fg.corner_radius_top_right = BattleUISettings.RADIUS_BAR
    fg.corner_radius_bottom_left = BattleUISettings.RADIUS_BAR
    fg.corner_radius_bottom_right = BattleUISettings.RADIUS_BAR
    bar.add_theme_stylebox_override("fill", fg)
    
    var bg := StyleBoxFlat.new()
    bg.bg_color = BattleUISettings.COLOR_HP_BAR_BG
    bg.corner_radius_top_left = BattleUISettings.RADIUS_BAR
    bg.corner_radius_top_right = BattleUISettings.RADIUS_BAR
    bg.corner_radius_bottom_left = BattleUISettings.RADIUS_BAR
    bg.corner_radius_bottom_right = BattleUISettings.RADIUS_BAR
    bar.add_theme_stylebox_override("background", bg)
    
    return bar

func _update_hp_bar(bar: ProgressBar, new_hp: int, max_hp: int) -> void:
    var old_value := bar.value
    bar.max_value = max_hp
    
    # Tween动画过渡
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(bar, "value", new_hp, 0.3)
    
    # 颜色变化（低血量变红）
    var hp_ratio := float(new_hp) / max_hp
    var target_color := BattleUISettings.COLOR_HP_BAR_LOW if hp_ratio < 0.3 else BattleUISettings.COLOR_HP_BAR
    
    var fg: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
    fg.bg_color = target_color
    bar.add_theme_stylebox_override("fill", fg)
```

---

## Step 6：敌方阵容卡片

```gdscript
func _create_enemy_card(enemy_data: Dictionary) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(BattleUISettings.ENEMY_CARD_WIDTH, BattleUISettings.ENEMY_CARD_HEIGHT)
    card.set_meta("entity_id", enemy_data.get("id", ""))
    card.set_meta("entity_type", "enemy")
    
    # 敌方特殊样式（微红底+红边框）
    var style := StyleBoxFlat.new()
    style.bg_color = BattleUISettings.COLOR_BG_CARD_ENEMY
    style.border_color = BattleUISettings.COLOR_BORDER_ENEMY
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 3
    style.corner_radius_top_left = BattleUISettings.RADIUS_CARD
    style.corner_radius_top_right = BattleUISettings.RADIUS_CARD
    style.corner_radius_bottom_left = BattleUISettings.RADIUS_CARD
    style.corner_radius_bottom_right = BattleUISettings.RADIUS_CARD
    style.shadow_color = Color(0.5, 0.1, 0.1, 0.1)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 3)
    card.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 4)
    card.add_child(vbox)
    
    # 名字
    var name_label := Label.new()
    name_label.text = enemy_data.get("name", "敌人")
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.2, 1))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(name_label)
    
    # 等级/类型
    var type_label := Label.new()
    type_label.text = enemy_data.get("type_desc", "普通")
    type_label.add_theme_font_size_override("font_size", 10)
    type_label.add_theme_color_override("font_color", BattleUISettings.COLOR_TEXT_SECOND)
    type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(type_label)
    
    # 头像（如未解锁显示剪影）
    var avatar_container := PanelContainer.new()
    avatar_container.custom_minimum_size = Vector2(BattleUISettings.ENEMY_AVATAR_SIZE, BattleUISettings.ENEMY_AVATAR_SIZE)
    var avatar_bg := StyleBoxFlat.new()
    avatar_bg.bg_color = Color(0.9, 0.85, 0.85, 1)
    avatar_bg.corner_radius_top_left = 8
    avatar_bg.corner_radius_top_right = 8
    avatar_bg.corner_radius_bottom_left = 8
    avatar_bg.corner_radius_bottom_right = 8
    avatar_container.add_theme_stylebox_override("panel", avatar_bg)
    vbox.add_child(avatar_container)
    
    var avatar := TextureRect.new()
    avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    avatar.custom_minimum_size = Vector2(BattleUISettings.ENEMY_AVATAR_SIZE, BattleUISettings.ENEMY_AVATAR_SIZE)
    var path: String = enemy_data.get("avatar_path", "")
    if not path.is_empty():
        var tex: Texture2D = load(path)
        if tex != null:
            avatar.texture = tex
        else:
            # 未解锁/无图时显示剪影色块
            avatar.modulate = Color(0.5, 0.4, 0.4, 0.3)
    avatar_container.add_child(avatar)
    
    # HP条
    var hp_bar := _create_hp_bar(enemy_data.get("hp", 30), enemy_data.get("max_hp", 30))
    hp_bar.name = "HPBar"
    vbox.add_child(hp_bar)
    
    # 威胁度/意图（如有）
    var intent_label := Label.new()
    intent_label.text = enemy_data.get("intent", "准备攻击")
    intent_label.add_theme_font_size_override("font_size", 9)
    intent_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3, 1))
    intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(intent_label)
    
    return card
```

---

## Step 7：VS中央区 + 战斗日志

```gdscript
func _setup_center_area() -> void:
    var center: VBoxContainer = $HUDLayer/CenterBattleArea/VSCenter
    center.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_theme_constant_override("separation", 12)
    
    # VS 标志
    var vs_label := Label.new()
    vs_label.text = "VS"
    vs_label.add_theme_font_size_override("font_size", 32)
    vs_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15, 1))  # 金色
    vs_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
    vs_label.add_theme_constant_override("shadow_offset_x", 2)
    vs_label.add_theme_constant_override("shadow_offset_y", 2)
    vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(vs_label)
    
    # 战斗日志（RichTextLabel支持颜色）
    var log_box := RichTextLabel.new()
    log_box.name = "BattleLog"
    log_box.custom_minimum_size = Vector2(200, 150)
    log_box.scroll_active = true
    log_box.bbcode_enabled = true
    
    # 日志框样式
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

func _add_battle_log(text: String, color: Color = BattleUISettings.COLOR_TEXT_MAIN) -> void:
    var log: RichTextLabel = $HUDLayer/CenterBattleArea/VSCenter/BattleLog
    var color_hex := color.to_html()
    log.append_text("[color=%s]%s[/color]\n" % [color_hex, text])
    log.scroll_to_line(log.get_line_count())
    
    # 新消息提示动画（log框边框闪烁）
    var flash_tween := create_tween()
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
    
    flash_tween.tween_callback(func():
        var normal := StyleBoxFlat.new()
        normal.bg_color = Color(0.98, 0.98, 0.99, 0.9)
        normal.border_color = BattleUISettings.COLOR_BORDER
        normal.border_width_left = 1
        normal.border_width_top = 1
        normal.border_width_right = 1
        normal.border_width_bottom = 1
        normal.corner_radius_top_left = 8
        normal.corner_radius_top_right = 8
        normal.corner_radius_bottom_left = 8
        normal.corner_radius_bottom_right = 8
        log.add_theme_stylebox_override("normal", normal)
    ).set_delay(0.3)
```

---

## Step 8：入场动画（双方滑入）

```gdscript
func _play_battle_entrance() -> void:
    # 获取所有卡片
    var left_cards := _get_left_cards()   # 我方
    var right_cards := _get_right_cards()  # 敌方
    
    # 初始状态
    for card in left_cards:
        card.modulate.a = 0.0
        card.position.x -= 60
    for card in right_cards:
        card.modulate.a = 0.0
        card.position.x += 60
    
    # 左侧卡片从左滑入
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
    var vs_label: Label = $HUDLayer/CenterBattleArea/VSCenter/VSLabel
    vs_label.scale = Vector2(0.5, 0.5)
    vs_label.modulate.a = 0.0
    
    var vs_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.4)
    vs_tween.tween_property(vs_label, "scale", Vector2.ONE, 0.35)
    vs_tween.parallel().tween_property(vs_label, "modulate:a", 1.0, 0.3)
    
    # 战斗日志淡入
    var log_box: RichTextLabel = $HUDLayer/CenterBattleArea/VSCenter/BattleLog
    log_box.modulate.a = 0.0
    var log_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.6)
    log_tween.tween_property(log_box, "modulate:a", 1.0, 0.3)
```

---

## Step 9：攻击动画系统

```gdscript
## ========== 5级伙伴飞出攻击 ==========
func _play_level5_attack(partner_card: Control, target_card: Control, damage: int) -> void:
    # 克隆卡片用于飞行动画
    var flyer := partner_card.duplicate()
    flyer.z_index = 100
    $BattleLayer/BattleField.add_child(flyer)
    
    var start_pos := partner_card.global_position
    var end_pos := target_card.global_position
    
    # 设置起始位置
    flyer.global_position = start_pos
    
    # 飞出路径：直线飞向目标 + 旋转
    var fly_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly_tween.tween_property(flyer, "global_position", end_pos, BattleUISettings.ATTACK_FLY_DURATION)
    fly_tween.parallel().tween_property(flyer, "rotation_degrees", 360.0, BattleUISettings.ATTACK_FLY_DURATION)
    fly_tween.parallel().tween_property(flyer, "scale", Vector2(1.1, 1.1), BattleUISettings.ATTACK_FLY_DURATION * 0.5)
    
    await fly_tween.finished
    
    # 到达后：目标受击 + 伤害数字
    _play_hit_effect(target_card, damage)
    
    #  flyer消失
    var fade_tween := create_tween()
    fade_tween.tween_property(flyer, "modulate:a", 0.0, 0.15)
    await fade_tween.finished
    flyer.queue_free()
    
    # 原卡片恢复
    var restore_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    restore_tween.tween_property(partner_card, "scale", Vector2.ONE, 0.2)

## ========== 1-4级CHAIN攻击（从CHAIN竖条飞出） ==========
func _play_chain_attack(slot_index: int, target_card: Control, damage: int) -> void:
    var slot: Control = get_node("HUDLayer/LeftChainColumn/ChainSlot_%d" % slot_index)
    
    # 发光效果
    var glow_tween := create_tween()
    glow_tween.tween_property(slot, "modulate", Color(1.2, 1.2, 1.5, 1.0), 0.15)
    glow_tween.tween_property(slot, "modulate", Color.WHITE, 0.2)
    
    # 能量线/飞弹从CHAIN槽飞向目标
    var projectile := ColorRect.new()
    projectile.custom_minimum_size = Vector2(12, 12)
    projectile.color = BattleUISettings.COLOR_CHAIN_ACTIVE
    projectile.position = slot.global_position + Vector2(40, 40)
    projectile.z_index = 100
    $BattleLayer/BattleField.add_child(projectile)
    
    var target_pos := target_card.global_position + Vector2(80, 80)
    
    var fly_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly_tween.tween_property(projectile, "position", target_pos, 0.35)
    
    await fly_tween.finished
    
    # 命中爆炸效果
    _play_hit_effect(target_card, damage)
    
    projectile.queue_free()

## ========== 主角/敌方普通攻击 ==========
func _play_normal_attack(attacker_card: Control, target_card: Control, damage: int) -> void:
    # 攻击者前移
    var original_x := attacker_card.position.x
    var attack_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    attack_tween.tween_property(attacker_card, "position:x", original_x + (20 if attacker_card.get_meta("entity_type") != "enemy" else -20), 0.12)
    attack_tween.tween_property(attacker_card, "position:x", original_x, 0.18).set_trans(Tween.TRANS_BACK)
    
    await attack_tween.finished
    
    # 目标受击
    _play_hit_effect(target_card, damage)

## ========== 受击效果（抖动+闪红+伤害飘字） ==========
func _play_hit_effect(target_card: Control, damage: int) -> void:
    # 闪红
    var flash_tween := create_tween()
    flash_tween.tween_property(target_card, "modulate", Color(1, 0.5, 0.5, 1), 0.05)
    flash_tween.tween_property(target_card, "modulate", Color.WHITE, 0.15)
    
    # 抖动
    var original_x := target_card.position.x
    var shake_tween := create_tween()
    shake_tween.tween_property(target_card, "position:x", original_x - 4, 0.03)
    shake_tween.tween_property(target_card, "position:x", original_x + 4, 0.03)
    shake_tween.tween_property(target_card, "position:x", original_x - 2, 0.03)
    shake_tween.tween_property(target_card, "position:x", original_x, 0.03)
    
    # 伤害数字飘字
    _show_damage_float(target_card.global_position + Vector2(60, 20), damage)
    
    # HP条更新
    var hp_bar: ProgressBar = target_card.get_node("HPBar")
    if hp_bar != null:
        var new_hp := max(0, int(hp_bar.value) - damage)
        _update_hp_bar(hp_bar, new_hp, int(hp_bar.max_value))

func _show_damage_float(pos: Vector2, damage: int, is_critical: bool = false) -> void:
    var label := Label.new()
    label.text = "-%d" % damage if not is_critical else "-%d!" % damage
    label.add_theme_font_size_override("font_size", 24 if not is_critical else 32)
    label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1) if not is_critical else Color(0.9, 0.5, 0.1, 1))
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.position = pos
    label.z_index = 200
    $BattleLayer/BattleField.add_child(label)
    
    # 飘字动画：向上飘 + 放大 + 淡出
    var float_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    float_tween.tween_property(label, "position:y", pos.y - 50, BattleUISettings.DAMAGE_FLOAT_DURATION)
    float_tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), BattleUISettings.DAMAGE_FLOAT_DURATION * 0.3)
    float_tween.parallel().tween_property(label, "modulate:a", 0.0, BattleUISettings.DAMAGE_FLOAT_DURATION)
    
    await float_tween.finished
    label.queue_free()
```

---

## Step 10：底部操作栏

```gdscript
func _setup_bottom_action_bar() -> void:
    var bar: HBoxContainer = $HUDLayer/BottomActionBar
    bar.alignment = BoxContainer.ALIGNMENT_CENTER
    bar.add_theme_constant_override("separation", 16)
    bar.custom_minimum_size = Vector2(0, BattleUISettings.BOTTOM_BAR_HEIGHT)
    bar.position = Vector2(0, 620)
    
    # 背景
    var bg := PanelContainer.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    var bg_style := StyleBoxFlat.new()
    bg_style.bg_color = Color(1.0, 1.0, 1.0, 0.9)
    bg_style.border_color = BattleUISettings.COLOR_BORDER
    bg_style.border_width_left = 0
    bg_style.border_width_top = 2
    bg_style.border_width_right = 0
    bg_style.border_width_bottom = 0
    bg_style.corner_radius_top_left = 12
    bg_style.corner_radius_top_right = 12
    bg_style.shadow_color = Color(0, 0, 0, 0.08)
    bg_style.shadow_size = -6  # 向上阴影
    bg.add_theme_stylebox_override("panel", bg_style)
    bar.add_child(bg)
    
    # 速度控制组
    var speed_group := HBoxContainer.new()
    speed_group.alignment = BoxContainer.ALIGNMENT_CENTER
    speed_group.add_theme_constant_override("separation", 4)
    bar.add_child(speed_group)
    
    # 1x速度
    var speed1x := Button.new()
    speed1x.text = "1x"
    speed1x.toggle_mode = true
    speed1x.button_pressed = true
    speed1x.custom_minimum_size = Vector2(48, 36)
    _apply_speed_button_style(speed1x)
    speed1x.pressed.connect(_on_speed_changed.bind(1.0))
    speed_group.add_child(speed1x)
    
    # 2x速度
    var speed2x := Button.new()
    speed2x.text = "2x"
    speed2x.toggle_mode = true
    speed2x.custom_minimum_size = Vector2(48, 36)
    _apply_speed_button_style(speed2x)
    speed2x.pressed.connect(_on_speed_changed.bind(2.0))
    speed_group.add_child(speed2x)
    
    # 跳过按钮
    var skip_btn := Button.new()
    skip_btn.text = "跳过"
    skip_btn.custom_minimum_size = Vector2(80, 40)
    _apply_secondary_button_style(skip_btn)
    skip_btn.pressed.connect(_on_skip_animation)
    bar.add_child(skip_btn)

func _apply_speed_button_style(button: Button) -> void:
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
    pressed.bg_color = BattleUISettings.COLOR_CHAIN_ACTIVE
    pressed.border_color = BattleUISettings.COLOR_CHAIN_ACTIVE
    pressed.corner_radius_top_left = 6
    pressed.corner_radius_top_right = 6
    pressed.corner_radius_bottom_left = 6
    pressed.corner_radius_bottom_right = 6
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _on_speed_changed(speed: float) -> void:
    _animation_speed = speed
    AudioManager.play_ui("click")

func _on_skip_animation() -> void:
    _skip_requested = true
    AudioManager.play_ui("click")
```

---

## Step 11：战斗结算界面

### 胜利面板

```gdscript
func _show_victory_panel(rewards: Dictionary) -> void:
    var panel: PanelContainer = $PopupLayer/VictoryPanel
    
    # 样式
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
    style.border_color = Color(0.3, 0.7, 0.4, 1)  # 胜利绿边框
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
    
    # 胜利标题
    var title := Label.new()
    title.text = "胜利!"
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4, 1))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 奖励信息
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
    
    # 继续按钮
    var continue_btn := Button.new()
    continue_btn.text = "继续"
    continue_btn.custom_minimum_size = Vector2(160, 48)
    _apply_primary_button_style(continue_btn)
    continue_btn.pressed.connect(_on_victory_continue)
    vbox.add_child(continue_btn)
    
    # 入场动画
    _popup_entrance(panel)

### 失败面板
func _show_defeat_panel() -> void:
    var panel: PanelContainer = $PopupLayer/DefeatPanel
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
    style.border_color = Color(0.8, 0.3, 0.3, 1)  # 失败红边框
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

## 通用弹窗动画
func _popup_entrance(panel: PanelContainer) -> void:
    panel.visible = true
    panel.scale = Vector2(0.85, 0.85)
    panel.modulate.a = 0.0
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(panel, "scale", Vector2.ONE, 0.35)
    tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
```

---

## Step 12：通用按钮样式

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
    
    # 点击弹跳
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
    hover.border_color = BattleUISettings.COLOR_CHAIN_ACTIVE
    hover.corner_radius_top_left = 8
    hover.corner_radius_top_right = 8
    hover.corner_radius_bottom_left = 8
    hover.corner_radius_bottom_right = 8
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_color_override("font_hover_color", BattleUISettings.COLOR_CHAIN_ACTIVE)
```

---

## 测试验收标准

- [ ] 进入战斗：爬塔场景淡入切到战斗场景（0.4s黑屏过渡）
- [ ] 背景：根据战斗类型（普通/精英/BOSS）显示不同背景色调
- [ ] 顶部栏：白底+底部灰边+下圆角+阴影，显示"回合 X"+敌方信息+暂停按钮
- [ ] 回合变化："回合 X"scale弹跳1.2x动画
- [ ] 左侧CHAIN竖条：4个槽位，未激活=灰底灰边框+"?"占位
- [ ] CHAIN激活：白底+蓝色边框+底部加粗+伙伴小头像+等级
- [ ] CHAIN入场：依次从透明+scale0.8弹跳到正常（间隔0.1s）
- [ ] 我方阵容：主角蓝色粗边框（3px）+★标记，伙伴普通灰边框
- [ ] 卡片：180x240白底+圆角12px+8px阴影，头像120x120正方形+8px圆角
- [ ] HP条：绿色填充（低血量<30%变红）+灰色背景+4px圆角，更新时Tween过渡0.3s
- [ ] 敌方阵容：微红底+红边框，名字红色，显示意图文字
- [ ] 中央VS：金色32px，入场scale0.5→1.0弹跳+淡入
- [ ] 战斗日志：RichTextLabel支持BBCode颜色，9成透明白底+灰边框，新消息边框闪烁蓝色0.3s
- [ ] 入场动画：我方从左滑入（间隔0.12s），敌方从右滑入（延迟0.2s）
- [ ] 5级伙伴飞出攻击：卡片克隆→飞向目标+旋转360°+scale1.1→命中爆炸→消失
- [ ] 1-4级CHAIN攻击：CHAIN槽发光→能量 projectile 飞出0.35s→命中
- [ ] 普通攻击：攻击者前移20px→弹回
- [ ] 受击效果：目标闪红0.05s+左右抖动4px+HP条Tween更新
- [ ] 伤害飘字：红色"-X"向上飘50px+scale1.2+淡出0.6s，暴击橙色大字号"-X!"
- [ ] 底部操作栏：白底+顶部灰边+上圆角，速度按钮1x/2x（选中=蓝底白字），跳过按钮
- [ ] 胜利面板：绿色边框+"胜利!"+金币/经验奖励+"继续"蓝色按钮
- [ ] 失败面板：红色边框+"战斗失败"+"重新开始"/"返回主菜单"按钮
- [ ] 结算面板入场：scale0.85→1.0弹跳+淡入
- [ ] 暂停菜单：半透明遮罩+白底面板+"继续"/"返回爬塔"/"退出"
- [ ] 1280x720 和 1920x1080 布局正常
- [ ] Tween资源正确清理，切换场景无内存泄漏
