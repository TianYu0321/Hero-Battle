# Bug修复任务卡：通关后"继续游戏"仍加载已完成的存档

---

## 根因

**胜利通关路径**：
1. 第30层打完终局战 → `_execute_final_battle()` → `_settle()`
2. `_settle()` 生成档案、发射 `run_ended` → 进入 SETTLEMENT 状态
3. **但 `_settle()` 没有标记 run存档为已完成！**
4. `_auto_save()` 之前保存的 run存档里 `run_status = 1`（ONGOING）
5. 回到主菜单，`has_active_run()` 看到 `run_status == 1` → 认为"还有未完成的局"
6. 点击"继续游戏" → 加载的是已通关的存档（层数=30，属性是终局属性）

**死亡/放弃路径**（正常）：
1. `_end_run()` 会删除 `save_*.json` 文件
2. 回到主菜单，`has_active_run()` 返回 false
3. "继续游戏"按钮不显示

---

## 修复

### 修复：_settle() 结算完成后标记 run存档为已完成

**文件：`scripts/systems/run_controller.gd`**

在 `_settle()` 末尾，发射 `run_ended` 之前，更新 run存档状态：

```gdscript
func _settle() -> void:
    ...
    # --- 生成档案数据（已有代码）---
    var archive_data: Dictionary = { ... }
    
    # **新增**：标记当前 run存档为已完成（run_status = 2）
    _run.run_status = RunStatus.COMPLETED
    _auto_save()  # 保存一次，把 run_status=2 写入 save_*.json
    
    // 通过 GameManager 传递档案数据
    var gm = get_node_or_null("/root/GameManager")
    if gm != null:
        gm.pending_archive = archive_data
    
    EventBus.run_ended.emit("victory", _run.total_score, archive_data)
    _change_state(RunState.SETTLEMENT)
```

**注意**：如果 `RunStatus` 枚举中没有 `COMPLETED`，需要添加：

```gdscript
enum RunStatus {
    ONGOING = 1,      # 进行中
    COMPLETED = 2,    # **新增**：已完成（通关）
    DEFEATED = 3,     # 已死亡
}
```

### 备选方案：直接删除 run存档（更简单）

如果不想引入 `COMPLETED` 状态，可以直接删除 run存档：

```gdscript
func _settle() -> void:
    ...
    // 删除 run存档，确保"继续游戏"不加载已完成的局
    var save_path: String = ConfigManager.SAVE_DIR + "save_001.json"
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
        print("[RunController] 通关存档已删除")
    
    EventBus.run_ended.emit("victory", _run.total_score, archive_data)
    ...
```

**两种方案都可以，不影响 PVP档案**（档案是单独保存在 `archive.json` 的）。

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/systems/run_controller.gd` | `_settle()` 末尾标记 `run_status = COMPLETED` 并 `_auto_save()`，或删除 run存档 |
| 2 | `scripts/models/runtime_run.gd`（如需要）| 添加 `RunStatus.COMPLETED = 2` |

---

## 验收标准

- [ ] 完成一局游戏（通关第30层）→ 进入 Settlement 场景
- [ ] 回到主菜单 → "继续游戏"按钮**不显示**
- [ ] `has_active_run()` 返回 false（控制台有输出可验证）
- [ ] 斗士档案正常保存（可在"查看档案"中看到新档案）
- [ ] PVP 大厅中可以选择该档案出战（档案级净胜场正常）
- [ ] 死亡/放弃后，"继续游戏"按钮也不显示（保持原有行为）
