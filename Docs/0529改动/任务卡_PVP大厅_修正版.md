# 任务卡：PVP大厅（净胜场排名 + 魔城币奖励）

## 参考来源

1. **isetr/godot-simpleboards-leaderboard-example** — Godot 4 leaderboard，score submission + UI flow，排名列表展示
2. **adrenallen/EasyLeaderboard-Godot** — Drop-in Ready Leaderboard，Score Submission Modal，分页/自定义行
3. **ptrlrd/spire-codex** — Leaderboards三标签页（Fastest Wins / Highest Ascension / Browse Runs），Rank + Name + Score + Stats
4. **SmartFoxServer/SFS_MatchMaking_GD4** — 分房间排行榜、匹配API、rank field、last rank

---

## 核心规则（用户确认）

| 规则 | 说明 |
|------|------|
| **排名依据** | 净胜场 = 总胜场 - 总败场，最小为0 |
| **匹配规则** | 根据相似净胜场匹配对手 |
| **胜利奖励** | 局外商店货币「魔城币」，每日限领5次 |
| **失败惩罚** | 只加败场，无其他惩罚 |
| **排行榜** | 按净胜场从高到低排序，显示胜/败/净胜 |

---

## Step 0：数据结构设计

### 全局存档扩展

```gdscript
var global_save := {
    ## ... 原有字段 ...
    
    ## === PVP数据 ===
    "pvp": {
        "wins": 0,                    # 总胜场
        "losses": 0,                  # 总败场
        "net_wins": 0,                # 净胜场 = max(0, wins - losses)
        "daily_reward_count": 0,      # 今日已领奖次数
        "last_reward_date": "",       # 上次领奖日期（用于日重置）
        "total_magic_coins": 0,       # 累计获得魔城币
        "magic_coins": 0,             # 当前持有魔城币（局外商店用）
        "history": [],                # 最近10场记录
        "pvp_deck": {},               # PVP队伍快照
    },
}
```

### AI对手库（预置，按净胜场分布）

```gdscript
const AI_OPPONENTS: Array[Dictionary] = [
    {
        "name": "见习冒险者",
        "net_wins": 0,
        "wins": 2, "losses": 2,
        "hero_id": "hero_1", "hero_level": 1,
        "partner_ids": ["partner_1"],
        "partner_levels": {"partner_1": 1},
        "ai_difficulty": 0.2,
    },
    {
        "name": "丛林猎人",
        "net_wins": 3,
        "wins": 8, "losses": 5,
        "hero_id": "hero_2", "hero_level": 3,
        "partner_ids": ["partner_2", "partner_3"],
        "partner_levels": {"partner_2": 2, "partner_3": 2},
        "ai_difficulty": 0.4,
    },
    {
        "name": "王国骑士",
        "net_wins": 8,
        "wins": 20, "losses": 12,
        "hero_id": "hero_1", "hero_level": 6,
        "partner_ids": ["partner_2", "partner_5", "partner_7"],
        "partner_levels": {"partner_2": 4, "partner_5": 3, "partner_7": 4},
        "ai_difficulty": 0.6,
    },
    {
        "name": "大魔法师",
        "net_wins": 15,
        "wins": 35, "losses": 20,
        "hero_id": "hero_3", "hero_level": 8,
        "partner_ids": ["partner_4", "partner_6", "partner_8"],
        "partner_levels": {"partner_4": 5, "partner_6": 5, "partner_8": 4},
        "ai_difficulty": 0.75,
    },
    {
        "name": "传说勇者",
        "net_wins": 30,
        "wins": 60, "losses": 30,
        "hero_id": "hero_2", "hero_level": 10,
        "partner_ids": ["partner_5", "partner_6", "partner_9"],
        "partner_levels": {"partner_5": 5, "partner_6": 5, "partner_9": 5},
        "ai_difficulty": 0.9,
    },
]
```

### 每日奖励规则

```gdscript
const DAILY_MAX_REWARDS := 5           # 每日最多领奖5次
const MAGIC_COINS_PER_WIN := 10        # 每次胜利获得10魔城币
const MAGIC_COINS_BONUS_STREAK := 5    # 连胜额外奖励
```

---

## Step 1：PVPManager（Autoload Singleton）

```gdscript
## pvp_manager.gd — Autoload
extends Node

signal match_found(opponent: Dictionary)
signal match_result(won: bool, net_wins: int, magic_coins_earned: int)
signal daily_reward_updated(remaining: int)

const DAILY_MAX_REWARDS := 5
const MAGIC_COINS_PER_WIN := 10
const MAGIC_COINS_STREAK_BONUS := 5
const HISTORY_MAX := 10

var _current_opponent: Dictionary = {}
var _pvp_deck: Dictionary = {}

func _ready() -> void:
    _load_pvp_data()
    _check_daily_reset()

## ========== 日重置检查 ==========

func _check_daily_reset() -> void:
    var global := SaveManager.load_global()
    var pvp_data: Dictionary = global.get("pvp", {})
    var last_date: String = pvp_data.get("last_reward_date", "")
    var today := _get_date_string()
    
    if last_date != today:
        ## 新的一天，重置领奖次数
        pvp_data["daily_reward_count"] = 0
        pvp_data["last_reward_date"] = today
        global["pvp"] = pvp_data
        SaveManager.save_global(global)
        daily_reward_updated.emit(DAILY_MAX_REWARDS)

func _get_date_string() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

## ========== 加载/保存 ==========

func _load_pvp_data() -> void:
    var global := SaveManager.load_global()
    if not global.has("pvp"):
        global["pvp"] = {
            "wins": 0,
            "losses": 0,
            "net_wins": 0,
            "daily_reward_count": 0,
            "last_reward_date": _get_date_string(),
            "total_magic_coins": 0,
            "magic_coins": 0,
            "history": [],
            "pvp_deck": {},
        }
        SaveManager.save_global(global)

func _save_pvp_data() -> void:
    SaveManager.save_global(SaveManager.load_global())

## ========== 队伍快照 ==========

func update_deck_snapshot() -> void:
    var snapshot := {
        "hero_id": GameManager.selected_hero_id,
        "hero_level": GameManager.hero_level,
        "partner_ids": GameManager.partner_ids.duplicate(),
        "partner_levels": GameManager.partner_levels.duplicate(),
    }
    var global := SaveManager.load_global()
    global["pvp"]["pvp_deck"] = snapshot
    SaveManager.save_global(global)
    _pvp_deck = snapshot

func get_deck_snapshot() -> Dictionary:
    if _pvp_deck.is_empty():
        var global := SaveManager.load_global()
        _pvp_deck = global.get("pvp", {}).get("pvp_deck", {})
    return _pvp_deck

## ========== 匹配系统（按净胜场） ==========

func find_match() -> Dictionary:
    var candidates: Array[Dictionary] = []
    
    ## 1. 预置AI对手
    candidates.append_array(AI_OPPONENTS)
    
    ## 2. 其他存档槽位的队伍
    for slot_id in range(1, 4):
        var meta: Dictionary = SaveManager.get_slot_meta(slot_id)
        if meta.get("exists", false):
            var run_data: Dictionary = SaveManager.load_run(slot_id)
            if not run_data.is_empty():
                var estimated_net := _estimate_net_wins(run_data)
                candidates.append({
                    "name": meta.get("hero_name", "???") + "的队伍",
                    "net_wins": estimated_net,
                    "wins": estimated_net + randi() % 5,
                    "losses": randi() % 5,
                    "hero_id": run_data.get("hero_id", "hero_1"),
                    "hero_level": _get_hero_level(run_data),
                    "partner_ids": run_data.get("partner_ids", []),
                    "partner_levels": run_data.get("partner_levels", {}),
                    "ai_difficulty": clampf(0.3 + estimated_net * 0.02, 0.2, 0.95),
                    "is_real_player": true,
                })
    
    ## 3. 按净胜场接近程度排序
    var my_net: int = get_net_wins()
    candidates.sort_custom(func(a, b):
        var diff_a := abs(a.get("net_wins", 0) - my_net)
        var diff_b := abs(b.get("net_wins", 0) - my_net)
        return diff_a < diff_b
    )
    
    ## 4. 从最接近的3个中随机选
    var top := candidates.slice(0, min(3, candidates.size()))
    var opponent: Dictionary = top[randi() % top.size()]
    
    _current_opponent = opponent
    match_found.emit(opponent)
    return opponent

func _estimate_net_wins(run_data: Dictionary) -> int:
    var floor: int = run_data.get("current_floor", 1)
    return clampi(floor / 2, 0, 50)

func _get_hero_level(run_data: Dictionary) -> int:
    return run_data.get("hero_level", 1)

## ========== 战斗结算 ==========

func calculate_match_result(won: bool) -> Dictionary:
    var global := SaveManager.load_global()
    var pvp_data: Dictionary = global.get("pvp", {})
    
    var magic_coins_earned: int = 0
    var can_claim_reward: bool = pvp_data.get("daily_reward_count", 0) < DAILY_MAX_REWARDS
    
    if won:
        pvp_data["wins"] = pvp_data.get("wins", 0) + 1
        
        ## 计算连胜
        var history: Array = pvp_data.get("history", [])
        var current_streak: int = 0
        for record in history:
            if record.get("result") == "win":
                current_streak += 1
            else:
                break
        
        ## 发放魔城币（每日限5次）
        if can_claim_reward:
            magic_coins_earned = MAGIC_COINS_PER_WIN
            if current_streak >= 2:
                magic_coins_earned += MAGIC_COINS_STREAK_BONUS
            
            pvp_data["magic_coins"] = pvp_data.get("magic_coins", 0) + magic_coins_earned
            pvp_data["total_magic_coins"] = pvp_data.get("total_magic_coins", 0) + magic_coins_earned
            pvp_data["daily_reward_count"] = pvp_data.get("daily_reward_count", 0) + 1
            pvp_data["last_reward_date"] = _get_date_string()
    else:
        pvp_data["losses"] = pvp_data.get("losses", 0) + 1
    
    ## 重新计算净胜场
    var wins: int = pvp_data.get("wins", 0)
    var losses: int = pvp_data.get("losses", 0)
    pvp_data["net_wins"] = maxi(0, wins - losses)
    
    ## 历史记录
    var history: Array = pvp_data.get("history", [])
    history.push_front({
        "opponent_name": _current_opponent.get("name", "???"),
        "opponent_net_wins": _current_opponent.get("net_wins", 0),
        "result": "win" if won else "loss",
        "magic_coins": magic_coins_earned,
        "timestamp": _get_timestamp(),
    })
    while history.size() > HISTORY_MAX:
        history.pop_back()
    pvp_data["history"] = history
    
    global["pvp"] = pvp_data
    SaveManager.save_global(global)
    
    match_result.emit(won, pvp_data["net_wins"], magic_coins_earned)
    daily_reward_updated.emit(DAILY_MAX_REWARDS - pvp_data.get("daily_reward_count", 0))
    
    return {
        "won": won,
        "net_wins": pvp_data["net_wins"],
        "wins": wins,
        "losses": losses,
        "magic_coins_earned": magic_coins_earned,
        "remaining_rewards": DAILY_MAX_REWARDS - pvp_data.get("daily_reward_count", 0),
    }

func get_net_wins() -> int:
    var global := SaveManager.load_global()
    return global.get("pvp", {}).get("net_wins", 0)

func get_stats() -> Dictionary:
    var global := SaveManager.load_global()
    var pvp_data: Dictionary = global.get("pvp", {})
    var wins: int = pvp_data.get("wins", 0)
    var losses: int = pvp_data.get("losses", 0)
    return {
        "net_wins": pvp_data.get("net_wins", 0),
        "wins": wins,
        "losses": losses,
        "magic_coins": pvp_data.get("magic_coins", 0),
        "daily_reward_count": pvp_data.get("daily_reward_count", 0),
        "remaining_rewards": DAILY_MAX_REWARDS - pvp_data.get("daily_reward_count", 0),
        "history": pvp_data.get("history", []),
    }

## ========== 排行榜（按净胜场） ==========

func get_leaderboard() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    
    ## 自己
    var my_stats := get_stats()
    entries.append({
        "rank": 0,
        "name": "我",
        "net_wins": my_stats["net_wins"],
        "wins": my_stats["wins"],
        "losses": my_stats["losses"],
        "is_player": true,
    })
    
    ## AI对手
    for opp in AI_OPPONENTS:
        entries.append({
            "rank": 0,
            "name": opp["name"],
            "net_wins": opp["net_wins"],
            "wins": opp.get("wins", 0),
            "losses": opp.get("losses", 0),
            "is_player": false,
        })
    
    ## 其他存档
    for slot_id in range(1, 4):
        var meta: Dictionary = SaveManager.get_slot_meta(slot_id)
        if meta.get("exists", false):
            var run_data: Dictionary = SaveManager.load_run(slot_id)
            if not run_data.is_empty():
                var net: int = _estimate_net_wins(run_data)
                entries.append({
                    "rank": 0,
                    "name": meta.get("hero_name", "???") + "（存档%d）" % slot_id,
                    "net_wins": net,
                    "wins": net + randi() % 3,
                    "losses": randi() % 3,
                    "is_player": false,
                })
    
    ## 按净胜场降序
    entries.sort_custom(func(a, b): return a["net_wins"] > b["net_wins"])
    
    ## 分配排名
    for i in range(entries.size()):
        entries[i]["rank"] = i + 1
    
    return entries

## ========== 魔城币消费（局外商店用） ==========

func spend_magic_coins(amount: int) -> bool:
    var global := SaveManager.load_global()
    var pvp_data: Dictionary = global.get("pvp", {})
    var current: int = pvp_data.get("magic_coins", 0)
    
    if current < amount:
        return false
    
    pvp_data["magic_coins"] = current - amount
    global["pvp"] = pvp_data
    SaveManager.save_global(global)
    return true

func add_magic_coins(amount: int) -> void:
    var global := SaveManager.load_global()
    var pvp_data: Dictionary = global.get("pvp", {})
    pvp_data["magic_coins"] = pvp_data.get("magic_coins", 0) + amount
    pvp_data["total_magic_coins"] = pvp_data.get("total_magic_coins", 0) + amount
    global["pvp"] = pvp_data
    SaveManager.save_global(global)

## ========== 辅助 ==========

func _get_timestamp() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02dT%02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]


---

## Step 2：PVP大厅UI

### 节点结构

```
PvpLobby (Control, anchors_preset=15)
├── BackgroundLayer (CanvasLayer, layer=0)
│   ├── ColorRect                    # 暗褐底 Color(0.12, 0.08, 0.08)
│   └── BackgroundTexture            # 竞技场背景图
├── UILayer (CanvasLayer, layer=2)
│   ├── TopBar (HBoxContainer)
│   │   ├── BackButton (Button)
│   │   ├── TitleLabel (Label)       # "竞技场"
│   │   └── MagicCoinDisplay (HBoxContainer)
│   │       ├── CoinIcon (TextureRect)
│   │       └── CoinLabel (Label)    # "魔城币: 150"
│   ├── MainContent (HBoxContainer)
│   │   ├── LeftPanel (VBoxContainer)
│   │   │   ├── PlayerCard (PanelContainer)
│   │   │   │   ├── HeroAvatar (TextureRect)
│   │   │   │   ├── PlayerName (Label)
│   │   │   │   ├── NetWinsBadge (Label)   # "净胜场: 12"
│   │   │   │   └── StatsGrid (GridContainer)
│   │   │   │       ├── WinsLabel     # "胜场: 20"
│   │   │   │       ├── LossesLabel   # "败场: 8"
│   │   │   │       └── StreakLabel   # "连胜: 3"
│   │   │   ├── DeckSnapshotPanel (PanelContainer)
│   │   │   │   └── DeckPreview      # 队伍预览
│   │   │   └── UpdateDeckButton (Button)
│   │   ├── CenterPanel (VBoxContainer)
│   │   │   ├── DailyRewardIndicator (HBoxContainer)
│   │   │   │   └── RewardLabels (5个小圆点)
│   │   │   ├── MatchButton (Button)       # "寻找对手"
│   │   │   ├── MatchingAnimation (Control) # 匹配中旋转
│   │   │   └── OpponentPreview (PanelContainer)
│   │   └── RightPanel (VBoxContainer)
│   │       ├── LeaderboardTitle (Label)   # "排行榜"
│   │       └── LeaderboardList (ScrollContainer)
│   │           └── LeaderboardVBox (VBoxContainer)
│   └── BottomBar (HBoxContainer)
│       ├── HistoryButton (Button)
│       └── RulesLabel (Label)         # "每日5次奖励"
├── PopupLayer (CanvasLayer, layer=10)
│   ├── MatchResultPanel (PanelContainer)
│   ├── HistoryPanel (PanelContainer)
│   └── ConfirmDialog (ConfirmationDialog)
└── TransitionOverlay (ColorRect)
```

### 核心代码

```gdscript
## pvp_lobby.gd
extends Control

@onready var back_btn: Button = $UILayer/TopBar/BackButton
@onready var title_label: Label = $UILayer/TopBar/TitleLabel
@onready var magic_coin_label: Label = $UILayer/TopBar/MagicCoinDisplay/CoinLabel
@onready var player_card: PanelContainer = $UILayer/MainContent/LeftPanel/PlayerCard
@onready var net_wins_badge: Label = $UILayer/MainContent/LeftPanel/PlayerCard/NetWinsBadge
@onready var wins_label: Label = $UILayer/MainContent/LeftPanel/PlayerCard/StatsGrid/WinsLabel
@onready var losses_label: Label = $UILayer/MainContent/LeftPanel/PlayerCard/StatsGrid/LossesLabel
@onready var streak_label: Label = $UILayer/MainContent/LeftPanel/PlayerCard/StatsGrid/StreakLabel
@onready var deck_preview: Control = $UILayer/MainContent/LeftPanel/DeckSnapshotPanel/DeckPreview
@onready var update_deck_btn: Button = $UILayer/MainContent/LeftPanel/UpdateDeckButton
@onready var daily_reward_dots: HBoxContainer = $UILayer/MainContent/CenterPanel/DailyRewardIndicator
@onready var match_btn: Button = $UILayer/MainContent/CenterPanel/MatchButton
@onready var matching_anim: Control = $UILayer/MainContent/CenterPanel/MatchingAnimation
@onready var opponent_preview: PanelContainer = $UILayer/MainContent/CenterPanel/OpponentPreview
@onready var leaderboard_list: VBoxContainer = $UILayer/MainContent/RightPanel/LeaderboardList/LeaderboardVBox
@onready var match_result_panel: PanelContainer = $PopupLayer/MatchResultPanel

func _ready() -> void:
    _setup_styles()
    _update_player_info()
    _update_daily_rewards()
    _update_leaderboard()
    _update_deck_preview()
    _update_magic_coins()
    
    back_btn.pressed.connect(_on_back_pressed)
    match_btn.pressed.connect(_on_match_pressed)
    update_deck_btn.pressed.connect(_on_update_deck_pressed)
    PVPManager.match_found.connect(_on_match_found)
    PVPManager.match_result.connect(_on_match_result)
    PVPManager.daily_reward_updated.connect(_on_daily_reward_updated)

func _setup_styles() -> void:
    ## 暗色竞技主题
    var bg: ColorRect = $BackgroundLayer/ColorRect
    bg.color = Color(0.12, 0.08, 0.08, 1.0)
    
    title_label.text = "竞技场"
    title_label.add_theme_font_size_override("font_size", 36)
    title_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
    
    ## 个人信息卡
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.18, 0.14, 0.12, 1.0)
    card_style.border_color = Color(0.6, 0.45, 0.15, 1.0)
    card_style.border_width_left = 2
    card_style.border_width_top = 2
    card_style.border_width_right = 2
    card_style.border_width_bottom = 3
    card_style.corner_radius_top_left = 12
    card_style.corner_radius_top_right = 12
    card_style.corner_radius_bottom_left = 12
    card_style.corner_radius_bottom_right = 12
    card_style.shadow_color = Color(0.6, 0.45, 0.15, 0.15)
    card_style.shadow_size = 10
    card_style.shadow_offset = Vector2(0, 4)
    player_card.add_theme_stylebox_override("panel", card_style)

func _update_player_info() -> void:
    var stats: Dictionary = PVPManager.get_stats()
    
    net_wins_badge.text = "净胜场: %d" % stats["net_wins"]
    net_wins_badge.add_theme_font_size_override("font_size", 24)
    net_wins_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
    
    wins_label.text = "胜场: %d" % stats["wins"]
    losses_label.text = "败场: %d" % stats["losses"]
    
    ## 连胜
    var history: Array = stats.get("history", [])
    var streak: int = 0
    for record in history:
        if record.get("result") == "win":
            streak += 1
        else:
            break
    streak_label.text = "连胜: %d" % streak
    
    for label in [wins_label, losses_label, streak_label]:
        label.add_theme_font_size_override("font_size", 13)
        label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75, 1))

func _update_daily_rewards() -> void:
    var stats: Dictionary = PVPManager.get_stats()
    var remaining: int = stats.get("remaining_rewards", 5)
    
    ## 更新5个小圆点
    for i in range(DAILY_MAX_REWARDS):
        var dot: ColorRect = daily_reward_dots.get_child(i) if i < daily_reward_dots.get_child_count() else null
        if dot == null:
            dot = ColorRect.new()
            dot.custom_minimum_size = Vector2(16, 16)
            daily_reward_dots.add_child(dot)
        
        if i < remaining:
            dot.color = Color(0.3, 0.8, 0.4, 1.0)   # 绿色（可领取）
        else:
            dot.color = Color(0.4, 0.4, 0.42, 1.0)   # 灰色（已用完）

func _update_magic_coins() -> void:
    var stats: Dictionary = PVPManager.get_stats()
    magic_coin_label.text = "魔城币: %d" % stats["magic_coins"]
    magic_coin_label.add_theme_font_size_override("font_size", 16)
    magic_coin_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.8, 1))  # 紫色魔城币

func _on_daily_reward_updated(remaining: int) -> void:
    _update_daily_rewards()
    _update_magic_coins()

func _update_leaderboard() -> void:
    for child in leaderboard_list.get_children():
        child.queue_free()
    
    var entries: Array[Dictionary] = PVPManager.get_leaderboard()
    
    for entry in entries:
        var row := _create_leaderboard_row(entry)
        leaderboard_list.add_child(row)

func _create_leaderboard_row(entry: Dictionary) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 40)
    row.add_theme_constant_override("separation", 12)
    
    ## 排名
    var rank_label := Label.new()
    rank_label.text = "#%d" % entry["rank"]
    rank_label.custom_minimum_size = Vector2(40, 0)
    rank_label.add_theme_font_size_override("font_size", 14)
    if entry.get("is_player", false):
        rank_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
    else:
        rank_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72, 1))
    row.add_child(rank_label)
    
    ## 名字
    var name_label := Label.new()
    name_label.text = entry["name"]
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override("font_size", 14)
    if entry.get("is_player", false):
        name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9, 1))
    else:
        name_label.add_theme_color_override("font_color", Color(0.75, 0.73, 0.7, 1))
    row.add_child(name_label)
    
    ## 净胜场
    var net_label := Label.new()
    net_label.text = "%d胜/%d负" % [entry["wins"], entry["losses"]]
    net_label.custom_minimum_size = Vector2(100, 0)
    net_label.add_theme_font_size_override("font_size", 12)
    net_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75, 0.8))
    row.add_child(net_label)
    
    ## 净胜值
    var net_value := Label.new()
    net_value.text = "净%d" % entry["net_wins"]
    net_value.custom_minimum_size = Vector2(50, 0)
    net_value.add_theme_font_size_override("font_size", 14)
    net_value.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4, 1))
    row.add_child(net_value)
    
    ## 高亮玩家行
    if entry.get("is_player", false):
        var bg := StyleBoxFlat.new()
        bg.bg_color = Color(0.25, 0.2, 0.15, 0.5)
        bg.corner_radius_top_left = 6
        bg.corner_radius_top_right = 6
        bg.corner_radius_bottom_left = 6
        bg.corner_radius_bottom_right = 6
        row.add_theme_stylebox_override("panel", bg)
    
    return row

func _update_deck_preview() -> void:
    ## ... 类似之前 ...
    pass

func _on_match_pressed() -> void:
    AudioManager.play_ui("confirm")
    
    var deck: Dictionary = PVPManager.get_deck_snapshot()
    if deck.is_empty():
        _show_confirm_dialog("请先设置PVP队伍", "你还没有设置PVP对战用的队伍，是否前往选人界面设置？")
        return
    
    match_btn.visible = false
    matching_anim.visible = true
    opponent_preview.visible = false
    
    var tween := create_tween()
    tween.tween_callback(func():
        PVPManager.find_match()
    ).set_delay(randf_range(1.0, 2.0))

func _on_match_found(opponent: Dictionary) -> void:
    matching_anim.visible = false
    opponent_preview.visible = true
    _fill_opponent_preview(opponent)
    
    var start_btn := Button.new()
    start_btn.text = "开始对战"
    start_btn.custom_minimum_size = Vector2(200, 56)
    _apply_primary_button_style(start_btn)
    start_btn.pressed.connect(func():
        _start_pvp_battle(opponent)
    )
    opponent_preview.add_child(start_btn)

func _fill_opponent_preview(opponent: Dictionary) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.22, 0.1, 0.1, 1.0)
    style.border_color = Color(0.8, 0.3, 0.3, 1.0)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    opponent_preview.add_theme_stylebox_override("panel", style)
    
    for child in opponent_preview.get_children():
        if not child is Button:
            child.queue_free()
    
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    opponent_preview.add_child(vbox)
    
    var name_label := Label.new()
    name_label.text = opponent.get("name", "???")
    name_label.add_theme_font_size_override("font_size", 20)
    name_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(name_label)
    
    var net_label := Label.new()
    net_label.text = "净胜场: %d" % opponent.get("net_wins", 0)
    net_label.add_theme_font_size_override("font_size", 16)
    net_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
    net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(net_label)

func _start_pvp_battle(opponent: Dictionary) -> void:
    GameManager.pvp_opponent = opponent
    GameManager.is_pvp_mode = true
    TransitionManager.switch_scene("res://scenes/battle/battle_scene.tscn", "run_to_battle")

func _on_match_result(won: bool, net_wins: int, magic_coins_earned: int) -> void:
    match_result_panel.visible = true
    
    var title: Label = match_result_panel.get_node("TitleLabel")
    var net_label: Label = match_result_panel.get_node("NetWinsLabel")
    var coin_label: Label = match_result_panel.get_node("CoinLabel")
    
    if won:
        title.text = "胜利！"
        title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4, 1))
        
        if magic_coins_earned > 0:
            coin_label.text = "+%d 魔城币" % magic_coins_earned
            coin_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.8, 1))
        else:
            coin_label.text = "今日奖励次数已用完"
            coin_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
    else:
        title.text = "失败"
        title.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
        coin_label.text = "胜败乃兵家常事"
        coin_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
    
    net_label.text = "当前净胜场: %d" % net_wins
    
    ## 动画
    match_result_panel.scale = Vector2(0.8, 0.8)
    match_result_panel.modulate.a = 0.0
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(match_result_panel, "scale", Vector2.ONE, 0.35)
    tween.parallel().tween_property(match_result_panel, "modulate:a", 1.0, 0.3)
    
    await get_tree().create_timer(3.0).timeout
    TransitionManager.switch_scene("res://scenes/pvp/pvp_lobby.tscn", "fade")

func _on_update_deck_pressed() -> void:
    AudioManager.play_ui("click")
    PVPManager.update_deck_snapshot()
    _update_deck_preview()
    _show_toast("PVP队伍已更新")

func _on_back_pressed() -> void:
    AudioManager.play_ui("cancel")
    TransitionManager.switch_scene("res://scenes/menu/menu.tscn", "fade")

func _apply_primary_button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.8, 0.3, 0.3, 1.0)
    normal.border_color = Color(0.7, 0.2, 0.2, 1.0)
    normal.corner_radius_top_left = 8
    normal.corner_radius_top_right = 8
    normal.corner_radius_bottom_left = 8
    normal.corner_radius_bottom_right = 8
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_color_override("font_color", Color.WHITE)

func _show_toast(text: String) -> void:
    var toast := Label.new()
    toast.text = text
    toast.position = Vector2(540, 80)
    toast.z_index = 200
    toast.add_theme_font_size_override("font_size", 14)
    toast.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4, 1))
    add_child(toast)
    
    var tween := create_tween()
    tween.tween_property(toast, "modulate:a", 0.0, 1.5).set_delay(0.5)
    tween.finished.connect(func(): toast.queue_free())

func _show_confirm_dialog(title: String, message: String) -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = title
    dialog.dialog_text = message
    dialog.ok_button_text = "前往设置"
    dialog.cancel_button_text = "取消"
    dialog.confirmed.connect(func():
        TransitionManager.switch_scene("res://scenes/hero_select/hero_select.tscn", "fade")
    )
    add_child(dialog)
    dialog.popup_centered()
```

---

## Step 3：主菜单入口

```gdscript
## menu.gd

func _setup_menu_buttons() -> void:
    ## ... 原有按钮 ...
    
    var pvp_btn := Button.new()
    pvp_btn.text = "竞技场"
    pvp_btn.custom_minimum_size = Vector2(200, 50)
    _apply_secondary_button_style(pvp_btn)
    pvp_btn.pressed.connect(_on_pvp_pressed)
    menu_buttons_container.add_child(pvp_btn)

func _on_pvp_pressed() -> void:
    AudioManager.play_ui("confirm")
    TransitionManager.switch_scene("res://scenes/pvp/pvp_lobby.tscn", "menu_to_hero_select")
```

---

## Step 4：PVP战斗适配

```gdscript
## battle_scene.gd

func _ready() -> void:
    if GameManager.is_pvp_mode:
        _setup_pvp_battle()
    else:
        _setup_pve_battle()

func _setup_pvp_battle() -> void:
    var opponent: Dictionary = GameManager.pvp_opponent
    var my_deck: Dictionary = PVPManager.get_deck_snapshot()
    
    ## 我方阵容
    var hero_card := _create_card_from_deck(my_deck, true)
    $HUDLayer/LeftSide.add_child(hero_card)
    
    ## 敌方阵容
    var enemy_hero := _create_card_from_deck(opponent, false)
    $HUDLayer/RightSide.add_child(enemy_hero)
    
    _is_enemy_ai = true
    _ai_difficulty = opponent.get("ai_difficulty", 0.5)

func _on_battle_ended(battle_result: Dictionary) -> void:
    if GameManager.is_pvp_mode:
        var won: bool = battle_result.get("winner") == "player"
        PVPManager.calculate_match_result(won)
        
        GameManager.is_pvp_mode = false
        GameManager.pvp_opponent = {}
    else:
        ## 原有PVE结算
        pass
```

---

## 测试验收标准

### PVPManager
- [ ] 每日首次进入PVP大厅时检查日重置，重置领奖次数为5
- [ ] 跨天后再次进入，领奖次数自动重置
- [ ] `find_match()` 根据玩家净胜场匹配相近对手
- [ ] 胜利：胜场+1，净胜场重算，发放魔城币（限每日5次）
- [ ] 连胜2场以上额外+5魔城币
- [ ] 失败：败场+1，净胜场重算，无惩罚
- [ ] 净胜场 = max(0, 胜场 - 败场)
- [ ] 历史记录保留最近10条
- [ ] 排行榜按净胜场降序排列

### PVP大厅UI
- [ ] 主菜单有"竞技场"按钮
- [ ] 暗色竞技主题（暗褐底+金色标题+紫色魔城币）
- [ ] 左侧面板显示：头像、净胜场（金色大字号）、胜/败/连胜
- [ ] 魔城币显示在顶部（紫色）
- [ ] 5个小圆点显示今日剩余奖励次数（绿=可领，灰=已用完）
- [ ] 中间"寻找对手"按钮+匹配动画
- [ ] 匹配成功后显示对手预览（名字+净胜场+开始对战按钮）
- [ ] 右侧排行榜：排名/名字/胜败/净胜，玩家行高亮
- [ ] 更新队伍快照按钮
- [ ] 无快照时点击匹配提示前往设置

### 战斗结算
- [ ] 胜利后显示结算面板：胜利/当前净胜场/魔城币获得
- [ ] 3秒后自动返回PVP大厅
- [ ] 返回后排行榜和个人信息已更新
- [ ] 魔城币总数正确累加

### 存档
- [ ] PVP数据（胜/败/净胜/魔城币/领奖次数/历史）持久化
- [ ] 重启游戏后数据保留
- [ ] 日重置逻辑正确（按日期字符串比对）
