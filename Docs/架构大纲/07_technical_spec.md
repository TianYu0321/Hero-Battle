# 技术规范与开发约束（Technical Specification & Development Constraints）

> **文档版本**: Phase 1 MVP [已对齐: 规格书v1.0]
> **适用范围**: "赛马娘版Q宠大乐斗" Roguelike回合制养成游戏
> **引擎版本**: Godot 4.x [已对齐: 规格书2.1节]
> **语言**: GDScript（Phase 1唯一语言）[修正:M2: 规格书2.1节虽写".NET/C# 或 GDScript"，但项目已决策GDScript唯一，删除C#选项以消除歧义]
> **基准规格书状态**: 已对齐，所有修改标注 `[已对齐: 规格书X.X节]`
> **文档用途**: 本规范作为代码Agent的编码检查清单，所有约束条目可直接用于代码审查

---

## 目录

1. [命名规范](#1-命名规范)
2. [代码组织约束](#2-代码组织约束)
3. [错误处理策略](#3-错误处理策略)
4. [性能约束](#4-性能约束)
5. [版本控制规范](#5-版本控制规范)

---

## 1. 命名规范

### 1.1 文件命名

| 文件类型 | 命名规则 | 示例 |
|----------|----------|------|
| `.gd` 脚本文件（通用模块） | `snake_case.gd` | `battle_engine.gd`, `character_manager.gd` |
| `.gd` 脚本文件（UI专属） | `snake_case_ui.gd` | `menu_ui.gd`, `run_hud.gd`, `battle_ui.gd` |
| `.gd` 脚本文件（组件级） | `snake_case.gd`，无组件后缀 | `damage_number.gd`, `unit_display.gd` |
| `.tscn` 场景文件 | 与绑定脚本同名（不含扩展名） | `battle_engine.tscn` → `battle_engine.gd` |
| `.tscn` 场景文件（纯UI预制体） | `snake_case.tscn` | `damage_number.tscn`, `text_log_panel.tscn` |
| `.json` 配置文件 | `snake_case.json`，使用复数形式表示集合 | `hero_configs.json`, `partner_configs.json`, `skill_table.json` |
| `.tres` 资源文件 | `snake_case.tres` | `default_theme.tres`, `battle_font.tres` |
| 目录名 | `snake_case`，使用单数名词 | `autoload/`, `system/`, `ui/`, `data/`, `asset/` |

**约束清单：**
- [ ] 所有文件名必须使用 `snake_case`
- [ ] 场景文件与其主绑定脚本同名（如 `foo.tscn` 绑定 `foo.gd`）
- [ ] 配置文件名使用复数形式表示配置集合（`hero_configs.json` 而非 `hero.json`）
- [ ] 目录名使用单数名词

### 1.2 类名（class_name）

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 通用模块类 | `PascalCase`，以功能命名 | `BattleEngine`, `CharacterManager`, `RewardSystem` |
| UI相关类 | `PascalCase`，后缀 `_UI` | `MenuUI`, `RunHUD`, `BattleUI` |
| 数据模型类 | `PascalCase`，后缀 `_Data` 或裸名词 | `HeroData`, `PartnerData`, `BattleResult` |
| 自定义资源类 | `PascalCase`，后缀 `_Resource` 或 `@tool` + `@icon` | `HeroConfigResource` |
| 枚举封装类 | 不定义 class_name，仅在定义文件中内部使用 | — |

**约束清单：**
- [ ] 所有 `class_name` 使用 `PascalCase`
- [ ] UI类名以 `UI` 结尾（如 `BattleUI`）
- [ ] 数据模型类名以 `Data` 结尾（如 `HeroData`）
- [ ] 每个 `.gd` 文件最多声明一个 `class_name`（单类原则）

### 1.3 函数名

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 公共函数（可被外部调用） | `snake_case`，动词开头 | `start_battle()`, `apply_damage()`, `get_hero_data()` |
| 私有函数（仅在类内部使用） | `_snake_case`，以下划线开头 | `_calculate_damage()`, `_resolve_turn_order()` |
| 虚函数（供子类重写） | `_virtual_snake_case`，以下划线开头 | `_on_turn_started()`, `_before_action_execute()` |
| 信号回调函数 | `_on_emitter_signal_name` | `_on_battle_started()`, `_on_stats_changed()` |
| 初始化函数 | `initialize()` 或 `_ready()`（Godot内置） | `initialize_run(config)` |
| Getter/Setter | `get_property()` / `set_property(value)` | `get_current_hp()`, `set_speed(value)` |

**约束清单：**
- [ ] 公共函数使用 `snake_case`，不加下划线前缀
- [ ] 私有函数使用 `_snake_case`，以下划线开头
- [ ] 信号回调函数命名格式为 `_on_发射者_信号名`（如 `_on_run_controller_round_changed`）
- [ ] Godot 内置虚函数（`_ready`, `_process`, `_physics_process`, `_unhandled_input`）保持原名
- [ ] 返回 `bool` 的函数以 `is_` / `has_` / `can_` 开头（如 `is_alive()`, `has_skill()`, `can_act()`）

### 1.4 变量名

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 局部变量 | `snake_case` | `current_hp`, `damage_amount` |
| 成员变量（可被外部访问） | `snake_case`，通过 @export 或 getter/setter | `current_round`, `max_rounds` |
| 私有成员变量 | `_snake_case`，以下划线开头 | `_battle_state`, `_turn_queue` |
| 常量（`const`） | `UPPER_SNAKE_CASE` | `MAX_CHAIN_SEGMENTS`, `MAX_PARTNER_ASSISTS` |
| 枚举值 | `UPPER_SNAKE_CASE`（命名空间由枚举类型名提供） | `NodeType.BATTLE`, `BattleState.RUNNING` |
| 布尔变量 | `is_` / `has_` / `can_` 前缀 | `is_player_turn`, `has_active_buff` |
| Godot 节点引用 | `_snake_case` + `_node` 或直接用节点名 | `_sprite_node`, `_animation_player` |
| 信号 | `snake_case`，以过去分词或事件名词结尾 | `battle_started`, `damage_taken` |

**约束清单：**
- [ ] 常量必须全部大写 `UPPER_SNAKE_CASE`
- [ ] 私有成员变量以下划线开头 `_snake_case`
- [ ] 布尔变量使用语义前缀 `is_` / `has_` / `can_`
- [ ] 信号名使用 `snake_case`，表示已发生的事件（过去式或状态描述）
- [ ] 信号名不使用命令式（用 `battle_started` 而非 `start_battle`）

### 1.5 信号名

信号在 `EventBus` 中集中声明，命名遵循以下规则 [已对齐: 规格书2.2节]：

| 前缀 | 含义 | 示例 |
|------|------|------|
| `battle_` | 战斗相关事件 | `battle_started`, `turn_started`, `action_executed`, `unit_damaged`, `battle_ended` |
| `run_` | 养成循环事件 | `run_started`, `round_changed`, `run_ended` |
| `node_` | 节点相关事件 | `node_entered`, `node_resolved`, `shop_entered` |
| `stats_` | 属性变更事件 | `stats_changed`, `partner_unlocked`, `skill_learned` |
| `reward_` | 奖励发放事件 | `reward_granted`, `item_acquired`, `gold_changed` |
| `pvp_` | PVP相关事件 | `pvp_match_found`, `pvp_result` |
| `enemy_` | 敌人相关事件 | `enemy_spawned` |
| `ui_` / `hud_` / `menu_` | UI面板事件（EventBus → UI） | `ui_panel_opened`, `hud_stats_updated` |

**约束清单：**
- [ ] 信号名使用 `snake_case`
- [ ] 信号名以模块前缀开头（`battle_`, `run_`, `stats_` 等）
- [ ] 信号名表示已发生的事件，使用过去式或名词（`battle_started` 而非 `start_battle`）
- [ ] 信号参数不超过4个，超过时使用 `Dictionary` 封装 [待确认：具体参数数量上限，规格书未明确]
- [ ] EventBus 中的信号必须添加类型注释：`signal battle_started(allies: Array, enemies: Array)`

### 1.6 常量命名与存放

#### 1.6.1 全局游戏常量 [已对齐: 规格书2.2节]

以下常量集中存放于 `ConfigManager` 单例内部的常量区域，不再独立为 AutoLoad 单例 [已对齐: 规格书2.2节]：

```gdscript
## res://autoload/config_manager.gd — 常量区域（原 game_constants.gd 内容并入此处）
## [已对齐: 规格书2.2节 — GameConstants 降级为 ConfigManager 内部工具类]

# --- 养成循环常量 ---
const MAX_ROUNDS: int = 30           # [已对齐: 规格书4.2节]
const INITIAL_GOLD: int = 0          # [待确认: 规格书未明确初始金币数]
const MAX_PARTY_SIZE: int = 5        # [已对齐: 规格书4.4节 — 1主角+2同行+3救援=最大5名伙伴]

# --- 战斗常量 ---
const MAX_CHAIN_SEGMENTS: int = 4    # [已对齐: 规格书4.3节 — 最多4段连锁]
const MAX_PARTNER_ASSISTS_PER_BATTLE: int = 2  # [已对齐: 规格书4.4节 — 单场每个伙伴最多触发2次]
const BASE_CRITICAL_MULTIPLIER: float = 1.5    # [待确认: 规格书未明确暴击倍率]
const BATTLE_MAX_ROUNDS: int = 20    # [已对齐: 规格书4.3节 — 战斗最多20回合]

# --- 属性常量 ---
const MIN_STAT_VALUE: int = 0
const MAX_STAT_VALUE: int = 999      # [待确认: 规格书未明确属性上限]

# --- 五属性编码 [已对齐: 规格书3.3节] ---
const ATTR_PHYSIQUE: int = 1   # 体魄 — 生命/防御/抗伤
const ATTR_STRENGTH: int = 2   # 力量 — 普攻伤害/物理技能/破防
const ATTR_AGILITY: int = 3    # 敏捷 — 先手/闪避/连击/行动频率
const ATTR_TECHNIQUE: int = 4  # 技巧 — 命中/暴击/技能触发率
const ATTR_SPIRIT: int = 5     # 精神 — 抗性/低血爆发/终盘表现

# --- 节点常量 ---
const NODE_OPTIONS_PER_ROUND: int = 3 # [已对齐: 规格书4.2节 — 每回合3个选项]

# --- 存档常量 ---
const SAVE_SLOT_COUNT: int = 3
const SAVE_DIR: String = "user://saves/"
const ARCHIVE_FILE: String = "user://archive.json"
```

**约束清单：**
- [ ] 所有 `const` 使用 `UPPER_SNAKE_CASE`
- [ ] 全局游戏常量集中在 `ConfigManager` 单例中管理 [已对齐: 规格书2.2节]
- [ ] 模块级常量（仅在单个模块中使用）放在该模块 `.gd` 文件的顶部，标记为 `const`
- [ ] 常量必须标注类型（`: int`, `: float`, `: String`）

#### 1.6.2 模块级常量存放位置

| 常量类别 | 存放位置 | 示例 |
|----------|----------|------|
| 全局共享常量 | `ConfigManager` 单例内部常量区 | `MAX_ROUNDS`, `MAX_CHAIN_SEGMENTS` [已对齐: 规格书2.2节] |
| 模块专用常量 | 模块 `.gd` 文件顶部 | `BattleEngine` 中的 `_MAX_TURN_TIMEOUT` |
| 配置默认值 | `ConfigManager` 中的回退字典 | 配置加载失败时的回退值 |
| UI布局常量 | 对应UI脚本的 `const` | `PANEL_WIDTH`, `ANIM_DURATION` |

### 1.7 配置表字段名与代码变量名的映射规则

JSON 配置文件使用 `snake_case` 作为字段名，与代码中的 `snake_case` 变量名直接一一对应 [已对齐: 规格书2.1节、3.1节]：

```json
// hero_configs.json
{
  "hero_id": "h001",
  "hero_name": "特别周",
  "base_physique": 12,
  "base_strength": 16,
  "base_agility": 10,
  "base_technique": 12,
  "base_spirit": 8,
  "skill_list": ["s001", "s002"],
  "evolve_at_level": 3
}
```

**五属性字段命名规范** [已对齐: 规格书3.3节]：

| 编码 | 属性 | JSON字段前缀 | 代码变量前缀 |
|:---:|:---|:---|:---|
| 1 | 体魄 | `physique` | `base_physique`, `cur_physique` |
| 2 | 力量 | `strength` | `base_strength`, `cur_strength` |
| 3 | 敏捷 | `agility` | `base_agility`, `cur_agility` |
| 4 | 技巧 | `technique` | `base_technique`, `cur_technique` |
| 5 | 精神 | `spirit` | `base_spirit`, `cur_spirit` |

```gdscript
# 代码中对应的数据类
class_name HeroData
extends RefCounted

var hero_id: String
var hero_name: String
var base_physique: int   # [已对齐: 规格书3.3节 — 编码1=体魄]
var base_strength: int   # [已对齐: 规格书3.3节 — 编码2=力量]
var base_agility: int    # [已对齐: 规格书3.3节 — 编码3=敏捷]
var base_technique: int  # [已对齐: 规格书3.3节 — 编码4=技巧]
var base_spirit: int     # [已对齐: 规格书3.3节 — 编码5=精神]
var skill_list: Array[String]
var evolve_at_level: int
```

**映射规则约束清单：**
- [ ] JSON 字段名使用 `snake_case`，与代码变量名完全一致
- [ ] JSON 中 ID 字段使用 `{entity}_id` 格式（`hero_id`, `partner_id`, `skill_id`）[已对齐: 规格书3.1节]
- [ ] JSON 中名称字段使用 `{entity}_name` 格式
- [ ] JSON 中列表字段使用复数或 `_list` 后缀
- [ ] **所有数据表中的属性字段统一使用五属性编码（1-5），禁止混用字符串和数字** [已对齐: 规格书3.3节]
- [ ] 代码加载配置后，必须做字段存在性校验（见第3章错误处理）
- [ ] 配置表 ID 格式建议 `{类型首字母}{3位数字}`：`h001`（主角）、`p001`（伙伴）、`s001`（技能）、`e001`（敌人）[待确认: 规格书未明确ID格式]

### 1.8 AutoLoad 单例命名 [已对齐: 规格书2.2节]

规格书定义 **5个** AutoLoad 单例，严格对齐如下：

| 单例脚本文件 | 全局变量名（Node Name） | class_name | 原设计映射 |
|-------------|----------------------|------------|-----------|
| `event_bus.gd` | `EventBus` | `EventBus` | 一致（原名保留） |
| `config_manager.gd` | `ConfigManager` | `ConfigManager` | 原 `GameData` → `ConfigManager` [已对齐: 规格书2.2节] |
| `game_manager.gd` | `GameManager` | `GameManager` | 原 `SceneManager` → `GameManager` [已对齐: 规格书2.2节] |
| `save_manager.gd` | `SaveManager` | `SaveManager` | 原 `SaveArchive` → `SaveManager` [已对齐: 规格书2.2节] |
| `audio_manager.gd` | `AudioManager` | `AudioManager` | 原设计遗漏，已补齐 [已对齐: 规格书2.2节] |

**注意：原设计中的 `GameConstants` 和 `GameEnums` 已从 AutoLoad 清单中移除**，其内容分别并入 `ConfigManager` 内部常量区和工具方法中 [已对齐: 规格书2.2节]。原设计的 `UIManager` 也从 AutoLoad 中移除（规格书 autoload 清单中无此单例），改为普通节点由 GameManager 管理 [已对齐: 规格书2.2节]。

**约束清单：**
- [ ] AutoLoad 单例的脚本文件名、全局变量名、`class_name` 三者完全一致（仅大小写差异）
- [ ] AutoLoad 单例使用 `PascalCase` 作为全局变量名
- [ ] AutoLoad 单例在 `project.godot` 中的顺序即为初始化顺序
- [ ] **AutoLoad 单例数量 = 5**，与规格书 `autoload/` 目录一致 [已对齐: 规格书2.2节]

---

## 2. 代码组织约束

### 2.1 文件职责范围

**核心原则：一个 `.gd` 文件对应一个 `class_name`，一个类只负责一种职责。**

| 规则 | 说明 |
|------|------|
| 单类原则 | 每个 `.gd` 文件最多声明一个 `class_name` |
| 最小职责 | 类的职责不超过模块拆分表中定义的范围（参见 `01_module_breakdown.md`） |
| 代码行数 | 单个 `.gd` 文件不超过 **600 行**（含注释），超过必须拆分 |
| 函数数量 | 单个类的公共函数不超过 **20 个**，超过考虑拆分子模块 |
| 信号数量 | 单个类的信号声明不超过 **15 个** |

**分层文件存放位置：**

| 层级 | 存放目录 | 文件类型 |
|------|----------|----------|
| AutoLoad 单例 | `res://autoload/` | 全局服务脚本 [已对齐: 规格书2.2节] |
| 功能层模块 | `res://scripts/core/` 和 `res://scripts/systems/` | 游戏逻辑脚本 [已对齐: 规格书2.2节] |
| UI 面板 | `res://scenes/{子目录}/` | UI 场景 `.tscn` + 脚本 `.gd` [已对齐: 规格书2.2节] |
| 数据定义 | `res://resources/` | 数据模型类、配置JSON [已对齐: 规格书2.2节] |
| 通用组件 | `res://scenes/shared/` | 可复用 UI 预制体 [已对齐: 规格书2.2节] |
| 主场景 | `res://scenes/` | 顶级场景文件 [已对齐: 规格书2.2节] |

**约束清单：**
- [ ] 每个 `.gd` 文件只有一个 `class_name`
- [ ] 文件行数不超过 600 行
- [ ] 公共函数不超过 20 个
- [ ] 按层级放入对应目录（`autoload/`、`scripts/core/`、`scripts/systems/`、`scenes/`、`resources/`、`scenes/shared/`）

### 2.2 class_name 使用规范

| 场景 | 是否需要 `class_name` | 说明 |
|------|----------------------|------|
| AutoLoad 单例（5个） | 是 | 需要通过全局变量名访问，如 `ConfigManager.get_hero_data()` [已对齐: 规格书2.2节] |
| 功能层模块（动态实例化） | 是 | 便于在其他模块中做类型检查和强引用 |
| UI 脚本 | 是 | 便于 UI 管理器做类型化面板管理 |
| 数据模型类 | 是 | 便于类型化参数传递和代码补全 |
| 纯工具函数脚本 | 否 | 使用静态函数或 `@static_unload`，不实例化 |
| 枚举定义文件 | 否 | 枚举通过命名引用，不需要实例化 |
| 场景内嵌小脚本 | 否 | 仅用于特定场景，不需要全局引用 |

**约束清单：**
- [ ] 需要被其他模块类型引用的类必须声明 `class_name`
- [ ] `class_name` 名称与文件名（不含 `.gd` 扩展名）的 `PascalCase` 形式一致
- [ ] 不需要跨文件类型引用的内部辅助类不声明 `class_name`

### 2.3 enum 定义位置 [已对齐: 规格书2.2节]

| enum 类别 | 定义位置 | 使用方式 |
|-----------|----------|----------|
| 全局枚举（跨多个模块使用） | `ConfigManager` 单例内部枚举区（原 `game_enums.gd` 内容并入） [已对齐: 规格书2.2节] | 通过 ConfigManager 引用 `ConfigManager.NodeType.BATTLE` |
| 模块专属枚举（仅一个模块使用） | 该模块 `.gd` 文件的顶部 | 直接引用 `BattleState.RUNNING` |
| UI 状态枚举 | 对应 UI 脚本内 | `PanelState.OPEN` / `PanelState.CLOSED` |

**ConfigManager 内部全局枚举区** [已对齐: 规格书2.2节 — 原 GameEnums 降级为 ConfigManager 内部工具]：

```gdscript
## res://autoload/config_manager.gd — 枚举区域
## [已对齐: 规格书2.2节 — GameEnums 并入 ConfigManager，避免增加第6个AutoLoad]

# 节点类型（7种）[已对齐: 规格书4.2节]
enum NodeType {
  TRAINING,       # 锻炼
  BATTLE_NORMAL,  # 普通战斗
  BATTLE_ELITE,   # 精英战
  SHOP,           # 商店
  RESCUE,         # 救援
  PVP_CHECK,      # PVP检定
  FINAL_BOSS,     # 终局战
}

# 战斗状态
enum BattleState {
  IDLE,
  STARTING,
  PLAYER_TURN,
  ENEMY_TURN,
  RESOLVING,
  ENDING,
  FINISHED,
}

# 养成循环终局类型 [已对齐: 规格书4.2节]
enum EndingType {
  VICTORY,    # 击败终局Boss
  DEFEAT,     # 战斗失败（生命归零或精英战败北）
  ABANDON,    # 玩家放弃
}

# 伤害类型
enum DamageType {
  PHYSICAL,
  MAGICAL,     # [待确认: 规格书未明确是否存在魔法伤害]
  TRUE_DAMAGE, # 无视防御
}

# 状态效果类型
enum StatusType {
  BUFF,
  DEBUFF,
}

# 播放模式 [已对齐: 规格书4.3节]
enum PlaybackMode {
  FAST_FORWARD,   # 简化快进（普通战斗2-3秒）
  STANDARD,       # 标准播放（精英战/PVP/终局战15-25秒）
}

# 熟练度阶段 [已对齐: 规格书4.5节]
enum MasteryStage {
  NOVICE,     # 生疏（0次锻炼）
  FAMILIAR,   # 熟悉（1-3次）
  PROFICIENT, # 精通（4-6次）
  EXPERT,     # 专精（≥7次）
}

# 评价等级 [已对齐: 规格书4.6节]
enum ScoreRank {
  S, A, B, C, D
}
```

**约束清单：**
- [ ] 全局枚举集中在 `ConfigManager` 单例中定义 [已对齐: 规格书2.2节]
- [ ] 模块专属枚举定义在该模块 `.gd` 文件顶部，`class_name` 之前
- [ ] 枚举值使用 `UPPER_SNAKE_CASE`
- [ ] 引用枚举时使用完整路径（`ConfigManager.NodeType.BATTLE` 而非魔法数字）

### 2.4 常量配置存放位置决策树

```
这个常量是否被多个模块共享？
├── 是 → 放入 ConfigManager 单例内部常量区 [已对齐: 规格书2.2节]
│        └── 是否可能在不同版本中变化？
│            ├── 是 → 考虑移入 JSON 配置文件
│            └── 否 → 保持为 GDScript const
└── 否 → 仅单个模块使用？
         ├── 是 → 放在该模块 .gd 文件顶部的 const
         └── 否（仅单个函数使用） → 放在函数内部的 const
```

**Phase 1 的常量分类存放表：**

| 常量 | 值 | 存放位置 | 理由 |
|------|-----|----------|------|
| `MAX_ROUNDS` | 30 | `ConfigManager` | 多个模块引用 [已对齐: 规格书4.2节] |
| `MAX_CHAIN_SEGMENTS` | 4 | `ConfigManager` | 战斗引擎+UI都需要 [已对齐: 规格书4.3节] |
| `MAX_PARTNER_ASSISTS` | 2 | `ConfigManager` | 战斗引擎+UI都需要 [已对齐: 规格书4.4节] |
| `BATTLE_MAX_ROUNDS` | 20 | `ConfigManager` | 战斗引擎使用 [已对齐: 规格书4.3节] |
| 敌人AI权重表 | [待确认] | JSON 配置文件 | 需要设计师调整 |
| 商店商品池 | [待确认] | JSON 配置文件 | 需要设计师调整 [已对齐: 规格书3.1节] |
| 伤害计算公式系数 | [待确认] | `BattleEngine` 模块级 const | 仅战斗引擎使用 [已对齐: 规格书4.3节] |
| 动画时长 | 0.3 | 对应UI模块 const | 仅该UI模块使用 |

**约束清单：**
- [ ] 多模块共享的常量在 `ConfigManager` 中定义 [已对齐: 规格书2.2节]
- [ ] 可能由设计师调整的数值放入 JSON 配置文件而非代码常量 [已对齐: 规格书2.1节]
- [ ] 模块专属常量放在模块 `.gd` 文件顶部
- [ ] 所有常量必须标注类型注释

---

## 3. 错误处理策略

### 3.1 配置表加载失败 [已对齐: 规格书2.1节]

**处理流程：**

```
ConfigManager.load_configs()
  ├── JSON 文件存在且格式正确 → 正常加载，缓存到字典
  ├── JSON 文件不存在 → 使用内嵌默认字典（fallback），记录 warning
  └── JSON 格式错误 → 使用内嵌默认字典（fallback），记录 error
```

**代码约束：**

```gdscript
## res://autoload/config_manager.gd [已对齐: 规格书2.2节]
const _FALLBACK_HERO_DATA: Dictionary = {
  "h001": {
    "hero_name": "默认主角",
    "base_physique": 12,
    "base_strength": 16,
    "base_agility": 10,
    "base_technique": 12,
    "base_spirit": 8,
  }
}

func get_hero_data(hero_id: String) -> HeroData:
  if not _hero_data.has(hero_id):
    push_warning("[ConfigManager] hero_id not found: %s, using fallback" % hero_id)
    # [待确认: 规格书未明确 — 未找到配置时的回退策略：使用默认值还是报错？]
    return _create_fallback_hero_data()
  return _hero_data[hero_id]
```

**约束清单：**
- [ ] 配置加载失败时 **不崩溃**，使用内嵌默认值回退
- [ ] 回退时通过 `push_warning()` 或 `push_error()` 输出日志
- [ ] 每个配置表必须有对应的 `FALLBACK_` 默认字典
- [ ] 加载失败的情况在主菜单以弹窗或日志提示告知玩家 [待确认: 规格书未明确UI提示方式]

### 3.2 数值计算中的除零/溢出保护

**必须做防护的计算场景：**

| 场景 | 防护代码模板 | 说明 |
|------|-------------|------|
| 除法运算 | `divisor = max(divisor, 1)` | 除数下限保护 |
| 百分比计算 | `clamp(ratio, 0.0, 1.0)` | 百分比范围限制 |
| 属性叠加 | `clamp(final_stat, MIN_STAT_VALUE, MAX_STAT_VALUE)` | 属性上下限钳制 |
| 伤害计算 | `max(damage, 1)` | 伤害至少为1 |
| 数组索引 | `clamp(index, 0, array.size() - 1)` | 索引越界保护 |
| 空数组遍历 | `if array.is_empty(): return` | 提前返回 |

**标准防护函数（建议放在工具类中）：**

```gdscript
## res://scripts/utils/formula_utils.gd（可选，如果计算复杂则创建）
static func safe_divide(numerator: float, denominator: float) -> float:
  if denominator == 0.0:
    push_warning("[FormulaUtils] Division by zero prevented, returning 0")
    return 0.0
  return numerator / denominator

static func clamp_stat(value: int) -> int:
  return clampi(value, ConfigManager.MIN_STAT_VALUE, ConfigManager.MAX_STAT_VALUE)

static func clamp_stat_f(value: float) -> float:
  return clampf(value, float(ConfigManager.MIN_STAT_VALUE), float(ConfigManager.MAX_STAT_VALUE))
```

**约束清单：**
- [ ] 所有除法运算前检查除数是否为0
- [ ] 所有属性值在赋值时做 `clamp` 限制
- [ ] 所有数组索引访问前检查数组非空和索引范围
- [ ] 战斗伤害最小值为1（不允许0伤害，除非有特殊闪避机制）[待确认: 规格书未明确最小伤害规则]

### 3.3 存档损坏的恢复策略 [已对齐: 规格书2.1节]

**存档文件结构：** [已对齐: 规格书2.1节 — 本地JSON文件]

```
user://saves/
  ├── save_001.json      # 当前局存档
  ├── save_002.json      # 第二槽位
  ├── save_003.json      # 第三槽位
  ├── archive.json       # 斗士档案
  └── backup/            # 自动备份目录
      ├── save_001_backup_{timestamp}.json
      └── ...
```

**存档加载错误处理流程：**

```
SaveManager.load_run(slot_id)
  ├── 文件不存在 → 返回 null（新游戏）
  ├── JSON 解析失败 → 尝试加载最近备份 → 备份也失败 → 返回 null
  ├── JSON 结构缺失关键字段 → 用默认值填充缺失字段，记录 warning
  └── 版本号不匹配 → 调用迁移函数 migrate_v{N}_to_v{N+1}
```

**约束清单：**
- [ ] 每次存档保存时自动创建一份带时间戳的备份（保留最近 5 份）[待确认: 规格书未明确备份数量]
- [ ] JSON 解析失败时自动尝试从 `backup/` 目录恢复
- [ ] 存档结构必须包含 `version` 字段用于版本兼容性检查
- [ ] 字段缺失时用该字段类型的默认值填充（`int→0`, `String→""`, `Array→[]`, `Dictionary→{}`）
- [ ] 存档操作失败时必须输出 `push_error()` 日志
- [ ] 斗士档案（`archive.json`）独立于局内存档，格式错误时重置为空档案 [已对齐: 规格书4.6节]

**存档数据结构约束：**

```gdscript
## 存档根结构（必须包含的字段）
var _REQUIRED_SAVE_FIELDS: Array[String] = [
  "version",        # 存档格式版本号 (int)
  "hero_id",        # 当前使用的主角ID
  "current_round",  # 当前回合数 (1-30)
  "current_node",   # 当前节点信息
  "party",          # 伙伴列表
  "inventory",      # 物品列表
  "gold",           # 金币数
  "hero_stats",     # 主角当前属性（五维属性编码1-5）[已对齐: 规格书3.3节]
  "timestamp",      # 存档时间戳
]
```

### 3.4 JSON 解析失败的降级处理

**标准 JSON 加载模式：**

```gdscript
static func load_json_safe(file_path: String, fallback: Dictionary = {}) -> Dictionary:
  if not FileAccess.file_exists(file_path):
    push_warning("[JSON] File not found: %s, using fallback" % file_path)
    return fallback.duplicate()

  var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
  if file == null:
    push_error("[JSON] Cannot open file: %s, error: %d" % [file_path, FileAccess.get_open_error()])
    return fallback.duplicate()

  var json_text: String = file.get_as_text()
  var json: JSON = JSON.new()
  var parse_result: Error = json.parse(json_text)

  if parse_result != OK:
    push_error("[JSON] Parse error in %s at line %d: %s" % [
      file_path, json.get_error_line(), json.get_error_message()
    ])
    return fallback.duplicate()

  var result = json.data
  if not result is Dictionary:
    push_error("[JSON] Root must be Dictionary in %s" % file_path)
    return fallback.duplicate()

  return result
```

**约束清单：**
- [ ] 所有 JSON 加载必须通过 `load_json_safe()` 包装函数
- [ ] 文件不存在 → 返回 `fallback` 字典
- [ ] JSON 解析错误 → 返回 `fallback` 字典 + `push_error` 日志
- [ ] 根节点非字典 → 返回 `fallback` 字典
- [ ] `fallback` 必须使用 `.duplicate()` 防止引用修改

---

## 4. 性能约束

### 4.1 帧率目标

| 阶段 | 目标帧率 | 最低可接受帧率 | 备注 |
|------|----------|---------------|------|
| Phase 1 MVP | 30 FPS | 20 FPS | 纯色块+文字标签，无复杂动画 |
| Phase 2 | 60 FPS | 45 FPS | 引入正式美术资源后 [待确认: 规格书未明确帧率目标] |

**约束清单：**
- [ ] 项目设置中 `application/run/frame_delay_milliseconds` 不设或设为0（不限制帧率）
- [ ] 通过 `Engine.max_fps = 30` 在 `_ready()` 中设置帧率上限（仅 Phase 1）
- [ ] 所有 `_process(delta)` 中的代码必须能在 33.3ms（1/30秒）内完成
- [ ] 战斗计算（不含动画）必须在 **100ms** 内完成
- [ ] 存档读写必须在 **500ms** 内完成

### 4.2 战斗计算时间预算 [已对齐: 规格书4.3节]

**播放模式分级与时长** [已对齐: 规格书4.3节]：

| 战斗类型 | 播放模式 | 预计时长 | 展示内容 |
|:---|:---|:---:|:---|
| **普通战斗** | 简化快进 | 2-3 秒 | 双方立绘 + 血条 + 每回合伤害数字 + 最终胜负 |
| **精英战** | 标准播放 | 15-25 秒 | 完整动画 + 伙伴援助 + 必杀技 + 连锁展示 |
| **PVP 检定** | 标准播放 | 15-25 秒 | 完整动画 + 伙伴援助 + 连锁展示 + 胜负判定 |
| **终局战** | 标准播放 + 日志 | 15-25 秒 | 完整动画 + 连锁展示 + 战后复盘统计 |

**简化快进模式（2-3秒）的时间拆分：**

| 阶段 | 时间预算 | 说明 |
|------|----------|------|
| 战斗初始化（阵容设置） | 200ms | 生成双方单位、初始化状态 |
| 每回合计算 | 50ms × 回合数 | 每场战斗最多20回合 [已对齐: 规格书4.3节] |
| 伤害数字弹出 | 300ms 总计 | 批量弹出，非逐次 |
| 结算动画 | 500ms | 胜利/失败结果展示 |
| 总时间 | ~2-3秒 | 20回合战斗 ≈ 200 + 50×20 + 300 + 500 = 2200ms |

**约束清单：**
- [ ] 快进模式下关闭逐帧动画，仅保留最终结果展示
- [ ] 每回合逻辑计算不超过 50ms（GDScript单线程执行）
- [ ] 使用 `await get_tree().create_timer(delay).timeout` 控制动画时序，而非 `OS.delay_msec()`
- [ ] 战斗回合上限为20回合 [已对齐: 规格书4.3节]，超过强制结束
- [ ] 精英战/PVP/终局战时长控制在15-25秒 [已对齐: 规格书4.3节]
- [ ] 连锁触发最多4段，每段间隔0.3-0.5秒动画 [已对齐: 规格书4.3节]

### 4.3 对象池使用建议

**Phase 1 是否需要对象池分析：**

| 对象类型 | 数量级 | 是否需要对象池 | 理由 |
|----------|--------|---------------|------|
| 伤害数字节点 | 每回合最多 10 个 | **不需要** | 纯色块+Label，实例化成本极低 |
| 战斗单位节点 | 每场战斗最多 6-8 个 | **不需要** | 数量固定，战斗开始时一次性实例化 |
| UI 面板实例 | 同时存在不超过 10 个 | **不需要** | 由 UI 管理器管理生命周期 |
| 日志文本项 | 累计可能较多 | 可选 | 滚动日志限制最大条目数（如 100 条），超出时移除最旧项 |

**约束清单：**
- [ ] Phase 1 **不强制使用对象池**，简化实现
- [ ] 滚动日志组件限制最大保留条目数为 **100 条**
- [ ] 超出条目上限时，`queue_free()` 最旧条目并移除引用
- [ ] Phase 2 引入粒子效果/复杂动画时重新评估对象池需求 [待确认: 规格书未明确]

### 4.4 内存管理注意事项

| 场景 | 风险 | 防护措施 |
|------|------|----------|
| 养成循环长时间运行 | `RunController` 持续30回合累积数据 | 每回合结束后清理上一回合的临时数据 |
| 战斗引擎重复实例化 | 每场战斗新建 `BattleEngine` 实例 | 确保 `battle_ended` 后调用 `queue_free()` |
| JSON 配置缓存 | `ConfigManager` 持有大量配置字典 | 使用 `Dictionary` 缓存，不重复加载 |
| 存档备份累积 | `backup/` 目录无限增长 | 保留最近 **5 份** 备份，旧备份自动删除 |
| 信号连接泄漏 | 动态实例化对象连接信号后未断开 | 使用 `Callable` + `disconnect` 在 `_exit_tree()` 中清理 |

**约束清单：**
- [ ] 动态实例化的对象（`BattleEngine`, `NodeResolver` 等）在销毁时调用 `queue_free()`
- [ ] 信号连接在对象销毁前必须断开，防止悬空回调
- [ ] 配置数据在 `ConfigManager` 中一次性加载后全局缓存，不重复读取文件 [已对齐: 规格书2.2节]
- [ ] 存档备份保留最多 5 份，超出时删除最旧的备份
- [ ] 使用 `weakref()` 持有可能提前释放的对象引用（如战斗中的临时Buff对象）
- [ ] 不使用 `free()`（不安全的立即释放），统一使用 `queue_free()`

### 4.5 性能监控代码模板

```gdscript
## 在关键计算函数中插入性能计时（仅在 DEBUG 模式下）
func _heavy_calculation() -> void:
  var start_time: int = Time.get_ticks_msec()

  # ... 计算逻辑 ...

  var elapsed: int = Time.get_ticks_msec() - start_time
  if elapsed > 50:
    push_warning("[Performance] _heavy_calculation took %d ms (budget: 50ms)" % elapsed)
```

**约束清单：**
- [ ] 所有耗时操作（> 50ms）必须有性能计时和超预算警告
- [ ] 性能日志仅在 `OS.is_debug_build()` 模式下输出

---

## 5. 版本控制规范

### 5.1 .gitignore 内容 [已对齐: 规格书2.1节]

```gitignore
# Godot 4.x .gitignore — 标准模板 [已对齐: 规格书2.1节 — Git + GitHub/GitLab]

# Godot-specific
.import/
.godot/              # Godot 4.x 导入缓存 [必须加入]
export.cfg
export_presets.cfg

# Imported translations
*.translation

# Mono / C# (Phase 1不使用C#，以下条目已注释)[修正:M2]
# .mono/
# data_*/
# *.csproj
# *.sln

# System-specific
.DS_Store
Thumbs.db
*.tmp
*.swp
*.swo
*~

# IDE
.vscode/
.idea/

# Build artifacts
/build/
/dist/

# User-specific (local-only files)
*.import
```

**约束清单：**
- [ ] 使用上述标准 Godot `.gitignore` 模板 [已对齐: 规格书2.1节]
- [ ] `.godot/` 目录（Godot 4.x 的导入缓存）**必须**加入 `.gitignore`
- [ ] `*.import` 文件（纹理/音频的导入配置）**必须**加入 `.gitignore`
- [ ] 实际导入后的资源文件（`.stex`, `.scn` 等缓存）**不提交**
- [ ] 版本控制使用 Git + GitHub/GitLab [已对齐: 规格书2.1节]

### 5.2 场景/脚本文件的二进制冲突避免

**冲突风险分析：**

| 文件类型 | 格式 | 冲突风险 | 策略 |
|----------|------|----------|------|
| `.gd` 脚本 | 纯文本 | 低 | 正常文本合并 |
| `.tscn` 场景 | 文本（类INI格式） | 中 | 单人编辑一个场景，或拆分场景 |
| `.tres` 资源 | 文本 | 中 | 正常文本合并 |
| `.json` 配置 | 纯文本 | 低 | 正常文本合并 |
| 图片/音频资源 | 二进制 | 高 | 使用 Git LFS [待确认: 规格书未明确是否使用 Git LFS] |

**避免场景冲突的协作策略：**

1. **场景拆分原则**：复杂UI场景拆分为子场景预制体
   ```
   # 不推荐：一个巨大的 tscn 包含所有UI
   run_hud.tscn          # 包含所有面板 → 多人频繁编辑，冲突风险高

   # 推荐：拆分为子预制体
   run_hud.tscn          # 仅包含布局框架
   ├── node_map_panel.tscn    # 独立的子场景
   ├── stat_panel.tscn        # 独立的子场景
   └── partner_panel.tscn     # 独立的子场景
   ```

2. **编辑锁定约定**：
   - 每个子场景在同一时间只由一人编辑
   - 修改 `.tscn` 前在团队频道声明

3. **脚本与场景分离**：
   - `.gd` 脚本文件不在 `.tscn` 中内嵌，始终保存为外部脚本
   - 这样即使 `.tscn` 冲突，脚本逻辑不受影响

**约束清单：**
- [ ] 复杂场景拆分为子场景预制体（每个面板独立 `.tscn`）
- [ ] 脚本始终保存为外部 `.gd` 文件，不在 `.tscn` 中内嵌
- [ ] 不直接编辑 `.tscn` 中的节点树结构，通过子场景引用组织
- [ ] 图片/音频等二进制资源使用 Git LFS 管理 [待确认: 规格书未明确]

### 5.3 配置表（JSON）的合并策略

**JSON 配置文件的版本控制规则：**

| 规则 | 说明 |
|------|------|
| 格式化提交 | JSON 文件提交前必须通过格式化工具（如 `jq` 或 IDE 格式化），确保一致缩进 |
| 单文件单职责 | 每张配置表只包含一种实体的配置（如 `hero_configs.json` 只含主角） [已对齐: 规格书3.1节] |
| 追加字段向后兼容 | 新增字段必须有默认值支持，旧版存档不报错 |
| 不修改已有 ID | 已存在的配置 ID 不修改、不删除，只能新增；废弃配置标记 `"deprecated": true` |
| 变更记录 | 每次修改 JSON 配置时，在提交消息中说明变更理由 |

**JSON 格式约束（便于代码合并）：**

```json
{
  "_meta": {
    "version": 1,
    "last_modified": "2024-01-15",
    "description": "主角配置表"
  },
  "entries": {
    "h001": {
      "hero_id": "h001",
      "hero_name": "勇者",
      "base_physique": 12,
      "base_strength": 16,
      "base_agility": 10,
      "base_technique": 12,
      "base_spirit": 8,
      "skill_list": ["s001", "s002"],
      "evolve_at_level": 3,
      "deprecated": false
    }
  }
}
```

**约束清单：**
- [ ] JSON 文件使用 2 空格缩进，提交前格式化
- [ ] 包含 `"_meta"` 元数据字段（版本号、最后修改时间、描述）
- [ ] 配置项用 `"entries"` 包裹，便于元数据和数据分离
- [ ] 废弃配置标记 `"deprecated": true` 而非删除
- [ ] 不修改已有 ID，新增配置只能追加
- [ ] 五属性字段使用编码1-5，禁止混用字符串 [已对齐: 规格书3.3节]

### 5.4 提交消息规范

| 前缀 | 用途 | 示例 |
|------|------|------|
| `[sys]` | 功能层系统修改 | `[sys] 修复战斗引擎回合顺序计算` |
| `[ui]` | UI 层修改 | `[ui] 新增战斗伤害数字动画` |
| `[data]` | 配置表修改 | `[data] 调整主角h001基础属性` |
| `[fix]` | Bug 修复 | `[fix] 修复存档读取时字段缺失崩溃` |
| `[perf]` | 性能优化 | `[perf] 优化JSON配置加载缓存` |
| `[docs]` | 文档更新 | `[docs] 更新技术规范枚举定义` |

**约束清单：**
- [ ] 提交消息使用 `[前缀] 描述` 格式
- [ ] 配置表修改必须包含 `[data]` 前缀和变更说明

---

## 附录 A：编码检查清单（Code Agent 速查）

### A.1 文件头模板

每个 `.gd` 文件必须包含以下头注释：

```gdscript
## res://scripts/core/battle_engine.gd
## 模块: BattleEngine
## 职责: 回合制战斗引擎核心，管理战斗状态机与伤害计算
## 依赖: EventBus, ConfigManager, CharacterManager, EnemyDirector
## 被依赖: NodeResolver, BattleUI
## class_name: BattleEngine

class_name BattleEngine
extends Node
# 版本: Phase 1 MVP
```

### A.2 代码风格速查

| 检查项 | 规则 | 优先级 |
|--------|------|--------|
| 缩进 | Tab（Godot 默认） | 必须 |
| 行尾分号 | 不使用 | 必须 |
| 类型注释 | 函数参数和返回值必须标注类型 | 必须 |
| 变量类型 | 尽可能使用静态类型（`: int`, `: String` 等） | 必须 |
| 信号类型 | 信号参数必须标注类型 | 必须 |
| 最大行宽 | 120 字符 | 建议 |
| 空行 | 类之间空 2 行，函数之间空 1 行 | 建议 |
| 注释语言 | 中文注释描述业务逻辑，英文注释描述技术细节 | 建议 |

### A.3 错误处理速查

| 检查项 | 规则 | 优先级 |
|--------|------|--------|
| 除零保护 | 所有除法运算前检查除数 | 必须 |
| 数组越界 | 索引访问前检查范围和空数组 | 必须 |
| 配置回退 | JSON加载失败使用fallback，不崩溃 | 必须 |
| 存档备份 | 每次保存自动备份，保留5份 | 必须 |
| 日志输出 | 异常情况使用 `push_warning()` / `push_error()` | 必须 |
| 空值检查 | 函数参数进入时做空值检查 | 必须 |

### A.4 性能速查

| 检查项 | 规则 | 优先级 |
|--------|------|--------|
| 帧率上限 | Phase 1 设 30 FPS | 必须 |
| 耗时操作计时 | > 50ms 的操作输出性能警告 | 建议 |
| 对象释放 | 动态实例使用 `queue_free()` 而非 `free()` | 必须 |
| 信号断开 | `_exit_tree()` 中断开所有信号连接 | 必须 |
| 配置缓存 | `ConfigManager` 全局缓存，不重复读取 [已对齐: 规格书2.2节] | 必须 |
| 战斗时长 | 普通战斗2-3秒，精英战/PVP/终局战15-25秒 [已对齐: 规格书4.3节] | 必须 |

---

## 附录 B：[待确认] 清单汇总

以下内容经与基准规格书核对后的状态：

### 已确认项（原[待确认]现已解决） [已对齐: 对应规格书章节]

| # | 已确认项 | 规格书依据 | 最终取值 |
|---|---------|-----------|---------|
| 1 | AutoLoad单例数量 | 规格书2.2节 | **5个**（GameManager/ConfigManager/SaveManager/AudioManager/EventBus） |
| 2 | 最大连锁段数 | 规格书4.3节 | **4段**（防止无限递归） |
| 3 | 战斗回合上限 | 规格书4.3节 | **20回合** |
| 4 | 普通战斗时长 | 规格书4.3节 | **2-3秒**（简化快进） |
| 5 | 精英战/PVP/终局战时长 | 规格书4.3节 | **15-25秒**（标准播放） |
| 6 | 最大回合数 | 规格书4.2节 | **30回合** |
| 7 | 最大伙伴数 | 规格书4.4节 | **5名**（1主角+2同行+3救援） |
| 8 | 五属性编码 | 规格书3.3节 | **1体魄/2力量/3敏捷/4技巧/5精神** |
| 9 | 每回合选项数 | 规格书4.2节 | **3个** |
| 10 | 熟练度阶段 | 规格书4.5节 | **四阶段**（生疏/熟悉/精通/专精） |
| 11 | 伙伴单场援助上限 | 规格书4.4节 | **每个伙伴每场最多2次** |
| 12 | 配置表数据源格式 | 规格书2.1节 | **Godot Resource + JSON导出** |
| 13 | 存档系统 | 规格书2.1节 | **本地JSON + Phase 3云端备份** |
| 14 | 版本控制 | 规格书2.1节 | **Git + GitHub/GitLab** |

### 仍待确认项（规格书未明确）

| # | 待确认项 | 影响范围 | 当前假设值 | 备注 |
|---|----------|----------|-----------|------|
| 1 | 初始金币数 | `ConfigManager.INITIAL_GOLD` | 0 | 规格书未明确 |
| 2 | 暴击倍率 | `ConfigManager.BASE_CRITICAL_MULTIPLIER` | 1.5 | 规格书未明确 |
| 3 | 属性上限 | `ConfigManager.MAX_STAT_VALUE` | 999 | 规格书未明确 |
| 4 | 存档备份数量 | `SaveManager` 备份策略 | 5 份 | 规格书未明确 |
| 5 | 日志最大条目数 | `RunHUD` 日志组件 | 100 条 | 规格书未明确 |
| 6 | 配置表 ID 格式 | 所有 JSON 配置 | `{类型}{3位数字}` | 规格书未明确 |
| 7 | 最小伤害规则 | `BattleEngine` 伤害计算 | 最小为 1 | 规格书未明确 |
| 8 | 是否存在魔法伤害 | `DamageType` 枚举 | 包含 MAGICAL | 规格书未明确 |
| 9 | 配置加载失败时的 UI 提示方式 | 主菜单反馈 | [未假设] | 规格书未明确 |
| 10 | Git LFS 使用 | 二进制资源管理 | [未假设] | 规格书未明确 |
| 11 | 信号参数数量上限 | EventBus 信号设计 | 4 个 | 规格书未明确 |
| 12 | Phase 2 帧率目标 | 性能规划 | 60 FPS | 规格书未明确 |
| 13 | 商店商品池生成规则 | `RewardSystem` | [未假设] | 规格书未明确 |
| 14 | 伤害计算公式系数 | `BattleEngine` | [待配置表确定] | 规格书未明确具体数值 |
| 15 | 主菜单具体布局 | UI设计 | [待确认] | 规格书未明确 |
| 16 | 战斗UI具体布局 | UI设计 | [待确认] | 规格书未明确 |

---

*文档结束。本规范已对齐基准规格书v1.0的2.1/2.2/2.3/3.3/4.3节，所有修改已标注[已对齐: 规格书X.X节]。*
*AutoLoad单例数量从7个（原设计）对齐为5个（规格书定义），GameConstants和GameEnums已降级为ConfigManager内部工具类。*
*规格书未明确的项保留[待确认]标注，当前假设值为开发团队暂定的合理值，需后续规格书补充确认。*
