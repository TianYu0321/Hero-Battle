# 设计文档缺陷分析报告

> 排查日期：2026-05-09
> 范围：Phase 0 七份设计文档（`01~07`）
> 结论：**文档在5个用户关注领域存在逻辑缺口或描述矛盾**，导致即使代码100%按文档实现，也会出现同样的问题。

---

## 一、每回合选项 + 伙伴逻辑（文档缺陷最严重的领域）

### 1.1 节点按钮交互链：文档完全缺失

**问题**：`06_ui_flow_design.md` 描述了RunMain的HUD布局（金币/生命/属性条/伙伴槽位），但**从未描述3个节点按钮的交互流程**。

| 文档 | 写了什么 | 缺了什么 |
|:---|:---|:---|
| `05_run_loop_design.md` 1.3节 | RUNNING子状态机（NODE_SELECT→NODE_EXECUTE→TURN_ADVANCE） | UI层如何进入/退出这些状态 |
| `02_interface_contracts.md` R07/R08 | `node_options_presented`信号参数格式 | **没有`node_selected`信号的定义**（代码中RunController.emit了不存在的信号） |
| `06_ui_flow_design.md` 3.3节 | HUD节点按钮的UI布局 | 按钮点击后的回调函数、调用链、信号发射 |
| `01_module_breakdown.md` RunController | "管理30回合推进" | 与RunMain之间的具体交互契约 |

**根因**：文档把RunController的状态机和RunMain的UI当成了两个独立系统描述，**没有画它们之间的交互时序图**。Phase 1的test测试绕过UI直接调用RunController，所以这个缺口从未暴露。

### 1.2 伙伴属性初始化：数据来源未指定

**问题**：`03_data_schema.md` 的 `partner_config` 表有完整的五维基础属性字段（`base_physique`/`base_strength`/...），但**没有任何一份文档明确说 `CharacterManager.initialize_partners()` 要从 `partner_config` 读取这些值**。

| 文档 | 说了什么 | 实际暗示了什么 |
|:---|:---|:---|
| `01_module_breakdown.md` CharacterManager | "负责主角和伙伴的属性计算" | 没指定初始化数据来源 |
| `03_data_schema.md` partner_config | 有`base_physique=10`等字段 | 但这些字段是否用于初始化？文档没说 |
| `05_run_loop_design.md` 3.2节 | 伙伴属性=基础值+支援加成 | 没写"基础值从哪来" |
| 代码实际 | 硬编码`p.current_vit=10` | 因为文档没指定，Agent只能猜 |

**根因**：`03_data_schema.md` 和 `01_module_breakdown.md` 之间的数据流没有明确映射。Schema有字段，但模块职责没说要读这些字段。

### 1.3 伙伴槽位刷新：信号→UI的映射缺失

**问题**：`EventBus` 有 `partner_unlocked` 信号（发射方=CharacterManager，接收方=RunHUD），但**没有描述RunMain如何响应这个信号来刷新伙伴名称和等级**。

| 文档 | 写了什么 | 缺了什么 |
|:---|:---|:---|
| `06_ui_flow_design.md` 1.4节 | PartnerContainer有5个ColorRect | 如何动态更新ColorRect下的Label文本 |
| `02_interface_contracts.md` partner_unlocked | 参数含`partner_id`/`partner_name`/`slot`/`level` | 没说UI层收到后怎么更新节点 |

**根因**：文档假设"信号投递了就自动刷新UI"，没有写UI回调逻辑。

---

## 二、没有战斗画面（文档矛盾，不是遗漏）

### 2.1 核心矛盾："要有战斗场景" vs "headless即可"

| 文档位置 | 内容 | 倾向 |
|:---|:---|:---:|
| `06_ui_flow_design.md` 1.1节 | 场景清单包含`battle.tscn` | 要有画面 |
| `04_battle_engine_design.md` 8.1节 | 定义fast_forward/standard/replay三种播放模式 | 要有画面 |
| `04_battle_engine_design.md` 代码注释 | "同步执行模式（单帧内完成），适用于headless测试" | 可以headless |
| `06_ui_flow_design.md` 5.1.1节 | fast_forward"2-3秒内完成，仅显示最终伤害数字和结果摘要" | 最低限度画面 |
| `04_battle_engine_design.md` 1.2节 | HERO_ACTION状态说"应用伤害并显示日志" | 应该有日志显示 |

**矛盾点**：
1. 文档既有战斗场景，又说fast_forward可以"仅显示最终结果"——那场景里的RoundLabel/HpBar/HeroRect/EnemyRect是干什么用的？
2. `04_battle_engine_design.md` 的headless注释和`06_ui_flow_design.md`的场景设计是**互斥**的：如果BattleEngine是单帧同步执行，UI根本来不及渲染任何动画
3. `06_ui_flow_design.md` 5.1.3节replay模式说"用于PVP回放、排行榜高光展示"，但Phase 1/2根本不做replay——这个模式在Phase 1/2是无用的，文档却把它列为三种模式之一

**根因**：`04_battle_engine_design.md` 和 `06_ui_flow_design.md` 对战斗的"可玩性级别"没有统一标准。一个按"后端推演"写，一个按"前端展示"写。

### 2.2 更严重的问题：战斗信号没有连接到UI

**问题**：`02_interface_contracts.md` 定义了`battle_started`/`action_executed`/`unit_damaged`/`battle_turn_started`等信号，但`06_ui_flow_design.md`的`battle.tscn`场景中**没有描述任何信号订阅**。

`battle.tscn` 的节点只有：
- RoundLabel（固定文本"回合: 1/20"）
- HeroRect/EnemyRect（ColorRect色块）
- HeroHpBar/EnemyHpBar（ProgressBar，固定value=100）
- BattleLog（RichTextLabel，固定文本"战斗日志..."）
- SpeedButton（"速度: 1x"）

**没有任何信号连接**。这意味着即使BattleEngine发射了所有信号，UI也不会响应。

**根因**：`06_ui_flow_design.md` 把 `battle.tscn` 当成一个**静态占位场景**设计，没有写动态数据绑定。但 `04_battle_engine_design.md` 却写了丰富的战斗信号——信号和UI之间没有桥梁。

---

## 三、画面表现（文档预期 vs 实际可玩性的鸿沟）

### 3.1 "占位美术"的定义不清

`06_ui_flow_design.md` 4节说"纯色块+文字占位"，但**没有量化最低可玩性标准**：

| 元素 | 文档描述 | 实际缺失的功能 |
|:---|:---|:---|
| 节点按钮 | "节点 1/2/3"固定文本 | **应该显示实际节点名称**（"锻炼体魄"、"普通战斗Lv3"） |
| 属性条 | ProgressBar（固定value=50） | **max_value应该动态设置**，否则属性涨到100+时条溢出 |
| HP显示 | "生命: 100/100" | **max_hp由体魄计算**，可能远高于100 |
| 伙伴槽位 | "伙伴1~5"固定文本 | **应该显示实际伙伴名称+等级** |

**根因**：文档把"占位"等同于"静态不变色块"，但可玩的最小集需要**动态数据绑定**。文档没有区分"美术占位"和"功能占位"——ColorRect可以占位，但Label文本必须动态刷新。

### 3.2 属性条最大值：文档完全没提

`06_ui_flow_design.md` 3.3节HUD设计描述了5个ProgressBar，但**没有写max_value怎么设置**。

- 如果固定max_value=100，属性涨到120时条溢出20%
- 如果max_value动态=当前最大值×1.2，可以容纳增长

**这个决策在7份文档中完全没有出现**。

---

## 四、属性相关（Schema有字段，但模块没说要读）

### 4.1 伙伴属性：Schema ↔ 模块职责的断裂

**`03_data_schema.md` partner_config 表**（已存在）：
```
partner_id, partner_name, role, favored_attr,
base_physique, base_strength, base_agility, base_technique, base_spirit,
assist_skill_id, support_skill_id, portrait_color
```

**`01_module_breakdown.md` CharacterManager职责**（未指定数据来源）：
> "负责主角和伙伴的属性计算（五维属性：体魄/力量/敏捷/技巧/精神）、等级提升..."

**断裂点**：Schema有字段，模块职责说"计算属性"，但**没有说"初始化时从partner_config读取base_physique等字段"**。Agent只能猜，结果猜成了硬编码10。

### 4.2 HP最大值计算：公式藏在DamageCalculator里

`04_battle_engine_design.md` 的DamageCalculator中定义了 `max_hp = physique × 10 + 50`，但：
- `06_ui_flow_design.md` 3.3节HUD的HP显示写的是"生命: 100/100"——固定值
- `05_run_loop_design.md` 中没有任何地方提到HP公式
- `01_module_breakdown.md` CharacterManager的职责描述中没有HP计算

**根因**：HP公式被埋在战斗引擎的技术细节里，没有在设计层面（模块职责/数据流）明确说明。

---

## 五、商店逻辑（交互链断裂）

### 5.1 商店节点的完整交互链：文档拼不起来

| 步骤 | 哪份文档写了 | 写了什么 | 缺了什么 |
|:---|:---|:---|:---|
| ① 玩家选择商店节点 | `05_run_loop_design.md` 1.4节 | "执行选中节点的逻辑（商店）" | **没说NodeResolver返回什么给UI** |
| ② UI弹出商店弹窗 | `06_ui_flow_design.md` 1.7节 | ShopPopup的UI结构 | **没说谁触发弹窗打开** |
| ③ 显示商品列表 | `02_interface_contracts.md` R13 | `shop_entered(inventory)`信号 | **信号发射方是谁？NodeResolver还是ShopSystem？** |
| ④ 玩家点击购买 | `06_ui_flow_design.md` 1.7节 | "点击BuyBtn → 发射`shop_purchase`" | **没说信号目标是谁** |
| ⑤ 扣除金币+升级 | `05_run_loop_design.md` 4.3节 | "扣除金币，属性即时生效" | **没说谁执行扣除和升级** |
| ⑥ 关闭弹窗推进回合 | `06_ui_flow_design.md` 1.7节 | "点击LeaveBtn → 关闭弹窗" | **没说谁调用advance_turn()** |

**根因**：5份文档各自写了商店的一个片段，但**没有一份文档画出完整的交互时序图**。结果是：
- `05_run_loop_design.md` 写了商店逻辑（商品价格/递增/购买后处理）
- `06_ui_flow_design.md` 写了商店UI（弹窗结构/按钮/信号）
- `02_interface_contracts.md` 写了商店信号（shop_entered/shop_purchased）
- `01_module_breakdown.md` 分配了职责（ShopSystem处理商店，RewardSystem处理奖励）

**但没人把这几块拼起来说明"点击BuyBtn后，数据流怎么走"**。

### 5.2 职责模糊：金币管理权归属不清

| 文档 | 谁管金币 |
|:---|:---|
| `01_module_breakdown.md` RunController | "管理局内玩家状态（含金币）" |
| `01_module_breakdown.md` RewardSystem | "处理...商品购买后的属性/物品/伙伴发放" |
| `01_module_breakdown.md` ShopSystem | "生成商品列表、处理购买" |
| `05_run_loop_design.md` 4.3节 | "扣除金币" |

**矛盾**：ShopSystem说"处理购买"，RewardSystem说"处理商品购买后的发放"，RunController说"管理金币"——**到底谁扣金币？** 文档没有明确。

代码实际：RunController有`_run.gold_owned`，ShopSystem有`process_purchase()`，但UI层没有连接到任何一个。

---

## 六、总结：文档问题的根因

| # | 问题领域 | 文档根因 | 影响 |
|:---:|:---|:---|:---|
| 1 | **UI↔Controller交互链** | 文档把状态机和UI当成独立系统描述，没有画交互时序图 | 节点按钮无反应 |
| 2 | **伙伴属性初始化** | Schema有字段，但模块职责没指定读取来源 | 伙伴全=10 |
| 3 | **战斗画面** | `04_battle_engine_design.md`(headless)和`06_ui_flow_design.md`(有场景)矛盾 | 有场景但无画面 |
| 4 | **属性条/HUD** | "占位"定义不清，没区分"美术占位"和"功能占位" | 条溢出、文本固定 |
| 5 | **商店交互链** | 5份文档各写片段，没人拼完整数据流 | 商店无法交互 |
| 6 | **金币管理权** | 3个模块都说管金币，职责边界模糊 | 购买调用链断裂 |

---

## 七、建议

**这不是代码Agent的锅**——代码Agent是按文档实现的，文档缺什么它就猜什么。问题是文档本身：

1. **缺少交互时序图**：UI层→功能层→数据层的完整调用链需要在单份文档中画出
2. **模块职责边界模糊**：特别是金币管理、属性初始化、信号发射方归属
3. **"占位"标准未量化**：需要区分"美术占位"（ColorRect）和"功能占位"（动态文本必须刷新）
4. **跨文档一致性检查缺失**：`04`(战斗引擎)和`06`(UI流程)对战斗画面的定义矛盾

**修复优先级**：
- 🔴 P0：补画UI↔Controller交互时序图（影响游戏可玩性）
- 🟡 P1：明确CharacterManager初始化数据来源、明确金币管理权
- 🟢 P2：统一战斗画面定义（headless vs 有画面）

---

*报告人：本地审核 Agent*  
*状态：建议先修文档，再按修后的文档修代码*
