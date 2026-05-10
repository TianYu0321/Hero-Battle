# 任务卡：Hero-Battle UI布局 + 战斗流程修复

> 优先级：P0（阻塞游戏运行）
> 目标：让游戏能正常进入战斗，UI布局符合v2.0规格

---

## Bug 1：UI布局不符合v2.0规格

### 问题描述
当前布局：顶部HudContainer横排（层数/金币/生命/属性条）+ 左侧4按钮 + 隐藏的训练面板/敌人面板 + 底部伙伴槽。

期望布局（v2.0）：
```
┌─────────────────────────────────────────────────────────────┐
│  左侧              中间                    右侧             │
│  ┌─────┐    ┌────────────────────┐    ┌─────────────────┐  │
│  │角色 │    │ [训练][战斗][休息][外出] │    │ 敌人: XXX        │  │
│  │头像 │    │                      │    │ HP: 50/50       │  │
│  │     │    │ 训练展开后:           │    │ 预计损失: 15    │  │
│  │五维 │    │ [体魄]LV:3 [伙伴头像] │    │                  │  │
│  │属性 │    │ [力量]LV:2 [伙伴头像] │    │                  │  │
│  │数值 │    │ ...                  │    │                  │  │
│  └─────┘    └────────────────────┘    └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 修改文件

#### 文件1：`scenes/run_main/run_main.tscn`

**步骤1**：移除顶部HudContainer中的属性条
- 删除节点：`AttrBar1`~`AttrBar5`、`AttrLabel1`~`AttrLabel5`
- 保留：`FloorLabel`、`GoldLabel`、`HpLabel`

**步骤2**：添加左侧角色信息区域
- 添加容器节点：`PlayerInfoPanel`（VBoxContainer），位于左侧
- 子节点：
  - `PlayerPortrait`（ColorRect，60x60，占位头像）
  - `PlayerVitLabel`（Label，"体魄: 0"）
  - `PlayerStrLabel`（Label，"力量: 0"）
  - `PlayerAgiLabel`（Label，"敏捷: 0"）
  - `PlayerTecLabel`（Label，"技巧: 0"）
  - `PlayerMndLabel`（Label，"精神: 0"）

**步骤3**：调整右侧EnemyInfoPanel
- 将`visible = false`改为`visible = true`（默认显示）
- 确保包含：`EnemyNameLabel`、`EnemyHpLabel`、`EstimatedDamageLabel`

#### 文件2：`scenes/run_main/run_main.gd`

**步骤1**：添加左侧属性标签引用
```gdscript
@onready var player_vit_label: Label = $PlayerInfoPanel/PlayerVitLabel
@onready var player_str_label: Label = $PlayerInfoPanel/PlayerStrLabel
@onready var player_agi_label: Label = $PlayerInfoPanel/PlayerAgiLabel
@onready var player_tec_label: Label = $PlayerInfoPanel/PlayerTecLabel
@onready var player_mnd_label: Label = $PlayerInfoPanel/PlayerMndLabel
```

**步骤2**：在`_update_hud()`中添加五维属性更新
```gdscript
# 在_update_hud()中添加
var hero_data = summary.get("hero", {})
player_vit_label.text = "体魄: %d" % hero_data.get("current_vit", 0)
player_str_label.text = "力量: %d" % hero_data.get("current_str", 0)
player_agi_label.text = "敏捷: %d" % hero_data.get("current_agi", 0)
player_tec_label.text = "技巧: %d" % hero_data.get("current_tec", 0)
player_mnd_label.text = "精神: %d" % hero_data.get("current_mnd", 0)
```

**步骤3**：移除属性条更新代码
- 删除`attr_bars`和`attr_labels`相关引用和更新逻辑

**步骤4**：添加敌人信息更新方法
```gdscript
func update_enemy_info(enemy_data: Dictionary) -> void:
    enemy_info_panel.visible = true
    enemy_name_label.text = "敌人: %s" % enemy_data.get("name", "???")
    var max_hp = enemy_data.get("max_hp", 0)
    var current_hp = enemy_data.get("current_hp", max_hp)
    enemy_hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
    estimated_damage_label.text = "预计损失血量: %d" % enemy_data.get("estimated_damage", 0)
```

### 验收标准
- [ ] 游戏启动后UI显示左侧五维属性数值
- [ ] 顶部只显示层数/金币/生命
- [ ] 右侧EnemyInfoPanel默认可见
- [ ] 属性数值随训练/战斗实时更新

---

## Bug 2：点击战斗直接生成存档返回主菜单

### 问题描述
点击战斗按钮后，敌人名字显示"???" HP:0，然后直接终局保存返回主菜单。

### 根因分析
`scripts/systems/node_resolver.gd`的`_resolve_battle()`方法：
- 只返回金币奖励
- 没有生成敌人
- 没有战斗计算
- 没有HP扣减/死亡判定
- 导致RunController认为战斗瞬间结束，直接推进到30层终局

### 修改文件

#### 文件3：`scripts/systems/node_resolver.gd`

**步骤1**：添加敌人生成方法
```gdscript
func generate_enemy_for_floor(floor: int) -> Dictionary:
    # 从enemy_configs.json读取敌人配置
    var enemy_cfg = ConfigManager.get_enemy_config_for_floor(floor)
    if enemy_cfg.is_empty():
        # 默认敌人（层数越高越强）
        var base_hp = 30 + floor * 5
        var base_atk = 5 + floor * 2
        return {
            "name": "第%d层怪物" % floor,
            "max_hp": base_hp,
            "current_hp": base_hp,
            "attack": base_atk,
            "gold_drop": 10 + floor,
            "estimated_damage": maxi(1, int(base_atk * 0.5)),
        }
    else:
        return {
            "name": enemy_cfg.get("name", "???"),
            "max_hp": enemy_cfg.get("hp", 50),
            "current_hp": enemy_cfg.get("hp", 50),
            "attack": enemy_cfg.get("attack", 10),
            "gold_drop": enemy_cfg.get("gold_drop", 20),
            "estimated_damage": enemy_cfg.get("estimated_damage", 10),
        }
```

**步骤2**：重写`_resolve_battle()`
```gdscript
func _resolve_battle(node_config: Dictionary, run: RuntimeRun, hero: RuntimeHero) -> Dictionary:
    var result := {"success": true, "rewards": [], "combat_result": null, "logs": []}
    
    # 生成敌人
    var enemy = generate_enemy_for_floor(run.current_floor)
    
    # 发送信号让UI显示敌人信息
    EventBus.emit_signal("enemy_encountered", enemy)
    
    # 简化战斗：玩家攻击 vs 敌人HP
    var hero_attack = hero.current_str * 2 + hero.current_tec  # 简化攻击计算
    var battle_rounds = 0
    var hero_hp_loss = 0
    
    while enemy.current_hp > 0 and battle_rounds < 20:
        # 玩家攻击
        enemy.current_hp -= hero_attack
        battle_rounds += 1
        
        # 敌人反击（每回合）
        if enemy.current_hp > 0:
            var damage = maxi(1, enemy.attack - hero.current_vit)
            hero.current_hp -= damage
            hero_hp_loss += damage
            
            # 检查玩家死亡
            if hero.current_hp <= 0:
                hero.current_hp = 0
                result["success"] = false
                result["logs"].append("第%d层：战斗失败，生命耗尽" % run.current_floor)
                EventBus.emit_signal("stats_changed", hero.id, {0: {"old": hero.current_hp + hero_hp_loss, "new": 0, "delta": -hero_hp_loss}})
                return result
    
    # 战斗胜利
    if enemy.current_hp <= 0:
        var gold_reward = enemy.gold_drop
        result["rewards"].append({"type": "gold", "amount": gold_reward})
        result["logs"].append("第%d层：战斗胜利，获得%d金币，损失%d生命" % [run.current_floor, gold_reward, hero_hp_loss])
        
        # 更新英雄HP和金币
        EventBus.emit_signal("gold_changed", run.gold_owned + gold_reward, gold_reward, "battle_reward")
        EventBus.emit_signal("stats_changed", hero.id, {0: {"old": hero.current_hp + hero_hp_loss, "new": hero.current_hp, "delta": -hero_hp_loss}})
    
    return result
```

**步骤3**：在NodeResolver的`_ready()`中声明新信号依赖
```gdscript
signal enemy_encountered(enemy_data: Dictionary)
```

#### 文件4：`scenes/run_main/run_main.gd`

**步骤1**：添加敌人遭遇信号处理
```gdscript
func _ready() -> void:
    # ... 现有代码 ...
    EventBus.enemy_encountered.connect(_on_enemy_encountered)

func _on_enemy_encountered(enemy_data: Dictionary) -> void:
    update_enemy_info(enemy_data)
```

**步骤2**：修改`_on_battle_button_pressed`
```gdscript
func _on_battle_button_pressed() -> void:
    # 显示敌人信息面板
    enemy_info_panel.visible = true
    _run_controller.select_node(1)  # BATTLE index
```

#### 文件5：`scripts/systems/run_controller.gd`

**步骤1**：在`select_node()`中确保敌人信息已生成
```gdscript
func select_node(node_index: int) -> void:
    # ... 现有代码 ...
    
    # 如果是战斗节点，预生成敌人信息供UI显示
    if _pending_node_type == NodePoolSystem.NodeType.BATTLE:
        var enemy_data = _node_resolver.generate_enemy_for_floor(_run.current_floor)
        EventBus.emit_signal("enemy_encountered", enemy_data)
```

**步骤2**：确保死亡判定正确
```gdscript
func _process_node_result(result: Dictionary) -> void:
    # ... 现有代码 ...
    
    # 检查战斗失败（生命耗尽）
    if not result.get("success", true):
        _change_state(RunState.SETTLEMENT)
        _generate_fighter_archive()
        return
    
    # 正常推进
    _node_pool_system.record_selection(_pending_node_type)
    _change_state(RunState.FLOOR_ADVANCE)
    advance_floor()
```

### 验收标准
- [ ] 点击战斗后右侧显示敌人名称/HP/预计损失（非"???"和0）
- [ ] 战斗有简化回合计算（非瞬间结束）
- [ ] 胜利后获得金币，扣减一定HP
- [ ] HP归零则死亡，本局结束生成存档
- [ ] 非死亡则正常推进到下一层

---

## 通用规则

1. **只改列出的文件和代码范围**，不要动其他文件
2. **改完一个文件就在群里回复"XX已改"**
3. **遇到问题立刻停下汇报**，不要猜
4. Godot场景文件(.tscn)修改：可以手动编辑文本，也可以Godot编辑器操作
5. 所有敌人配置先走简化逻辑（不用等enemy_configs.json完备）

---

## 文件修改清单汇总

| # | 文件 | Bug | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scenes/run_main/run_main.tscn` | 1 | 移除属性条，添加左侧PlayerInfoPanel，调整EnemyInfoPanel |
| 2 | `scenes/run_main/run_main.gd` | 1+2 | 添加属性标签引用+更新，添加敌人信息更新方法 |
| 3 | `scripts/systems/node_resolver.gd` | 2 | 添加generate_enemy_for_floor()，重写_resolve_battle() |
| 4 | `scripts/systems/run_controller.gd` | 2 | 战斗节点预生成敌人，死亡判定修正 |
