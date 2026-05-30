# 任务卡：存档管理UI与多槽位系统

## 参考来源

1. **hi-godot/save-system-godot-claude** — Save slots UI：4槽位 + 时间戳 + 游玩时长 + 每行 Save/Load/Delete 按钮，career stats footer
2. **VidyaGameMaka/GameBase_Godot4** — Save/Load/Delete 3槽位示例菜单，含音频/分辨率设置
3. **Cwoolf91/GodotSaveEngine** — SaveService：NewSlot/DeleteSlot/SaveGame/LoadGame/GetSlots，文件哈希校验

---

## 核心规则

| 规则 | 说明 |
|------|------|
| **槽位数量** | 3个槽位（Slot 1/2/3） |
| **文件命名** | `run_001.save` / `run_002.save` / `run_003.save`（加密格式，与现有一致） |
| **元数据** | `save_slots.save` 存储槽位概要（主角名/层数/时间/是否自动保存） |
| **兼容迁移** | 检测到旧版 `run.save` 时自动迁移到 Slot 1 |
| **入口** | 主菜单「存档管理」按钮；暂停菜单「保存进度」「保存并退出」 |
| **自动保存** | 仍写入当前活跃槽位（默认 Slot 1），不改变现有行为 |

---

## Step 0：SaveManager 扩展（多槽位接口）

在 `autoload/save_manager.gd` 中新增（保留原有接口不变）：

```gdscript
const MAX_SLOTS := 3
const SLOTS_META_FILE := "save_slots.save"

## ========== 槽位元数据 ==========

func _get_slot_file(slot_id: int) -> String:
    return "run_%03d.save" % slot_id

func _load_slots_meta() -> Dictionary:
    var data: Dictionary = _load_dict(SLOTS_META_FILE)
    if data.is_empty():
        ## 尝试迁移旧版单存档
        if FileAccess.file_exists(ConfigManager.SAVE_DIR + RUN_FILE):
            return _migrate_legacy_to_slots()
        return {"slots": [{}, {}, {}], "active_slot": 0}
    return data

func _save_slots_meta(meta: Dictionary) -> bool:
    return _save_dict(SLOTS_META_FILE, meta)

func _migrate_legacy_to_slots() -> Dictionary:
    ## 旧版 run.save → Slot 1
    var legacy_data: Dictionary = _load_dict(RUN_FILE)
    var slot1_file: String = _get_slot_file(1)
    var success := _write_encrypted(ConfigManager.SAVE_DIR + slot1_file, legacy_data)
    if not success:
        return {"slots": [{}, {}, {}], "active_slot": 0}
    
    var meta := {
        "slots": [
            _extract_slot_summary(legacy_data),
            {},
            {}
        ],
        "active_slot": 0
    }
    _save_slots_meta(meta)
    print("[SaveManager] 旧存档已迁移到 Slot 1")
    return meta

func _extract_slot_summary(run_data: Dictionary) -> Dictionary:
    var hero: Dictionary = run_data.get("hero", {})
    var hero_name: String = hero.get("name", "???")
    var floor: int = run_data.get("current_floor", 1)
    var is_auto: bool = run_data.get("is_auto_save", true)
    var timestamp: int = run_data.get("timestamp", 0)
    var play_time: int = run_data.get("play_time_seconds", 0)
    return {
        "has_data": true,
        "hero_name": hero_name,
        "floor": floor,
        "timestamp": timestamp,
        "is_auto_save": is_auto,
        "play_time_seconds": play_time,
    }

## ========== 公共接口 ==========

## 获取所有槽位信息（UI 用）
func get_all_slots_info() -> Array[Dictionary]:
    var meta: Dictionary = _load_slots_meta()
    var slots: Array = meta.get("slots", [{}, {}, {}])
    var result: Array[Dictionary] = []
    for i in range(MAX_SLOTS):
        var info: Dictionary = slots[i] if i < slots.size() else {}
        info["slot_id"] = i + 1
        info["is_active"] = (meta.get("active_slot", 0) == i)
        if not info.has("has_data"):
            info["has_data"] = false
        result.append(info)
    return result

## 获取当前活跃槽位（1-3，0表示无）
func get_active_slot() -> int:
    var meta: Dictionary = _load_slots_meta()
    return meta.get("active_slot", 0)

## 保存到指定槽位
func save_to_slot(slot_id: int, run_data: Dictionary, is_auto: bool = false) -> bool:
    if slot_id < 1 or slot_id > MAX_SLOTS:
        push_error("[SaveManager] 槽位ID越界: %d" % slot_id)
        return false
    
    var file_name: String = _get_slot_file(slot_id)
    var data: Dictionary = run_data.duplicate(true)
    data["timestamp"] = Time.get_unix_time_from_system()
    data["is_auto_save"] = is_auto
    
    var success := _save_dict(file_name, data)
    if not success:
        return false
    
    ## 更新元数据
    var meta: Dictionary = _load_slots_meta()
    var slots: Array = meta.get("slots", [{}, {}, {}])
    while slots.size() < MAX_SLOTS:
        slots.append({})
    slots[slot_id - 1] = _extract_slot_summary(data)
    meta["slots"] = slots
    meta["active_slot"] = slot_id - 1
    _save_slots_meta(meta)
    
    EventBus.game_saved.emit(slot_id, data["timestamp"], data.get("current_floor", 0), is_auto)
    print("[SaveManager] 已保存到槽位 %d" % slot_id)
    return true

## 从指定槽位加载
func load_from_slot(slot_id: int) -> Dictionary:
    if slot_id < 1 or slot_id > MAX_SLOTS:
        return {}
    
    var file_name: String = _get_slot_file(slot_id)
    var data: Dictionary = _load_dict(file_name)
    if data.is_empty():
        return {}
    
    ## 更新活跃槽位标记
    var meta: Dictionary = _load_slots_meta()
    meta["active_slot"] = slot_id - 1
    _save_slots_meta(meta)
    
    EventBus.game_loaded.emit(data)
    return data

## 删除指定槽位
func delete_slot(slot_id: int) -> bool:
    if slot_id < 1 or slot_id > MAX_SLOTS:
        return false
    
    var file_name: String = _get_slot_file(slot_id)
    var file_path: String = ConfigManager.SAVE_DIR + file_name
    if FileAccess.file_exists(file_path):
        DirAccess.remove_absolute(file_path)
    
    ## 清理备份
    var backup_path: String = file_path + BACKUP_SUFFIX
    if FileAccess.file_exists(backup_path):
        DirAccess.remove_absolute(backup_path)
    
    ## 更新元数据
    var meta: Dictionary = _load_slots_meta()
    var slots: Array = meta.get("slots", [{}, {}, {}])
    while slots.size() < MAX_SLOTS:
        slots.append({})
    slots[slot_id - 1] = {}
    meta["slots"] = slots
    
    ## 如果删除的是活跃槽位，重置活跃标记
    if meta.get("active_slot", 0) == slot_id - 1:
        meta["active_slot"] = -1
    
    _save_slots_meta(meta)
    print("[SaveManager] 已删除槽位 %d" % slot_id)
    return true

## 检查槽位是否有存档
func slot_has_data(slot_id: int) -> bool:
    var file_name: String = _get_slot_file(slot_id)
    return FileAccess.file_exists(ConfigManager.SAVE_DIR + file_name)

## ========== 兼容旧接口 ==========

## 重写 save_run_state：保存到活跃槽位（兼容现有调用）
func save_run_state(run_data: Dictionary, is_auto: bool = true, slot_id: int = -1, _user_id: String = current_user_id) -> bool:
    if slot_id < 1:
        ## 使用活跃槽位，无活跃槽位则默认 Slot 1
        slot_id = get_active_slot() + 1
        if slot_id < 1:
            slot_id = 1
    return save_to_slot(slot_id, run_data, is_auto)

## 重写 load_latest_run：从活跃槽位加载（兼容现有调用）
func load_latest_run(_user_id: String = current_user_id) -> Dictionary:
    var active: int = get_active_slot()
    if active >= 0:
        return load_from_slot(active + 1)
    ## 无活跃槽位，尝试 Slot 1
    if slot_has_data(1):
        return load_from_slot(1)
    return {}

## 重写 has_active_run：检查活跃槽位是否有数据（兼容现有调用）
func has_active_run(_user_id: String = current_user_id) -> bool:
    var active: int = get_active_slot()
    if active >= 0 and active < MAX_SLOTS:
        return slot_has_data(active + 1)
    ## 无活跃槽位，检查 Slot 1
    return slot_has_data(1)
```

---

## Step 1：存档管理UI场景（`save_manager_ui.tscn`）

### 节点结构

```
SaveManagerUI (Control, anchors_preset=15)
├── BackgroundLayer (CanvasLayer, layer=0)
│   └── ColorRect  # 半透明遮罩 Color(0,0,0,0.5)
├── MainPanel (PanelContainer)
│   ├── PanelStyle (StyleBoxFlat)
│   │   # 明亮纸片剧场：白底 + 浅灰边框 + 底部4px + 16px圆角 + 阴影
│   ├── VBoxContainer
│   │   ├── TitleLabel (Label)           # "存档管理"
│   │   ├── SubtitleLabel (Label)        # "选择槽位进行保存或读取"
│   │   ├── SlotGrid (HBoxContainer)     # 3个槽位卡片
│   │   │   └── SlotCard (PanelContainer, x3)
│   │   │       ├── SlotNumberLabel      # "槽位 1"
│   │   │       ├── HeroIcon (TextureRect) # 主角立绘占位 64x64
│   │   │       ├── InfoVBox
│   │   │       │   ├── HeroNameLabel    # "勇者"
│   │   │       │   ├── FloorLabel       # "第5层"
│   │   │       │   ├── TimeLabel        # "05-30 14:32"
│   │   │       │   └── AutoLabel        # "自动保存" / "手动保存"
│   │   │       └── ActionVBox
│   │   │           ├── SaveBtn          # "覆盖保存" / "新建存档"
│   │   │           ├── LoadBtn          # "读取"（有存档时）
│   │   │           └── DeleteBtn        # "删除"（有存档时）
│   │   └── BottomBar (HBoxContainer)
│   │       └── BackButton (Button)      # "返回"
└── ConfirmDialog (AcceptDialog)         # 覆盖/删除确认
```

### 核心代码

```gdscript
## scenes/save_manager/save_manager_ui.gd
extends Control

signal slot_loaded(slot_id: int)
signal back_requested

@onready var slot_grid: HBoxContainer = $MainPanel/VBoxContainer/SlotGrid
@onready var back_btn: Button = $MainPanel/VBoxContainer/BottomBar/BackButton
@onready var confirm_dialog: AcceptDialog = $ConfirmDialog

var _slot_cards: Array[PanelContainer] = []
var _slot_infos: Array[Dictionary] = []
var _pending_action: String = ""    # "overwrite" / "delete"
var _pending_slot: int = 0

func _ready() -> void:
    _setup_styles()
    _build_slot_cards()
    _refresh_slots()
    back_btn.pressed.connect(_on_back)

func _setup_styles() -> void:
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.98, 0.98, 0.96, 1.0)
    panel_style.border_color = Color(0.8, 0.8, 0.82, 1.0)
    panel_style.border_width_left = 1
    panel_style.border_width_top = 1
    panel_style.border_width_right = 1
    panel_style.border_width_bottom = 4
    panel_style.corner_radius_top_left = 16
    panel_style.corner_radius_top_right = 16
    panel_style.corner_radius_bottom_left = 16
    panel_style.corner_radius_bottom_right = 16
    panel_style.shadow_color = Color(0, 0, 0, 0.12)
    panel_style.shadow_size = 12
    panel_style.shadow_offset = Vector2(0, 4)
    $MainPanel.add_theme_stylebox_override("panel", panel_style)

func _build_slot_cards() -> void:
    for i in range(3):
        var card := _create_slot_card(i + 1)
        slot_grid.add_child(card)
        _slot_cards.append(card)

func _create_slot_card(slot_id: int) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(280, 320)
    card.name = "SlotCard%d" % slot_id
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
    style.border_color = Color(0.75, 0.75, 0.78, 1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 3
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = Color(0, 0, 0, 0.06)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0, 2)
    card.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 10)
    card.add_child(vbox)
    
    ## 槽位号
    var num_label := Label.new()
    num_label.name = "SlotNumber"
    num_label.text = "槽位 %d" % slot_id
    num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    num_label.add_theme_font_size_override("font_size", 18)
    num_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48, 1))
    vbox.add_child(num_label)
    
    ## 主角图标占位
    var icon := TextureRect.new()
    icon.name = "HeroIcon"
    icon.custom_minimum_size = Vector2(64, 64)
    icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    vbox.add_child(icon)
    
    ## 信息区
    var info_vbox := VBoxContainer.new()
    info_vbox.name = "InfoVBox"
    info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(info_vbox)
    
    var hero_name := Label.new()
    hero_name.name = "HeroName"
    hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_name.add_theme_font_size_override("font_size", 16)
    hero_name.add_theme_color_override("font_color", Color(0.25, 0.25, 0.28, 1))
    info_vbox.add_child(hero_name)
    
    var floor_label := Label.new()
    floor_label.name = "FloorLabel"
    floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    floor_label.add_theme_font_size_override("font_size", 13)
    floor_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 1))
    info_vbox.add_child(floor_label)
    
    var time_label := Label.new()
    time_label.name = "TimeLabel"
    time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    time_label.add_theme_font_size_override("font_size", 11)
    time_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.68, 1))
    info_vbox.add_child(time_label)
    
    var auto_label := Label.new()
    auto_label.name = "AutoLabel"
    auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    auto_label.add_theme_font_size_override("font_size", 11)
    info_vbox.add_child(auto_label)
    
    ## 操作按钮区
    var action_vbox := VBoxContainer.new()
    action_vbox.name = "ActionVBox"
    action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    action_vbox.add_theme_constant_override("separation", 6)
    vbox.add_child(action_vbox)
    
    var save_btn := Button.new()
    save_btn.name = "SaveBtn"
    save_btn.custom_minimum_size = Vector2(120, 36)
    save_btn.pressed.connect(_on_slot_save.bind(slot_id))
    action_vbox.add_child(save_btn)
    
    var load_btn := Button.new()
    load_btn.name = "LoadBtn"
    load_btn.text = "读取"
    load_btn.custom_minimum_size = Vector2(120, 36)
    load_btn.visible = false
    load_btn.pressed.connect(_on_slot_load.bind(slot_id))
    action_vbox.add_child(load_btn)
    
    var delete_btn := Button.new()
    delete_btn.name = "DeleteBtn"
    delete_btn.text = "删除"
    delete_btn.custom_minimum_size = Vector2(120, 36)
    delete_btn.visible = false
    delete_btn.pressed.connect(_on_slot_delete.bind(slot_id))
    action_vbox.add_child(delete_btn)
    
    return card

func _refresh_slots() -> void:
    _slot_infos = SaveManager.get_all_slots_info()
    
    for i in range(3):
        var info: Dictionary = _slot_infos[i]
        var card: PanelContainer = _slot_cards[i]
        var has_data: bool = info.get("has_data", false)
        
        var hero_name: Label = card.get_node("VBoxContainer/InfoVBox/HeroName")
        var floor_label: Label = card.get_node("VBoxContainer/InfoVBox/FloorLabel")
        var time_label: Label = card.get_node("VBoxContainer/InfoVBox/TimeLabel")
        var auto_label: Label = card.get_node("VBoxContainer/InfoVBox/AutoLabel")
        var save_btn: Button = card.get_node("VBoxContainer/ActionVBox/SaveBtn")
        var load_btn: Button = card.get_node("VBoxContainer/ActionVBox/LoadBtn")
        var delete_btn: Button = card.get_node("VBoxContainer/ActionVBox/DeleteBtn")
        
        ## 高亮活跃槽位
        var is_active: bool = info.get("is_active", false)
        var card_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
        if is_active:
            card_style.border_color = Color(0.25, 0.55, 0.9, 0.6)
            card_style.border_width_bottom = 4
        card.add_theme_stylebox_override("panel", card_style)
        
        if has_data:
            hero_name.text = info.get("hero_name", "???")
            floor_label.text = "第%d层" % info.get("floor", 1)
            
            var timestamp: int = info.get("timestamp", 0)
            if timestamp > 0:
                var dt := Time.get_datetime_dict_from_unix_time(timestamp)
                time_label.text = "%02d-%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
            else:
                time_label.text = "未知时间"
            
            if info.get("is_auto_save", false):
                auto_label.text = "自动保存"
                auto_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 1))
            else:
                auto_label.text = "手动保存"
                auto_label.add_theme_color_override("font_color", Color(0.25, 0.55, 0.9, 1))
            
            ## 按钮
            save_btn.text = "覆盖保存"
            _apply_button_style(save_btn, true)
            load_btn.visible = true
            _apply_button_style(load_btn, true)
            delete_btn.visible = true
            _apply_button_style(delete_btn, false)
        else:
            hero_name.text = ""
            floor_label.text = ""
            time_label.text = ""
            auto_label.text = ""
            
            save_btn.text = "新建存档"
            _apply_button_style(save_btn, true)
            load_btn.visible = false
            delete_btn.visible = false

func _apply_button_style(btn: Button, primary: bool) -> void:
    var style := StyleBoxFlat.new()
    if primary:
        style.bg_color = Color(0.25, 0.55, 0.9, 1.0)
    else:
        style.bg_color = Color(0.92, 0.92, 0.94, 1.0)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_color_override("font_color", Color.WHITE if primary else Color(0.35, 0.35, 0.38, 1))

## ========== 槽位操作 ==========

func _on_slot_save(slot_id: int) -> void:
    if SaveManager.slot_has_data(slot_id):
        ## 覆盖确认
        _pending_action = "overwrite"
        _pending_slot = slot_id
        confirm_dialog.title = "覆盖存档"
        confirm_dialog.dialog_text = "槽位 %d 已有存档，确定要覆盖吗？" % slot_id
        confirm_dialog.ok_button_text = "覆盖"
        confirm_dialog.cancel_button_text = "取消"
        if not confirm_dialog.confirmed.is_connected(_on_confirm_action):
            confirm_dialog.confirmed.connect(_on_confirm_action, CONNECT_ONE_SHOT)
        confirm_dialog.popup_centered()
    else:
        ## 新建存档：需要当前RUN数据
        _perform_save(slot_id)

func _on_slot_load(slot_id: int) -> void:
    var data: Dictionary = SaveManager.load_from_slot(slot_id)
    if not data.is_empty():
        print("[SaveManagerUI] 从槽位 %d 加载存档" % slot_id)
        slot_loaded.emit(slot_id)
        ## 跳转到爬塔场景继续游戏
        GameManager.pending_save_data = data
        TransitionManager.switch_scene("res://scenes/run_main/run_main.tscn", "fade")
    else:
        push_error("[SaveManagerUI] 槽位 %d 加载失败" % slot_id)

func _on_slot_delete(slot_id: int) -> void:
    _pending_action = "delete"
    _pending_slot = slot_id
    confirm_dialog.title = "删除存档"
    confirm_dialog.dialog_text = "确定要删除槽位 %d 的存档吗？此操作不可恢复。" % slot_id
    confirm_dialog.ok_button_text = "删除"
    confirm_dialog.cancel_button_text = "取消"
    if not confirm_dialog.confirmed.is_connected(_on_confirm_action):
        confirm_dialog.confirmed.connect(_on_confirm_action, CONNECT_ONE_SHOT)
    confirm_dialog.popup_centered()

func _on_confirm_action() -> void:
    match _pending_action:
        "overwrite":
            _perform_save(_pending_slot)
        "delete":
            SaveManager.delete_slot(_pending_slot)
            _refresh_slots()
            AudioManager.play_ui("cancel")
    _pending_action = ""

func _perform_save(slot_id: int) -> void:
    ## 获取当前RUN数据（从 RunController 或 GameManager）
    var run_data: Dictionary = {}
    var run_controller = get_tree().root.get_node_or_null("RunMain/RunController")
    if run_controller != null and run_controller.has_method("get_run_data"):
        run_data = run_controller.get_run_data()
    else:
        ## 尝试从 GameManager 获取
        run_data = GameManager.pending_save_data.duplicate() if not GameManager.pending_save_data.is_empty() else {}
    
    if run_data.is_empty():
        push_warning("[SaveManagerUI] 没有可保存的RUN数据")
        return
    
    SaveManager.save_to_slot(slot_id, run_data, false)  ## 手动保存
    _refresh_slots()
    AudioManager.play_ui("success")
    
    ## 保存成功提示
    _show_toast("已保存到槽位 %d" % slot_id)

func _show_toast(text: String) -> void:
    var panel := PanelContainer.new()
    panel.z_index = 300
    panel.position = Vector2(440, 260)
    panel.custom_minimum_size = Vector2(240, 60)
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.3, 0.7, 0.4, 0.95)
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    panel.add_theme_stylebox_override("panel", style)
    
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(label)
    
    add_child(panel)
    
    var tween := create_tween()
    tween.tween_property(panel, "modulate:a", 0.0, 0.8).set_delay(0.5)
    tween.finished.connect(func(): panel.queue_free())

func _on_back() -> void:
    AudioManager.play_ui("cancel")
    back_requested.emit()
    queue_free()
```

---

## Step 2：主菜单入口

```gdscript
## menu.gd — 修改 "继续游戏" 逻辑和新增 "存档管理" 按钮

## 在 _setup_menu_buttons() 中：
## 原有：继续游戏 / 新游戏 / 退出
## 修改后：新游戏 / 存档管理 / 设置 / 退出

func _setup_menu_buttons() -> void:
    ## ... 原有按钮收集 ...
    
    ## "继续游戏" 改为智能判断：
    ## 如果有活跃存档，保留"继续游戏"（直接跳转到活跃槽位的RUN）
    ## 否则移除"继续游戏"，玩家通过"存档管理"选择
    
    var has_active: bool = SaveManager.has_active_run()
    if not has_active and _btn_continue != null:
        ## 无活跃存档，移除继续游戏按钮
        var wrapper = _btn_continue.get_parent()
        wrapper.get_parent().remove_child(wrapper)
        wrapper.queue_free()
        _menu_buttons.erase(_btn_continue)
        _btn_continue = null
    
    ## 新增"存档管理"按钮（在 IconBar 或 MenuButtons 中）
    var btn_save_manager: BaseButton = get_node_or_null("UILayer/IconBar/BtnSaveManagerWrapper/BtnSaveManager")
    if btn_save_manager != null:
        btn_save_manager.visible = true
        btn_save_manager.disabled = false
        _connect_with_bounce(btn_save_manager, _on_save_manager_pressed)
        _menu_buttons.append(btn_save_manager)

func _on_continue_pressed() -> void:
    ## 原有逻辑不变，但改为通过存档管理加载
    if SaveManager.has_active_run():
        var slot_id: int = SaveManager.get_active_slot() + 1
        var data: Dictionary = SaveManager.load_latest_run()
        if not data.is_empty():
            GameManager.pending_save_data = data
            EventBus.continue_game_requested.emit()

func _on_save_manager_pressed() -> void:
    print("[MainMenu] 【点击】存档管理")
    AudioManager.play_ui("confirm")
    
    var save_ui_scene = load("res://scenes/save_manager/save_manager_ui.tscn")
    if save_ui_scene == null:
        push_warning("[MainMenu] 存档管理UI场景未找到")
        return
    
    var save_ui = save_ui_scene.instantiate()
    save_ui.back_requested.connect(func():
        save_ui.queue_free()
        ## 重新检查继续游戏按钮状态
        _refresh_continue_button()
    )
    add_child(save_ui)

func _refresh_continue_button() -> void:
    ## 存档管理返回后，检查是否需要显示/隐藏继续游戏按钮
    var has_active: bool = SaveManager.has_active_run()
    if has_active and _btn_continue == null:
        ## 需要恢复继续游戏按钮（简化处理：直接刷新菜单）
        pass
```

---

## Step 3：暂停菜单扩展

```gdscript
## scenes/menu/pause_menu.gd — 增加保存相关按钮

## 在 Panel/VBoxContainer 中，MainMenuButton 之前添加：

@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var save_and_quit_button: Button = $Panel/VBoxContainer/SaveAndQuitButton

func _ready() -> void:
    ## ... 原有连接 ...
    
    save_button.pressed.connect(_on_save)
    save_and_quit_button.pressed.connect(_on_save_and_quit)
    
    ## 设置按钮样式（与 ResumeButton 一致）
    _setup_button_style(save_button)
    _setup_button_style(save_and_quit_button)

func _setup_button_style(btn: Button) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.25, 0.55, 0.9, 1.0)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_color_override("font_color", Color.WHITE)

func _on_save() -> void:
    ## 保存到当前活跃槽位
    var active_slot: int = SaveManager.get_active_slot()
    if active_slot < 0:
        active_slot = 0  ## 默认 Slot 1
    
    ## 获取RUN数据
    var run_controller = get_tree().root.get_node_or_null("RunMain/RunController")
    if run_controller == null:
        push_warning("[PauseMenu] 无法找到 RunController，保存失败")
        return
    
    var run_data: Dictionary = run_controller.get_run_data() if run_controller.has_method("get_run_data") else {}
    if run_data.is_empty():
        push_warning("[PauseMenu] 没有可保存的RUN数据")
        return
    
    SaveManager.save_to_slot(active_slot + 1, run_data, false)
    AudioManager.play_ui("success")
    
    ## 显示保存成功提示（在原 save_button 位置临时替换文本）
    var original_text: String = save_button.text
    save_button.text = "已保存 ✓"
    await get_tree().create_timer(1.5).timeout
    save_button.text = original_text

func _on_save_and_quit() -> void:
    ## 先保存
    _on_save()
    ## 再返回主菜单
    _on_main_menu()
```

---

## Step 4：RunController 适配（如需）

确保 `RunController` 有 `get_run_data()` 方法返回当前RUN完整数据：

```gdscript
## scripts/systems/run_controller.gd — 添加公共接口

func get_run_data() -> Dictionary:
    ## 返回当前RUN的完整数据（用于存档）
    var data: Dictionary = {
        "hero": _hero_data.duplicate(true) if _hero_data != null else {},
        "partners": [],
        "current_floor": _current_floor,
        "gold": _gold,
        "turn": _current_turn,
        "play_time_seconds": _play_time_seconds,
        "run_status": _run_status,
        ## ... 其他需要持久化的字段
    }
    for p in _partners:
        data["partners"].append(p.to_dictionary())
    return data
```

---

## 测试验收标准

### SaveManager 多槽位
- [ ] `get_all_slots_info()` 返回3个槽位，空槽位 `has_data=false`
- [ ] 旧版 `run.save` 自动迁移到 Slot 1
- [ ] `save_to_slot(2, run_data)` 成功，元数据正确更新
- [ ] `load_from_slot(2)` 返回正确数据，活跃槽位标记更新
- [ ] `delete_slot(2)` 删除文件并清理元数据
- [ ] `save_run_state()` 仍兼容（保存到活跃槽位）
- [ ] `load_latest_run()` 仍兼容（从活跃槽位加载）
- [ ] `has_active_run()` 仍兼容

### 存档管理UI
- [ ] 主菜单有「存档管理」按钮
- [ ] 存档管理界面弹出时显示3个槽位卡片
- [ ] 空槽位显示「新建存档」按钮，无读取/删除按钮
- [ ] 有存档槽位显示：主角名/层数/时间/自动或手动保存标记
- [ ] 有存档槽位显示「覆盖保存」「读取」「删除」按钮
- [ ] 活跃槽位边框蓝色高亮
- [ ] 覆盖保存时弹出确认对话框
- [ ] 删除时弹出确认对话框（不可恢复警告）
- [ ] 新建/覆盖保存成功后显示绿色「已保存到槽位 X」飘字
- [ ] 读取存档后跳转到爬塔场景继续游戏
- [ ] 点击返回关闭存档管理界面
- [ ] 明亮纸片剧场风格（白底卡片 + 底部加粗边框 + 圆角 + 阴影）

### 暂停菜单
- [ ] 暂停菜单有「保存进度」按钮
- [ ] 点击后保存到当前活跃槽位
- [ ] 按钮文本临时变为「已保存 ✓」，1.5秒后恢复
- [ ] 暂停菜单有「保存并退出」按钮
- [ ] 点击后先保存再返回主菜单

### 主菜单继续游戏
- [ ] 有活跃存档时显示「继续游戏」按钮
- [ ] 点击后直接加载活跃槽位并跳转爬塔
- [ ] 无存档时隐藏「继续游戏」，玩家通过「存档管理」选择
