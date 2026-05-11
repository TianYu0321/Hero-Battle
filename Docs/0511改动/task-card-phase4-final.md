# Phase 4 任务卡（终版）：清理残留 + 商店UI + 战斗可视化

> 用户确认：商店仅卖伙伴等级（无属性强化）。v1.0残留必须全部删除。

---

## Part A：删除 v1.0 残留（3个文件）

### A1. `scripts/systems/shop_system.gd`

**删除**主角属性强化商品生成逻辑：

```gdscript
# 删除这一段（第20~34行左右）：
# 主角升级选项（5属性各一个）
for attr in range(1, 6):
    var item_id: String = "hero_attr_%d" % attr
    ...
```

只保留伙伴升级部分：

```gdscript
func generate_shop_inventory(turn: int, current_gold: int) -> Array[Dictionary]:
    var inventory: Array[Dictionary] = []
    var partners: Array[RuntimePartner] = _character_manager.get_partners()
    
    var shown: int = 0
    for p in partners:
        if not p.is_active or shown >= 3:
            continue
        var item_id: String = "partner_%d" % p.partner_config_id
        var base_cost: int = _get_item_base_cost(item_id)
        var cost: int = _calculate_current_cost(item_id, base_cost)
        var config: Dictionary = ConfigManager.get_partner_config(str(p.partner_config_id))
        var p_name: String = config.get("name", "伙伴")
        var max_level_reached: bool = p.current_level >= 5
        inventory.append({
            "item_id": item_id,
            "item_type": "partner_upgrade",
            "name": p_name + "升级",
            "price": cost if not max_level_reached else 999999,
            "current_level": p.current_level,
            "effect_desc": "等级%d→%d" % [p.current_level, mini(5, p.current_level + 1)] if not max_level_reached else "已达最高等级",
            "can_afford": current_gold >= cost and not max_level_reached,
            "target_id": str(p.partner_config_id),
        })
        shown += 1
    
    return inventory
```

**删除** `process_purchase()` 中的 `hero_upgrade` 分支：

```gdscript
# 删除这一段：
# "hero_upgrade":
#     var attr: int = item_data.get("target_attr", 0)
#     if attr >= 1 and attr <= 5:
#         _character_manager.modify_hero_stats({attr: 3})
```

**删除** `_get_item_base_cost()` 中的 hero_attr 相关逻辑：

```gdscript
func _get_item_base_cost(item_id: String) -> int:
    var shop_cfg: Dictionary = ConfigManager.get_shop_price_config()
    for k in shop_cfg:
        var item: Dictionary = shop_cfg[k]
        if str(item.get("id", "")) == item_id:
            return item.get("cost_base", 30)
    # 只剩伙伴升级
    if item_id.begins_with("partner_"):
        return 30
    return 30
```

### A2. `scripts/systems/run_controller.gd`

**删除** `_process_reward()` 中的两个分支：

```gdscript
# 删除 "level_up" 分支：
"level_up":
    var attr: int = randi() % 5 + 1
    if _character_manager != null:
        _character_manager.modify_hero_stats({attr: 1})

# 删除 "train_lv5" 分支：
"train_lv5":
    var attr: int = reward.get("attr", -1)
    if attr < 1 or attr > 5:
        attr = randi() % 5 + 1
    if _character_manager != null:
        _character_manager.modify_hero_stats({attr: 5})
```

**修改** 战斗胜利后金币奖励，从敌人配置读取（不是硬编码）：

```gdscript
# 找到这一段（在 _process_node_result 的 requires_battle 分支中）
# 旧代码：
# var gold_reward: int = randi() % 20 + 10

# 新代码：
var enemy_cfg: Dictionary = ConfigManager.get_enemy_config(str(enemy_config_id))
var gold_reward: int = enemy_cfg.get("reward_gold_min", 20)
if enemy_cfg.has("reward_gold_max"):
    var gold_max: int = enemy_cfg.get("reward_gold_max", gold_reward)
    gold_reward = randi() % (gold_max - gold_reward + 1) + gold_reward
```

**修改** `select_rescue_partner()` 中的商店调用，传入真实金币：

```gdscript
# 旧代码：
# shop_items = shop_system.generate_items(_run.current_turn)

# 新代码：
shop_items = shop_system.generate_shop_inventory(_run.current_turn, _run.gold_owned)
```

### A3. `scenes/run_main/run_main.gd`

**删除** `_on_panel_opened` 中对 hero_upgrade 商品的任何引用（当前代码里没有，确认一下即可）。

---

## Part B：商店UI渲染

### B1. 新建 `scenes/run_main/shop_item_button.tscn`

```
ShopItemButton (Button)
├── IconTexture (TextureRect)      # 伙伴LVUP图标占位
├── InfoContainer (VBoxContainer)
│   ├── NameLabel (Label)            # "剑士升级"
│   └── LevelLabel (Label)           # "LV2 → LV3"
└── PriceLabel (Label)               # "30金币"
```

### B2. 新建 `scenes/run_main/shop_item_button.gd`

```gdscript
class_name ShopItemButton
extends Button

@onready var name_label: Label = $InfoContainer/NameLabel
@onready var level_label: Label = $InfoContainer/LevelLabel
@onready var price_label: Label = $PriceLabel

var item_data: Dictionary = {}
var is_sold_out: bool = false

func setup(item: Dictionary) -> void:
    item_data = item
    var item_type = item.get("item_type", "")
    
    match item_type:
        "partner_upgrade":
            name_label.text = item.get("name", "???")
            var current_lv = item.get("current_level", 1)
            var next_lv = mini(5, current_lv + 1)
            level_label.text = "LV%d → LV%d" % [current_lv, next_lv]
    
    price_label.text = "%d金币" % item.get("price", 0)
    
    var can_afford = item.get("can_afford", true)
    disabled = not can_afford
    if not can_afford:
        modulate = Color(0.5, 0.5, 0.5)

func mark_sold_out() -> void:
    is_sold_out = true
    disabled = true
    name_label.text += " (已售出)"
    modulate = Color(0.3, 0.3, 0.3)
```

### B3. 修改 `scenes/run_main/run_main.tscn`

在 ShopPanel 下添加：
```
ShopPanel (Panel)
├── TitleLabel (Label)              # "商店"
├── ShopItemContainer (VBoxContainer)   # **新增**
├── GoldDisplayLabel (Label)        # **新增**："持有金币: 0"
└── CloseButton (Button)            # 已有
```

### B4. 修改 `scenes/run_main/run_main.gd`

在 @onready 区域添加：
```gdscript
@onready var shop_item_container: VBoxContainer = $ShopPanel/ShopItemContainer
@onready var shop_gold_label: Label = $ShopPanel/GoldDisplayLabel
var _shop_item_buttons: Array[ShopItemButton] = []
```

修改 `_on_panel_opened` 中的 SHOP_PANEL 分支：
```gdscript
"SHOP_PANEL":
    _transition_ui_state(UISceneState.SHOP_BROWSE)
    _show_shop_panel(panel_data.get("items", []))
```

新增 `_show_shop_panel`：
```gdscript
func _show_shop_panel(items: Array[Dictionary]) -> void:
    # 清空旧按钮
    for btn in _shop_item_buttons:
        btn.queue_free()
    _shop_item_buttons.clear()
    
    # 刷新金币显示
    var summary = _run_controller.get_current_run_summary()
    var gold = summary.get("gold", 0)
    shop_gold_label.text = "持有金币: %d" % gold
    
    # 只生成伙伴升级按钮
    for item in items:
        if item.get("item_type", "") != "partner_upgrade":
            continue
        var btn = preload("res://scenes/run_main/shop_item_button.tscn").instantiate()
        btn.setup(item)
        btn.pressed.connect(_on_shop_item_purchased.bind(item))
        shop_item_container.add_child(btn)
        _shop_item_buttons.append(btn)
    
    if _shop_item_buttons.is_empty():
        var label = Label.new()
        label.text = "暂无可升级伙伴"
        shop_item_container.add_child(label)
```

新增 `_on_shop_item_purchased`：
```gdscript
func _on_shop_item_purchased(item_data: Dictionary) -> void:
    print("[RunMain] 购买商品: %s" % item_data.get("name", "???"))
    if _run_controller == null:
        return
    
    var result = _run_controller.purchase_shop_item(item_data)
    if result.get("success", false):
        var new_gold = result.get("new_gold", 0)
        shop_gold_label.text = "持有金币: %d" % new_gold
        gold_label.text = "金币: %d" % new_gold
        
        # 标记已售出
        for btn in _shop_item_buttons:
            if btn.item_data.get("item_id", "") == item_data.get("item_id", ""):
                btn.mark_sold_out()
                break
        
        # 刷新其他按钮可购买状态
        _refresh_shop_buttons_affordability(new_gold)
    else:
        print("[RunMain] 购买失败: %s" % result.get("error", "???"))

func _refresh_shop_buttons_affordability(current_gold: int) -> void:
    for btn in _shop_item_buttons:
        if btn.is_sold_out:
            continue
        var price = btn.item_data.get("price", 0)
        btn.disabled = current_gold < price
        btn.modulate = Color(0.5, 0.5, 0.5) if current_gold < price else Color(1, 1, 1)
```

---

## Part C：战斗可视化（解耦独立模块）

### 设计原则
- `BattleEngine.gd` **零修改**，保持同步执行
- 新增 `BattleSummaryPanel` 独立场景，只订阅 `battle_ended` 信号
- 以后做动画回放，只需替换面板场景，不改主干

### C1. 新建 `scenes/run_main/battle_summary_panel.tscn`

```
BattleSummaryPanel (Panel)
├── TitleLabel (Label)              # "战斗结果"
├── ResultLabel (Label)             # "胜利！" / "败北..."
├── DetailContainer (VBoxContainer)
│   ├── EnemyNameLabel (Label)      # "敌人: 第5层怪物"
│   ├── RoundsLabel (Label)         # "经过8回合"
│   ├── HpLossLabel (Label)         # "损失生命: 32/100"
│   ├── GoldLabel (Label)           # "获得金币: 25"
│   └── ChainLabel (Label)          # "连锁触发: x3"
└── ConfirmButton (Button)          # "确定"
```

### C2. 新建 `scenes/run_main/battle_summary_panel.gd`

```gdscript
class_name BattleSummaryPanel
extends Panel

@onready var result_label: Label = $ResultLabel
@onready var enemy_name_label: Label = $DetailContainer/EnemyNameLabel
@onready var rounds_label: Label = $DetailContainer/RoundsLabel
@onready var hp_loss_label: Label = $DetailContainer/HpLossLabel
@onready var gold_label: Label = $DetailContainer/GoldLabel
@onready var chain_label: Label = $DetailContainer/ChainLabel
@onready var confirm_button: Button = $ConfirmButton

signal confirmed

func show_result(battle_result: Dictionary) -> void:
    visible = true
    
    var winner = battle_result.get("winner", "")
    var is_victory = winner == "player"
    
    result_label.text = "胜利！" if is_victory else "败北..."
    result_label.modulate = Color(0, 1, 0) if is_victory else Color(1, 0, 0)
    
    var enemies = battle_result.get("enemies", [])
    var enemy_name = "???"
    if enemies.size() > 0:
        enemy_name = enemies[0].get("name", "???")
    enemy_name_label.text = "敌人: %s" % enemy_name
    
    var turns = battle_result.get("turns_elapsed", 0)
    rounds_label.text = "经过%d回合" % turns
    
    var hero_remaining_hp = battle_result.get("hero_remaining_hp", 0)
    var hero_max_hp = battle_result.get("hero_max_hp", 100)
    var hp_loss = hero_max_hp - hero_remaining_hp
    hp_loss_label.text = "损失生命: %d/%d" % [hp_loss, hero_max_hp]
    
    var gold_reward = battle_result.get("gold_reward", 0)
    gold_label.text = "获得金币: %d" % gold_reward
    
    var chain_count = battle_result.get("max_chain_count", 0)
    chain_label.text = "连锁触发: x%d" % chain_count
    
    confirm_button.pressed.connect(_on_confirmed, CONNECT_ONE_SHOT)

func _on_confirmed() -> void:
    visible = false
    confirmed.emit()
```

### C3. 修改 `scenes/run_main/run_main.tscn`

添加 BattleSummaryPanel 实例：
```
RunMain
├── ... (现有内容)
└── BattleSummaryPanel (BattleSummaryPanel)  # 新增，默认 visible = false
```

### C4. 修改 `scenes/run_main/run_main.gd`

在 @onready 添加：
```gdscript
@onready var battle_summary_panel: BattleSummaryPanel = $BattleSummaryPanel
```

在 `_ready()` 的信号订阅中添加：
```gdscript
EventBus.battle_ended.connect(_on_battle_ended)
```

新增战斗结束回调：
```gdscript
func _on_battle_ended(battle_result: Dictionary) -> void:
    print("[RunMain] 战斗结束: winner=%s, turns=%d" % [
        battle_result.get("winner", "???"),
        battle_result.get("turns_elapsed", 0)
    ])
    _update_hud()
    battle_summary_panel.show_result(battle_result)
    battle_summary_panel.confirmed.connect(_on_battle_summary_confirmed, CONNECT_ONE_SHOT)

func _on_battle_summary_confirmed() -> void:
    print("[RunMain] 战斗摘要关闭")
    # 英雄存活则回到选项状态，阵亡则 RunController 已触发游戏结束
    _transition_ui_state(UISceneState.OPTION_SELECT)
```

### C5. 修改 `scripts/systems/run_controller.gd` 补充 battle_result 字段

在 `_run_battle_engine()` 中确保返回字段完整：

```gdscript
func _run_battle_engine(enemy_config_id: int) -> Dictionary:
    # ... 现有战斗逻辑 ...
    var result = battle_engine.execute_battle(config)
    
    # 补充 gold_reward
    if not result.has("gold_reward"):
        var enemy_cfg = ConfigManager.get_enemy_config(str(enemy_config_id))
        result["gold_reward"] = enemy_cfg.get("reward_gold_min", 20)
    
    # 补充 hero_max_hp
    if not result.has("hero_max_hp"):
        result["hero_max_hp"] = _hero.max_hp
    
    # 确保 hero_remaining_hp
    result["hero_remaining_hp"] = battle_hero.get("hp", 0)
    
    battle_engine.queue_free()
    return result
```

---

## Part D：文件修改清单汇总

| # | 文件 | 操作 | 所属Part |
|:---:|:---|:---:|:---:|
| 1 | `scripts/systems/shop_system.gd` | 删除hero_upgrade + 修改generate_items参数 | A |
| 2 | `scripts/systems/run_controller.gd` | 删除level_up/train_lv5 + 修正金币 + 修正商店调用 | A + C |
| 3 | `scenes/run_main/shop_item_button.tscn` | 新建 | B |
| 4 | `scenes/run_main/shop_item_button.gd` | 新建 | B |
| 5 | `scenes/run_main/battle_summary_panel.tscn` | 新建 | C |
| 6 | `scenes/run_main/battle_summary_panel.gd` | 新建 | C |
| 7 | `scenes/run_main/run_main.tscn` | 添加ShopItemContainer + GoldDisplayLabel + BattleSummaryPanel | B + C |
| 8 | `scenes/run_main/run_main.gd` | 商店渲染 + 购买回调 + 战斗摘要信号处理 | B + C |

---

## Part E：验收标准

### v1.0残留清理
- [ ] 商店面板只显示伙伴升级按钮，没有"体魄强化"等属性商品
- [ ] `shop_system.gd` 中搜索不到 `hero_upgrade` 字符串
- [ ] `run_controller.gd` 中搜索不到 `level_up` 和 `train_lv5` 字符串
- [ ] 战斗胜利金币奖励随敌人不同而变化（不是固定15左右）

### 商店UI
- [ ] 救援层选完伙伴后，自动弹出商店面板
- [ ] 商店显示可升级伙伴列表（名称、当前LV→下一LV、价格）
- [ ] 金币不足或已达LV5的按钮置灰
- [ ] 点击购买后金币立即刷新，对应按钮变"已售出"
- [ ] 关闭商店后自动推进到下一层

### 战斗可视化
- [ ] 点击"战斗"后弹出 BattleSummaryPanel
- [ ] 面板显示：敌人名称、回合数、损失生命、获得金币、连锁次数
- [ ] 胜利绿色"胜利！"，败北红色"败北..."
- [ ] 点击"确定"关闭面板，回到4选项（英雄存活时）
- [ ] `BattleEngine.gd` 没有任何修改（验证解耦）
