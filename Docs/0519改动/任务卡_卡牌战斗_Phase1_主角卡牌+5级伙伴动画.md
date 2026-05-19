# 任务卡：卡牌式战斗系统重构 — Phase 1（主角/敌方卡牌 + 5级伙伴保留逐帧动画）

## 方案确认

| 角色 | 表现形式 | 动画方式 |
|------|---------|---------|
| 主角（英雄） | 卡牌头像（正方形 TextureRect） | Tween + Shader + 粒子 |
| 敌方（含Boss） | 卡牌头像（正方形 TextureRect） | Tween + Shader + 粒子 |
| 1-4级伙伴 | 左侧 CHAIN 列表（头像+文字） | 头像闪烁/飞出/飘字 |
| **5级伙伴** | **动态创建 AnimatedSprite2D** | **完整逐帧攻击/技能动画，播完删除** |

---

## 修改范围

### 文件 1：`scenes/run_main/battle_animation_panel.tscn`

**删除节点**：
```
StageArea/HeroArt (AnimatedSprite2D)     ← 删除
StageArea/EnemyArt (AnimatedSprite2D)    ← 删除
```

**新增节点**：
```
StageArea
├── HeroCard (PanelContainer 或 Control)
│   ├── CardBorder (ColorRect / TextureRect)
│   ├── Portrait (TextureRect)                    ← 200x200 正方形
│   │   └── PortraitOverlay (ColorRect)           ← ShaderMaterial: portrait_overlay
│   ├── GlowOverlay (ColorRect)                   ← ShaderMaterial: glow_pulse
│   ├── NameLabel (Label)
│   └── HpBar (ProgressBar)                       ← 可选：放卡牌内或保留原位置
├── CenterBadge (Control)                          ← VS + 回合数（保留）
├── EnemyCard (PanelContainer 或 Control)
│   └── (同 HeroCard 结构)
└── PartnerAnimContainer (Node2D)                   ← 5级伙伴动态挂载点
    ## 空节点，runtime 动态 add_child AnimatedSprite2D

PartnerChainLayer (CanvasLayer, layer=4)            ← 左侧 CHAIN 列表（新增）
└── PartnerChainList (VBoxContainer)
    ├── ChainSlot_0 ~ ChainSlot_3 (HBoxContainer)

VFXLayer (CanvasLayer, layer=5)                   ← 如已有则保留/扩展
```

---

### 文件 2：`scenes/run_main/battle_animation_panel.gd`

#### 2.1 @onready 引用更新

```gdscript
## 删除以下引用：
# @onready var hero_art: AnimatedSprite2D = $StageArea/HeroArt
# @onready var enemy_art: AnimatedSprite2D = $StageArea/EnemyArt

## 新增引用（按实际 .tscn 路径）：
@onready var hero_card: Control = $StageArea/HeroCard
@onready var hero_portrait: TextureRect = $StageArea/HeroCard/Portrait
@onready var hero_portrait_overlay: ColorRect = $StageArea/HeroCard/Portrait/PortraitOverlay
@onready var hero_glow: ColorRect = $StageArea/HeroCard/GlowOverlay

@onready var enemy_card: Control = $StageArea/EnemyCard
@onready var enemy_portrait: TextureRect = $StageArea/EnemyCard/Portrait
@onready var enemy_portrait_overlay: ColorRect = $StageArea/EnemyCard/Portrait/PortraitOverlay
@onready var enemy_glow: ColorRect = $StageArea/EnemyCard/GlowOverlay

@onready var partner_anim_container: Node2D = $StageArea/PartnerAnimContainer
@onready var partner_chain_list: VBoxContainer = $PartnerChainLayer/PartnerChainList
```

保留 `hero_name_label`、`enemy_name_label`、`hero_hp_bar`、`enemy_hp_bar` 等现有引用，路径按需调整。

#### 2.2 删除函数（主角/敌方不再用 AnimatedSprite2D）

```gdscript
## 以下函数整段删除：

func _load_sprite(animated_sprite: AnimatedSprite2D, path: String) -> void:
    ## 删除（第394~418行）

func _set_placeholder_sprite(animated_sprite: AnimatedSprite2D, is_hero: bool) -> void:
    ## 删除（第420~434行）

func _play_anim(animated_sprite: AnimatedSprite2D, action: String) -> void:
    ## 删除（第436~467行）
    ## 注意：此函数内 "attack_1/attack_2/attack_3" 多段攻击轮询逻辑不再使用
```

#### 2.3 新增函数：主角/敌方卡牌头像加载

```gdscript
## 替换 _load_sprite
func _load_card_portrait(portrait: TextureRect, path: String, is_hero: bool) -> void:
    if path.is_empty():
        ## 占位：纯色渐变
        var gradient := GradientTexture2D.new()
        gradient.gradient = Gradient.new()
        if is_hero:
            gradient.gradient.colors = [Color("#4ECDC4"), Color("#2B6B5E")]
        else:
            gradient.gradient.colors = [Color("#FF6B6B"), Color("#8B2E2E")]
        gradient.width = 200
        gradient.height = 200
        portrait.texture = gradient
        return
    
    var texture: Texture2D = load(path)
    if texture == null:
        push_warning("[BattleAnimation] 无法加载头像: %s" % path)
        _load_card_portrait(portrait, "", is_hero)
        return
    
    portrait.texture = texture
```

#### 2.4 修改 `start_playback()`：初始化卡牌

当前代码（第170~173行）：
```gdscript
hero_art.visible = true
enemy_art.visible = true
_load_sprite(hero_art, hero_sprite_path)
_load_sprite(enemy_art, enemy_sprite_path)
```

改为：
```gdscript
hero_card.visible = true
enemy_card.visible = true
_load_card_portrait(hero_portrait, hero_sprite_path, true)
_load_card_portrait(enemy_portrait, enemy_sprite_path, false)

## 重置 overlay
hero_portrait_overlay.color = Color(1, 1, 1, 0)
hero_portrait_overlay.material.set_shader_parameter("flash", 0.0)
hero_portrait_overlay.material.set_shader_parameter("saturation", 1.0)
hero_glow.color = Color(1, 1, 1, 0)
## 敌方同理...

## 重置卡牌 Tween 状态（在 _ready 中缓存原始位置）
hero_card.position = _hero_card_orig_pos
hero_card.rotation = 0.0
hero_card.scale = Vector2.ONE
enemy_card.position = _enemy_card_orig_pos
enemy_card.rotation = 0.0
enemy_card.scale = Vector2.ONE

## 清理上次残留的5级伙伴动画节点
for child in partner_anim_container.get_children():
    child.queue_free()
```

在 `_ready()` 中缓存原始位置：
```gdscript
var _hero_card_orig_pos: Vector2 = Vector2.ZERO
var _enemy_card_orig_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
    ## ... 现有代码 ...
    _hero_card_orig_pos = hero_card.position
    _enemy_card_orig_pos = enemy_card.position
```

#### 2.5 新增：主角/敌方卡牌攻击 Tween

```gdscript
func _play_card_attack(is_hero: bool, action_type: String) -> void:
    var card: Control = hero_card if is_hero else enemy_card
    var orig_pos: Vector2 = _hero_card_orig_pos if is_hero else _enemy_card_orig_pos
    var dir: float = 1.0 if is_hero else -1.0  ## 己方向右，敌方向左
    
    match action_type:
        "ultimate":
            var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            tween.tween_property(card, "scale", Vector2(1.15, 1.15), 0.2)
            tween.tween_property(card, "scale", Vector2.ONE, 0.3)
            tween.parallel().tween_property(card, "position:x", orig_pos.x + dir * 30, 0.15)
            tween.tween_property(card, "position:x", orig_pos.x, 0.2)
        "skill":
            _card_glow_pulse(card, Color("#E6C040"), 0.3)
            var tween := create_tween()
            tween.tween_property(card, "position:x", orig_pos.x + dir * 15, 0.1)
            tween.tween_property(card, "position:x", orig_pos.x, 0.15)
        _:
            var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tween.tween_property(card, "position:x", orig_pos.x + dir * 20, 0.08)
            tween.tween_property(card, "position:x", orig_pos.x, 0.12)
    
    _spawn_slash_trail(card.global_position, 
                       (enemy_card if is_hero else hero_card).global_position, 
                       is_hero)

func _card_glow_pulse(card: Control, glow_color: Color, duration: float) -> void:
    var glow: ColorRect = card.get_node("GlowOverlay") if card.has_node("GlowOverlay") else null
    if glow == null:
        return
    glow.color = glow_color
    var tween := create_tween()
    tween.tween_property(glow, "color:a", 0.6, duration * 0.3)
    tween.tween_property(glow, "color:a", 0.0, duration * 0.7)
```

#### 2.6 新增：主角/敌方卡牌受击 Tween

```gdscript
func _play_card_hurt(is_hero: bool, is_crit: bool) -> void:
    var card: Control = hero_card if is_hero else enemy_card
    var orig_pos: Vector2 = _hero_card_orig_pos if is_hero else _enemy_card_orig_pos
    var shake: float = 8.0 if is_crit else 4.0
    var back_dir: float = -1.0 if is_hero else 1.0
    
    var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(card, "position:x", orig_pos.x + back_dir * shake, 0.06)
    tween.parallel().tween_property(card, "rotation", back_dir * 0.05, 0.06)  ## ~3°
    tween.tween_property(card, "position:x", orig_pos.x, 0.1)
    tween.parallel().tween_property(card, "rotation", 0.0, 0.1)
```

#### 2.7 新增：主角/敌方卡牌死亡 Tween

```gdscript
func _play_card_death(is_hero: bool) -> void:
    var card: Control = hero_card if is_hero else enemy_card
    var overlay: ColorRect = hero_portrait_overlay if is_hero else enemy_portrait_overlay
    
    ## 灰度化：Shader saturation 1.0 → 0.0
    var gray_tween := create_tween()
    gray_tween.tween_method(func(t: float):
        overlay.material.set_shader_parameter("saturation", 1.0 - t)
    , 0.0, 1.0, 0.5)
    
    ## 卡牌渐隐
    var fade_tween := create_tween()
    fade_tween.tween_property(card, "modulate:a", 0.0, 1.0).set_delay(0.3)
    fade_tween.tween_callback(func():
        card.visible = false
        card.modulate.a = 1.0
        overlay.material.set_shader_parameter("saturation", 1.0)
    )
```

#### 2.8 修改 `reset_panel()`：重置卡牌 + 清理5级伙伴节点

```gdscript
func reset_panel() -> void:
    ## ... 现有代码 ...
    _stop_frenzy_glow()
    
    ## 重置主角/敌方卡牌
    hero_card.visible = true
    hero_card.modulate.a = 1.0
    hero_card.position = _hero_card_orig_pos
    hero_card.rotation = 0.0
    hero_card.scale = Vector2.ONE
    hero_portrait_overlay.color = Color(1, 1, 1, 0)
    hero_portrait_overlay.material.set_shader_parameter("saturation", 1.0)
    hero_glow.color = Color(1, 1, 1, 0)
    ## 敌方同理...
    
    ## 清理5级伙伴动画节点
    for child in partner_anim_container.get_children():
        child.queue_free()
    
    ## 删除旧代码：
    # _play_anim(hero_art, "idle")
    # _play_anim(enemy_art, "idle")
```

#### 2.9 修改 `_process_event()` 中 `action_executed`

当前：
```gdscript
if actor == hero_name_label.text:
    _play_anim(hero_art, anim_action)
elif actor == enemy_name_label.text:
    _play_anim(enemy_art, anim_action)
```

改为：
```gdscript
if actor == hero_name_label.text:
    _play_card_attack(true, anim_action)
elif actor == enemy_name_label.text:
    _play_card_attack(false, anim_action)
```

#### 2.10 修改 `unit_damaged` 中的受击和死亡

当前（己方受击）：
```gdscript
_play_anim(hero_art, "hurt")
```

改为：
```gdscript
_play_card_hurt(true, is_crit)
```

当前（敌方受击）：
```gdscript
_play_anim(enemy_art, "hurt")
```

改为：
```gdscript
_play_card_hurt(false, is_crit)
```

当前（己方死亡）：
```gdscript
_play_anim(hero_art, "dead")
_death_flash(true)
```

改为：
```gdscript
_play_card_death(true)
```

当前（敌方死亡）：
```gdscript
_play_anim(enemy_art, "dead")
_death_flash(false)
```

改为：
```gdscript
_play_card_death(false)
```

#### 2.11 修改 `unit_died`

当前：
```gdscript
if uname == hero_name_label.text:
    _play_anim(hero_art, "dead")
elif uname == enemy_name_label.text:
    _play_anim(enemy_art, "dead")
```

改为：
```gdscript
if uname == hero_name_label.text:
    _play_card_death(true)
elif uname == enemy_name_label.text:
    _play_card_death(false)
```

#### 2.12 修改 `partner_assist`：1-4级伙伴头像闪烁/飞出

```gdscript
"partner_assist":
    var pname: String = data.get("partner_name", "???")
    battle_log.append_text("[color=#BF4DE6]  %s 援助攻击！[/color]\n" % pname)
    AudioManager.play_sfx("partner_assist")
    
    ## 查找 CHAIN 列表中对应 slot
    var slot: Control = _find_chain_slot_by_name(pname)
    if slot != null:
        _flash_chain_slot(slot)
        ## 头像飞出攻击（1-4级通用）
        _fly_partner_avatar(slot, false)  ## false = 不是5级，用轻量飞出
```

#### 2.13 新增：5级伙伴动态逐帧动画（核心新增）

```gdscript
## 在 chain_triggered 或 partner_assist 中判断伙伴等级
## 假设 recorder 事件中带 partner_level 字段，或从 data 中解析

func _play_partner_action(partner_name: String, partner_level: int, action: String, 
                          partner_sprite_path: String, partner_anim_name: String) -> void:
    if partner_level < 5:
        ## 1-4级：轻量头像飞出
        var slot: Control = _find_chain_slot_by_name(partner_name)
        if slot != null:
            _fly_partner_avatar(slot, false)
        return
    
    ## 5级：动态创建 AnimatedSprite2D，完整逐帧动画
    var sprite := AnimatedSprite2D.new()
    sprite.name = "PartnerAnim_%s" % partner_name
    
    var frames: Resource = load(partner_sprite_path)
    if frames == null or not frames is SpriteFrames:
        push_warning("[BattleAnimation] 无法加载5级伙伴动画: %s" % partner_sprite_path)
        sprite.queue_free()
        return
    
    sprite.sprite_frames = frames
    sprite.autoplay = partner_anim_name  ## "attack" / "skill" / "ultimate"
    
    ## 位置：主角左侧或独立位置（按动作类型调整）
    sprite.position = _get_partner_spawn_position(action)
    sprite.scale = Vector2(2.0, 2.0)  ## 按需调整
    
    partner_anim_container.add_child(sprite)
    sprite.play(partner_anim_name)
    
    ## Tween 飞入/飞出（可选）
    var enter_tween := create_tween()
    var spawn_pos: Vector2 = _get_partner_spawn_position(action)
    var attack_pos: Vector2 = enemy_card.global_position + Vector2(-160, 0)  ## 敌方左侧
    
    sprite.position = spawn_pos
    sprite.modulate.a = 0.0
    
    enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
    enter_tween.tween_property(sprite, "position", attack_pos, 0.3)
    
    ## 等待动画播放完毕
    sprite.animation_finished.connect(func():
        var exit_tween := create_tween()
        exit_tween.tween_property(sprite, "position", spawn_pos, 0.2)
        exit_tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
        exit_tween.tween_callback(func():
            sprite.queue_free()
        )
    , CONNECT_ONE_SHOT)

func _get_partner_spawn_position(action: String) -> Vector2:
    ## 5级伙伴出场位置：主角卡牌左侧偏上
    return hero_card.global_position + Vector2(-200, -40)

## 1-4级伙伴头像飞出（轻量）
func _fly_partner_avatar(slot: Control, is_level5: bool) -> void:
    if is_level5:
        return  ## 5级走上面的完整动画
    
    var orig_avatar: TextureRect = slot.get_node("Avatar") if slot.has_node("Avatar") else null
    if orig_avatar == null or orig_avatar.texture == null:
        return
    
    var flying := TextureRect.new()
    flying.texture = orig_avatar.texture
    flying.custom_minimum_size = Vector2(48, 48)
    flying.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    add_child(flying)
    
    var start: Vector2 = slot.global_position
    var target: Vector2 = enemy_card.global_position + enemy_card.size / 2 - flying.size / 2
    flying.global_position = start
    
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(flying, "global_position", target, 0.3)
    tween.tween_callback(func():
        VFX.flash_white(enemy_portrait_overlay, 0.05)
        _play_card_hurt(false, false)
    )
    tween.tween_property(flying, "global_position", start, 0.25)
    tween.tween_property(flying, "modulate:a", 0.0, 0.15)
    tween.tween_callback(func(): flying.queue_free())
    
    ## slot 闪烁
    _flash_chain_slot(slot)

func _flash_chain_slot(slot: Control) -> void:
    var orig: Color = slot.modulate
    var tween := create_tween()
    tween.tween_property(slot, "modulate", Color(1.3, 1.3, 1.0), 0.15)
    tween.tween_property(slot, "modulate", orig, 0.3)
```

#### 2.14 修改 `chain_triggered`：区分伙伴等级

```gdscript
"chain_triggered":
    var chain_count: int = data.get("chain_count", 0)
    var pname: String = data.get("partner_name", "???")
    var dmg: int = data.get("damage", 0)
    var plevel: int = data.get("partner_level", 1)  ## 需要 recorder 提供
    var ppath: String = data.get("partner_sprite_path", "")  ## 5级才需要
    
    battle_log.append_text("[color=#BF4DE6]  CHAIN x%d! %s %d[/color]\n" % [chain_count, pname, dmg])
    AudioManager.play_sfx("chain")
    _show_damage_number(dmg, false, false, true, chain_count)
    
    ## 触发伙伴动作
    if plevel >= 5 and not ppath.is_empty():
        _play_partner_action(pname, plevel, "attack", ppath, "attack")
    else:
        var slot: Control = _find_chain_slot_by_name(pname)
        if slot != null:
            _flash_chain_slot(slot)
            _fly_partner_avatar(slot, false)
```

**注意**：如果 `BattlePlaybackRecorder` 当前事件中不带 `partner_level` 和 `partner_sprite_path`，需要：
- 方案 A：`BattleEngine` 在生成事件时补充这两个字段
- 方案 B：战斗面板根据 `partner_name` 查 `ConfigManager` 获取等级和 sprite_path

建议方案 B（解耦，不在 recorder 中加游戏逻辑数据）：
```gdscript
## 在 _play_partner_action 内部查 ConfigManager
var pconfig: Dictionary = ConfigManager.get_partner_config_by_name(partner_name)
var plevel: int = pconfig.get("level", 1)
var ppath: String = pconfig.get("sprite_frames_path", "")
```

#### 2.15 修改 `ultimate_triggered`：主角必杀

```gdscript
"ultimate_triggered":
    var log_text: String = data.get("log", "")
    battle_log.append_text("[color=#E6C040]  %s[/color]\n" % log_text)
    _screen_shake()
    AudioManager.play_sfx("ultimate")
    
    ## 主角卡牌必杀动作
    _play_card_attack(true, "ultimate")
    _spawn_skill_aura(Color("#E6C040"))
    _show_ultimate_text(log_text)
```

#### 2.16 修改 `frenzy_triggered`：双方边框红光

```gdscript
"frenzy_triggered":
    _is_frenzy_active = true
    var msg: String = data.get("message", "狂暴阶段触发！")
    battle_log.append_text("\n[color=red]★ %s ★[/color]\n" % msg)
    round_label.modulate = Color(1, 0.2, 0.2)
    _update_hp_display()
    AudioManager.play_sfx("frenzy_alert")
    
    _start_frenzy_glow()

func _start_frenzy_glow() -> void:
    var tween := create_tween().set_loops()
    tween.tween_property(hero_glow, "color", Color(1, 0.1, 0.1, 0.5), 0.4)
    tween.tween_property(hero_glow, "color", Color(1, 0.1, 0.1, 0.1), 0.4)
    tween.parallel().tween_property(enemy_glow, "color", Color(1, 0.1, 0.1, 0.5), 0.4)
    tween.parallel().tween_property(enemy_glow, "color", Color(1, 0.1, 0.1, 0.1), 0.4)
    set_meta("frenzy_tween", tween)

func _stop_frenzy_glow() -> void:
    if has_meta("frenzy_tween"):
        var t: Tween = get_meta("frenzy_tween")
        if t != null and t.is_valid():
            t.kill()
        remove_meta("frenzy_tween")
    hero_glow.color = Color(1, 1, 1, 0)
    enemy_glow.color = Color(1, 1, 1, 0)
```

#### 2.17 修改闪白函数（`_flash_sprite` → `_flash_overlay`）

当前 `_flash_sprite()` 操作的是 `hero_art/enemy_art`（AnimatedSprite2D），改为操作 Overlay：

```gdscript
## 删除旧 _flash_sprite()（第613~624行）
## 替换为：
func _flash_sprite(is_hero: bool, is_crit: bool) -> void:
    var overlay: ColorRect = hero_portrait_overlay if is_hero else enemy_portrait_overlay
    var flash_color: Color = COL_CRIT if is_crit else Color(1, 1, 1)
    
    overlay.color = flash_color
    var tween := create_tween()
    tween.tween_property(overlay, "color:a", 0.8, 0.05)
    tween.tween_property(overlay, "color:a", 0.0, 0.15)
```

**或者**如果 VFX.flash_white 已支持 ColorRect，直接保留调用但改节点：
```gdscript
VFX.flash_white(hero_portrait_overlay, 0.1)
```

#### 2.18 新增 `_spawn_slash_trail()` 刀光轨迹

```gdscript
func _spawn_slash_trail(from: Vector2, to: Vector2, is_hero: bool) -> void:
    var slash := Line2D.new()
    slash.name = "SlashTrail"
    slash.points = [from, to]
    slash.width = 4.0
    slash.default_color = Color("#E6C040") if is_hero else Color("#D93826")
    slash.antialiased = true
    add_child(slash)
    
    var tween := create_tween()
    tween.tween_property(slash, "modulate:a", 0.0, 0.2).set_delay(0.05)
    tween.tween_callback(func(): slash.queue_free())
```

#### 2.19 新增 `_spawn_skill_aura()` 技能光晕

```gdscript
func _spawn_skill_aura(aura_color: Color) -> void:
    var aura := ColorRect.new()
    aura.name = "SkillAura"
    aura.set_anchors_preset(Control.PRESET_FULL_RECT)
    aura.color = Color(0, 0, 0, 0)
    
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://shaders/radial_burst.gdshader")
    mat.set_shader_parameter("aura_color", aura_color)
    aura.material = mat
    
    add_child(aura)
    
    var tween := create_tween()
    tween.tween_method(func(t: float):
        mat.set_shader_parameter("progress", t)
    , 0.0, 1.0, 0.6)
    tween.tween_callback(func(): aura.queue_free())
```

#### 2.20 新增 `_show_ultimate_text()` 必杀大字

```gdscript
func _show_ultimate_text(text: String) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 48)
    label.modulate = Color("#E6C040")
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(label)
    
    var min_size: Vector2 = label.get_combined_minimum_size()
    label.position = Vector2(size.x / 2 - min_size.x / 2, size.y * 0.3)
    label.scale = Vector2(1.5, 1.5)
    
    var tween := create_tween()
    tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "position:y", label.position.y - 60, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "modulate:a", 0.0, 0.4)
    tween.tween_callback(func(): label.queue_free())
```

#### 2.21 PartnerChainList 初始化和更新

```gdscript
var _chain_slots: Array[Control] = []

func _ready() -> void:
    ## ... 现有代码 ...
    _init_chain_slots()

func _init_chain_slots() -> void:
    _chain_slots.clear()
    for child in partner_chain_list.get_children():
        if child is HBoxContainer:
            _chain_slots.append(child)
            child.visible = false

func _update_chain_slots(partners: Array) -> void:
    for i in range(_chain_slots.size()):
        var slot: Control = _chain_slots[i]
        if i < partners.size():
            var p = partners[i]
            var name_label: Label = slot.get_node("NameLabel")
            var chain_label: Label = slot.get_node("ChainLabel")
            var avatar: TextureRect = slot.get_node("Avatar")
            
            name_label.text = p.get("name", "???")
            chain_label.text = "x chain %d" % p.get("chain_count", 0)
            
            var path: String = p.get("avatar_path", "")
            if not path.is_empty():
                avatar.texture = load(path)
            slot.visible = true
        else:
            slot.visible = false
```

#### 2.22 `_show_damage_number()` 飘字位置修正

当前飘字位置基于 `hero_art.global_position`（已删除的 AnimatedSprite2D），改为基于卡牌：

```gdscript
## 当前（第578行）：
## var target_sprite: Node2D = enemy_art if is_enemy_side else hero_art
## var sprite_pos: Vector2 = target_sprite.global_position

## 改为：
var target_card: Control = enemy_card if is_enemy_side else hero_card
var sprite_pos: Vector2 = target_card.global_position + target_card.size / 2
```

---

### 文件 3：`shaders/portrait_overlay.gdshader`（新建）

```glsl
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desaturated = mix(vec3(gray), tex.rgb, saturation);
    vec3 final_color = mix(desaturated, vec3(1.0), flash);
    COLOR = vec4(final_color, tex.a);
}
```

### 文件 4：`shaders/radial_burst.gdshader`（新建）

```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.90, 0.75, 0.35, 0.6);
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    float dist = distance(UV, center);
    float ring = smoothstep(progress - 0.1, progress, dist) 
               * smoothstep(progress + 0.2, progress, dist);
    float alpha = aura_color.a * ring * (1.0 - progress);
    COLOR = vec4(aura_color.rgb, alpha);
}
```

---

### 文件 5：`scenes/run_main/run_main.gd` — 连接伙伴数据

在 `_on_battle_ended()` 中调用 `start_playback()` 前，传入伙伴列表供 CHAIN 显示：

```gdscript
## _on_battle_ended() 中：
var partners: Array = _run_controller.get_partners()
var partner_summaries: Array = []
for p in partners:
    partner_summaries.append({
        "name": p.get("name", "???") if p is Dictionary else p.name,
        "avatar_path": _get_partner_avatar_path(p),
        "chain_count": p.get("chain_count", 0) if p is Dictionary else p.chain_count,
        "level": p.get("level", 1) if p is Dictionary else p.level,
    })
battle_animation_panel._update_chain_slots(partner_summaries)

## 然后再调用 start_playback
```

如果 `start_playback()` 签名需要扩展接收伙伴数据：
```gdscript
func start_playback(recorder, hero_name, enemy_name, hero_max_hp, enemy_max_hp,
                    _hero_partners: Array, _enemy_partners: Array,
                    total_rounds, hero_start_hp, enemy_start_hp,
                    hero_sprite_path, enemy_sprite_path,
                    partner_chain_data: Array = []) -> void:
    ## ...
    _update_chain_slots(partner_chain_data)
```

---

## 素材需求

| 素材 | 规格 | 数量 | 说明 |
|------|------|------|------|
| 主角 Q版头像 | 200x200 PNG，透明背景，正方形 | 每个英雄 1 张 | 放卡牌 Portrait 中 |
| 敌方 Q版头像 | 200x200 PNG，透明背景，正方形 | 每个敌人 1 张 | 同上 |
| 伙伴小头像（1-4级） | 48x48 PNG，透明背景 | 每个伙伴 1 张 | CHAIN 列表用 |
| **5级伙伴逐帧动画** | SpriteFrames (.tres)，含 attack/skill/idle | 每个 5级伙伴 1 套 | 完整 AnimatedSprite2D 资源 |
| 卡牌底框 | 无需图片，StyleBoxFlat+Shader 生成 | 0 | 动态按稀有度变色 |
| 特效纹理 | GradientTexture2D / ColorRect 程序生成 | 0 | 刀光、碎片等 |

---

## 删除代码清单

在 `battle_animation_panel.gd` 中删除：

1. `_load_sprite()`（原第394~418行）
2. `_set_placeholder_sprite()`（原第420~434行）
3. `_play_anim()`（原第436~467行）
4. `_death_flash()`（原第620~624行）
5. `start_playback()` 中的 `hero_art.visible` / `enemy_art.visible` / `_load_sprite()` 调用
6. `_process_event()` 中所有 `_play_anim()` 调用
7. `_flash_sprite()` 中操作 AnimatedSprite2D 的 modulate 逻辑（改为 Overlay）
8. `reset_panel()` 中的 `_play_anim(hero_art, "idle")` / `_play_anim(enemy_art, "idle")`
9. `_show_damage_number()` 中引用 `enemy_art` / `hero_art` 的位置（改为卡牌中心）

---

## 测试清单

### 基础卡牌显示
- [ ] 进入战斗，己方/敌方卡牌正确显示头像（或占位渐变）
- [ ] 头像为正方形 1:1，无拉伸变形
- [ ] 卡牌边框颜色按稀有度正确显示（S暗金/A蓝/B青/C灰）

### 主角/敌方战斗动作（Tween+特效）
- [ ] 普通攻击：己方卡牌向前突刺 20px，0.2s 回位，刀光飞向敌方
- [ ] 敌方受击：卡牌向后抖动 + 闪白 0.1s + 震屏
- [ ] 暴击：定格 + CRIT 大字 + 强震屏 + 卡牌边框爆闪
- [ ] 必杀（ultimate）：卡牌放大 1.15x + 脉冲 + 全屏暗金光晕扩散
- [ ] 技能（skill）：轻微突刺 + 边框暗金发光 0.3s
- [ ] 死亡：卡牌灰度化 0.5s + 透明度渐隐 1s
- [ ] 狂暴：双方卡牌边框红光 pulse（0.8s 周期）

### 1-4级伙伴（CHAIN 列表）
- [ ] 左侧列表正确显示伙伴名字 + chain 计数 + 小头像
- [ ] 触发援助时对应 slot 闪烁
- [ ] 头像飞出攻击敌方，命中后飞回消失
- [ ] CHAIN 触发时飘字从 slot 位置飘出

### 5级伙伴（逐帧动画）
- [ ] 5级伙伴触发时动态创建 AnimatedSprite2D
- [ ] 正确加载 SpriteFrames 资源，播放 attack/skill 动画
- [ ] 位置在主角左侧（或独立位置），不遮挡卡牌信息
- [ ] 动画播放完毕后节点自动删除（queue_free）
- [ ] 多次触发5级伙伴不残留节点（每次清理）

### 其他
- [ ] 战斗结束 reset 后，卡牌状态正确重置
- [ ] 跳过按钮有效，所有 Tween 和 Shader 参数正确重置
- [ ] 飘字（伤害数字）从受击卡牌中心上方飘出
- [ ] 1280x720 和 1920x1080 下卡牌位置正确
- [ ] **AnimatedSprite2D 不再在 StageArea 中作为固定节点存在**

---

## 执行顺序

1. 改 `.tscn` 节点结构：删 HeroArt/EnemyArt，加 HeroCard/EnemyCard/PartnerAnimContainer/PartnerChainList
2. 新建两个 Shader 文件
3. 改 `.gd` @onready 引用
4. 新增 `_load_card_portrait()`、缓存原始位置
5. 改 `start_playback()` 初始化卡牌
6. 新增 `_play_card_attack()`、`_play_card_hurt()`、`_play_card_death()`
7. 改 `_process_event()` 替换所有 `_play_anim()` 调用
8. 新增 `_spawn_slash_trail()`、`_spawn_skill_aura()`、`_show_ultimate_text()`
9. 改 `partner_assist` / `chain_triggered`：1-4级头像飞出，5级动态动画
10. 改 `ultimate_triggered` / `frenzy_triggered`
11. 改 `reset_panel()` 清理5级伙伴节点 + 重置卡牌
12. 改 `_show_damage_number()` 飘字位置
13. 新增 PartnerChainList 初始化
14. 改 `run_main.gd` 传入伙伴数据
15. 测试验证