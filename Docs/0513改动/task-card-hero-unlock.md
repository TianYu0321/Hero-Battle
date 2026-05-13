# Bug修复任务卡：英雄解锁与选择

> 问题：勇者通关后影舞者仍不可用，未解锁英雄应灰显不可选。

---

## 根因分析

1. `ConfigManager.get_unlocked_hero_ids()` **只返回默认解锁的英雄**（`is_default_unlock = true`），也就是只有勇者。影舞者和铁卫的 `is_default_unlock = false`，所以根本不会被创建卡片。

2. **没有通关解锁逻辑**：勇者通关后，没有任何代码去修改解锁状态，影舞者永远不可用。

3. **英雄选择界面没有处理"未解锁但可见"的情况**：当前 `_populate_hero_cards` 遍历的是 `get_unlocked_hero_ids()`，未解锁的英雄连卡片都不生成。

---

## 修复步骤

### Step 1：定义解锁条件（在配置中明确）

**文件：`resources/configs/hero_configs.json`（或修改 fallback 配置）**

给每个英雄增加 `unlock_condition` 字段：

```json
{
    "hero_warrior": {
        "hero_id": "hero_warrior",
        "hero_name": "勇者",
        "is_default_unlock": true,
        "unlock_condition": "none"
    },
    "hero_shadow_dancer": {
        "hero_id": "hero_shadow_dancer",
        "hero_name": "影舞者",
        "is_default_unlock": false,
        "unlock_condition": "clear_with_hero_warrior"
    },
    "hero_iron_guard": {
        "hero_id": "hero_iron_guard",
        "hero_name": "铁卫",
        "is_default_unlock": false,
        "unlock_condition": "clear_with_hero_shadow_dancer"
    }
}
```

如果 JSON 文件不存在或没有这些字段，修改 `config_manager.gd` 的 `_FALLBACK_HERO_CONFIGS`：

```gdscript
"hero_shadow_dancer": {
    ...
    "is_default_unlock": false,
    "unlock_condition": "clear_with_hero_warrior",
},
"hero_iron_guard": {
    ...
    "is_default_unlock": false,
    "unlock_condition": "clear_with_hero_shadow_dancer",
}
```

### Step 2：SaveManager 增加英雄解锁持久化

**文件：`autoload/save_manager.gd`**

```gdscript
# 在 player_data 中增加 unlocked_heroes 字段

func load_player_data() -> Dictionary:
    var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
    if not FileAccess.file_exists(file_path):
        return {
            "mocheng_coin": 0,
            "unlocked_partners": [],
            "unlocked_heroes": ["hero_warrior"],   # **新增**：默认解锁勇者
            "total_wins": 0,
            "total_losses": 0,
            "pvp_wins_today": 0,
            "last_pvp_date": "",
        }
    var data = ModelsSerializer.load_json_file(file_path)
    if not data.has("unlocked_heroes"):
        data["unlocked_heroes"] = ["hero_warrior"]
    return data

func save_player_data(data: Dictionary) -> void:
    var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
    var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

# **新增**：解锁英雄
func unlock_hero(hero_id: String) -> bool:
    var data = load_player_data()
    var unlocked: Array = data.get("unlocked_heroes", [])
    if not hero_id in unlocked:
        unlocked.append(hero_id)
        data["unlocked_heroes"] = unlocked
        save_player_data(data)
        print("[SaveManager] 解锁英雄: %s" % hero_id)
        return true
    return false
```

### Step 3：通关时检查并解锁新英雄

**文件：`scripts/systems/run_controller.gd`**

在 `_settle` 或 `_end_run`（终局完成时）中添加解锁逻辑：

```gdscript
# 在 _settle 中（终局胜利后）
func _settle() -> void:
    ...
    # 检查是否解锁新英雄
    _check_hero_unlocks()
    ...

func _check_hero_unlocks() -> void:
    var hero_id: String = ConfigManager.get_hero_id_by_config_id(_run.hero_config_id)
    var all_heroes: Dictionary = ConfigManager._hero_configs
    
    for hid in all_heroes:
        var cfg: Dictionary = all_heroes[hid]
        var condition: String = cfg.get("unlock_condition", "")
        
        match condition:
            "clear_with_hero_warrior":
                if hero_id == "hero_warrior" and _run.current_turn >= 30:
                    SaveManager.unlock_hero(hid)
            "clear_with_hero_shadow_dancer":
                if hero_id == "hero_shadow_dancer" and _run.current_turn >= 30:
                    SaveManager.unlock_hero(hid)
```

### Step 4：ConfigManager 改为读取存档中的解锁状态

**文件：`autoload/config_manager.gd`**

```gdscript
func get_unlocked_hero_ids() -> Array[String]:
    var result: Array[String] = []
    var player_data: Dictionary = SaveManager.load_player_data()
    var unlocked: Array = player_data.get("unlocked_heroes", [])
    
    for hero_id in _hero_configs:
        var cfg: Dictionary = _hero_configs[hero_id]
        # 默认解锁 或 存档中已解锁
        if cfg.get("is_default_unlock", false) or hero_id in unlocked:
            result.append(hero_id)
    
    return result
```

### Step 5：英雄选择界面显示所有英雄（已解锁可点，未解锁灰显）

**文件：`scenes/hero_select/hero_select.gd`**

改为遍历**所有英雄**，而不是只遍历已解锁的：

```gdscript
func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    # 获取所有英雄ID（不是只获取已解锁的）
    _hero_ids = ConfigManager._hero_configs.keys()
    _populate_hero_cards()

func _populate_hero_cards() -> void:
    var player_data: Dictionary = SaveManager.load_player_data()
    var unlocked: Array = player_data.get("unlocked_heroes", [])
    
    var card_index: int = 0
    for hero_id in _hero_ids:
        var config: Dictionary = ConfigManager.get_hero_config(hero_id)
        if config.is_empty():
            continue

        var card: Control = _hero_cards.get_child(card_index)
        if card == null:
            continue

        var portrait: ColorRect = card.get_node("PortraitRect")
        var name_label: Label = card.get_node("NameLabel")
        var desc_label: Label = card.get_node("ClassDesc")
        var stats_container: VBoxContainer = card.get_node("StatsPreview")
        var select_btn: Button = card.get_node("SelectBtn")

        portrait.color = Color.html(config.get("portrait_color", "#FFFFFF"))
        name_label.text = config.get("hero_name", hero_id)
        desc_label.text = config.get("class_desc", "")

        var favored_attr: int = config.get("favored_attr", 0)
        _set_stat_label(stats_container.get_node("StatPhysique"), "体魄", config.get("base_physique", 0), favored_attr == 1)
        _set_stat_label(stats_container.get_node("StatStrength"), "力量", config.get("base_strength", 0), favored_attr == 2)
        _set_stat_label(stats_container.get_node("StatAgility"), "敏捷", config.get("base_agility", 0), favored_attr == 3)
        _set_stat_label(stats_container.get_node("StatTechnique"), "技巧", config.get("base_technique", 0), favored_attr == 4)
        _set_stat_label(stats_container.get_node("StatSpirit"), "精神", config.get("base_spirit", 0), favored_attr == 5)

        # **关键修改**：判断是否解锁
        var is_unlocked: bool = config.get("is_default_unlock", false) or hero_id in unlocked
        
        if is_unlocked:
            select_btn.text = "选择"
            select_btn.disabled = false
            select_btn.modulate = Color(1, 1, 1)
            select_btn.pressed.connect(_on_select_hero.bind(hero_id, config))
        else:
            select_btn.text = "未解锁"
            select_btn.disabled = true
            select_btn.modulate = Color(0.3, 0.3, 0.3)
            # 显示解锁条件
            var condition: String = config.get("unlock_condition", "")
            var condition_text: String = _get_unlock_condition_text(condition)
            desc_label.text += "\n[color=gray]%s[/color]" % condition_text

        card_index += 1

func _get_unlock_condition_text(condition: String) -> String:
    match condition:
        "clear_with_hero_warrior":
            return "通关勇者解锁"
        "clear_with_hero_shadow_dancer":
            return "通关影舞者解锁"
    return "未解锁"
```

### Step 6：兼容旧存档（没有 unlocked_heroes 字段）

**文件：`autoload/save_manager.gd`**

在 `load_player_data` 中已经处理了（Step 2 中的 `if not data.has(