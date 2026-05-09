# Bug #005: 养成循环节点执行后无法推进（按钮点击无反应 + 回合卡住 + 信号时序）

**发现时间**: 2026-05-09  
**发现方式**: Godot headless 自动化测试（30回合全流程模拟）  
**影响范围**: `scenes/run_main/run_main.gd`、`scripts/systems/run_controller.gd`  
**严重级别**: 🔴 阻断性 — 养成循环完全无法交互和推进

---

## 问题描述

在修复 Bug #004（RunMain-RunController 连接链路断裂）后，RunMain 场景能正常加载、RunController 能启动、按钮能显示节点选项。但点击按钮后无任何反应，回合数不增加，游戏完全卡住。

通过30回合自动化测试追踪，发现三个相互关联的缺口：

### 问题1: `_on_node_button_pressed()` 为空实现

- **表现**: 点击任意节点按钮，RunController 收不到任何调用
- **代码**:
  ```gdscript
  func _on_node_button_pressed(_index: int) -> void:
      pass
  ```
- **根因**: Phase 1 实现时只完成了 UI 布局，未实现按钮回调逻辑

### 问题2: `advance_turn()` 没有任何调用方

- **表现**: 即使按钮能触发 `select_node()` → `_process_node_result()`，节点处理完毕后状态变为 `TURN_ADVANCE`，然后永远卡死在此状态
- **代码分析**:
  - `_process_node_result()` 最后调用 `_change_state(RunState.TURN_ADVANCE)`
  - `_change_state(TURN_ADVANCE)` 中 `match` 分支为空（`pass`）
  - `advance_turn()` 是公共方法，但全局搜索确认 **没有任何代码调用它**
- **根因**: Phase 1 的状态机只实现了节点选择和执行，遗漏了"回合推进"的触发逻辑。可能是设计时假设由 UI 层调用，但 UI 层也未实现

### 问题3: `_ready()` 信号订阅时序错误

- **表现**: 即使修复了问题1和问题2，首回合的按钮文本、回合标签、金币显示等都不会更新
- **代码分析**:
  ```gdscript
  func _ready() -> void:
      _run_controller = RunController.new()
      add_child(_run_controller)
      _run_controller.start_new_run(hero_id, partner_ids)  # ← 同步调用，立即发射信号
      # ...
      EventBus.node_options_presented.connect(_on_node_options_presented)  # ← 信号在此之后才连接
  ```
  - `start_new_run()` 同步执行 → `_change_state(RUNNING_NODE_SELECT)` → 发射 `node_options_presented`、`round_changed`、`run_started`
  - 但 RunMain 的 EventBus 连接写在 `start_new_run()` 之后，所有首回合信号全部丢失
- **根因**: 对 Godot `_ready()` 同步执行顺序和信号发射时序理解不足

---

## 修复措施

### 修复1: 实现按钮点击回调

`run_main.gd`:
```gdscript
func _on_node_button_pressed(index: int) -> void:
    if _run_controller != null:
        _run_controller.select_node(index)
    else:
        push_warning("[RunMain] RunController not available")
```

**设计决策**: 直接调用 `_run_controller.select_node(index)`，而非通过 `EventBus.node_selected.emit(index)`。原因：
- RunController 本身在 `select_node()` 中会发射 `EventBus.node_selected` 信号（用于 UI 反馈）
- 如果 RunController 同时订阅 `node_selected`，会造成递归死循环
- 直接调用是最简单、最可靠的方式

### 修复2: 节点处理完毕后自动推进回合

`run_controller.gd` `_process_node_result()` 末尾：
```gdscript
_node_pool_system.record_selection(_pending_node_type)
_change_state(RunState.TURN_ADVANCE)
advance_turn()  # ← 新增
```

**注意**: 此修复意味着商店/救援等需要 UI 交互的节点也会被自动跳过。当前 Phase 1/2 中商店购买面板和救援选择面板未完整实现，自动推进是合理的临时方案。

### 修复3: 调整 `_ready()` 执行顺序

`run_main.gd`:
```gdscript
func _ready() -> void:
    # 1. 先连接所有信号（必须在 RunController 启动前）
    for i in range(node_buttons.size()):
        node_buttons[i].pressed.connect(_on_node_button_pressed.bind(i))
    EventBus.gold_changed.connect(_on_gold_changed)
    EventBus.stats_changed.connect(_on_stats_changed)
    EventBus.pvp_result.connect(_on_pvp_result)
    EventBus.round_changed.connect(_on_round_changed)
    EventBus.node_options_presented.connect(_on_node_options_presented)
    EventBus.run_started.connect(_on_run_started)
    EventBus.turn_advanced.connect(_on_turn_advanced)
    
    # 2. 再启动 RunController
    _run_controller = RunController.new()
    add_child(_run_controller)
    _run_controller.start_new_run(hero_config_id, partner_config_ids)
```

---

## 验证结果

30回合 headless 自动化测试通过：

| 检查项 | 结果 |
|--------|------|
| 第1-4回合（训练/战斗/商店） | ✅ 正常推进 |
| 第5回合（救援） | ✅ 正常推进 |
| 第10回合（PVP检定） | ✅ 触发，惩罚正确应用 |
| 第15回合（救援） | ✅ 正常推进 |
| 第20回合（PVP检定） | ✅ 触发，惩罚正确应用 |
| 第21-29回合（精英战/商店/战斗） | ✅ 正常推进 |
| 第30回合（终局战） | ⚠️ BattleEngine 执行成功，见下方备注 |

---

## 备注：终局战后续状态缺口

`_execute_final_battle()` → `_settle()` 执行完毕后：
- `run_ended` 信号正常发射 → GameManager 切场景到 Settlement ✅
- 但 RunController 内部状态仍停留在 `FINAL_BATTLE(6)`，未变为 `SETTLEMENT(5)`
- **影响**: 对场景切换链路无影响，仅在需要读取 RunController 内部状态时可能不一致

---

## 相关文件变更

| 文件 | 变更 | 说明 |
|------|------|------|
| `scenes/run_main/run_main.gd` | 修改 | 按钮回调实现 + `_ready()` 时序调整 |
| `scripts/systems/run_controller.gd` | 修改 | `_process_node_result()` 末尾追加 `advance_turn()` |
