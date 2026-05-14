# PVP异步镜像对战任务卡（属性快照+AI）

## 核心设计
异步PVP无需实时服务器：
1. **爬塔时保存影子**：每层战斗结束后，把玩家当前属性/伙伴/战斗风格存为"影子"
2. **虚拟档案池**：所有同层影子汇聚到池中
3. **PVP匹配**：玩家B匹配时，从同层影子池随机抽取一个作为AI对手
4. **AI对战**：用 `BattleEngine` 让影子AI（固定策略）vs 玩家B战斗
5. **结果结算**：胜负计入净胜场，给魔城币

## 现有基础
- `scripts/systems/virtual_archive_pool.gd` — 虚拟档案池（已存玩家爬塔数据）
- `scripts/systems/pvp_opponent_generator.gd` — PVP对手生成
- `scripts/systems/pvp_director.gd` — PVP导演（胜负判定）
- `scripts/core/battle_engine.gd` — 战斗引擎（复用）
- `scripts/systems/battle_playback_recorder.gd` — 战斗录像（可选复用）

## 修改步骤

### Step 1：扩展影子数据结构

**文件：`scripts/systems/virtual_archive_pool.gd`**

影子数据包含：
```gdscript
class_name ShadowData
extends RefCounted

var user_id: String
var floor: int
var hero_config: Dictionary       # 英雄五维/HP/技能
var partner_configs: Array        # 伙伴列表（config_id + level + favored_attr）
var combat_style_tags: Array      # 战斗风格标签 ["aggressive", "defensive", "balanced"]
var win_rate: float               # 该影子主人的胜率（用于匹配权重）
var timestamp: int                # 创建时间

func to_dict() -> Dictionary:
    return {
        "user_id": user_id,
        "floor": floor,
        "hero_config": hero_config,
        "partner_configs": partner_configs,
        "combat_style_tags": combat_style_tags,
        "win_rate": win_rate,
        "timestamp": timestamp
    }
```

### Step 2：爬塔时自动保存影子

**文件：`scripts/systems/run_controller.gd`**

在 `_finish_node_execution()` 中，战斗节点完成后保存影子：
```gdscript
func _finish_node_execution() -> void:
    # ... 原有层推进逻辑 ...
    
    # 如果是战斗节点，保存影子到虚拟档案池
    if executed_node_type == NodeType.BATTLE:
        _save_shadow_to_pool()
    
    # 层入口存档
    _save_at_floor_entrance()

func _save_shadow_to_pool() -> void:
    var shadow := ShadowData.new()
    shadow.user_id = SaveManager.get_user_id()
    shadow.floor = _current_floor
    shadow.hero_config = _character_manager.get_hero_snapshot()
    shadow.partner_configs = _character_manager.get_partners_snapshot()
    shadow.combat_style_tags = _derive_combat_style()
    shadow.win_rate = _calculate_recent_win_rate()
    shadow.timestamp = Time.get_unix_time_from_system()
    
    VirtualArchivePool.add_shadow(shadow)
    print("[RunController] 影子已保存: user=%s, floor=%d" % [shadow.user_id, shadow.floor])

func _derive_combat_style() -> Array[String]:
    var tags: Array[String] = []
    var hero := _character_manager.get_hero()
    if hero.current_str > hero.current_vit:
        tags.append("aggressive")
    elif hero.current_vit > hero.current_str:
        tags.append("defensive")
    else:
        tags.append("balanced")
    return tags
```

### Step 3：虚拟档案池管理影子

**文件：`scripts/systems/virtual_archive_pool.gd`**

```gdscript
class_name VirtualArchivePool
extends Node

var _shadows: Array[ShadowData] = []
var _max_shadows_per_floor: int = 50  # 每层最多存50个影子

func add_shadow(shadow: ShadowData) -> void:
    # 同层同用户去重：先删除旧影子
    _shadows = _shadows.filter(func(s): return not (s.user_id == shadow.user_id and s.floor == shadow.floor))
    _shadows.append(shadow)
    
    # 同层超过50个时，删除最旧的
    var floor_shadows := _shadows.filter(func(s): return s.floor == shadow.floor)
    if floor_shadows.size() > _max_shadows_per_floor:
        floor_shadows.sort_custom(func(a, b): return a.timestamp < b.timestamp)
        var oldest := floor_shadows[0]
        _shadows.erase(oldest)
    
    print("[VirtualArchivePool] 影子池大小: %d" % _shadows.size())

func get_random_shadow_for_floor(floor: int, exclude_user_id: String = "") -> ShadowData:
    var candidates := _shadows.filter(func(s): return s.floor == floor and s.user_id != exclude_user_id)
    if candidates.is_empty():
        return null
    
    # 加权随机：胜率高的影子更容易被匹配（增加挑战性）
    var total_weight: float = 0.0
    for s in candidates:
        total_weight += s.win_rate + 0.1  # +0.1避免0权重
    
    var roll := randf() * total_weight
    var cumulative: float = 0.0
    for s in candidates:
        cumulative += s.win_rate + 0.1
        if roll <= cumulative:
            return s
    
    return candidates[0]  # fallback

func save_shadows_to_disk() -> void:
    var data := _shadows.map(func(s): return s.to_dict())
    var file := FileAccess.open("user://shadow_pool.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func load_shadows_from_disk() -> void:
    if not FileAccess.file_exists("user://shadow_pool.json"):
        return
    var file := FileAccess.open("user://shadow_pool.json", FileAccess.READ)
    var json := JSON.new()
    json.parse(file.get_as_text())
    # 反序列化...
```

### Step 4：PVP对手生成（影子AI）

**文件：`scripts/systems/pvp_opponent_generator.gd`**

```gdscript
func generate_pvp_opponent(player_floor: int, player_user_id: String) -> Dictionary:
    # 先从影子池找同层对手
    var shadow := VirtualArchivePool.get_random_shadow_for_floor(player_floor, player_user_id)
    
    if shadow != null:
        print("[PvpOpponentGenerator] 使用影子对手: user=%s, floor=%d" % [shadow.user_id, shadow.floor])
        return _build_opponent_from_shadow(shadow)
    
    # 影子池为空，fallback到固定AI模板
    print("[PvpOpponentGenerator] 影子池为空，使用固定AI")
    return _build_default_ai_opponent(player_floor)

func _build_opponent_from_shadow(shadow: ShadowData) -> Dictionary:
    return {
        "type": "shadow",
        "user_id": shadow.user_id,
        "hero": shadow.hero_config.duplicate(),
        "partners": shadow.partner_configs.duplicate(),
        "combat_style": shadow.combat_style_tags.duplicate(),
        "is_ai": true  # 标记为AI控制
    }

func _build_default_ai_opponent(floor: int) -> Dictionary:
    # 固定AI模板（已有代码）
    var hero_config := _get_default_hero_for_floor(floor)
    var partners := _get_default_partners_for_floor(floor)
    return {
        "type": "default_ai",
        "hero": hero_config,
        "partners": partners,
        "combat_style": ["balanced"],
        "is_ai": true
    }
```

### Step 5：影子AI战斗策略

**文件：`scripts/systems/shadow_ai_controller.gd`（新建）**

```gdscript
class_name ShadowAIController
extends Node

var _combat_style: Array[String] = []

func setup(style_tags: Array[String]) -> void:
    _combat_style = style_tags.duplicate()

func decide_action(hero, enemy, partners) -> Dictionary:
    var hero_hp_ratio: float = float(hero.current_hp) / hero.max_hp
    var enemy_hp_ratio: float = float(enemy.current_hp) / enemy.max_hp
    
    # 激进型：优先攻击，血量低也不退缩
    if "aggressive" in _combat_style:
        if hero_hp_ratio > 0.3:
            return {"action": "attack", "skill": _select_best_skill(hero, enemy)}
        else:
            # 血量极低时50%概率防御
            return {"action": "defend" if randf() < 0.5 else "attack"}
    
    # 防御型：血量低时优先防御/恢复
    elif "defensive" in _combat_style:
        if hero_hp_ratio < 0.4:
            return {"action": "defend"}
        elif hero_hp_ratio < 0.6 and enemy_hp_ratio < 0.3:
            return {"action": "attack", "skill": _select_best_skill(hero, enemy)}
        else:
            return {"action": "attack"}
    
    # 平衡型：标准策略
    else:
        if hero_hp_ratio < 0.3:
            return {"action": "defend"}
        elif enemy_hp_ratio < 0.2:
            return {"action": "attack", "skill": _select_best_skill(hero, enemy)}
        else:
            return {"action": "attack"}

func _select_best_skill(hero, enemy) -> String:
    # 简单策略：选择伤害最高的可用技能
    return ""  # 默认普攻
```

### Step 6：PVP导演器接入影子AI

**文件：`scripts/systems/pvp_director.gd`**

```gdscript
func start_pvp_battle(player_hero, opponent_data: Dictionary) -> void:
    var is_shadow: bool = opponent_data.get("type", "") == "shadow"
    
    if is_shadow:
        # 影子AI战斗
        var ai_controller := ShadowAIController.new()
        ai_controller.setup(opponent_data.get("combat_style", ["balanced"]))
        
        # 用 BattleEngine 执行战斗
        var battle_engine := BattleEngine.new()
        battle_engine.set_ai_controller(ai_controller)  # 让AI控制对手
        var result := battle_engine.execute_battle(player_hero, opponent_data.get("hero"), opponent_data.get("partners", []))
        
        _process_battle_result(result, opponent_data)
    else:
        # 固定AI战斗（原有逻辑）
        _start_default_ai_battle(player_hero, opponent_data)

func _process_battle_result(result: Dictionary, opponent_data: Dictionary) -> void:
    var winner: String = result.get("winner", "")
    var is_player_win: bool = winner == "player"
    
    # 更新净胜场
    _update_net_wins(is_player_win)
    
    # 胜利给魔城币（20/场，上限5场=100/日）
    if is_player_win:
        var daily_wins := _get_daily_pvp_wins()
        if daily_wins < 5:
            var current_coin := ConfigManager.get_mocheng_coin_total()
            ConfigManager.set_mocheng_coin_total(current_coin + 20)
            SaveManager.save_mocheng_coin(current_coin + 20)
            _increment_daily_pvp_wins()
    
    # 发射信号让UI显示结算
    EventBus.emit_signal("pvp_battle_ended", result, opponent_data)
```

### Step 7：PVP大厅匹配逻辑

**文件：`scenes/pvp/pvp_lobby.gd`**

```gdscript
func _on_match_pressed() -> void:
    AudioManager.play_sfx("ui_click")
    
    # 获取玩家当前层数（从存档读取）
    var save_data := SaveManager.load_latest_run()
    var player_floor := save_data.get("current_floor", 1)
    var player_user_id := SaveManager.get_user_id()
    
    # 生成对手
    var opponent := PvpOpponentGenerator.generate_pvp_opponent(player_floor, player_user_id)
    
    if opponent.is_empty():
        print("[PvpLobby] 匹配失败")
        return
    
    # 显示对手信息
    _show_match_result(opponent)
    
    # 玩家点击"开始战斗"
    start_battle_button.pressed.connect(_start_pvp_battle.bind(opponent))

func _start_pvp_battle(opponent: Dictionary) -> void:
    # 加载玩家英雄
    var player_hero := _load_player_hero()
    
    # 启动PVP战斗
    PvpDirector.start_pvp_battle(player_hero, opponent)
```

### Step 8：魔城币每日上限检查

**文件：`scripts/systems/pvp_director.gd`**

```gdscript
func _get_daily_pvp_wins() -> int:
    var today := Time.get_date_string_from_system()
    var key := "pvp_wins_%s_%s" % [SaveManager.get_user_id(), today]
    return SaveManager.get_daily_counter(key)

func _increment_daily_pvp_wins() -> void:
    var today := Time.get_date_string_from_system()
    var key := "pvp_wins_%s_%s" % [SaveManager.get_user_id(), today]
    SaveManager.increment_daily_counter(key)
```

## 文件清单
| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/data/shadow_data.gd` | 新建，影子数据结构 |
| 2 | `scripts/systems/virtual_archive_pool.gd` | 扩展影子管理（保存/读取/加权匹配） |
| 3 | `scripts/systems/run_controller.gd` | 战斗节点后自动保存影子 |
| 4 | `scripts/systems/pvp_opponent_generator.gd` | 从影子池生成对手 |
| 5 | `scripts/systems/shadow_ai_controller.gd` | 新建，影子AI决策逻辑 |
| 6 | `scripts/systems/pvp_director.gd` | 接入影子AI战斗 |
| 7 | `scenes/pvp/pvp_lobby.gd` | 匹配逻辑+显示对手信息 |
| 8 | `scripts/systems/save_manager.gd` | 新增每日计数器 |

## 验收标准
- [ ] 爬塔战斗后影子自动保存到虚拟档案池
- [ ] PVP匹配时从同层影子池抽取对手（排除自己）
- [ ] 影子池为空时fallback到固定AI
- [ ] 影子AI按战斗风格标签执行策略（激进/防御/平衡）
- [ ] PVP胜利给20魔城币，每日上限5场=100币
- [ ] 净胜场正确更新（最低0，无负数）
- [ ] PVP战斗结束后显示结算面板（胜负+魔城币获得）
