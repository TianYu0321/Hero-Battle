# 任务卡：酒馆/商店 UI 改造 + 主菜单→酒馆过渡

## 背景

当前 `ShopPopup` 已实现功能完整（Tab页、购买确认、金币、拥有状态），但：
1. 商品是文字 Button，无头像/稀有度/描述卡片化展示
2. 整体暗黑风格（Overlay 黑底 0.8 alpha），需改明亮纸片剧场
3. 缺少主菜单→酒馆的开场过渡动画

---

## 涉及文件

1. `scenes/shop/shop_popup.gd` — 商品卡片化改造 + 明亮风格
2. `scenes/shop/shop_popup.tscn` — 节点结构调整（Overlay颜色、Content样式、Tab页）
3. `scenes/main_menu/menu.gd` — 主菜单→酒馆过渡动画（淡入+滑入）
4. `resources/themes/shop_theme.tres` — **新建** 商店专用 Theme（或复用 menu_theme 扩展）

---

## Step 1：商店 Theme 资源（新建或复用）

**推荐**：复用 `menu_theme.tres` 作为基础，在代码中覆盖按钮/标签的特定样式。

如果新建 `shop_theme.tres`：
- 基于 `menu_theme.tres` 复制
- TabContainer 标签样式：font_size=18，选中=橙底白字，未选=白底灰字
- ScrollContainer 滚动条：细条（4px），橙 thumb，灰轨道

---

## Step 2：改造 `shop_popup.tscn` — 明亮风格节点调整

### Overlay（遮罩层）

当前：
```
[node name="Overlay" type="ColorRect"]
color = Color(0, 0, 0, 0.8)  ← 暗黑半透明
```

改为：
```
[node name="Overlay" type="ColorRect"]
color = Color(0.96, 0.95, 0.92, 0.85)  ← 淡米白半透明，呼应主菜单背景
```

或更通透的方案（让背景图隐约透出）：
```
color = Color(0.98, 0.97, 0.95, 0.75)
```

### Content（弹窗主体）

当前是 `Panel`，改为 `PanelContainer` 或带 StyleBox 的 `Control`：

```
[node name="Content" type="PanelContainer"]  ← 或保持 Panel 但加 Theme override
layout_mode = 1
anchors_preset = 8  (Center)
offset_left = -525.0
offset_top = -390.0
offset_right = 525.0
offset_bottom = 390.0

## 在脚本或 Theme 中设置样式：
## bg_color = Color(1.0, 1.0, 1.0)  白底实色
## border_color = Color(0.2, 0.2, 0.22)  深灰边框 2px
## corner_radius = 8  （比菜单按钮稍大，弹窗更重）
## shadow_size = 12
## shadow_color = rgba(0,0,0,0.1)
## shadow_offset = (0, 4)
```

### Header（标题栏）

```
HeaderHBox
├── TitleLabel ("酒馆")  ← 字号 28px，粗体，颜色 #1A1A1A
├── Spacer (spring)
├── CoinLabel ("💰 999")  ← 字号 20px，颜色 #D4A843 亮金
├── CloseButton ("✕")  ← 同菜单按钮样式，36x36 正方形
```

### TabContainer 标签改造

```
TabContainer
├── 英雄 (ScrollContainer)
│   └── ItemGrid (GridContainer, columns=3, h_sep=16, v_sep=16)
├── 伙伴
│   └── ItemGrid
└── 皮肤
    └── ItemGrid
```

Tab 标签样式（在 Theme 或脚本中）：
- 未选中：白底，深灰文字 16px，底部灰线 1px
- 选中：白底，活力橙文字 16px bold，底部橙线 3px
- Hover：白底微暖 `#FFF8F0`，文字 `#FF6B35`
- 过渡动画：底部 indicator line Tween 滑动（0.2s）

---

## Step 3：改造 `shop_popup.gd` — 商品卡片化

### 3.1 删除旧的文字 Button 生成

当前 `_create_item_button`：
```gdscript
var btn := Button.new()
btn.text = "%s\n💰 %d" % [item_name, cost]
btn.custom_minimum_size = Vector2(100, 120)
btn.tooltip_text = desc
```

改为卡片式 PanelContainer：

### 3.2 新增 `_create_item_card()`

```gdscript
func _create_item_card(item: Dictionary, unlocked: Array) -> PanelContainer:
    var id: int = int(item.get("id", 0))
    var cost: int = int(item.get("cost", 0))
    var is_owned: bool = id in unlocked
    var can_afford: bool = _current_coin >= cost
    
    var item_name: String = item.get("name", "???")
    var desc: String = item.get("desc", "")
    var rarity: String = item.get("rarity", "C")  ## C/B/A/S
    var icon_path: String = item.get("icon_path", "")  ## 商品头像路径
    
    ## 卡片根节点
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(160, 220)  ## 3:4 竖版卡片
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    
    ## 卡片样式
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0)
    style.border_color = _get_rarity_color(rarity) if not is_owned else Color(0.7, 0.7, 0.72)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.shadow_size = 6
    style.shadow_color = Color(0, 0, 0, 0.08)
    style.shadow_offset = Vector2(0, 3)
    card.add_theme_stylebox_override("panel", style)
    
    ## 内部纵向布局
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 6)
    card.add_child(vbox)
    
    ## 稀有度角标（左上角）
    var badge := Label.new()
    badge.text = rarity
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    badge.add_theme_font_size_override("font_size", 11)
    badge.add_theme_color_override("font_color", _get_rarity_color_bright(rarity))
    ## 角标放在卡片左上角 —— 需要额外容器或绝对定位
    ## 简化：放在顶部中央作为小标签
    vbox.add_child(badge)
    
    ## 商品图标/头像
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(100, 100)
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    if not icon_path.is_empty():
        var tex := load(icon_path)
        if tex != null:
            icon.texture = tex
    else:
        ## 占位：纯色渐变
        var grad := GradientTexture2D.new()
        grad.gradient = Gradient.new()
        grad.gradient.colors = [Color(0.9, 0.9, 0.92), Color(0.85, 0.85, 0.88)]
        grad.width = 100
        grad.height = 100
        icon.texture = grad
    vbox.add_child(icon)
    
    ## 商品名称
    var name_label := Label.new()
    name_label.text = item_name
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override("font_color", Color("#1A1A1A"))
    vbox.add_child(name_label)
    
    ## 价格
    var price_label := Label.new()
    price_label.text = "💰 %d" % cost
    price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    price_label.add_theme_font_size_override("font_size", 13)
    if is_owned:
        price_label.add_theme_color_override("font_color", Color("#888888"))
        price_label.text = "✅ 已拥有"
    elif not can_afford:
        price_label.add_theme_color_override("font_color", Color("#CC4422"))
    else:
        price_label.add_theme_color_override("font_color", Color("#D4A843"))  ## 亮金
    vbox.add_child(price_label)
    
    ## 描述（小字，两行截断）
    var desc_label := Label.new()
    desc_label.text = desc
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc_label.add_theme_font_size_override("font_size", 10)
    desc_label.add_theme_color_override("font_color", Color("#888888"))
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_label.custom_minimum_size = Vector2(140, 0)
    vbox.add_child(desc_label)
    
    ## 交互
    if not is_owned and can_afford:
        card.gui_input.connect(func(event: InputEvent):
            if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                _show_purchase_confirm(item)
        )
        ## Hover 效果
        card.mouse_entered.connect(func():
            var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.12)
            tween.parallel().tween_property(card, "modulate", Color(1.05, 1.05, 1.0), 0.12)
            ## 阴影扩散
            var hover_style := style.duplicate()
            hover_style.shadow_size = 10
            hover_style.shadow_color = Color(0, 0, 0, 0.15)
            card.add_theme_stylebox_override("panel", hover_style)
        )
        card.mouse_exited.connect(func():
            var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tween.tween_property(card, "scale", Vector2.ONE, 0.15)
            tween.parallel().tween_property(card, "modulate", Color.WHITE, 0.15)
            card.add_theme_stylebox_override("panel", style)
        )
    else:
        ## 禁用态：灰度 + 不可点击
        card.modulate = Color(0.85, 0.85, 0.85) if is_owned else Color(0.9, 0.8, 0.8)
    
    return card

func _get_rarity_color(rarity: String) -> Color:
    match rarity:
        "S": return Color("#E6C040")  ## 暗金边框
        "A": return Color("#5A8FD0")  ## 蓝
        "B": return Color("#4ECDC4")  ## 青
        _:   return Color("#888888")  ## 灰

func _get_rarity_color_bright(rarity: String) -> Color:
    match rarity:
        "S": return Color("#FFD700")  ## 亮金文字
        "A": return Color("#5599FF")  ## 亮蓝
        "B": return Color("#44DDAA")  ## 亮青
        _:   return Color("#AAAAAA")  ## 灰
```

### 3.3 购买确认弹窗改造

当前用 `AcceptDialog`（系统默认样式），改为自定义弹窗：

```gdscript
func _show_purchase_confirm(item: Dictionary) -> void:
    var cost: int = int(item.get("cost", 0))
    var item_name: String = item.get("name", "???")
    
    ## 自定义确认弹窗（非系统 AcceptDialog）
    var dialog := PanelContainer.new()
    dialog.custom_minimum_size = Vector2(360, 200)
    dialog.set_anchors_preset(Control.PRESET_CENTER)
    
    ## 样式：白底 + 深灰边框 + 阴影
    var dstyle := StyleBoxFlat.new()
    dstyle.bg_color = Color(1.0, 1.0, 1.0)
    dstyle.border_color = Color(0.2, 0.2, 0.22)
    dstyle.border_width_left = 2
    dstyle.border_width_top = 2
    dstyle.border_width_right = 2
    dstyle.border_width_bottom = 2
    dstyle.corner_radius_top_left = 8
    dstyle.corner_radius_top_right = 8
    dstyle.corner_radius_bottom_left = 8
    dstyle.corner_radius_bottom_right = 8
    dstyle.shadow_size = 16
    dstyle.shadow_color = Color(0, 0, 0, 0.15)
    dstyle.shadow_offset = Vector2(0, 6)
    dialog.add_theme_stylebox_override("panel", dstyle)
    
    var dvbox := VBoxContainer.new()
    dvbox.alignment = BoxContainer.ALIGNMENT_CENTER
    dvbox.add_theme_constant_override("separation", 16)
    dialog.add_child(dvbox)
    
    ## 标题
    var title := Label.new()
    title.text = "确认购买"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("#1A1A1A"))
    dvbox.add_child(title)
    
    ## 内容
    var content := Label.new()
    content.text = "花费 %d 魔城币购买 %s？" % [cost, item_name]
    content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_theme_font_size_override("font_size", 16)
    content.add_theme_color_override("font_color", Color("#444444"))
    dvbox.add_child(content)
    
    ## 按钮行
    var btn_hbox := HBoxContainer.new()
    btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_hbox.add_theme_constant_override("separation", 16)
    dvbox.add_child(btn_hbox)
    
    ## 取消按钮
    var cancel_btn := Button.new()
    cancel_btn.text = "取消"
    cancel_btn.custom_minimum_size = Vector2(100, 40)
    ## 应用菜单按钮样式（白底+灰边框）
    _apply_menu_button_style(cancel_btn)
    cancel_btn.pressed.connect(func():
        if is_instance_valid(dialog):
            ## 退出动画
            var out_tween := create_tween()
            out_tween.tween_property(dialog, "modulate:a", 0.0, 0.15)
            out_tween.tween_callback(func(): dialog.queue_free())
    )
    btn_hbox.add_child(cancel_btn)
    
    ## 确认按钮（活力橙强调）
    var confirm_btn := Button.new()
    confirm_btn.text = "确认购买"
    confirm_btn.custom_minimum_size = Vector2(120, 40)
    ## 橙底白字强调样式
    var cstyle := StyleBoxFlat.new()
    cstyle.bg_color = Color("#FF6B35")
    cstyle.border_color = Color("#CC5520")
    cstyle.border_width_left = 1
    cstyle.border_width_top = 1
    cstyle.border_width_right = 1
    cstyle.border_width_bottom = 3
    cstyle.corner_radius_top_left = 4
    cstyle.corner_radius_top_right = 4
    cstyle.corner_radius_bottom_left = 4
    cstyle.corner_radius_bottom_right = 4
    confirm_btn.add_theme_stylebox_override("normal", cstyle)
    confirm_btn.add_theme_color_override("font_color", Color.WHITE)
    confirm_btn.add_theme_font_size_override("font_size", 16)
    confirm_btn.pressed.connect(func():
        _confirm_purchase(item)
        if is_instance_valid(dialog):
            var out_tween := create_tween()
            out_tween.tween_property(dialog, "modulate:a", 0.0, 0.15)
            out_tween.tween_callback(func(): dialog.queue_free())
    )
    btn_hbox.add_child(confirm_btn)
    
    ## 添加到场景
    add_child(dialog)
    
    ## 入场动画：从下方滑入 + 淡入
    dialog.modulate.a = 0.0
    dialog.position.y += 20
    var in_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    in_tween.tween_property(dialog, "modulate:a", 1.0, 0.25)
    in_tween.parallel().tween_property(dialog, "position:y", dialog.position.y - 20, 0.3)
```

---

## Step 4：改造 `_render_tab()`

```gdscript
func _render_tab(tab_name: String, items: Array, unlocked: Array) -> void:
    var grid: GridContainer = _tab_container.get_node("%s/ItemGrid" % tab_name)
    for child in grid.get_children():
        child.queue_free()
    for item in items:
        var card := _create_item_card(item, unlocked)
        grid.add_child(card)
```

---

## Step 5：主菜单→酒馆过渡动画

### 5.1 改造 `menu.gd` 的 `_on_shop_button_pressed()`

```gdscript
func _on_shop_button_pressed() -> void:
    ## 先播放按钮弹性动画（已有）
    ## 然后启动过渡序列
    _transition_to_shop()

func _transition_to_shop() -> void:
    ## 1. 全屏淡入遮罩（从主菜单画面过渡到酒馆）
    var transition_overlay := ColorRect.new()
    transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    transition_overlay.color = Color(0.96, 0.95, 0.92, 0.0)  ## 淡米白，初始透明
    transition_overlay.z_index = 100
    add_child(transition_overlay)
    
    var tween := create_tween()
    ## 淡入遮罩 0.3s
    tween.tween_property(transition_overlay, "color:a", 1.0, 0.3)
    tween.tween_callback(func():
        ## 2. 打开酒馆弹窗
        shop_popup.show_popup()
        ## 3. 淡出遮罩 0.3s
        var out_tween := create_tween()
        out_tween.tween_property(transition_overlay, "color:a", 0.0, 0.3)
        out_tween.tween_callback(func(): transition_overlay.queue_free())
    )
```

**注意**：如果 `ShopPopup` 是 `Popup` 或 `Window` 类型，直接 `popup_centered()`。如果是 `Control`（当前是 `Control` + `visible` 切换），用上面的序列。

### 5.2 酒馆出场动画

在 `shop_popup.gd` 的 `show_popup()` 中添加：

```gdscript
func show_popup() -> void:
    visible = true
    
    ## 入场动画
    _content.modulate.a = 0.0
    _content.position.y += 30
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_content, "modulate:a", 1.0, 0.35)
    tween.parallel().tween_property(_content, "position:y", _content.position.y - 30, 0.4)
    
    refresh()
```

---

## Step 6：关闭酒馆→返回主菜单过渡

```gdscript
func hide_popup() -> void:
    ## 退场动画
    var tween := create_tween()
    tween.tween_property(_content, "modulate:a", 0.0, 0.2)
    tween.parallel().tween_property(_content, "position:y", _content.position.y + 20, 0.25)
    tween.tween_callback(func():
        for child in get_children():
            if child is Window:
                child.queue_free()
        visible = false
        closed.emit()
    )
```

---

## 测试清单

- [ ] Overlay 为淡米白半透明（非暗黑黑底）
- [ ] Content 弹窗白底实色 + 深灰边框 + 圆角阴影
- [ ] Tab 标签：未选中灰线，选中橙线，切换有滑动感
- [ ] 商品卡片：白底 + 稀有度色边框 + 阴影
- [ ] 卡片含：稀有度角标、头像/图标、名称、价格、描述
- [ ] 已拥有卡片：灰度 + ✅标签
- [ ] 金币不足卡片：微红 + 不可点击
- [ ] Hover 卡片：scale 1.03 + 阴影扩散 + 微亮
- [ ] 点击可购买卡片：弹出确认对话框（白底+阴影，非系统 AcceptDialog）
- [ ] 确认对话框：取消按钮（白底灰边）+ 确认按钮（橙底白字）
- [ ] 购买成功：金币数字更新，卡片状态刷新（变灰+✅）
- [ ] 主菜单点击商店：淡米白遮罩淡入 → 酒馆弹出 → 遮罩淡出
- [ ] 酒馆关闭：内容淡出下移 → 完全关闭 → 返回主菜单
- [ ] 所有文字在白底上清晰可读
- [ ] 商品网格 3 列，间距 16px，无重叠
