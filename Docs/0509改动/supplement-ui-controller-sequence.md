# 补充文档：UI↔Controller交互时序图

> 补充日期：2026-05-09  
> 补充到：02_interface_contracts.md / 05_run_loop_design.md / 06_ui_flow_design.md  
> 目的：补全RunMain UI与RunController之间的完整调用链，使节点按钮有响应

---

## 一、RunMain ↔ RunController 交互时序图

```
[GameManager]        [RunMain]            [RunController]        [EventBus]
     │                  │                      │                    │
     │  change_scene("RUNNING")                │                    │
     │─────────────────▶│                      │                    │
     │                  │ _ready()             │                    │
     │                  │ 1. get_tree().root.get_node("GameManager")
     │                  │ 2. hero_id = GameManager.selected_hero_config_id
     │                  │ 3. partner_ids = GameManager.selected_partner_config_ids
     │                  │ 4. _run_controller = $RunController (tscn子节点)
     │                  │                      │                    │
     │                  │ start_new_run(hero_id, partner_ids)
     │                  │─────────────────────▶│                    │
     │                  │                      │ 初始化hero/partners
     │                  │                      │ _change_state(NODE_SELECT)
     │                  │                      │ _generate_node_options()
     │                  │                      │ emit node_options_presented
     │                  │                      │───────────────────▶│
     │                  │◀─────────────────────│                    │
     │                  │ _on_node_options_presented(node_options)
     │                  │ 刷新3个按钮文本："锻炼体魄"、"普通战斗Lv3"、"商店"
     │                  │                      │                    │
     │                  │  ╔══════════════════════════════════════════════╗
     │                  │  ║ 玩家点击"锻炼体魄"按钮                         ║
     │                  │  ╚══════════════════════════════════════════════╝
     │                  │                      │                    │
     │                  │ _on_node_button_pressed(index=0)
     │                  │ 1. 禁用3个按钮（防重复点击）
     │                  │ 2. _run_controller.select_node(index)
     │                  │─────────────────────▶│                    │
     │                  │                      │ _change_state(NODE_EXECUTE)
     │                  │                      │ _node_resolver.resolve_node()
     │                  │                      │ 执行锻炼逻辑 → CharacterManager修改属性
     │                  │                      │ emit training_completed
     │                  │                      │───────────────────▶│
     │                  │                      │ emit node_resolved
     │                  │                      │───────────────────▶│
     │                  │◀─────────────────────│                    │
     │                  │ _on_node_resolved(result)
     │                  │ 更新HUD（金币/属性/生命）
     │                  │                      │                    │
     │                  │ _run_controller.advance_turn()
     │                  │─────────────────────▶│                    │
     │                  │                      │ turn++
     │                  │                      │ _change_state(TURN_ADVANCE)
     │                  │                      │ 检查回合：turn==30? FINAL_BATTLE : NODE_SELECT
     │                  │                      │ _change_state(NODE_SELECT)
     │                  │                      │ _generate_node_options()
     │                  │                      │ emit node_options_presented
     │                  │                      │───────────────────▶│
     │                  │◀─────────────────────│                    │
     │                  │ _on_node_options_presented(node_options)
     │                  │ 刷新3个按钮，启用按钮
     │                  │                      │                    │
     │  ╔═══════════════════════════════════════════════════════════════════════╗
     │  ║ 第30回合：_change_state(FINAL_BATTLE)                                 ║
     │  ║ RunController自动调用 _execute_final_battle() → _settle()             ║
     │  ║ emit run_ended → GameManager切换场景到 SETTLEMENT                    ║
     │  ╚═══════════════════════════════════════════════════════════════════════╝
```

---

## 二、信号定义补充

### 2.1 新增/修正信号

| 信号名 | 发射方 | 接收方 | 参数 | 触发时机 | 文档位置 |
|:---|:---|:---|:---|:---|:---|
| `node_selected` | RunMain (UI) | RunController | `(node_index: int)` — 玩家选择的选项索引 0/1/2 | 玩家点击节点按钮后 | **新增到 02_interface_contracts.md 2.1.2节** |
| `node_options_presented` | RunController | RunMain (RunHUD) | `(node_options: Array[Dictionary])` — 3个选项 | 每回合进入NODE_SELECT状态后 | 已存在，需补充UI响应逻辑 |
| `node_resolved` | NodeResolver | RunMain (RunHUD) | `(node_type, result_data)` | 节点执行完毕 | 已存在 |
| `training_completed` | TrainingSystem | RunMain (RunHUD) | `(attr_code, attr_name, gain, new_total, stage, bonus)` | 锻炼结算后 | 已存在 |

### 2.2 信号参数修正

`node_options_presented` 的参数格式（现有文档描述不完整）：

```gdscript
# 每个选项的Dictionary结构
{
  "node_type": int,           # 1=TRAINING, 2=BATTLE, 3=ELITE, 4=SHOP, 5=RESCUE, 6=PVP, 7=FINAL
  "node_id": String,          # 唯一标识，如 "train_vit_001"
  "node_name": String,        # 显示名称，如 "锻炼体魄"
  "description": String,      # 描述，如 "体魄+5，熟练度+1"
  "display_name": String,      # UI显示用短名
  "rewards_hint": String,     # 奖励提示，如 "体魄+5 | 熟练度+1"
  "icon_color": String,       # 节点图标颜色（ColorRect占位）
  "difficulty": int,           # 难度等级（战斗节点）
  "enemy_id": int,             # 敌人配置ID（战斗节点）
  "cost": int,                 # 消耗（锻炼节点：精力？Phase1无精力系统，忽略）
}
```

---

## 三、RunMain.gd 交互实现规范

### 3.1 _ready() 初始化流程

```gdscript
func _ready() -> void:
    # 1. 获取RunController（必须是场景子节点或代码创建）
    _run_controller = $RunController  # 或 RunController.new() + add_child()
    
    # 2. 从GameManager读取选择数据
    var gm: GameManager = get_tree().root.get_node("GameManager")
    var hero_id: int = gm.selected_hero_config_id
    var partner_ids: Array[int] = gm.selected_partner_config_ids
    
    # 3. 启动养成循环
    _run_controller.start_new_run(hero_id, partner_ids)
    
    # 4. 订阅信号
    EventBus.node_options_presented.connect(_on_node_options_presented)
    EventBus.node_resolved.connect(_on_node_resolved)
    EventBus.training_completed.connect(_on_training_completed)
    EventBus.gold_changed.connect(_on_gold_changed)
    EventBus.stats_changed.connect(_on_stats_changed)
    EventBus.hp_changed.connect(_on_hp_changed)  # 如果EventBus有此信号
    EventBus.pvp_result.connect(_on_pvp_result)
    EventBus.rescue_encountered.connect(_on_rescue_encountered)
    EventBus.partner_unlocked.connect(_on_partner_unlocked)
    
    # 5. 绑定按钮点击
    node_button_1.pressed.connect(_on_node_button_pressed.bind(0))
    node_button_2.pressed.connect(_on_node_button_pressed.bind(1))
    node_button_3.pressed.connect(_on_node_button_pressed.bind(2))
    
    # 6. 初始化HUD默认值
    _update_hud()
```

### 3.2 _on_node_options_presented() — 刷新按钮

```gdscript
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    # 保存当前选项（用于显示详情或防止篡改）
    _current_node_options = node_options
    
    # 刷新3个按钮
    for i in range(min(3, node_options.size())):
        var opt: Dictionary = node_options[i]
        var btn: Button = _node_buttons[i]
        
        # 按钮文本 = 节点名称 + 奖励提示
        var name: String = opt.get("node_name", "节点 %d" % (i+1))
        var hint: String = opt.get("rewards_hint", "")
        if hint.is_empty():
            btn.text = name
        else:
            btn.text = "%s\n%s" % [name, hint]
        
        # 按钮颜色/图标（按节点类型）
        var ntype: int = opt.get("node_type", 0)
        var color: Color = _get_node_type_color(ntype)
        _node_color_rects[i].color = color
        
        # 启用按钮
        btn.disabled = false
        btn.modulate = Color.WHITE
    
    # 隐藏未使用的按钮（选项少于3个时，如PVP/终局回合）
    for i in range(node_options.size(), 3):
        _node_buttons[i].visible = false
        _node_color_rects[i].visible = false
    
    # 回合信息更新
    var turn_label: Label = $HudContainer/TurnLabel
    turn_label.text = "第 %d 回合" % _run_controller.get_current_turn()
```

### 3.3 _on_node_button_pressed() — 玩家选择

```gdscript
func _on_node_button_pressed(index: int) -> void:
    # 防重复点击
    if _is_processing_node:
        return
    _is_processing_node = true
    
    # 禁用所有按钮
    for btn in _node_buttons:
        btn.disabled = true
        btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
    
    # 发送到RunController
    _run_controller.select_node(index)
    
    # 等待节点执行完成 → node_resolved信号
    # （异步处理，不阻塞UI）
```

### 3.4 _on_node_resolved() — 节点执行完毕

```gdscript
func _on_node_resolved(node_type: String, result_data: Dictionary) -> void:
    # 1. 更新HUD（金币/属性/HP变化已在各自的信号回调中处理）
    _update_hud()
    
    # 2. 处理特殊节点的UI反馈
    match node_type:
        "TRAIN":
            # 锻炼结果已在 training_completed 回调中显示
            pass
        "SHOP":
            # 商店弹窗已在 shop_entered 回调中处理
            pass
        "RESCUE":
            # 救援弹窗已在 rescue_encountered 回调中处理
            pass
        "PVP":
            var pvp_result: Dictionary = result_data.get("pvp_data", {})
            _show_pvp_result_popup(pvp_result)
        "FINAL":
            # 终局战结束后GameManager会切换场景，无需处理
            pass
    
    # 3. 推进回合
    _run_controller.advance_turn()
    
    # 4. 重置处理标记（advance_turn会触发新的node_options_presented）
    _is_processing_node = false
```

### 3.5 特殊节点弹窗交互

#### 锻炼弹窗 (training_popup.tscn)

```gdscript
# RunMain 中检测到锻炼节点
func _on_node_resolved(node_type: String, result_data: Dictionary) -> void:
    if node_type == "TRAIN":
        # 锻炼节点不需要弹窗——锻炼在NodeResolver中直接执行
        # 结果通过 training_completed 信号显示在HUD上
        pass
```

> **注意**：05_run_loop_design.md 4.1节说锻炼弹窗"显示当前五维属性值和阶段"，但Phase 1/2的锻炼是即时结算（无预览），弹窗可简化为HUD直接显示结果。如需弹窗，则在NodeResolver执行前暂停，弹出选择属性界面。

#### 商店弹窗 (shop_popup.tscn)

```gdscript
# RunMain 中处理商店节点
func _on_node_resolved(node_type: String, result_data: Dictionary) -> void:
    if node_type == "SHOP":
        var inventory: Array = result_data.get("shop_inventory", [])
        _show_shop_popup(inventory)

func _show_shop_popup(inventory: Array[Dictionary]) -> void:
    var popup = preload("res://scenes/shop/shop_popup.tscn").instantiate()
    add_child(popup)
    popup.set_inventory(inventory, _run_controller.get_gold())
    
    # 连接购买信号
    popup.purchase_requested.connect(_on_shop_purchase_requested)
    popup.leave_requested.connect(_on_shop_leave_requested)

func _on_shop_purchase_requested(item_index: int) -> void:
    var result: Dictionary = _run_controller.purchase_shop_item(item_index)
    if result.success:
        _update_hud()  # 金币和属性已更新
    else:
        # 显示错误提示（金币不足/已达最高等级）
        pass

func _on_shop_leave_requested() -> void:
    # 关闭弹窗 → 推进回合已在 _on_node_resolved 中调用
    pass
```

#### 救援弹窗 (rescue_popup.tscn)

```gdscript
# 救援回合：3个选项已经是3名候选伙伴
func _on_node_button_pressed(index: int) -> void:
    var opt: Dictionary = _current_node_options[index]
    if opt.get("node_type") == 5:  # RESCUE
        var partner_id: int = opt.get("partner_config_id", 0)
        _run_controller.select_node(index)  # 传入的是伙伴ID
        # select_node内部调用 rescue_system.recruit_partner(partner_id)
```

---

## 四、GameManager 选择数据传递

### 4.1 新增字段

```gdscript
# GameManager.gd 中新增
var selected_hero_config_id: int = 0          # 主角数字ID（1=勇者/2=影舞者/3=铁卫）
var selected_partner_config_ids: Array[int] = []  # 伙伴数字ID数组
```

### 4.2 时序

```
HeroSelect场景：
  玩家选择勇者 → EventBus.hero_selected.emit("hero_warrior")
  GameManager._on_hero_selected("hero_warrior"):
    selected_hero_config_id = _HERO_STRING_TO_ID["hero_warrior"]  # =1
    change_scene("TAVERN")

Tavern场景：
  玩家选择剑士(1001)和斥候(1002) → EventBus.team_confirmed.emit([1001, 1002])
  GameManager._on_team_confirmed([1001, 1002]):
    selected_partner_config_ids = [1001, 1002]
    change_scene("RUNNING")

RunMain场景：
  _ready():
    hero_id = GameManager.selected_hero_config_id  # =1
    partner_ids = GameManager.selected_partner_config_ids  # =[1001, 1002]
    RunController.start_new_run(hero_id, partner_ids)
```

---

## 五、EventBus 信号修正

### 5.1 必须新增的信号

```gdscript
# EventBus.gd — 在现有信号中添加
signal node_selected(node_index: int)              # UI→Controller：玩家选择了第几个节点
signal hp_changed(new_hp: int, max_hp: int, unit_id: String)  # 任意单位HP变化
signal partner_unlocked(partner_id: String, partner_name: String, slot: int, level: int)  # 修正：增加level参数
```

### 5.2 必须修正的信号参数

```gdscript
# node_options_presented — 现有参数已定义，但UI层没有响应逻辑
# 需补充：RunMain必须订阅此信号并刷新按钮
```

---

## 六、跨文档一致性修正

### 6.1 对应到各份文档的修改点

| 本文档内容 | 应补充到哪份文档 | 补充位置 |
|:---|:---|:---|
| 3.1 _ready()初始化流程 | `06_ui_flow_design.md` | 1.4节 "RunMain核心场景" |
| 3.2 _on_node_options_presented | `06_ui_flow_design.md` | 新增 "节点按钮交互" 子节 |
| 3.3 _on_node_button_pressed | `06_ui_flow_design.md` | 同上 |
| 3.4 _on_node_resolved | `06_ui_flow_design.md` | 同上 |
| 3.5 商店弹窗交互 | `06_ui_flow_design.md` | 1.7节 "商店弹窗"（扩展交互流程） |
| 4.1 GameManager新增字段 | `01_module_breakdown.md` | GameManager职责描述 |
| 4.2 选择数据传递时序 | `05_run_loop_design.md` | 1.2节状态说明（HERO_SELECT→TAVERN→RUNNING） |
| 5.1 node_selected信号 | `02_interface_contracts.md` | 2.1.2节回合推进信号表 |
| 5.1 hp_changed信号 | `02_interface_contracts.md` | 2.2节战斗信号表 |

---

*补充文档版本：v1.0*  
*日期：2026-05-09*
