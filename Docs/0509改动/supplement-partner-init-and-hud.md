# 补充文档：伙伴初始化数据来源 + HUD动态刷新规范

> 补充日期：2026-05-09
> 补充到：03_data_schema.md / 01_module_breakdown.md / 06_ui_flow_design.md
> 目的：>   1. 明确伙伴属性初始化从 partner_config.json 读取
>   2. 明确HUD中属性条、HP显示、伙伴槽位的动态刷新规则

---

## 第一部分：伙伴初始化数据来源

### 一、现状问题

**`03_data_schema.md` 有字段，但 `01_module_breakdown.md` 没说谁读它**。

`partner_config` 表字段（已存在）：
```json
{
  "partner_id": "partner_swordsman",
  "partner_name": "剑士",
  "role": "输出型·力量",
  "favored_attr": 2,          // 力量
  "base_physique": 10,
  "base_strength": 12,
  "base_agility": 10,
  "base_technique": 8,
  "base_spirit": 8,
  "assist_skill_id": "aid_swordsman_01",
  "support_skill_id": "sup_swordsman_01",
  "portrait_color": "#E74C3C"
}
```

`CharacterManager.initialize_partners()` 当前（错误实现）：
```gdscript
# 硬编码所有属性=10
p.current_vit = 10
p.current_str = 10
p.current_agi = 10
p.current_tec = 10
p.current_mnd = 10
```

**问题**：即使Agent按文档实现了，文档也没告诉它要从 `partner_config` 读取 `base_physique`/`base_strength` 等字段。

### 二、修正：明确初始化数据来源

**`01_module_breakdown.md` 中 CharacterManager 职责应明确添加**：

```
CharacterManager 职责扩展：
  - 初始化主角时，从 hero_config.json 读取基础属性（base_physique/base_strength/...）
  - 初始化伙伴时，从 partner_config.json 读取基础属性（base_physique/base_strength/...）
  - 运行时属性计算：当前值 = 基础值 + 锻炼加成 + 伙伴支援加成 + 熟练度加成 + 装备加成（如有）
  - 注意：Phase 1/2 没有装备系统，装备加成项固定为0
```

**`03_data_schema.md` 中 partner_config 表应增加注释**：

```
partner_config — 伙伴配置
> **注意**：此表中的 base_physique/base_strength/base_agility/base_technique/base_spirit
> 是伙伴加入队伍时的**初始属性值**。CharacterManager.initialize_partners() 必须读取这些字段
> 来初始化 RuntimePartner 的 current_vit/current_str/current_agi/current_tec/current_mnd。
```

### 三、修正后的 initialize_partners() 伪代码

```gdscript
func initialize_partners(partner_config_ids: Array[int]) -> Array[RuntimePartner]:
    _partners.clear()
    for pid in partner_config_ids:
        var config: Dictionary = ConfigManager.get_partner_config(str(pid))
        if config.is_empty():
            push_warning("[CharacterManager] Partner config not found: %d" % pid)
            continue
        
        var p := RuntimePartner.new()
        p.partner_config_id = pid
        p.current_level = 1
        p.is_active = true
        
        # **修正：从 partner_config 读取基础属性**
        p.current_vit = config.get("base_physique", 10)
        p.current_str = config.get("base_strength", 10)
        p.current_agi = config.get("base_agility", 10)
        p.current_tec = config.get("base_technique", 10)
        p.current_mnd = config.get("base_spirit", 10)
        
        _partners.append(p)
    return _partners
```

### 四、验证清单

| # | 验证项 | 预期值 |
|:---:|:---|:---|
| 1 | 剑士(base_physique=10, base_strength=12) | current_vit=10, current_str=12 |
| 2 | 斥候(base_physique=8, base_agility=14) | current_vit=8, current_agi=14 |
| 3 | 盾卫(base_physique=14, base_strength=10) | current_vit=14, current_str=10 |

---

## 第二部分：HUD动态刷新规范

### 一、现状问题

`06_ui_flow_design.md` 描述了HUD布局，但**所有UI元素是静态的**（固定值、固定颜色、固定文本）：

| HUD元素 | 文档描述 | 实际问题 |
|:---|:---|:---|
| 金币Label | "金币: XXX" | 不知道"XXX"怎么更新 |
| 生命Label | "生命: 100/100" | max_hp由体魄计算，不是固定100 |
| 5个属性条 | ProgressBar(value=50) | max_value固定=100，属性涨到120时溢出 |
| 5个属性Label | "体魄"、"力量"等 | 不显示当前数值 |
| 伙伴槽位 | "伙伴1~5" | 不显示实际伙伴名称和等级 |

### 二、动态刷新规范

#### 2.1 金币显示

```gdscript
# RunMain.gd — 金币变化回调
func _on_gold_changed(new_amount: int, delta: int, reason: String) -> void:
    gold_label.text = "金币: %d" % new_amount
    # 可选：显示变化动画（delta为正时绿色闪烁，为负时红色闪烁）
```

#### 2.2 生命显示（HP/MaxHP）

```gdscript
# RunMain.gd — HP变化回调
func _on_hp_changed(new_hp: int, max_hp: int, unit_id: String) -> void:
    if unit_id == "hero":  # 只更新主角HP
        hp_label.text = "生命: %d/%d" % [new_hp, max_hp]
        hp_bar.value = new_hp
        hp_bar.max_value = max_hp
        hp_bar.tint_progress = _get_hp_color(new_hp, max_hp)  # 绿→黄→红渐变
```

**MaxHP 计算规则**（从 `04_battle_engine_design.md` 提取并明确）：
```
max_hp = physique × 10 + 50
```
- 勇者初始体魄12 → max_hp = 12×10+50 = **170**
- 铁卫初始体魄16 → max_hp = 16×10+50 = **210**
- 文档中的"生命: 100/100"是错误的占位值

#### 2.3 属性条（ProgressBar）

**max_value 动态计算规则**：
```gdscript
# 属性条最大值 = max(初始值, 当前值) × 1.2
# 这样属性增长时条不会溢出，同时留有一定余量
func _update_attr_bar(attr_code: int, current_value: int, initial_value: int) -> void:
    var bar: ProgressBar = _attr_bars[attr_code - 1]  # 0-based index
    var label: Label = _attr_labels[attr_code - 1]
    
    var max_val: int = max(initial_value, current_value) * 1.2
    bar.max_value = max_val
    bar.value = current_value
    
    # 标签显示："属性名: 当前值 (初始值)"
    var attr_names: Array[String] = ["体魄", "力量", "敏捷", "技巧", "精神"]
    label.text = "%s: %d (%d)" % [attr_names[attr_code - 1], current_value, initial_value]
```

**初始值来源**：从 hero_config / partner_config 的 base_physique/base_strength 等字段读取。

#### 2.4 伙伴槽位刷新

```gdscript
# RunMain.gd — 伙伴解锁/升级回调
func _on_partner_unlocked(partner_id: String, partner_name: String, slot: int, level: int) -> void:
    var slot_rect: ColorRect = _partner_slots[slot - 1]
    var label: Label = slot_rect.get_node("Label")
    
    label.text = "%s Lv%d" % [partner_name, level]
    
    # 颜色从 partner_config 读取 portrait_color
    var config: Dictionary = ConfigManager.get_partner_config(partner_id)
    var color_str: String = config.get("portrait_color", "#FFFFFF")
    slot_rect.color = Color(color_str)

# 初始队伍初始化时也调用（酒馆选伙伴后）
func _init_partner_slots(partners: Array[RuntimePartner]) -> void:
    for i in range(5):
        if i < partners.size():
            var p: RuntimePartner = partners[i]
            var config: Dictionary = ConfigManager.get_partner_config(str(p.partner_config_id))
            var name: String = config.get("partner_name", "伙伴")
            var color_str: String = config.get("portrait_color", "#FFFFFF")
            
            _partner_slots[i].color = Color(color_str)
            _partner_slots[i].get_node("Label").text = "%s Lv%d" % [name, p.current_level]
            _partner_slots[i].visible = true
        else:
            _partner_slots[i].visible = false  # 空槽位隐藏
```

### 三、信号→UI的完整映射表

| 信号 | 发射方 | 参数 | UI响应 | 刷新元素 |
|:---|:---|:---|:---|:---|
| `gold_changed` | RunController/ShopSystem | `(new_amount, delta, reason)` | `_on_gold_changed()` | 金币Label |
| `hp_changed` | CharacterManager/BattleEngine | `(new_hp, max_hp, unit_id)` | `_on_hp_changed()` | 生命Label + HP条 |
| `stats_changed` | CharacterManager | `(unit_id, changes)` | `_on_stats_changed()` | 5个属性条 + 标签 |
| `partner_unlocked` | CharacterManager | `(partner_id, name, slot, level)` | `_on_partner_unlocked()` | 伙伴槽位ColorRect + Label |
| `proficiency_stage_changed` | CharacterManager | `(attr_code, name, stage, count)` | `_on_stage_changed()` | 属性条颜色/边框（可选） |

### 四、初始值持久化

HUD刷新需要知道"初始值"（用于计算max_value和显示对比），但RuntimeHero中没有保存初始值字段。

**建议**：
```gdscript
# RuntimeHero 增加字段
var initial_vit: int = 0
var initial_str: int = 0
var initial_agi: int = 0
var initial_tec: int = 0
var initial_mnd: int = 0

# CharacterManager.initialize_hero() 中保存
_hero.initial_vit = config.get("base_physique", 10)
_hero.initial_str = config.get("base_strength", 10)
# ...
```

### 五、跨文档修正对照

| 本文档内容 | 应补充到哪份文档 | 补充位置 |
|:---|:---|:---|
| 二、伙伴初始化数据来源 | `01_module_breakdown.md` | CharacterManager 职责描述 |
| partner_config base_* 字段注释 | `03_data_schema.md` | partner_config 表定义 |
| 2.2 MaxHP计算规则 | `05_run_loop_design.md` | 新增"属性计算"子节 |
| 2.3 属性条max_value动态规则 | `06_ui_flow_design.md` | 3.3节 "HUD节点详细设计" |
| 2.4 伙伴槽位刷新规范 | `06_ui_flow_design.md` | 3.3节 "伙伴槽位" |
| 三、信号→UI映射表 | `02_interface_contracts.md` | 2.1节 信号清单（扩展说明列） |
| 四、初始值持久化 | `03_data_schema.md` | runtime_hero 表定义 |

---

*补充文档版本：v1.0*
*日期：2026-05-09*
