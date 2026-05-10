# 任务卡：菜单按钮 + 继续游戏修复

> 优先级：P1（功能缺失）

---

## Bug 1：菜单只有ESC能唤出，缺少UI按钮

### 问题描述
当前菜单只能通过ESC键唤出，游戏内和主界面没有可视化的菜单按钮。

### 修复方案

#### 文件1：`scenes/main_menu/main_menu.tscn`

在右上角添加**设置按钮**（齿轮图标或文字"设置"）：
```
MainMenu
├── ... (现有内容)
└── MenuButton (Button)
    ├── layout_mode = 0
    ├── offset_left = 900
    ├── offset_top = 20
    ├── offset_right = 1000
    ├── offset_bottom = 60
    └── text = "菜单" 或 "⚙"
```

#### 文件2：`scenes/main_menu/main_menu.gd`

添加菜单按钮点击处理：
```gdscript
@onready var menu_button: Button = $MenuButton  # 添加引用

func _ready() -> void:
    # ... 现有代码 ...
    menu_button.pressed.connect(_on_menu_button_pressed)

func _on_menu_button_pressed() -> void:
    # 打开设置菜单（复用PauseMenu或直接跳转）
    # 方案A：直接显示设置面板
    # 方案B：切换到设置场景
    pass
```

#### 文件3：`scenes/run_main/run_main.tscn`

在右上角添加**菜单按钮**：
```
RunMain
├── ... (现有内容)
└── MenuButton (Button)
    ├── layout_mode = 0
    ├── offset_left = 900
    ├── offset_top = 20
    ├── offset_right = 1000
    ├── offset_bottom = 60
    └── text = "菜单"
```

#### 文件4：`scenes/run_main/run_main.gd`

添加菜单按钮点击处理：
```gdscript
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
    # ... 现有代码 ...
    menu_button.pressed.connect(_on_menu_button_pressed)

func _on_menu_button_pressed() -> void:
    # 呼出暂停菜单（和ESC一样的逻辑）
    if pause_menu.visible:
        pause_menu.hide_menu()
    else:
        pause_menu.show_menu()
```

---

## Bug 2：退出至主界面后不能继续游戏

### 问题描述
从暂停菜单选择"返回主菜单"后，回到主界面，但没有"继续游戏"选项。

### 修复方案

#### 文件5：`scenes/main_menu/main_menu.tscn`

添加**继续游戏**按钮（在有存档时显示）：
```
MainMenu
├── ...
├── StartButton ("开始游戏")
├── ContinueButton ("继续游戏")  # 新增
└── SettingsButton ("设置")       # 新增
```

#### 文件6：`scenes/main_menu/main_menu.gd`

添加继续游戏逻辑：
```gdscript
@onready var continue_button: Button = $ContinueButton

func _ready() -> void:
    # ... 现有代码 ...
    continue_button.pressed.connect(_on_continue_button_pressed)
    
    # 检查是否有存档
    var has_save = SaveManager.has_active_run()
    continue_button.visible = has_save

func _on_continue_button_pressed() -> void:
    # 加载存档并继续游戏
    var save_data = SaveManager.load_latest_run()
    if save_data != null and not save_data.is_empty():
        # 切换到RunMain场景并传入存档数据
        var run_main_scene = load("res://scenes/run_main/run_main.tscn").instantiate()
        run_main_scene.continue_from_save(save_data)
        get_tree().current_scene.queue_free()
        get_tree().root.add_child(run_main_scene)
        get_tree().current_scene = run_main_scene
```

#### 文件7：`scenes/run_main/run_main.gd`

添加从存档继续的方法：
```gdscript
func continue_from_save(save_data: Dictionary) -> void:
    # 恢复RunController状态
    _run_controller = RunController.new()
    _run_controller.continue_from_save(save_data)
    add_child(_run_controller)
    
    # 恢复UI显示
    _update_hud()
    
    # 根据当前层类型显示对应UI
    var current_floor = save_data.get("current_floor", 1)
    var floor_type = save_data.get("floor_type", "normal")
    match floor_type:
        "normal":
            _show_option_buttons()
        "rescue":
            _show_rescue_panel(save_data.get("candidates", []))
        # ... 其他类型
```

#### 文件8：`scripts/systems/run_controller.gd`

添加从存档恢复的方法：
```gdscript
func continue_from_save(save_data: Dictionary) -> void:
    # 恢复RuntimeRun
    _run = RuntimeRun.from_dict(save_data)
    
    # 恢复英雄
    var hero_data = save_data.get("hero", {})
    _hero = RuntimeHero.from_dict(hero_data)
    
    # 恢复伙伴
    var partner_data = save_data.get("partners", [])
    for p_data in partner_data:
        var partner = RuntimePartner.from_dict(p_data)
        _partners.append(partner)
    
    # 恢复金币
    _run.gold_owned = save_data.get("gold", 0)
    
    # 恢复状态
    _state = RunState.RUNNING_NODE_SELECT
    
    # 生成当前层选项
    _generate_node_options()
    
    # 发送信号
    EventBus.emit_signal("run_continued", _run.current_floor)
```

#### 文件9：`autoload/save_manager.gd`

添加检查是否有存档的方法（如果不存在）：
```gdscript
func has_active_run() -> bool:
    var file_path = SAVE_DIR + "latest_run.json"
    return FileAccess.file_exists(file_path)

func load_latest_run() -> Dictionary:
    var file_path = SAVE_DIR + "latest_run.json"
    if not FileAccess.file_exists(file_path):
        return {}
    return ModelsSerializer.load_json_file(file_path)
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/main_menu/main_menu.tscn` | 添加MenuButton + ContinueButton + SettingsButton |
| 2 | `scenes/main_menu/main_menu.gd` | 菜单按钮回调 + 继续游戏逻辑 |
| 3 | `scenes/run_main/run_main.tscn` | 添加MenuButton |
| 4 | `scenes/run_main/run_main.gd` | 菜单按钮回调 + continue_from_save方法 |
| 5 | `scripts/systems/run_controller.gd` | continue_from_save方法 |
| 6 | `autoload/save_manager.gd` | has_active_run() + load_latest_run()（如缺失） |
| 7 | `autoload/event_bus.gd` | 添加run_continued信号（如缺失） |

---

## 验收标准

- [ ] 主界面有"菜单"按钮，点击可打开设置
- [ ] 游戏内有"菜单"按钮（右上角），点击呼出暂停菜单
- [ ] ESC键仍然可以呼出暂停菜单
- [ ] 暂停菜单有：音量调节、全屏切换、返回游戏、返回主菜单
- [ ] 主界面在有存档时显示"继续游戏"按钮
- [ ] 点击"继续游戏"加载最新存档，恢复到对应层
- [ ] 从暂停菜单返回主菜单后，可以重新点击"继续游戏"恢复
