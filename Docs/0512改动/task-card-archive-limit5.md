# 任务卡：档案上限5个 + 覆盖确认机制

> 只修改档案系统相关文件，不改战斗/商店等其他模块。

---

## 需求

1. 斗士档案最多保留 **5个**
2. 已有5个档案时点击"生成档案"，弹出已有档案列表供玩家选择**覆盖目标**
3. 选择后弹出确认窗口：**"是否覆盖档案？该操作不可撤销。"**
4. 确认后覆盖，取消后回到 Settlement 界面

---

## 当前问题

`SaveManager.generate_fighter_archive()` 直接 `append` 到 archives 数组，不做数量限制。`load_archives` 返回全部档案。

---

## 修复步骤

### Step 1：SaveManager 增加档案数量检查 + 覆盖接口

**文件：`autoload/save_manager.gd`**

#### 1a. 新增 `get_archive_count()`

```gdscript
func get_archive_count() -> int:
    var file_path: String = ConfigManager.ARCHIVE_FILE
    var data: Dictionary = ModelsSerializer.load_json_file(file_path)
    if data.is_empty():
        return 0
    var archives: Array = data.get("archives", [])
    return archives.size()
```

#### 1b. 新增 `get_archives_for_overwrite()`

返回5个档案的基本信息（用于UI列表显示），包含索引号方便后续覆盖：

```gdscript
func get_archives_for_overwrite() -> Array[Dictionary]:
    var file_path: String = ConfigManager.ARCHIVE_FILE
    var data: Dictionary = ModelsSerializer.load_json_file(file_path)
    if data.is_empty():
        return []
    var archives: Array = data.get("archives", [])
    var result: Array[Dictionary] = []
    for i in range(archives.size()):
        var entry: Dictionary = archives[i]
        result.append({
            "index": i,
            "hero_name": entry.get("hero_name", "???"),
            "final_grade": entry.get("final_grade", "?"),
            "final_score": entry.get("final_score", 0),
            "final_turn": entry.get("final_turn", 0),
            "created_at": entry.get("created_at", 0),
        })
    return result
```

#### 1c. 新增 `overwrite_archive(index, new_archive)`

```gdscript
func overwrite_archive(index: int, new_archive: Dictionary) -> bool:
    var file_path: String = ConfigManager.ARCHIVE_FILE
    var data: Dictionary = ModelsSerializer.load_json_file(file_path)
    if data.is_empty():
        return false
    var archives: Array = data.get("archives", [])
    if index < 0 or index >= archives.size():
        push_error("[SaveManager] 覆盖索引越界: %d, 总数: %d" % [index, archives.size()])
        return false
    
    # 覆盖指定索引的档案
    new_archive["archive_id"] = archives[index].get("archive_id", _generate_archive_id())
    new_archive["created_at"] = Time.get_unix_time_from_system()
    new_archive["is_fixed"] = true
    archives[index] = new_archive
    data["last_updated"] = Time.get_unix_time_from_system()
    
    var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        EventBus.archive_generated.emit(new_archive)
        EventBus.archive_saved.emit(new_archive)
        print("[SaveManager] 覆盖档案成功, index=%d" % index)
        return true
    else:
        push_error("[SaveManager] 覆盖档案失败: 无法写入文件")
        return false
```

#### 1d. 修改 `generate_fighter_archive()`，增加数量上限检查

```gdscript
func generate_fighter_archive(archive_data: Dictionary) -> Dictionary:
    var file_path: String = ConfigManager.ARCHIVE_FILE
    var existing: Dictionary = ModelsSerializer.load_json_file(file_path)
    if existing.is_empty():
        existing = {"version": _current_version, "archives": [], "last_updated": 0}
    if not existing.has("archives"):
        existing["archives"] = []
    
    var archives: Array = existing["archives"]
    
    # 如果未满5个，直接追加
    if archives.size() < 5:
        archive_data["archive_id"] = _generate_archive_id()
        archive_data["created_at"] = Time.get_unix_time_from_system()
        archive_data["is_fixed"] = true
        archives.append(archive_data)
        existing["last_updated"] = Time.get_unix_time_from_system()
        existing["version"] = _current_version
        
        var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
        if file != null:
            file.store_string(JSON.stringify(existing, "\t"))
            file.close()
        else:
            push_error("[SaveManager] Failed to write archive file")
        
        EventBus.archive_generated.emit(archive_data)
        EventBus.archive_saved.emit(archive_data)
        return archive_data
    else:
        # 已满5个，不直接保存，返回特殊标记通知上层处理覆盖
        print("[SaveManager] 档案已满(5/5)，需要覆盖")
        return {"_needs_overwrite": true, "archive_data": archive_data}
```

---

### Step 2：新建档案覆盖选择弹窗场景

**新建文件：`scenes/settlement/archive_overwrite_dialog.tscn`**

```
ArchiveOverwriteDialog (Panel)
├── BgOverlay (ColorRect)           # 半透明黑色背景，全屏
│   └── color = Color(0, 0, 0, 0.5)
│   └── mouse_filter = 2            # STOP，拦截底层点击
├── DialogPanel (Panel)             # 白色对话框
│   ├── TitleLabel (Label)          # "档案已满"
│   ├── DescLabel (Label)           # "最多保留5个档案，请选择要覆盖的档案："
│   ├── ArchiveList (VBoxContainer) # 5个档案条目（动态生成）
│   │   └── ArchiveItem (Button)    # 每个条目显示：主角名 评分 层数
│   ├── ConfirmPanel (HBoxContainer) # 确认覆盖提示
│   │   ├── ConfirmLabel (Label)    # "是否覆盖档案？该操作不可撤销。"
│   │   ├── YesButton (Button)      # "确认覆盖"
│   │   └── NoButton (Button)       # "取消"
│   └── CancelButton (Button)       # "返回"（在未进入确认状态时显示）
```

**新建文件：`scenes/settlement/archive_overwrite_dialog.gd`**

```gdscript
class_name ArchiveOverwriteDialog
extends Control

@onready var archive_list: VBoxContainer = $DialogPanel/ArchiveList
@onready var confirm_panel: HBoxContainer = $DialogPanel/ConfirmPanel
@onready var cancel_button: Button = $DialogPanel/CancelButton
@onready var dialog_panel: Panel = $DialogPanel

var _archives: Array[Dictionary] = []
var _selected_index: int = -1
var _pending_new_archive: Dictionary = {}

signal archive_overwritten
signal cancelled

func _ready() -> void:
    confirm_panel.visible = false
    cancel_button.pressed.connect(_on_cancel)
    $DialogPanel/ConfirmPanel/YesButton.pressed.connect(_on_confirm_yes)
    $DialogPanel/ConfirmPanel/NoButton.pressed.connect(_on_confirm_no)

func show_dialog(archives: Array[Dictionary], new_archive: Dictionary) -> void:
    visible = true
    _archives = archives
    _pending_new_archive = new_archive
    _selected_index = -1
    confirm_panel.visible = false
    cancel_button.visible = true
    
    # 清空旧条目
    for child in archive_list.get_children():
        child.queue_free()
    
    # 生成档案条目
    for archive in archives:
        var btn := Button.new()
        var hero_name: String = archive.get("hero_name", "???")
        var grade: String = archive.get("final_grade", "?")
        var score: int = archive.get("final_score", 0)
        var turn: int = archive.get("final_turn", 0)
        btn.text = "%s  |  %s级  |  %d分  |  第%d层" % [hero_name, grade, score, turn]
        btn.custom_minimum_size = Vector2(0, 40)
        btn.pressed.connect(_on_archive_selected.bind(archive.get("index", -1)))
        archive_list.add_child(btn)

func _on_archive_selected(index: int) -> void:
    _selected_index = index
    print("[OverwriteDialog] 选择覆盖目标: index=%d" % index)
    # 高亮选中的条目
    for i in range(archive_list.get_child_count()):
        var btn: Button = archive_list.get_child(i)
        btn.modulate = Color(1, 1, 1) if i == index else Color(0.7, 0.7, 0.7)
    
    # 显示确认面板
    confirm_panel.visible = true
    cancel_button.visible = false

func _on_confirm_yes() -> void:
    if _selected_index < 0:
        return
    print("[OverwriteDialog] 确认覆盖 index=%d" % _selected_index)
    var result = SaveManager.overwrite_archive(_selected_index, _pending_new_archive)
    if result:
        archive_overwritten.emit()
        visible = false
    else:
        push_error("[OverwriteDialog] 覆盖失败")

func _on_confirm_no() -> void:
    # 回到选择状态
    confirm_panel.visible = false
    cancel_button.visible = true
    _selected_index = -1
    for btn in archive_list.get_children():
        btn.modulate = Color(1, 1, 1)

func _on_cancel() -> void:
    cancelled.emit()
    visible = false
```

---

### Step 3：修改 Settlement 场景，集成覆盖弹窗

**修改文件：`scenes/settlement/settlement.tscn`**

添加 ArchiveOverwriteDialog 实例：
```
[node name="ArchiveOverwriteDialog" parent="." instance=ExtResource("4_dialog")]
visible = false
```

**修改文件：`scenes/settlement/settlement.gd`**

```gdscript
@onready var overwrite_dialog: ArchiveOverwriteDialog = $ArchiveOverwriteDialog

func _ready() -> void:
    ...
    overwrite_dialog.archive_overwritten.connect(_on_archive_overwritten)
    overwrite_dialog.cancelled.connect(_on_overwrite_cancelled)
    ...

func _on_archive_button_pressed() -> void:
    if _archive_data.is_empty():
        push_warning("[Settlement] No archive data available")
        return
    
    # 检查档案数量
    var count: int = SaveManager.get_archive_count()
    print("[Settlement] 当前档案数: %d" % count)
    
    if count < 5:
        # 未满5个，直接保存
        var saved: Dictionary = SaveManager.generate_fighter_archive(_archive_data)
        _archive_saved = true
        _update_saved_ui()
    else:
        # 已满5个，弹出覆盖选择窗口
        var archives: Array[Dictionary] = SaveManager.get_archives_for_overwrite()
        overwrite_dialog.show_dialog(archives, _archive_data)

func _on_archive_overwritten() -> void:
    _archive_saved = true
    _update_saved_ui()
    print("[Settlement] 档案覆盖完成")

func _on_overwrite_cancelled() -> void:
    print("[Settlement] 用户取消覆盖")

func _update_saved_ui() -> void:
    if saved_hint_label != null:
        saved_hint_label.text = "档案已保存"
        saved_hint_label.visible = true
    if view_archive_button != null:
        view_archive_button.visible = true
    archive_button.disabled = true
```

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `autoload/save_manager.gd` | 新增 | `get_archive_count()` |
| 2 | `autoload/save_manager.gd` | 新增 | `get_archives_for_overwrite()` |
| 3 | `autoload/save_manager.gd` | 新增 | `overwrite_archive(index, data)` |
| 4 | `autoload/save_manager.gd` | 修改 | `generate_fighter_archive()` 增加5个上限判断，满时返回 `_needs_overwrite` |
| 5 | `scenes/settlement/archive_overwrite_dialog.tscn` | 新建 | 覆盖选择弹窗场景 |
| 6 | `scenes/settlement/archive_overwrite_dialog.gd` | 新建 | 弹窗逻辑 |
| 7 | `scenes/settlement/settlement.tscn` | 修改 | 添加 ArchiveOverwriteDialog 实例 |
| 8 | `scenes/settlement/settlement.gd` | 修改 | 档案按钮回调增加数量检查 + 覆盖流程 |

---

## 验收标准

- [ ] 档案数量 < 5 时，点击"生成档案"直接保存，按钮变灰，显示"档案已保存"
- [ ] 档案数量 = 5 时，点击"生成档案"弹出"档案已满"对话框
- [ ] 对话框显示5个已有档案的基本信息（主角名、评分、层数）
- [ ] 点击某个档案条目后，条目高亮，下方显示确认提示"是否覆盖档案？该操作不可撤销。"
- [ ] 点击"确认覆盖" → 档案被覆盖 → 弹窗关闭 → Settlement 显示"档案已保存"
- [ ] 点击"取消" → 回到选择列表，可重新选择
- [ ] 点击"返回" → 弹窗关闭 → 回到 Settlement，不保存档案
- [ ] 覆盖后档案总数仍为5（不会变成6）
