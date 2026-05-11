# Bug修复 + 功能调整任务卡

---

## Bug 1：游戏结束后点"继续游戏"继承上把属性

### 根因
游戏结束时 RunController 发射 `run_ended`，但**没有删除存档文件**。`SaveManager.has_active_run()` 仍然返回 true，"继续游戏"按钮仍然显示。点击后加载的是已结束的那局存档，主角属性、层数、金币全是上把的最终状态。

### 修复
在 `scripts/systems/run_controller.gd` 的 `FINISHED` 分支末尾，发射 `run_ended` **之前**，删除存档文件：

```gdscript
RunState.FINISHED:
    ...
    # 删除存档，防止已结束的局被"继续游戏"加载
    var save_path: String = ConfigManager.SAVE_DIR + "save_001.json"
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
        print("[RunController] 已删除存档: %s" % save_path)
    
    EventBus.run_ended.emit("victory", _run.total_score, archive_data)
    return
```

**同理**，如果存在 `DEFEATED` / `GAME_OVER` 分支，也要在发射 `run_ended` 前删除存档。

### 验证
- [ ] 完成一局游戏 → 回到主菜单
- [ ] "继续游戏"按钮**不显示**（或点击后提示"无存档"）
- [ ] 新开局的主角属性是初始值

---

## Bug 2：5层营救的伙伴没有入队（商店不显示）

### 根因
`run_main.gd` 的 `_on_rescue_confirm_button_pressed()` 调用 `_run_controller.select_rescue_partner(-1)`，传入的 `-1` 不是有效的伙伴配置ID，`CharacterManager.add_partner(-1)` 失败，伙伴没有加入队伍。

### 修复

#### Step 1：修改 `scenes/run_main/run_main.gd` 的 `_show_rescue_panel_details`

把救援候选从不可点击的 Label 改成可点击的 Button，点击后记录选择的伙伴ID：

```gdscript
var _selected_rescue_partner_id: int = -1  # **新增**：记录选择的伙伴ID

func _show_rescue_panel_details(panel_data: Dictionary) -> void:
    var candidates: Array[Dictionary] = panel_data.get("candidates", [])
    rescue_partner_labels.clear()
    _selected_rescue_partner_id = -1  # 重置选择
    for child in rescue_partner_container.get_children():
        child.queue_free()
    
    for candidate in candidates:
        var btn := Button.new()
        btn.text = candidate.get("name", "???")
        btn.custom_minimum_size = Vector2(0, 40)
        # 点击时记录 partner_id 并高亮
        btn.pressed.connect(_on_rescue_candidate_clicked.bind(candidate))
        rescue_partner_container.add_child(btn)
        rescue_partner_labels.append(btn)
    
    rescue_confirm_button.visible = (candidates.size() > 0)
    # 初始禁用确认按钮，等选了候选再启用
    rescue_confirm_button.disabled = true

func _on_rescue_candidate_clicked(candidate: Dictionary) -> void:
    _selected_rescue_partner_id = int(candidate.get("partner_id", 0))
    print("[RunMain] 选择救援伙伴: id=%d" % _selected_rescue_partner_id)
    # 高亮选中的按钮（简化：其他按钮变暗，选中的变亮）
    for btn in rescue_partner_labels:
        btn.modulate = Color(0.5, 0.5, 0.5)
    var clicked_btn = rescue_partner_labels[candidates.find(candidate)]
    clicked_btn.modulate = Color(1, 1, 1)
    rescue_confirm_button.disabled = false
```

#### Step 2：修改 `_on_rescue_confirm_button_pressed` 传正确的ID

```gdscript
func _on_rescue_confirm_button_pressed() -> void:
    print("[RunMain] 救援确认按钮点击")
    if _selected_rescue_partner_id <= 0:
        push_error("[RunMain] 未选择救援伙伴")
        return
    if _run_controller != null:
        _run_controller.select_rescue_partner(_selected_rescue_partner_id)
```

### 验证
- [ ] 第5层弹出救援面板，显示3个候选伙伴按钮
- [ ] 点击候选伙伴按钮，按钮高亮，"确认"按钮变为可点击
- [ ] 点击"确认"后，救援面板关闭，商店面板弹出
- [ ] 商店面板显示刚救的伙伴（名称、LV1→LV2、价格）
- [ ] 控制台有 `[RunController] 救援伙伴加入: config_id=X` 输出

---

## 调整 1：主界面增加"查看档案"按钮

### 当前状态
`menu.gd` 中 `btn_archive` 被强制隐藏：
```gdscript
var btn_archive: Button = get_node_or_null("%BtnArchive")
if btn_archive != null:
    btn_archive.visible = false
    btn_archive.disabled = true
```

### 修复
删除隐藏代码，启用按钮并连接信号：

```gdscript
func _ready() -> void:
    ...
    var btn_archive: Button = get_node_or_null("%BtnArchive")
    if btn_archive != null:
        btn_archive.visible = true
        btn_archive.disabled = false
        btn_archive.pressed.connect(_on_archive_button_pressed)
        print("[MainMenu] 档案按钮已启用")
    else:
        push_warning("[MainMenu] BtnArchive 未找到")
    ...

func _on_archive_button_pressed() -> void:
    print("[MainMenu] 查看档案按钮点击")
    EventBus.archive_view_requested.emit()
```

### 验证
- [ ] 主菜单显示"查看档案"按钮
- [ ] 点击后进入档案浏览界面（`scenes/archive_view/archive_view.tscn`）
- [ ] 档案界面显示已有的斗士档案列表
- [ ] 点击"返回"回到主菜单

---

## 调整 2：商店允许同一伙伴多次升级

### 当前状态
购买后调用 `btn.mark_sold_out()`，按钮永久置灰显示"已售出"。

### 修复
购买成功后，刷新整个商店面板（重新读取伙伴当前等级），而不是永久标记已售出。

#### Step 1：`scripts/systems/run_controller.gd` 新增 `get_current_shop_items()`

```gdscript
func get_current_shop_items() -> Array[Dictionary]:
    var shop_system = get_node_or_null("ShopSystem")
    if shop_system != null:
        return shop_system.generate_shop_inventory(_run.current_turn, _run.gold_owned)
    return []
```

#### Step 2：修改 `scenes/run_main/run_main.gd` 的 `_on_shop_item_purchased`

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
        
        # **关键修改**：刷新整个商店面板，允许继续升级
        var fresh_items = _run_controller.get_current_shop_items()
        _show_shop_panel(fresh_items)
        
        print("[RunMain] 商店已刷新，当前金币=%d" % new_gold)
    else:
        print("[RunMain] 购买失败: %s" % result.get("error", "???"))
```

#### Step 3：`scenes/run_main/shop_item_button.gd` 确保 `setup()` 可重复调用

`setup()` 应该能正确处理重复调用（重置 sold_out 状态）：

```gdscript
func setup(item: Dictionary) -> void:
    item_data = item
    is_sold_out = false  # **新增**：重置状态
    modulate = Color(1, 1, 1)  # **新增**：重置颜色
    
    var item_type = item.get("item_type", "")
    match item_type:
        "partner_upgrade":
            name_label.text = item.get("name", "???")
            var current_lv = item.get("current_level", 1)
            var next_lv = mini(5, current_lv + 1)
            level_label.text = "LV%d → LV%d" % [current_lv, next_lv]
    
    price_label.text = "%d金币" % item.get("price", 0)
    
    var can_afford = item.get("can_afford", true)
    var max_level_reached = item.get("current_level", 1) >= 5
    disabled = not can_afford or max_level_reached
    if disabled:
        modulate = Color(0.5, 0.5, 0.5)
```

### 验证
- [ ] 救援层商店中，伙伴显示 LV1→LV2，价格30金币
- [ ] 点击购买后，按钮刷新为 LV2→LV3，新价格（如40金币）
- [ ] 继续购买直到 LV5，按钮变为"已满级"置灰
- [ ] 金币不足时按钮置灰，金币足够后恢复可点击

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/systems/run_controller.gd` | FINISHED分支删除存档 |
| 2 | `scenes/run_main/run_main.gd` | `_show_rescue_panel_details` 候选改为按钮 + `_on_rescue_candidate_clicked` |
| 3 | `scenes/run_main/run_main.gd` | `_on_rescue_confirm_button_pressed` 传 `_selected_rescue_partner_id` |
| 4 | `scenes/main_menu/menu.gd` | 启用档案按钮 + `_on_archive_button_pressed` |
| 5 | `scripts/systems/run_controller.gd` | 新增 `get_current_shop_items()` |
| 6 | `scenes/run_main/run_main.gd` | `_on_shop_item_purchased` 刷新面板代替 mark_sold_out |
| 7 | `scenes/run_main/shop_item_button.gd` | `setup()` 支持重复调用 |
