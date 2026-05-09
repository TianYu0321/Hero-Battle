# Bug #004: RunMain UI 与 RunController 连接链路断裂

**发现时间**: 2026-05-09  
**发现方式**: 代码审查（Phase 1 遗留架构缺口排查）  
**影响范围**: `scenes/run_main/run_main.gd`、`scenes/run_main/run_main.tscn`、`autoload/game_manager.gd`  
**严重级别**: 🔴 阻断性 — 养成循环主场景完全无法运行

---

## 问题描述

RunMain 场景（养成循环主UI）与 RunController（养成循环主控器）之间存在多条连接链路断裂，导致整个养成循环流程无法启动和交互。

### 问题1: RunMain 未订阅 `node_options_presented` 信号

- **表现**: 每回合开始时，UI 不显示任何节点选项，3个按钮保持默认文本（"节点 1/2/3"）
- **代码**: `run_main.gd` 的 `_ready()` 中没有 `EventBus.node_options_presented.connect(...)`
- **影响**: 用户看不到当前回合可选的节点内容

### 问题2: `_on_node_button_pressed()` 为空实现

- **表现**: 点击任意节点按钮无任何反应
- **代码**: `_on_node_button_pressed(_index: int) -> void: pass`
- **影响**: 用户无法选择节点，RunController 永远收不到 `select_node()` 调用

### 问题3: EventBus 缺少 `node_selected` 信号（已被 Bug #003 覆盖）

- **表现**: RunController.select_node() 中 `EventBus.emit_signal("node_selected", node_index)` 会失败
- **根因**: `node_selected` 信号被重复声明（Bug #003），Godot 编译时会报错
- **状态**: 与 Bug #003 一并修复

### 问题4: run_main.tscn 中存在无脚本的空 RunController 节点

- **表现**: 场景文件末尾有 `[node name="RunController" type="Node" parent="."]` 但无 `script` 属性
- **影响**: 该节点没有任何功能，造成误导

### 问题5: GameManager → RunMain 数据传递链路断裂

- **表现**: 从酒馆确认队伍后切换到 RunMain 场景，但 RunController 没有被启动
- **代码分析**:
  - `GameManager._on_team_confirmed()` 正确保存了 `selected_hero_config_id` 和 `selected_partner_config_ids`
  - `GameManager.change_scene("RUNNING")` 正确切换场景到 `run_main.tscn`
  - 但 `run_main.gd` 的 `_ready()` **没有**读取 GameManager 数据，也没有实例化/启动 RunController
- **影响**: 场景切换后 RunController 不运行，没有任何回合推进、节点生成或状态更新

### 问题6: `run_main.tscn` 文件格式导致 Godot 解析失败

- **表现**: 酒馆点击确认后场景切换失败，报错 `Parse Error: Parse error. [Resource file res://scenes/run_main/run_main.tscn:257]`
- **根因分析（3个子问题）**:
  1. **`load_steps=2` 与实际资源数不匹配**: 文件头声明 `load_steps=2`，但场景中只有1个 `[ext_resource]`。Godot 解析器在扫描完整文件后仍找不到第2个资源声明，在文件末尾（不存在的第257行）报错
  2. **删除空 RunController 节点后残留末尾空行**: 使用文本编辑删除节点时，导致文件末尾多出 `\n\n`。Godot tscn 解析器对文件末尾的额外空行敏感，将其视为无效内容
  3. **`AttrLabel4` 文本属性损坏**: `text = "技�?` 缺少闭合引号且"巧"字编码损坏，导致 Godot 字符串解析器读到该行时认为字符串未结束，后续所有内容被错误解析为字符串的一部分
- **影响**: 整个 `run_main.tscn` 无法被 Godot 加载，养成循环主场景完全进不去
- **备注**: 经排查，项目中 **所有** `.tscn` 场景文件均存在 `load_steps` 与 `ext_resource` 数量不匹配的问题（`load_steps=2` 但 `ext_count=1`），但其他场景此前未被动态加载触发报错。`run_main.tscn` 因同时存在末尾空行和中文引号损坏问题，导致 Godot 解析器在此处暴露错误。

- **表现**: 从酒馆确认队伍后切换到 RunMain 场景，但 RunController 没有被启动
- **代码分析**:
  - `GameManager._on_team_confirmed()` 正确保存了 `selected_hero_config_id` 和 `selected_partner_config_ids`
  - `GameManager.change_scene("RUNNING")` 正确切换场景到 `run_main.tscn`
  - 但 `run_main.gd` 的 `_ready()` **没有**读取 GameManager 数据，也没有实例化/启动 RunController
- **影响**: 场景切换后 RunController 不运行，没有任何回合推进、节点生成或状态更新

---

## 修复措施

### 修复1: 重写 `run_main.gd`

1. **在 `_ready()` 中动态实例化 RunController**：
   ```gdscript
   _run_controller = RunController.new()
   _run_controller.name = "RunController"
   add_child(_run_controller)
   ```

2. **读取 GameManager 选择数据并启动新局**：
   ```gdscript
   var hero_config_id: int = GameManager.selected_hero_config_id
   var partner_config_ids: Array[int] = GameManager.selected_partner_config_ids.duplicate()
   _run_controller.start_new_run(hero_config_id, partner_config_ids)
   ```

3. **订阅 `node_options_presented` 信号**：
   ```gdscript
   EventBus.node_options_presented.connect(_on_node_options_presented)
   ```

4. **实现 `_on_node_options_presented()`**：
   - 遍历 `node_options` 数组，为每个可用按钮设置 `node_name` + `description`
   - 超出选项数量的按钮设为 `visible = false`
   - PVP/终局等固定节点可能只有1个选项

5. **实现 `_on_node_button_pressed()`**：
   ```gdscript
   EventBus.node_selected.emit(index)
   ```

6. **新增 `turn_advanced` 信号订阅**：
   - 回合推进时清空按钮文本并禁用，防止用户在选项到来前误触

### 修复2: 修复 `run_main.tscn` 文件格式

1. **删除**场景文件末尾无脚本的 `[node name="RunController" type="Node" parent="."]` 节点行
2. **修正** `load_steps`：`[gd_scene load_steps=2 format=3]` → `[gd_scene load_steps=1 format=3]`
3. **删除**文件末尾多余的空行，确保以最后一个属性行（`vertical_alignment = 1`） cleanly 结束
4. **修复** `AttrLabel4` 的文本属性：`text = "技�?` → `text = "技巧"`

**教训**: 手动编辑 `.tscn` 文本文件时必须注意 `load_steps` 值与 `[ext_resource]`/`[sub_resource]` 实际数量严格匹配，且文件末尾不应有额外空行。Godot 编辑器保存时会自动维护这些格式，绕过编辑器直接改文件容易引入此类问题。

---

## 验证清单

- [ ] Godot 编译通过（无重复信号错误）
- [ ] 从 HeroSelect → Tavern → RunMain 流程可正常切换
- [ ] RunMain _ready() 成功读取 GameManager 数据并启动 RunController
- [ ] 回合1开始时，3个按钮显示正确的节点选项（训练/战斗/商店等）
- [ ] 点击按钮后，RunController 正确进入 RUNNING_NODE_EXECUTE 状态
- [ ] PVP回合（第10、20回）只显示1个"PVP检定"按钮
- [ ] 救援回合（第5、15、25回）显示3个候选伙伴按钮
- [ ] 回合推进后按钮重置为等待状态

---

## 相关文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `autoload/event_bus.gd` | 修改 | 删除重复的 `node_selected`（Bug #003） |
| `scenes/run_main/run_main.gd` | 重写 | 添加 RunController 启动 + 信号订阅 + 回调实现 |
| `scenes/run_main/run_main.tscn` | 修改 | 删除空 RunController 节点 + 修正 `load_steps=1` + 删除末尾多余空行 |
