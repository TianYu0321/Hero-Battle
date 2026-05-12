# Phase 5-A 任务卡：局内PVP修正（档案影子匹配 + 数据架构）

> 只做局内PVP（第10/20层），局外PVP大厅后续排期。
> 核心改动：PVP对手从"复制当前玩家生成AI"改为"从通关档案匹配影子"。

---

## 一、数据存储架构（需记录到文档）

### 问题
用户问：不同玩家的数据怎么存放到一个地方？是通过数据库吗？

### 方案（分阶段）

**Phase A（当前单机模式）**：
- 本地预置一批 **虚拟玩家档案**（`resources/virtual_archives/`）
- 这些档案是开发者/测试者通关后导出的真实通关记录（包含英雄配置、五维、伙伴、层数）
- PVP匹配时从 `virtual_archives/` + 本地 `archive.json` 中随机抽取
- 无联机、无数据库，纯本地JSON

**Phase B（后续联机扩展）**：
- 如需真人对战，需要后端服务器 + 数据库（推荐 PostgreSQL / SQLite）
- 玩家通关后档案自动上传到服务器，进入"影子池"
- PVP匹配时从服务器影子池按层数/胜场筛选
- 文档中预留接口：`ArchiveSync.upload(archive)` / `ArchiveSync.download_opponent(floor)`

**当前决策**：先实现Phase A，在文档中记录Phase B扩展路径。

---

## 二、局内PVP流程（v2.0修正版）

```
第10层/20层 → 显示"PVP对战"选项按钮
→ 玩家点击 → 系统静默匹配影子对手（不显示对手信息界面，直接进战斗）
    → 从 virtual_archives/ 和 archive.json 中随机选一个 "final_turn >= 当前层" 且 "完整通关" 的档案
    → 没有匹配 → fallback到AI（固定角色hero_warrior + 随机Lv1伙伴）
→ BattleEngine 执行完整战斗
→ 弹出战斗摘要面板（胜负、回合数、对手名、奖励信息）
→ 玩家点击确认 → 推进到下一层
```

### 局内PVP奖励（v2.0规格）

| 结果 | 金币 | 全属性 | 事件透视 |
|:---:|:---:|:---:|:---:|
| **胜利** | +150 | +15 | 无 |
| **失败** | +50 | +5 | +5次 |

- **无魔城币**（魔城币仅局外PVP发放）
- **无净胜场**（净胜场仅局外PVP计算）
- 失败不扣减任何属性（最低为0）

---

## 三、修复步骤

### Step 1：预置虚拟玩家档案（自动生成脚本）

**新建目录：`resources/virtual_archives/`**

由本地agent运行以下脚本自动生成3个预置档案：

```gdscript
# tools/generate_virtual_archives.gd
extends SceneTree

func _init():
    var base_path: String = "res://resources/virtual_archives/"
    
    var archives: Array[Dictionary] = [
        {
            "archive_id": "VIR_001",
            "hero_config_id": 1,
            "hero_name": "剑影",
            "final_turn": 30,
            "final_score": 185,
            "final_grade": "S",
            "attr_snapshot_vit": 45,
            "attr_snapshot_str": 50,
            "attr_snapshot_agi": 38,
            "attr_snapshot_tec": 42,
            "attr_snapshot_mnd": 35,
            "max_hp_reached": 120,
            "partner_count": 3,
            "partners": [
                {"partner_config_id": 1001, "current_level": 4, "favored_attr": 1, "is_active": true},
                {"partner_config_id": 1002, "current_level": 3, "favored_attr": 3, "is_active": true},
                {"partner_config_id": 1003, "current_level": 3, "favored_attr": 2, "is_active": true}
            ],
            "battle_win_count": 15,
            "elite_win_count": 3,
            "gold_earned_total": 850,
            "training_count": 25,
            "created_at": Time.get_unix_time_from_system() - 86400 * 7,
            "is_fixed": true,
            "is_virtual": true
        },
        {
            "archive_id": "VIR_002",
            "hero_config_id": 2,
            "hero_name": "风行者",
            "final_turn": 30,
            "final_score": 162,
            "final_grade": "A",
            "attr_snapshot_vit": 38,
            "attr_snapshot_str": 42,
            "attr_snapshot_agi": 50,
            "attr_snapshot_tec": 35,
            "attr_snapshot_mnd": 30,
            "max_hp_reached": 110,
            "partner_count": 2,
            "partners": [
                {"partner_config_id": 1004, "current_level": 3, "favored_attr": 4, "is_active": true},
                {"partner_config_id": 1001, "current_level": 2, "favored_attr": 1, "is_active": true}
            ],
            "battle_win_count": 12,
            "elite_win_count": 2,
            "gold_earned_total": 720,
            "training_count": 22,
            "created_at": Time.get_unix_time_from_system() - 86400 * 3,
            "is_fixed": true,
            "is_virtual": true
        },
        {
            "archive_id": "VIR_003",
            "hero_config_id": 3,
            "hero_name": "暗影刺客",
            "final_turn": 30,
            "final_score": 145,
            "final_grade": "A",
            "attr_snapshot_vit": 30,
            "attr_snapshot_str": 48,
            "attr_snapshot_agi": 45,
            "attr_snapshot_tec": 40,
            "attr_snapshot_mnd": 25,
            "max_hp_reached": 100,
            "partner_count": 3,
            "partners": [
                {"partner_config_id": 1002, "current_level": 4, "favored_attr": 3, "is_active": true},
                {"partner_config_id": 1005, "current_level": 2, "favored_attr": 5, "is_active": true},
                {"partner_config_id": 1003, "current_level": 2, "favored_attr": 2, "is_active": true}
            ],
            "battle_win_count": 14,
            "elite_win_count": 4,
            "gold_earned_total": 680,
            "training_count": 20,
            "created_at": Time.get_unix_time_from_system() - 86400 * 1,
            "is_fixed": true,
            "is_virtual": true
        }
    ]
    
    # 确保目录存在
    var dir: DirAccess = DirAccess.open("res://")
    if not dir.dir_exists("resources/virtual_archives"):
        dir.make_dir_recursive("resources/virtual_archives")
    
    for archive in archives:
        var file_path: String = base_path + archive["archive_id"] + ".json"
        var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
        if file != null:
            file.store_string(JSON.stringify(archive, "\t"))
            file.close()
            print("已生成虚拟档案: %s" % file_path)
        else:
            push_error("无法写入文件: %s" % file_path)
    
    print("虚拟档案生成完成，共 %d 个" % archives.size())
    quit()
```

**执行方式**：在 Godot 项目中新建 `tools/generate_virtual_archives.gd`，然后命令行运行：
```bash
godot --headless --script tools/generate_virtual_archives.gd
```

### Step 2：新建 VirtualArchivePool

**新建文件：`scripts/systems/virtual_archive_pool.gd`**

```gdscript
class_name VirtualArchivePool
extends Node

var _virtual_archives: Array[Dictionary] = []
var _local_archives: Array[Dictionary] = []

func _ready() -> void:
    _load_virtual_archives()

func _load_virtual_archives() -> void:
    var dir_path: String = "res://resources/virtual_archives/"
    var dir: DirAccess = DirAccess.open(dir_path)
    if dir == null:
        push_warning("[VirtualArchivePool] 虚拟档案目录不存在: %s" % dir_path)
        return
    dir.list_dir_begin()
    var file_name: String = dir.get_next()
    while not file_name.is_empty():
        if file_name.ends_with(".json"):
            var file_path: String = dir_path + file_name
            var data = ModelsSerializer.load_json_file(file_path)
            if data != null and not data.is_empty():
                data["_source"] = "virtual"
                _virtual_archives.append(data)
        file_name = dir.get_next()
    dir.list_dir_end()
    print("[VirtualArchivePool] 加载虚拟档案: %d个" % _virtual_archives.size())

func refresh_local_archives() -> void:
    _local_archives = SaveManager.load_archives("date", 9999, "")
    print("[VirtualArchivePool] 加载本地档案: %d个" % _local_archives.size())

func find_opponent_for_floor(floor: int) -> Dictionary:
    refresh_local_archives()
    
    var candidates: Array[Dictionary] = []
    
    # 从本地档案筛选（final_turn >= floor 且完整通关）
    for archive in _local_archives:
        if archive.get("final_turn", 0) >= floor and archive.get("is_fixed", false):
            candidates.append(archive)
    
    # 从虚拟档案筛选
    for archive in _virtual_archives:
        if archive.get("final_turn", 0) >= floor:
            candidates.append(archive)
    
    if candidates.is_empty():
        print("[VirtualArchivePool] 无匹配档案，返回空")
        return {}
    
    # 随机选一个
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var idx: int = rng.randi() % candidates.size()
    var selected: Dictionary = candidates[idx]
    print("[VirtualArchivePool] 选中对手: %s (层数:%d, 来源:%s)" % [
        selected.get("hero_name", "???"),
        selected.get("final_turn", 0),
        selected.get("_source", "local")
    ])
    return selected
```

### Step 3：改造 PvpOpponentGenerator

**文件：`scripts/systems/pvp_opponent_generator.gd`**

新增 `generate_opponent_from_archive(archive_data, turn_number)`：

```gdscript
func generate_opponent_from_archive(archive_data: Dictionary, turn_number: int) -> Dictionary:
    print("[PvpOpponentGenerator] 从档案生成对手: %s" % archive_data.get("hero_name", "???"))
    
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = archive_data.get("archive_id", "").hash() + turn_number
    
    # 从档案提取英雄属性
    var hero_stats: Dictionary = {
        "physique": archive_data.get("attr_snapshot_vit", 10),
        "strength": archive_data.get("attr_snapshot_str", 10),
        "agility": archive_data.get("attr_snapshot_agi", 10),
        "technique": archive_data.get("attr_snapshot_tec", 10),
        "spirit": archive_data.get("attr_snapshot_mnd", 10),
    }
    var hero_config_id: int = archive_data.get("hero_config_id", 1)
    var hero_id: String = ConfigManager.get_hero_id_by_config_id(hero_config_id)
    if hero_id.is_empty():
        hero_id = "hero_warrior"
    
    var ai_hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)
    ai_hero.hp = ai_hero.max_hp
    ai_hero.name = archive_data.get("hero_name", "影子斗士")
    
    # 从档案提取伙伴
    var archive_partners: Array = archive_data.get("partners", [])
    var ai_partners: Array = []
    for p_data in archive_partners:
        var pid: int = p_data.get("partner_config_id", 1001)
        var pcfg: Dictionary = ConfigManager.get_partner_config(str(pid))
        var p_name: String = pcfg.get("name", "伙伴")
        var p_level: int = p_data.get("current_level", 1)
        # 伙伴属性按等级缩放（Lv1基准 × 等级系数）
        var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(str(pid))
        var base_stats: Dictionary = {
            "physique": assist_cfg.get("base_physique", 10),
            "strength": assist_cfg.get("base_strength", 10),
            "agility": assist_cfg.get("base_agility", 10),
            "technique": assist_cfg.get("base_technique", 10),
            "spirit": assist_cfg.get("base_spirit", 10),
        }
        var level_multiplier: float = 1.0 + (p_level - 1) * 0.2  # Lv2=1.2, Lv3=1.4...
        for key in base_stats.keys():
            base_stats[key] = int(base_stats[key] * level_multiplier)
        ai_partners.append(PartnerAssist.make_partner_battle_unit(str(pid), p_name, base_stats))
    
    # 生成玩家镜像（和原来一样）
    var player_hero: Dictionary = _get_current_player_hero()  # 需要传入或从全局获取
    var player_battle_unit: Dictionary = _generate_player_enemy(player_hero)
    
    return {
        "hero": ai_hero,
        "enemies": [player_battle_unit],
        "partners": ai_partners,
        "battle_seed": rng.seed,
        "playback_mode": "fast_forward",
        "opponent_name": archive_data.get("hero_name", "影子斗士"),
        "opponent_source": "archive",
    }
```

**修改 `generate_opponent()` 入口**：

```gdscript
func generate_opponent(player_state: Dictionary, turn_number: int, use_archive: bool = true) -> Dictionary:
    if use_archive:
        var archive_pool: VirtualArchivePool = get_node_or_null("/root/RunController/VirtualArchivePool")
        if archive_pool == null:
            archive_pool = VirtualArchivePool.new()
        var opponent_archive: Dictionary = archive_pool.find_opponent_for_floor(turn_number)
        if not opponent_archive.is_empty():
            return generate_opponent_from_archive(opponent_archive, turn_number)
        print("[PvpOpponentGenerator] 无档案匹配，fallback到AI生成")
    
    # fallback：原来的AI生成逻辑
    return _generate_ai_opponent(player_state, turn_number)
```

### Step 4：RunController PVP分支调用改造

**文件：`scripts/systems/run_controller.gd`**

在 `_process_node_result` 的 PVP 分支中，确保传入 `use_archive=true`：

```gdscript
elif _pending_node_type == NodePoolSystem.NodeType.PVP_CHECK:
    var pvp_director: PvpDirector = get_node_or_null("PvpDirector")
    if pvp_director != null:
        var pvp_config: Dictionary = {
            "turn_number": _run.current_turn,
            "player_gold": _run.gold_owned,
            "player_hp": _hero.current_hp,
            "player_hero": _hero_to_battle_dict(),
            "run_seed": _run.seed,
            "use_archive": true,  # 启用档案匹配
        }
        var pvp_result: Dictionary = pvp_director.execute_pvp(pvp_config)
        var won: bool = pvp_result.get("won", false)
        
        # --- 局内PVP奖励（v2.0规格）---
        if won:
            # 胜利：150金币 + 15全属性
            _process_reward({"type": "gold", "amount": 150})
            _character_manager.modify_hero_stats({
                1: 15, 2: 15, 3: 15, 4: 15, 5: 15
            })
            print("[RunController] 局内PVP胜利：金币+150，全属性+15")
        else:
            # 失败：50金币 + 5全属性 + 5次事件透视
            _process_reward({"type": "gold", "amount": 50})
            _character_manager.modify_hero_stats({
                1: 5, 2: 5, 3: 5, 4: 5, 5: 5
            })
            # TODO: 事件透视 buff（+5次）
            # _event_forecast_system.add_charges(5)
            print("[RunController] 局内PVP失败：金币+50，全属性+5，事件透视+5")
        
        # 记录胜负标记（供结算显示）
        if _run.current_turn == 10:
            _run.pvp_10th_result = 1 if won else 2
        elif _run.current_turn == 20:
            _run.pvp_20th_result = 1 if won else 2
    
    _finish_node_execution(result)
    return
```

**注意**：事件透视（+5次）需要事件系统支持。如果当前代码中没有事件透视机制，先标记 TODO，不影响PVP主体流程。

### Step 5：PvpDirector 支持档案匹配模式

**文件：`scripts/systems/pvp_director.gd`**

修改 `execute_pvp`，将对手信息传给 BattleSummaryPanel：

```gdscript
func execute_pvp(pvp_config: Dictionary) -> Dictionary:
    var turn_number: int = pvp_config.get("turn_number", 0)
    var use_archive: bool = pvp_config.get("use_archive", true)
    
    # 1. 生成对手
    var opponent_generator: PvpOpponentGenerator = PvpOpponentGenerator.new()
    var battle_config: Dictionary
    if use_archive:
        battle_config = opponent_generator.generate_opponent(pvp_config, turn_number, true)
    else:
        battle_config = opponent_generator.generate_opponent(pvp_config, turn_number, false)
    
    # 2. 构建 BattleEngine 配置
    var hero: Dictionary = battle_config.hero.duplicate(true)
    var enemies: Array[Dictionary] = battle_config.enemies.duplicate(true)
    var partners: Array[Dictionary] = battle_config.get("partners", []).duplicate(true)
    var config: Dictionary = {
        "hero": hero,
        "enemies": enemies,
        "partners": partners,
        "battle_seed": battle_config.get("battle_seed", 0),
        "turn_number": turn_number,
        "pvp_mode": true,
    }
    
    # 3~5. 保持原有战斗执行逻辑
    var battle_engine: BattleEngine = BattleEngine.new()
    battle_engine.name = "PvpBattleEngine"
    add_child(battle_engine)
    var result = battle_engine.execute_battle(config)
    
    # 6. 组装返回结果
    var won: bool = result.winner == "player"
    var return_data: Dictionary = {
        "won": won,
        "opponent_name": battle_config.get("opponent_name", "AI挑战者"),
        "opponent_source": battle_config.get("opponent_source", "ai"),
        "turns": result.turns_elapsed,
        "battle_result": result,
    }
    
    battle_engine.queue_free()
    return return_data
```

### Step 6：BattleSummaryPanel 显示对手来源

```gdscript
# battle_summary_panel.gd
func show_result(battle_result: Dictionary) -> void:
    visible = true
    ...
    var opponent_name: String = battle_result.get("opponent_name", "???")
    var opponent_source: String = battle_result.get("opponent_source", "AI")
    var source_text: String = "(档案影子)" if opponent_source == "archive" else "(AI)"
    enemy_name_label.text = "对手: %s %s" % [opponent_name, source_text]
    ...
```

---

## 四、数据架构文档记录

需要在 `Docs/` 下新建或更新文档，记录以下架构决策：

```markdown
## PVP数据架构（v2.0）

### 当前实现（Phase A - 单机模式）

**数据来源**：
- 本地 `archive.json`：玩家自己的通关档案
- `resources/virtual_archives/`：预置的虚拟玩家档案（JSON格式）

**匹配逻辑**：
1. PVP触发时（第10/20层），从本地档案 + 虚拟档案中筛选 `final_turn >= 当前层` 的记录
2. 随机抽取一条作为影子对手
3. 无匹配时fallback到AI生成

**存储格式**：
- 档案字段：hero_config_id, hero_name, final_turn, final_score, final_grade,
  attr_snapshot_vit/str/agi/tec/mnd, partner_count, partners[], is_fixed

### 未来扩展（Phase B - 联机模式）

**如需真人对战，需引入**：
- 后端服务器（REST API）
- 数据库（PostgreSQL / SQLite）存储玩家档案
- 影子池：所有玩家通关档案的聚合
- 匹配API：`POST /api/pvp/match {floor, net_wins}` → 返回对手档案
- 上传API：`POST /api/archive/upload {archive_data}`

**Godot端接口预留**：
```gdscript
class ArchiveSync:
    static func upload(archive: Dictionary) -> bool
    static func download_opponent(floor: int, net_wins: int) -> Dictionary
```

### 局内 vs 局外PVP区分

| 维度 | 局内PVP（第10/20层） | 局外PVP（PVP大厅） |
|:---|:---|:---|
| 入口 | 爬塔第10/20层选项按钮 | 主菜单"PVP对战"按钮 |
| 对手来源 | 档案影子 / AI fallback | 档案影子（按胜场匹配） |
| 战斗 | 完整BattleEngine | 完整BattleEngine |
| 魔城币 | ❌ 无 | ✅ 胜利+20，上限100/日 |
| 净胜场 | ❌ 无 | ✅ 胜场-败场 |
| 金币奖励 | ✅ 胜利+150 / 失败+50 | ❌ 无 |
| 属性奖励 | ✅ 胜利+15全属性 / 失败+5全属性 | ❌ 无 |
| 背景 | 爬塔背景 | 独立PVP背景 |
```

---

## 五、文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `resources/virtual_archives/` | 新建目录 | 由 `tools/generate_virtual_archives.gd` 生成3个预置档案 |
| 2 | `scripts/systems/virtual_archive_pool.gd` | 新建 | 虚拟档案池：加载、筛选、随机匹配 |
| 3 | `scripts/systems/pvp_opponent_generator.gd` | 修改 | 新增 `generate_opponent_from_archive()`，改造入口支持档案匹配 |
| 4 | `scripts/systems/pvp_director.gd` | 修改 | `execute_pvp` 支持 `use_archive` 参数，将对手信息传给UI |
| 5 | `scripts/systems/run_controller.gd` | 修改 | PVP分支：传入 `use_archive=true`，局内PVP奖励（胜利150+15 / 失败50+5+5透视） |
| 6 | `scenes/run_main/battle_summary_panel.gd` | 修改 | 显示对手名称和来源（"影子斗士(档案)" 或 "AI挑战者(AI)"） |
| 7 | `Docs/pvp-data-architecture.md` | 新建 | 记录数据架构决策和Phase B扩展路径 |

---

## 六、验收标准

### 局内PVP
- [ ] 第10层/20层点击"PVP对战"，控制台显示 `[VirtualArchivePool] 选中对手: XXX`
- [ ] 如果本地有通关档案，可能匹配到自己的档案或其他本地档案
- [ ] 如果没有档案匹配，控制台显示 `[PvpOpponentGenerator] 无档案匹配，fallback到AI生成`
- [ ] PVP胜利后：金币+150，五维各+15
- [ ] PVP失败后：金币+50，五维各+5
- [ ] 战斗摘要面板显示对手名称和来源（"剑影(档案影子)" 或 "AI挑战者(AI)"）
- [ ] 点击确认后推进到下一层
- [ ] **无魔城币发放**（局内PVP不给魔城币）
- [ ] **无净胜场变化**（局内PVP不计入净胜场）

### 数据架构
- [ ] `Docs/pvp-data-architecture.md` 存在，包含Phase A和Phase B方案
- [ ] `virtual_archive_pool.gd` 能正确加载 `resources/virtual_archives/` 下的JSON
- [ ] 预置档案包含完整的英雄属性、伙伴列表、层数信息
- [ ] 3个预置档案生成成功
