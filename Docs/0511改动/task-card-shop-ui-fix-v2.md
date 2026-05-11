# 商店UI修复任务卡（精确版 v2）

> 只修复当前报告的2个具体问题，不改其他文件。

---

## 问题分析

**用户报告**：
1. 关闭按钮还是不能点击
2. 按钮布局已超出背景框（ShopPanel）

**根因（两个问题的共同根因）**：

ShopPanel 当前尺寸 400×280（宽×高），内部 ContentVBox 可用高度约 260px（减去 padding）。

内容占用：
- TitleLabel：~30px
- GoldDisplayLabel：~20px
- CloseButton：~40px
- 3个间距（VBoxContainer separation=4）：~12px
- ShopItemContainer 剩余分配空间：260 - 30 - 20 - 40 - 12 = **158px**

但 ShopItemButton 每个高 **60px**（custom_minimum_size），3个商品按钮总高 = 180px + 间距 > **158px**。VBoxContainer 尊重子节点的 custom_minimum_size，导致按钮向下**溢出**，覆盖在 CloseButton 之上。

溢出的 ShopItemButton 仍在屏幕上可见且可点击，它们的点击区域遮挡了 CloseButton，导致：
- **视觉上**：商品按钮超出 ShopPanel 底部边界
- **交互上**：点击 CloseButton 的位置实际点到了溢出的 ShopItemButton，CloseButton 接收不到点击事件

---

## 修复方案

### 修复1：增大 ShopPanel 高度（tscn）

ShopPanel 当前：
```
offset_left = 440.0
offset_top = 200.0
offset_right = 840.0
offset_bottom = 480.0    # 高 = 280
```

改为：
```
offset_left = 440.0
offset_top = 140.0       # 上移60px
offset_right = 840.0
offset_bottom = 540.0    # 下移60px，高 = 400
```

这样 ContentVBox 内部可用高度 = 400 - 20 = **380px**，足够放下所有内容。

### 修复2：减小 ShopItemButton 高度（tscn）

ShopItemButton 当前：
```
custom_minimum_size = Vector2(360, 60)
```

改为：
```
custom_minimum_size = Vector2(360, 50)
```

3个按钮总高 = 150px + 间距，加上其他元素约 250px，远小于 380px，不会溢出。

### 修复3：确保 UIModalBlocker 拦截底层点击（tscn）

UIModalBlocker 当前只设置了 `color = Color(0, 0, 0, 0.3)`，但 `mouse_filter` 默认是 PASS（点击会穿透到下层）。改为 STOP，确保模态显示时底层真的点不了。

```
[node name="UIModalBlocker" type="ColorRect" parent="."]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.3)
mouse_filter = 1           # **新增**：STOP，拦截所有点击
```

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scenes/run_main/run_main.tscn` | ShopPanel offset_top 200→140，offset_bottom 480→540（高从280→400） |
| 2 | `scenes/run_main/shop_item_button.tscn` | custom_minimum_size (360,60) → (360,50) |
| 3 | `scenes/run_main/run_main.tscn` | UIModalBlocker 添加 mouse_filter = 1 |

---

## 验收标准

- [ ] 商店面板能完整显示：标题 + 金币 + 商品列表 + 关闭按钮，都不超出面板边界
- [ ] 3个商品按钮整齐排列，按钮底部和关闭按钮之间有明显间距
- [ ] 点击关闭按钮，控制台输出 `[RunMain] 商店关闭`
- [ ] 点击商品按钮购买，功能正常，购买后对应按钮变"已售出"
- [ ] 商店打开时，底层4选项按钮无法点击（半透明遮罩生效）

---

## 禁止事项

1. **禁止**手动用 offset 定位 CloseButton，保持 VBoxContainer 自动排列
2. **禁止**修改 ContentVBox 的结构或子节点顺序
3. **禁止**修改 ShopItemButton 的 InfoContainer/PriceLabel 内部布局
