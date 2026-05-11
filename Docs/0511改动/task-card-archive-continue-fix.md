# Bug修复任务卡：结算档案 + 继续游戏属性残留

> 只修改3个文件：run_controller.gd、game_manager.gd、settlement.gd（可选优化）

---

## Bug 1：游戏结束时档案五维全50，生成档案按钮无效

### 根因（两句话）

1. RunController 在游戏结束时发射 `run_ended("victory", score, {})`，第三个参数 archive 传了**空字典**
2. GameManager 收到空 archive 后，`pending_archive` 为空 → Settlement 场景走 fallback 路径显示"属性: 50" → `_archive_data` 为空 → 点击"生成档案"按钮时 `_on_archive_button_pressed` 判断空数据直接 return，没有实际生成档案

### 修复步骤

#### Step 1：修改 `scripts/systems/run_controller.gd` 的 FINISHED 分支

在 `_finish_node_execution` 的 `RunState.FINISHED` 分支中，生成正确的 archive 数据并传给 GameManager：

```gdscript
RunState.FINISHED:
    print("[RunController] 终局完成，结算... final_turn=%d, score=%d" % [_run.current_turn, _run.total_score])
    
    # --- 生成档案数据 ---
    var archive_data: Dictionary = {
        "hero_config_id": _run.hero_config_id,
        "final_turn": _run.current_turn,
        "final_score": _run.total_score,
        "final_grade": "S",  # TODO: 接入SettlementSystem计算真实评分
        "attr_snapshot_vit": _hero.current_vit,
        "attr_snapshot_str": _hero.current_str,
        "attr_snapshot_agi": _hero.current_agi,
        "attr_snapshot_tec": _hero.current_tec,
        "attr_snapshot_mnd": _hero.current_mnd,
        "initial_vit": _hero.current_vit,  # 如果没有初始值记录，先用当前值
        "initial_str": _hero.current_str,
        "initial_agi": _hero.current_agi,
        "initial_tec": _hero.current_tec,
        "initial_mnd": _hero.current_mnd,
        "battle_win_count": _run.battle_win_count,
        "elite_win_count": _run.elite_win_count,
        "elite_total_count": _run.elite_total_count,
        "pvp_10th_result": _run.pvp_10th_result,
        "pvp_20th_result": _run.pvp_20th_result,
        "training_count": _hero.total_training_count,
        "shop_visit_count": _run.shop_visit_count,
        "rescue_success_count": _run.rescue_success_count,
        "total_damage_dealt": _run.total_damage_dealt,
        "total_enemies_killed": _run.total_enemies_killed,
        "max_chain_reached": _run.max_chain_reached,
        "total_chain_count": _run.total_chain_count,
        "total_aid_trigger_count": _run.total_aid_trigger_count,
        "ultimate_triggered": _hero.ultimate_used,
        "gold_spent": _run.gold_spent,
        "gold_earned_total": _run.gold_earned_total,
        "partner_count": _partners.size(),
        "max_hp_reached": _hero.max_hp,
        "ended_at": Time.get_unix_time_from_system(),
    }
    
    # 通过 GameManager 传递档案数据
    var gm = get_node_or_null("/root/GameManager")
    if gm != null:
        gm.pending_archive = archive_data
        print("[RunController] 档案数据已传给 GameManager")
    else:
        push_error("[RunController] GameManager not found, cannot pass archive")
    
    EventBus.run_ended.emit("victory", _run.total_score, archive_data)
    return
```

**注意**：`final_grade` 目前硬编码为 "S"，因为 SettlementSystem 需要 `RuntimeFinalBattle` 数据才能计算真实评分。如果终局战数据可用，应该调用 SettlementSystem 计算。但当前 MVP 阶段，先用硬编码或简化评分。

如果需要接入真实 SettlementSystem 评分，可以：
1. 在 RunController 中 `add_child(SettlementSystem.new())`
2. 构造 `RuntimeFinalBattle` 对象（从 `_pending_battle_result` 取数据）
3. 调用 `settlement_system.calculate_score(_run, _hero, final_battle, _partners)`
4. 把 score 放入 archive_data

#### Step 2（可选）：Settlement 场景增加 fallback 提示

如果 GameManager.pending_archive 仍然为空（异常情况），Settlement 不应该静默显示"50"，而应该提示用户：

```gdscript
func _ready() -> void:
    ...
    var gm = get_node_or_null("/root/GameManager")
    if gm != null and not gm.pending_archive.is_empty():
        _archive_data = gm.pending_archive.duplicate()
        _populate_from_data(_archive_data)
    else:
        # fallback 改为提示而非假数据
        rating_label.text = "?"
        for i in range(attr_labels.size()):
            attr_labels[i].text = "属性%d: 数据缺失" % (i + 1)
        archive_button.disabled = true
        archive_button.text = "无档案数据"
```

---

## Bug 2：点击继续游戏后，新游戏沿用上次属性

### 根因（一句话）

`GameManager.pending_save_data` 在"继续游戏"时被填充了存档数据，但**新游戏流程**（点击"新游戏" → 选英雄 → 选伙伴 → 进入 RunMain）中没有任何一步清空 `pending_save_data`。RunMain._ready() 看到 `pending_save_data` 非空，误以为是"继续游戏"，调用 `continue_from_save()` 而非 `start_new_run()`。

### 修复步骤

#### Step 1：修改 `autoload/game_manager.gd`

在三个入口函数中清空 `pending_save_data`：

```gdscript
func _on_new_game_requested(hero_id: String) -> void:
    pending_save_data = {}      # **新增**：确保新游戏不沿用旧存档
    pending_archive = {}        # **新增**：同时清空档案
    change_scene("HERO_SELECT", "fade")

func _on_team_confirmed(partner_ids: Array[String]) -> void:
    pending_save_data = {}      # **新增**：选完队伍后确保不沿用旧存档
    selected_partner_config_ids.clear()
    for pid in partner_ids:
        selected_partner_config_ids.append(_PARTNER_STRING_TO_ID.get(pid, 1001))
    change_scene("RUNNING", "fade")

func _on_back_to_menu_requested() -> void:
    pending_save_data = {}      # **新增**：返回主菜单时清空
    pending_archive = {}        # **新增**
    change_scene("MENU", "fade")
```

#### Step 2（防御性）：RunMain._ready() 增加双重检查

在 `scenes/run_main/run_main.gd` 的 `_ready()` 中，即使 `pending_save_data` 非空，也要确认用户意图：

```gdscript
func _ready() -> void:
    ...
    var pending_save: Dictionary = GameManager.pending_save_data
    # 双重检查：如果 GameManager 当前状态不是 RUNNING（比如是从新游戏流程进来的），
    # 即使有 pending_save_data 也不应该继续
    if not pending_save.is_empty() and GameManager.get_current_state() == "RUNNING":
        print("[RunMain] 检测到待恢复存档，继续游戏")
        var success = _run_controller.continue_from_save(pending_save)
        if success:
            GameManager.pending_save_data = {}
            _update_hud()
        else:
            push_error("[RunMain] 存档恢复失败，回到主菜单")
            get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")
    else:
        # 正常新开局
        GameManager.pending_save_data = {}  # **新增**：确保清空
        var hero_config_id = GameManager.selected_hero_config_id
        var partner_config_ids = GameManager.selected_partner_config_ids.duplicate()
        if hero_config_id <= 0:
            push_error("[RunMain] No hero selected")
            return
        _run_controller.start_new_run(hero_config_id, partner_config_ids)
```

**注意**：`GameManager.get_current_state()` 返回的是当前状态字符串。如果从新游戏流程进入，状态应该是 `"RUNNING"`（因为 GameManager.change_scene 已经把状态设为 RUNNING 了）。所以这个双重检查可能不够严格。

更好的方案：在 GameManager 中增加一个标志位 `is_continuing_run`，RunMain 检查这个标志位：

```gdscript
# GameManager.gd
var is_continuing_run: bool = false

func _on_continue_game_requested() -> void:
    var save_data = SaveManager.load_latest_run()
    if save_data.is_empty():
        return
    pending_save_data = save_data
    is_continuing_run = true          # **新增**
    change_scene("RUNNING", "fade")

func _on_new_game_requested(hero_id: String) -> void:
    pending_save_data = {}
    pending_archive = {}
    is_continuing_run = false         # **新增**
    change_scene("HERO_SELECT", "fade")

func _on_team_confirmed(partner_ids: Array[String]) -> void:
    pending_save_data = {}
    is_continuing_run = false         # **新增**
    ...
```

RunMain._ready() 检查 `is_continuing_run`：
```gdscript
if GameManager.is_continuing_run and not pending_save.is_empty():
    # 继续游戏
    ...
    GameManager.is_continuing_run = false  # 重置
else:
    # 新开局
    ...
```

这个方案更精确，但需要修改更多文件。如果 Step 1 的三处清空足够，Step 2 可以省略。

---

## 文件修改清单

| # | 文件 | 修改内容 | Bug |
|:---:|:---|:---|:---:|
| 1 | `scripts/systems/run_controller.gd` | FINISHED分支生成archive数据并传给GameManager | Bug 1 |
| 2 | `autoload/game_manager.gd` | _on_new_game_requested / _on_team_confirmed / _on_back_to_menu_requested 清空 pending_save_data 和 pending_archive | Bug 2 |
| 3 | `scenes/settlement/settlement.gd` | fallback路径改为提示"数据缺失"并禁用按钮（可选） | Bug 1 |

---

## 验收标准

### Bug 1 验收
- [ ] 完成一局游戏（到达第30层或战败）→ 进入 Settlement 场景
- [ ] Settlement 显示的五维属性与游戏中实际属性一致（不是50）
- [ ] 点击"生成档案"按钮后，控制台有 `[Settlement] 档案已保存` 相关输出
- [ ] 查看档案文件（ARCHIVE_FILE），能看到正确的五维属性值

### Bug 2 验收
- [ ] 玩一局游戏后退出到主菜单
- [ ] 点击"继续游戏" → 正常恢复上次进度
- [ ] 再玩几层后返回主菜单
- [ ] 点击"新游戏" → 选英雄 → 选伙伴 → 进入游戏
- [ ] 新游戏的主角属性是初始值（不是上次游戏的属性）
- [ ] 新游戏的当前层是第1层（不是上次游戏的层数）
- [ ] 控制台没有 `[RunMain] 检测到待恢复存档` 输出
