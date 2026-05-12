# Phase 5-B 任务卡：局外PVP大厅

> 目标：主菜单PVP按钮 → PVP大厅 → 匹配对手 → 战斗 → 魔城币+净胜场结算

---

## 需求确认

1. 主菜单"PVP对战"按钮进入PVP大厅
2. PVP大厅功能：**查看记录** + **匹配对手**
3. 匹配时按当前胜场自动匹配影子（异步，非实时），不需要玩家选择对手
4. 完整BattleEngine战斗
5. 独立PVP背景（和爬塔背景不同）
6. 奖励：
   - 魔城币：胜利+20/场，上限100/日（5场）
   - 净胜场 = 总胜场 - 总败场（最低0，不扣减）
7. 魔城币仅通过PVP获取

---

## 当前代码状态

- `menu.gd` 有 `show_leaderboard()` 占位，但 `_load_leaderboard_data()` 返回空数组
- 没有PVP大厅场景
- 没有局外PVP的战斗流程
- `player_data.json` 格式未知（SaveManager私有方法访问不了）

---

## 修复/新建步骤

### Step 1：主菜单添加PVP按钮

**文件：`scenes/main_menu/menu.gd`**

```gdscript
@onready var _btn_pvp: Button = %BtnPVP

func _ready() -> void:
    ...
    _btn_pvp.pressed.connect(_on_pvp_pressed)
    ...

func _on_pvp_pressed() -> void:
    print("[MainMenu] PVP对战按钮点击")
    EventBus.pvp_lobby_requested.emit()
```

**文件：`scenes/main_menu/menu.tscn`**（如需要，添加BtnPVP按钮）

---

### Step 2：新建PVP大厅场景

**新建文件：`scenes/pvp_lobby/pvp_lobby.tscn`**

```
PvpLobby (Control)
├── Background (TextureRect)          # 独立PVP背景图
├── TitleLabel (Label)                # "PVP大厅"
├── NetWinsDisplay (Label)            # "当前净胜场: X"
├── MochengCoinDisplay (Label)        # "魔城币: X"
├── MatchButton (Button)              # "匹配对手"
├── RecordButton (Button)            # "查看记录"
├── BackButton (Button)              # "返回主菜单"
├── MatchResultPanel (Panel)         # 匹配结果弹窗（默认隐藏）
│   ├── OpponentInfoLabel (Label)    # 对手信息
│   ├── StartBattleButton (Button)   # "开始战斗"
│   └── CancelButton (Button)        # "取消"
└── BattleSummaryPanel (BattleSummaryPanel)  # 战斗摘要（复用run_main的）
```

**新建文件：`scenes/pvp_lobby/pvp_lobby.gd`**

```gdscript
class_name PvpLobby
extends Control

@onready var net_wins_label: Label = $NetWinsDisplay
@onready var coin_label: Label = $MochengCoinDisplay
@onready var match_button: Button = $MatchButton
@onready var record_button: Button = $RecordButton
@onready var back_button: Button = $BackButton
@onready var match_result_panel: Panel = $MatchResultPanel
@onready var opponent_info_label: Label = $MatchResultPanel/OpponentInfoLabel
@onready var start_battle_button: Button = $MatchResultPanel/StartBattleButton
@onready var cancel_button: Button = $MatchResultPanel/CancelButton
@onready var battle_summary_panel: BattleSummaryPanel = $BattleSummaryPanel

var _current_opponent: Dictionary = {}
var _player_data: Dictionary = {}

func _ready() -> void:
    _load_player_data()
    _update_ui()
    
    match_button.pressed.connect(_on_match_pressed)
    record_button.pressed.connect(_on_record_pressed)
    back_button.pressed.connect(_on_back_pressed)
    start_battle_button.pressed.connect(_on_start_battle)
    cancel_button.pressed.connect(_on_cancel_match)
    battle_summary_panel.confirmed.connect(_on_battle_confirmed)
    
    match_result_panel.visible = false
    battle_summary_panel.visible = false

func _load_player_data() -> void:
    _player_data = SaveManager.load_player_data()
    if _player_data.is_empty():
        _player_data = {
            "net_wins": 0,
            "total_wins": 0,
            "total_losses": 0,
            "mocheng_coin": 0,
            "pvp_wins_today": 0,
            "last_pvp_date": "",
        }

func _update_ui() -> void:
    net_wins_label.text = "当前净胜场: %d" % _player_data.get("net_wins", 0)
    coin_label.text = "魔城币: %d" % _player_data.get("mocheng_coin", 0)

func _on_match_pressed() -> void:
    print("[PvpLobby] 开始匹配")
    
    # 按净胜场匹配影子对手
    var net_wins: int = _player_data.get("net_wins", 0)
    var opponent: Dictionary = _find_opponent_by_net_wins(net_wins)
    
    if opponent.is_empty():
        opponent_info_label.text = "未找到匹配对手，使用AI挑战者"
        _current_opponent = _generate_ai_opponent()
    else:
        var opp_name: String = opponent.get("hero_name", "影子斗士")
        var opp_wins: int = opponent.get("net_wins", 0)
        opponent_info_label.text = "匹配到对手: %s\n净胜场: %d" % [opp_name, opp_wins]
        _current_opponent = opponent
    
    match_result_panel.visible = true

func _find_opponent_by_net_wins(player_net_wins: int) -> Dictionary:
    # 从本地档案 + 虚拟档案中找净胜场相近的对手（±2范围）
    var all_archives: Array[Dictionary] = SaveManager.load_archives("net_wins", 9999, "")
    
    # 加入虚拟档案
    var virtual_pool := VirtualArchivePool.new()
    virtual_pool._ready()
    for va in virtual_pool._virtual_archives:
        all_archives.append(va)
    
    var candidates: Array[Dictionary] = []
    for archive in all_archives:
        var opp_net_wins: int = archive.get("net_wins", 0)
        if abs(opp_net_wins - player_net_wins) <= 2:
            candidates.append(archive)
    
    if candidates.is_empty():
        # 放宽范围
        for archive in all_archives:
            candidates.append(archive)
    
    if candidates.is_empty():
        return {}
    
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    return candidates[rng.randi() % candidates.size()]

func _generate_ai_opponent() -> Dictionary:
    # 固定角色 + 随机Lv1伙伴
    return {
        "hero_name": "AI挑战者",
        "hero_config_id": 1,
        "attr_snapshot_vit": 20,
        "attr_snapshot_str": 20,
        "attr_snapshot_agi": 20,
        "attr_snapshot_tec": 20,
        "attr_snapshot_mnd": 20,
        "partners": [
            {"partner_config_id": 1001, "current_level": 1},
        ],
        "net_wins": 0,
        "_source": "ai",
    }

func _on_start_battle() -> void:
    print("[PvpLobby] 开始PVP战斗")
    match_result_panel.visible = false
    
    # 执行PVP战斗（复用PvpDirector逻辑）
    var pvp_director := PvpDirector.new()
    add_child(pvp_director)
    
    # 从当前玩家档案构建player_state
    var player_archive := _get_current_player_archive()
    var pvp_config: Dictionary = {
        "turn_number": 30,  # 局外PVP默认30层强度
        "player_gold": 0,
        "player_hp": player_archive.get("max_hp_reached", 100),
        "player_hero": _archive_to_battle_dict(player_archive),
        "run_seed": randi(),
        "use_archive": true,
        "opponent_archive": _current_opponent,
    }
    
    var result: Dictionary = pvp_director.execute_pvp(pvp_config)
    pvp_director.queue_free()
    
    # 结算
    _process_pvp_result(result)
    
    # 显示战斗摘要
    battle_summary_panel.show_result(result)
    battle_summary_panel.visible = true

func _process_pvp_result(result: Dictionary) -> void:
    var won: bool = result.get("won", false)
    var total_wins: int = _player_data.get("total_wins", 0)
    var total_losses: int = _player_data.get("total_losses", 0)
    var current_coin: int = _player_data.get("mocheng_coin", 0)
    var today_wins: int = _player_data.get("pvp_wins_today", 0)
    var last_date: String = _player_data.get("last_pvp_date", "")
    
    var today_str: String = Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), true).split(" ")[0]
    if last_date != today_str:
        today_wins = 0
        last_date = today_str
    
    if won:
        total_wins += 1
        _player_data["total_wins"] = total_wins
        
        # 魔城币发放（上限5场/日）
        if today_wins < 5:
            current_coin += 20
            today_wins += 1
            print("[PvpLobby] 魔城币+20，今日胜利 %d/5" % today_wins)
            EventBus.emit_signal("mocheng_coin_changed", current_coin, 20, "pvp_reward")
        else:
            print("[PvpLobby] 今日PVP已达上限，不再发放魔城币")
    else:
        total_losses += 1
        _player_data["total_losses"] = total_losses
        print("[PvpLobby] PVP失败")
    
    # 净胜场 = 胜 - 负（最低0）
    var net_wins: int = maxi(0, total_wins - total_losses)
    _player_data["net_wins"] = net_wins
    _player_data["mocheng_coin"] = current_coin
    _player_data["pvp_wins_today"] = today_wins
    _player_data["last_pvp_date"] = last_date
    
    SaveManager.save_player_data(_player_data)
    _update_ui()
    
    print("[PvpLobby] PVP结算完成: 净胜场=%d, 魔城币=%d" % [net_wins, current_coin])

func _get_current_player_archive() -> Dictionary:
    # 从最新档案获取玩家当前数据
    var archives: Array[Dictionary] = SaveManager.load_archives("date", 1, "")
    if not archives.is_empty():
        return archives[0]
    # 如果没有档案，返回默认数据
    return {
        "hero_config_id": 1,
        "attr_snapshot_vit": 20,
        "attr_snapshot_str": 20,
        "attr_snapshot_agi": 20,
        "attr_snapshot_tec": 20,
        "attr_snapshot_mnd": 20,
        "max_hp_reached": 100,
        "partners": [],
    }

func _archive_to_battle_dict(archive: Dictionary) -> Dictionary:
    return {
        "hero_id": ConfigManager.get_hero_id_by_config_id(archive.get("hero_config_id", 1)),
        "stats": {
            "physique": archive.get("attr_snapshot_vit", 10),
            "strength": archive.get("attr_snapshot_str", 10),
            "agility": archive.get("attr_snapshot_agi", 10),
            "technique": archive.get("attr_snapshot_tec", 10),
            "spirit": archive.get("attr_snapshot_mnd", 10),
        },
        "max_hp": archive.get("max_hp_reached", 100),
        "hp": archive.get("max_hp_reached", 100),
    }

func _on_record_pressed() -> void:
    print("[PvpLobby] 查看PVP记录")
    # TODO: 显示PVP历史记录弹窗

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_cancel_match() -> void:
    match_result_panel.visible = false
    _current_opponent = {}

func _on_battle_confirmed() -> void:
    battle_summary_panel.visible = false
```

---

### Step 3：SaveManager 公共接口

**文件：`autoload/save_manager.gd`**

将 `_load_player_data` / `_save_player_data` 改为公共方法（如果还没改）：

```gdscript
func load_player_data() -> Dictionary:
    var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
    if not FileAccess.file_exists(file_path):
        return {}
    return ModelsSerializer.load_json_file(file_path)

func save_player_data(data: Dictionary) -> void:
    var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
    var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
```

---

### Step 4：EventBus 新增信号

**文件：`autoload/event_bus.gd`**

```gdscript
# 新增
signal pvp_lobby_requested
signal mocheng_coin_changed(current, delta, reason)
```

---

### Step 5：GameManager 订阅PVP大厅信号

**文件：`autoload/game_manager.gd`**

```gdscript
func _ready() -> void:
    ...
    EventBus.pvp_lobby_requested.connect(_on_pvp_lobby_requested)

func _on_pvp_lobby_requested() -> void:
    change_scene("PVP_LOBBY", "fade")
```

---

### Step 6：主菜单排行榜数据接入

**文件：`scenes/main_menu/menu.gd`**

```gdscript
func _load_leaderboard_data() -> Array[Dictionary]:
    var leaderboard_system := LeaderboardSystem.new()
    var entries: Array[Dictionary] = leaderboard_system.get_leaderboard(10, "")
    var result: Array[Dictionary] = []
    for entry in entries:
        result.append({
            "player_name": entry.get("hero_name", "Unknown"),
            "net_wins": entry.get("net_wins", 0),
            "hero_name": entry.get("hero_name", ""),
            "hero_attrs": "",
            "partners": "",
        })
    return result
```

**同时修改 `LeaderboardSystem.get_leaderboard`** 确保从 player_data 读取 `net_wins`：

```gdscript
# scripts/systems/leaderboard_system.gd
func get_leaderboard(...) -> Array[Dictionary]:
    ...
    for archive in archives:
        # 如果档案里没有 net_wins，从 player_data 读取
        if not archive.has("net_wins"):
            var pd = SaveManager.load_player_data()
            archive["net_wins"] = pd.get("net_wins", 0)
    ...
```

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scenes/main_menu/menu.gd` | 修改 | 添加 `_btn_pvp` 按钮和 `_on_pvp_pressed` 回调 |
| 2 | `scenes/main_menu/menu.tscn` | 修改 | 添加 BtnPVP 按钮（如需要） |
| 3 | `scenes/pvp_lobby/pvp_lobby.tscn` | 新建 | PVP大厅场景 |
| 4 | `scenes/pvp_lobby/pvp_lobby.gd` | 新建 | PVP大厅逻辑 |
| 5 | `autoload/save_manager.gd` | 修改 | `load_player_data` / `save_player_data` 改为公共方法 |
| 6 | `autoload/event_bus.gd` | 修改 | 新增 `pvp_lobby_requested` 和 `mocheng_coin_changed` 信号 |
| 7 | `autoload/game_manager.gd` | 修改 | 订阅 `pvp_lobby_requested`，切到PVP大厅场景 |
| 8 | `scripts/systems/leaderboard_system.gd` | 修改 | 排行榜从 player_data 读取 net_wins |
| 9 | `scenes/main_menu/menu.gd` | 修改 | `_load_leaderboard_data()` 接入 LeaderboardSystem |

---

## 验收标准

### PVP大厅
- [ ] 主菜单显示"PVP对战"按钮
- [ ] 点击后进入PVP大厅（独立背景）
- [ ] PVP大厅显示：当前净胜场、魔城币余额
- [ ] 点击"匹配对手" → 弹窗显示匹配到的对手（档案影子或AI）
- [ ] 点击"开始战斗" → 进入BattleEngine战斗
- [ ] 战斗结束后弹出摘要面板
- [ ] 点击确认后回到PVP大厅，净胜场和魔城币已更新

### 魔城币
- [ ] PVP胜利后魔城币+20
- [ ] 单日第6次胜利不再发放魔城币
- [ ] 新的一天重置计数，重新可获魔城币
- [ ] 魔城币持久化到 player_data.json

### 净胜场
- [ ] 胜利后总胜场+1，净胜场重新计算
- [ ] 失败后总败场+1，净胜场不变（最低0）
- [ ] 净胜场持久化到 player_data.json

### 排行榜
- [ ] 主菜单 leaderboard 显示真实数据（从档案读取净胜场排序）
- [ ] 排行榜按净胜场降序，同净胜场按评分降序