# 任务卡：战斗动画面板（格斗游戏风格）

> 核心原则：BattleEngine 零修改。新增 BattlePlaybackRecorder 缓存信号，BattleAnimationPanel 逐帧播放。
> 播放逻辑：每回合约2秒（含所有攻击/miss/援助/连锁），伙伴动画时长预留接口，可随时"跳过"。

---

## 布局结构（格斗游戏风格）

```
┌──────────────────────────────────────────────────────┐
│  [英雄名]                 回合 X/20        [敌人名]   │
│  ████████████░░ HP 80%   ───VS───   ░░████████ HP 60% │  ← 顶部：血条横排
│  [剑士○][弓手○][法师○]              [骷髅○]          │  ← 血条下方：伙伴小圆头像
├──────────────────────────────────────────────────────┤
│                                                      │
│                    ✨ 攻击特效区 ✨                    │  ← 中上部：特效占位区
│                                                      │
│        ┌──────────┐          ┌──────────┐          │
│        │          │          │          │          │
│        │   英雄   │  →→💥→→  │   敌人   │          │  ← 中下部：角色左右站位
│        │  占位图   │          │  占位图   │          │    攻击时向中间突进
│        │          │          │          │          │
│        └──────────┘          └──────────┘          │
│                                                      │
│           25↗                  ↗－15                 │  ← 伤害数字飘字（暴击红色放大）
│                                                      │
├──────────────────────────────────────────────────────┤
│  CHAIN x3! 伙伴弓手造成25伤害！                        │  ← 底部：连击/援助大字提示
│                                      [跳过]          │
└──────────────────────────────────────────────────────┘
```

### 布局要点
1. **顶部**：双方血条横向并排，中间夹回合数/VS标识
2. **血条下方**：伙伴小圆头像（英雄侧显示自己的伙伴，敌人侧显示敌人伙伴）
3. **中上部**：大面积空旷，留给攻击突进动效+伤害飘字+特效占位
4. **中下部**：角色左右站位（像拳皇/街霸），攻击时向中间突进，结束后退回原位
5. **底部**：连击/援助的大字提示（RichTextLabel），无逐行战斗日志
6. **右下角**："跳过"按钮（任何时候可点击，直接跳到结果面板）

---

## 修复步骤

### Step 1：新建 BattlePlaybackRecorder

**文件：`scripts/systems/battle_playback_recorder.gd`**

```gdscript
class_name BattlePlaybackRecorder
extends Node

var _events: Array[Dictionary] = []
var _is_recording: bool = false

func start_recording() -> void:
    _events.clear()
    _is_recording = true

func stop_recording() -> void:
    _is_recording = false
    print("[PlaybackRecorder] 记录完成: %d个事件" % _events.size())

func record_event(event_type: String, data: Dictionary) -> void:
    if not _is_recording:
        return
    _events.append({"type": event_type, "data": data})

func get_events() -> Array[Dictionary]:
    return _events.duplicate()

# 将事件按回合分组，方便逐回合播放
func get_events_by_turn() -> Dictionary:
    var result: Dictionary = {}
    for evt in _events:
        var turn: int = evt["data"].get("turn", 0)
        if not result.has(turn):
            result[turn] = []
        result[turn].append(evt)
    return result
```

### Step 2：RunController 中创建 Recorder 并订阅信号

**文件：`scripts/systems/run_controller.gd`**

在 `_run_battle_engine` 中，战斗开始前创建 Recorder，订阅 BattleEngine 发射的所有信号：

```gdscript
func _run_battle_engine(enemy_config_id: int) -> Dictionary:
    var battle_engine: BattleEngine = BattleEngine.new()
    add_child(battle_engine)
    
    # --- 创建回放记录器 ---
    var recorder := BattlePlaybackRecorder.new()
    recorder.name = "PlaybackRecorder"
    add_child(recorder)
    recorder.start_recording()
    
    # 订阅所有战斗信号
    var _on_turn_started = func(turn, order, mode):
        recorder.record_event("turn_started", {"turn": turn, "order": order})
    EventBus.battle_turn_started.connect(_on_turn_started)
    
    var _on_action_executed = func(action_data):
        recorder.record_event("action_executed", action_data)
    EventBus.action_executed.connect(_on_action_executed)
    
    var _on_unit_damaged = func(unit_id, damage, hp, max_hp, dmg_type, is_crit, is_miss, attacker_id):
        recorder.record_event("unit_damaged", {
            "unit_id": unit_id, "damage": damage, "hp": hp, "max_hp": max_hp,
            "is_crit": is_crit, "is_miss": is_miss, "attacker_id": attacker_id,
        })
    EventBus.unit_damaged.connect(_on_unit_damaged)
    
    var _on_unit_died = func(unit_id, name, unit_type, killer_id):
        recorder.record_event("unit_died", {"unit_id": unit_id, "name": name})
    EventBus.unit_died.connect(_on_unit_died)
    
    var _on_partner_assist = func(pid, pname, trigger_type, assist_data, chain_count):
        recorder.record_event("partner_assist", {"partner_name": pname, "chain_count": chain_count})
    EventBus.partner_assist_triggered.connect(_on_partner_assist)
    
    var _on_chain_triggered = func(chain_count, partner_id, partner_name, damage, multiplier, total_chains):
        recorder.record_event("chain_triggered", {
            "chain_count": chain_count, "partner_name": partner_name, "damage": damage,
        })
    EventBus.chain_triggered.connect(_on_chain_triggered)
    
    var _on_ultimate_triggered = func(hero_id, hero_name, turn, skill_id, log_text):
        recorder.record_event("ultimate_triggered", {"hero_name": hero_name, "log": log_text})
    EventBus.ultimate_triggered.connect(_on_ultimate_triggered)
    
    # 执行战斗
    var result = battle_engine.execute_battle(battle_config)
    
    # 断开信号
    EventBus.battle_turn_started.disconnect(_on_turn_started)
    EventBus.action_executed.disconnect(_on_action_executed)
    EventBus.unit_damaged.disconnect(_on_unit_damaged)
    EventBus.unit_died.disconnect(_on_unit_died)
    EventBus.partner_assist_triggered.disconnect(_on_partner_assist)
    EventBus.chain_triggered.disconnect(_on_chain_triggered)
    EventBus.ultimate_triggered.disconnect(_on_ultimate_triggered)
    
    recorder.stop_recording()
    result["playback_recorder"] = recorder
    
    battle_engine.queue_free()
    return result
```

### Step 3：新建 BattleAnimationPanel

**文件：`scenes/run_main/battle_animation_panel.tscn`**

按上述格斗游戏风格布局构建场景：

```
BattleAnimationPanel (Control)
├── TopBar (HBoxContainer)
│   ├── HeroPanel (VBoxContainer)
│   │   ├── HeroNameLabel (Label)
│   │   ├── HeroHPBar (ProgressBar)
│   │   └── HeroPartnersContainer (HBoxContainer)  # 伙伴小圆头像
│   ├── CenterInfo (VBoxContainer)
│   │   ├── TurnLabel (Label)           # "回合 3/20"
│   │   └── VsLabel (Label)             # "VS"
│   └── EnemyPanel (VBoxContainer)
│       ├── EnemyNameLabel (Label)
│       ├── EnemyHPBar (ProgressBar)
│       └── EnemyPartnersContainer (HBoxContainer)
├── EffectArea (Control)                 # 攻击特效占位区
├── BattleArea (HBoxContainer)
│   ├── HeroSprite (TextureRect/ColorRect)  # 英雄占位图
│   └── EnemySprite (TextureRect/ColorRect) # 敌人占位图
├── DamageContainer (Node)               # 伤害数字飘字容器
├── BottomHint (RichTextLabel)           # 连击/援助大字提示
└── SkipButton (Button)                  # "跳过"
```

**文件：`scenes/run_main/battle_animation_panel.gd`**

```gdscript
class_name BattleAnimationPanel
extends Control

@onready var turn_label: Label = $TopBar/CenterInfo/TurnLabel
@onready var hero_name_label: Label = $TopBar/HeroPanel/HeroNameLabel
@onready var hero_hp_bar: ProgressBar = $TopBar/HeroPanel/HeroHPBar
@onready var enemy_name_label: Label = $TopBar/EnemyPanel/EnemyNameLabel
@onready var enemy_hp_bar: ProgressBar = $TopBar/EnemyPanel/EnemyHPBar
@onready var bottom_hint: RichTextLabel = $BottomHint
@onready var skip_button: Button = $SkipButton
@onready var damage_container: Node = $DamageContainer
@onready var hero_sprite: Control = $BattleArea/HeroSprite
@onready var enemy_sprite: Control = $BattleArea/EnemySprite

var _recorder: BattlePlaybackRecorder = null
var _events_by_turn: Dictionary = {}
var _turn_keys: Array = []
var _current_turn_index: int = 0
var _is_playing: bool = false
var _hero_hp: int = 0
var _hero_max_hp: int = 0
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0
var _turn_duration: float = 2.0  # 每回合基础时长2秒

signal confirmed

func start_playback(recorder: BattlePlaybackRecorder, hero_name: String, enemy_name: String,
                    hero_max_hp: int, enemy_max_hp: int, hero_partners: Array, enemy_partners: Array) -> void:
    _recorder = recorder
    _events_by_turn = recorder.get_events_by_turn()
    _turn_keys = _events_by_turn.keys()
    _current_turn_index = 0
    _hero_max_hp = hero_max_hp
    _enemy_max_hp = enemy_max_hp
    _hero_hp = hero_max_hp
    _enemy_hp = enemy_max_hp
    _is_playing = true
    visible = true
    
    hero_name_label.text = hero_name
    enemy_name_label.text = enemy_name
    _update_hp_display()
    bottom_hint.text = ""
    
    skip_button.pressed.connect(_on_skip)
    
    print("[BattleAnimation] 开始回放: %d个回合" % _turn_keys.size())
    _play_turn()

func _play_turn() -> void:
    if not _is_playing or _current_turn_index >= _turn_keys.size():
        _show_result()
        return
    
    var turn: int = _turn_keys[_current_turn_index]
    var events: Array = _events_by_turn[turn]
    turn_label.text = "回合 %d" % turn
    
    # 计算本回合实际时长（基础2秒 + 伙伴动画预留）
    var partner_events: int = 0
    for evt in events:
        if evt["type"] in ["partner_assist", "chain_triggered"]:
            partner_events += 1
    var duration: float = _turn_duration + partner_events * 0.5  # 每个伙伴动画+0.5秒
    
    # 播放本回合所有事件
    for evt in events:
        _process_event(evt)
    
    await get_tree().create_timer(duration).timeout
    _current_turn_index += 1
    _play_turn()

func _process_event(evt: Dictionary) -> void:
    var type: String = evt["type"]
    var data: Dictionary = evt["data"]
    
    match type:
        "turn_started":
            # 高亮当前行动者
            var order: Array = data.get("order", [])
            if order.size() > 0:
                var actor: String = order[0].get("name", "???")
                bottom_hint.append_text("[color=yellow]%s 的行动[/color]\n" % actor)
        
        "action_executed":
            var actor: String = data.get("actor_name", "???")
            var target: String = data.get("target_name", "???")
            var summary: Dictionary = data.get("result_summary", {})
            var is_miss: bool = summary.get("is_miss", false)
            var is_crit: bool = summary.get("is_crit", false)
            var value: int = summary.get("value", 0)
            
            if is_miss:
                bottom_hint.append_text("[color=gray]%s → %s miss[/color]\n" % [actor, target])
            elif is_crit:
                bottom_hint.append_text("[color=red]%s → %s 暴击 %d！[/color]\n" % [actor, target, value])
            else:
                bottom_hint.append_text("%s → %s %d\n" % [actor, target, value])
        
        "unit_damaged":
            var unit_id: String = data.get("unit_id", "")
            var damage: int = data.get("damage", 0)
            var hp: int = data.get("hp", 0)
            var is_crit: bool = data.get("is_crit", false)
            
            if unit_id == "hero":
                _hero_hp = maxi(0, hp)
                _update_hp_display()
                _show_damage_number(damage, is_crit, false)  # 英雄受伤，数字在左侧飘
            else:
                _enemy_hp = maxi(0, hp)
                _update_hp_display()
                _show_damage_number(damage, is_crit, true)   # 敌人受伤，数字在右侧飘
            
            # 角色受击闪烁（占位动画）
            _flash_sprite(unit_id)
        
        "unit_died":
            var name: String = data.get("name", "???")
            bottom_hint.append_text("[color=red]%s 被击败！[/color]\n" % name)
        
        "partner_assist":
            var pname: String = data.get("partner_name", "???")
            bottom_hint.append_text("[color=cyan]%s 援助！[/color]\n" % pname)
            _flash_partner_icon(pname)
        
        "chain_triggered":
            var chain_count: int = data.get("chain_count", 0)
            var pname: String = data.get("partner_name", "???")
            var dmg: int = data.get("damage", 0)
            bottom_hint.append_text("[color=purple]CHAIN x%d! %s %d[/color]\n" % [chain_count, pname, dmg])
        
        "ultimate_triggered":
            var hero_name: String = data.get("hero_name", "???")
            var log: String = data.get("log", "")
            bottom_hint.append_text("[color=gold]%s[/color]\n" % log)
            _screen_shake()  # 屏幕震动占位

func _update_hp_display() -> void:
    hero_hp_bar.value = float(_hero_hp) / _hero_max_hp * 100
    enemy_hp_bar.value = float(_enemy_hp) / _enemy_max_hp * 100

func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool) -> void:
    var label := Label.new()
    label.text = str(damage)
    label.add_theme_font_size_override("font_size", 32 if is_crit else 24)
    label.modulate = Color(1, 0.2, 0.2) if is_crit else Color(1, 1, 1)
    
    # 位置：敌人侧在右侧飘，英雄侧在左侧飘
    var base_x: float = 450 if is_enemy_side else 150
    label.position = Vector2(base_x, 300)
    damage_container.add_child(label)
    
    var tween := create_tween()
    tween.tween_property(label, "position:y", label.position.y - 80, 0.6)
    tween.tween_property(label, "modulate:a", 0, 0.3)
    tween.tween_callback(label.queue_free)

func _flash_sprite(unit_id: String) -> void:
    var sprite: Control = enemy_sprite if unit_id == "enemy" else hero_sprite
    var tween := create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
    tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func _flash_partner_icon(partner_name: String) -> void:
    # 伙伴头像闪烁（根据名字找到对应图标节点）
    pass  # 占位，后续实现

func _screen_shake() -> void:
    # 屏幕震动占位
    var tween := create_tween()
    tween.tween_property(self, "position:x", position.x + 5, 0.05)
    tween.tween_property(self, "position:x", position.x - 5, 0.05)
    tween.tween_property(self, "position:x", position.x, 0.05)

func _on_skip() -> void:
    _is_playing = false
    _show_result()

func _show_result() -> void:
    _is_playing = false
    bottom_hint.append_text("\n[color=yellow]=== 战斗结束 ===[/color]")
    confirmed.emit()
```

### Step 4：RunMain 中替换 BattleSummaryPanel

**文件：`scenes/run_main/run_main.gd`**

```gdscript
@onready var battle_animation_panel: BattleAnimationPanel = $BattleAnimationPanel

func _on_battle_ended(battle_result: Dictionary) -> void:
    print("[RunMain] 战斗结束: winner=%s" % battle_result.get("winner", "???"))
    _update_hud()
    
    var recorder: BattlePlaybackRecorder = battle_result.get("playback_recorder", null)
    
    if recorder != null and recorder.get_events().size() > 0:
        # 提取双方信息
        var hero_data: Dictionary = battle_result.get("hero", {})
        var enemy_data: Dictionary = battle_result.get("enemies", [{}])[0]
        var hero_name: String = hero_data.get("name", "英雄")
        var enemy_name: String = enemy_data.get("name", "敌人")
        var hero_max_hp: int = hero_data.get("max_hp", 100)
        var enemy_max_hp: int = enemy_data.get("max_hp", 100)
        
        battle_animation_panel.start_playback(recorder, hero_name, enemy_name, hero_max_hp, enemy_max_hp, [], [])
        battle_animation_panel.confirmed.connect(_on_battle_animation_confirmed, CONNECT_ONE_SHOT)
    else:
        # 无回放数据，fallback到摘要
        battle_summary_panel.show_result(battle_result)
        battle_summary_panel.confirmed.connect(_on_battle_summary_confirmed, CONNECT_ONE_SHOT)

func _on_battle_animation_confirmed() -> void:
    battle_animation_panel.visible = false
    _transition_ui_state(UISceneState.OPTION_SELECT)
```

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scripts/systems/battle_playback_recorder.gd` | 新建 | 战斗事件缓存模块 |
| 2 | `scripts/systems/run_controller.gd` | 修改 | `_run_battle_engine` 创建Recorder，订阅信号 |
| 3 | `scenes/run_main/battle_animation_panel.tscn` | 新建 | 格斗游戏风格战斗动画面板场景 |
| 4 | `scenes/run_main/battle_animation_panel.gd` | 新建 | 逐回合播放逻辑 |
| 5 | `scenes/run_main/run_main.tscn` | 修改 | 添加 BattleAnimationPanel 实例 |
| 6 | `scenes/run_main/run_main.gd` | 修改 | 战斗结束后优先播放动画 |

---

## 验收标准

- [ ] 点击"战斗"后，弹出 BattleAnimationPanel（格斗游戏风格布局）
- [ ] 顶部显示双方血条横排、回合数、VS标识
- [ ] 血条下方显示伙伴小圆头像
- [ ] 角色在下半区左右站位，攻击时向中间突进（占位动画）
- [ ] 伤害数字从被击方飘出，暴击红色+放大
- [ ] 伙伴援助时，底部大字提示"[伙伴名] 援助！"，伙伴头像闪烁
- [ ] 连锁触发时，底部大字提示"CHAIN xN! [伙伴名] [伤害]"（紫色）
- [ ] 必杀技时，底部金色文字，屏幕震动（占位）
- [ ] 点击"跳过"直接结束动画显示结果
- [ ] BattleEngine.gd **没有任何修改**
- [ ] 伙伴动画时长预留接口（当前每个伙伴+0.5秒，后续可配置）
