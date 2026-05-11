# Bug修复任务卡（Phase 4回归）：4项Bug + 解耦方案

> 核心原则：每个Bug修复必须同步处理耦合问题，不允许在原有耦合结构上打补丁。

---

## Bug 1：商店UI关闭按钮位置错误

### 根因

ShopPanel 的 CloseButton 使用 `anchors_preset = 7`（BOTTOM_LEFT = 左下角），但手动设置了 `anchor_left = 0.5`（水平居中）。这两个值矛盾：
- `anchors_preset = 7` 要求 anchor_left=0, anchor_top=1
- 手动设置 anchor_left=0.5（水平中心点）

Godot 4.x 的 anchors_preset 和手动 anchor 混合时，以手动设置为准，但 offset 计算基准混乱，导致按钮实际位置偏离预期。

另一个问题：ShopItemContainer 的 `offset_bottom = -70.0`，CloseButton 的 `offset_top = -60.0`，两者在 Y 轴上几乎重叠（相差仅10像素），导致按钮可能部分被商品列表遮挡。

### 修复步骤

#### Step 1：修正 CloseButton 的 anchors_preset

将 `anchors_preset` 改为与手动 anchor 值一致的预设，或统一使用手动设置。

**推荐**：使用 `anchors_preset = 8`（BOTTOM_CENTER），它正好对应 `anchor_left=0.5, anchor_top=1, anchor_right=0.5, anchor_bottom=1`，与现有手动设置一致。

```
[node name="CloseButton" type="Button" parent="ShopPanel"]
layout_mode = 1
anchors_preset = 8              # BOTTOM_CENTER，不是7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -60.0
offset_top = -60.0
offset_right = 60.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 0
text = "关闭"
```

#### Step 2：调整 ShopItemContainer 高度，避免与按钮重叠

ShopItemContainer 当前：
```
offset_top = 85.0
offset_bottom = -70.0
```

这意味着容器底部距离 ShopPanel 底部 70 像素。CloseButton 高度约 40 像素（-60 到 -20），两者间隔只有 30 像素（70-40=30），加上容器内的 padding，实际间隔更小。

改为 `offset_bottom = -65.0`，给按钮留出至少 45 像素的净空间：
```
[node name="ShopItemContainer" type="VBoxContainer" parent="ShopPanel"]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_left = 20.0
offset_top = 85.0
offset_right = -20.0
offset_bottom = -65.0          # 原来是-70，改为-65
grow_horizontal = 2
```

### 解耦说明

关闭按钮的位置问题属于纯 UI 布局问题，不涉及业务逻辑耦合。但为避免未来修改 ShopPanel 结构时再次破坏按钮位置，建议将 CloseButton 的 anchors 信息注释在 tscn 文件中：
```
# CloseButton: 底部居中，距底边20px，宽120px
```

---

## Bug 2：怪物信息仅在营救时显示 / 普通层不显示

### 根因（双重问题）

**问题 A：`enemy_info_panel` 的显隐未被 UISceneState 状态机管理**

`_transition_ui_state()` 控制以下面板：
- option_container
- training_panel
- rescue_panel
- shop_panel

**唯独没有控制 `enemy_info_panel`**。这意味着：
1. 普通层显示敌人信息 → 切换到训练/救援/商店时 → enemy_info_panel 仍然可见
2. 从救援层返回普通层时 → 如果 `_update_monster_info` 没找到敌人数据 → enemy_info_panel 保持上一层的旧数据可见

**问题 B：`_update_monster_info` 的 node_type 判断可能因类型不匹配而失效**

选项字典中的 `node_type` 在 `_generate_combat_options` 中设置为 `NodeType.BATTLE`（枚举值=2）。但 `NodeType` 是 `node_pool_system.gd` 中定义的枚举，当选项字典通过信号传递到其他脚本时，枚举值可能被转换为整数或字符串。

看 `run_main.gd` 的判断：
```gdscript
var node_type: int = opt.get("node_type", 0)
if node_type == 2 or node_type == 3 or node_type == 7:
```

如果 `opt.get("node_type")` 返回的是字符串 `"2"`（JSON 反序列化后的结果），则 `int == string` 在 GDScript 中返回 `false`（严格类型比较）。

但实际上选项字典是直接内存传递的，没有经过 JSON，所以 `node_type` 应该是整数。问题 A 才是主因。

### 修复步骤

#### Step 1：将 enemy_info_panel 纳入 UISceneState 管理

修改 `_transition_ui_state()`：

```gdscript
func _transition_ui_state(new_state: UISceneState) -> void:
    print("[RunMain] UI状态: %s → %s" % [_get_ui_state_name(_current_ui_state), _get_ui_state_name(new_state)])
    _current_ui_state = new_state
    
    # 先全部隐藏
    option_container.visible = false
    training_panel.visible = false
    rescue_panel.visible = false
    shop_panel.visible = false
    enemy_info_panel.visible = false   # **新增**
    
    # 再按需显示
    match new_state:
        UISceneState.OPTION_SELECT:
            option_container.visible = true
            # 不在这里显示 enemy_info_panel，由 _update_monster_info 决定
        UISceneState.TRAINING_SELECT:
            training_panel.visible = true
        UISceneState.RESCUE_SELECT:
            rescue_panel.visible = true
        UISceneState.SHOP_BROWSE:
            shop_panel.visible = true
        UISceneState.BATTLE_PREVIEW:
            pass  # TODO
```

#### Step 2：修正 `_update_monster_info` 中的类型判断

使用宽松的类型比较，兼容 int 和 string：

```gdscript
func _update_monster_info(node_options: Array[Dictionary]) -> void:
    var has_enemy: bool = false
    var enemy_name: String = "???"
    var enemy_hp: int = 0
    var enemy_stats: Dictionary = {}

    for opt in node_options:
        var raw_type = opt.get("node_type", 0)
        var node_type: int
        if raw_type is String:
            node_type = int(raw_type)
        else:
            node_type = int(raw_type)
        
        # 战斗节点: 普通战斗(2), 精英(3), 终局(7)
        if node_type == 2 or node_type == 3 or node_type == 7:
            has_enemy = true
            var enemy_cfg: Dictionary = opt.get("enemy_config", {})
            if enemy_cfg.is_empty():
                enemy_cfg = _fetch_enemy_config_for_option(opt)
            enemy_name = enemy_cfg.get("name", "???")
            enemy_hp = enemy_cfg.get("hp", 0)
            enemy_stats = enemy_cfg
            break

    if not has_enemy:
        enemy_info_panel.visible = false
        return

    enemy_info_panel.visible = true
    enemy_name_label.text = "敌人: %s" % enemy_name
    enemy_hp_label.text = "HP: %d" % enemy_hp

    if enemy_stats.is_empty():
        enemy_info_panel.visible = false
        return
    
    var hero_stats: Dictionary = _get_current_hero_stats()
    var prediction: Dictionary = DamagePredictor.predict_battle_outcome(
        _get_current_hero_hp(), hero_stats, enemy_stats
    )

    predicted_damage_label.text = "预计损失: %d/击" % prediction.get("per_hit", 0)
    var risk: String = prediction.get("risk_level", "unknown")
    risk_label.text = DamagePredictor.get_risk_display_text(risk)
    risk_label.modulate = DamagePredictor.get_risk_color(risk)
```

#### Step 3：在 `_on_panel_opened` 中确保 enemy_info_panel 被隐藏

```gdscript
func _on_panel_opened(panel_name: String, panel_data: Dictionary) -> void:
    print("[RunMain] _on_panel_opened: 面板=%s" % panel_name)
    enemy_info_panel.visible = false  # **新增**：打开任何面板时先隐藏敌人信息
    match panel_name:
        ...
```

### 解耦说明

`enemy_info_panel` 此前是 UISceneState 状态机的"漏网之鱼"，导致状态切换时残留显示。将其纳入 `_transition_ui_state()` 统一管理，确保所有面板的显隐由单一状态机驱动，不再出现"状态A的面板在状态B时仍然可见"的问题。

---

## Bug 3：同一个角色的升级出现在商店里两次

### 根因

`shop_system.gd` 的 `generate_shop_inventory()` 使用 `partner_config_id` 作为 item_id：
```gdscript
var item_id: String = "partner_%d" % p.partner_config_id
```

如果玩家通过救援获得了两个相同类型的伙伴（比如两个剑士，config_id 都是 101），它们在 `_character_manager.get_partners()` 中作为两个独立的 `RuntimePartner` 实例返回。由于两者 `partner_config_id` 相同，生成的 `item_id` 也相同（`"partner_101"`），导致同一个角色在商店中出现两次。

v2.0 规格中伙伴应该有唯一标识（实例级），但当前 `RuntimePartner` 可能只有 `partner_config_id`（类型级）。

### 修复步骤

#### Step 1：给 RuntimePartner 添加唯一实例标识

**文件：`scripts/models/runtime_partner.gd`**

添加 `instance_id` 字段（运行时唯一，不需要持久化到存档）：

```gdscript
class_name RuntimePartner
extends RefCounted

var partner_config_id: int = 0       # 伙伴类型ID（如剑士=101）
var instance_id: int = 0               # **新增**：运行时唯一实例ID
var favored_attr: int = 1
var is_active: bool = true
var current_level: int = 1
var is_on_deck: bool = false

static var _next_instance_id: int = 1  # 静态计数器

func _init() -> void:
    instance_id = RuntimePartner._next_instance_id
    RuntimePartner._next_instance_id += 1
```

#### Step 2：修改 shop_system.gd 使用 instance_id 作为商品唯一键

```gdscript
func generate_shop_inventory(turn: int, current_gold: int) -> Array[Dictionary]:
    var inventory: Array[Dictionary] = []
    var partners: Array[RuntimePartner] = _character_manager.get_partners()
    var seen_instance_ids: Array[int] = []  # **新增**：去重检查
    
    var shown: int = 0
    for p in partners:
        if not p.is_active or shown >= 3:
            continue
        
        # **新增**：如果该实例已生成过商品，跳过
        if p.instance_id in seen_instance_ids:
            continue
        seen_instance_ids.append(p.instance_id)
        
        var item_id: String = "partner_%d_%d" % [p.partner_config_id, p.instance_id]  # **修改**：加 instance_id
        var base_cost: int = _get_item_base_cost("partner_%d" % p.partner_config_id)
        var cost: int = _calculate_current_cost(item_id, base_cost)
        var config: Dictionary = ConfigManager.get_partner_config(str(p.partner_config_id))
        var p_name: String = config.get("name", "伙伴")
        var max_level_reached: bool = p.current_level >= 5
        
        inventory.append({
            "item_id": item_id,
            "item_type": "partner_upgrade",
            "name": p_name + " Lv%d→%d" % [p.current_level, mini(5, p.current_level + 1)],
            "price": cost if not max_level_reached else 999999,
            "current_level": p.current_level,
            "effect_desc": "等级%d→%d" % [p.current_level, mini(5, p.current_level + 1)] if not max_level_reached else "已达最高等级",
            "can_afford": current_gold >= cost and not max_level_reached,
            "target_id": str(p.instance_id),   # **修改**：用 instance_id 而不是 config_id
            "target_config_id": str(p.partner_config_id),  # **新增**：保留 config_id 用于显示
        })
        shown += 1
    
    return inventory
```

#### Step 3：修改 process_purchase 使用 instance_id

```gdscript
"partner_upgrade":
    var target_id: String = item_data.get("target_id", "")   # instance_id
    var pid: int = int(target_id) if target_id.is_valid_int() else 0
    var target_config_id: int = int(item_data.get("target_config_id", "0"))
    if _character_manager.upgrade_partner_by_instance_id(pid):
        result["applied_effects"].append({"type": "partner_level", "instance_id": pid, "config_id": target_config_id, "delta": 1})
    else:
        result["error"] = "升级失败"
        return result
```

#### Step 4：CharacterManager 添加 upgrade_partner_by_instance_id

**文件：`scripts/core/character_manager.gd`**

```gdscript
func upgrade_partner_by_instance_id(instance_id: int) -> bool:
    for p in _partners:
        if p.instance_id == instance_id:
            if p.current_level >= 5:
                return false
            p.current_level += 1
            return true
    return false
```

### 解耦说明

此前商店商品使用 `partner_config_id`（类型级ID）作为唯一键，导致同类型伙伴重复显示。引入 `instance_id`（实例级ID）后：
1. 每个伙伴实例在商店中有唯一商品条目
2. 升级操作精确指向特定实例，不会误升级另一个同类型伙伴
3. `item_id` 包含 instance_id，购买计数（`_shop_purchase_counts`）也按实例隔离

---

## Bug 4：PVP弹窗存在时可点击别的按钮

### 根因

`BattleSummaryPanel` 只是 `visible = true`，没有阻止底层 UI 的交互。Godot 中如果面板没有覆盖全屏或没有设置 `mouse_filter = STOP`，玩家仍然可以点击底层的 4 个选项按钮。

用户期望的顺序：
```
点击"PVP" → 开始战斗 → 战斗画面 → 战斗结束 → 弹出窗口 → 点击箭头 → 下一层
```

这意味着弹窗必须是**模态的**（modal）：
1. 弹窗显示时，底层所有按钮必须被禁用
2. 弹窗关闭后才恢复交互
3. 弹窗关闭后才推进到下一层

当前代码中：
- `_on_battle_ended` 直接调用 `battle_summary_panel.show_result()`
- 但 RunController 的 `_finish_node_execution` 可能在 `battle_summary_panel` 还没关闭时就推进了层数
- 而且底层 `option_container` 的按钮仍然可点击

### 修复步骤

#### Step 1：新建 UIModalBlocker 遮罩层

**文件：`scenes/run_main/ui_modal_blocker.tscn`**

```
UIModalBlocker (ColorRect)
├── color = Color(0, 0, 0, 0.3)   # 半透明黑色
├── mouse_filter = 2               # STOP（拦截所有点击）
├── visible = false
```

大小设置为全屏（和 RunMain 一样大）。

#### Step 2：将 Blocker 添加到 run_main.tscn

```
[node name="UIModalBlocker" type="ColorRect" parent="."]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.3)
```

#### Step 3：修改 run_main.gd 增加模态管理

在 @onready 添加：
```gdscript
@onready var ui_modal_blocker: ColorRect = $UIModalBlocker
```

添加模态控制函数：
```gdscript
func _show_modal_panel(panel: Control) -> void:
    # 显示遮罩层
    ui_modal_blocker.visible = true
    ui_modal_blocker.z_index = panel.z_index - 1  # 在面板下方、其他UI上方
    
    # 禁用底层交互（通过状态机切到 LOADING 状态）
    _current_ui_state = UISceneState.LOADING
    option_container.visible = false
    training_panel.visible = false
    rescue_panel.visible = false
    shop_panel.visible = false
    enemy_info_panel.visible = false
    
    # 显示面板
    panel.visible = true
    panel.z_index = 100  # 确保在最上层
    
    print("[RunMain] 模态面板显示: %s" % panel.name)

func _hide_modal_panel(panel: Control) -> void:
    panel.visible = false
    ui_modal_blocker.visible = false
    
    # 恢复底层状态
    _transition_ui_state(UISceneState.OPTION_SELECT)
    
    print("[RunMain] 模态面板关闭: %s" % panel.name)
```

#### Step 4：修改 BattleSummaryPanel 和商店面板的显示逻辑

**BattleSummaryPanel 显示（战斗结束后）**：
```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    print("[RunMain] 战斗结束: winner=%s, turns=%d" % [
        battle_result.get("winner", "???"),
        battle_result.get("turns_elapsed", 0)
    ])
    _update_hud()
    
    # 以模态方式显示战斗摘要
    battle_summary_panel.show_result(battle_result)
    _show_modal_panel(battle_summary_panel)
    
    if not battle_summary_panel.confirmed.is_connected(_on_battle_summary_confirmed):
        battle_summary_panel.confirmed.connect(_on_battle_summary_confirmed, CONNECT_ONE_SHOT)

func _on_battle_summary_confirmed() -> void:
    print("[RunMain] 战斗摘要确认关闭")
    _hide_modal_panel(battle_summary_panel)
    
    # 此时才推进层数（如果 RunController 还没推进的话）
    # 注意：RunController 的 _finish_node_execution 应该在战斗结束后被调用
    # 但如果之前因为 battle_summary_panel 阻塞而没调用，这里补调
```

**但这里有个问题**：RunController 的 `_finish_node_execution` 什么时候调用？

看 `_run_battle_engine` 返回后，在哪里调用 `_finish_node_execution`？

在 `run_controller.gd` 的 `_process_node_result` 中：
```gdscript
if pending_result.requires_battle:
    var battle_result = _run_battle_engine(enemy_config_id)
    _pending_result = battle_result
    _finish_node_execution(battle_result)
```

问题是：`_run_battle_engine` 是同步执行的，在它返回时战斗已经结束了，然后立即调用 `_finish_node_execution` 推进层数。但此时 `battle_summary_panel` 还没被用户确认关闭！

这意味着层数在玩家还没看到战斗结果时就推进了，这与用户期望的"弹窗→点击箭头→下一层"顺序矛盾。

**根本修复**：将 `_finish_node_execution` 的调用延迟到用户确认关闭 battle_summary_panel 之后。

#### Step 5：引入 BattleResultState 子状态机

在 `RunController` 中增加：
```gdscript
enum BattleResultPhase {
    NONE,
    BATTLE_RUNNING,      # 战斗引擎执行中
    BATTLE_ENDED,        # 战斗结束，等待UI确认
    BATTLE_CONFIRMED,    # 用户已确认，可以推进层数
}

var _battle_result_phase: BattleResultPhase = BattleResultPhase.NONE
var _pending_battle_result: Dictionary = {}
```

修改 `_process_node_result` 的战斗分支：
```gdscript
if pending_result.requires_battle:
    _battle_result_phase = BattleResultPhase.BATTLE_RUNNING
    var battle_result = _run_battle_engine(enemy_config_id)
    _pending_battle_result = battle_result
    _battle_result_phase = BattleResultPhase.BATTLE_ENDED
    # 不立即调用 _finish_node_execution，等 RunMain 确认后再推进
    EventBus.emit_signal("battle_ended", battle_result)
```

新增 `confirm_battle_result()`：
```gdscript
func confirm_battle_result() -> void:
    if _battle_result_phase == BattleResultPhase.BATTLE_ENDED:
        _battle_result_phase = BattleResultPhase.BATTLE_CONFIRMED
        _finish_node_execution(_pending_battle_result)
        _battle_result_phase = BattleResultPhase.NONE
        _pending_battle_result = {}
```

RunMain 在用户确认后调用：
```gdscript
func _on_battle_summary_confirmed() -> void:
    print("[RunMain] 战斗摘要确认关闭")
    _hide_modal_panel(battle_summary_panel)
    
    # 通知 RunController 可以推进层数了
    if _run_controller != null:
        _run_controller.confirm_battle_result()
```

#### Step 6：BattleSummaryPanel 按钮改为"箭头"（或用户指定的按钮样式）

当前 BattleSummaryPanel 的按钮是"确定"。用户提到"点击箭头"，这更像是"下一步"的箭头图标按钮。

如果用户需要箭头按钮，修改 `battle_summary_panel.tscn`：
```
[node name="ConfirmButton" type="Button" parent="."]
text = "→"    # 箭头符号，或者保留"确定"但加大字号
```

或保持"确定"不变，因为文字按钮更明确。由用户最终确认。

#### Step 7：商店面板也使用模态方式显示

```gdscript
func _on_panel_opened(panel_name: String, panel_data: Dictionary) -> void:
    print("[RunMain] _on_panel_opened: 面板=%s" % panel_name)
    enemy_info_panel.visible = false
    match panel_name:
        "SHOP_PANEL":
            _show_shop_panel(panel_data.get("items", []))
            _show_modal_panel(shop_panel)  # **新增**：模态显示商店
```

关闭商店时：
```gdscript
func _on_shop_close_pressed() -> void:
    print("[RunMain] 商店关闭")
    _hide_modal_panel(shop_panel)  # **修改**：使用模态关闭
    if _run_controller != null:
        _run_controller.close_shop_panel()
```

### 解耦说明

引入 `UIModalBlocker` + `_show_modal_panel()` / `_hide_modal_panel()` 两个函数后：
1. 任何面板（商店、战斗摘要、未来可能的事件结果面板）都可以统一以模态方式显示
2. 底层交互自动被禁用，不会出现"弹窗存在时点别的按钮"的问题
3. `_show_modal_panel` 会自动管理 z_index 和状态机，调用方不需要关心底层细节
4. `RunController` 增加 `BattleResultPhase` 子状态机，将"战斗结束"和"用户确认"分离，确保层数推进的顺序正确

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scenes/run_main/run_main.tscn` | 修改 | CloseButton anchors_preset 7→8；ShopItemContainer offset_bottom -70→-65 |
| 2 | `scenes/run_main/run_main.tscn` | 新增 | UIModalBlocker 节点（全屏半透明遮罩） |
| 3 | `scenes/run_main/run_main.gd` | 修改 | `_transition_ui_state` 增加 `enemy_info_panel.visible = false` |
| 4 | `scenes/run_main/run_main.gd` | 修改 | `_on_panel_opened` 增加 `enemy_info_panel.visible = false` |
| 5 | `scenes/run_main/run_main.gd` | 修改 | `_update_monster_info` node_type 增加 string→int 兼容 |
| 6 | `scripts/models/runtime_partner.gd` | 新增 | `instance_id` 字段 + 静态计数器 |
| 7 | `scripts/systems/shop_system.gd` | 修改 | `generate_shop_inventory` 使用 instance_id 去重 |
| 8 | `scripts/systems/shop_system.gd` | 修改 | `process_purchase` 使用 instance_id 定位伙伴 |
| 9 | `scripts/core/character_manager.gd` | 新增 | `upgrade_partner_by_instance_id()` |
| 10 | `scenes/run_main/run_main.gd` | 新增 | `_show_modal_panel()` / `_hide_modal_panel()` |
| 11 | `scenes/run_main/run_main.gd` | 修改 | `_on_battle_ended` 使用模态显示 |
| 12 | `scenes/run_main/run_main.gd` | 修改 | `_on_battle_summary_confirmed` 调用 `_hide_modal_panel` + `confirm_battle_result` |
| 13 | `scenes/run_main/run_main.gd` | 修改 | 商店显示/关闭使用模态方式 |
| 14 | `scripts/systems/run_controller.gd` | 新增 | `BattleResultPhase` 子状态机 |
| 15 | `scripts/systems/run_controller.gd` | 修改 | `_process_node_result` 战斗分支不立即推进层数 |
| 16 | `scripts/systems/run_controller.gd` | 新增 | `confirm_battle_result()` |

---

## 验收标准

### Bug 1 验收
- [ ] 商店面板底部"关闭"按钮水平居中，不与商品列表重叠
- [ ] 按钮点击区域完整，没有被遮挡

### Bug 2 验收
- [ ] 普通层（有战斗选项）显示敌人信息面板（敌人名称、HP、预计损失）
- [ ] 点击"训练"后，敌人信息面板自动隐藏
- [ ] 救援层不显示敌人信息面板
- [ ] 从救援层返回普通层后，敌人信息面板正确显示当前层的敌人数据

### Bug 3 验收
- [ ] 商店中每个伙伴只出现一次（即使有两个同类型的伙伴）
- [ ] 升级操作精确升级玩家选择的那个伙伴实例
- [ ] 购买后对应按钮变为"已售出"，其他同类型伙伴的按钮不受影响

### Bug 4 验收
- [ ] 点击"PVP"或"战斗"后，BattleSummaryPanel 以模态方式显示（半透明遮罩覆盖底层）
- [ ] 弹窗存在时无法点击底层的 4 个选项按钮
- [ ] 弹窗存在时无法点击"菜单"按钮
- [ ] 点击弹窗的"确定"（或箭头）按钮后，弹窗关闭，遮罩消失，自动推进到下一层
- [ ] 商店面板也以模态方式显示，关闭后才推进层数
- [ ] 整个流程符合：点击PVP→开始战斗→战斗画面→战斗结束→弹出窗口→点击确认→下一层

### 解耦验收
- [ ] `run_main.gd` 中没有直接设置 `xxx.visible = true/false`（除了 `_transition_ui_state` 和 `_show_modal_panel`）
- [ ] `RunController` 中 `_finish_node_execution` 不在战斗结束后立即调用，而是等用户确认
- [ ] `ShopSystem` 使用 `instance_id` 而非 `partner_config_id` 作为商品唯一键
