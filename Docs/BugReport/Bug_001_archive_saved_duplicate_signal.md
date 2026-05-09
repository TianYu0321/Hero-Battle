# Bug #001: event_bus.gd 中 `archive_saved` 信号重复声明

**发现时间**: 2026-05-09  
**发现方式**: Godot 编译报错  
**错误信息**: `Signal "archive_saved" has the same name as a previously declared signal.`  
**错误位置**: `res://autoload/event_bus.gd` (115, 8)

---

## 问题描述

在按 `phase2-task-c-integration.md` 扩展 `event_bus.gd` 时，新增 Phase 2 信号 `archive_saved` 和 `leaderboard_updated` 的过程中，由于未先检查文件中是否已存在同名信号，导致 `archive_saved` 被声明了两次：

- **第1处**（新增）: 在 PVP 信号区域之后，作为"档案/排行榜信号"区块的一部分插入
- **第2处**（原有）: 在文件末尾的系统信号区域，Phase 1 已存在

## 根因分析

`save_manager.gd` 在 Phase 1 已实现 `EventBus.archive_saved.emit(archive)`，说明该信号在 `event_bus.gd` 中早已声明。执行 Phase 2 任务卡 C 时，未全文搜索确认 `archive_saved` 是否已存在，直接新增了一条同名信号声明，造成重复。

## 修复措施

1. **删除**新增的重复区块（原第38-40行）：
   ```gdscript
   # --- 档案/排行榜信号 (Archive & Leaderboard) ---
   signal archive_saved(archive_data: Dictionary)
   signal leaderboard_updated(leaderboard: Array[Dictionary])
   ```

2. **保留**原有的 `archive_saved` 声明（第115行附近，系统信号区域）。

3. **将**新增的 `leaderboard_updated` 信号移至原有 `archive_saved` 的下一行，保持同类信号集中：
   ```gdscript
   signal archive_saved(archive_data: Dictionary)
   signal leaderboard_updated(leaderboard: Array[Dictionary])
   ```

## 修复后验证

```bash
# grep 确认不再有重复
grep -n "archive_saved" autoload/event_bus.gd
# 输出: 111:signal archive_saved(archive_data: Dictionary)

grep -n "leaderboard_updated" autoload/event_bus.gd
# 输出: 112:signal leaderboard_updated(leaderboard: Array[Dictionary])
```

两处信号均只出现一次，Godot 编译通过。

---

## 预防措施

- **新增 EventBus 信号前**，先执行 `grep -n "signal_name" autoload/event_bus.gd` 确认是否已存在
- **新增 ConfigManager 查询字段前**，先确认类级变量声明区已包含对应字段（参考 Bug #002 类似问题）
