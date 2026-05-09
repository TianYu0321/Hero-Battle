# 03_数据表Schema设计 — Phase 1 MVP完整集（已对齐规格书）

> **版本**: v2.0 | **范围**: Phase 1 MVP | **表数**: 27张
> **对齐状态**: 已与《开发规格书_赛马娘版Q宠大乐斗》3.1/3.2/3.3/4.x/5.x/6.x节对齐
> **对齐标注**: 所有修改标注 `[已对齐: 规格书X.X节]`，规格书未明确的保留 `[待确认: 规格书未明确]`

---

## 目录

- [全局约定](#全局约定)
- [一、静态配置表（Config）](#一静态配置表config)
  - [1. hero_config — 主角配置](#1-hero_config--主角配置)
  - [2. partner_config — 伙伴配置](#2-partner_config--伙伴配置)
  - [3. skill_config — 技能配置](#3-skill_config--技能配置)
  - [4. partner_assist_config — 伙伴战斗援助配置](#4-partner_assist_config--伙伴战斗援助配置)
  - [5. partner_support_config — 伙伴锻炼支援配置](#5-partner_support_config--伙伴锻炼支援配置)
  - [6. attribute_mastery_config — 属性熟练度阶段配置](#6-attribute_mastery_config--属性熟练度阶段配置)
  - [7. node_config — 节点类型定义](#7-node_config--节点类型定义)
  - [8. node_pool_config — 节点池配置](#8-node_pool_config--节点池配置)
  - [9. enemy_config — 敌人模板配置](#9-enemy_config--敌人模板配置)
  - [10. battle_formula_config — 战斗公式参数配置](#10-battle_formula_config--战斗公式参数配置)
  - [11. shop_config — 商店商品配置](#11-shop_config--商店商品配置)
  - [12. scoring_config — 通关评分公式配置](#12-scoring_config--通关评分公式配置)
- [二、局内运行时数据表（Runtime）](#二局内运行时数据表runtime)
  - [13. runtime_run — 单次养成运行](#13-runtime_run--单次养成运行)
  - [14. runtime_hero — 主角运行时状态](#14-runtime_hero--主角运行时状态)
  - [15. runtime_partner — 伙伴运行时状态](#15-runtime_partner--伙伴运行时状态)
  - [16. runtime_mastery — 属性熟练度运行时状态](#16-runtime_mastery--属性熟练度运行时状态)
  - [17. runtime_buff — 临时Buff/Debuff](#17-runtime_buff--临时buffdebuff)
  - [18. runtime_training_log — 锻炼记录日志](#18-runtime_training_log--锻炼记录日志)
  - [19. runtime_final_battle — 终局战数据](#19-runtime_final_battle--终局战数据)
- [三、局外存档数据表（Archive）](#三局外存档数据表archive)
  - [20. player_account — 玩家账号](#20-player_account--玩家账号)
  - [21. fighter_archive_main — 斗士档案主表](#21-fighter_archive_main--斗士档案主表)
  - [22. fighter_archive_partner — 档案伙伴快照](#22-fighter_archive_partner--档案伙伴快照)
  - [23. fighter_archive_score — 档案评分明细](#23-fighter_archive_score--档案评分明细)
- [四、战斗数据表（Battle）](#四战斗数据表battle)
  - [24. battle_main — 战斗主表](#24-battle_main--战斗主表)
  - [25. battle_round — 战斗回合记录](#25-battle_round--战斗回合记录)
  - [26. battle_action — 战斗行动记录](#26-battle_action--战斗行动记录)
  - [27. battle_final_result — 战斗最终结果](#27-battle_final_result--战斗最终结果)
- [五、全局关系图](#五全局关系图)
- [六、Phase 1 占位数据汇总](#六phase-1-占位数据汇总)
- [附录：待确认事项汇总](#附录待确认事项汇总)

---

## 全局约定

### 五属性编码（全局统一，禁止字符串混用）

| 编码(int) | 属性名 | 英文代号 |
|:---:|:---|:---|
| 1 | 体魄 | VIT (Vitality) |
| 2 | 力量 | STR (Strength) |
| 3 | 敏捷 | AGI (Agility) |
| 4 | 技巧 | TEC (Technique) |
| 5 | 精神 | MND (Mind) |

> `[已对齐: 规格书3.3节]` 所有数据表中的属性字段统一使用此编码，禁止混用字符串和数字。

### 元素类型编码（Phase 1不启用）

| 编码(int) | 元素名 |
|:---:|:---|
| 0 | 无元素 |

> `[已对齐: 规格书未定义元素系统]` Phase 1不涉及元素克制体系，所有skill_config.element_type固定为0。

### 通用枚举定义

```
enum NodeType:       # 节点类型 [已对齐: 规格书4.2节]
    TRAINING   = 1  # 锻炼节点
    BATTLE     = 2  # 普通战斗
    ELITE      = 3  # 精英战
    SHOP       = 4  # 商店
    RESCUE     = 5  # 救援
    PVP_CHECK  = 6  # PVP检定（第10/20回）
    FINAL      = 7  # 终局战（第30回）

enum SkillType:      # 技能类型 [已对齐: 规格书4.7节]
    PASSIVE    = 1  # 被动技能/常驻触发
    ACTIVE     = 2  # 主动技能
    ULTIMATE   = 3  # 必杀技（整场限1次）
    AID        = 4  # 伙伴援助技 [已对齐: 规格书4.4节]

enum AidTriggerType: # 伙伴援助触发类型 [已对齐: 规格书4.4节]
    FIXED_TURN = 1  # 固定回合触发
    CONDITION  = 2  # 条件触发（如HP<50%）
    PROBABILITY= 3  # 概率触发（每回合检查）
    PASSIVE    = 4  # 被动常驻（持续生效）
    CHAIN      = 5  # 连锁触发（特定事件后）
    ENEMY_ACT  = 6  # 敌方触发（受击后等）

enum TargetType:     # 技能目标类型
    SELF       = 1  # 自身
    SINGLE_ENEMY = 2 # 单体敌人
    ALL_ENEMY  = 3  # 全体敌人
    SINGLE_ALLY = 4 # 单体友方
    ALL_ALLY   = 5  # 全体友方

enum RunStatus:      # 养成运行状态
    ONGOING    = 1  # 进行中
    WIN        = 2  # 终局胜利
    LOSE       = 3  # 终局失败/精英战败北
    ABANDON    = 4  # 中途放弃

enum RarityType:     # 稀有度
    COMMON     = 1  # 普通（N）
    RARE       = 2  # 稀有（R）
    EPIC       = 3  # 史诗（SR）
    LEGEND     = 4  # 传说（SSR）

enum MasteryStage:   # 属性熟练度阶段 [已对齐: 规格书4.5节]
    NOVICE     = 1  # 生疏（0次）
    FAMILIAR   = 2  # 熟悉（1-3次）
    PROFICIENT = 3  # 精通（4-6次）
    EXPERT     = 4  # 专精（≥7次）

enum PartnerPosition:# 伙伴站位 [已对齐: 规格书4.4节]
    COMPANION  = 1  # 同行伙伴（酒馆选的前2名）
    RESCUE_1   = 2  # 第1次救援（第5回）
    RESCUE_2   = 3  # 第2次救援（第15回）
    RESCUE_3   = 4  # 第3次救援（第25回）

enum BattleType:     # 战斗类型 [已对齐: 规格书4.3节]
    NORMAL     = 1  # 普通战斗（简化快进）
    ELITE      = 2  # 精英战（标准播放）
    PVP        = 3  # PVP检定（标准播放）
    FINAL      = 4  # 终局战（标准播放+日志）

enum BattleResult:   # 战斗结果
    WIN        = 1  # 胜利
    LOSE       = 2  # 失败
    DRAW       = 3  # 平局（20回合到限）
```

### 命名规范
- 所有表名：`snake_case`，后缀区分用途（`_config`、`_runtime`、无后缀表示存档）
- 所有字段名：`snake_case`
- 主键统一命名：`id`（整型自增或配置ID）
- 外键命名：`_id` 结尾，如 `hero_id`、`skill_id`
- 时间戳字段：`created_at`、`updated_at`（Unix时间戳int）

### ID区间规划

| 区间 | 用途 | 说明 |
|:---:|:---|:---|
| 1~999 | 主角配置ID | 3名主角 |
| 1001~1999 | 伙伴配置ID | Phase 1: 6名 |
| 2001~2999 | 敌人模板ID | Phase 1: 5种 |
| 3001~3999 | 商店商品ID | Phase 1: 约8条 |
| 4001~4999 | 节点/节点池ID | Phase 1: 约10条 |
| 5001~5999 | 属性熟练度配置ID | Phase 1: 4阶段×5属性=20条 |
| 6001~6999 | 伙伴援助配置ID | Phase 1: 6条 |
| 7001~7999 | 伙伴支援配置ID | Phase 1: 6条 |
| 8001~8999 | 技能配置ID | Phase 1: 约25条 |
| 1~10 | 战斗公式/评分配置ID | Phase 1: 各1~2条 |

---

## 一、静态配置表（Config）

> 设计原则：配置表在Phase 1全部为**只读**，游戏启动时加载到内存或按需读取。

---

### 1. hero_config — 主角配置

**用途**：定义4名主角（勇者/影舞者/铁卫/术士）的基础属性、技能绑定。Phase 1使用3名（勇者/影舞者/铁卫），术士Phase 2加入。

**Phase 1占位数据量**：3条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 1~999 | 主角唯一配置ID |
| name | String | 是 | "" | 长度<=16 | 主角名称（如"勇者"） |
| title | String | 是 | "" | 长度<=32 | 职业称号（如"均衡型剑士"） |
| rarity | int | 是 | 4 | 4=LEGEND | 主角均为传说品质 `[已对齐: 规格书4.7节]` |
| description | String | 否 | "" | 长度<=256 | 角色背景描述 |
| icon_path | String | 是 | "" | 资源路径 | 头像图标路径（占位用默认） |
| model_path | String | 是 | "" | 资源路径 | 角色立绘路径（占位用默认） |
| base_vit | int | 是 | 10 | 1~999 | 基础体魄 `[已对齐: 规格书4.7节]` |
| base_str | int | 是 | 10 | 1~999 | 基础力量 `[已对齐: 规格书4.7节]` |
| base_agi | int | 是 | 10 | 1~999 | 基础敏捷 `[已对齐: 规格书4.7节]` |
| base_tec | int | 是 | 10 | 1~999 | 基础技巧 `[已对齐: 规格书4.7节]` |
| base_mnd | int | 是 | 10 | 1~999 | 基础精神 `[已对齐: 规格书4.7节]` |
| passive_skill_id | int | 是 | 0 | skill_config.id | 常规技能ID（外键→skill_config） `[已对齐: 规格书4.7节]` |
| ultimate_skill_id | int | 是 | 0 | skill_config.id | 必杀技ID（外键→skill_config） `[已对齐: 规格书4.7节]` |
| is_default_unlock | bool | 是 | true | true/false | 是否默认解锁 `[已对齐: 规格书6.1节]` |
| unlock_condition_text | String | 否 | "" | 自由文本 | 解锁条件描述（如"勇者通关1次"） `[已对齐: 规格书6.1节]` |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

**关系**：
- 1:N → `skill_config`（passive_skill_id / ultimate_skill_id引用2个技能）

**具体初始属性值** `[已对齐: 规格书4.7节]`：

| 主角ID | 名称 | 体魄 | 力量 | 敏捷 | 技巧 | 精神 | 常规技能 | 必杀技 |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---|:---|
| 1 | 勇者 | 12 | 16 | 10 | 12 | 8 | 追击斩 | 终结一击 |
| 2 | 影舞者 | 10 | 10 | 16 | 10 | 12 | 疾风连击 | 风暴乱舞 |
| 3 | 铁卫 | 16 | 8 | 10 | 10 | 14 | 铁壁反击 | 不动如山 |
| 4 | 术士 | 10 | 8 | 10 | 12 | 16 | 灵魂灼烧 | 灵魂收割(Phase 2) |

> `[已对齐: 规格书4.7节]` 主角之间**仅初始值不同**，属性成长完全由锻炼次数和伙伴支援决定，成长系数统一为1.0。

---

### 2. partner_config — 伙伴配置

**用途**：定义12名伙伴的基础信息、定位、擅长属性。Phase 1配置6名默认解锁伙伴（剑士/斥候/盾卫/药师/术士伙伴/猎人）。

**Phase 1占位数据量**：6条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 1001~1999 | 伙伴唯一配置ID |
| name | String | 是 | "" | 长度<=16 | 伙伴名称（如"剑士"） |
| title | String | 是 | "" | 长度<=32 | 职业定位（如"力量型输出伙伴"） |
| rarity | int | 是 | 2 | 1~4 | 稀有度（R=2, SR=3）`[已对齐: 规格书4.8节]` |
| description | String | 否 | "" | 长度<=256 | 角色背景描述 |
| icon_path | String | 是 | "" | 资源路径 | 头像图标路径（占位用默认） |
| favored_attr | int | 是 | 1 | 1~5 | 擅长属性（五属性编码） `[已对齐: 规格书4.8节]` |
| aid_trigger_type | int | 是 | 1 | 1~6 | 援助触发类型（AidTriggerType枚举） `[已对齐: 规格书4.4节]` |
| linked_hero_id | int | 否 | 0 | hero_config.id | 最优联动主角ID，0=通用 `[已对齐: 规格书4.8节]` |
| is_default_unlock | bool | 是 | true | true/false | Phase 1是否默认解锁 `[已对齐: 规格书6.1节]` |
| unlock_condition_text | String | 否 | "" | 自由文本 | 解锁条件描述 `[已对齐: 规格书6.1节]` |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

**关系**：
- N:1 → `partner_assist_config`（战斗援助配置，通过partner_id关联）
- N:1 → `partner_support_config`（锻炼支援配置，通过partner_id关联）

**Phase 1的6名默认解锁伙伴** `[已对齐: 规格书4.8节/6.1节]`：

| ID | 名称 | 定位 | 擅长属性 | 触发类型 | 联动主角 | 默认解锁 |
|:---:|:---|:---|:---:|:---|:---|:---:|
| 1001 | 剑士 | 输出型 | 力量(2) | 攻击后概率 | 勇者 | 是 |
| 1002 | 斥候 | 输出型 | 敏捷(3) | 暴击后触发 | 影舞者 | 是 |
| 1003 | 盾卫 | 防御型 | 体魄(1) | 受击后触发 | 铁卫 | 是 |
| 1004 | 药师 | 辅助型 | 精神(5) | 条件触发(低血) | 通用 | 是 |
| 1005 | 术士 | 控场型 | 技巧(4) | 概率触发 | 通用 | 是 |
| 1006 | 猎人 | 斩杀型 | 技巧(4) | 条件触发(低血) | 勇者 | 是 |

---

### 3. skill_config — 技能配置

**用途**：定义所有技能的参数模板，包括常规技能、必杀技。

**Phase 1占位数据量**：约20条（3主角×2技能 + 6伙伴援助技 + 通用模板）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 8001~8999 | 技能唯一配置ID |
| name | String | 是 | "" | 长度<=32 | 技能名称 |
| description | String | 是 | "" | 长度<=512 | 技能效果描述（UI展示用） |
| skill_type | int | 是 | 1 | 1~4 | 技能类型：1=PASSIVE, 2=ACTIVE, 3=ULTIMATE, 4=AID `[已对齐: 规格书4.7节]` |
| owner_hero_id | int | 否 | 0 | hero_config.id | 所属主角ID，0=通用/伙伴技能 |
| owner_partner_id | int | 否 | 0 | partner_config.id | 所属伙伴ID，0=通用/主角技能 |
| target_type | int | 是 | 2 | 1~5 | 目标类型：1=SELF, 2=SINGLE_ENEMY, 3=ALL_ENEMY, 4=SINGLE_ALLY, 5=ALL_ALLY |
| element_type | int | 否 | 0 | 0 | Phase 1无元素系统，固定为0 `[已对齐: 规格书未定义元素系统]` |
| power_attr | int | 是 | 1 | 1~5 | 技能威力关联属性（五属性编码） |
| power_scale | float | 是 | 1.0 | 0.0~100.0 | 威力系数（如0.6 = 60%属性值） `[已对齐: 规格书4.7节]` |
| base_trigger_prob | float | 否 | 0.0 | 0.0~1.0 | 基础触发概率（如追击斩30%） `[已对齐: 规格书4.7节]` |
| prob_attr_bonus | int | 否 | 0 | 1~5 | 提升触发概率的属性（如技巧提升追击斩概率） `[已对齐: 规格书4.7节]` |
| prob_attr_step | int | 否 | 10 | 1~100 | 每N点属性提升概率（如技巧每+10点） `[已对齐: 规格书4.7节]` |
| prob_attr_inc | float | 否 | 0.0 | 0.0~0.1 | 每步提升的概率值（如+2% = 0.02） `[已对齐: 规格书4.7节]` |
| prob_max | float | 否 | 0.0 | 0.0~1.0 | 触发概率上限（如追击斩上限50%） `[已对齐: 规格书4.7节]` |
| cooldown | int | 是 | 0 | 0~99 | 冷却回合数，0=无冷却 |
| once_per_battle | bool | 否 | false | true/false | 是否整场限1次（必杀技=true） `[已对齐: 规格书4.7节]` |
| condition_desc | String | 否 | "" | 自由文本 | 触发条件描述（如"敌方HP<40%"） `[已对齐: 规格书4.7节]` |
| special_effect | String | 否 | "" | 自由文本 | 特殊效果描述（如"无视30%防御"） `[已对齐: 规格书4.7节]` |
| chain_tags | Array[String] | 否 | [] | 标签数组 | 连锁标签（如["追击","反击"]） `[已对齐: 规格书4.4节]` |
| icon_path | String | 是 | "" | 资源路径 | 技能图标路径 |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

**关系**：
- N:1 ← `hero_config` / `partner_config`（被引用）

---

### 4. partner_assist_config — 伙伴战斗援助配置

**用途**：定义每名伙伴在战斗中的援助能力参数。`[已对齐: 规格书4.4节/4.8节]`

**Phase 1占位数据量**：6条（Phase 1的6名默认解锁伙伴各1条）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 6001~6999 | 援助配置唯一ID |
| partner_id | int | 是 | 0 | partner_config.id | 所属伙伴ID（外键） |
| trigger_type | int | 是 | 1 | 1~6 | 触发类型（AidTriggerType枚举） `[已对齐: 规格书4.4节]` |
| trigger_condition | String | 是 | "" | 条件描述 | 触发条件（如"主角攻击后""敌方HP<40%"） `[已对齐: 规格书4.8节]` |
| trigger_prob | float | 否 | 0.0 | 0.0~1.0 | 触发概率（条件触发型可为1.0=必触发） `[已对齐: 规格书4.8节]` |
| effect_type | int | 是 | 1 | 1~5 | 效果类型：1=造成伤害, 2=治疗, 3=护盾, 4=BUFF, 5=DEBUFF |
| effect_attr | int | 是 | 1 | 1~5 | 效果关联属性（五属性编码） |
| effect_scale_lv1 | float | 是 | 0.0 | 0.0~100.0 | Lv1效果系数（如剑气斩攻击力×0.5） `[已对齐: 规格书4.8节]` |
| effect_scale_lv3 | float | 是 | 0.0 | 0.0~100.0 | Lv3质变效果系数 `[已对齐: 规格书4.8节]` |
| effect_scale_lv5 | float | 否 | 0.0 | 0.0~100.0 | Lv5效果系数（Phase 1只做Lv3，Lv5占位） `[已对齐: 规格书1.3节决策6]` |
| lv3_mechanic_desc | String | 否 | "" | 自由文本 | Lv3质变机制描述 `[已对齐: 规格书4.8节]` |
| lv5_mechanic_desc | String | 否 | "" | 自由文本 | Lv5机制描述（Phase 1占位） `[已对齐: 规格书1.3节决策6]` |
| cooldown | int | 是 | 0 | 0~99 | 冷却回合数，0=无冷却 |
| max_trigger_per_battle | int | 否 | 999 | 1~999 | 单场最大触发次数（默认无限制） `[已对齐: 规格书4.4节]` |
| chain_max | int | 是 | 4 | 1~4 | 最大连锁段数 `[已对齐: 规格书4.4节]` |
| chain_window | int | 是 | 3 | 1~10 | 连锁判定窗口（连续N次同属性攻击触发连锁） `[待确认: 规格书未明确]` |

**关系**：
- N:1 → `partner_config`（partner_id关联）

---

### 5. partner_support_config — 伙伴锻炼支援配置

**用途**：定义每名伙伴在锻炼节点中提供的属性加成。`[已对齐: 规格书4.5节/4.8节]`

**Phase 1占位数据量**：6条（Phase 1的6名默认解锁伙伴各1条）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 7001~7999 | 支援配置唯一ID |
| partner_id | int | 是 | 0 | partner_config.id | 所属伙伴ID（外键） |
| supported_attr | int | 是 | 1 | 1~5 | 支援属性（五属性编码） `[已对齐: 规格书4.8节]` |
| bonus_lv1 | int | 是 | 2 | 0~999 | Lv1锻炼加成值（如+2力量） `[已对齐: 规格书4.8节]` |
| bonus_lv3 | int | 是 | 4 | 0~999 | Lv3锻炼加成值（如+4力量） `[已对齐: 规格书4.8节]` |
| bonus_lv5 | int | 否 | 6 | 0~999 | Lv5锻炼加成值（Phase 1占位） `[已对齐: 规格书1.3节决策6]` |
| extra_effect | String | 否 | "" | 自由文本 | 额外效果（如"猎人锻炼技巧时+1金币"） `[已对齐: 规格书4.8节]` |
| cost_hp_on_training | int | 否 | 0 | 0~999 | 锻炼时消耗生命（如狂战士消耗1点） `[已对齐: 规格书4.8节]` |

**关系**：
- N:1 → `partner_config`（partner_id关联）

---

### 6. attribute_mastery_config — 属性熟练度阶段配置

**用途**：定义五属性各熟练度阶段的锻炼次数阈值与加成值。`[已对齐: 规格书4.5节]`

> **重要 redesign**: 原设计为"等级+XP"系统，规格书4.5节定义为"锻炼次数→阶段→加成"的直接映射。已按规格书重新设计。

**Phase 1占位数据量**：20条（5属性 × 4阶段）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 5001~5999 | 熟练度配置唯一ID |
| attr_type | int | 是 | 1 | 1~5 | 属性类型（五属性编码） `[已对齐: 规格书3.3节]` |
| stage | int | 是 | 1 | 1~4 | 阶段：1=生疏, 2=熟悉, 3=精通, 4=专精 `[已对齐: 规格书4.5节]` |
| stage_name | String | 是 | "" | 长度<=16 | 阶段名称 `[已对齐: 规格书4.5节]` |
| training_count_min | int | 是 | 0 | 0~999 | 该阶段最少锻炼次数（含） `[已对齐: 规格书4.5节]` |
| training_count_max | int | 是 | 0 | 0~999 | 该阶段最多锻炼次数（-1=无上限） `[已对齐: 规格书4.5节]` |
| training_bonus | int | 是 | 0 | 0~999 | 该阶段锻炼收益加成 `[已对齐: 规格书4.5节]` |
| display_color | String | 否 | "#FFFFFF" | HEX颜色码 | UI展示颜色（生疏=灰, 熟悉=绿, 精通=蓝, 专精=紫）`[已对齐: 规格书4.5节]` |

**关系**：
- 1:N ← `runtime_mastery`（运行时按 attr_type + stage 匹配）

**具体配置数据** `[已对齐: 规格书4.5节]`：

| 属性 | 阶段 | 阶段名 | 次数范围 | 加成 | 颜色 |
|:---:|:---:|:---|:---:|:---:|:---:|
| 1~5 | 1 | 生疏 | 0 | +0 | #999999 |
| 1~5 | 2 | 熟悉 | 1~3 | +2 | #66CC66 |
| 1~5 | 3 | 精通 | 4~6 | +4 | #6699FF |
| 1~5 | 4 | 专精 | ≥7 | +5 | #CC66FF |

> **边际递减机制**（运行时计算，非配置表）`[已对齐: 规格书4.5节]`：单项属性锻炼次数超过总锻炼次数60%时，该属性后续锻炼收益递减20%。
> **副属性共享**（运行时计算，非配置表）`[已对齐: 规格书4.5节]`：副属性锻炼享受50%的熟练度共享（如主练力量时，技巧锻炼也能获得部分熟练度加成）。

---

### 7. node_config — 节点类型定义

**用途**：定义7类节点的基本属性和参数。`[新增: 规格书3.1节定义NodeConfig为独立配置表]`

**Phase 1占位数据量**：7条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 4001~4007 | 节点类型配置ID |
| node_type | int | 是 | 1 | 1~7 | 节点类型枚举（NodeType） `[已对齐: 规格书4.2节]` |
| node_name | String | 是 | "" | 长度<=16 | 节点名称（如"锻炼"） |
| description | String | 否 | "" | 长度<=256 | 节点描述 |
| icon_path | String | 是 | "" | 资源路径 | 节点图标路径 |
| can_skip | bool | 是 | true | true/false | 玩家是否可选择跳过 `[已对齐: 规格书5.2节]` |
| is_fixed_turn | bool | 是 | false | true/false | 是否固定回合出现（如终局战=第30回） `[已对齐: 规格书4.2节]` |
| fixed_turn | int | 否 | 0 | 1~30 | 固定出现的回合数，0=不固定 `[已对齐: 规格书4.2节]` |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

**固定节点回合分布** `[已对齐: 规格书4.2节]`：

| 节点类型 | 名称 | 固定回合 | 说明 |
|:---:|:---|:---:|:---|
| RESCUE(5) | 救援 | 5, 15, 25 | 第5/15/25回固定出现 |
| PVP_CHECK(6) | PVP检定 | 10, 20 | 第10/20回固定出现 |
| FINAL(7) | 终局战 | 30 | 第30回固定出现 |

---

### 8. node_pool_config — 节点池配置

**用途**：定义30回合中各阶段普通节点的随机池规则。`[已对齐: 规格书3.1节/4.2节]`

**Phase 1占位数据量**：约7条（每类普通节点1条配置）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 4101~4999 | 节点池规则唯一配置ID |
| node_type | int | 是 | 1 | 1~7 | 节点类型（NodeType枚举） `[已对齐: 规格书4.2节]` |
| stage | int | 是 | 1 | 1~3 | 游戏阶段：1=前期(1-9回), 2=中期(10-19回), 3=后期(20-29回) `[已对齐: 规格书4.2节]` |
| weight | int | 是 | 100 | 1~10000 | 该阶段内随机权重 `[已对齐: 规格书4.2节]` |
| max_consecutive | int | 是 | 2 | 1~10 | 最多连续出现次数（防同类连续） `[已对齐: 规格书4.2节]` |
| enemy_pool | Array[int] | 否 | [] | enemy_config.id | 可刷新的敌人模板ID列表（BATTLE/ELITE时） `[已对齐: 规格书5.1节/5.2节]` |
| shop_item_pool | Array[int] | 否 | [] | shop_config.id | 可刷新的商品ID列表（SHOP时） |
| rescue_partner_pool | Array[int] | 否 | [] | partner_config.id | 可遇到的伙伴ID列表（RESCUE时） `[已对齐: 规格书4.2节]` |
| training_options | Array[int] | 否 | [1,2,3,4,5] | 1~5 | 锻炼选项=五属性选择（固定[1,2,3,4,5]） `[已对齐: 规格书3.3节]` |

**关系**：
- N:M → `enemy_config`（enemy_pool数组引用）
- N:M → `shop_config`（shop_item_pool数组引用）
- N:M → `partner_config`（rescue_partner_pool数组引用）

---

### 9. enemy_config — 敌人模板配置

**用途**：定义5种精英敌人模板，用于普通战斗、精英战、终局战的敌人实例化。`[已对齐: 规格书5.2节]`

**Phase 1占位数据量**：5条（5种精英敌人模板）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 2001~2999 | 敌人模板唯一配置ID |
| name | String | 是 | "" | 长度<=32 | 敌人名称（如"重甲守卫"） `[已对齐: 规格书5.2节]` |
| difficulty_tier | int | 是 | 1 | 1~5 | 难度层级（1=最简单，5=最难） `[已对齐: 规格书5.2节]` |
| description | String | 否 | "" | 长度<=256 | 敌人描述 `[已对齐: 规格书5.2节]` |
| icon_path | String | 是 | "" | 资源路径 | 敌人图标路径 |
| vit_base | int | 是 | 0 | 0~9999 | 体魄固定基础值 `[修正:S3: 从String公式改为数值系数]` |
| vit_scale_hero_attr | int | 是 | 0 | 1~5或0 | 体魄取自主角哪项属性（1=体魄,2=力量,3=敏捷,4=技巧,5=精神,0=不取） `[修正:S3]` |
| vit_scale_hero_coeff | float | 是 | 0.0 | 0.0~10.0 | 体魄取自主角属性的系数（如2.0=主角力量×2.0） `[修正:S3]` |
| str_base | int | 是 | 0 | 0~9999 | 力量固定基础值 `[修正:S3]` |
| str_scale_hero_attr | int | 是 | 0 | 0~5 | 力量取自主角哪项属性（编码同上，0=不取） `[修正:S3]` |
| str_scale_hero_coeff | float | 是 | 0.0 | 0.0~10.0 | 力量取自主角属性的系数 `[修正:S3]` |
| agi_base | int | 是 | 0 | 0~9999 | 敏捷固定基础值 `[修正:S3]` |
| agi_scale_hero_attr | int | 是 | 0 | 0~5 | 敏捷取自主角哪项属性 `[修正:S3]` |
| agi_scale_hero_coeff | float | 是 | 0.0 | 0.0~10.0 | 敏捷取自主角属性的系数 `[修正:S3]` |
| tec_base | int | 是 | 0 | 0~9999 | 技巧固定基础值 `[修正:S3]` |
| tec_scale_hero_attr | int | 是 | 0 | 0~5 | 技巧取自主角哪项属性 `[修正:S3]` |
| tec_scale_hero_coeff | float | 是 | 0.0 | 0.0~10.0 | 技巧取自主角属性的系数 `[修正:S3]` |
| spi_base | int | 是 | 0 | 0~9999 | 精神固定基础值 `[修正:S3: mnd_formula→spi_base等，五属性统一命名]` |
| spi_scale_hero_attr | int | 是 | 0 | 0~5 | 精神取自主角哪项属性 `[修正:S3]` |
| spi_scale_hero_coeff | float | 是 | 0.0 | 0.0~10.0 | 精神取自主角属性的系数 `[修正:S3]` |
| special_mechanic | String | 否 | "" | 自由文本 | 特殊机制描述（如"坚甲：伤害-25%"） `[已对齐: 规格书5.2节]` |
| appear_turn_min | int | 是 | 1 | 1~30 | 最早出现的回合数 `[已对齐: 规格书5.2节]` |
| appear_turn_max | int | 是 | 30 | 1~30 | 最晚出现的回合数 `[已对齐: 规格书5.2节]` |
| reward_gold_min | int | 是 | 0 | 0~99999 | 击杀金币奖励下限 `[已对齐: 规格书5.2节]` |
| reward_gold_max | int | 是 | 0 | 0~99999 | 击杀金币奖励上限 `[已对齐: 规格书5.2节]` |
| reward_buff_desc | String | 否 | "" | 自由文本 | 精英战3选1奖励描述 `[已对齐: 规格书5.2节]` |
| score_value | int | 是 | 0 | 0~99999 | 击杀获得基础评分 `[已对齐: 规格书6.3节]` |
| is_elite | bool | 是 | false | true/false | 是否为精英敌人（失败=本局结束） `[已对齐: 规格书5.2节]` |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

**5种敌人模板摘要** `[已对齐: 规格书5.2节]`：

| ID | 名称 | 难度 | 检测属性 | 适用回合 | 核心机制 |
|:---:|:---|:---:|:---|:---:|:---|
| 2001 | 重甲守卫 | 1 | 力量 | 3-8 | 坚甲：受到伤害-25% |
| 2002 | 暗影刺客 | 2 | 技巧/敏捷 | 8-15 | 闪避：30%概率闪避普攻 |
| 2003 | 元素法师 | 3 | 爆发/生存 | 12-18 | 蓄力爆发：第3回合力×2.5伤害 |
| 2004 | 狂战士 | 4 | 控血/timing | 15-22 | 狂暴：HP<30%时攻击×1.5 |
| 2005 | 混沌领主 | 5 | 构筑强度 | 18-25 | 成长进化：每回合全属性+5% |

**敌人属性缩放配置示例** `[修正:S3: 重甲守卫——体魄=主角力量×2.0，力量=主角力量×0.5]`：

```json
{
  "id": 2001,
  "name": "重甲守卫",
  "difficulty_tier": 1,
  "vit_base": 0, "vit_scale_hero_attr": 2, "vit_scale_hero_coeff": 2.0,
  "str_base": 0, "str_scale_hero_attr": 2, "str_scale_hero_coeff": 0.5,
  "agi_base": 0, "agi_scale_hero_attr": 0, "agi_scale_hero_coeff": 0.0,
  "tec_base": 0, "tec_scale_hero_attr": 0, "tec_scale_hero_coeff": 0.0,
  "spi_base": 0, "spi_scale_hero_attr": 0, "spi_scale_hero_coeff": 0.0,
  "special_mechanic": "坚甲：受到伤害-25%",
  "appear_turn_min": 3,
  "appear_turn_max": 8
}
```

> 含义：体魄=主角力量×2.0，力量=主角力量×0.5，其他属性无缩放（使用默认值或另行配置）。
> `[修正:S3]` 敌人属性 = base + 主角对应属性 × coeff，运行时直接数值计算，避免字符串解析。

---

### 10. battle_formula_config — 战斗公式参数配置

**用途**：集中存储战斗公式中的可调节参数，便于数值平衡调试。`[已对齐: 规格书4.3节/4.5节/6.3节]`

**Phase 1占位数据量**：1条（全局一套公式参数）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | 1 | 1 | 全局唯一配置ID |
| formula_name | String | 是 | "default" | 长度<=32 | 公式配置方案名称 |
| dmg_base_formula | String | 是 | "" | 表达式 | 基础伤害公式框架 `[已对齐: 规格书4.3节]` |
| dmg_rand_min | float | 是 | 0.9 | 0.0~2.0 | 伤害随机波动下限（90%） `[已对齐: 规格书4.3节]` |
| dmg_rand_max | float | 是 | 1.1 | 0.0~2.0 | 伤害随机波动上限（110%） `[已对齐: 规格书4.3节]` |
| atk_from_str | float | 是 | 1.0 | 0.0~1000.0 | 每点力量转化的攻击力系数 `[已对齐: 规格书4.3节]` |
| def_from_vit | float | 是 | 1.0 | 0.0~1000.0 | 每点体魄转化的防御力系数 `[已对齐: 规格书4.3节]` |
| hp_from_vit | float | 是 | 10.0 | 1.0~1000.0 | 每点体魄转化的HP `[待确认: 具体数值需数值策划确认]` |
| speed_from_agi | float | 是 | 1.0 | 0.0~1000.0 | 每点敏捷转化的速度 `[待确认: 具体数值需数值策划确认]` |
| crit_rate_base | float | 是 | 0.05 | 0.0~1.0 | 基础暴击率 `[已对齐: 规格书4.7节]` |
| crit_dmg_multiplier | float | 是 | 1.5 | 1.0~10.0 | 暴击伤害倍率（150%） `[待确认: 具体数值需数值策划确认]` |
| evade_from_agi | float | 是 | 0.0 | 0.0~1.0 | 敏捷转化为闪避率 `[待确认: 具体数值需数值策划确认]` |
| hit_from_tec | float | 是 | 0.0 | 0.0~1.0 | 技巧转化为命中率 `[待确认: 具体数值需数值策划确认]` |
| resist_from_mnd | float | 是 | 0.0 | 0.0~1.0 | 精神转化为抗性率 `[待确认: 具体数值需数值策划确认]` |
| chain_max_length | int | 是 | 4 | 1~10 | 最大连锁段数 `[已对齐: 规格书4.4节]` |
| chain_partner_max_per_battle | int | 是 | 2 | 1~10 | 每伙伴单场连锁触发上限 `[已对齐: 规格书4.4节]` |
| mastery_margin_threshold | float | 是 | 0.6 | 0.0~1.0 | 边际递减阈值（单项>60%总投入触发） `[已对齐: 规格书4.5节]` |
| mastery_margin_decrease | float | 是 | 0.2 | 0.0~1.0 | 边际递减比例（收益-20%） `[已对齐: 规格书4.5节]` |
| mastery_secondary_share | float | 是 | 0.5 | 0.0~1.0 | 副属性熟练度共享比例（50%） `[已对齐: 规格书4.5节]` |
| pvp_fail_attr_penalty | float | 否 | 0.15 | 0.0~1.0 | PVP失败后续敌人属性加成（+15%） `[已对齐: 规格书5.3节]` |
| score_damage_weight | float | 是 | 0.1 | 0.0~10.0 | 每伤害1点评分系数 `[已对齐: 规格书6.3节]` |
| score_kill_bonus | int | 是 | 100 | 0~99999 | 每击杀1个敌人评分 `[已对齐: 规格书6.3节]` |
| score_win_bonus | int | 是 | 500 | 0~999999 | 终局胜利bonus评分 `[已对齐: 规格书6.3节]` |
| score_lose_bonus | int | 是 | 100 | 0~999999 | 终局失败bonus评分 `[已对齐: 规格书6.3节]` |

> `[已对齐: 规格书4.3节]` 伤害公式框架：伤害 = 基础值 × 属性系数 × 技能倍率 × 随机波动(0.9-1.1)
> `[已对齐: 规格书4.5节]` 属性系数计算：攻击方=力量×力系数+技巧×技系数，防御方=体魄×体系数

---

### 11. shop_config — 商店商品配置

**用途**：定义商店节点中可购买的商品（主角/伙伴升级、属性加成道具等）。`[已对齐: 规格书4.6节]`

> 规格书4.6节商店系统说明：商店节点可"升级自己或升级伙伴"，资源分配是核心抉择。

**Phase 1占位数据量**：约8条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | auto | 3001~3999 | 商品唯一配置ID |
| name | String | 是 | "" | 长度<=32 | 商品名称（如"力量提升"） |
| description | String | 是 | "" | 长度<=256 | 商品描述 |
| shop_type | int | 是 | 1 | 1~4 | 商品类型：1=主角升级, 2=伙伴升级, 3=属性道具, 4=回复道具 `[已对齐: 规格书4.6节]` |
| cost_currency | int | 是 | 1 | 1 | Phase 1仅局内金币=1 `[已对齐: 规格书仅定义局内金币]` |
| cost_base | int | 是 | 0 | 0~999999 | 基础价格 `[已对齐: 规格书4.6节]` |
| cost_increase_per_buy | int | 是 | 0 | 0~999999 | 每次购买后价格增量（价格递增） `[已对齐: 规格书4.6节]` |
| target_type | int | 是 | 1 | 1~3 | 作用目标：1=主角, 2=指定伙伴, 3=全体 `[已对齐: 规格书4.6节]` |
| target_attr | int | 否 | 0 | 0~5 | 目标属性（五属性编码），0=非属性类 `[已对齐: 规格书3.3节]` |
| attr_bonus_value | int | 否 | 0 | -999~999 | 属性增加值 `[已对齐: 规格书4.6节]` |
| heal_hp_value | int | 否 | 0 | 0~99999 | 回复HP值（shop_type=4时） |
| stock_type | int | 是 | 1 | 1~2 | 库存类型：1=每局限量, 2=无限 `[已对齐: 规格书4.6节]` |
| stock_limit | int | 否 | 0 | 0~999 | 库存上限（stock_type=1时） |
| min_turn_to_appear | int | 是 | 1 | 1~30 | 最早出现的回合数 |
| max_turn_to_appear | int | 是 | 30 | 1~30 | 最晚出现的回合数 |
| weight | int | 是 | 100 | 1~10000 | 商店随机池权重 |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

> `[已对齐: 规格书4.6节]` 商店核心设计：铁卫"升级自己（更肉）or 升级伙伴（更强输出）"是资源分配的核心痛苦抉择。

---

### 12. scoring_config — 通关评分公式配置

**用途**：定义终局通关评分的计算公式和评级标准。`[新增: 规格书6.3节/6.4节定义评分系统]`

**Phase 1占位数据量**：1条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | int | 是 | 1 | 1 | 全局唯一配置ID |
| config_name | String | 是 | "default" | 长度<=32 | 评分方案名称 |
| weight_final_performance | float | 是 | 0.4 | 0.0~1.0 | 终局战表现分权重(40%) `[已对齐: 规格书6.3节]` |
| weight_training_efficiency | float | 是 | 0.2 | 0.0~1.0 | 养成效率分权重(20%) `[已对齐: 规格书6.3节]` |
| weight_pvp_performance | float | 是 | 0.2 | 0.0~1.0 | PVP表现分权重(20%) `[已对齐: 规格书6.3节]` |
| weight_build_purity | float | 是 | 0.1 | 0.0~1.0 | 流派纯度分权重(10%) `[已对齐: 规格书6.3节]` |
| weight_chain_showcase | float | 是 | 0.1 | 0.0~1.0 | 连锁展示分权重(10%) `[已对齐: 规格书6.3节]` |
| final_win_score | int | 是 | 50 | 0~100 | 终局战胜利得分 `[已对齐: 规格书6.3节]` |
| final_hp_ratio_max | int | 是 | 30 | 0~100 | 剩余生命比例满分 `[已对齐: 规格书6.3节]` |
| final_damage_ratio_max | int | 是 | 20 | 0~100 | 造成伤害比例满分 `[已对齐: 规格书6.3节]` |
| training_growth_max | int | 是 | 30 | 0~100 | 总属性成长满分 `[已对齐: 规格书6.3节]` |
| training_gold_eff_max | int | 是 | 30 | 0~100 | 金币使用效率满分 `[已对齐: 规格书6.3节]` |
| training_balance_max | int | 是 | 20 | 0~100 | 属性均衡度满分 `[已对齐: 规格书6.3节]` |
| training_elite_wr_max | int | 是 | 20 | 0~100 | 精英战胜率满分 `[已对齐: 规格书6.3节]` |
| pvp_10th_win_score | int | 是 | 40 | 0~100 | 第10回PVP胜利得分 `[已对齐: 规格书6.3节]` |
| pvp_10th_lose_score | int | 是 | 15 | 0~100 | 第10回PVP失败得分 `[已对齐: 规格书6.3节]` |
| pvp_10th_skip_score | int | 是 | 0 | 0~100 | 第10回PVP跳过得分 `[已对齐: 规格书6.3节]` |
| pvp_20th_win_score | int | 是 | 40 | 0~100 | 第20回PVP胜利得分 `[已对齐: 规格书6.3节]` |
| pvp_20th_lose_score | int | 是 | 15 | 0~100 | 第20回PVP失败得分 `[已对齐: 规格书6.3节]` |
| pvp_20th_skip_score | int | 是 | 0 | 0~100 | 第20回PVP跳过得分 `[已对齐: 规格书6.3节]` |
| purity_main_attr_max | int | 是 | 50 | 0~100 | 主属性占比满分 `[已对齐: 规格书6.3节]` |
| purity_skill_trigger_max | int | 是 | 30 | 0~100 | 技能触发次数满分 `[已对齐: 规格书6.3节]` |
| purity_partner_synergy_max | int | 是 | 20 | 0~100 | 伙伴协同满分 `[已对齐: 规格书6.3节]` |
| chain_max_score | int | 是 | 40 | 0~100 | 最大CHAIN满分(4段=40分) `[已对齐: 规格书6.3节]` |
| chain_total_max | int | 是 | 30 | 0~100 | 总连锁次数满分 `[已对齐: 规格书6.3节]` |
| chain_aid_total_max | int | 是 | 30 | 0~100 | 伙伴援助次数满分 `[已对齐: 规格书6.3节]` |
| grade_s_threshold | int | 是 | 90 | 0~100 | S评级阈值 `[已对齐: 规格书6.3节]` |
| grade_a_threshold | int | 是 | 75 | 0~100 | A评级阈值 `[已对齐: 规格书6.3节]` |
| grade_b_threshold | int | 是 | 60 | 0~100 | B评级阈值 `[已对齐: 规格书6.3节]` |
| grade_c_threshold | int | 是 | 40 | 0~100 | C评级阈值 `[已对齐: 规格书6.3节]` |


---

## 二、局内运行时数据表（Runtime）

> 设计原则：运行时表在**每次开始新养成循环时创建**，循环结束后归档到fighter_archive或废弃。仅保存在内存/临时存储中，不长期持久化。

---

### 13. runtime_run — 单次养成运行

**用途**：记录一次完整的30回合养成循环的全局状态，是局内数据的顶层聚合表。`[已对齐: 规格书3.2节/4.2节]`

**Phase 1占位数据量**：游戏进行中有1条（每局1条，存档时归档）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| run_id | String | 是 | UUID | 唯一字符串 | 单次运行唯一标识（UUID） |
| run_status | int | 是 | 1 | 1~4 | 运行状态：1=ONGOING, 2=WIN, 3=LOSE, 4=ABANDON `[已对齐: 规格书4.2节]` |
| player_account_id | String | 是 | "" | player_account.id | 所属玩家账号（外键） |
| hero_config_id | int | 是 | 0 | hero_config.id | 选择的主角配置ID |
| current_turn | int | 是 | 1 | 1~30 | 当前回合数 `[已对齐: 规格书4.2节]` |
| max_turn | int | 是 | 30 | 30 | Phase 1固定30回合 `[已对齐: 规格书1.2节]` |
| current_node_type | int | 是 | 0 | 0~7 | 当前节点类型（0=未开始），1~7见NodeType枚举 `[已对齐: 规格书4.2节]` |
| node_history | Array[Dictionary] | 是 | [] | JSON数组 | 历史节点记录 `[已对齐: 规格书4.2节]` |
| total_score | int | 是 | 0 | 0~999999 | 当前累计评分（终局时写入） `[已对齐: 规格书6.3节]` |
| gold_owned | int | 是 | 0 | 0~999999 | 当前持有局内金币 `[已对齐: 规格书术语表]` |
| formula_config_id | int | 是 | 1 | battle_formula_config.id | 引用的战斗公式配置ID |
| seed | int | 是 | 0 | 0~999999999 | 随机数种子（用于复盘） `[待确认: 规格书未明确]` |
| started_at | int | 是 | 0 | Unix时间戳 | 开始时间 |
| ended_at | int | 否 | 0 | Unix时间戳 | 结束时间（运行中时=0） |
| final_enemy_cleared | bool | 是 | false | true/false | 是否已击败终局敌人 `[已对齐: 规格书4.2节]` |
| pvp_10th_result | int | 否 | 0 | 0~2 | 第10回PVP结果：0=未触发, 1=胜, 2=负 `[已对齐: 规格书5.3节]` |
| pvp_20th_result | int | 否 | 0 | 0~2 | 第20回PVP结果：0=未触发, 1=胜, 2=负 `[已对齐: 规格书5.3节]` |
| pvp_fail_penalty_active | bool | 是 | false | true/false | PVP失败惩罚是否生效 `[已对齐: 规格书5.3节]` |
| battle_win_count | int | 是 | 0 | 0~30 | 普通/精英战斗胜利次数 `[已对齐: 规格书6.3节]` |
| battle_lose_count | int | 是 | 0 | 0~30 | 战斗失败次数 |
| elite_win_count | int | 是 | 0 | 0~30 | 精英战胜利次数 `[已对齐: 规格书6.3节]` |
| elite_total_count | int | 是 | 0 | 0~30 | 精英战总次数 `[已对齐: 规格书6.3节]` |
| shop_visit_count | int | 是 | 0 | 0~30 | 商店访问次数 |
| rescue_success_count | int | 是 | 0 | 0~30 | 救援成功次数 |
| gold_spent | int | 是 | 0 | 0~999999 | 累计花费金币（评分用） `[已对齐: 规格书6.3节]` |
| gold_earned_total | int | 是 | 0 | 0~999999 | 累计获得金币（评分用） `[已对齐: 规格书6.3节]` |
| max_chain_reached | int | 是 | 0 | 0~4 | 本局最高CHAIN数（上限4） `[已对齐: 规格书4.4节/6.3节]` |
| total_chain_count | int | 是 | 0 | 0~999 | 本局总连锁次数 `[已对齐: 规格书6.3节]` |
| total_aid_trigger_count | int | 是 | 0 | 0~999 | 本局伙伴援助总触发次数 `[已对齐: 规格书6.3节]` |
| total_damage_dealt | int | 是 | 0 | 0~9999999 | 本局累计造成伤害 `[已对齐: 规格书6.3节]` |
| total_enemies_killed | int | 是 | 0 | 0~999 | 本局击杀敌人数 `[已对齐: 规格书6.3节]` |
| training_count_per_attr | Array[int] | 是 | [0,0,0,0,0] | 5元素数组 | 各属性锻炼次数[体魄,力量,敏捷,技巧,精神] `[已对齐: 规格书4.5节/6.3节]` |
| initial_attr_sum | int | 是 | 0 | 0~9999 | 初始五维总和（评分用） `[已对齐: 规格书6.3节]` |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `hero_config`（选择的角色）
- N:1 → `player_account`（所属玩家）
- N:1 → `battle_formula_config`（引用的公式参数）
- 1:1 → `runtime_hero`（该运行对应的主角运行时状态）
- 1:N → `runtime_partner`（该运行招募的伙伴列表，max=6）
- 1:1 → `runtime_mastery`（该运行的5属性熟练度状态）
- 1:N → `runtime_buff`（当前生效的Buff列表）
- 1:N → `runtime_training_log`（锻炼日志）
- 1:1 → `runtime_final_battle`（终局战数据）

---

### 14. runtime_hero — 主角运行时状态

**用途**：记录局内主角的实时属性、HP、技能状态等可变状态。`[已对齐: 规格书3.2节/4.7节]`

> 规格书4.7节明确："主角之间仅初始值不同，属性成长完全由锻炼次数和伙伴支援决定"。因此主角无独立等级/XP系统，属性值直接由 base + 锻炼加成 + 伙伴支援 + 熟练度加成 计算得出。

**Phase 1占位数据量**：游戏进行中有1条（每局1条）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 运行时记录唯一ID |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| hero_config_id | int | 是 | 0 | hero_config.id | 主角配置ID（外键） |
| max_hp | int | 是 | 0 | 1~99999 | 当前最大HP（由体魄×公式计算） `[已对齐: 规格书4.3节]` |
| current_hp | int | 是 | 0 | 0~99999 | 当前HP |
| current_vit | int | 是 | 0 | 1~9999 | 当前体魄（含养成加成） `[已对齐: 规格书3.3节]` |
| current_str | int | 是 | 0 | 1~9999 | 当前力量（含养成加成） `[已对齐: 规格书3.3节]` |
| current_agi | int | 是 | 0 | 1~9999 | 当前敏捷（含养成加成） `[已对齐: 规格书3.3节]` |
| current_tec | int | 是 | 0 | 1~9999 | 当前技巧（含养成加成） `[已对齐: 规格书3.3节]` |
| current_mnd | int | 是 | 0 | 1~9999 | 当前精神（含养成加成） `[已对齐: 规格书3.3节]` |
| passive_skill_id | int | 是 | 0 | skill_config.id | 常规技能ID `[已对齐: 规格书4.7节]` |
| ultimate_skill_id | int | 是 | 0 | skill_config.id | 必杀技ID `[已对齐: 规格书4.7节]` |
| ultimate_used | bool | 是 | false | true/false | 必杀技是否已使用（整场限1次） `[已对齐: 规格书4.7节]` |
| buff_list | Array[Dictionary] | 否 | [] | JSON数组 | 当前生效Buff列表 |
| total_training_count | int | 是 | 0 | 0~30 | 本局锻炼次数 |
| total_damage_dealt | int | 是 | 0 | 0~9999999 | 本局累计造成伤害 |
| total_damage_taken | int | 是 | 0 | 0~9999999 | 本局累计承受伤害 |
| total_enemies_killed | int | 是 | 0 | 0~999 | 本局击杀敌人数 |
| is_alive | bool | 是 | true | true/false | 是否存活（HP=0时false，精英战败北本局结束） `[已对齐: 规格书4.2节/5.2节]` |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

**关系**：`[已对齐: 规格书3.2节]`
- 1:1 → `runtime_run`（通过run_id关联）
- N:1 → `hero_config`（通过hero_config_id关联）

> **注意**：原设计的 `current_level`/`current_xp`/`equipment_list` 字段已删除。`[已对齐: 规格书4.7节]` 主角无等级系统，Phase 1无装备系统。

---

### 15. runtime_partner — 伙伴运行时状态

**用途**：记录局内已招募伙伴的实时状态。`[已对齐: 规格书3.2节/4.4节]`

> 规格书4.4节队伍结构：1主角 + 2同行伙伴（酒馆选）+ 3救援伙伴（第5/15/25回）。Phase 1最多6名伙伴。

**Phase 1占位数据量**：游戏进行中0~6条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 运行时记录唯一ID |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| partner_config_id | int | 是 | 0 | partner_config.id | 伙伴配置ID（外键） |
| position | int | 是 | 1 | 1~4 | 伙伴站位：1=同行, 2=第1次救援, 3=第2次救援, 4=第3次救援 `[已对齐: 规格书4.4节]` |
| recruit_turn | int | 是 | 0 | 0~30 | 招募回合数（0=初始同行伙伴） `[已对齐: 规格书4.2节]` |
| current_level | int | 是 | 1 | 1~3 | 当前等级（Phase 1上限Lv3） `[已对齐: 规格书1.3节决策6]` |
| current_hp | int | 是 | 0 | 0~99999 | 当前HP（伙伴不参与战斗，HP仅作展示） `[已对齐: 规格书4.4节]` |
| current_vit | int | 是 | 0 | 1~9999 | 当前体魄（含支援加成） `[已对齐: 规格书3.3节]` |
| current_str | int | 是 | 0 | 1~9999 | 当前力量（含支援加成） `[已对齐: 规格书3.3节]` |
| current_agi | int | 是 | 0 | 1~9999 | 当前敏捷（含支援加成） `[已对齐: 规格书3.3节]` |
| current_tec | int | 是 | 0 | 1~9999 | 当前技巧（含支援加成） `[已对齐: 规格书3.3节]` |
| current_mnd | int | 是 | 0 | 1~9999 | 当前精神（含支援加成） `[已对齐: 规格书3.3节]` |
| aid_trigger_count | int | 是 | 0 | 0~999 | 本局援助触发次数 `[已对齐: 规格书4.4节]` |
| chain_trigger_count | int | 是 | 0 | 0~999 | 本局连锁触发次数 `[已对齐: 规格书4.4节]` |
| buff_list | Array[Dictionary] | 否 | [] | JSON数组 | 当前生效Buff列表 |
| is_active | bool | 是 | true | true/false | 是否激活（退场后false） |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `runtime_run`（通过run_id关联）
- N:1 → `partner_config`（通过partner_config_id关联）

> `[已对齐: 规格书4.4节]` 伙伴援助触发规则：最大链长4段，每伙伴单场最多触发2次。

---

### 16. runtime_mastery — 属性熟练度运行时状态

**用途**：记录五属性在当前养成循环中的熟练度阶段与锻炼次数。`[已对齐: 规格书3.2节/4.5节]`

> **存储模式确定**：规格书3.2节明确 RuntimeRun(1) ──< RuntimeMastery(5)，即5条独立记录。`[已对齐: 规格书3.2节]`

**Phase 1占位数据量**：游戏进行中5条（5属性各1条）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 运行时记录唯一ID |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| attr_type | int | 是 | 1 | 1~5 | 属性类型（五属性编码） `[已对齐: 规格书3.3节]` |
| stage | int | 是 | 1 | 1~4 | 当前阶段：1=生疏, 2=熟悉, 3=精通, 4=专精 `[已对齐: 规格书4.5节]` |
| training_count | int | 是 | 0 | 0~30 | 本局该属性锻炼次数 `[已对齐: 规格书4.5节]` |
| training_bonus | int | 是 | 0 | 0~999 | 当前阶段锻炼收益加成（缓存值） `[已对齐: 规格书4.5节]` |
| is_marginal_decrease | bool | 是 | false | true/false | 该属性是否触发边际递减 `[已对齐: 规格书4.5节]` |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `runtime_run`（通过run_id关联）
- N:1 → `attribute_mastery_config`（通过attr_type + stage匹配配置）

**阶段判断逻辑** `[已对齐: 规格书4.5节]`：
- 生疏(stage=1)：training_count = 0，bonus = +0
- 熟悉(stage=2)：training_count = 1~3，bonus = +2
- 精通(stage=3)：training_count = 4~6，bonus = +4
- 专精(stage=4)：training_count ≥ 7，bonus = +5

> **边际递减判断** `[已对齐: 规格书4.5节]`：当 training_count_for_attr / total_training_count > 0.6 时，is_marginal_decrease=true，该属性后续锻炼收益 × (1 - 0.2)。

---

### 17. runtime_buff — 临时Buff/Debuff

**用途**：记录局内主角/伙伴的临时Buff和Debuff状态。`[新增: 规格书5.2节奖励Buff/战斗效果需要存储]`

**Phase 1占位数据量**：游戏进行中0~N条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | Buff记录唯一ID |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| target_type | int | 是 | 1 | 1~2 | 作用目标：1=主角, 2=伙伴 |
| target_id | String | 否 | "" | runtime_partner.id | 目标伙伴ID（target_type=2时） |
| buff_name | String | 是 | "" | 长度<=32 | Buff名称（如"攻击提升"） |
| buff_effect | int | 是 | 1 | 1~5 | 效果类型：1=攻击加成%, 2=防御加成%, 3=速度加成%, 4=HP回复, 5=特殊 |
| effect_value | float | 是 | 0.0 | -999.0~999.0 | 效果数值（如0.1=+10%攻击） |
| duration_total | int | 是 | 0 | 0~99 | 总持续回合数（0=永久） |
| duration_remaining | int | 是 | 0 | 0~99 | 剩余回合数 |
| source | String | 否 | "" | 自由文本 | Buff来源（如"精英战奖励""商店购买"） |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

---

### 18. runtime_training_log — 锻炼记录日志

**用途**：记录每回合锻炼的详细日志，用于复盘和评分计算。`[新增: 规格书4.5节/6.3节养成效率分计算需要]`

**Phase 1占位数据量**：游戏进行中0~30条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 日志记录唯一ID |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| turn | int | 是 | 1 | 1~30 | 锻炼回合数 |
| attr_type | int | 是 | 1 | 1~5 | 锻炼属性（五属性编码） `[已对齐: 规格书3.3节]` |
| base_gain | int | 是 | 0 | 0~999 | 基础属性增长 |
| mastery_bonus | int | 是 | 0 | 0~999 | 熟练度加成值 |
| partner_bonus | int | 是 | 0 | 0~999 | 伙伴支援加成值 |
| marginal_decrease_applied | bool | 是 | false | true/false | 是否触发边际递减 `[已对齐: 规格书4.5节]` |
| final_gain | int | 是 | 0 | 0~999 | 最终属性增长（含所有加成/递减） |
| partner_support_list | Array[int] | 否 | [] | partner_config.id | 提供支援的伙伴ID列表 `[已对齐: 规格书4.8节]` |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |

---

### 19. runtime_final_battle — 终局战数据

**用途**：记录第30回终局战的详细数据，用于评分和复盘。`[新增: 规格书4.2节/6.3节]`

**Phase 1占位数据量**：游戏进行中0~1条（终局时创建）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 终局战记录唯一ID |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| enemy_config_id | int | 是 | 0 | enemy_config.id | 终局敌人模板ID |
| result | int | 是 | 0 | 0~2 | 战斗结果：0=未开始, 1=胜利, 2=失败 `[已对齐: 规格书4.2节]` |
| total_rounds | int | 是 | 0 | 0~20 | 实际进行回合数（上限20） `[已对齐: 规格书4.3节]` |
| hero_max_hp | int | 是 | 0 | 0~99999 | 终局战开始时主角最大HP `[已对齐: 规格书6.3节]` |
| hero_remaining_hp | int | 是 | 0 | 0~99999 | 终局战后主角剩余HP `[已对齐: 规格书6.3节]` |
| damage_dealt_to_enemy | int | 是 | 0 | 0~999999 | 对终局敌人造成的总伤害 `[已对齐: 规格书6.3节]` |
| enemy_max_hp | int | 是 | 0 | 0~999999 | 终局敌人最大HP `[已对齐: 规格书6.3节]` |
| max_chain_in_battle | int | 是 | 0 | 0~4 | 本场最高CHAIN数 `[已对齐: 规格书4.4节/6.3节]` |
| ultimate_triggered | bool | 是 | false | true/false | 必杀技是否触发 `[已对齐: 规格书4.7节]` |
| battle_log_summary | String | 否 | "" | 文本 | 战斗日志摘要（复盘用） |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |


---

## 三、局外存档数据表（Archive）

> 设计原则：存档表在**养成循环结束后持久化**，用于斗士档案展示、PVP对手池、跨局进度保持。

---

### 20. player_account — 玩家账号

**用途**：存储玩家全局账号信息、设置、解锁内容。Phase 1采用极简本地存档。`[已对齐: 规格书3.2节/6.1节]`

**Phase 1占位数据量**：1条（单机本地1个账号）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| account_id | String | 是 | UUID | 唯一字符串 | 账号唯一标识（本地生成UUID） |
| nickname | String | 是 | "Player" | 长度<=16 | 玩家昵称 |
| created_at | int | 是 | 0 | Unix时间戳 | 账号创建时间 |
| last_login_at | int | 是 | 0 | Unix时间戳 | 最后登录时间 |
| total_play_time_sec | int | 是 | 0 | 0~999999999 | 累计游戏时长（秒） |
| total_runs_completed | int | 是 | 0 | 0~999999 | 累计完成养成循环次数 `[已对齐: 规格书6.3节]` |
| total_runs_win | int | 是 | 0 | 0~999999 | 累计胜利次数 |
| total_runs_lose | int | 是 | 0 | 0~999999 | 累计失败次数 |
| highest_score | int | 是 | 0 | 0~999999 | 历史最高评分 `[已对齐: 规格书6.3节]` |
| highest_grade | String | 否 | "" | 长度<=1 | 历史最高评级（S/A/B/C/D） `[已对齐: 规格书6.3节]` |
| unlocked_hero_id_list | Array[int] | 是 | [1] | hero_config.id | 已解锁主角ID列表 `[已对齐: 规格书6.1节]` |
| unlocked_partner_id_list | Array[int] | 是 | [1001,1002,1003,1004,1005,1006] | partner_config.id | 已解锁伙伴ID列表 `[已对齐: 规格书6.1节]` |
| outgame_gold | int | 是 | 0 | 0~9999999 | 局外金币 `[已对齐: 规格书6.1节]` |
| is_tutorial_completed | bool | 是 | false | true/false | 新手引导是否完成 `[修正:L1: Phase 1不包含设置系统，已删除settings_*字段]` |
| client_version | String | 是 | "1.0.0" | 版本号 | 创建账号时的客户端版本 `[已对齐: 规格书4.6节固定化规则]` |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

**关系**：`[已对齐: 规格书3.2节]`
- 1:N → `fighter_archive_main`（该玩家历史斗士档案列表）

**解锁进度初始值** `[已对齐: 规格书6.1节]`：
- 主角：初始仅勇者(id=1)解锁，影舞者需勇者通关1次，铁卫需影舞者通关1次
- 伙伴：初始6名默认解锁（id=1001~1006）

---

### 21. fighter_archive_main — 斗士档案主表

**用途**：记录每次养成循环的终局结果与主角关键数据快照，用于历史回顾和PVP对手池。`[已对齐: 规格书3.2节/4.6节]`

**Phase 1占位数据量**：N条（随游玩次数增长，本地保留最近50条 `[待确认: 规格书未明确保留条数]`）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| archive_id | String | 是 | UUID | 唯一字符串 | 档案唯一标识 |
| account_id | String | 是 | "" | player_account.account_id | 所属账号（外键） |
| run_id | String | 是 | "" | runtime_run.run_id | 关联的运行ID（归档源） |
| hero_config_id | int | 是 | 0 | hero_config.id | 使用的主角ID |
| hero_name | String | 是 | "" | 长度<=16 | 主角名称（快照，防配置变更） `[已对齐: 规格书4.6节]` |
| run_status | int | 是 | 1 | 1~4 | 终局状态：2=WIN, 3=LOSE, 4=ABANDON `[已对齐: 规格书4.6节]` |
| final_turn | int | 是 | 30 | 1~30 | 结束时的回合数（中途失败<30） `[已对齐: 规格书4.6节]` |
| final_score | int | 是 | 0 | 0~999999 | 终局评分 `[已对齐: 规格书6.3节]` |
| final_grade | String | 是 | "" | 长度<=1 | 终局评级（S/A/B/C/D） `[已对齐: 规格书6.3节]` |
| partner_count | int | 是 | 0 | 0~6 | 本局招募伙伴数量 `[已对齐: 规格书4.6节]` |
| max_hp_reached | int | 是 | 0 | 1~99999 | 本局达到的最高HP `[已对齐: 规格书4.6节]` |
| attr_snapshot_vit | int | 是 | 0 | 1~9999 | 终局体魄快照 `[已对齐: 规格书4.6节]` |
| attr_snapshot_str | int | 是 | 0 | 1~9999 | 终局力量快照 `[已对齐: 规格书4.6节]` |
| attr_snapshot_agi | int | 是 | 0 | 1~9999 | 终局敏捷快照 `[已对齐: 规格书4.6节]` |
| attr_snapshot_tec | int | 是 | 0 | 1~9999 | 终局技巧快照 `[已对齐: 规格书4.6节]` |
| attr_snapshot_mnd | int | 是 | 0 | 1~9999 | 终局精神快照 `[已对齐: 规格书4.6节]` |
| initial_vit | int | 是 | 0 | 1~9999 | 初始体魄（评分用） `[已对齐: 规格书6.3节]` |
| initial_str | int | 是 | 0 | 1~9999 | 初始力量（评分用） `[已对齐: 规格书6.3节]` |
| initial_agi | int | 是 | 0 | 1~9999 | 初始敏捷（评分用） `[已对齐: 规格书6.3节]` |
| initial_tec | int | 是 | 0 | 1~9999 | 初始技巧（评分用） `[已对齐: 规格书6.3节]` |
| initial_mnd | int | 是 | 0 | 1~9999 | 初始精神（评分用） `[已对齐: 规格书6.3节]` |
| battle_win_count | int | 是 | 0 | 0~30 | 战斗胜利次数 `[已对齐: 规格书6.3节]` |
| elite_win_count | int | 是 | 0 | 0~30 | 精英战胜利次数 `[已对齐: 规格书6.3节]` |
| elite_total_count | int | 是 | 0 | 0~30 | 精英战总次数 `[已对齐: 规格书6.3节]` |
| pvp_10th_result | int | 否 | 0 | 0~2 | 第10回PVP结果 `[已对齐: 规格书5.3节]` |
| pvp_20th_result | int | 否 | 0 | 0~2 | 第20回PVP结果 `[已对齐: 规格书5.3节]` |
| training_count | int | 是 | 0 | 0~30 | 锻炼次数 `[已对齐: 规格书6.3节]` |
| shop_visit_count | int | 是 | 0 | 0~30 | 商店访问次数 |
| rescue_success_count | int | 是 | 0 | 0~30 | 救援成功次数 |
| total_damage_dealt | int | 是 | 0 | 0~9999999 | 累计造成伤害 `[已对齐: 规格书6.3节]` |
| total_enemies_killed | int | 是 | 0 | 0~999 | 击杀敌人数 `[已对齐: 规格书6.3节]` |
| max_chain_reached | int | 是 | 0 | 0~4 | 最高CHAIN数 `[已对齐: 规格书6.3节]` |
| total_chain_count | int | 是 | 0 | 0~999 | 总连锁次数 `[已对齐: 规格书6.3节]` |
| total_aid_trigger_count | int | 是 | 0 | 0~999 | 伙伴援助总触发次数 `[已对齐: 规格书6.3节]` |
| passive_skill_trigger_count | int | 是 | 0 | 0~999 | 常规技能总触发次数 `[已对齐: 规格书6.3节]` |
| ultimate_triggered | bool | 是 | false | true/false | 必杀技是否触发过 `[已对齐: 规格书4.7节]` |
| gold_spent | int | 是 | 0 | 0~999999 | 累计花费金币 `[已对齐: 规格书6.3节]` |
| gold_earned_total | int | 是 | 0 | 0~999999 | 累计获得金币 `[已对齐: 规格书6.3节]` |
| is_pvp_eligible | bool | 是 | true | true/false | 是否可作为PVP对手（完整完成一局=true） `[已对齐: 规格书4.6节]` |
| is_fixed | bool | 是 | true | true/false | 是否已固定化（不受后续版本更新影响） `[已对齐: 规格书4.6节]` |
| client_version | String | 是 | "1.0.0" | 版本号 | 客户端版本（向后兼容用） `[已对齐: 规格书4.6节]` |
| started_at | int | 是 | 0 | Unix时间戳 | 开始时间 |
| ended_at | int | 是 | 0 | Unix时间戳 | 结束时间 |
| updated_at | int | 是 | 0 | Unix时间戳 | 最后更新时间 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `player_account`（通过account_id关联）
- 1:N → `fighter_archive_partner`（档案中的伙伴快照）
- 1:1 → `fighter_archive_score`（档案评分明细）

> **固定化规则** `[已对齐: 规格书4.6节]`：终局斗士生成后立即固定化，is_fixed=true，锁定所有属性值，保留版本号用于向后兼容。

---

### 22. fighter_archive_partner — 档案伙伴快照

**用途**：记录终局时5名伙伴的快照数据。`[新增: 规格书3.2节/4.6节保存内容包含伙伴数据]`

**Phase 1占位数据量**：每份档案0~5条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 快照记录唯一ID |
| archive_id | String | 是 | "" | fighter_archive_main.archive_id | 所属档案（外键） |
| partner_config_id | int | 是 | 0 | partner_config.id | 伙伴配置ID |
| partner_name | String | 是 | "" | 长度<=16 | 伙伴名称（快照） `[已对齐: 规格书4.6节]` |
| position | int | 是 | 1 | 1~4 | 伙伴站位 `[已对齐: 规格书4.4节]` |
| final_level | int | 是 | 1 | 1~3 | 终局等级 `[已对齐: 规格书1.3节决策6]` |
| final_vit | int | 是 | 0 | 1~9999 | 终局体魄 `[已对齐: 规格书3.3节]` |
| final_str | int | 是 | 0 | 1~9999 | 终局力量 `[已对齐: 规格书3.3节]` |
| final_agi | int | 是 | 0 | 1~9999 | 终局敏捷 `[已对齐: 规格书3.3节]` |
| final_tec | int | 是 | 0 | 1~9999 | 终局技巧 `[已对齐: 规格书3.3节]` |
| final_mnd | int | 是 | 0 | 1~9999 | 终局精神 `[已对齐: 规格书3.3节]` |
| aid_trigger_count | int | 是 | 0 | 0~999 | 本局援助触发次数 `[已对齐: 规格书6.3节]` |
| chain_trigger_count | int | 是 | 0 | 0~999 | 本局连锁触发次数 `[已对齐: 规格书6.3节]` |
| sort_order | int | 是 | 0 | 0~999 | 排序优先级 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `fighter_archive_main`（通过archive_id关联）

---

### 23. fighter_archive_score — 档案评分明细

**用途**：记录终局评分的各项明细，用于回顾和PVP匹配。`[新增: 规格书6.3节/6.4节评分系统]`

**Phase 1占位数据量**：每份档案1条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| id | String | 是 | UUID | 唯一字符串 | 评分明细唯一ID |
| archive_id | String | 是 | "" | fighter_archive_main.archive_id | 所属档案（外键） |
| final_performance_raw | float | 是 | 0.0 | 0.0~100.0 | 终局战表现分（原始） `[已对齐: 规格书6.3节]` |
| final_performance_weighted | float | 是 | 0.0 | 0.0~100.0 | 终局战表现分（加权后，×0.4） `[已对齐: 规格书6.3节]` |
| training_efficiency_raw | float | 是 | 0.0 | 0.0~100.0 | 养成效率分（原始） `[已对齐: 规格书6.3节]` |
| training_efficiency_weighted | float | 是 | 0.0 | 0.0~100.0 | 养成效率分（加权后，×0.2） `[已对齐: 规格书6.3节]` |
| pvp_performance_raw | float | 是 | 0.0 | 0.0~100.0 | PVP表现分（原始） `[已对齐: 规格书6.3节]` |
| pvp_performance_weighted | float | 是 | 0.0 | 0.0~100.0 | PVP表现分（加权后，×0.2） `[已对齐: 规格书6.3节]` |
| build_purity_raw | float | 是 | 0.0 | 0.0~100.0 | 流派纯度分（原始） `[已对齐: 规格书6.3节]` |
| build_purity_weighted | float | 是 | 0.0 | 0.0~100.0 | 流派纯度分（加权后，×0.1） `[已对齐: 规格书6.3节]` |
| chain_showcase_raw | float | 是 | 0.0 | 0.0~100.0 | 连锁展示分（原始） `[已对齐: 规格书6.3节]` |
| chain_showcase_weighted | float | 是 | 0.0 | 0.0~100.0 | 连锁展示分（加权后，×0.1） `[已对齐: 规格书6.3节]` |
| total_score | float | 是 | 0.0 | 0.0~100.0 | 总分（加权求和） `[已对齐: 规格书6.3节]` |
| grade | String | 是 | "" | 长度<=1 | 评级（S/A/B/C/D） `[已对齐: 规格书6.3节]` |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |

**关系**：`[已对齐: 规格书3.2节]`
- 1:1 → `fighter_archive_main`（通过archive_id关联）


---

## 四、战斗数据表（Battle）

> 设计原则：战斗数据表在**每次战斗发生时创建**，战斗结束后归档。Phase 1普通战斗简化快进不存明细，仅精英战/PVP/终局战存储详细战斗数据。`[已对齐: 规格书4.3节/3.2节]`

---

### 24. battle_main — 战斗主表

**用途**：记录一场战斗的顶层信息（敌人、类型、结果等）。`[新增: 规格书3.2节定义战斗数据8张表，Phase 1取核心4张]`

**Phase 1占位数据量**：每局0~N条（普通战斗不存储，仅精英/PVP/终局战存储）

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| battle_id | String | 是 | UUID | 唯一字符串 | 战斗唯一标识 |
| run_id | String | 是 | "" | runtime_run.run_id | 所属运行（外键） |
| battle_type | int | 是 | 1 | 1~4 | 战斗类型：1=NORMAL, 2=ELITE, 3=PVP, 4=FINAL `[已对齐: 规格书4.3节]` |
| node_turn | int | 是 | 0 | 1~30 | 发生在第几回合的节点 |
| enemy_config_id | int | 否 | 0 | enemy_config.id | 敌人模板ID（PVP时=0） |
| enemy_name | String | 否 | "" | 长度<=32 | 敌人名称（快照） |
| battle_result | int | 是 | 0 | 0~3 | 结果：0=进行中, 1=WIN, 2=LOSE, 3=DRAW `[已对齐: 规格书4.3节]` |
| total_rounds | int | 是 | 0 | 0~20 | 实际进行回合数（上限20） `[已对齐: 规格书4.3节]` |
| hero_start_hp | int | 是 | 0 | 0~99999 | 战斗开始时主角HP |
| hero_end_hp | int | 是 | 0 | 0~99999 | 战斗结束时主角HP |
| hero_max_hp | int | 是 | 0 | 0~99999 | 战斗时主角最大HP |
| damage_dealt | int | 是 | 0 | 0~999999 | 主角方造成总伤害 `[已对齐: 规格书6.3节]` |
| damage_taken | int | 是 | 0 | 0~999999 | 主角方承受总伤害 |
| ultimate_triggered | bool | 是 | false | true/false | 必杀技是否触发 `[已对齐: 规格书4.7节]` |
| max_chain_reached | int | 是 | 0 | 0~4 | 本场最高CHAIN数 `[已对齐: 规格书4.4节]` |
| chain_trigger_count | int | 是 | 0 | 0~999 | 本场连锁触发次数 `[已对齐: 规格书4.4节]` |
| aid_trigger_count | int | 是 | 0 | 0~999 | 本场伙伴援助触发次数 `[已对齐: 规格书4.4节]` |
| reward_gold | int | 否 | 0 | 0~999999 | 战斗奖励金币 `[已对齐: 规格书5.1节/5.2节]` |
| reward_buff_desc | String | 否 | "" | 文本 | 精英战3选1奖励描述 `[已对齐: 规格书5.2节]` |
| started_at | int | 是 | 0 | Unix时间戳 | 战斗开始时间 |
| ended_at | int | 否 | 0 | Unix时间戳 | 战斗结束时间 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `runtime_run`（通过run_id关联）
- 1:N → `battle_round`（该战斗的回合记录，max=20）
- 1:N → `battle_action`（该战斗的行动记录）
- 1:1 → `battle_final_result`（该战斗的最终结果）

---

### 25. battle_round — 战斗回合记录

**用途**：记录战斗中每回合的概览数据（双方状态、关键事件）。`[新增: 规格书4.3节定义每回合流程]`

**Phase 1占位数据量**：每场战斗0~20条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| round_id | String | 是 | UUID | 唯一字符串 | 回合记录唯一ID |
| battle_id | String | 是 | "" | battle_main.battle_id | 所属战斗（外键） |
| round_number | int | 是 | 1 | 1~20 | 回合序号 `[已对齐: 规格书4.3节]` |
| hero_hp_start | int | 是 | 0 | 0~99999 | 回合开始时主角HP |
| enemy_hp_start | int | 是 | 0 | 0~99999 | 回合开始时敌人HP |
| hero_hp_end | int | 是 | 0 | 0~99999 | 回合结束时主角HP |
| enemy_hp_end | int | 是 | 0 | 0~99999 | 回合结束时敌人HP |
| hero_action | String | 否 | "" | 文本 | 主角行动描述（如"普攻：造成45伤害"） |
| enemy_action | String | 否 | "" | 文本 | 敌人行动描述 |
| chain_triggered | bool | 是 | false | true/false | 本回合是否触发连锁 `[已对齐: 规格书4.4节]` |
| chain_count | int | 否 | 0 | 0~4 | 本回合连锁段数 `[已对齐: 规格书4.4节]` |
| aid_triggered | bool | 是 | false | true/false | 本回合是否有伙伴援助 `[已对齐: 规格书4.4节]` |
| ultimate_triggered | bool | 是 | false | true/false | 本回合是否触发必杀技 `[已对齐: 规格书4.7节]` |
| buff_changes | String | 否 | "" | 文本 | Buff变化摘要（如"攻击+10%[3回合]"） |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `battle_main`（通过battle_id关联）

---

### 26. battle_action — 战斗行动记录

**用途**：记录战斗中每次行动的详细数据（攻击、技能、伤害等）。`[新增: 规格书4.3节定义战斗流程]`

**Phase 1占位数据量**：每场战斗0~N条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| action_id | String | 是 | UUID | 唯一字符串 | 行动记录唯一ID |
| battle_id | String | 是 | "" | battle_main.battle_id | 所属战斗（外键） |
| round_number | int | 是 | 1 | 1~20 | 所在回合序号 |
| actor_type | int | 是 | 1 | 1~3 | 行动者：1=主角, 2=伙伴, 3=敌人 |
| partner_id | String | 否 | "" | runtime_partner.id | 伙伴ID（actor_type=2时） |
| action_type | int | 是 | 1 | 1~5 | 行动类型：1=普攻, 2=技能, 3=必杀技, 4=援助, 5=连锁 `[已对齐: 规格书4.3节]` |
| skill_id | int | 否 | 0 | skill_config.id | 使用的技能ID（action_type=2/3/4时） |
| target_type | int | 是 | 1 | 1~2 | 目标：1=敌人, 2=主角 |
| damage_value | int | 否 | 0 | 0~999999 | 造成伤害值（0=未造成伤害） |
| is_crit | bool | 是 | false | true/false | 是否暴击 |
| is_evade | bool | 是 | false | true/false | 是否被闪避 |
| buff_applied | String | 否 | "" | 文本 | 施加的Buff效果描述 |
| chain_sequence | int | 否 | 0 | 0~4 | 连锁序列号（0=非连锁） `[已对齐: 规格书4.4节]` |
| action_order | int | 是 | 1 | 1~99 | 行动顺序（本回合内） `[已对齐: 规格书4.3节]` |
| created_at | int | 是 | 0 | Unix时间戳 | 记录创建时间 |

**关系**：`[已对齐: 规格书3.2节]`
- N:1 → `battle_main`（通过battle_id关联）

---

### 27. battle_final_result — 战斗最终结果

**用途**：记录战斗结束后的统计和复盘数据。`[新增: 规格书4.3节播放模式分级]`

**Phase 1占位数据量**：每场战斗1条

| 字段名 | 数据类型 | 必填 | 默认值 | 取值范围/枚举值 | 说明 |
|:---|:---|:---:|:---|:---|:---|
| result_id | String | 是 | UUID | 唯一字符串 | 结果记录唯一ID |
| battle_id | String | 是 | "" | battle_main.battle_id | 所属战斗（外键） |
| hero_total_damage | int | 是 | 0 | 0~999999 | 主角方造成总伤害 `[已对齐: 规格书6.3节]` |
| hero_max_single_hit | int | 是 | 0 | 0~999999 | 主角方单次最高伤害 |
| enemy_total_damage | int | 是 | 0 | 0~999999 | 敌人造成总伤害 |
| total_healing | int | 是 | 0 | 0~999999 | 总治疗量 |
| skill_trigger_count | int | 是 | 0 | 0~99 | 常规技能触发次数 `[已对齐: 规格书6.3节]` |
| ultimate_trigger_count | int | 是 | 0 | 0~1 | 必杀技触发次数（上限1） `[已对齐: 规格书4.7节]` |
| aid_trigger_count | int | 是 | 0 | 0~999 | 伙伴援助总触发次数 `[已对齐: 规格书4.4节/6.3节]` |
| max_chain_length | int | 是 | 0 | 0~4 | 最大连锁长度 `[已对齐: 规格书4.4节]` |
| crit_count | int | 是 | 0 | 0~99 | 暴击次数 |
| evade_count | int | 是 | 0 | 0~99 | 闪避次数 |
| turn_count | int | 是 | 0 | 0~20 | 实际回合数 `[已对齐: 规格书4.3节]` |
| review_summary | String | 否 | "" | 文本 | 战斗复盘摘要（终局战展示用） `[已对齐: 规格书4.3节]` |

**关系**：`[已对齐: 规格书3.2节]`
- 1:1 → `battle_main`（通过battle_id关联）

---

## 五、全局关系图

### 5.1 表间关系总览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              静态配置层（Config）                              │
│                         Phase 1共12张表，只读，启动加载                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐            │
│   │ hero_config  │◄───┤ skill_config │───►│attribute_mastery_│            │
│   │   (3条)      │    │   (~20条)    │    │    config        │            │
│   └──────────────┘    └──────┬───────┘    │   (20条)         │            │
│                              │             └──────────────────┘            │
│   ┌──────────────┐           │                                             │
│   │partner_config│◄─────────┘    ┌──────────────────┐                     │
│   │   (6条)      │               │battle_formula_   │                     │
│   └──────┬───────┘               │    config        │                     │
│          │                        │   (1条)          │                     │
│          ▼                        └────────┬─────────┘                     │
│   ┌──────────────┐              ┌──────────┴──────────┐                   │
│   │partner_assist│              │                     │                   │
│   │   _config    │       ┌─────▼──────┐    ┌─────────▼────────┐          │
│   │   (6条)      │       │node_config │    │node_pool_config  │          │
│   └──────────────┘       │   (7条)    │    │   (7~10条)       │          │
│   ┌──────────────┐       └────────────┘    └──────────────────┘          │
│   │partner_      │                                                         │
│   │support_config│       ┌──────────────┐    ┌──────────────┐             │
│   │   (6条)      │       │ enemy_config │    │ shop_config  │             │
│   └──────────────┘       │   (5条)      │    │  (8条)       │             │
│                          └──────────────┘    └──────────────┘             │
│   ┌──────────────┐                                                         │
│   │scoring_config│                                                         │
│   │   (1条)      │                                                         │
│   └──────────────┘                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 引用配置
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        局内运行层（Runtime）                                  │
│                     Phase 1共7张表，每局创建，内存存储                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌─────────────────┐                                  │
│                        │   runtime_run   │◄──── 顶层记录（每局1条）          │
│                        │    (每局1条)     │                                  │
│                        └───────┬─────────┘                                  │
│                                │                                            │
│              ┌─────────────────┼─────────────────┐                         │
│              │                 │                 │                         │
│        1:1   ▼           1:N   ▼           1:1   ▼                         │
│      ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│      │ runtime_hero │  │runtime_      │  │runtime_      │                  │
│      │  (每局1条)   │  │  partner     │  │  mastery     │                  │
│      └──────────────┘  │ (0~6条/局)   │  │ (5条/局)     │                  │
│                        └──────────────┘  └──────────────┘                  │
│                                                                             │
│      ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│      │ runtime_buff │  │runtime_      │  │runtime_final │                  │
│      │  (0~N条/局)  │  │training_log  │  │   _battle    │                  │
│      └──────────────┘  │ (0~30条/局)  │  │ (0~1条/局)   │                  │
│                        └──────────────┘  └──────────────┘                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │ 终局归档
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        局外存档层（Archive）                                  │
│                      Phase 1共4张表，持久化存储                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────────────────────────────────────────────────────┐         │
│   │                    player_account                            │         │
│   │                     (1条/设备)                                │         │
│   └──────────────────────────┬───────────────────────────────────┘         │
│                              │ 1:N                                         │
│                              ▼                                              │
│                       ┌──────────────┐    ┌──────────────┐                  │
│                       │fighter_      │◄───┤fighter_      │                  │
│                       │archive_main  │    │archive_score │                  │
│                       │ (N条历史)    │    │ (1条/档案)   │                  │
│                       └──────┬───────┘    └──────────────┘                  │
│                              │                                             │
│                              │ 1:N                                         │
│                              ▼                                              │
│                       ┌──────────────┐                                      │
│                       │fighter_      │                                      │
│                       │archive_      │                                      │
│                       │  partner     │                                      │
│                       │ (0~5条/档案) │                                      │
│                       └──────────────┘                                      │
│                              ▲                                              │
│                              │ 作为PVP对手池数据                             │
└──────────────────────────────┼──────────────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────────────────┐
│                        战斗数据层（Battle）                                   │
│              Phase 1共4张表，仅精英/PVP/终局战存储                             │
├──────────────────────────────┼──────────────────────────────────────────────┤
│                              │                                             │
│                       ┌──────┴───────┐                                      │
│                       │  battle_main │                                      │
│                       │  (0~N条/局)  │                                      │
│                       └──────┬───────┘                                      │
│                              │                                             │
│              ┌───────────────┼───────────────┐                             │
│              │               │               │                             │
│              ▼               ▼               ▼                             │
│      ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                   │
│      │battle_round  │ │battle_action │ │battle_final  │                   │
│      │(0~20条/战斗) │ │ (0~N条/战斗) │ │  _result     │                   │
│      └──────────────┘ └──────────────┘ │ (1条/战斗)   │                   │
│                                        └──────────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 核心数据关系 `[已对齐: 规格书3.2节]`

| 关系类型 | 主表 | 从表 | 关联字段 | 基数 | 说明 |
|:---:|:---|:---|:---|:---:|:---|
| 1:N | player_account | fighter_archive_main | account_id | 1:N | 每个账号N份历史档案 |
| 1:1 | fighter_archive_main | fighter_archive_score | archive_id | 1:1 | 每份档案1条评分明细 |
| 1:N | fighter_archive_main | fighter_archive_partner | archive_id | 1:0~5 | 每份档案0~5条伙伴快照 |
| 1:1 | runtime_run | runtime_hero | run_id | 1:1 | 每局1个主角状态 |
| 1:N | runtime_run | runtime_partner | run_id | 1:0~6 | 每局0~6个伙伴状态 |
| 1:N | runtime_run | runtime_mastery | run_id | 1:5 | 每局5属性各1条 |
| 1:N | runtime_run | runtime_buff | run_id | 1:0~N | 每局0~N个Buff |
| 1:N | runtime_run | runtime_training_log | run_id | 1:0~30 | 每局最多30条锻炼日志 |
| 1:1 | runtime_run | runtime_final_battle | run_id | 1:0~1 | 终局时有1条 |
| 1:N | runtime_run | battle_main | run_id | 1:0~N | 每局若干场战斗 |
| 1:N | battle_main | battle_round | battle_id | 1:0~20 | 每场最多20回合 |
| 1:N | battle_main | battle_action | battle_id | 1:0~N | 每场N次行动 |
| 1:1 | battle_main | battle_final_result | battle_id | 1:1 | 每场1条结果 |
| N:1 | hero_config | skill_config | passive/ultimate_skill_id | N:1 | 技能引用 |
| N:1 | partner_config | partner_assist_config | partner_id | 1:1 | 伙伴援助配置 |
| N:1 | partner_config | partner_support_config | partner_id | 1:1 | 伙伴支援配置 |

### 5.3 数据流向图 `[已对齐: 规格书3.2节/4.2节]`

```
[游戏启动]
    │
    ├──► 加载全部 _config 表到内存（只读）
    │
[开始新养成循环]
    │
    ├──► 创建 runtime_run（顶层记录）
    ├──► 创建 runtime_hero（根据 hero_config_id 初始化）
    ├──► 创建 runtime_mastery（5属性初始stage=1生疏）
    ├──► 创建 runtime_partner（酒馆选2名同行伙伴）
    │
[回合推进 1→30]
    │
    ├──► 读取 node_config + node_pool_config 决定节点类型
    │    ├──► TRAINING → 更新 runtime_mastery（stage/training_count）
    │    │              创建 runtime_training_log
    │    │              更新 runtime_hero（属性值重新计算）
    │    ├──► BATTLE → 读取 enemy_config 生成敌人
    │    │             创建 battle_main + battle_round + battle_action
    │    │             更新 runtime_hero（HP/伤害统计）
    │    ├──► ELITE → 同上，但失败时 run_status=LOSE
    │    ├──► SHOP → 读取 shop_config 展示商品
    │    │            更新 runtime_hero（属性加成/升级）
    │    ├──► RESCUE → 读取 partner_config 生成候选伙伴
    │    │             创建 runtime_partner（招募成功时）
    │    ├──► PVP_CHECK → 读取 fighter_archive 作为对手
    │    │                创建 battle_main（PVP类型）
    │    │                更新 runtime_run（PVP结果）
    │    └──► FINAL → 读取 enemy_config（终局敌人）
    │                  创建 runtime_final_battle
    │                  创建 battle_main（FINAL类型）
    │
[终局结算]
    │
    ├──► 从 runtime_run / runtime_hero / runtime_partner / runtime_mastery
    │    / runtime_final_battle 聚合数据
    │    ──► 创建 fighter_archive_main（持久化存档）
    │    ──► 创建 fighter_archive_partner（伙伴快照）
    │    ──► 创建 fighter_archive_score（评分明细）
    │
    ├──► 更新 player_account（累计统计/解锁进度）
    │
    └──► 清理 runtime_* 表（或保留供复盘后清除）
```

---

## 六、Phase 1 占位数据汇总

### 6.1 各表占位数据量

| 序号 | 表名 | 类型 | Phase 1数据量 | 数据来源 | 对齐状态 |
|:---:|:---|:---:|:---:|:---|:---:|
| 1 | hero_config | 静态配置 | **3条** | 勇者、影舞者、铁卫 | `[已对齐: 规格书4.7节]` |
| 2 | partner_config | 静态配置 | **6条** | 剑士、斥候、盾卫、药师、术士、猎人 `[已对齐: 规格书6.1节]` | 原12条→6条（Phase 1仅默认解锁6个） |
| 3 | skill_config | 静态配置 | **~20条** | 3主角×2技能 + 6伙伴援助技 + 通用 | `[已对齐: 规格书4.7节/4.8节]` |
| 4 | partner_assist_config | 静态配置 | **6条** | 6伙伴各1条援助配置 | `[新增: 规格书4.4节]` |
| 5 | partner_support_config | 静态配置 | **6条** | 6伙伴各1条支援配置 | `[新增: 规格书4.8节]` |
| 6 | attribute_mastery_config | 静态配置 | **20条** | 5属性×4阶段 `[已对齐: 规格书4.5节]` | 原15~20条→20条（精确4阶段） |
| 7 | node_config | 静态配置 | **7条** | 7种节点类型各1条 | `[新增: 规格书3.1节]` |
| 8 | node_pool_config | 静态配置 | **7~10条** | 每类普通节点1条 | `[已对齐: 规格书4.2节]` |
| 9 | enemy_config | 静态配置 | **5条** | 5种精英敌人模板 `[已对齐: 规格书5.2节]` | 确认5条 |
| 10 | battle_formula_config | 静态配置 | **1条** | 全局一套公式参数 | 确认1条 |
| 11 | shop_config | 静态配置 | **8条** | 主角/伙伴升级 + 属性/回复道具 `[已对齐: 规格书4.6节]` | 原8~12条→8条 |
| 12 | scoring_config | 静态配置 | **1条** | 评分公式配置 | `[新增: 规格书6.3节]` |
| 13 | runtime_run | 局内运行 | **1条/局** | 每次养成循环创建1条 | 确认1条/局 |
| 14 | runtime_hero | 局内运行 | **1条/局** | 每局1条 `[已对齐: 规格书4.7节]` | 删除level/xp/equipment字段 |
| 15 | runtime_partner | 局内运行 | **0~6条/局** | 根据招募情况 `[已对齐: 规格书4.4节]` | 删除xp字段，level上限改为3 |
| 16 | runtime_mastery | 局内运行 | **5条/局** | 5属性各1条 `[已对齐: 规格书3.2节]` | redesign为阶段制 |
| 17 | runtime_buff | 局内运行 | **0~N条/局** | 动态创建 | `[新增: 规格书5.2节]` |
| 18 | runtime_training_log | 局内运行 | **0~30条/局** | 每次锻炼1条 | `[新增: 规格书4.5节]` |
| 19 | runtime_final_battle | 局内运行 | **0~1条/局** | 终局时创建 | `[新增: 规格书4.2节]` |
| 20 | player_account | 局外存档 | **1条/设备** | 单机本地1个账号 `[已对齐: 规格书6.1节]` | 解锁逻辑对齐 |
| 21 | fighter_archive_main | 局外存档 | **N条** | 保留最近50条 `[待确认: 规格书未明确保留条数]` | 扩展评分相关字段 |
| 22 | fighter_archive_partner | 局外存档 | **0~5条/档案** | 伙伴快照 | `[新增: 规格书4.6节]` |
| 23 | fighter_archive_score | 局外存档 | **1条/档案** | 评分明细 | `[新增: 规格书6.3节]` |
| 24 | battle_main | 战斗数据 | **0~N条/局** | 仅精英/PVP/终局战存储 | `[新增: 规格书3.2节]` |
| 25 | battle_round | 战斗数据 | **0~20条/战斗** | 每场战斗的回合记录 | `[新增: 规格书4.3节]` |
| 26 | battle_action | 战斗数据 | **0~N条/战斗** | 每次行动的详细记录 | `[新增: 规格书4.3节]` |
| 27 | battle_final_result | 战斗数据 | **1条/战斗** | 战斗结果统计 | `[新增: 规格书4.3节]` |

### 6.2 静态配置数据总量估算

| 大类 | 表数 | Phase 1数据条数 |
|:---:|:---:|:---:|
| 角色相关 | 5张（hero + partner + skill + assist + support） | ~41条 |
| 战斗相关 | 3张（enemy + formula + scoring） | ~7条 |
| 养成相关 | 3张（shop + node_config + node_pool） | ~22~25条 |
| 精通系统 | 1张（attribute_mastery） | 20条 |
| **静态配置合计** | **12张** | **~90~93条** |

### 6.3 五属性编码使用验证 `[已对齐: 规格书3.3节]`

| 表名 | 属性字段 | 编码说明 | 验证 |
|:---:|:---|:---|:---:|
| hero_config | base_vit/str/agi/tec/mnd | 直接存储数值 | 确认 |
| partner_config | favored_attr | 1~5编码 | 确认 |
| skill_config | power_attr | 1~5编码 | 确认 |
| partner_support_config | supported_attr | 1~5编码 | 确认 |
| attribute_mastery_config | attr_type | 1~5编码 | 确认 |
| runtime_hero | current_vit/str/agi/tec/mnd | 直接存储数值 | 确认 |
| runtime_partner | current_vit/str/agi/tec/mnd | 直接存储数值 | 确认 |
| runtime_mastery | attr_type | 1~5编码 | 确认 |
| fighter_archive_main | attr_snapshot_vit/str/agi/tec/mnd | 直接存储数值 | 确认 |
| fighter_archive_partner | final_vit/str/agi/tec/mnd | 直接存储数值 | 确认 |
| runtime_training_log | attr_type | 1~5编码 | 确认 |
| shop_config | target_attr | 0~5编码（0=非属性） | 确认 |
| runtime_run | training_count_per_attr | 5元素数组[体魄,力量,敏捷,技巧,精神] | 确认 |

---

## 附录：待确认事项汇总

> 以下事项规格书已提供信息的部分已对齐，规格书确实未明确的项保留如下：

| 序号 | 所在表/模块 | 字段/事项 | 当前状态 | 说明 |
|:---:|:---|:---|:---:|:---|
| 1 | battle_formula_config | hp_from_vit, speed_from_agi, crit_dmg_multiplier等 | `[待确认: 规格书未明确具体数值]` | 规格书4.3节给出公式框架，具体数值需数值策划确认 |
| 2 | battle_formula_config | evade_from_agi, hit_from_tec, resist_from_mnd | `[待确认: 规格书未明确具体数值]` | 规格书提到敏捷影响闪避、技巧影响命中、精神影响抗性，但未给出具体系数 |
| 3 | battle_formula_config | chain_window | `[待确认: 规格书未明确]` | 连锁判定窗口（连续N次同属性攻击触发连锁）的具体数值 |
| 4 | partner_assist_config | max_trigger_per_battle默认值 | `[待确认: 规格书未明确]` | 规格书4.4节提到"每伙伴每场最多2次"，但这是连锁限制还是援助总次数限制 |
| 5 | player_account | ~~settings_* 全部字段~~ | `[修正:L1: 已删除]` | Phase 1不包含设置系统，相关字段已移除，后续Phase需要时再加 |
| 6 | fighter_archive_main | 本地保留条数上限 | `[待确认: 规格书未明确保留条数]` | 规格书4.6节未明确本地保留最近多少条档案，暂设50条 |
| 7 | runtime_run | seed（随机数种子） | `[待确认: 规格书未明确]` | 规格书未提及是否需要保存随机种子用于复盘 |
| 8 | shop_config | cost_base, cost_increase_per_buy 具体数值 | `[待确认: 规格书未明确具体数值]` | 规格书4.6节提到"价格递增"但未给出具体数值 |
| 9 | 全局 | Buff系统独立配置表 | `[待确认: 规格书未明确]` | 规格书5.2节提到精英战奖励Buff效果，但未定义是否需要独立buff_config表 |
| 10 | 全局 | 存档格式 | `[待确认: 规格书未明确]` | 规格书2.1节提到"本地JSON文件"，但是否按表拆分或合并存储未明确 |

---

## 变更日志

| 版本 | 日期 | 变更内容 | 对齐依据 |
|:---:|:---|:---|:---|
| v1.0 | 原始 | 初始14张表设计，大量`[待确认]` | 无 |
| v2.0 | 本次 | 扩展至27张表，所有`[待确认]`项已与规格书对齐 | 规格书3.1/3.2/3.3/4.x/5.x/6.x节 |

**主要变更摘要**：
1. **新增12张表**：partner_assist_config、partner_support_config、node_config、scoring_config、runtime_buff、runtime_training_log、runtime_final_battle、fighter_archive_partner、fighter_archive_score、battle_main、battle_round、battle_action、battle_final_result
2. **重设attribute_mastery_config**：从"等级+XP"系统改为规格书4.5节的"锻炼次数→4阶段→加成"映射
3. **删除字段**：runtime_hero.current_level/current_xp/equipment_list（规格书无等级/装备系统）；runtime_partner.current_xp
4. **新增字段**：runtime_run增加评分/PVP/边际递减相关字段；fighter_archive_main扩展评分快照字段
5. **所有五属性编码确认统一**：1=体魄, 2=力量, 3=敏捷, 4=技巧, 5=精神
6. **伙伴数量确认**：Phase 1仅6名默认解锁伙伴（剑士/斥候/盾卫/药师/术士/猎人），等级上限Lv3
7. **主角初始属性确认**：按规格书4.7节填入具体数值
8. **敌人模板确认**：按规格书5.2节5种精英敌人定义
9. **评分系统确认**：按规格书6.3节/6.4节5项加权评分+S/A/B/C/D评级
10. **解锁系统确认**：按规格书6.1节主角递进解锁+6伙伴默认解锁

---

> **文档结束**
>
> 产出：`03_data_schema.md` | 总表数：27张 | 静态配置：12张 | 局内运行：7张 | 局外存档：4张 | 战斗数据：4张
