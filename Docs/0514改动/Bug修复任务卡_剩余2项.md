# Bug修复任务卡（剩余2项）

## Bug1：战斗失败时跳过动画演出

### 现象
20HP点击"战斗"→被秒→直接显示结算面板（败北），没有战斗动画回放。

### 根因
`run_main.gd` `_on_battle_ended` 中，失败分支没有启动 `battle_animation_panel.start_playback()`，直接走了 `_show_battle_summary()`。

### 修复

**文件：`scenes/run_main/run_main.gd`**

找到 `_on_battle_ended` 函数，修改为：

```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    print("[RunMain] 战斗结束: winner=%s, turns=%d" % [
        battle_result.get("winner", "???"),
        battle_result.get("turns_elapsed", 0)
    ])
    
    # 缓存结果
    _pending_battle_result = battle_result
    
    var recorder = battle_result.get("playback_recorder", null)
    if recorder != null and recorder.get_events().size() > 0:
        var hero_data = battle_result.get("hero", {})
        var enemy_data = battle_result.get("enemies", [{}])[0]
        var hero_name = hero_data.get("name", "英雄")
        var enemy_name = enemy_data.get("name", "敌人")
        var hero_max_hp = hero_data.get("max_hp", 100)
        var enemy_max_hp = enemy_data.get("max_hp", 100)
        
        # ✅ 关键：无论胜负，都要启动动画回放
        battle_animation_panel.start_playback(
            recorder, hero_name, enemy_name, hero_max_hp, enemy_max_hp, [], []
        )
        
        if not battle_animation_panel.confirmed.is_connected(_on_battle_animation_finished):
            battle_animation_panel.confirmed.connect(_on_battle_animation_finished, CONNECT_ONE_SHOT)
    else:
        # 没有录像，直接显示结算面板
        _show_battle_summary(battle_result)
```

确认 `_on_battle_animation_finished` 存在且正确：

```gdscript
func _on_battle_animation_finished() -> void:
    print("[RunMain] 动画播放完毕，显示结算面板")
    _show_battle_summary(_pending_battle_result)
```

### 验收
- [ ] 20HP进战斗 → 被秒 → 战斗动画正常播放 → 结算面板显示败北

---

## Bug2：战斗画面血条显示满血

### 现象
英雄HP 100/210，进入战斗后血条显示100%（满血）。

### 根因
`battle_result.hero` 字典缺少 `max_hp` 字段，`hero_data.get("max_hp", 100)` 返回默认值100，ratio = 100/100 = 1.0。

### 修复

**Step 1：文件 `scripts/data/runtime_hero.gd`**

找到 `to_dict()` 方法，添加 `max_hp`：

```gdscript
func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "current_hp": current_hp,
        "max_hp": max_hp,  # ← 新增这行
        "current_vit": current_vit,
        "current_str": current_str,
        "current_agi": current_agi,
        "current_tec": current_tec,
        "current_mnd": current_mnd,
    }
```

如果 `RuntimeHero` 没有 `max_hp` 字段，用 `get_max_hp()` 或从配置读取：

```gdscript
"max_hp": max_hp if "max_hp" in self else ConfigManager.get_hero_max_hp(id)
```

**Step 2：文件 `scenes/run_main/run_main.gd`**

确认 `_on_battle_ended` 中正确读取 `max_hp`：

```gdscript
var hero_data = battle_result.get("hero", {})
var hero_max_hp = hero_data.get("max_hp", 100)
# 如果 hero_max_hp 还是100默认值，说明 to_dict() 没加 max_hp
```

**Step 3：文件 `scenes/run_main/battle_animation_panel.gd`**

确认 `_update_hp_display` 计算正确：

```gdscript
func _update_hp_display() -> void:
    var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
    var enemy_ratio: float = float(_enemy_hp) / maxi(1, _enemy_max_hp)
    
    hero_hp_bar.value = hero_ratio * 100
    enemy_hp_bar.value = enemy_ratio * 100
```

### 验收
- [ ] 100/210 HP进战斗 → 血条显示约47%
- [ ] 50/210 HP进战斗 → 血条显示约23%
- [ ] 200/210 HP进战斗 → 血条显示约95%
