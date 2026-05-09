# 补充文档：商店交互完整链路

> 补充日期：2026-05-09
> 补充到：05_run_loop_design.md 4节 / 06_ui_flow_design.md 1.7节 / 01_module_breakdown.md
> 目的：明确商店节点从"玩家选择"到"回合推进"的完整数据流

---

## 一、现状问题

**5份文档各自写了商店的一个片段，但没人拼出完整链路**：

| 文档 | 写了什么 | 缺了什么 |
|:---|:---|:---|
| `05_run_loop_design.md` 4节 | 商店商品价格公式、购买后属性计算 | UI层如何触发购买 |
| `06_ui_flow_design.md` 1.7节 | ShopPopup的UI结构、按钮布局 | 弹窗谁打开、购买后谁执行 |
| `02_interface_contracts.md` R13-R14 | `shop_entered`/`shop_purchased`信号 | 信号发射方/接收方的调用链 |
| `01_module_breakdown.md` | ShopSystem"生成商品列表、处理购买" | 和RunController的金币管理权边界 |
| `01_module_breakdown.md` | RewardSystem"处理商品购买后的发放" | 和ShopSystem的职责分界线 |

**导致的问题**：
- RunController处理商店节点时，只返回了商品列表，没有触发UI弹窗
- UI层有ShopPopup场景但不知道谁打开它
- 点击"购买"后不知道调用谁扣金币
- 点击"离开"后不知道谁推进回合

---

## 二、完整交互时序图（商店节点）

```
[RunMain]            [RunController]      [NodeResolver]       [ShopSystem]        [RunMain Popup]
    │                      │                    │                    │                   │
    │  _on_node_button_pressed(index=2, SHOP)   │                    │                   │
    │─────────────────────▶│                    │                    │                   │
    │                      │ select_node(2)     │                    │                   │
    │                      │───────────────────▶│                    │                   │
    │                      │                    │ resolve_node("SHOP")│                   │
    │                      │                    │────────────────────▶│                   │
    │                      │                    │                    │ generate_shop_inventory()
    │                      │                    │                    │ 返回 Array[商品]
    │                      │◀─────────────────│                    │                   │
    │                      │ _process_node_result({
    │                      │   success: true,
    │                      │   rewards: [{
    │                      │     type: "shop_inventory",
    │                      │     data: inventory_array
    │                      │   }]
    │                      │ })
    │                      │                    │                    │                   │
    │                      │ 不自动advance_turn  │                    │                   │
    │                      │ （商店需要玩家交互）  │                    │                   │
    │                      │                    │                    │                   │
    │◀─────────────────────│ emit shop_entered(inventory)         │                   │
    │ _on_shop_entered(inventory)              │                    │                   │
    │ _show_shop_popup(inventory)              │                    │                   │
    │──────────────────────────────────────────────────────────────────────────────────▶│
    │                      │                    │                    │                   │
    │                      │                    │                    │                   │ 显示商品列表
    │                      │                    │                    │                   │
    │  ╔═══════════════════════════════════════════════════════════════════════════════╗
    │  ║ 玩家点击"购买主角力量强化"                                                     ║
    │  ╚═══════════════════════════════════════════════════════════════════════════════╝
    │                      │                    │                    │                   │
    │ _on_shop_purchase_requested(item_index=0) │                    │                   │
    │─────────────────────▶│ purchase_shop_item(index)            │                   │
    │                      │─────────────────────────────────────▶│                   │
    │                      │                    │                    │                   │
    │                      │                    │                    │ process_purchase()
    │                      │                    │                    │ 1. 检查金币
    │                      │                    │                    │ 2. 扣除金币（修改_run.gold_owned）
    │                      │                    │                    │ 3. 应用效果（CharacterManager修改属性）
    │                      │                    │                    │ 4. 记录购买次数
    │                      │                    │                    │ 5. 返回 {success, new_gold, applied_effects}
    │                      │◀──────────────────────────────────────────────────────────│
    │                      │                    │                    │                   │
    │                      │ emit gold_changed   │                    │                   │
    │                      │ emit stats_changed  │                    │                   │
    │                      │                    │                    │                   │
    │◀─────────────────────│                    │                    │                   │
    │ _update_hud()        │                    │                    │                   │
    │ 刷新金币和属性显示    │                    │                    │                   │
    │                      │                    │                    │                   │
    │  ╔═══════════════════════════════════════════════════════════════════════════════╗
    │  ║ 玩家继续购买其他商品...（循环上述购买流程）                                     ║
    │  ╚═══════════════════════════════════════════════════════════════════════════════╝
    │                      │                    │                    │                   │
    │  ╔═══════════════════════════════════════════════════════════════════════════════╗
    │  ║ 玩家点击"离开商店"                                                             ║
    │  ╚═══════════════════════════════════════════════════════════════════════════════╝
    │                      │                    │                    │                   │
    │ _on_shop_leave_requested()               │                    │                   │
    │ 关闭弹窗             │                    │                    │                   │
    │─────────────────────▶│ advance_turn()     │                    │                   │
    │                      │ turn++ → NODE_SELECT│                    │                   │
    │                      │ _generate_node_options()               │                   │
    │                      │ emit node_options_presented            │                   │
    │                      │                    │                    │                   │
    │◀─────────────────────│                    │                    │                   │
    │ _on_node_options_presented                │                    │                   │
    │ 刷新下一回合按钮      │                    │                    │                   │
```

---

## 三、关键修正点

### 3.1 NodeResolver.resolve_node("SHOP") 的行为修正

**现有问题**：NodeResolver.resolve_node() 在商店节点时只返回了商品列表，但**没有暂停回合推进**——商店需要玩家交互，不能自动执行完就 advance_turn。

**修正后行为**：

```gdscript
# NodeResolver.gd
func resolve_node(node_config: Dictionary) -> Dictionary:
    var node_type: int = node_config.get("node_type", 0)
    
    match node_type:
        1: # TRAINING — 即时结算，自动完成
            return _training_system.execute_training(...)
        
        2: # BATTLE — 即时结算（headless），自动完成
            return _battle_engine.execute_battle(...)
        
        3: # ELITE — 同上
            return _elite_battle_system.execute(...)
        
        4: # SHOP — **需要玩家交互，返回库存后不自动完成**
            var inventory: Array = _shop_system.generate_shop_inventory(...)
            return {
                "success": true,
                "requires_ui_interaction": true,  # **新增标记**
                "rewards": [{
                    "type": "shop_inventory",
                    "data": inventory,
                }]
            }
        
        5: # RESCUE — 同理，需要玩家3选1
            return {
                "success": true,
                "requires_ui_interaction": true,
                "rewards": [{
                    "type": "rescue_candidates",
                    "data": candidates,
                }]
            }
        
        6: # PVP — 即时结算（headless战斗），自动完成
            return _pvp_director.execute_pvp(...)
        
        7: # FINAL — 即时结算，自动完成
            return _final_battle_system.execute(...)
```

### 3.2 RunController._process_node_result() 修正

```gdscript
# RunController.gd
func _process_node_result(result: Dictionary) -> void:
    # 处理奖励
    for reward in result.get("rewards", []):
        _process_reward(reward)
    
    # **新增：检查是否需要UI交互**
    if result.get("requires_ui_interaction", false):
        # 暂停回合推进，等待UI层交互完成
        # UI层交互完毕后，由UI层调用 advance_turn()
        _waiting_for_ui = true
        return
    
    # 不需要UI交互的节点（战斗/锻炼/PVP），直接推进
    _advance_to_next_turn()

# 新增：由UI层调用的接口
func advance_turn_after_ui_interaction() -> void:
    if _waiting_for_ui:
        _waiting_for_ui = false
        _advance_to_next_turn()
```

### 3.3 RunMain 中的 advance_turn 调用权

**修正前**：`_on_node_resolved()` 中无条件调用 `_run_controller.advance_turn()`
**修正后**：只在不需要UI交互的节点类型时自动调用，商店/救援节点由UI层交互完成后调用

```gdscript
# RunMain.gd
func _on_node_resolved(node_type: String, result_data: Dictionary) -> void:
    var ntype: int = result_data.get("node_type_int", 0)
    
    match ntype:
        1, 2, 3, 6, 7:  # TRAIN, BATTLE, ELITE, PVP, FINAL
            # 自动完成，直接推进回合
            _run_controller.advance_turn()
        
        4: # SHOP
            # 显示弹窗，等待交互
            _show_shop_popup(result_data.get("shop_inventory", []))
            # 不调用 advance_turn——等玩家离开弹窗后再调用
        
        5: # RESCUE
            _show_rescue_popup(result_data.get("candidates", []))
            # 同上，不自动推进

func _on_shop_leave_requested() -> void:
    _shop_popup.queue_free()
    _run_controller.advance_turn_after_ui_interaction()

func _on_rescue_partner_selected(partner_id: int) -> void:
    _run_controller.select_rescue_partner(partner_id)
    _rescue_popup.queue_free()
    _run_controller.advance_turn_after_ui_interaction()
```

---

## 四、金币管理权明确

### 4.1 职责边界

| 模块 | 金币相关职责 | 禁止做的事 |
|:---|:---|:---|
| **RunController** | 持有 `_run.gold_owned`，是金币的"主人" | 不直接执行购买逻辑（交给ShopSystem） |
| **ShopSystem** | 计算价格、检查金币、执行扣除 | 不直接修改 `_run.gold_owned`，通过返回值通知RunController修改 |
| **RewardSystem** | 处理战斗奖励金币（增加） | 不处理商店购买（ShopSystem已覆盖） |
| **RunMain (UI)** | 显示金币数值、禁用/启用购买按钮 | 不修改金币数值（只读） |

### 4.2 购买流程中的金币流转

```
1. RunController调用 ShopSystem.generate_shop_inventory(turn, _run.gold_owned)
   → ShopSystem 用 current_gold 计算 can_afford

2. UI显示商品，金币不足的按钮 disabled

3. 玩家点击购买 → RunController.purchase_shop_item(index)
   → RunController 从当前库存中找到 item_data
   → RunController 调用 ShopSystem.process_purchase(item_data, _run.gold_owned)

4. ShopSystem.process_purchase():
   a. 检查金币：if current_gold < price → return {success: false, error: "金币不足"}
   b. 扣除金币：new_gold = current_gold - price（不修改_run，只计算）
   c. 应用效果：调用 CharacterManager 修改属性/伙伴等级
   d. 返回：{success: true, new_gold: new_gold, applied_effects: [...]}

5. RunController 收到结果后：
   _run.gold_owned = result.new_gold
   emit gold_changed(_run.gold_owned, -price, "shop_purchase")
   emit stats_changed(...)  // 如果有属性变化

6. UI收到 gold_changed → 刷新HUD金币显示
```

---

## 五、现有代码的适配修改清单

需要修改的文件和具体位置：

| # | 文件 | 修改内容 | 行号（参考） |
|:---:|:---|:---|:---|
| 1 | `autoload/event_bus.gd` | 新增 `hp_changed` 信号（如果缺失） | 新增 |
| 2 | `scripts/systems/node_resolver.gd` | `resolve_node()` 商店/救援节点返回 `requires_ui_interaction: true` | `resolve_node()` 内 |
| 3 | `scripts/systems/run_controller.gd` | `_process_node_result()` 新增 `requires_ui_interaction` 检查；新增 `advance_turn_after_ui_interaction()` 接口 | `_process_node_result()` 末尾 |
| 4 | `scripts/systems/shop_system.gd` | `process_purchase()` 不直接修改 `_run.gold_owned`，返回 `new_gold` | `process_purchase()` |
| 5 | `scenes/run_main/run_main.gd` | 重写 `_on_node_resolved()` 区分自动完成节点和需要UI交互节点 | 新增/重写 |
| 6 | `scenes/run_main/run_main.gd` | 新增 `_show_shop_popup()` / `_on_shop_purchase_requested()` / `_on_shop_leave_requested()` | 新增 |
| 7 | `scenes/run_main/run_main.gd` | 新增 `_show_rescue_popup()` / `_on_rescue_partner_selected()` | 新增 |
| 8 | `scenes/shop/shop_popup.gd` | 新增 `purchase_requested` / `leave_requested` 自定义信号 | 新增 |
| 9 | `scenes/rescue/rescue_popup.gd` | 新增 `partner_selected` 自定义信号 | 新增 |

---

## 六、跨文档修正对照

| 本文档内容 | 应补充到哪份文档 | 补充位置 |
|:---|:---|:---|
| 二、完整交互时序图 | `05_run_loop_design.md` | 4.4节新增"商店交互时序图" |
| 3.1 NodeResolver `requires_ui_interaction` | `05_run_loop_design.md` | 4.1节"商店节点" |
| 3.2 RunController `_advance_to_next_turn()` | `05_run_loop_design.md` | 1.3节"RUNNING子状态机"（扩展状态转移条件） |
| 3.3 RunMain advance_turn 调用权 | `06_ui_flow_design.md` | 1.4节"RunMain核心场景"（新增交互规范） |
| 四、金币管理权 | `01_module_breakdown.md` | ShopSystem / RewardSystem / RunController 职责描述 |
| 五、适配修改清单 | `07_technical_spec.md` | 新增"商店交互实现检查清单" |

---

*补充文档版本：v1.0*
*日期：2026-05-09*
