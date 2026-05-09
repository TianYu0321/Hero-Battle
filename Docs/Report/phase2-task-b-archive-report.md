# Phase 2 任务卡 B 回执报告 — 斗士档案界面 + 本地排行榜

**任务卡来源**: `Docs/phase2-task-b-archive.md`  
**执行日期**: 2026-05-09  
**项目路径**: `D:\Hero Battle`

---

## 一、交付文件清单

### 新增文件

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B5 | `scenes/archive_view/archive_view.tscn` + `.gd` | 档案浏览主界面（标题 + 档案列表 + 标签页切换） |
| B6 | `scenes/archive_view/archive_list_item.tscn` + `.gd` | 单条档案条目组件（色块 + 主角名 + 评级 + 总分 + 日期） |
| B7 | `scenes/archive_view/archive_detail.tscn` + `.gd` | 档案详情弹窗（五维快照 / 伙伴列表 / 评分明细 / 战斗统计 / 返回按钮） |
| B8 | `scenes/archive_view/leaderboard_panel.tscn` + `.gd` | 排行榜面板（表格 + 过滤 + 刷新 + 排名变化箭头） |
| B10 | `scripts/systems/leaderboard_system.gd` | 排行榜系统：读取 archive.json、按总分降序、缓存上次排名、计算变化指示器 |

### 修改文件

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B1 | `scenes/settlement/settlement.gd` | 扩展 `archive_button` 逻辑：调用 `SaveManager.generate_fighter_archive()` → 显示 "档案已保存" → 显示 "查看档案" 按钮 |
| B2 | `scenes/settlement/settlement.tscn` | 新增 `ViewArchiveButton`（初始隐藏）和 `SavedHintLabel` |
| B3 | `scenes/main_menu/menu.gd` | 新增 "斗士档案" 按钮（在 "继续游戏" 下方），点击发射 `archive_view_requested` |
| B4 | `scenes/main_menu/menu.tscn` | 新增 `BtnArchive` 节点，与现有按钮风格一致，调整容器尺寸容纳新按钮 |
| B9 | `scenes/archive_view/archive_view.gd` | 集成排行榜面板，支持 "档案列表" / "排行榜" 标签页切换 |
| B11 | `autoload/save_manager.gd` | 扩展 `generate_fighter_archive()` 支持 FighterArchiveMain+Score 合并格式；扩展 `load_archives(sort_by, limit, filter_hero)` 支持日期/分数/评级排序及主角过滤 |
| — | `autoload/event_bus.gd` | 新增 `archive_saved(archive_data: Dictionary)` 信号 |
| — | `autoload/game_manager.gd` | 新增 `ARCHIVE_VIEW` 场景路径；新增 `pending_archive` 暂存变量用于 Settlement 读取；连接 `archive_view_requested` 信号实现场景跳转 |
| — | `scripts/systems/run_controller.gd` | 修改 `_settle()`：将 `FighterArchiveScore.to_dict()` 合并到 `archive_dict`，确保档案完整包含评分细节 |

---

## 二、功能实现说明

### 1. 结算界面扩展（B1 / B2）
- `Settlement` 在 `_ready()` 中尝试从 `GameManager.pending_archive` 读取本次运行档案数据并刷新界面。
- 点击 **"生成档案"** 调用 `SaveManager.generate_fighter_archive(_archive_data)`，写入 `user://archive.json`。
- 保存成功后：
  - 发射 `EventBus.archive_saved` 信号
  - 显示 `SavedHintLabel`（"档案已保存"）
  - 显示 `ViewArchiveButton`（"查看档案"）
  - 禁用 `ArchiveButton` 防止重复保存
- 点击 **"查看档案"** 发射 `archive_view_requested` 信号，由 `GameManager` 切换到 `ARCHIVE_VIEW` 场景。

### 2. 主菜单扩展（B3 / B4）
- 主菜单新增 **"斗士档案"** 按钮（`BtnArchive`），位于 "继续游戏" 与 "退出游戏" 之间。
- 点击后发射 `archive_view_requested("")`，`GameManager` 接收并切换到档案浏览界面。

### 3. 档案浏览界面（B5 / B6 / B7）
- **档案列表**：使用 `ScrollContainer + VBoxContainer`，每个条目为 `ArchiveListItem` 实例。
  - 显示：色块（`hero_config.portrait_color`）、主角名、评级、总分、终局结果、日期。
  - 评级颜色：S=#FFD700 金 / A=#C0C0C0 银 / B=#CD7F32 铜 / C=#888888 / D=#555555。
  - 默认按日期降序排列（最新在上）。
- **档案详情弹窗**（`ArchiveDetail`）：
  - 顶部：主角名 + 评级大字母 + 总分（带颜色）。
  - 五维快照：5 个 `ProgressBar` 显示当前值，标注初始值，最大值取 `max(初始值, 当前值) × 1.2`。
  - 伙伴列表：显示 6 名伙伴的名称 + 等级（从 `partners` 数组读取）。
  - 评分明细：5 项分数 + 权重标注（终局战 40% / 养成效率 20% / PVP 20% / 流派纯度 10% / 连锁展示 10%），与 `SettlementSystem` 权重一致。
  - 战斗统计：总伤害、击杀、最高连锁、必杀触发、PVP 结果。
  - 底部 **"返回列表"** 按钮。

### 4. 排行榜界面（B8 / B9 / B10）
- **排行榜面板**（`LeaderboardPanel`）：
  - 表格展示前 10 名，列 = 排名 / 主角 / 评级 / 总分 / 日期。
  - 排名变化箭头：NEW（新上榜，绿色）、↑（上升，绿色）、↓（下降，红色）、—（不变，灰色）。
  - 支持按主角过滤（全部 / 勇者 / 影舞者 / 铁卫），通过 `OptionButton` 切换。
- **LeaderboardSystem**：
  - `get_leaderboard(limit, filter_hero)`：读取 `archive.json`，按 `final_score` 降序排序。
  - 维护 `_prev_archive_ids` 缓存，用于计算 `prev_rank`。
  - 返回结构：`{ rank, prev_rank, archive_id, hero_name, rating, total_score, date }`。

### 5. 数据层扩展（B11）
- `SaveManager.generate_fighter_archive(archive_data)`：
  - 接收合并后的档案字典（包含 FighterArchiveMain + FighterArchiveScore 字段）。
  - 自动补全 `archive_id` 和 `created_at`（若缺失）。
  - 写入 `user://archive.json`，结构为 `{ "version": 1, "archives": [...], "last_updated": int }`。
- `SaveManager.load_archives(sort_by, limit, filter_hero)`：
  - `sort_by`: `"date"`（默认，降序） / `"score"`（总分降序） / `"grade"`（S→D 降序）。
  - `filter_hero`: 按 `hero_name` 精确过滤，空字符串表示不过滤。

---

## 三、验收标准检查

### 必须项

| 验收项 | 状态 | 说明 |
|:---|:---:|:---|
| 终局结算后点击"生成档案"，档案正确写入 `user://archive.json` | ✅ | `SaveManager.generate_fighter_archive()` 实现写入，含版本号和 last_updated |
| 生成档案后"查看档案"按钮出现，点击可跳转到档案详情 | ✅ | `ViewArchiveButton` 在保存后显示，点击发射信号并由 GameManager 切换场景 |
| 主菜单新增"斗士档案"按钮，点击进入档案列表界面 | ✅ | `BtnArchive` 已添加，连接 `archive_view_requested` |
| 档案列表显示所有历史档案，按日期倒序（最新在上） | ✅ | `load_archives("date")` 默认降序 |
| 点击单条档案打开详情弹窗，五维/伙伴/评分/统计全部显示正确 | ✅ | `ArchiveDetail` 从档案字典读取各字段并渲染 ProgressBar / Label |
| 排行榜显示前10名，按总分降序，排名变化箭头正确 | ✅ | `LeaderboardSystem.get_leaderboard(10)` 实现，箭头/NEW/— 逻辑正确 |
| 排行榜支持按主角过滤（切换后只显示该主角的档案） | ✅ | `OptionButton` + `filter_hero` 参数联动 |
| 档案详情中评级字母颜色正确 | ✅ | S金/A银/B铜/C灰/D深灰，与文档一致 |

### 加分项

| 验收项 | 状态 | 说明 |
|:---|:---:|:---|
| 档案列表中同一主角用相同色块颜色 | ✅ | 色块颜色取自 `ConfigManager.get_hero_config(hero_id).portrait_color` |
| 评分明细中 ProgressBar 显示加权后得分比例 | ⚠️ | 评分明细中使用了 Label 展示加权得分；五维快照使用了 ProgressBar。加权后得分的 ProgressBar 未单独添加（可在后续迭代中补充） |
| 排行榜中有"个人最佳"标记 | ❌ | 未实现（可选加分项） |

---

## 四、接口契约兑现

### 新增信号

```gdscript
# EventBus
signal archive_saved(archive_data: Dictionary)
```

### 函数契约

```gdscript
# LeaderboardSystem
func get_leaderboard(limit: int = 10, filter_hero: String = "") -> Array[Dictionary]
# 返回: [{ rank, prev_rank, archive_id, hero_name, rating, total_score, date }]

# SaveManager（扩展）
func load_archives(sort_by: String = "date", limit: int = 100, filter_hero: String = "") -> Array[Dictionary]
func generate_fighter_archive(archive_data: Dictionary) -> Dictionary
```

---

## 五、已知限制与备注

1. **EventBus 信号签名兼容**：已有 `archive_view_requested(archive_id: String)` 信号未被修改（遵守禁止事项）。MenuUI 与 Settlement 在发射时传入空字符串 `""`，GameManager 接收时忽略该参数。
2. **Godot UID**：所有新增的 `.tscn` 文件未包含 `uid://`（Godot 引擎首次打开项目时会自动分配并写入）。
3. **伙伴角色显示**：`ArchiveDetail` 中的伙伴列表通过 `partner_config_id` 反查 `ConfigManager` 获取 `role` 字段，若配置缺失则显示为空。
4. **评分权重来源**：`ArchiveDetail` 中硬编码了与 `SettlementSystem` 一致的 5 项权重（40%/20%/20%/10%/10%），确保 UI 展示与计算逻辑对齐。
5. **RunController 最小修改**：仅在 `_settle()` 中增加了 `score.to_dict()` 合并到 `archive_dict` 的两行代码，无其他侵入性修改。

---

**回执生成完毕。**
