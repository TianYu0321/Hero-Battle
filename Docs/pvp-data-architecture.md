# PVP数据架构（v2.0）

## 当前实现（Phase A - 单机模式）

**数据来源**：
- 本地 `archive.json`：玩家自己的通关档案
- `resources/virtual_archives/`：预置的虚拟玩家档案（JSON格式）

**匹配逻辑**：
1. PVP触发时（第10/20层），从本地档案 + 虚拟档案中筛选 `final_turn >= 当前层` 的记录
2. 随机抽取一条作为影子对手
3. 无匹配时fallback到AI生成

**存储格式**：
- 档案字段：`hero_config_id`, `hero_name`, `final_turn`, `final_score`, `final_grade`,
  `attr_snapshot_vit/str/agi/tec/mnd`, `partner_count`, `partners[]`, `is_fixed`

## 未来扩展（Phase B - 联机模式）

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

## 局内 vs 局外PVP区分

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
