# 任务卡：菜单按钮 + 继续游戏修复（详细版）

> 优先级：P1（功能缺失）
> 代码端：请严格按以下根因分析和步骤执行，不要自行推测其他方案

---

## Bug 1：菜单按钮点不了（主菜单 + 游戏内菜单）

### 根因分析（必须按此修复）

在 Godot 4.x 的 UI 系统中，`layout_mode` 决定了 Control 节点的定位方式：
- `layout_mode = 0` → 绝对定位（OFFSET模式），通过 `offset_left/top/right/bottom` 像素值定位
- `layout_mode = 1` → 锚点模式（ANCHOR模式），通过 `anchor_*` 比例定位
- `layout_mode = 3` → 容器模式（Container会强制子节点用此模式）

**关键问题**：当父节点使用 `layout_mode = 3`（例如 `VBoxContainer`、`HBoxContainer`、`PanelContainer` 等容器节点）时，如果子节点被手动设置为 `layout_mode = 0`，Godot 的布局系统会出现输入事件处理冲突——子节点的点击区域虽然视觉上在正确位置，但输入事件被父容器的布局系统拦截，导致按钮 `pressed` 信号不触发。

**修复必须满足的条件**：
1. 如果按钮的父节点是任何 Container 类型（VBoxContainer/HBoxContainer/PanelContainer/GridContainer/MarginContainer 等），按钮必须使用 `layout_mode = 1`
2. 使用 `anchors_preset = 1`（左上角定位），然后通过 `offset_*` 调整具体像素位置
3. 如果按钮必须放在非容器类型的 Control 下（如普通的 Control 或 CanvasLayer），才可以使用 `layout_mode = 0`

### 修复步骤

#### 步骤 1：检查当前场景结构

打开以下两个 tscn 文件，查看 MenuButton 的父节点类型：
- `scenes/main_menu/main_menu.tscn`
- `scenes/run_main/run_main.tscn`

**检查命令**：在 Godot 编辑器中选中 MenuButton，看父节点是什么类型。如果是 Container 子类，必须改 layout_mode。

#### 步骤 2：修正 MenuButton 的属性

将 MenuButton（或要添加的菜单按钮）的属性按以下方式设置：

```
[node name="MenuButton" type="Button" parent="."]
layout_mode = 1              # 必须改为1，不能用0
anchors_preset = 1           # Top-Left = 1
offset_left = 900.0
offset_top = 20.0
offset_right = 1000.0
offset_bottom = 60.0
text = "菜单"
```

**验证方法**：修改后运行场景，点击按钮，在 `_on_menu_button_pressed()` 里加一行 `print("按钮被点击了")`，看控制台是否有输出。如果没有输出，说明还是被拦截了。

#### 步骤 3：检查按钮是否被其他节点遮挡

如果改了 layout_mode 后仍然点不了：
1. 检查按钮的 `z_index` 是否被其他全屏半透明面板（如 ColorRect、Panel）盖住
2. 检查按钮是否在某个不可见但 `mouse_filter = 0`（PASS）或 `1`（STOP）的 Control 节点下面
3. **调试技巧**：给 MenuButton 添加一个独特的 `theme_override_colors/font_color = Color(1, 0, 0)`，运行时如果能看到红色文字但点不了，说明是渲染可见但输入被拦截；如果连红色文字都看不到，说明按钮被完全遮挡或没有正确实例化

#### 步骤 4：添加按钮回调代码

**文件：`scenes/main_menu/main_menu.gd`**

```gdscript
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
    # ... 现有代码 ...
    if menu_button:
        menu_button.pressed.connect(_on_menu_button_pressed)
        print("[MainMenu] MenuButton 已连接信号")
    else:
        push_error("[MainMenu] MenuButton 未找到")

func _on_menu_button_pressed() -> void:
    print("[MainMenu] 菜单按钮被点击")
    # 呼出暂停菜单（如果主菜单已有 PauseMenu 场景实例）
    if pause_menu and not pause_menu.visible:
        pause_menu.show_menu()
    else:
        push_warning("[MainMenu] PauseMenu 不可用或已显示")
```

**文件：`scenes/run_main/run_main.gd`**

```gdscript
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
    # ... 现有代码 ...
    if menu_button:
        menu_button.pressed.connect(_on_menu_button_pressed)
        print("[RunMain] MenuButton 已连接信号")
    else:
        push_error("[RunMain] MenuButton 未找到")

func _on_menu_button_pressed() -> void:
    print("[RunMain] 菜单按钮被点击")
    # 和 ESC 键一样的逻辑：呼出/收起暂停菜单
    if pause_menu:
        if pause_menu.visible:
            pause_menu.hide_menu()
        else:
            pause_menu.show_menu()
    else:
        push_error("[RunMain] pause_menu 未初始化")
```

**ESC 键处理也要保留**：
```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):  # ESC键
        if pause_menu:
            if pause_menu.visible:
                pause_menu.hide_menu()
            else:
                pause_menu.show_menu()
```

---

## Bug 2：继续游戏按钮逻辑错误

### 根因分析（必须按此修复）

目前问题有两个层面：

**问题 A：`has_active_run()` 只检查文件存在，不检查内容有效性**
- 当前实现很可能是 `return FileAccess.file_exists(file_path)`
- 这会导致：只要文件存在（即使是空文件、只有 `{}` 的文件、缺少关键字段的文件），就返回 `true`
- 结果：主菜单显示"继续游戏"按钮，但点击后加载不到有效数据，游戏无法启动或报错

**问题 B：点击"继续游戏"后如果存档无效，UI 状态不同步**
- 假设 `has_active_run()` 返回 true，按钮显示
- 用户点击按钮，`load_latest_run()` 返回 `{}` 或无效数据
- `run_main.gd` 的 `continue_from_save()` 收到无效数据，无法恢复状态
- 可能的表现：按钮消失了，但游戏场景没切换；或者切换到 RunMain 但一片空白

**修复必须满足的条件**：
1. `has_active_run()` 必须打开文件，验证 JSON 字典中包含 `hero_config_id`（或 `hero_id`）和 `current_floor` 两个字段，且 `current_floor > 0`
2. 主菜单的 `_ready()` 中调用 `has_active_run()` 控制按钮显隐
3. 从 RunMain 返回 MainMenu 时，MainMenu 必须重新检查存档状态（因为玩家可能刚删除存档或刚完成一局）

### 修复步骤

#### 步骤 1：增强存档有效性检查

**文件：`autoload/save_manager.gd`**

```gdscript
func has_active_run() -> bool:
    var file_path = SAVE_DIR + "latest_run.json"
    if not FileAccess.file_exists(file_path):
        return false
    
    var data = ModelsSerializer.load_json_file(file_path)
    if data == null or data.is_empty():
        return false
    
    # 必须包含这两个关键字段
    var has_hero = data.has("hero_config_id") or data.has("hero_id")
    var has_floor = data.has("current_floor") and data.get("current_floor", 0) > 0
    
    print("[SaveManager] 存档检查: has_hero=", has_hero, ", has_floor=", has_floor, ", floor=", data.get("current_floor", 0))
    return has_hero and has_floor
```

**关键说明**：`hero_config_id` 和 `hero_id` 都有可能被使用，取决于存档序列化时用的字段名。如果不确定，两个都检查。可以用 `or` 逻辑：
```gdscript
var has_hero = data.has("hero_config_id") or data.has("hero") or data.has("hero_id")
```

#### 步骤 2：主菜单控制继续游戏按钮

**文件：`scenes/main_menu/main_menu.gd`**

```gdscript
@onready var continue_button: Button = $ContinueButton  # 确保场景里有这个按钮

func _ready() -> void:
    # ... 现有代码 ...
    
    if continue_button:
        continue_button.pressed.connect(_on_continue_button_pressed)
        # 根据存档状态控制显隐
        var has_save = SaveManager.has_active_run()
        continue_button.visible = has_save
        print("[MainMenu] 继续游戏按钮显隐: ", has_save)
    else:
        push_error("[MainMenu] ContinueButton 未找到")

# 每次主菜单变成当前场景时都重新检查
func _enter_tree() -> void:
    if continue_button:
        var has_save = SaveManager.has_active_run()
        continue_button.visible = has_save
        print("[MainMenu] _enter_tree 重新检查存档: ", has_save)

func _on_continue_button_pressed() -> void:
    print("[MainMenu] 继续游戏按钮被点击")
    
    # 再次检查存档有效性（防御性编程）
    if not SaveManager.has_active_run():
        push_error("[MainMenu] 点击继续游戏但存档无效")
        continue_button.visible = false
        return
    
    var save_data = SaveManager.load_latest_run()
    if save_data == null or save_data.is_empty():
        push_error("[MainMenu] 存档加载失败")
        continue_button.visible = false
        return
    
    print("[MainMenu] 存档加载成功，current_floor=", save_data.get("current_floor", "???"))
    
    # 切换到 RunMain 场景并传入存档
    GameManager.continue_run(save_data)  # 如果 GameManager 有这个方法
    # 或者直接用：
    # var run_main = load("res://scenes/run_main/run_main.tscn").instantiate()
    # run_main.continue_from_save(save_data)
    # get_tree().change_scene_to_file("res://scenes/run_main/run_main.tscn")
```

**注意**：如果项目里有 `GameManager` autoload 负责场景切换，优先用它的方法；如果没有，再用 `get_tree().change_scene_to_file()`。

#### 步骤 3：RunMain 支持从存档继续

**文件：`scenes/run_main/run_main.gd`**

```gdscript
# 标记是否是从存档继续的模式
var _is_continuing: bool = false
var _continue_save_data: Dictionary = {}

func continue_from_save(save_data: Dictionary) -> void:
    print("[RunMain] 从存档继续, floor=", save_data.get("current_floor", "???"))
    _is_continuing = true
    _continue_save_data = save_data
    
    # 延迟到 _ready 后再恢复，确保所有 @onready 节点已初始化
    call_deferred("_do_continue_from_save")

func _do_continue_from_save() -> void:
    if _continue_save_data.is_empty():
        push_error("[RunMain] _do_continue_from_save 被调用但存档为空")
        return
    
    # 初始化 RunController 并恢复状态
    if _run_controller == null:
        _run_controller = RunController.new()
        add_child(_run_controller)
    
    _run_controller.continue_from_save(_continue_save_data)
    
    # 刷新UI
    _update_hud()
    _show_option_buttons()  # 或根据当前层类型显示对应UI
    
    print("[RunMain] 存档恢复完成")
```

**文件：`scripts/systems/run_controller.gd`**

```gdscript
func continue_from_save(save_data: Dictionary) -> void:
    print("[RunController] 恢复存档, floor=", save_data.get("current_floor", 0))
    
    # 1. 恢复 RuntimeRun
    if save_data.has("run"):
        _run = RuntimeRun.from_dict(save_data["run"])
    else:
        # 如果存档结构里没有 "run" 键，直接从 save_data 构造
        _run = RuntimeRun.new()
        _run.current_floor = save_data.get("current_floor", 1)
        _run.gold_owned = save_data.get("gold", 0)
        # ... 其他字段
    
    # 2. 恢复英雄
    var hero_data = save_data.get("hero", {})
    if not hero_data.is_empty() and _hero == null:
        _hero = RuntimeHero.from_dict(hero_data)
    
    # 3. 恢复伙伴列表
    var partners_data = save_data.get("partners", [])
    _partners.clear()
    for p_data in partners_data:
        var partner = RuntimePartner.from_dict(p_data)
        _partners.append(partner)
    
    # 4. 恢复状态机
    _state = RunState.RUNNING_NODE_SELECT
    
    # 5. 重新生成当前层的选项（确保4个按钮显示正确）
    _generate_node_options()
    
    # 6. 发信号通知UI更新
    EventBus.emit_signal("run_continued", _run.current_floor)
    print("[RunController] 存档恢复完成，当前层=", _run.current_floor)
```

#### 步骤 4：处理从暂停菜单返回主菜单后的状态刷新

**文件：`scenes/pause_menu/pause_menu.gd`**

当玩家点击"返回主菜单"时：

```gdscript
func _on_return_to_main_menu() -> void:
    # 先保存当前进度（如果有的话）
    if RunController and RunController.is_running():
        SaveManager.save_run(RunController.get_run_data())
    
    # 返回主菜单
    get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
    
    # 注意：change_scene_to_file 会自动释放当前场景并加载新场景
    # MainMenu._ready() 和 _enter_tree() 会重新检查存档状态
```

---

## 调试辅助（运行时必须能看到这些输出）

在每个关键函数开头加 `print()`，方便定位问题：

```gdscript
# main_menu.gd
func _ready():
    print("[MainMenu] _ready 开始, continue_button=", continue_button != null)

func _on_menu_button_pressed():
    print("[MainMenu] 菜单按钮点击")

func _on_continue_button_pressed():
    print("[MainMenu] 继续游戏点击, has_active_run=", SaveManager.has_active_run())

# save_manager.gd
func has_active_run():
    print("[SaveManager] has_active_run 被调用")
    # ... 逻辑 ...
    print("[SaveManager] 检查结果: ", result)
    return result

# run_main.gd
func continue_from_save(data):
    print("[RunMain] continue_from_save, keys=", data.keys())

# run_controller.gd
func continue_from_save(data):
    print("[RunController] continue_from_save, floor=", data.get("current_floor"))
```

---

## 文件修改清单

| # | 文件 | 修改内容 | 关键验证点 |
|:---:|:---|:---|:---|
| 1 | `scenes/main_menu/main_menu.tscn` | 添加 MenuButton，layout_mode=1 | 父节点如果是 Container，子按钮不能用 layout_mode=0 |
| 2 | `scenes/main_menu/main_menu.gd` | 菜单按钮回调 + 继续游戏逻辑 + _enter_tree 刷新 | 控制台有 `[MainMenu]` 开头的 print 输出 |
| 3 | `scenes/run_main/run_main.tscn` | 添加 MenuButton，layout_mode=1 | 按钮点击后控制台输出 `[RunMain] 菜单按钮被点击` |
| 4 | `scenes/run_main/run_main.gd` | 菜单按钮回调 + continue_from_save | 从存档继续后控制台输出 `[RunMain] 存档恢复完成` |
| 5 | `scripts/systems/run_controller.gd` | continue_from_save 方法 | 控制台输出 `[RunController] 存档恢复完成` |
| 6 | `autoload/save_manager.gd` | 增强 has_active_run() 检查内容有效性 | 控制台输出 `[SaveManager] 存档检查: has_hero=... has_floor=...` |
| 7 | `scenes/pause_menu/pause_menu.gd` | 返回主菜单时保存 + 切场景 | 返回主菜单后"继续游戏"按钮状态正确 |

---

## 验收标准

修复完成后必须逐项验证：

1. **主菜单菜单按钮**：运行游戏，主界面右上角有"菜单"按钮，点击后控制台输出 `[MainMenu] 菜单按钮被点击`
2. **游戏内菜单按钮**：开始一局游戏，右上角有"菜单"按钮，点击后弹出暂停菜单（和ESC效果一样），再次点击收起
3. **ESC仍然可用**：游戏内按ESC，能呼出暂停菜单；再按ESC或点击"返回游戏"，能收起
4. **继续游戏按钮显隐**：
   - 首次启动游戏（无存档）：主菜单**没有**"继续游戏"按钮
   - 玩了一层后退出到主菜单：主菜单**有**"继续游戏"按钮
   - 点击"继续游戏"后：进入游戏，显示的是退出时的那一层，4个选项正常显示
5. **存档有效性兜底**：手动删除存档文件内容只剩 `{}`，重启游戏，"继续游戏"按钮应该**不显示**

---

## 常见错误排查

**如果按钮还是点不了**：
1. 在 Godot 编辑器里运行场景，选中 MenuButton，看 Inspector 里的 `layout_mode` 是多少，必须不是 0
2. 检查父节点类型：如果父节点是 `VBoxContainer`/`HBoxContainer`/`GridContainer`/`PanelContainer`/`MarginContainer`，layout_mode 必须不是 0
3. 检查按钮的 `mouse_filter` 属性，必须是 `0 (PASS)` 或 `1 (STOP)`，不能是 `2 (IGNORE)`
4. 检查按钮上方是否有全屏的 ColorRect/Panel 且 mouse_filter 为 STOP，这会挡住按钮点击

**如果继续游戏按钮不显示/不隐藏**：
1. 看控制台是否有 `[SaveManager] 存档检查` 的输出，如果没有，说明 `has_active_run()` 没被调用
2. 检查 ContinueButton 的 `$` 引用路径是否正确（`$ContinueButton` 是否对应场景树中的实际节点名）
3. 检查 `_enter_tree()` 是否被触发（从 RunMain 切换回 MainMenu 时应该触发）

**如果从存档继续后游戏黑屏/空白**：
1. 看控制台是否有 `[RunMain] 从存档继续` 的输出，如果没有，说明 `continue_from_save()` 没被调用
2. 检查 `GameManager` 切场景时是否传了参数，Godot 的 `change_scene_to_file()` **不能传参数**，参数需要用 autoload 中转或在目标场景的 `_ready()` 后读取
