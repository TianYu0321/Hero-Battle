# 任务卡：局外商店（主菜单独立入口）

> 入口：主菜单"商店"按钮
> 货币：魔城币
> 商品：伙伴（角色后续扩展）

---

## 需求

1. 主菜单增加"商店"按钮
2. 点击进入商店场景
3. 商店显示当前魔城币余额
4. 商品列表：可解锁的伙伴（用魔城币购买）
5. 购买后伙伴解锁，可在新游戏中选择
6. 魔城币不足时按钮置灰

---

## 当前状态

- `SaveManager` 已有 `spend_mocheng_coin(amount)` 接口
- `SaveManager.load_player_data()` 返回的数据包含 `unlocked_partners: []`
- 主菜单没有"商店"按钮
- 没有商店场景

---

## 修复步骤

### Step 1：主菜单添加"商店"按钮

**文件：`scenes/main_menu/menu.gd`**

```gdscript
@onready var _btn_shop: Button = %BtnShop

func _ready() -> void:
    ...
    _btn_shop.pressed.connect(_on_shop_pressed)
    ...

func _on_shop_pressed() -> void:
    print("[MainMenu] 商店按钮点击")
    EventBus.shop_requested.emit()
```

**文件：`scenes/main_menu/menu.tscn`**（添加 BtnShop 按钮）

### Step 2：EventBus 新增信号

**文件：`autoload/event_bus.gd`**

```gdscript
signal shop_requested
```

### Step 3：GameManager 订阅信号

**文件：`autoload/game_manager.gd`**

```gdscript
func _ready() -> void:
    ...
    EventBus.shop_requested.connect(_on_shop_requested)

func _on_shop_requested() -> void:
    change_scene("SHOP", "fade")
```

### Step 4：新建商店场景

**新建文件：`scenes/shop/shop.tscn`**

```
ShopScene (Control)
├── Background (ColorRect/TextureRect)
├── TitleLabel (Label)              # "商店"
├── CoinDisplay (Label)             # "魔城币: X"
├── ShopItemContainer (VBoxContainer)  # 商品列表
│   └── ShopItemRow (HBoxContainer)   # 每个商品一行
│       ├── Icon (TextureRect)
│       ├── NameLabel (Label)       # "剑士伙伴"
│       ├── DescLabel (Label)       # "擅长属性: 体魄"
│       ├── PriceLabel (Label)      # "100魔城币"
│       └── BuyButton (Button)      # "购买" / "已拥有"
├── BackButton (Button)             # "返回主菜单"
└── InsufficientCoinLabel (Label)   # "魔城币不足"（默认隐藏）
```

**新建文件：`scenes/shop/shop.gd`**

```gdscript
class_name ShopScene
extends Control

@onready var coin_display: Label = $CoinDisplay
@onready var shop_container: VBoxContainer = $ShopItemContainer
@onready var back_button: Button = $BackButton
@onready var insufficient_label: Label = $InsufficientCoinLabel

var _player_data: Dictionary = {}
var _shop_items: Array[Dictionary] = []

func _ready() -> void:
    _load_player_data()
    _load_shop_items()
    _render_shop()
    _update_coin_display()
    
    back_button.pressed.connect(_on_back)

func _load_player_data() -> void:
    _player_data = SaveManager.load_player_data()
    if _player_data.is_empty():
        _player_data = {
            "mocheng_coin": 0,
            "unlocked_partners": [],
        }

func _load_shop_items() -> void:
    # 从配置读取可购买的伙伴列表
    var all_partners: Array[Dictionary] = ConfigManager.get_all_partner_configs()
    var unlocked: Array = _player_data.get("unlocked_partners", [])
    
    _shop_items.clear()
    for p in all_partners:
        var pid: String = str(p.get("id", ""))
        var is_unlocked: bool = pid in unlocked
        var price: int = p.get("unlock_price_mocheng", 100)  # 默认100魔城币
        
        _shop_items.append({
            "partner_id": pid,
            "name": p.get("name", "???"),
            "desc": "擅长属性: %s" % _attr_name(p.get("favored_attr", 1)),
            "price": price,
            "is_unlocked": is_unlocked,
        })

func _attr_name(attr_id: int) -> String:
    match attr_id:
        1: return "体魄"
        2: return "力量"
        3: return "敏捷"
        4: return "技巧"
        5: return "精神"
    return "???"

func _render_shop() -> void:
    # 清空旧条目
    for child in shop_container.get_children():
        child.queue_free()
    
    var current_coin: int = _player_data.get("mocheng_coin", 0)
    
    for item in _shop_items:
        var row := HBoxContainer.new()
        
        var name_label := Label.new()
        name_label.text = item["name"]
        name_label.custom_minimum_size = Vector2(120, 0)
        row.add_child(name_label)
        
        var desc_label := Label.new()
        desc_label.text = item["desc"]
        desc_label.custom_minimum_size = Vector2(150, 0)
        row.add_child(desc_label)
        
        var price_label := Label.new()
        price_label.text = "%d魔城币" % item["price"]
        price_label.custom_minimum_size = Vector2(100, 0)
        row.add_child(price_label)
        
        var buy_btn := Button.new()
        if item["is_unlocked"]:
            buy_btn.text = "已拥有"
            buy_btn.disabled = true
        elif current_coin < item["price"]:
            buy_btn.text = "购买"
            buy_btn.disabled = true
            buy_btn.modulate = Color(0.5, 0.5, 0.5)
        else:
            buy_btn.text = "购买"
            buy_btn.pressed.connect(_on_buy.bind(item))
        row.add_child(buy_btn)
        
        shop_container.add_child(row)

func _on_buy(item: Dictionary) -> void:
    var price: int = item["price"]
    var pid: String = item["partner_id"]
    
    if not SaveManager.spend_mocheng_coin(price):
        insufficient_label.visible = true
        print("[Shop] 购买失败: 魔城币不足")
        return
    
    # 解锁伙伴
    var unlocked: Array = _player_data.get("unlocked_partners", [])
    if not pid in unlocked:
        unlocked.append(pid)
    _player_data["unlocked_partners"] = unlocked
    SaveManager.save_player_data(_player_data)
    
    print("[Shop] 购买成功: %s, 花费%d魔城币" % [item["name"], price])
    
    # 刷新界面
    _load_player_data()
    _load_shop_items()
    _render_shop()
    _update_coin_display()
    insufficient_label.visible = false

func _update_coin_display() -> void:
    var coin: int = _player_data.get("mocheng_coin", 0)
    coin_display.text = "魔城币: %d" % coin

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
```

### Step 5：ConfigManager 增加伙伴解锁价格配置

**文件：`autoload/config_manager.gd`**

在 `partner_configs.json` 中，每个伙伴增加 `unlock_price_mocheng` 字段：

```json
{
    "id": "1004",
    "name": "弓箭手",
    "favored_attr": 4,
    "unlock_price_mocheng": 150
}
```

如果没有该字段，默认100魔城币。

### Step 6：伙伴选择界面读取已解锁伙伴

**文件：`scenes/team_select/team_select.gd`**（或类似场景）

```gdscript
func _load_available_partners() -> Array[Dictionary]:
    var player_data: Dictionary = SaveManager.load_player_data()
    var unlocked: Array = player_data.get("unlocked_partners", [])
    
    var all_partners: Array[Dictionary] = ConfigManager.get_all_partner_configs()
    var available: Array[Dictionary] = []
    
    for p in all_partners:
        var pid: String = str(p.get("id", ""))
        # 初始伙伴默认解锁（如1001, 1002, 1003）
        var is_default: bool = pid in ["1001", "1002", "1003"]
        if is_default or pid in unlocked:
            available.append(p)
    
    return available
```

---

## 文件修改清单

| # | 文件 | 操作 | 修改内容 |
|:---:|:---|:---:|:---|
| 1 | `scenes/main_menu/menu.gd` | 修改 | 添加 `_btn_shop` 和 `_on_shop_pressed` |
| 2 | `scenes/main_menu/menu.tscn` | 修改 | 添加 BtnShop 按钮 |
| 3 | `autoload/event_bus.gd` | 修改 | 新增 `shop_requested` 信号 |
| 4 | `autoload/game_manager.gd` | 修改 | 订阅 `shop_requested`，切到商店场景 |
| 5 | `scenes/shop/shop.tscn` | 新建 | 商店场景 |
| 6 | `scenes/shop/shop.gd` | 新建 | 商店逻辑 |
| 7 | `resources/configs/partner_configs.json` | 修改 | 增加 `unlock_price_mocheng` 字段 |
| 8 | `scenes/team_select/team_select.gd` | 修改 | 读取已解锁伙伴过滤可用列表 |

---

## 验收标准

- [ ] 主菜单显示"商店"按钮
- [ ] 点击进入商店，显示当前魔城币余额
- [ ] 商店显示可购买的伙伴列表（名称、擅长属性、价格）
- [ ] 已拥有的伙伴显示"已拥有"且不可点击
- [ ] 魔城币不足的购买按钮置灰
- [ ] 点击购买后，魔城币扣除，按钮变"已拥有"
- [ ] 购买后返回主菜单，新游戏选伙伴时能看到新解锁的伙伴
- [ ] `player_data.json` 中 `unlocked_partners` 包含新伙伴ID
