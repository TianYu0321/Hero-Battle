# Phase 2 任务卡 B — 斗士档案界面 + 本地排行榜

**项目路径**：`D:\Hero Battle`  
**引擎**：Godot 4.6.2 / GDScript  
**基准文档**：`02_interface_contracts.md`（信号R01-R21）、`06_ui_flow_design.md`  
**交付目录**：`res://scenes/archive_view/`、`res://scripts/systems/`、`res://scenes/main_menu/`、`res://scenes/settlement/`

---

## 目标

1. **结算界面档案按钮可用**：终局结算后点击"生成档案"，保存档案并进入档案浏览
2. **档案浏览主界面**：从主菜单可进入，列表展示所有历史档案
3. **档案详情弹窗**：点击单份档案查看五维快照、伙伴列表、评分明细、战斗统计
4. **本地排行榜**：按评分排序展示前N名，支持按主角过滤

---

## 交付物清单

### 1. 结算界面扩展

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B1 | `scenes/settlement/settlement.gd` **扩展** | `archive_button` 实际可用：调用 `SaveManager.generate_fighter_archive()` → 发射 `archive_saved` 信号 → 显示"档案已保存"提示 → 提供"查看档案"按钮（跳转到 archive_view） |
| B2 | `scenes/settlement/settlement.tscn` **扩展** | 新增"查看档案"按钮（初始隐藏，保存后显示） |

### 2. 主菜单扩展

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B3 | `scenes/main_menu/menu.gd` **扩展** | 新增"斗士档案"按钮（在"继续游戏"下方），点击发射 `archive_view_requested` 信号 → 跳转到 archive_view |
| B4 | `scenes/main_menu/menu.tscn` **扩展** | 新增按钮节点，与现有按钮风格一致 |

### 3. 档案浏览界面

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B5 | `scenes/archive_view/archive_view.tscn` + `.gd` **新增** | 档案浏览主界面：顶部标题 + 档案列表（ScrollContainer + VBoxContainer），每个档案条目显示：主角名/评级/总分/终局结果/日期 |
| B6 | `scenes/archive_view/archive_list_item.tscn` + `.gd` **新增** | 共享组件：单条档案条目（色块+主角名+评级字母+总分+日期），点击打开详情弹窗 |
| B7 | `scenes/archive_view/archive_detail.tscn` + `.gd` **新增** | 档案详情弹窗（PanelContainer覆盖）：
- 顶部：主角名 + 评级大字母（S/A/B/C/D）+ 总分
- 五维快照：5个属性条（当前值/初始值对比）
- 伙伴列表：6名伙伴名称+等级+定位（色块占位）
- 评分明细：5项分数 + 权重标注（终局战40%/养成20%/PVP20%/纯度10%/连锁10%）
- 战斗统计：总伤害/击杀/最高连锁/必杀触发/PVP结果
- 底部："返回列表"按钮 |

### 4. 排行榜界面

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B8 | `scenes/archive_view/leaderboard_panel.tscn` + `.gd` **新增** | 排行榜面板：表格展示前10名，列=排名/主角名/评级/总分/日期。排名变化箭头（与上次对比，新上榜=NEW，上升=↑，下降=↓，不变=—） |
| B9 | `scenes/archive_view/archive_view.gd` **扩展** | 新增"排行榜"标签页/按钮，切换列表视图和排行榜视图 |

### 5. 排行榜系统

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B10 | `scripts/systems/leaderboard_system.gd` **新增** | 排行榜管理：读取 `archive.json`，按 `total_score` 降序排序，支持过滤（全部主角/勇者/影舞者/铁卫），缓存上次排名用于变化计算 |

### 6. 数据层扩展（如有需要）

| # | 文件路径 | 说明 |
|:---:|:---|:---|
| B11 | `autoload/save_manager.gd` **扩展** | `load_archives()` 增加 `sort_by` 参数支持（"date"/"score"/"grade"），增加 `filter_hero` 参数 |

---

## 接口契约

### 新增信号（EventBus）

```gdscript
# 发射方：Settlement
# 接收方：ArchiveView（预加载时订阅）
EventBus.archive_saved.emit({
  "archive_id": String,
  "hero_name": String,
  "rating": String,
  "total_score": float,
})

# 发射方：MenuUI
# 接收方：GameManager
EventBus.archive_view_requested.emit()
```

### 函数契约

```gdscript
# LeaderboardSystem
func get_leaderboard(limit: int = 10, filter_hero: String = "") -> Array[Dictionary]
# 返回: [{ rank, prev_rank, archive_id, hero_name, rating, total_score, date }]
# prev_rank: -1=新上榜, 0=不变, >0=上次排名（当前rank < prev_rank 表示上升）

# SaveManager（扩展）
func load_archives(sort_by: String = "date", limit: int = 100, filter_hero: String = "") -> Array[Dictionary]
```

---

## 档案列表条目显示规范

每个档案条目（`archive_list_item`）显示：

```
┌────────────────────────────────────────┐
│ [色块64×64]  勇者          评级: C    │
│             总分: 52                   │
│             终局: 胜利   2026-05-09    │
└────────────────────────────────────────┘
```

- 色块颜色 = `hero_config.portrait_color`
- 评级字母用大字号（24px），颜色编码：S=#FFD700 金 / A=#C0C0C0 银 / B=#CD7F32 铜 / C=#888888 / D=#555555

---

## 档案详情弹窗布局

```
┌────────────────────────────────────────┐
│ 斗士档案详情                    [X]    │
├────────────────────────────────────────┤
│  勇者      评级: C      总分: 52       │
├────────────────────────────────────────┤
│ 五维快照                               │
│ 体魄: 27 (初始12) ████████████░░░░     │
│ 力量: 35 (初始16) ████████████████     │
│ 敏捷: 18 (初始10) ████████░░░░░░░░     │
│ 技巧: 22 (初始12) ██████████░░░░░░     │
│ 精神: 15 (初始 8) ███████░░░░░░░░░     │
├────────────────────────────────────────┤
│ 伙伴队伍                               │
│ [剑士 Lv2] [斥候 Lv1] [盾卫 Lv3] ...  │
├────────────────────────────────────────┤
│ 评分明细                               │
│ 终局战(40%): 45/100  → 18.0           │
│ 养成效率(20%): 60/100 → 12.0          │
│ PVP(20%): 80/100    → 16.0           │
│ 流派纯度(10%): 30/100 → 3.0          │
│ 连锁展示(10%): 30/100 → 3.0          │
│ ─────────────────────────────────     │
│ 总分: 52.0                             │
├────────────────────────────────────────┤
│ 战斗统计                               │
│ 总伤害: 1247  击杀: 8  最高连锁: 4     │
│ 必杀触发: 1次  PVP: 第10回胜/第20回败 │
├────────────────────────────────────────┤
│              [返回列表]                  │
└────────────────────────────────────────┘
```

- 所有数值从 `FighterArchiveMain` + `FighterArchiveScore` 读取
- 属性条用 `ProgressBar` 或 `ColorRect` 占位，最大值取 `max(初始值, 当前值) × 1.2`
- 评分明细中权重标注与 `scoring_configs.json` 一致

---

## 排行榜布局

```
┌────────────────────────────────────────┐
│ 本地排行榜                    [返回]   │
├────┬────────┬────┬───────┬─────────────┤
│排名│ 主角   │评级│ 总分  │  日期       │
├────┼────────┼────┼───────┼─────────────┤
│ 1  │ 影舞者 │ S  │  92   │ 2026-05-09 │
│ 2 ↑│ 勇者   │ A  │  78   │ 2026-05-08 │
│ 3 ↓│ 铁卫   │ A  │  76   │ 2026-05-08 │
│ 4 —│ 勇者   │ B  │  65   │ 2026-05-07 │
│ 5 NEW│ 影舞者│ B │  62   │ 2026-05-09 │
└────┴────────┴────┴───────┴─────────────┘
```

- 排名变化：↑ 上升 / ↓ 下降 / — 不变 / NEW 新上榜
- 支持按主角过滤（全部/勇者/影舞者/铁卫）
- 默认显示前 10 名

---

## 验收标准

### 必须项

- [ ] 终局结算后点击"生成档案"，档案正确写入 `user://archive.json`
- [ ] 生成档案后"查看档案"按钮出现，点击可跳转到档案详情
- [ ] 主菜单新增"斗士档案"按钮，点击进入档案列表界面
- [ ] 档案列表显示所有历史档案，按日期倒序（最新在上）
- [ ] 点击单条档案打开详情弹窗，五维/伙伴/评分/统计全部显示正确
- [ ] 排行榜显示前10名，按总分降序，排名变化箭头正确
- [ ] 排行榜支持按主角过滤（切换后只显示该主角的档案）
- [ ] 档案详情中评级字母颜色正确（S金/A银/B铜/C灰/D深灰）

### 加分项

- [ ] 档案列表中同一主角用相同色块颜色
- [ ] 评分明细中 ProgressBar 显示加权后得分比例
- [ ] 排行榜中有"个人最佳"标记（该玩家的最高分档案）

---

## 禁止事项

- ❌ 不做档案编辑/删除功能（只读浏览）
- ❌ 不做在线排行榜同步（纯本地）
- ❌ 不连接网络服务器
- ❌ 不改 EventBus 已有信号签名
- ❌ 不改 `FighterArchiveMain` / `FighterArchiveScore` 模型字段

---

## 备注

- `SaveManager` 已提供 `generate_fighter_archive()` 和 `load_archives()`，在此基础上扩展排序和过滤即可
- `archive.json` 结构：`{ "version": 1, "archives": Array[FighterArchiveMain+Score], "last_updated": int }`
- 档案列表的日期格式化：`Time.get_datetime_string_from_unix_time(created_at)`
- 排名变化缓存：LeaderboardSystem 维护 `prev_leaderboard: Array[Dictionary]`，每次生成新排行榜时保存副本用于下次对比

---

*任务卡版本：v1.0*  
*日期：2026-05-09*
