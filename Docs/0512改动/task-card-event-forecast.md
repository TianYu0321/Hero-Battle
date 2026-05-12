# 任务卡：事件透视系统（解耦模块）

> 核心原则：事件透视是独立模块，后续新伙伴技能可直接调用 `add_charges()` 接口。

---

## 设计确认

1. **显示方式**：外出选项按钮下方小字标注 `[奖励]` `[惩罚]` `[精英]`，颜色区分
   - 绿色 = 奖励
   - 红色 = 惩罚
   - 紫色 = 精英
2. **获取途径**：目前只有PVP失败给+5次，后续新伙伴技能通过 `EventForecastSystem.add_charges()` 接口扩展
3. **消耗方式**：**每走一层消耗1次**（不是每次使用消耗）
4. **解耦要求**：EventForecastSystem 独立模块，不依赖任何具体系统

---

## 修复步骤

### Step 1：新建 EventForecastSystem 模块

**新建文件：`scripts/systems/event_forecast_system.gd`**

```gdscript
class_name EventForecastSystem
extends Node

# 透视次数（运行时，不持久化到存档，每局游戏独立）
var _foresight_charges: int = 0

# 当前层已生成的外出事件缓存（用于显示标注）
var _cached_outgoing_events: Array[Dictionary] = []

# 添加透视次数（PVP失败、伙伴技能等调用）
func add_charges(amount: int) -> void:
    _foresight_charges += amount
    print("[EventForecast] 透视次数+%d，当前=%d" % [amount, _foresight_charges])

# 获取当前透视次数
func get_charges() -> int:
    return _foresight_charges

# 消耗1次（每层推进时调用）
func consume_charge() -> void:
    if _foresight_charges > 0:
        _foresight_charges -= 1
        print("[EventForecast] 消耗1次透视，剩余=%d" % _foresight_charges)

# 判断当前是否有透视效果
func is_active() -> bool:
    return _foresight_charges > 0

# 缓存外出事件（NodePoolSystem 生成选项时调用）
func cache_outgoing_events(events: Array[Dictionary]) -> void:
    _cached_outgoing_events.clear()
    for evt in events:
        _cached_outgoing_events.append({
            "node_id": evt.get("node_id", ""),
            "event_type": _resolve_event_type(evt),
        })

# 获取指定事件的类型标注（RunMain 渲染按钮时调用）
func get_event_tag(node_id: String) -> Dictionary:
    if _foresight_charges <= 0:
        return {"text": "", "color": Color.WHITE}
    
    for evt in _cached_outgoing_events:
        if evt["node_id"] == node_id:
            match evt["event_type"]:
                "reward":
                    return {"text": "[奖励]", "color": Color(0, 1, 0)}      # 绿色
                "penalty":
                    return {"text": "[惩罚]", "color": Color(1, 0, 0)}      # 红色
                "elite":
                    return {"text": "[精英]", "color": Color(0.5, 0, 1)}    # 紫色
    
    return {"text": "", "color": Color.WHITE}

# 内部：解析事件类型（从事件配置判断）
func _resolve_event_type(event_data: Dictionary) -> String:
    var node_id: String = event_data.get("node_id", "")
    var event_config: Dictionary = ConfigManager.get_event_config(node_id)
    
    var event_type: String = event_config.get("event_type", "")
    match event_type:
        "reward", "gold_bonus", "attr_up", "partner_buff", "item_reward":
            return "reward"
        "penalty", "trap", "gold_loss", "attr_down", "hp_loss":
            return "penalty"
        "elite_encounter":
            return "elite"
    
    #  fallback：按事件池概率判断
    var pool_type: String = event_data.get("pool_type", "")
    match pool_type:
        "reward":
            return "reward"
        "penalty":
            return "penalty"
        "elite":
            return "elite"
    
    return "unknown"
```

### Step 2：NodePoolSystem 生成外出选项时缓存事件

**文件：`scripts/systems/node_pool_system.gd`**

在 `_generate_outgoing_options` 中，生成事件后调用缓存：

```gdscript
func _generate_outgoing_options(floor: int) -> Array[Dictionary]:
    var options: Array[Dictionary] = []
    ...
    # 生成3个事件选项（奖励/惩罚/精英 4:3:3比例）
    ...
    
    # **新增**：通知 EventForecastSystem 缓存事件
    var forecast_system: EventForecastSystem = get_node_or_null("/root/RunController/EventForecastSystem")
    if forecast_system != null:
        forecast_system.cache_outgoing_events(options)
    
    return options
```

### Step 3：RunController 每层推进时消耗透视次数

**文件：`scripts/systems/run_controller.gd`**

在 `advance_floor` 或 `_finish_node_execution` 中，推进层数时消耗1次：

```gdscript
func advance_floor() -> void:
    _run.current_floor += 1
    print("[RunController] 推进到第%d层" % _run.current_floor)
    
    # **新增**：事件透视消耗1次
    var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
    if forecast_system != null:
        forecast_system.consume_charge()
    
    EventBus.emit_signal("floor_changed", _run.current_floor, _MAX_TURNS, _get_phase_name())
```

### Step 4：RunMain 渲染选项按钮时显示透视标注

**文件：`scenes/run_main/run_main.gd`**

在 `_on_node_options_presented` 中，设置按钮文本时检查透视标注：

```gdscript
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    print("[RunMain] _on_node_options_presented: 选项数=%d" % node_options.size())
    _transition_ui_state(UISceneState.OPTION_SELECT)
    
    var forecast_system: EventForecastSystem = get_node_or_null("/root/RunController/EventForecastSystem")
    
    for i in range(option_buttons.size()):
        if i < node_options.size():
            var opt = node_options[i]
            var btn: Button = option_buttons[i]
            
            # 基础文本
            var btn_text: String = opt.get("node_name", "???")
            
            # **新增**：如果有事件透视，添加标注
            if forecast_system != null and forecast_system.is_active():
                var node_id: String = opt.get("node_id", "")
                var tag: Dictionary = forecast_system.get_event_tag(node_id)
                if not tag["text"].is_empty():
                    btn_text += "\n%s" % tag["text"]
                    # 设置按钮文字颜色（通过主题或rich text）
                    # 注意：Godot Button 不支持多色文本，改用子Label节点或BBCode
            
            btn.text = btn_text
            btn.visible = true
            btn.disabled = false
            
            # **新增**：如果有透视标注，设置标注颜色
            if forecast_system != null and forecast_system.is_active():
                var node_id: String = opt.get("node_id", "")
                var tag: Dictionary = forecast_system.get_event_tag(node_id)
                if not tag["text"].is_empty():
                    _apply_event_tag_style(btn, tag)
        else:
            option_buttons[i].visible = false
            option_buttons[i].disabled = true
    
    _update_monster_info(node_options)

# 新增：给按钮应用透视标注样式
func _apply_event_tag_style(btn: Button, tag: Dictionary) -> void:
    # 方案1：通过按钮的 theme_override_colors/font_color 改整行颜色（简单但整行都变色）
    # btn.add_theme_color_override("font_color", tag["color"])
    
    # 方案2：在按钮内添加子Label节点显示彩色标注（推荐，只变标注颜色）
    var existing_label = btn.get_node_or_null("EventTagLabel")
    if existing_label != null:
        existing_label.queue_free()
    
    var tag_label := Label.new()
    tag_label.name = "EventTagLabel"
    tag_label.text = tag["text"]
    tag_label.modulate = tag["color"]
    tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag_label.position = Vector2(0, btn.size.y - 20)
    tag_label.custom_minimum_size = Vector2(btn.size.x, 20)
    btn.add_child(tag_label)
```

**注意**：Button 不支持 RichTextLabel 的多色文本。推荐方案：
- 主文本用 Button 的 `text`
- 标注用子 Label 节点，设置 `modulate` 为对应颜色，放在按钮底部

### Step 5：PVP失败奖励改为实际调用

**文件：`scripts/systems/run_controller.gd`**

找到 `"pvp_result"` 分支的失败处理，删除TODO，实际调用：

```gdscript
"pvp_result":
    ...
    if won:
        _run.gold_owned += 150
        _run.gold_earned_total += 150
        _character_manager.modify_hero_stats({1: 15, 2: 15, 3: 15, 4: 15, 5: 15})
        print("[RunController] 局内PVP胜利：金币+150，全属性+15")
    else:
        _run.gold_owned += 50
        _run.gold_earned_total += 50
        _character_manager.modify_hero_stats({1: 5, 2: 5, 3: 5, 4: 5, 5: 5})
        
        # **实际调用事件透视**
        var forecast_system: EventForecastSystem = get_node_or_null("EventForecastSystem")
        if forecast_system != null:
            forecast_system.add_charges(5)
            print("[RunController] 局内PVP失败：金币+50，全属性+5，事件透视+5")
        else:
            print("[RunController] 局内PVP失败：金币+50，全属性+5（事件透视系统未初始化）")
```

### Step 6：RunController 初始化 EventForecastSystem

**文件：`scripts/systems/run_controller.gd`** 的 `_ready()`

```gdscript
func _ready() -> void:
    ...
    # **新增**：初始化事件透视系统
    var forecast_system := EventForecastSystem.new()
    forecast_system.name = "EventForecastSystem"
    add_child(forecast_system)
    print("[RunController] EventForecastSystem 已初始化")
    ...
```

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scripts/systems/event_forecast_system.gd` | 新建 | 事件透视核心模块 |
| 2 | `scripts/systems/node_pool_system.gd` | 修改 | `_generate_outgoing_options` 生成后调用 `cache_outgoing_events()` |
| 3 | `scripts/systems/run_controller.gd` | 修改 | `_ready()` 初始化 EventForecastSystem |
| 4 | `scripts/systems/run_controller.gd` | 修改 | `advance_floor()` 推进时调用 `consume_charge()` |
| 5 | `scripts/systems/run_controller.gd` | 修改 | `"pvp_result"` 失败分支实际调用 `add_charges(5)` |
| 6 | `scenes/run_main/run_main.gd` | 修改 | `_on_node_options_presented` 渲染按钮时显示透视标注 |
| 7 | `scenes/run_main/run_main.gd` | 新增 | `_apply_event_tag_style()` 给按钮添加彩色标注 |

---

## 验收标准

- [ ] PVP失败后，控制台输出包含"事件透视+5"
- [ ] 进入新的一层，透视次数-1（控制台有输出）
- [ ] 有透视次数时，外出选项按钮下方显示彩色标注：`[奖励]`绿色 / `[惩罚]`红色 / `[精英]`紫色
- [ ] 透视次数为0时，不显示任何标注
- [ ] 新伙伴技能可直接调用 `EventForecastSystem.add_charges(N)` 增加透视次数
- [ ] 事件透视模块不依赖任何具体业务系统（纯独立模块）
