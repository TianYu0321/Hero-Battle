# 任务卡：局内UI统一改造（爬塔主场景 + 战斗 + 事件弹窗）

## 参考来源（已分析的真实项目）

### 1. StephenMRicks85/turn-based-deckbuilder-godot（Godot 4回合制卡牌构建）
- **combat_scene.gd** — combat state / UI / resolution logic 三层分离
- **improvise_modal.gd** — UI-driven gameplay effect 弹窗模式
- **dialog_scene.gd** — JSON-driven dialogue，场景间 clean transition
- 截图显示：顶部手牌区 + 中央战斗区 + 底部玩家状态栏的横版布局

### 2. balbonits/infinite-dungeon-game（Godot 4.6 + C# 地下城爬行者）
- **Diablo-style HUD**：HP/MP orbs + skill hotbar + XP progress bar
- **顶部信息栏**：金币、深度、当前区域
- **底部快捷栏**：技能/物品快捷使用

### 3. IYanel-DEV/MainMenu-MP（已下载分析）
- **StyleBoxFlat shadow系统**：`shadow_size=6` + `shadow_offset=Vector2(0,2)`
- **White主题**：纯白底 + 浅灰边框 + 蓝色hover边框

### 4. chun92/card-framework（已分析）
- **Tween-Based Movement**：平滑可中断动画
- **Hover Effects**：scale + position 双重效果
- **State Machine**：状态标记防止hover/click冲突

---

## 第一部分：爬塔主场景 HUD 改造

### 场景结构

```
RunMain (Control)
├── BackgroundLayer (CanvasLayer, layer=0)
│   ├── ColorRect                    # 游戏背景色
│   └── TowerMapBackground           # 爬塔地图背景纹理
├── GameLayer (CanvasLayer, layer=1)
│   └── TowerMapContainer            # 爬塔地图节点（保留原有）
├── HUDLayer (CanvasLayer, layer=5)  # 局内HUD层
│   ├── TopBar (PanelContainer)
│   │   ├── LeftGroup (HBoxContainer)
│   │   │   ├── GoldDisplay (HBoxContainer)        # 金币
│   │   │   ├── RoundDisplay (HBoxContainer)       # 回合
│   │   │   └── FloorDisplay (HBoxContainer)       # 当前层
│   │   ├── CenterGroup (HBoxContainer)
│   │   │   └── DifficultyIndicator (Label)      # 新手/老手
│   │   └── RightGroup (HBoxContainer)
│   │       ├── PauseButton (Button)               # 暂停
│   │       └── SettingsButton (Button)            # 设置
│   ├── PartnerChainBar (HBoxContainer)            # 底部伙伴CHAIN条
│   │   ├── PartnerCard_1 (PanelContainer)
│   │   ├── PartnerCard_2 (PanelContainer)
│   │   └── PartnerCard_3 (PanelContainer)
│   └── EventPopupAnchor (Control)                 # 事件弹窗锚点
├── PopupLayer (CanvasLayer, layer=10)
│   ├── ShopPopup (PanelContainer)                 # 商店
│   ├── TrainingPopup (PanelContainer)             # 训练
│   ├── RescuePopup (PanelContainer)               # 营救
│   ├── OutingPopup (PanelContainer)               # 外出事件
│   ├── PauseMenu (PanelContainer)               # 暂停菜单
│   └── SettingsPanel (PanelContainer)           # 设置面板
└── TransitionOverlay (ColorRect, z_index=100)
```

---

### 1.1 顶部信息栏

```gdscript
## ========== 局内基础色（和选人/酒馆保持一致）==========
const COLOR_BG_HUD    := Color(1.0,   1.0,   1.0,   0.92)   # 白底稍透
const COLOR_BG_SOLID  := Color(1.0,   1.0,   1.0,   1.0)
const COLOR_BORDER    := Color(0.85,  0.85,  0.85,  1.0)
const COLOR_BORDER_HOVER := Color(0.4, 0.6, 1.0, 1.0)
const COLOR_TEXT_MAIN  := Color(0.2,   0.2,   0.2,   1.0)
const COLOR_TEXT_SECOND := Color(0.5,  0.5,   0.5,   1.0)
const COLOR_TEXT_GOLD  := Color(0.85,  0.65,  0.15,  1.0)    # 亮金-金币

func _setup_top_bar() -> void:
    var top_bar: PanelContainer = $HUDLayer/TopBar
    
    # 顶部栏样式：白底 + 底部边框 + 轻微阴影
    var style := StyleBoxFlat.new()
    style.bg_color = COLOR_BG_HUD
    style.border_color = COLOR_BORDER
    style.border_width_left = 0
    style.border_width_top = 0
    style.border_width_right = 0
    style.border_width_bottom = 2
    style.corner_radius_top_left = 0
    style.corner_radius_top_right = 0
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = Color(0, 0, 0, 0.1)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 4)
    top_bar.add_theme_stylebox_override("panel", style)
    
    top_bar.custom_minimum_size = Vector2(0, 56)
    top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _setup_gold_display() -> void:
    var container: HBoxContainer = $HUDLayer/TopBar/LeftGroup/GoldDisplay
    container.add_theme_constant_override("separation", 6)
    
    # 金币图标（TextureRect）
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(24, 24)
    # icon.texture = preload("res://assets/ui/gold_icon.png")
    container.add_child(icon)
    
    # 金币数值
    var label := Label.new()
    label.name = "GoldLabel"
    label.text = "0"
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
    container.add_child(label)
    
    # 更新方法
    _update_gold_display()

func _update_gold_display() -> void:
    var label: Label = $HUDLayer/TopBar/LeftGroup/GoldDisplay/GoldLabel
    label.text = str(GameManager.gold)
    
    # 金币变化动画：缩放弹跳
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(label, "scale", Vector2.ONE, 0.2)

func _setup_round_display() -> void:
    var container: HBoxContainer = $HUDLayer/TopBar/LeftGroup/RoundDisplay
    container.add_theme_constant_override("separation", 4)
    
    var prefix := Label.new()
    prefix.text = "回合"
    prefix.add_theme_font_size_override("font_size", 12)
    prefix.add_theme_color_override("font_color", COLOR_TEXT_SECOND)
    container.add_child(prefix)
    
    var label := Label.new()
    label.name = "RoundLabel"
    label.text = "1"
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
    container.add_child(label)

func _setup_floor_display() -> void:
    var container: HBoxContainer = $HUDLayer/TopBar/LeftGroup/FloorDisplay
    container.add_theme_constant_override("separation", 4)
    
    var prefix := Label.new()
    prefix.text = "第"
    prefix.add_theme_font_size_override("font_size", 12)
    prefix.add_theme_color_override("font_color", COLOR_TEXT_SECOND)
    container.add_child(prefix)
    
    var label := Label.new()
    label.name = "FloorLabel"
    label.text = "1"
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
    container.add_child(label)
    
    var suffix := Label.new()
    suffix.text = "层"
    suffix.add_theme_font_size_override("font_size", 12)
    suffix.add_theme_color_override("font_color", COLOR_TEXT_SECOND)
    container.add_child(suffix)

func _setup_difficulty_indicator() -> void:
    var label: Label = $HUDLayer/TopBar/CenterGroup/DifficultyIndicator
    label.text = "新手模式" if not GameManager.pending_archive.get("is_veteran", false) else "老手模式"
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", COLOR_TEXT_SECOND)

func _setup_top_buttons() -> void:
    # 暂停按钮
    _pause_btn.custom_minimum_size = Vector2(40, 40)
    _pause_btn.text = "||"
    _pause_btn.add_theme_font_size_override("font_size", 16)
    _apply_icon_button_style(_pause_btn)
    
    # 设置按钮
    _settings_btn.custom_minimum_size = Vector2(40, 40)
    _settings_btn.text = "⚙"
    _settings_btn.add_theme_font_size_override("font_size", 16)
    _apply_icon_button_style(_settings_btn)

func _apply_icon_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.96, 0.96, 0.98, 1)
    normal.border_color = COLOR_BORDER
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
    button.add_theme_color_override("font_color", COLOR_TEXT_SECOND)
    
    var hover := StyleBoxFlat.new()
    hover.bg_color = COLOR_BG_SOLID
    hover.border_color = COLOR_BORDER_HOVER
    hover.corner_radius_top_left = 8
    hover.corner_radius_top_right = 8
    hover.corner_radius_bottom_left = 8
    hover.corner_radius_bottom_right = 8
    hover.shadow_color = Color(0.4, 0.6, 1.0, 0.1)
    hover.shadow_size = 6
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_color_override("font_hover_color", COLOR_BORDER_HOVER)
```

---

### 1.2 底部伙伴CHAIN条（参考 deckbuilder 底部手牌区）

```gdscript
const CHAIN_CARD_WIDTH := 180
const CHAIN_CARD_HEIGHT := 80
const CHAIN_AVATAR_SIZE := 56

func _setup_partner_chain_bar() -> void:
    var chain_bar: HBoxContainer = $HUDLayer/PartnerChainBar
    chain_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    chain_bar.add_theme_constant_override("separation", 12)
    chain_bar.position = Vector2(0, 640)  # 底部偏上
    chain_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _update_partner_chain_display(partners: Array[Dictionary]) -> void:
    var chain_bar: HBoxContainer = $HUDLayer/PartnerChainBar
    
    # 清空旧卡片
    for child in chain_bar.get_children():
        child.queue_free()
    
    for partner in partners:
        var card := _create_chain_card(partner)
        chain_bar.add_child(card)
    
    # 入场动画：依次弹跳
    var cards := chain_bar.get_children()
    for i in range(cards.size()):
        var card: Control = cards[i]
        card.scale = Vector2(0.9, 0.9)
        card.modulate.a = 0.0
        
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.08)
        tween.tween_property(card, "scale", Vector2.ONE, 0.25)
        tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2)

func _create_chain_card(partner: Dictionary) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(CHAIN_CARD_WIDTH, CHAIN_CARD_HEIGHT)
    
    # 样式：白底 + 浅灰边框 + 底部加粗 + 圆角 + 阴影
    var style := StyleBoxFlat.new()
    style.bg_color = COLOR_BG_SOLID
    style.border_color = COLOR_BORDER
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 3
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    style.shadow_color = Color(0, 0, 0, 0.08)
    style.shadow_size = 4
    style.shadow_offset = Vector2(0, 2)
    card.add_theme_stylebox_override("panel", style)
    
    var hbox := HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 8)
    card.add_child(hbox)
    
    # 头像（正方形）
    var avatar_container := PanelContainer.new()
    avatar_container.custom_minimum_size = Vector2(CHAIN_AVATAR_SIZE, CHAIN_AVATAR_SIZE)
    var avatar_bg := StyleBoxFlat.new()
    avatar_bg.bg_color = Color(0.95, 0.95, 0.97, 1)
    avatar_bg.corner_radius_top_left = 6
    avatar_bg.corner_radius_top_right = 6
    avatar_bg.corner_radius_bottom_left = 6
    avatar_bg.corner_radius_bottom_right = 6
    avatar_container.add_theme_stylebox_override("panel", avatar_bg)
    hbox.add_child(avatar_container)
    
    var avatar := TextureRect.new()
    avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    avatar.custom_minimum_size = Vector2(CHAIN_AVATAR_SIZE, CHAIN_AVATAR_SIZE)
    var avatar_path: String = partner.get("avatar_path", "")
    if not avatar_path.is_empty():
        var tex: Texture2D = load(avatar_path)
        if tex != null:
            avatar.texture = tex
    avatar_container.add_child(avatar)
    
    # 信息区
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 2)
    hbox.add_child(vbox)
    
    var name_label := Label.new()
    name_label.text = partner.get("name", "???")
    name_label.add_theme_font_size_override("font_size", 13)
    name_label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
    vbox.add_child(name_label)
    
    var level_label := Label.new()
    level_label.text = "Lv.%d" % partner.get("level", 1)
    level_label.add_theme_font_size_override("font_size", 11)
    level_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
    vbox.add_child(level_label)
    
    # Hover效果
    card.mouse_entered.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.12)
        tween.parallel().tween_property(card, "position:y", card.position.y - 4, 0.12)
        
        var hover_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
        hover_style.border_color = COLOR_BORDER_HOVER
        hover_style.shadow_size = 8
        card.add_theme_stylebox_override("panel", hover_style)
    )
    card.mouse_exited.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(card, "scale", Vector2.ONE, 0.15)
        tween.parallel().tween_property(card, "position:y", card.position.y + 4, 0.15)
        
        var base_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
        base_style.border_color = COLOR_BORDER
        base_style.shadow_size = 4
        card.add_theme_stylebox_override("panel", base_style)
    )
    
    return card
```

---

## 第二部分：战斗面板改造

### 2.1 战斗面板结构（参考 turn-based-deckbuilder 横版布局）

```
BattlePanel (CanvasLayer, layer=6)
├── TopInfoBar (HBoxContainer)
│   ├── TurnIndicator (Label)          # "回合 X"
│   ├── RoundProgress (ProgressBar)    # 回合进度
│   └── SkipButton (Button)            # 跳过动画
├── MainBattleArea (HBoxContainer)
│   ├── LeftColumn (VBoxContainer)       # 我方伙伴
│   │   ├── HeroCard (PanelContainer)    # 主角
│   │   ├── PartnerCard_1 (PanelContainer)
│   │   └── PartnerCard_2 (PanelContainer)
│   ├── CenterColumn (VBoxContainer)     # VS + 战斗信息
│   │   ├── VSLabel (Label)
│   │   └── BattleLog (RichTextLabel)    # 战斗日志
│   └── RightColumn (VBoxContainer)    # 敌方
│       └── EnemyCard (PanelContainer)
└── BottomActionBar (HBoxContainer)      # 手动操作按钮（如有）
```

### 2.2 战斗卡片样式（参考 card-framework 标准卡片）

```gdscript
const BATTLE_CARD_WIDTH := 200
const BATTLE_CARD_HEIGHT := 260
const BATTLE_AVATAR_SIZE := 140

func _create_battle_card(entity_data: Dictionary, is_enemy: bool = false) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(BATTLE_CARD_WIDTH, BATTLE_CARD_HEIGHT)
    
    # 基础样式
    var style := StyleBoxFlat.new()
    if is_enemy:
        style.bg_color = Color(0.98, 0.92, 0.92, 1)      # 敌方微红底
        style.border_color = Color(0.8, 0.5, 0.5, 1)     # 红边框
    else:
        style.bg_color = COLOR_BG_SOLID                   # 我方白底
        style.border_color = COLOR_BORDER
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 3
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = Color(0, 0, 0, 0.1)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 4)
    card.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 6)
    card.add_child(vbox)
    
    # 名字
    var name_label := Label.new()
    name_label.text = entity_data.get("name", "???")
    name_label.add_theme_font_size_override("font_size", 16)
    name_label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(name_label)
    
    # 等级
    var level_label := Label.new()
    level_label.text = "Lv.%d" % entity_data.get("level", 1)
    level_label.add_theme_font_size_override("font_size", 11)
    level_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(level_label)
    
    # 头像
    var avatar_container := PanelContainer.new()
    avatar_container.custom_minimum_size = Vector2(BATTLE_AVATAR_SIZE, BATTLE_AVATAR_SIZE)
    var avatar_bg := StyleBoxFlat.new()
    avatar_bg.bg_color = Color(0.95, 0.95, 0.97, 1)
    avatar_bg.corner_radius_top_left = 8
    avatar_bg.corner_radius_top_right = 8
    avatar_bg.corner_radius_bottom_left = 8
    avatar_bg.corner_radius_bottom_right = 8
    avatar_container.add_theme_stylebox_override("panel", avatar_bg)
    vbox.add_child(avatar_container)
    
    var avatar := TextureRect.new()
    avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    avatar.custom_minimum_size = Vector2(BATTLE_AVATAR_SIZE, BATTLE_AVATAR_SIZE)
    var avatar_path: String = entity_data.get("avatar_path", "")
    if not avatar_path.is_empty():
        var tex: Texture2D = load(avatar_path)
        if tex != null:
            avatar.texture = tex
    avatar_container.add_child(avatar)
    
    # 五维简版（HP条 + 2个主要属性）
    var stats_hbox := HBoxContainer.new()
    stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    stats_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(stats_hbox)
    
    var hp_label := Label.new()
    hp_label.text = "HP: %d/%d" % [entity_data.get("hp", 0), entity_data.get("max_hp", 1)]
    hp_label.add_theme_font_size_override("font_size", 12)
    hp_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
    stats_hbox.add_child(hp_label)
    
    # 入场动画：从下方滑入+淡入
    card.modulate.a = 0.0
    card.position.y += 30
    
    return card

func _play_battle_entrance(left_cards: Array[Control], right_cards: Array[Control]) -> void:
    ## 左方卡片从左滑入
    for i in range(left_cards.size()):
        var card: Control = left_cards[i]
        card.position.x -= 50
        
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)
        tween.tween_property(card, "modulate:a", 1.0, 0.3)
        tween.parallel().tween_property(card, "position:x", card.position.x + 50, 0.35)
        tween.parallel().tween_property(card, "position:y", card.position.y - 30, 0.35)
    
    ## 右方卡片从右滑入
    for i in range(right_cards.size()):
        var card: Control = right_cards[i]
        card.position.x += 50
        
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.2 + i * 0.1)
        tween.tween_property(card, "modulate:a", 1.0, 0.3)
        tween.parallel().tween_property(card, "position:x", card.position.x - 50, 0.35)
        tween.parallel().tween_property(card, "position:y", card.position.y - 30, 0.35)

## === 攻击动画（卡片抖动 + 目标闪红）===
func _play_attack_animation(attacker: Control, target: Control, damage: int) -> void:
    # 攻击者前移
    var attack_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    attack_tween.tween_property(attacker, "position:x", attacker.position.x + 20, 0.1)
    attack_tween.tween_property(attacker, "position:x", attacker.position.x, 0.15).set_trans(Tween.TRANS_BACK)
    
    # 目标受击闪红+抖动
    var hit_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.08)
    hit_tween.tween_property(target, "modulate", Color(1, 0.5, 0.5, 1), 0.05)
    hit_tween.parallel().tween_property(target, "position:x", target.position.x - 3, 0.03)
    hit_tween.tween_property(target, "position:x", target.position.x + 3, 0.03)
    hit_tween.tween_property(target, "position:x", target.position.x - 2, 0.03)
    hit_tween.tween_property(target, "position:x", target.position.x, 0.03)
    hit_tween.tween_property(target, "modulate", Color.WHITE, 0.15)
    
    # 伤害数字飘字（可选）
    _show_damage_number(target.global_position, damage)

func _show_damage_number(pos: Vector2, damage: int) -> void:
    var label := Label.new()
    label.text = "-%d" % damage
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
    label.position = pos
    label.z_index = 100
    add_child(label)
    
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "position:y", pos.y - 40, 0.6)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
    tween.finished.connect(func(): label.queue_free())
```

---

## 第三部分：弹窗统一改造

所有弹窗统一使用以下结构：

```gdscript
## 通用弹窗样式
func _apply_popup_style(panel: PanelContainer, title: String) -> void:
    # 弹窗主面板
    var main_style := StyleBoxFlat.new()
    main_style.bg_color = COLOR_BG_SOLID
    main_style.border_color = COLOR_BORDER
    main_style.border_width_left = 2
    main_style.border_width_top = 2
    main_style.border_width_right = 2
    main_style.border_width_bottom = 2
    main_style.corner_radius_top_left = 16
    main_style.corner_radius_top_right = 16
    main_style.corner_radius_bottom_left = 16
    main_style.corner_radius_bottom_right = 16
    main_style.shadow_color = Color(0, 0, 0, 0.2)
    main_style.shadow_size = 20
    main_style.shadow_offset = Vector2(0, 10)
    panel.add_theme_stylebox_override("panel", main_style)
    
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(560, 400)
    
    # 标题栏
    var title_bar := PanelContainer.new()
    title_bar.custom_minimum_size = Vector2(0, 48)
    var title_style := StyleBoxFlat.new()
    title_style.bg_color = COLOR_BG_SELECTED
    title_style.corner_radius_top_left = 14
    title_style.corner_radius_top_right = 14
    title_style.corner_radius_bottom_left = 0
    title_style.corner_radius_bottom_right = 0
    title_bar.add_theme_stylebox_override("panel", title_style)
    
    var title_label := Label.new()
    title_label.text = title
    title_label.add_theme_font_size_override("font_size", 18)
    title_label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_bar.add_child(title_label)

## 通用弹窗入场动画
func _popup_entrance_animation(panel: PanelContainer, dim_overlay: ColorRect) -> void:
    # 遮罩淡入
    dim_overlay.color = Color(0, 0, 0, 0)
    dim_overlay.visible = true
    var dim_tween := create_tween()
    dim_tween.tween_property(dim_overlay, "color:a", 0.5, 0.25)
    
    # 面板缩放入场
    panel.scale = Vector2(0.9, 0.9)
    panel.modulate.a = 0.0
    panel.visible = true
    
    var panel_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.3)
    panel_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.25)

## 通用弹窗退出动画
func _popup_exit_animation(panel: PanelContainer, dim_overlay: ColorRect) -> void:
    var panel_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    panel_tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.2)
    panel_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.2)
    
    var dim_tween := create_tween()
    dim_tween.tween_property(dim_overlay, "color:a", 0.0, 0.25)
    
    await panel_tween.finished
    panel.visible = false
    dim_overlay.visible = false
```

---

### 3.1 商店弹窗

```gdscript
## 商店弹窗继承通用样式
func _setup_shop_popup() -> void:
    var popup: PanelContainer = $PopupLayer/ShopPopup
    _apply_popup_style(popup, "商店")
    
    # 商品列表
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(520, 280)
    popup.add_child(scroll)
    
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 12)
    scroll.add_child(grid)
    
    # 商品卡片（复用 _create_pool_card 样式但更小）
    for item in _shop_items:
        var card := _create_shop_item_card(item)
        grid.add_child(card)

func _create_shop_item_card(item: Dictionary) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(160, 200)
    
    var style := StyleBoxFlat.new()
    style.bg_color = COLOR_BG_SOLID
    style.border_color = COLOR_BORDER
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 3
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    style.shadow_color = Color(0, 0, 0, 0.06)
    style.shadow_size = 4
    card.add_theme_stylebox_override("panel", style)
    
    # ... 商品信息 ...
    
    # Hover：上浮 + 蓝色边框
    card.mouse_entered.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(card, "scale", Vector2(1.04, 1.04), 0.12)
        tween.parallel().tween_property(card, "position:y", card.position.y - 4, 0.12)
        
        var hover_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
        hover_style.border_color = COLOR_BORDER_HOVER
        hover_style.shadow_size = 8
        card.add_theme_stylebox_override("panel", hover_style)
    )
    card.mouse_exited.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(card, "scale", Vector2.ONE, 0.15)
        tween.parallel().tween_property(card, "position:y", card.position.y + 4, 0.15)
        
        var base_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
        base_style.border_color = COLOR_BORDER
        base_style.shadow_size = 4
        card.add_theme_stylebox_override("panel", base_style)
    )
    
    return card
```

---

### 3.2 训练/营救/外出事件弹窗

所有弹窗统一使用 `_apply_popup_style()` + `_popup_entrance_animation()` + `_popup_exit_animation()`。

只需在各自弹窗的 `_ready()` 中调用：

```gdscript
# shop_popup.gd / training_popup.gd / rescue_popup.gd / outing_popup.gd
func _ready() -> void:
    _apply_popup_style(self, _get_popup_title())
    visible = false

func show_popup() -> void:
    _popup_entrance_animation(self, _dim_overlay)
    _build_content()

func hide_popup() -> void:
    _popup_exit_animation(self, _dim_overlay)
```

---

### 3.3 暂停菜单

```gdscript
func _setup_pause_menu() -> void:
    var menu: PanelContainer = $PopupLayer/PauseMenu
    _apply_popup_style(menu, "暂停")
    menu.custom_minimum_size = Vector2(360, 320)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 16)
    menu.add_child(vbox)
    
    # 继续游戏按钮
    var resume_btn := Button.new()
    resume_btn.text = "继续游戏"
    resume_btn.custom_minimum_size = Vector2(200, 48)
    _apply_primary_button_style(resume_btn)
    resume_btn.pressed.connect(_on_resume)
    vbox.add_child(resume_btn)
    
    # 保存并退出按钮
    var save_quit_btn := Button.new()
    save_quit_btn.text = "保存并退出"
    save_quit_btn.custom_minimum_size = Vector2(200, 48)
    _apply_secondary_button_style(save_quit_btn)
    save_quit_btn.pressed.connect(_on_save_and_quit)
    vbox.add_child(save_quit_btn)
    
    # 设置按钮
    var settings_btn := Button.new()
    settings_btn.text = "设置"
    settings_btn.custom_minimum_size = Vector2(200, 48)
    _apply_secondary_button_style(settings_btn)
    settings_btn.pressed.connect(_on_settings)
    vbox.add_child(settings_btn)

func _on_pause_pressed() -> void:
    get_tree().paused = true
    $PopupLayer/PauseMenu.show_popup()

func _on_resume() -> void:
    $PopupLayer/PauseMenu.hide_popup()
    get_tree().paused = false
```

---

## 第四部分：通用按钮样式

```gdscript
## 主行动按钮（蓝色底 + 白字）
func _apply_primary_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.25, 0.55, 0.95, 1)
    normal.border_color = Color(0.2, 0.45, 0.85, 1)
    normal.border_width_left = 2
    normal.border_width_top = 2
    normal.border_width_right = 2
    normal.border_width_bottom = 3
    normal.corner_radius_top_left = 8
    normal.corner_radius_top_right = 8
    normal.corner_radius_bottom_left = 8
    normal.corner_radius_bottom_right = 8
    normal.shadow_color = Color(0.25, 0.55, 0.95, 0.2)
    normal.shadow_size = 6
    normal.shadow_offset = Vector2(0, 2)
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
    
    var pressed := StyleBoxFlat.new()
    pressed.bg_color = Color(0.2, 0.45, 0.85, 1)
    pressed.corner_radius_top_left = 8
    pressed.corner_radius_top_right = 8
    pressed.corner_radius_bottom_left = 8
    pressed.corner_radius_bottom_right = 8
    pressed.shadow_size = 3
    button.add_theme_stylebox_override("pressed", pressed)
    
    # 点击弹跳
    button.pressed.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
        tween.tween_property(button, "scale", Vector2.ONE, 0.15)
    )

## 次要按钮（白底 + 灰边 + 灰字）
func _apply_secondary_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = COLOR_BG_SOLID
    normal.border_color = COLOR_BORDER
    normal.border_width_left = 2
    normal.border_width_top = 2
    normal.border_width_right = 2
    normal.border_width_bottom = 2
    normal.corner_radius_top_left = 8
    normal.corner_radius_top_right = 8
    normal.corner_radius_bottom_left = 8
    normal.corner_radius_bottom_right = 8
    normal.shadow_color = Color(0, 0, 0, 0.06)
    normal.shadow_size = 4
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_color_override("font_color", COLOR_TEXT_SECOND)
    
    var hover := StyleBoxFlat.new()
    hover.bg_color = COLOR_BG_SELECTED
    hover.border_color = COLOR_BORDER_HOVER
    hover.corner_radius_top_left = 8
    hover.corner_radius_top_right = 8
    hover.corner_radius_bottom_left = 8
    hover.corner_radius_bottom_right = 8
    hover.shadow_size = 6
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_color_override("font_hover_color", COLOR_BORDER_HOVER)
```

---

## 测试验收标准

### 爬塔主场景HUD
- [ ] 顶部信息栏：白底 + 底部2px灰边 + 12px下圆角 + 8px阴影
- [ ] 金币显示：亮金文字，变化时scale弹跳1.2x
- [ ] 回合/层数显示：前缀小字灰色 + 数值大字黑色
- [ ] 难度指示：居中显示"新手模式"/"老手模式"灰色
- [ ] 暂停/设置按钮：方形40x40，灰底+灰字，hover变蓝+阴影
- [ ] 底部伙伴CHAIN条：3张卡片横排，间隔12px
- [ ] CHAIN卡片：白底+灰边+底部3px加粗+8px圆角+4px阴影
- [ ] CHAIN卡片头像：56x56正方形，圆角6px
- [ ] CHAIN卡片hover：scale1.05+上浮4px+蓝色边框+阴影8px
- [ ] CHAIN卡片入场：依次弹跳（间隔0.08s）

### 战斗面板
- [ ] 布局：左方（主角+2伙伴） | 中央（VS+日志） | 右方（敌方）
- [ ] 战斗卡片：200x260，12px圆角，8px阴影
- [ ] 我方白底灰边，敌方微红底红边
- [ ] 头像140x140正方形，8px圆角
- [ ] 入场动画：左方从左滑入（间隔0.1s），右方从右滑入（延迟0.2s）
- [ ] 攻击动画：攻击者前移20px→弹回，目标闪红+左右抖动3px
- [ ] 伤害数字飘字：红色"-X"，向上飘40px+淡出0.6s
- [ ] 回合指示器：顶部显示"回合 X"
- [ ] 跳过按钮：暂停按钮样式

### 弹窗统一
- [ ] 所有弹窗：白底+灰边+16px圆角+20px阴影+顶部标题栏
- [ ] 标题栏：微蓝白底+14px上圆角+标题居中
- [ ] 入场动画：遮罩淡入0.5透明度+面板scale0.9→1.0弹跳
- [ ] 退出动画：面板缩小淡出+遮罩淡出
- [ ] 商店商品卡片：hover上浮4px+scale1.04+蓝色边框
- [ ] 暂停菜单：3个按钮（继续/保存退出/设置），主行动按钮蓝色

### 通用
- [ ] 主行动按钮（蓝色）：hover更亮蓝+阴影扩散，点击scale0.95→弹回
- [ ] 次要按钮（白底）：hover蓝边框+字体变蓝
- [ ] 1280x720 和 1920x1080 无重叠
- [ ] Tween资源正确清理，无内存泄漏
