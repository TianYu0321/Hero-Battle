# 任务卡：4个Bug修复 + UI调整 + 菜单添加

> 优先级：P0
> 代码已push到GitHub，基于最新版本

---

## Bug 1：第5层救援点击没反应

### 问题描述
第5层是特殊层（救援+商店），显示两个按钮[救援][商店]。点击后没有任何反应。

### 根因分析
1. `node_resolver.gd`的`_resolve_rescue()`只返回`requires_ui_selection=true`，但**没有生成候选伙伴列表**
2. `run_main.gd`没有处理rescue选项的UI显示逻辑（没有显示3选1面板）
3. `run_controller.gd`没有处理rescue后的伙伴入队逻辑

### 修复步骤

#### 文件1：`scripts/systems/node_resolver.gd`

修改`_resolve_rescue()`：
```gdscript
func _resolve_rescue(_node_config: Dictionary, run: RuntimeRun, hero: RuntimeHero) -> Dictionary:
    var result := {"success": true, "rewards": [], "combat_result": null, "logs": [], "requires_ui_selection": true, "selection_type": "rescue_partner"}
    
    # 生成3个候选伙伴
    var candidates: Array[Dictionary] = []
    var all_partner_ids = ConfigManager.get_all_partner_config_ids()
    # 过滤已拥有的伙伴
    var owned_ids = []  # 需要从CharacterManager获取
    var available_ids = []
    for pid in all_partner_ids:
        if not (pid in owned_ids):
            available_ids.append(pid)
    
    # 随机选3个
    available_ids.shuffle()
    for i in range(min(3, available_ids.size())):
        var cfg = ConfigManager.get_partner_config(str(available_ids[i]))
        candidates.append({
            "partner_config_id": available_ids[i],
            "name": cfg.get("name", "未知伙伴"),
            "role": cfg.get("role", ""),
            "favored_attr": cfg.get("favored_attr", 1),
        })
    
    result["candidates"] = candidates
    result["logs"].append("第%d层：发现遇险伙伴，请选择一名加入" % run.current_floor)
    return result
```

#### 文件2：`scenes/run_main/run_main.gd`

添加救援面板处理：
```gdscript
# 添加引用
@onready var rescue_panel: Control = $RescuePanel  # 需要在tscn中创建

# 在_on_node_options_presented中添加rescue处理
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    # ... 现有代码 ...
    elif node_options.size() == 2 and node_options[0].get("node_type") == NodePoolSystem.NodeType.RESCUE:
        # 救援层：隐藏选项按钮，显示救援面板
        for btn in option_buttons:
            btn.visible = false
        _show_rescue_panel(node_options[0].get("candidates", []))

func _show_rescue_panel(candidates: Array[Dictionary]) -> void:
    rescue_panel.visible = true
    # 更新3个候选伙伴的显示（头像/名称/擅长属性）
    for i in range(min(3, candidates.size())):
        var candidate = candidates[i]
        # 更新UI...

func _on_rescue_partner_selected(partner_config_id: int) -> void:
    _run_controller.select_rescue_partner(partner_config_id)
    rescue_panel.visible = false
    # 显示商店按钮或直接进入商店
```

#### 文件3：`scripts/systems/run_controller.gd`

确保`select_rescue_partner()`正确工作：
```gdscript
func select_rescue_partner(partner_config_id: int) -> void:
    var partner = _node_resolver.process_rescue_selection(partner_config_id, _run.current_floor, _run)
    if partner != null:
        # 伙伴已加入，可以继续（进入商店或下一层）
        _process_node_result({"success": true, "rewards": [], "logs": ["救援成功"]}}
```

---

## Bug 2：外出点击没反应

### 问题描述
点击[外出]按钮后没有任何反应。

### 根因分析
`node_resolver.gd`的`_resolve_outing()`有事件选择逻辑，但：
1. 返回的`rewards`为空，没有实际应用事件效果
2. 没有发送信号让UI显示事件结果
3. `run_controller.gd`收到空结果后没有正确处理

### 修复步骤

#### 文件4：`scripts/systems/node_resolver.gd`

重写`_resolve_outing()`：
```gdscript
func _resolve_outing(_node_config: Dictionary, run: RuntimeRun, hero: RuntimeHero) -> Dictionary:
    var result := {"success": true, "rewards": [], "combat_result": null, "logs": []}
    
    # 按4:3:3比例选择事件类型
    var roll = randi() % 10
    if roll < 4:  # 40% 奖励事件
        var reward_events = [
            {"type": "gold", "amount": 30 + run.current_floor * 2, "log": "发现宝藏，获得%d金币"},
            {"type": "level_up", "target": "random", "log": "遇到导师，随机角色等级+1"},
            {"type": "heal_full", "log": "发现圣泉，生命完全恢复"},
            {"type": "train_lv5", "attr": -1, "log": "神秘训练场，自选属性享受LV5训练"},
        ]
        var evt = reward_events[randi() % reward_events.size()]
        
        match evt.type:
            "gold":
                result["rewards"].append({"type": "gold", "amount": evt.amount})
                result["logs"].append(evt.log % evt.amount)
            "level_up":
                result["rewards"].append({"type": "level_up", "target": "random"})
                result["logs"].append(evt.log)
            "heal_full":
                var old_hp = hero.current_hp
                hero.current_hp = hero.max_hp
                result["rewards"].append({"type": "heal", "amount": hero.max_hp - old_hp})
                result["logs"].append(evt.log)
            "train_lv5":
                result["rewards"].append({"type": "train_lv5", "attr": -1})  # -1表示自选
                result["logs"].append(evt.log)
                result["requires_ui_selection"] = true
                result["selection_type"] = "train_attr"
    
    elif roll < 7:  # 30% 惩罚事件
        var penalty_events = [
            {"type": "damage", "amount": int(hero.max_hp * 0.15), "log": "落入陷阱，损失%d生命"},
            {"type": "debuff", "effect": "weak", "duration": 3, "log": "中了虚弱，接下来3层训练效果减半"},
            {"type": "steal_gold", "percent": 0.2, "log": "遭遇小偷，损失%d金币"},
            {"type": "debuff", "effect": "vulnerable", "duration": 3, "log": "喝了弱化药水，接下来3场战斗受到伤害+20%%"},
        ]
        var evt = penalty_events[randi() % penalty_events.size()]
        
        match evt.type:
            "damage":
                hero.current_hp = maxi(0, hero.current_hp - evt.amount)
                result["rewards"].append({"type": "damage", "amount": evt.amount})
                result["logs"].append(evt.log % evt.amount)
            "debuff":
                result["rewards"].append({"type": "debuff", "effect": evt.effect, "duration": evt.duration})
                result["logs"].append(evt.log)
            "steal_gold":
                var stolen = int(run.gold_owned * evt.percent)
                run.gold_owned = maxi(0, run.gold_owned - stolen)
                result["rewards"].append({"type": "gold", "amount": -stolen})
                result["logs"].append(evt.log % stolen)
    
    else:  # 30% 精英
        result["node_type_redirect"] = NodePoolSystem.NodeType.ELITE
        result["logs"].append("遭遇精英怪物！")
    
    return result
```

#### 文件5：`scenes/run_main/run_main.gd`

添加外出事件结果显示：
```gdscript
# 在_on_node_options_presented后或_process_result中添加
func show_event_result(logs: Array, rewards: Array) -> void:
    # 显示事件结果弹窗（可以用临时Label或AcceptDialog）
    var msg = ""
    for log in logs:
        msg += log + "\n"
    # 使用Godot的AcceptDialog或自定义弹窗显示
```

---

## Bug 3：前两层战斗后生命上限从120变成100

### 问题描述
初始生命120/120，点击战斗后变成当前HP/100。

### 根因分析
`scenes/run_main/run_main.gd`中两处硬编码max_hp=100：
1. 第71行：`_update_hud()`中 `var max_hp: int = hero_data.get("max_hp", 100)`
2. 第143行：`_on_stats_changed()`中 `var max_hp: int = 100  # HUD暂时使用固定最大值`

这是**UI显示bug**，不是数据bug。hero的真实max_hp可能还是120，但UI显示为100。

### 修复步骤

#### 文件6：`scenes/run_main/run_main.gd`

修复两处max_hp获取：
```gdscript
# _update_hud()中（约第71行）
func _update_hud() -> void:
    if _run_controller == null:
        return
    var summary: Dictionary = _run_controller.get_current_run_summary()
    var current_turn: int = summary.get("current_floor", 1)
    var gold: int = summary.get("gold", 0)
    var hero_data: Dictionary = summary.get("hero", {})
    var current_hp: int = hero_data.get("current_hp", 100)
    var max_hp: int = hero_data.get("max_hp", 100)  # 从hero_data读取真实max_hp
    floor_label.text = "层数: %d/30" % current_turn
    gold_label.text = "金币: %d" % gold
    hp_label.text = "生命: %d/%d" % [current_hp, max_hp]
    # ...

# _on_stats_changed()中（约第143行）
func _on_stats_changed(_unit_id: String, stat_changes: Dictionary) -> void:
    for attr_code in stat_changes.keys():
        var change: Dictionary = stat_changes[attr_code]
        var code: int = int(attr_code)
        match code:
            0:  # HP
                var new_hp: int = change.get("new", 0)
                var max_hp: int = change.get("max_hp", 100)  # 从change中获取max_hp
                # 如果change中没有max_hp，从RunController获取
                if max_hp == 100:
                    var summary = _run_controller.get_current_run_summary()
                    var hero_data = summary.get("hero", {})
                    max_hp = hero_data.get("max_hp", 100)
                hp_label.text = "生命: %d/%d" % [new_hp, max_hp]
```

#### 文件7：`scripts/systems/character_manager.gd`

确保stats_changed信号发送时包含max_hp：
```gdscript
# 在modify_hero_stats()或HP变化的地方
EventBus.emit_signal("stats_changed", hero.id, {
    0: {
        "old": old_hp,
        "new": hero.current_hp,
        "delta": delta,
        "max_hp": hero.max_hp,  # 添加max_hp
        "attr_code": 0
    }
})
```

---

## Bug 4：需要添加游戏内菜单

### 需求
添加暂停菜单，包含：
- 音量调节（Slider）
- 是否全屏（CheckBox）
- 返回主菜单（Button）
- 返回游戏（Button，关闭菜单）
- 主菜单不需要"返回主菜单"选项

### 修复步骤

#### 文件8：新建 `scenes/menu/pause_menu.tscn`

创建Control场景，包含：
```
PauseMenu (CanvasLayer)
└── Panel (居中，400x300)
    ├── TitleLabel ("菜单")
    ├── VolumeLabel ("音量")
    ├── VolumeSlider (HSlider，0-100)
    ├── FullscreenCheck (CheckBox，"全屏")
    ├── ResumeButton ("返回游戏")
    └── MainMenuButton ("返回主菜单")
```

#### 文件9：新建 `scenes/menu/pause_menu.gd`

```gdscript
class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal main_menu_requested

@onready var volume_slider: HSlider = $Panel/VolumeSlider
@onready var fullscreen_check: CheckBox = $Panel/FullscreenCheck
@onready var resume_button: Button = $Panel/ResumeButton
@onready var main_menu_button: Button = $Panel/MainMenuButton

func _ready() -> void:
    visible = false
    volume_slider.value = AudioManager.get_master_volume() * 100 if AudioManager else 50
    fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    
    volume_slider.value_changed.connect(_on_volume_changed)
    fullscreen_check.toggled.connect(_on_fullscreen_toggled)
    resume_button.pressed.connect(_on_resume)
    main_menu_button.pressed.connect(_on_main_menu)

func show_menu() -> void:
    visible = true
    get_tree().paused = true

func hide_menu() -> void:
    visible = false
    get_tree().paused = false

func _on_volume_changed(value: float) -> void:
    var vol = value / 100.0
    if AudioManager:
        AudioManager.set_master_volume(vol)
    # 或使用Godot内置AudioServer
    AudioServer.set_bus_volume_db(0, linear_to_db(vol))

func _on_fullscreen_toggled(enabled: bool) -> void:
    if enabled:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_resume() -> void:
    hide_menu()
    resume_requested.emit()

func _on_main_menu() -> void:
    hide_menu()
    main_menu_requested.emit()
    get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
```

#### 文件10：`scenes/run_main/run_main.tscn` + `scenes/run_main/run_main.gd`

添加菜单按钮和暂停逻辑：
```gdscript
# run_main.gd中添加
@onready var pause_menu: PauseMenu = $PauseMenu  # 需要在tscn中添加

func _ready() -> void:
    # ... 现有代码 ...
    # 添加暂停菜单信号
    pause_menu.resume_requested.connect(_on_resume_game)
    pause_menu.main_menu_requested.connect(_on_return_main_menu)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):  # ESC键
        if pause_menu.visible:
            pause_menu.hide_menu()
        else:
            pause_menu.show_menu()

func _on_resume_game() -> void:
    pass  # 游戏继续

func _on_return_main_menu() -> void:
    # 保存当前进度（可选）
    pass
```

---

## 附加：UI布局微调

从截图看，当前UI和v2.0规格还有差距：

1. **顶部**：当前有层数/金币/生命 + 属性条横排 → **应只保留层数/金币/生命**
2. **左侧**：当前有蓝色方块 + 五维数值 → **应添加角色名称/头像，五维数值用Label显示**
3. **右侧**：当前有敌人文字信息 → **后续可添加怪物图片占位**
4. **底部**：5个伙伴槽 → **保持**

如果要做UI美化，建议等4个功能bug修完后再做。

---

## 170个警告的说明

Godot中的170个warnings（"signal XXX is declared but never explicitly used"）是**EventBus声明的信号没有被某些类连接使用**。这些不影响运行，可以通过以下方式清理：

方案A（推荐）：在`project.godot`中禁用该类型警告：
```
[debug]
gdscript/warnings/unused_signal=0
```

方案B：在每个不使用的类中添加`# warning-ignore:unused_signal`

建议先选方案A，等游戏稳定后再考虑清理。

---

## 文件修改清单

| # | 文件 | Bug | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scripts/systems/node_resolver.gd` | 1 | _resolve_rescue()生成候选伙伴 |
| 2 | `scripts/systems/node_resolver.gd` | 2 | _resolve_outing()应用事件效果 |
| 3 | `scripts/systems/node_resolver.gd` | 3 | 确保战斗/休息发送正确stats_changed |
| 4 | `scenes/run_main/run_main.gd` | 1 | 添加救援面板显示/选择逻辑 |
| 5 | `scenes/run_main/run_main.gd` | 2 | 添加外出事件结果显示 |
| 6 | `scenes/run_main/run_main.gd` | 3 | 修复max_hp硬编码为100 |
| 7 | `scenes/run_main/run_main.gd` | 4 | 添加ESC暂停菜单 |
| 8 | `scripts/systems/run_controller.gd` | 1 | 修复select_rescue_partner() |
| 9 | `scripts/systems/character_manager.gd` | 3 | stats_changed信号包含max_hp |
| 10 | `scenes/menu/pause_menu.tscn` | 4 | 新建暂停菜单场景 |
| 11 | `scenes/menu/pause_menu.gd` | 4 | 新建暂停菜单脚本 |
