# PVP大厅修正任务卡（v2）：主菜单选档案 + PVP大厅直接用

> 用户确认：档案选择放到主菜单，PVP大厅直接使用已选档案。

---

## 修正后的完整流程

```
主菜单
├── 新游戏 / 继续游戏 / 查看档案 / PVP对战 / 退出
│
├── 玩家先在"查看档案"里选择"设为出战档案"（或自动用最新档案）
│   └── GameManager 记录 current_pvp_archive
│
└── 点击"PVP对战" → 进入PVP大厅
    ├── 显示当前出战档案信息（不可更改，只读）
    ├── 显示该档案的净胜场
    ├── 点击"匹配对手" → 用该档案净胜场匹配
    ├── 显示对手 → 开始战斗
    ├── 结算：档案净胜场更新 + 账号魔城币更新
    └── 点击确认 → 回到PVP大厅（可继续匹配）
```

---

## 修复步骤

### Step 1：GameManager 增加当前PVP档案记录

**文件：`autoload/game_manager.gd`**

```gdscript
# 新增：当前PVP出战档案
var current_pvp_archive: Dictionary = {}

func set_pvp_archive(archive: Dictionary) -> void:
    current_pvp_archive = archive.duplicate(true)
    print("[GameManager] 设置PVP出战档案: %s" % archive.get("hero_name", "???"))

func get_pvp_archive() -> Dictionary:
    if current_pvp_archive.is_empty():
        # 如果没有设置，自动取最新档案
        var archives: Array[Dictionary] = SaveManager.load_archives("date", 1, "")
        if not archives.is_empty() and archives[0].get("is_fixed", false):
            current_pvp_archive = archives[0]
    return current_pvp_archive
```

### Step 2：档案浏览界面增加"设为出战档案"按钮

**文件：`scenes/archive_view/archive_view.gd`**

在档案详情弹窗（ArchiveDetailPanel）中增加按钮：

```gdscript
# 在 _show_archive_detail 或档案条目点击回调中
func _on_archive_selected_for_pvp(archive: Dictionary) -> void:
    GameManager.set_pvp_archive(archive)
    print("[ArchiveView] 已设为出战档案: %s" % archive.get("hero_name", "???"))
    # 显示提示："已设为PVP出战档案"
    
func _show_archive_detail(archive: Dictionary) -> void:
    ...
    # 在弹窗按钮区域增加
    var set_pvp_btn := Button.new()
    set_pvp_btn.text = "设为出战档案"
    set_pvp_btn.pressed.connect(_on_archive_selected_for_pvp.bind(archive))
    detail_buttons_container.add_child(set_pvp_btn)
```

**注意**：如果档案浏览界面没有详情弹窗，直接在每个档案条目上增加"出战"按钮。

### Step 3：PVP大厅移除档案选择面板，改为只读显示

**文件：`scenes/pvp_lobby/pvp_lobby.gd`**

```gdscript
func _ready() -> void:
    _load_player_data()
    _load_selected_archive()   # 从 GameManager 读取
    _update_ui()
    ...

func _load_selected_archive() -> void:
    _selected_archive = GameManager.get_pvp_archive()
    if _selected_archive.is_empty():
        print("[PvpLobby] 没有出战档案，无法匹配")
        match_button.disabled = true
        selected_archive_info.visible = false
        no_archive_warning.visible = true
        return
    
    # 补全字段（兼容旧档案）
    if not _selected_archive.has("net_wins"):
        _selected_archive["net_wins"] = 0
    if not _selected_archive.has("total_wins"):
        _selected_archive["total_wins"] = 0
    if not _selected_archive.has("total_losses"):
        _selected_archive["total_losses"] = 0
    
    print("[PvpLobby] 出战档案: %s, 净胜场=%d" % [
        _selected_archive.get("hero_name", "???"),
        _selected_archive.get("net_wins", 0)
    ])

func _update_ui() -> void:
    # 显示账号魔城币
    coin_label.text = "魔城币: %d" % _player_data.get("mocheng_coin", 0)
    
    # 显示出战档案信息
    if not _selected_archive.is_empty():
        hero_name_label.text = "出战: %s" % _selected_archive.get("hero_name", "???")
        grade_label.text = "%s级" % _selected_archive.get("final_grade", "?")
        net_wins_label.text = "净胜场: %d" % _selected_archive.get("net_wins", 0)
        selected_archive_info.visible = true
        match_button.disabled = false
```

**文件：`scenes/pvp_lobby/pvp_lobby.tscn`**

- **删除** ArchiveSelectPanel（不再需要）
- **保留** SelectedArchiveInfo（只读显示出战档案）

### Step 4：主菜单增加"更换出战档案"按钮或入口

**方案A（简单）**：在"查看档案"按钮旁边增加提示——"当前出战: XXX"

**方案B（推荐）**：在"PVP对战"按钮下方显示一行小字："当前出战: 剑影 (净胜场: 3)"

```gdscript
# menu.gd 的 _ready 中
func _update_pvp_archive_display() -> void:
    var archive := GameManager.get_pvp_archive()
    if not archive.is_empty():
        var hint_label := get_node_or_null("PVPHintLabel")
        if hint_label != null:
            hint_label.text = "PVP出战: %s (净胜场:%d)" % [
                archive.get("hero_name", "???"),
                archive.get("net_wins", 0)
            ]
            hint_label.visible = true
```

### Step 5：匹配逻辑不变（仍用档案级净胜场）

```gdscript
func _on_match_pressed() -> void:
    if _selected_archive.is_empty():
        push_warning("[PvpLobby] 未选择出战档案")
        return
    
    var net_wins: int = _selected_archive.get("net_wins", 0)
    var opponent: Dictionary = _find_opponent_by_net_wins(net_wins)
    ...
```

### Step 6：结算逻辑不变（更新档案净胜场 + 账号魔城币）

和之前一样：
- 更新 `_selected_archive` 的 `net_wins` / `total_wins` / `total_losses`
- 调用 `SaveManager.update_archive()` 保存档案
- 更新 `player_data` 的 `mocheng_coin`

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `autoload/game_manager.gd` | 新增 | `current_pvp_archive` 字段 + `set_pvp_archive()` / `get_pvp_archive()` |
| 2 | `scenes/archive_view/archive_view.gd` | 修改 | 档案详情弹窗增加"设为出战档案"按钮 |
| 3 | `scenes/pvp_lobby/pvp_lobby.tscn` | 修改 | 删除 ArchiveSelectPanel，保留 SelectedArchiveInfo（只读） |
| 4 | `scenes/pvp_lobby/pvp_lobby.gd` | 重写 | 从 GameManager 读取出战档案，移除档案选择逻辑 |
| 5 | `scenes/main_menu/menu.gd` | 修改 | 增加PVP出战档案提示显示 |
| 6 | `autoload/save_manager.gd` | 修改 | 生成档案时增加 net_wins/total_wins/total_losses |
| 7 | `autoload/save_manager.gd` | 新增 | `update_archive()` 方法 |
| 8 | `scripts/systems/leaderboard_system.gd` | 修改 | 排序改为档案级 net_wins |

---

## 验收标准

- [ ] 在"查看档案"界面，点击档案详情有"设为出战档案"按钮
- [ ] 设置后，主菜单显示"PVP出战: XXX (净胜场:X)"
- [ ] 进入PVP大厅，直接显示当前出战档案信息（不可选择）
- [ ] 没有出战档案时，PVP大厅提示"请先选择出战档案"
- [ ] 匹配、战斗、结算逻辑和之前一致（档案级净胜场 + 账号魔城币）
- [ ] 结算后回到PVP大厅，可以继续匹配（不换档案）
