# 任务卡：三Bug修复 + 代码解耦（v2.2）

> 优先级：P0（阻断性问题）
> 修复原则：**先解耦，再修Bug**。不允许在原有耦合结构上打补丁，否则Bug会反复回归。

---

## 一、耦合性诊断（为什么改A会影响B）

当前代码存在以下耦合问题，导致每次修改都会引发回归：

### 耦合点1：UI显隐逻辑散落在6个回调里
`run_main.gd` 中 `option_container.visible`、`training_panel.visible`、`rescue_panel.visible` 的设置分散在：
- `_on_node_options_presented()`
- `_on_panel_opened()` / `_on_panel_closed()`
- `_on_training_attr_selected()`
- `_on_rescue_partner_selected()`
- `_on_floor_advanced()`

**后果**：任何新增的面板或修改回调顺序，都会破坏已有的显隐平衡。选项按钮消失就是因为某个回调没调用 `_show_option_container()`。

### 耦合点2：RunController直接操作CharacterManager内部字段
```gdscript
_character_manager._hero = _hero  # run_controller.gd 第106行
```
访问了命名约定上的私有字段。如果 CharacterManager 内部改了 `_hero` 的初始化逻辑，这里就会失效。

### 耦合点3：存档字段命名混用（floor vs turn）
- `save_manager.gd` 验证的是 `current_floor`
- `run_controller.gd` 使用的是 `current_turn`
- `RuntimeRun.from_dict()` 的字段映射不透明

**后果**：存档恢复时层数错乱，继续游戏可能直接跳到终局战。

### 耦合点4：特殊层流程被拆成三个文件
救援层的"救援→商店"流程被拆散：
- `node_pool_system.gd`：生成两个独立选项（救援、商店）
- `run_controller.gd`：`_process_node_result` 处理救援选择后直接 `advance_turn()`
- `run_main.gd`：显示救援面板，选择后推进层数

**后果**：救援和商店变成了二选一，而不是顺序执行。因为 `_generate_node_options` 把它们当成普通选项并列呈现，选了一个就直接推进。

---

## 二、解耦方案（必须按此执行）

### 解耦1：引入 `UISceneState` 统一状态机
在 `run_main.gd` 中增加一个枚举，所有面板切换必须通过 `_transition_ui_state()`：

```gdscript
enum UISceneState {
    LOADING,           # 什么都不显示，等待初始化
    OPTION_SELECT,     # 显示4个选项按钮
    TRAINING_SELECT,   # 显示训练属性面板
    RESCUE_SELECT,     # 显示3个候选伙伴
    SHOP_BROWSE,       # 显示商店（后续实现）
    EVENT_RESULT,      # 显示外出事件结果
    BATTLE_PREVIEW,    # 显示敌人信息+战斗按钮
}

var _current_ui_state: UISceneState = UISceneState.LOADING

func _transition_ui_state(new_state: UISceneState) -> void:
    print("[RunMain] UI状态: %s → %s" % [_get_ui_state_name(_current_ui_state), _get_ui_state_name(new_state)])
    _current_ui_state = new_state
    
    # 先全部隐藏
    option_container.visible = false
    training_panel.visible = false
    rescue_panel.visible = false
    # shop_panel.visible = false  # 后续有商店时添加
    
    # 再按需显示
    match new_state:
        UISceneState.OPTION_SELECT:
            option_container.visible = true
        UISceneState.TRAINING_SELECT:
            training_panel.visible = true
        UISceneState.RESCUE_SELECT:
            rescue_panel.visible = true
        UISceneState.SHOP_BROWSE:
            pass  # TODO
```

**禁止**：任何回调函数直接设置 `xxx.visible = true/false`，必须通过 `_transition_ui_state()`。

### 解耦2：引入 `RunSnapshot` 纯数据类统一存档格式
新建 `scripts/data/run_snapshot.gd`：

```gdscript
class_name RunSnapshot
extends RefCounted

var hero_config_id: int = 0
var current_floor: int = 1
var gold: int = 0

# 英雄属性
var hero_vit: int = 0
var hero_str: int = 0
var hero_agi: int = 0
var hero_tec: int = 0
var hero_mnd: int = 0
var hero_hp: int = 0
var hero_max_hp: int = 0

# 训练计数
var training_counts: Dictionary = {}

# 伙伴列表（存 partner_config_id + favored_attr + is_active）
var partners: Array[Dictionary] = []

# 其他运行时数据
var node_history: Array = []
var battle_win_count: int = 0
var elite_win_count: int = 0

func to_dict() -> Dictionary:
    return {
        "version": 1,
        "hero_config_id": hero_config_id,
        "current_floor": current_floor,
        "gold": gold,
        "hero": {
            "current_vit": hero_vit,
            "current_str": hero_str,
            "current_agi": hero_agi,
            "current_tec": hero_tec,
            "current_mnd": hero_mnd,
            "current_hp": hero_hp,
            "max_hp": hero_max_hp,
            "training_counts": training_counts,
        },
        "partners": partners,
        "node_history": node_history,
        "battle_win_count": battle_win_count,
        "elite_win_count": elite_win_count,
    }

static func from_dict(data: Dictionary) -> RunSnapshot:
    var snap = RunSnapshot.new()
    snap.hero_config_id = data.get("hero_config_id", data.get("hero_id", 0))
    snap.current_floor = data.get("current_floor", data.get("current_turn", 1))
    snap.gold = data.get("gold", data.get("gold_owned", 0))
    
    var hero_data = data.get("hero", {})
    snap.hero_vit = hero_data.get("current_vit", 0)
    snap.hero_str = hero_data.get("current_str", 0)
    snap.hero_agi = hero_data.get("current_agi", 0)
    snap.hero_tec = hero_data.get("current_tec", 0)
    snap.hero_mnd = hero_data.get("current_mnd", 0)
    snap.hero_hp = hero_data.get("current_hp", 0)
    snap.hero_max_hp = hero_data.get("max_hp", 0)
    snap.training_counts = hero_data.get("training_counts", {})
    
    snap.partners = data.get("partners", [])
    snap.node_history = data.get("node_history", [])
    snap.battle_win_count = data.get("battle_win_count", 0)
    snap.elite_win_count = data.get("elite_win_count", 0)
    return snap
```

**所有存档读写统一用 `RunSnapshot`**，不再在 `save_manager.gd` 和 `run_controller.gd` 里混用不同字段名。

### 解耦3：特殊层流程改为顺序状态机
救援层（5/15/25）不再是两个选项让玩家二选一，而是强制顺序：

```
进入第5层 → 显示救援面板 → 玩家选伙伴 → 自动显示商店面板 → 玩家购买/关闭商店 → 自动推进到第6层
```

实现方式：在 `run_controller.gd` 中增加 `RescueFloorState`：

```gdscript
enum SpecialFloorPhase {
    NONE,
    RESCUE_SELECT,      # 选择伙伴阶段
    SHOP_BROWSE,        # 商店阶段
    COMPLETE,           # 完成，推进层数
}

var _special_floor_phase: SpecialFloorPhase = SpecialFloorPhase.NONE
```

当 `_generate_node_options` 检测到救援层时：
1. 不生成选项按钮
2. 设置 `_special_floor_phase = RESCUE_SELECT`
3. 直接发射 `panel_opened("RESCUE_PANEL", candidates)`

当玩家选择伙伴后：
1. `select_rescue_partner()` 设置 `_special_floor_phase = SHOP_BROWSE`
2. 发射 `panel_opened("SHOP_PANEL", shop_items)`
3. 不推进层数

当商店关闭后：
1. 设置 `_special_floor_phase = COMPLETE`
2. 调用 `_finish_node_execution()` 推进层数

---

## 三、Bug 1：救援和商店不是二选一，是先救援后商店

### 根因
`node_pool_system._generate_rescue_options()` 返回两个**并列选项**（救援、商店），`run_controller._generate_node_options()` 把它们当成普通选项呈现给玩家二选一。但设计意图是**强制顺序**：救援 → 商店 → 下一层。

### 修复步骤

#### Step 1：修改 `node_pool_system.gd`
救援层只生成一个标记性选项，不生成商店选项：

```gdscript
func _generate_rescue_options(floor: int) -> Array[Dictionary]:
    return [{
        "node_type": NodePoolSystem.NodeType.RESCUE,
        "node_name": "救援",
        "description": "发现遇险伙伴",
        "node_id": "rescue_%d" % floor,
    }]
```

#### Step 2：修改 `run_controller.gd` 的 `_generate_node_options`
检测到救援层时，设置子状态机并直接打开救援面板：

```gdscript
func _generate_node_options() -> void:
    var turn: int = _run.current_turn
    
    if turn in _RESCUE_TURNS:
        _special_floor_phase = SpecialFloorPhase.RESCUE_SELECT
        var rescue_system = get_node_or_null("RescueSystem")
        var candidates = []
        if rescue_system != null:
            candidates = rescue_system.generate_candidates()
        # 不生成普通选项，直接打开救援面板
        EventBus.emit_signal("panel_opened", "RESCUE_PANEL", {"candidates": candidates})
        return
    
    if turn in _PVP_TURNS:
        # ... 保持现有逻辑
        return
    
    if turn == _FINAL_TURN:
        # ... 保持现有逻辑
        return
    
    # 普通层生成4选项
    _current_node_options = _node_pool_system.generate_options(turn)
    EventBus.emit_signal("node_options_presented", _current_node_options)
```

#### Step 3：修改 `run_controller.gd` 的 `select_rescue_partner`
选择伙伴后进入商店阶段，不推进层数：

```gdscript
func select_rescue_partner(partner_config_id: int) -> void:
    var rescue_system = get_node_or_null("RescueSystem")
    if rescue_system != null:
        rescue_system.rescue_partner(partner_config_id, _run.current_turn)
    
    # 如果当前是救援层的救援阶段，进入商店阶段
    if _special_floor_phase == SpecialFloorPhase.RESCUE_SELECT:
        _special_floor_phase = SpecialFloorPhase.SHOP_BROWSE
        var shop_system = get_node_or_null("ShopSystem")
        var shop_items = []
        if shop_system != null:
            shop_items = shop_system.generate_items(_run.current_turn)
        EventBus.emit_signal("panel_opened", "SHOP_PANEL", {"items": shop_items})
    else:
        # 非救援层的普通救援（如果有的话），直接完成
        _finish_node_execution(_pending_result)
```

#### Step 4：添加商店关闭回调
在 `run_controller.gd` 中新增：

```gdscript
func close_shop_panel() -> void:
    if _special_floor_phase == SpecialFloorPhase.SHOP_BROWSE:
        _special_floor_phase = SpecialFloorPhase.COMPLETE
        _finish_node_execution({"success": true, "rewards": []})
```

`run_main.gd` 中商店面板的关闭按钮要调用 `_run_controller.close_shop_panel()`。

#### Step 5：`run_main.gd` 的 `_on_rescue_partner_selected` 不需要推进层数
因为 `run_controller.select_rescue_partner()` 现在自己管理状态机，UI层只需要关闭救援面板：

```gdscript
func _on_rescue_partner_selected(index: int) -> void:
    var summary = _run_controller.get_current_run_summary()
    var node_options = summary.get("node_options", [])
    var candidates = []
    if node_options.size() > 0:
        candidates = node_options[0].get("candidates", [])
    if index < candidates.size():
        var partner_config_id = int(candidates[index].get("partner_config_id", 0))
        if partner_config_id > 0:
            _run_controller.select_rescue_partner(partner_config_id)
            # UI状态切换由 RunController 的下一个 panel_opened 信号驱动
```

---

## 四、Bug 2：继续游戏直接到最终战，没有属性

### 根因
`continue_from_save()` 中存档字段命名混用导致层数恢复错误：
- 存档可能存的是 `current_floor`，但 `RuntimeRun` 可能只有 `current_turn` 字段
- `RuntimeRun.from_dict()` 如果无法正确映射 `current_floor` → `current_turn`，恢复后 `current_turn` 可能默认变成30或其他错误值

另一个可能：`_auto_save()` 调用的 `save_run_state(_run.to_dict())` 中，`_run.to_dict()` 的字段和 `RuntimeRun.from_dict()` 期望的字段不匹配。

### 修复步骤

#### Step 1：新建 `run_snapshot.gd`（见解耦2中的代码）

#### Step 2：修改 `save_manager.gd`
使用 `RunSnapshot` 统一存档格式：

```gdscript
func save_run_state(run_data: Dictionary, is_auto: bool = true) -> bool:
    var snapshot = RunSnapshot.from_dict(run_data)
    var data = snapshot.to_dict()
    data["timestamp"] = Time.get_unix_time_from_system()
    data["is_auto_save"] = is_auto
    # ... 存文件
```

#### Step 3：修改 `run_controller.gd` 的 `continue_from_save`
使用 `RunSnapshot` 恢复，确保字段映射正确：

```gdscript
func continue_from_save(save_data: Dictionary) -> bool:
    print("[RunController] 恢复存档")
    if save_data.is_empty():
        push_error("[RunController] Cannot continue from empty save data")
        return false
    
    var snapshot = RunSnapshot.from_dict(save_data)
    print("[RunController] 存档解析: floor=%d, hero_id=%d, gold=%d" % [snapshot.current_floor, snapshot.hero_config_id, snapshot.gold])
    
    # 恢复 RuntimeRun
    _run = RuntimeRun.new()
    _run.hero_config_id = snapshot.hero_config_id
    _run.current_turn = snapshot.current_floor  # 统一用 floor 映射到 turn
    _run.gold_owned = snapshot.gold
    _run.node_history = snapshot.node_history.duplicate()
    _run.battle_win_count = snapshot.battle_win_count
    _run.elite_win_count = snapshot.elite_win_count
    
    # 恢复英雄（通过 CharacterManager 的公共接口，不直接操作私有字段）
    if _character_manager != null:
        _hero = _character_manager.load_hero_from_snapshot(snapshot)
    else:
        push_error("[RunController] CharacterManager not initialized")
        return false
    
    # 恢复伙伴
    _character_manager.clear_partners()
    for p in snapshot.partners:
        var partner = RuntimePartner.from_dict(p)
        _character_manager.add_partner(partner)
    
    print("[RunController] 英雄恢复: VIT=%d STR=%d AGI=%d TEC=%d MND=%d HP=%d/%d" % [
        _hero.current_vit, _hero.current_str, _hero.current_agi, 
        _hero.current_tec, _hero.current_mnd, _hero.current_hp, _hero.max_hp
    ])
    
    # 重置节点池
    _node_pool_system.reset()
    
    # 恢复状态
    _state = RunState.RUNNING_NODE_SELECT
    _change_state(RunState.RUNNING_NODE_SELECT)
    
    EventBus.emit_signal("run_continued", _run.current_turn)
    print("[RunController] 存档恢复完成，当前层=%d" % _run.current_turn)
    return true
```

#### Step 4：在 `character_manager.gd` 中添加公共恢复接口

```gdscript
func load_hero_from_snapshot(snapshot: RunSnapshot) -> RuntimeHero:
    # 根据 hero_config_id 重新初始化英雄
    var hero = initialize_hero(snapshot.hero_config_id)
    # 覆盖属性为存档值
    hero.current_vit = snapshot.hero_vit
    hero.current_str = snapshot.hero_str
    hero.current_agi = snapshot.hero_agi
    hero.current_tec = snapshot.hero_tec
    hero.current_mnd = snapshot.hero_mnd
    hero.current_hp = snapshot.hero_hp
    hero.max_hp = snapshot.hero_max_hp
    hero.training_counts = snapshot.training_counts.duplicate()
    return hero
```

**禁止**在 `run_controller.gd` 中直接写 `_character_manager._hero = _hero`。

#### Step 5：修改 `run_main.gd` 的 `_ready()` 中的存档恢复逻辑
确保恢复后正确刷新UI：

```gdscript
func _ready() -> void:
    # ... 信号连接 ...
    
    _run_controller = RunController.new()
    _run_controller.name = "RunController"
    add_child(_run_controller)
    
    # 检查是否有待加载的存档
    var pending_save = GameManager.pending_save_data
    if not pending_save.is_empty():
        print("[RunMain] 检测到待恢复存档")
        var success = _run_controller.continue_from_save(pending_save)
        if success:
            GameManager.pending_save_data = {}
            _update_hud()
            # 不要在这里手动调用 _show_option_container()
            # 让 _change_state → _generate_node_options → node_options_presented 信号来驱动UI显示
        else:
            push_error("[RunMain] 存档恢复失败，回到主菜单")
            get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")
    else:
        # 正常新开局
        var hero_config_id = GameManager.selected_hero_config_id
        var partner_config_ids = GameManager.selected_partner_config_ids.duplicate()
        if hero_config_id <= 0:
            push_error("[RunMain] No hero selected")
            return
        _run_controller.start_new_run(hero_config_id, partner_config_ids)
```

---

## 五、Bug 3：选项按钮又消失了

### 根因
UI显隐逻辑散落在多个回调中，缺少统一状态机。具体触发路径：
1. `continue_from_save()` 调用 `_change_state(RUNNING_NODE_SELECT)`
2. `_change_state` 发射 `floor_changed` 信号
3. `run_main._on_floor_changed()` 把按钮 text 改成 "..." 并 disabled = true
4. 但 `node_options_presented` 信号可能没有触发，或触发时 `node_options` 为空
5. 导致按钮保持 disabled 且不可见

另一个可能：`run_main._on_floor_advanced()` 把按钮 disabled 了，但后续信号没恢复。

### 修复步骤（基于解耦1的 UISceneState）

#### Step 1：在 `run_main.gd` 中实现 `_transition_ui_state()`
（见解耦1中的代码）

#### Step 2：重写所有涉及显隐的回调

```gdscript
func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
    _transition_ui_state(UISceneState.OPTION_SELECT)
    
    # 更新按钮内容
    for i in range(option_buttons.size()):
        if i < node_options.size():
            var opt = node_options[i]
            option_buttons[i].text = opt.get("node_name", "???")
            option_buttons[i].visible = true
            option_buttons[i].disabled = false
        else:
            option_buttons[i].visible = false
            option_buttons[i].disabled = true
    
    _update_monster_info(node_options)

func _on_panel_opened(panel_name: String, panel_data: Dictionary) -> void:
    match panel_name:
        "TRAINING_PANEL":
            _transition_ui_state(UISceneState.TRAINING_SELECT)
            _show_training_panel_details(panel_data)
        "RESCUE_PANEL":
            _transition_ui_state(UISceneState.RESCUE_SELECT)
            _show_rescue_panel_details(panel_data.get("candidates", []))
        "SHOP_PANEL":
            _transition_ui_state(UISceneState.SHOP_BROWSE)
            # TODO: 显示商店

func _on_panel_closed(_panel_name: String, _close_reason: String) -> void:
    # 面板关闭后回到选项状态
    _transition_ui_state(UISceneState.OPTION_SELECT)

func _on_training_attr_selected(attr_type: int) -> void:
    if _run_controller != null:
        _run_controller.select_training_attr(attr_type)
    # 训练完成后 RunController 会发射 panel_closed 或 node_options_presented
    # 不要在这里手动切状态，让信号驱动
```

#### Step 3：删除 `_show_option_container()` 等旧函数
把所有直接操作 `visible` 的旧辅助函数删掉，统一走 `_transition_ui_state()`。

#### Step 4：确保 `continue_from_save` 后正确触发信号
在 `run_controller.gd` 的 `_change_state(RUNNING_NODE_SELECT)` 中：

```gdscript
RunState.RUNNING_NODE_SELECT:
    _generate_node_options()
    # 普通层：发射 node_options_presented
    # 救援层：发射 panel_opened(RESCUE_PANEL)
    # PVP层：发射 node_options_presented（只有1个选项）
    # 终局层：发射 node_options_presented（只有1个选项）
    EventBus.emit_signal("floor_changed", _run.current_turn, _MAX_TURNS, _get_phase_name())
```

注意：`_generate_node_options()` 内部已经发射了 `node_options_presented` 或 `panel_opened`，所以 `_change_state` 里不要再重复发射。

---

## 六、文件修改清单

| # | 文件 | 修改内容 | 验证方法 |
|:---:|:---|:---|:---|
| 1 | `scripts/data/run_snapshot.gd` | **新建** 纯数据类，统一存档格式 | 编译无报错 |
| 2 | `scripts/core/character_manager.gd` | 添加 `load_hero_from_snapshot()` 公共接口 | 继续游戏后英雄属性正确 |
| 3 | `autoload/save_manager.gd` | 用 `RunSnapshot` 统一读写 | `has_active_run()` 能正确识别无效存档 |
| 4 | `scripts/systems/run_controller.gd` | 1. 引入 `SpecialFloorPhase` 子状态机<br>2. 重写 `_generate_node_options` 救援层流程<br>3. 重写 `continue_from_save` 用 RunSnapshot<br>4. 删除 `_character_manager._hero = _hero` 直接赋值 | 1. 第5层只显示救援面板<br>2. 救援后自动进商店<br>3. 继续游戏层数正确 |
| 5 | `scripts/systems/node_pool_system.gd` | `_generate_rescue_options` 只返回救援选项 | 救援层不显示商店选项按钮 |
| 6 | `scenes/run_main/run_main.gd` | 1. 引入 `UISceneState` 枚举<br>2. 实现 `_transition_ui_state()`<br>3. 重写所有回调走状态机<br>4. 删除直接操作 visible 的旧代码 | 1. 选项按钮始终可见<br>2. 面板切换不闪屏<br>3. 训练/救援/选项互不干扰 |
| 7 | `scenes/run_main/run_main.tscn` | 如需要，添加 ShopPanel 节点 | 商店面板能显示（后续实现） |
| 8 | `scripts/systems/shop_system.gd` | 添加 `generate_items()` 接口 | 救援层商店有商品 |

---

## 七、验收标准

### Bug 1 验收
- [ ] 第5层进入后，**不显示**4个选项按钮，而是直接显示救援面板（3个候选伙伴）
- [ ] 选择伙伴后，救援面板关闭，**自动显示**商店面板
- [ ] 商店操作完成后（或关闭后），自动推进到第6层，显示正常的4个选项
- [ ] 第15层、第25层重复上述流程

### Bug 2 验收
- [ ] 玩几层后退出到主菜单，主菜单有"继续游戏"按钮
- [ ] 点击"继续游戏"，进入游戏后显示的**是当前层**（不是第30层）
- [ ] 继续游戏后，左侧英雄属性面板显示**正确的数值**（不是0或默认值）
- [ ] 继续游戏后，HP显示正确
- [ ] 控制台有 `[RunController] 存档恢复完成，当前层=X` 且 X 正确

### Bug 3 验收
- [ ] 新开局：第1层正常显示4个选项按钮
- [ ] 点击"训练"：显示训练面板，4选项按钮隐藏
- [ ] 选择属性训练完成后：自动回到4选项按钮
- [ ] 继续游戏后：当前层正常显示4选项按钮
- [ ] 从暂停菜单返回游戏：4选项按钮仍然可见
- [ ] 任何操作后按钮不会变成 "..." 或全部消失

### 解耦验收
- [ ] `run_main.gd` 中**没有**任何直接设置 `xxx.visible = true/false` 的代码（`_transition_ui_state` 除外）
- [ ] `run_controller.gd` 中**没有** `_character_manager._hero = xxx` 的直接字段赋值
- [ ] 存档字段命名统一为 `current_floor`（不再混用 `current_turn`）

---

## 八、调试输出要求

以下 `print()` 语句**必须保留**，用于验证修复：

```gdscript
# run_controller.gd
"[RunController] 恢复存档, floor=X"
"[RunController] 存档解析: floor=X, hero_id=Y, gold=Z"
"[RunController] 英雄恢复: VIT=A STR=B AGI=C TEC=D MND=E HP=F/G"
"[RunController] 存档恢复完成，当前层=X"
"[RunController] 特殊层阶段: RESCUE_SELECT"
"[RunController] 特殊层阶段: SHOP_BROWSE"
"[RunController] 生成节点选项: 层=X, 类型=Y"

# run_main.gd
"[RunMain] UI状态: OLD → NEW"
"[RunMain] 检测到待恢复存档"
"[RunMain] _on_node_options_presented: 选项数=X"
"[RunMain] _on_panel_opened: 面板=X"
```

---

## 九、禁止事项

1. **禁止**在 `run_main.gd` 的任何回调里直接写 `option_container.visible = true/false`，必须走 `_transition_ui_state()`
2. **禁止**在 `run_controller.gd` 里直接访问 `_character_manager._xxx` 私有字段，必须走公共接口
3. **禁止**在存档逻辑里混用 `current_floor` 和 `current_turn`，统一用 `current_floor`
4. **禁止**在救援层生成"商店"选项按钮让玩家二选一
5. **禁止**在救援选择后直接 `advance_turn()`，必须先经过商店阶段
