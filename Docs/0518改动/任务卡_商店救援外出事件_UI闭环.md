# 任务卡：商店/救援/外出事件 UI 闭环

## 背景

当前三个节点类型的 UI 流程存在断点：
1. **救援后商店**：RESCUE 分支已生成 SHOP 节点，但救援面板关闭后不会自动进入商店面板，玩家需要手动再点一次"神秘商店"选项
2. **外出事件**：OUTING 节点在 `run_main.gd` 的 `_on_node_button_pressed()` 里直接 `select_node()` 无弹窗，只有控制台日志输出，玩家看不到事件内容和选择分支
3. **休息节点**：REST 节点同样直接 `select_node()`，点完后没有任何 UI 反馈显示回了多少血

**目标**：三个节点都有完整的"触发→弹窗→交互→反馈→推进"闭环。

---

## 节点流程总览

```
玩家点击节点按钮
    │
    ├─ BATTLE/ELITE/FINAL_BOSS → CombatConfirmPanel → BattleAnimationPanel
    ├─ TRAINING → TrainingPopup → 选择属性 → 属性+1 → 关闭弹窗 → _update_hud()
    ├─ SHOP → ShopPopup → 购买/离开 → 关闭弹窗 → _update_hud()
    ├─ RESCUE → RescuePopup → 选择伙伴 → 招募成功/放弃 → 【自动进入 ShopPopup】→ 关闭 → 推进
    ├─ OUTING → OutingPopup → 选择分支 A/B/C → 显示结果 → 关闭 → _update_hud()
    └─ REST → RestPopup → 显示回血动画 → 关闭 → _update_hud()
```

---

## 子任务 1：救援后自动进入商店

### 当前问题

`run_controller.gd` 的 RESCUE 分支：
```gdscript
if turn in _RESCUE_TURNS:
    var candidates = _rescue_system.generate_candidates()
    _current_node_options.clear()
    for c in candidates:
        _current_node_options.append({...})  # 3 个救援选项
    _current_node_options.append({         # 1 个商店选项
        "node_type": NodePoolSystem.NodeType.SHOP,
        ...
    })
    return
```

救援面板关闭后，`run_main.gd` 的 `_on_panel_closed()` 只做 `_transition_ui_state(UISceneState.OPTION_SELECT)`，不会自动弹出商店。玩家回到 4 选项界面，看到"神秘商店"选项，需要再点一次。

### 修改方案

**方案 A（推荐）：救援完成后直接触发商店，不在选项列表里显示**

`run_main.gd`：
```gdscript
func _on_panel_closed(panel_name: String, close_reason: String) -> void:
    if panel_name == "RescuePopup":
        if close_reason == "partner_selected":
            ## 伙伴已招募，自动弹出商店
            _auto_open_shop_after_rescue()
            return
        ## 放弃救援，直接回选项
    
    _transition_ui_state(UISceneState.OPTION_SELECT)
    _update_hud()

func _auto_open_shop_after_rescue() -> void:
    ## 从当前节点选项中找 SHOP 节点
    var summary: Dictionary = _run_controller.get_current_run_summary()
    var node_options: Array[Dictionary] = summary.get("node_options", [])
    for opt in node_options:
        if opt.get("node_type", 0) == NodePoolSystem.NodeType.SHOP:
            _open_shop(opt)
            return
    ## 找不到商店节点（异常情况）
    push_warning("[RunMain] 救援后找不到商店节点")
    _transition_ui_state(UISceneState.OPTION_SELECT)
```

**方案 B（备选）：保留"神秘商店"选项，但高亮提示**

如果希望玩家有选择权（救援后可以跳过商店），保留选项但给商店选项加闪烁边框或"推荐"标签。

**建议用方案 A**：救援后强制进商店是设计意图（"救援完正好遇到商人"），减少一次无意义的点击。

### 涉及文件

- `scenes/run_main/run_main.gd` — 新增 `_auto_open_shop_after_rescue()`，修改 `_on_panel_closed()`
- `scenes/rescue/rescue_popup.gd` — 确保关闭时 emit `panel_closed` 信号带 `close_reason = "partner_selected"` 或 `"abandoned"`

---

## 子任务 2：外出事件弹窗（OutingPopup）

### 当前问题

`run_main.gd` `_on_node_button_pressed()`：
```gdscript
NodePoolSystem.NodeType.OUTING:
    _run_controller.select_node(index)  ## 直接执行，无弹窗
```

`node_resolver.gd` `_resolve_outing_dict()` 只返回一个字典，没有交互分支。外出事件的结果直接应用到英雄属性/金币上，玩家完全不知道发生了什么。

### 设计方案

外出事件 = 随机遭遇小故事，3 选 1：
- 选项 A：安全但收益低
- 选项 B：风险中等，可能好可能坏
- 选项 C：高风险高回报

**新建 `scenes/outing/outing_popup.tscn` + `outing_popup.gd`**

节点结构：
```
OutingPopup (PanelContainer, 居中, 宽 800 高 500)
├── TitleLabel ("外出遭遇")
├── EventImage (TextureRect, 事件插图占位)
├── DescriptionLabel (RichTextLabel, 事件描述文本)
├── ChoicesContainer (VBoxContainer)
│   ├── ChoiceButton_A
│   ├── ChoiceButton_B
│   └── ChoiceButton_C
└── ResultPanel (VBoxContainer, 初始 hidden)
    ├── ResultLabel (结果描述)
    ├── EffectLabel ("HP +10 / 金币 -20" 等)
    └── ConfirmButton ("继续")
```

### 数据流

1. `NodeResolver._resolve_outing_dict()` 生成事件配置（含 3 个选项和对应结果）
2. `run_main._on_node_button_pressed()` 检测到 OUTING → `_show_outing_popup(selected_node)`
3. `outing_popup.gd` 读取事件配置，显示描述和 3 个选项
4. 玩家点击选项 → 播放简单动画（如金币飞走/HP 上升粒子）→ 显示结果面板
5. 点击确认 → `outing_popup.confirmed.emit(choice_index)` → `run_main` 调用 `_run_controller.resolve_outing_choice(choice_index)` → 应用效果 → 关闭弹窗 → `_update_hud()`

### `node_resolver.gd` 修改

```gdscript
func _resolve_outing_dict(hero: RuntimeHero, run_data: RuntimeRun) -> Dictionary:
    var templates: Array[Dictionary] = [
        {
            "title": "神秘商人",
            "description": "一个裹着斗篷的商人拦住了你。他展示了三件物品...",
            "choices": [
                {"text": "购买护身符 (金币-30, 下次战斗伤害-20%)", "cost_gold": 30, "effect": {"damage_reduction": 0.2, "turns": 1}},
                {"text": "购买情报 (金币-15, 透视下次节点)", "cost_gold": 15, "effect": {"forecast_charge": 1}},
                {"text": "拒绝并离开", "cost_gold": 0, "effect": {}},
            ]
        },
        {
            "title": "竞技场外围赌局",
            "description": "观众席有人在开盘口，赌下一场战斗的胜负...",
            "choices": [
                {"text": "押自己赢 (金币-20, 胜利后返还50)", "cost_gold": 20, "effect": {"bet_win": 50}},
                {"text": "小额试水 (金币-5, 胜利后返还15)", "cost_gold": 5, "effect": {"bet_win": 15}},
                {"text": "不参与", "cost_gold": 0, "effect": {}},
            ]
        },
        {
            "title": "受伤的训练师",
            "description": "一位满身是伤的退役训练师倒在路边，他请求帮助...",
            "choices": [
                {"text": "给予治疗药水 (HP-10, 获得训练次数+1)", "cost_hp": 10, "effect": {"training_bonus": 1}},
                {"text": "给予金币买绷带 (金币-20, 获得随机属性+2)", "cost_gold": 20, "effect": {"random_attr": 2}},
                {"text": "无视走开", "cost_gold": 0, "effect": {}},
            ]
        },
    ]
    
    ## 随机选模板或按层数递进
    var idx: int = randi() % templates.size()
    var tpl: Dictionary = templates[idx].duplicate(true)
    tpl["node_type"] = NodePoolSystem.NodeType.OUTING
    return tpl
```

### `run_controller.gd` 新增

```gdscript
func select_outing_choice(choice_index: int) -> Dictionary:
    ## 由 OutingPopup 调用，应用选择结果
    var node: Dictionary = _current_node_options[_selected_outing_index]
    var choices: Array = node.get("choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        push_error("[RunController] 无效外出选择")
        return {}
    
    var choice: Dictionary = choices[choice_index]
    var result := {
        "success": true,
        "message": "",
        "hp_change": 0,
        "gold_change": -choice.get("cost_gold", 0),
    }
    
    var cost_hp: int = choice.get("cost_hp", 0)
    if cost_hp > 0:
        _hero.current_hp = maxi(0, _hero.current_hp - cost_hp)
        result["hp_change"] = -cost_hp
    
    var cost_gold: int = choice.get("cost_gold", 0)
    if cost_gold > 0:
        _run.gold_owned = maxi(0, _run.gold_owned - cost_gold)
        result["gold_change"] = -cost_gold
    
    ## 应用效果（如伤害减免、透视次数等）
    var effect: Dictionary = choice.get("effect", {})
    ## ... 运行时 buff/debuff 系统（如没有可以先存到 hero 的临时属性里）
    
    EventBus.emit_signal("gold_changed", _run.gold_owned, result["gold_change"], "outing")
    if result["hp_change"] != 0:
        EventBus.emit_signal("hero_hp_changed", _hero.current_hp, _hero.max_hp, result["hp_change"])
    
    return result
```

### 涉及文件

1. `scenes/outing/outing_popup.tscn` — 新建场景
2. `scenes/outing/outing_popup.gd` — 新建脚本
3. `scripts/systems/node_resolver.gd` — 修改 `_resolve_outing_dict()` 返回完整事件配置
4. `scripts/systems/run_controller.gd` — 新增 `select_outing_choice()`
5. `scenes/run_main/run_main.gd` — `_on_node_button_pressed()` 增加 OUTING 分支，`_show_outing_popup()`
6. `scenes/run_main/run_main.tscn` — 添加 OutingPopup 节点实例

---

## 子任务 3：休息节点反馈（RestPopup）

### 当前问题

REST 节点直接 `select_node()`，没有任何 UI 反馈。玩家点了"休息"后，只看到 HUD 的 HP 条突然增加了，不知道回了多少血。

### 设计方案

**轻量方案**：不用独立弹窗，在 `run_main.gd` 的 REST 分支直接显示一个浮动文字 + 粒子效果。

```gdscript
## run_main.gd
NodePoolSystem.NodeType.REST:
    _run_controller.select_node(index)
    ## 显示回血反馈
    var heal_amount: int = _run_controller.get_last_rest_heal_amount()  ## 需要 RC 暴露
    _show_rest_feedback(heal_amount)

func _show_rest_feedback(heal_amount: int) -> void:
    ## 在 HeroHPBar 上方飘出 "+XX HP" 绿色文字
    var label := Label.new()
    label.text = "+%d HP" % heal_amount
    label.add_theme_color_override("font_color", Color("#00FF88"))
    label.add_theme_font_size_override("font_size", 24)
    label.position = hero_hp_bar.global_position + Vector2(0, -40)
    add_child(label)
    
    var tween := create_tween()
    tween.tween_property(label, "position:y", label.position.y - 60, 1.0)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
    tween.finished.connect(label.queue_free)
    
    ## 可选：HP 条闪烁绿色
    var hp_tween := create_tween()
    hp_tween.tween_property(hero_hp_bar, "modulate", Color(0.5, 1.0, 0.5), 0.2)
    hp_tween.tween_property(hero_hp_bar, "modulate", Color.WHITE, 0.3)
```

**完整方案（如有更多休息变体）**：新建 `scenes/rest/rest_popup.tscn`
- 显示"你在安全的角落休息了一晚"
- HP 条从旧值动画增长到新值（1 秒 Tween）
- 显示"HP +XX" 浮动文字
- 如果有伙伴，显示伙伴好感度变化
- 确认按钮关闭

**建议用轻量方案**：REST 是低交互节点，不需要独立弹窗打断节奏。飘字 + HP 条动画足够。

### `run_controller.gd` 新增

```gdscript
var _last_rest_heal_amount: int = 0

func _process_node_result(index: int) -> void:
    ## ...
    NodePoolSystem.NodeType.REST:
        var rest_result: Dictionary = _rest_system.rest(_hero)
        _last_rest_heal_amount = rest_result.get("heal_amount", 0)
        _hero.current_hp = min(_hero.max_hp, _hero.current_hp + _last_rest_heal_amount)
        EventBus.emit_signal("hero_hp_changed", _hero.current_hp, _hero.max_hp, _last_rest_heal_amount)
        ## ...

func get_last_rest_heal_amount() -> int:
    return _last_rest_heal_amount
```

### 涉及文件

1. `scenes/run_main/run_main.gd` — 新增 `_show_rest_feedback()`
2. `scripts/systems/run_controller.gd` — 新增 `_last_rest_heal_amount` 和 `get_last_rest_heal_amount()`

---

## 测试清单

### 救援→商店
- [ ] 第 5 层救援面板弹出，显示 3 个候选伙伴
- [ ] 选择伙伴后，救援面板关闭，自动弹出商店面板
- [ ] 商店面板显示正确商品列表
- [ ] 购买/离开后，回到选项界面，救援节点和商店节点都已消失
- [ ] 放弃救援（不选伙伴），直接回到选项界面，不弹出商店

### 外出事件
- [ ] 点击 OUTING 节点，弹出 OutingPopup
- [ ] 弹窗显示事件标题、描述、3 个选项
- [ ] 选择选项后，显示结果面板（描述 + 效果文字）
- [ ] 点击确认后，效果应用到英雄（金币/HP/属性变化）
- [ ] HUD 正确更新（金币、HP、五维）
- [ ] 回到选项界面，OUTING 节点消失
- [ ] 金币不足时对应选项自动 disabled 或显示 "金币不足"

### 休息反馈
- [ ] 点击 REST 节点，不弹窗
- [ ] HeroHPBar 上方飘出 "+XX HP" 绿色文字，1 秒后消失
- [ ] HP 条闪烁绿色后恢复白色
- [ ] HUD 的 HP 数值正确更新
- [ ] 回到选项界面，REST 节点消失

---

## 执行顺序建议

1. **先做休息反馈（子任务 3）** — 最简单，1 个函数 + 1 个变量暴露
2. **同时做救援→商店（子任务 1）** — 改 `_on_panel_closed` 信号流程
3. **最后做外出事件（子任务 2）** — 需要新建场景 + 改 NodeResolver + 改 RunController，工作量最大

三个子任务互不阻塞，可以串行或并行（如果多人协作）。