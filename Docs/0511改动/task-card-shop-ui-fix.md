# 商店UI修复任务卡（精确版）

> 只修复用户当前报告的2个具体问题，不改其他文件。

---

## 问题1：关闭按钮点不了 + 和商品按钮重叠

### 根因（一句话）

ShopPanel 用手动 offset 定位 ShopItemContainer 和 CloseButton，两者在 Y 轴上几乎重叠（间距约5px）。ShopItemContainer 是 VBoxContainer，里面的商品按钮（高40px左右）向下延伸时覆盖到 CloseButton 的点击区域，导致 CloseButton 接收不到输入事件。

### 修复方案：把 ShopPanel 改为 VBoxContainer 自动布局

当前 ShopPanel 内部用绝对 offset 手工定位，容易出错。改为 VBoxContainer 自动排列，关闭按钮永远在最底部，不会被商品列表遮挡。

#### Step 1：修改 `run_main.tscn` 的 ShopPanel 结构

**删除** ShopPanel 内部所有子节点的手动 offset/anchor，改为 VBoxContainer 统一管理。

```
[node name="ShopPanel" type="Panel" parent="."]
visible = false
layout_mode = 0
offset_left = 440.0
offset_top = 200.0
offset_right = 840.0
offset_bottom = 480.0

[node name="ContentVBox" type="VBoxContainer" parent="ShopPanel"]      # **新增**
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 10.0
offset_right = -20.0
offset_bottom = -10.0
grow_horizontal = 2
grow_vertical = 2

[node name="TitleLabel" type="Label" parent="ShopPanel/ContentVBox"]      # **路径改到 ContentVBox 下**
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "商店"
horizontal_alignment = 1
vertical_alignment = 1

[node name="GoldDisplayLabel" type="Label" parent="ShopPanel/ContentVBox"]  # **路径改到 ContentVBox 下**
layout_mode = 2
text = "持有金币: 0"
horizontal_alignment = 1

[node name="ShopItemContainer" type="VBoxContainer" parent="ShopPanel/ContentVBox"]  # **路径改到 ContentVBox 下**
layout_mode = 2
size_flags_vertical = 3    # **关键**：占据ContentVBox中所有剩余垂直空间

[node name="CloseButton" type="Button" parent="ShopPanel/ContentVBox"]   # **路径改到 ContentVBox 下**
layout_mode = 2
text = "关闭"
```

**关键说明**：
- `ContentVBox` 是 VBoxContainer，所有子节点（TitleLabel → GoldDisplayLabel → ShopItemContainer → CloseButton）按顺序从上到下排列
- `ShopItemContainer` 设置 `size_flags_vertical = 3`（EXPAND），占据 TitleLabel、GoldDisplayLabel 和 CloseButton 以外的所有剩余空间
- CloseButton 在 VBoxContainer 中排最后，永远在最底部，不会被 ShopItemContainer 的商品按钮遮挡
- ContentVBox 的 `offset_left/right/top/bottom = 20/−20/10/−10` 给 ShopPanel 边缘留出 10~20px 内边距

#### Step 2：修改 `run_main.gd` 的节点引用路径

因为 ShopItemContainer 和 CloseButton 的路径变了（从 `ShopPanel/ShopItemContainer` 变为 `ShopPanel/ContentVBox/ShopItemContainer`），需要更新代码中的引用。

```gdscript
# 旧路径（删除）
# @onready var shop_item_container: VBoxContainer = $ShopPanel/ShopItemContainer
# @onready var shop_gold_label: Label = $ShopPanel/GoldDisplayLabel

# 新路径
@onready var shop_item_container: VBoxContainer = $ShopPanel/ContentVBox/ShopItemContainer
@onready var shop_gold_label: Label = $ShopPanel/ContentVBox/GoldDisplayLabel
```

`_on_shop_close_pressed` 中获取 CloseButton 的引用也需要改路径：

```gdscript
# 旧代码（_ready中）
# var shop_close_button: Button = $ShopPanel/CloseButton

# 新代码
var shop_close_button: Button = $ShopPanel/ContentVBox/CloseButton
```

#### Step 3：删除 `_show_modal_panel` 中对 shop_panel 的特殊处理

当前 `_show_modal_panel` 中会隐藏 shop_panel，但因为我们现在用 ContentVBox 管理布局，不需要特殊处理。

```gdscript
func _show_modal_panel(panel: Control) -> void:
    ui_modal_blocker.visible = true
    ui_modal_blocker.z_index = panel.z_index - 1 if panel.z_index > 0 else 50
    _current_ui_state = UISceneState.LOADING
    option_container.visible = false
    training_panel.visible = false
    rescue_panel.visible = false
    # shop_panel.visible = false   # **删除这行**——因为shop_panel还没显示，不需要先隐藏
    enemy_info_panel.visible = false
    panel.visible = true
    panel.z_index = 100
    print("[RunMain] 模态面板显示: %s" % panel.name)
```

### 验证方法

1. 进入救援层 → 选择伙伴 → 商店面板弹出
2. 观察关闭按钮是否在面板最底部，和商品列表之间有明显间距
3. 点击关闭按钮，看控制台是否有 `[RunMain] 商店关闭` 输出
4. 如果还有点不了，检查 ContentVBox 的 `mouse_filter` 是否为 PASS（VBoxContainer 默认 PASS，不拦截点击）

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/run_main/run_main.tscn` | ShopPanel内部改为VBoxContainer自动布局，删除手动offset |
| 2 | `scenes/run_main/run_main.gd` | 更新shop_item_container和shop_gold_label的节点路径 |

---

## 禁止事项

1. **禁止**手动计算 offset 值来定位关闭按钮，必须用 VBoxContainer 自动排列
2. **禁止**给 ShopItemContainer 设置固定高度，必须用 `size_flags_vertical = 3` 让它自适应
3. **禁止**修改 ShopPanel 在 RunMain 中的位置和大小（offset_left/top/right/bottom 保持 440/200/840/480）
