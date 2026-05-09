# Phase 2 逻辑问题排查报告

> 排查日期：2026-05-09
> 排查范围：D:\Hero Battle 全部代码
> 触发条件：手动测试 → 选择人物和伙伴 → 进入游戏 → 节点按钮点击无反应

---

## 一、节点按钮点击无反应（直接原因）

**根因**：RunMain UI 和 RunController 之间的**连接链完全缺失**。

| 缺失点 | 具体表现 | 位置 |
|:---:|:---|:---|
| ① `_on_node_button_pressed` 是空函数 | 点击按钮后执行 `pass`，无任何动作 | `run_main.gd:41` |
| ② RunMain 未订阅 `node_options_presented` | 按钮不会刷新节点选项文本，永远显示"节点 1/2/3" | `run_main.gd` |
| ③ EventBus 缺少 `node_selected` 信号 | RunController 的 `select_node()` 里发射了不存在的信号，运行时可能报错 | `event_bus.gd` |
| ④ GameManager 未传递选择数据 | `_on_team_confirmed` 只切换场景，没有把 hero_id/partner_ids 传给 RunMain | `game_manager.gd` |
| ⑤ RunMain 未创建 RunController | 场景中没有 RunController 实例，UI 无法调用养成循环 | `run_main.tscn` |

**这5个缺失点是 Phase 1 就存在的架构缺口**，test_full_run 测试是通过代码直接操控 RunController 绕过了 UI 层，所以之前没暴露。

---

## 二、用户提出的5个深层逻辑问题

### 问题1：每回合选项 + 伙伴相关逻辑

**现状核查**：

| 子项 | 状态 | 具体问题 |
|:---:|:---:|:---|
| 节点生成 | ✅ 逻辑存在 | `_generate_node_options()` 按规则生成：救援(3伙伴)/PVP(1)/终局(1)/普通(3随机) |
| 节点池权重 | ✅ 有权重配置 | 前期训练30%/战斗40%/精英5%/商店20%，中晚期逐步增加精英 |
| 保底机制 | ✅ 已实现 | 连续3回合无战斗 → 强制第1个选项为战斗 |
| 锻炼系统 | ✅ 完整 | 基础+5，熟练度加成，边际递减（超60%占比-20%），副属性50%共享 |
| **伙伴属性初始化** | ❌ **占位值** | `initialize_partners()` 中伙伴五维全部硬编码为 **10**，没有从 `partner_configs.json` 读取 |
| **伙伴在HUD显示** | ⚠️ 有占位 | `PartnerContainer` 有5个 ColorRect，但只显示"伙伴1~5"固定文本，没有动态刷新 |
| 伙伴援助（战斗内） | ✅ 已实现 | `PartnerAssist.execute_assist()` 完整，但战斗是 headless，用户看不到 |
| 救援选择后入队 | ✅ 已实现 | `add_partner()` 将伙伴加入队伍，最多5人 |

**建议修复**：
1. `CharacterManager.initialize_partners()` 改为从 `partner_configs.json` 读取 `base_physique`/`base_strength` 等字段
2. RunMain 订阅 `partner_unlocked` 信号，动态刷新伙伴槽位显示（名称+等级）

---

### 问题2：目前没有战斗画面

**现状**：

| 战斗类型 | 处理方式 | 用户可见性 |
|:---:|:---|:---:|
| 普通战斗 | NodeResolver 直接给金币奖励，无 BattleEngine | ❌ 无任何画面 |
| 精英战 | 调用 `EliteBattleSystem.execute_elite_battle()` → 内部调用 BattleEngine | ❌ headless，只有结果 |
| PVP | 调用 `PvpDirector.execute_pvp()` → 内部调用 BattleEngine | ❌ headless，只有结果 |
| 终局战 | 调用 `RunController._run_battle_engine()` → BattleEngine | ❌ headless，只有结果 |

**关键代码**（`battle_engine.gd:72`）：
```gdscript
# NOTE: 当前为同步执行模式（单帧内完成），适用于 headless 测试与后端推演。
# 未来如需 UI 帧同步回放，可在此恢复 await get_tree().process_frame。
```

**结论**：这是**设计意图**——Phase 1/2 明确只做 headless 战斗。`battle.tscn` 存在但只是一个**静态占位场景**，没有和 BattleEngine 连接。

**如果要战斗画面，需要**：
1. 将 BattleEngine 改为**帧同步模式**（每回合/每动作间 `await get_tree().process_frame`）
2. BattleEngine 发射细粒度信号：`unit_damaged` / `action_executed` / `chain_triggered` 等
3. Battle 场景订阅这些信号，播放动画/伤害数字/血条变化
4. 工作量：**Phase 4 级别**（需要美术+动画+特效）

---

### 问题3：画面表现

**现状清单**（全部占位）：

| 元素 | 当前实现 | 期望 |
|:---:|:---|:---|
| 主角头像 | ColorRect 色块 | 实际角色立绘/头像 |
| 伙伴头像 | ColorRect 色块 + "伙伴1~5"固定文本 | 实际伙伴头像+名称+等级 |
| 敌人形象 | ColorRect 色块 | 实际敌人Sprite |
| 属性条 | ProgressBar（固定最大值） | 动态最大值+属性名称标签 |
| 伤害数字 | 无 | 弹出伤害数字（红/黄暴击/灰闪避） |
| 血条变化 | 直接赋值 | 平滑动画过渡 |
| 连锁提示 | 无 | 连锁触发时屏幕特效+音效 |
| 必杀技 | 无 | 大招动画+特写 |
| 按钮交互 | 无悬停/选中效果 | 正常按钮状态变化 |

**注意**：Phase 1/2 任务卡明确写了 **"不做动画/音效/特效（Phase 4）"**，这些占位是预期的。但如果现在就要 playable 的体验，至少需要：
- HUD 中的伙伴名称和等级动态显示
- 属性条最大值动态计算（否则属性涨到100+时条会溢出）
- 按钮文本显示实际节点名称（"锻炼体魄"而不是"节点 1"）

---

### 问题4：属性相关

**具体问题**：

| # | 问题 | 位置 | 影响 |
|:---:|:---|:---|:---|
| 1 | 伙伴属性全是硬编码10 | `character_manager.gd:81-85` | 伙伴在战斗中无差异化（全部同属性） |
| 2 | HUD 属性条最大值固定 | `run_main.gd:30` | 属性超过100时 ProgressBar 溢出 |
| 3 | 属性条不显示属性名 | `run_main.tscn` | 只有"体魄/力量/敏捷/技巧/精神"固定标签，不随主角变化 |
| 4 | `stats_changed` 只更新 value | `run_main.gd:46-59` | ProgressBar 的 max_value 不会动态调整 |
| 5 | HP 显示固定最大值100 | `run_main.gd:56` | 实际 MaxHP 由体魄计算，可能远高于100 |

**建议修复（最小集）**：
1. `run_main.gd` 的 `_update_hud()` 中，从 `GameManager` 或 `RunController` 获取实际 hero 数据，动态设置 ProgressBar.max_value
2. `CharacterManager.initialize_partners()` 读取 `partner_configs.json` 中的 `base_physique` 等字段
3. `_on_stats_changed` 中同时更新 ProgressBar 的 max_value（如果属性值超过当前 max）

---

### 问题5：商店逻辑

**现状**：

| 子项 | 状态 | 说明 |
|:---:|:---:|:---|
| 商品类型 | ✅ 2种 | 主角属性升级（+3）/ 伙伴升级（Lv+1，最多3级） |
| 价格递增 | ✅ 已实现 | 每次购买后价格上升 |
| 金币校验 | ✅ 已实现 | `can_afford` 根据当前金币计算 |
| **商店UI** | ❌ **缺失** | RunMain 没有处理商店节点的购买交互 |
| **购买后反馈** | ⚠️ 部分缺失 | `process_purchase` 返回结果，但 UI 没有显示"购买成功"提示 |
| 商品数量 | ⚠️ 偏少 | 只有升级选项，没有消耗品/道具/装备（装备已确认不在设计范围内） |

**商店节点交互流程缺失**：

```
当前流程：
1. 玩家选择"商店"节点
2. NodeResolver.resolve_node() → 返回商品列表
3. RunController._process_node_result() → 把商品列表存到 reward
4. ❌ UI 层没有弹出商店界面让玩家选择购买
5. ❌ 没有调用 purchase_shop_item()
```

对比设计文档 `05_run_loop_design.md` 中 5.2 节"商店节点"：
> "玩家进入商店界面，看到当前可购买的商品列表（主角属性强化 / 伙伴升级），选择购买后扣除金币，属性即时生效。"

**结论**：商店 UI 交互链没有实现。需要：
1. RunMain 检测到商店节点 → 弹出商店弹窗（`shop_popup.tscn` 已存在但可能未连接）
2. 玩家点击购买 → 调用 `RunController.purchase_shop_item()`
3. 购买后刷新 HUD 金币和属性

---

## 三、问题汇总与优先级

| 优先级 | 问题 | 影响 | 工作量 |
|:---:|:---|:---:|:---:|
| 🔴 **P0** | 节点按钮点击无反应 | **游戏无法进行** | 半天（修5个连接点） |
| 🔴 **P0** | 商店节点无购买交互 | **商店功能不可用** | 半天（连接 shop_popup） |
| 🟡 **P1** | 伙伴属性全=10（硬编码） | 伙伴无差异化 | 1小时（读JSON配置） |
| 🟡 **P1** | HUD 属性条最大值固定 | 属性溢出、HP显示错误 | 1小时（动态计算max_value） |
| 🟡 **P1** | 伙伴名称/等级不刷新 | 伙伴槽位信息错误 | 1小时（订阅partner_unlocked） |
| 🟢 **P2** | 按钮显示"节点1/2/3"而非实际名称 | 玩家不知道选什么 | 1小时（订阅node_options_presented刷新文本） |
| 🔵 **P3** | 没有战斗画面 | 体验差，但功能正确 | **Phase 4**（帧同步+动画+美术） |
| 🔵 **P3** | 全部ColorRect占位 | 视觉差 | **Phase 4**（美术资源） |

---

## 四、建议修复方案

### 立即修复（P0-P1，1天工作量）

修复 **5个连接点 + 2个数据问题 + 1个UI问题**：

1. **EventBus** — 新增 `node_selected(index: int)` 信号
2. **GameManager** — 保存 `selected_hero_config_id` / `selected_partner_config_ids`，`_on_team_confirmed` 时写入
3. **run_main.tscn** — 添加 RunController 子节点（或代码中 `RunController.new()`）
4. **run_main.gd** — 完整重写 `_ready()` 和 `_on_node_button_pressed()`：
   - 创建/获取 RunController
   - 从 GameManager 读取选择 → `start_new_run()`
   - 订阅 `node_options_presented` → 刷新按钮文本
   - `_on_node_button_pressed` → `run_controller.select_node(index)` → `advance_turn()`
   - 订阅 `partner_unlocked` → 刷新伙伴槽位
5. **CharacterManager** — `initialize_partners()` 从 JSON 读取属性
6. **RunMain HUD** — 动态设置 ProgressBar.max_value
7. **商店交互** — RunMain 检测到商店节点 → 显示商品列表 → 购买后调用 `purchase_shop_item()`

### 延后处理（P3）

- 战斗画面 → Phase 4
- 美术占位替换 → Phase 4
- 伤害数字/连锁特效 → Phase 4

---

*报告人：本地审核 Agent*  
*状态：建议立即修复 P0-P1 问题后再做总体测试*
