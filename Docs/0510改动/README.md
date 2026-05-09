# Hero-Battle 代码修改 — Phase 1+2 交付包

> 修改日期：2026-05-09
> 基于规格书 v2.0

---

## 修改文件清单（13个文件）

### 数据层修正（5个文件）

| 文件 | 修改内容 |
|:---|:---|
| `scripts/models/runtime_partner.gd` | 删除 `current_vit/str/agi/tec/mnd`，新增 `favored_attr` |
| `resources/configs/partner_configs.json` | 删除所有 `base_physique/strength/agility/technique/spirit` 字段 |
| `resources/configs/hero_configs.json` | 字段名统一：`id`→`hero_id`, `name`→`hero_name`, `title`→`class_desc` |
| `autoload/config_manager.gd` | 删除 fallback 伙伴属性，修复 `get_hero_id_by_config_id` 字段名 |
| `scripts/systems/character_manager.gd` | 删除伙伴属性初始化，战斗属性改为 `8 + level * 2` |

### 回合结构重写（4个文件）

| 文件 | 修改内容 |
|:---|:---|
| `scripts/systems/node_pool_system.gd` | **完全重写**：30层爬塔，特殊层判定，固定4选项 |
| `scripts/systems/node_resolver.gd` | **完全重写**：直接处理训练/战斗/休息/外出/救援/商店/PVP/终局 |
| `scripts/systems/run_controller.gd` | 添加 `current_floor`，`select_training_attr` 接口，伙伴属性引用修正 |
| `scenes/run_main/run_main.gd` | **重写UI**：4固定按钮，训练/战斗/休息/外出，信号改为 floor_changed/floor_advanced |

### 其他修正（4个文件）

| 文件 | 修改内容 |
|:---|:---|
| `scripts/models/fighter_archive_partner.gd` | 删除 `final_vit` 等五维，新增 `favored_attr` |
| `scripts/models/runtime_run.gd` | 新增 `current_floor` 字段 |
| `autoload/event_bus.gd` | 新增 `floor_changed` / `floor_advanced` 信号 |
| `scripts/systems/rescue_system.gd` | `config.get("title")` → `config.get("role")` |

---

## 使用方式

1. 解压本压缩包
2. 用解压出的文件覆盖项目中对应路径的文件
3. 建议先备份原文件

---

## 附带文档

| 文档 | 说明 |
|:---|:---|
| `开发规格书_v2.0.md` | 完整修正后的设计规格书 |
| `v1到v2差异汇总.md` | 40处修改对照表 |
| `代码修改任务清单.md` | 剩余31项代码修改任务（Phase 3+4+5） |

---

## 下一步

Phase 1+2（数据层+回合结构）已完成。剩余任务：
- **Phase 3**：训练系统重写、战斗引擎修正
- **Phase 4**：商店/PVP/终局系统修正
- **Phase 5**：排行榜/魔城币/事件池收尾

如需继续，请确认开始 Phase 3。
