# 任务卡：伙伴 UI 显示

## 背景

当前 `run_main.gd` 中有 `partner_container` 节点（参考之前的代码片段），但 `_update_partner_hud()` 可能只打印日志或为空，伙伴头像、等级/稀有度、技能触发状态完全没有显示。伙伴是爬塔核心辅助系统（救援招募、战斗连携、奥义触发），玩家需要随时知道带了谁、技能是否可用。

**目标**：在 run_main 默认界面添加常驻伙伴 HUD 条，显示已招募伙伴的头像、等级/稀有度、技能冷却/触发状态。

---

## 设计约束

- 分辨率：1920x1080（Stretch: canvas_items）
- 风格：延续暗黑霓虹（暗底 + 暗金边框 + 蓝绿激活态）
- 位置：屏幕右侧边缘（与左侧 4 选项按钮平衡），或底部横条（与顶部/中央信息区不冲突）
- 1280x720 缩放后仍可读

---

## 推荐布局方案（右侧竖条）

```
RunMain (Control, Full Rect)
├── ... (现有节点保持不变)
│
├── PartnerHUDLayer (CanvasLayer, layer=3)
│   └── PartnerPanel (VBoxContainer)
│       ├── PartnerTitle (Label, "随行伙伴")
│       ├── PartnerSlot_0 (PanelContainer)
│       │   ├── AvatarTexture (TextureRect, 48x48)
│       │   ├── RarityBadge (ColorRect, 4x48 左边框色条)
│       │   ├── NameLabel (Label)
│       │   ├── LevelLabel (Label, "Lv.3")
│       │   └── SkillGauge (ProgressBar, 高 4, 宽 100)
│       ├── PartnerSlot_1
│       ├── PartnerSlot_2
│       └── PartnerSlot_3
```

位置：
- `PartnerPanel` 锚点：`anchors_preset = 11` (Right Wide) 或 `anchors_preset = 1` (Top Right)
- `anchor_right = 1.0`，`offset_left = -200`，`offset_top = 120`，宽 180，高自适应
- 与左侧选项按钮区域（约 x=40~320）不重叠

---

## 节点属性

### PartnerPanel
- `anchors_preset = 1` (Top Right)
- `offset_left = -200`, `offset_top = 120`, `offset_right = -20`, `offset_bottom` 自适应
- `theme_override_constants/separation = 8`
- 背景：`StyleBoxFlat`，`bg_color = Color(0.06, 0.06, 0.08, 0.85)`，圆角 6px

### PartnerSlot_x (PanelContainer)
- `custom_minimum_size = Vector2(160, 56)`
- 默认边框：`StyleBoxFlat`，`border_color = Color(0.25, 0.25, 0.3, 0.5)`，`border_width_* = 1`
- Hover：`border_color = Color(0.35, 0.55, 0.85, 0.6)`（蓝）
- 内部 HBoxContainer：头像(48x48) + VBoxContainer（名字+等级+技能条）

### RarityBadge (左边框色条)
- 宽 4，高填满，表示稀有度：
  - C (普通)：灰 `#888888`
  - B (稀有)：绿 `#4ECDC4`
  - A (史诗)：蓝 `#5A8FD0`
  - S (传说)：暗金 `#E6C040`

### SkillGauge (ProgressBar)
- `custom_minimum_size = Vector2(100, 4)`
- 底色：`bg_color = Color(0.15, 0.15, 0.18, 1)`
- 填充色：
  - 充能中：`fill = Color(0.35, 0.55, 0.85, 0.8)`（蓝）
  - 可触发：`fill = Color(0.90, 0.75, 0.25, 1)`（暗金闪烁）
- 无动画，值变化用 Tween 0.3s

---

## 数据接口

### `RuntimePartner` 需要暴露（确认已有或新增）

```gdscript
class_name RuntimePartner
extends RefCounted

var partner_config_id: int = 0
var level: int = 1
var rarity: String = "C"  ## C/B/A/S
var skill_charge: int = 0       ## 当前充能
var skill_charge_max: int = 3   ## 满充能触发
var is_skill_ready: bool = false

## 以下从 ConfigManager 查
var name: String = "???"
var role: String = "???"
var avatar_path: String = ""      ## res://assets/partners/...
var skill_name: String = "???"
var skill_desc: String = "???"
```

### `CharacterManager` 需要暴露

```gdscript
func get_partners() -> Array[RuntimePartner]:
    ## 返回当前已招募伙伴列表（最多 4 个）
    return _partners.duplicate()

func get_partner_by_config_id(config_id: int) -> RuntimePartner:
    ## 按 config_id 查伙伴
    for p in _partners:
        if p.partner_config_id == config_id:
            return p
    return null
```

### `ConfigManager` 新增伙伴配置

```gdscript
static func get_partner_config(config_id: int) -> Dictionary:
    ## 返回伙伴静态配置
    ## {
    ##   "name": "烈焰拳手",
    ##   "role": "输出",
    ##   "rarity": "A",
    ##   "avatar_path": "res://assets/partners/fighter_avatar.png",
    ##   "skill_name": "烈焰连击",
    ##   "skill_desc": "战斗开始时概率发动额外攻击",
    ##   "skill_charge_max": 3,
    ## }
    return _partner_configs.get(str(config_id), {})

static func get_partner_avatar_path(config_id: int) -> String:
    var cfg := get_partner_config(config_id)
    return cfg.get("avatar_path", "res://assets/partners/default_avatar.png")

static func get_rarity_color(rarity: String) -> Color:
    match rarity:
        "S": return Color("#E6C040")  ## 暗金
        "A": return Color("#5A8FD0")  ## 蓝
        "B": return Color("#4ECDC4")  ## 青
        _:   return Color("#888888")  ## 灰
```

---

## UI 更新逻辑

### `run_main.gd` 中 `_update_partner_hud()` 完整实现

```gdscript
@onready var partner_panel: VBoxContainer = $PartnerHUDLayer/PartnerPanel

## 预先生成/复用 4 个 slot（避免运行中频繁实例化）
var _partner_slots: Array[Control] = []
var _max_partner_slots: int = 4

func _ready() -> void:
    ## ... 现有初始化 ...
    _init_partner_slots()
    EventBus.partner_unlocked.connect(_on_partner_unlocked)
    EventBus.partner_skill_triggered.connect(_on_partner_skill_triggered)
    EventBus.partner_charge_changed.connect(_on_partner_charge_changed)

func _init_partner_slots() -> void:
    ## 清空并创建 4 个占位 slot
    for child in partner_panel.get_children():
        if child.name != "PartnerTitle":
            child.queue_free()
    _partner_slots.clear()
    
    for i in range(_max_partner_slots):
        var slot := _create_partner_slot(i)
        partner_panel.add_child(slot)
        _partner_slots.append(slot)
        slot.visible = false  ## 默认隐藏

func _create_partner_slot(index: int) -> PanelContainer:
    var slot := PanelContainer.new()
    slot.name = "PartnerSlot_%d" % index
    slot.custom_minimum_size = Vector2(160, 56)
    
    var hbox := HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
    hbox.add_theme_constant_override("separation", 6)
    slot.add_child(hbox)
    
    ## 稀有度色条
    var rarity_badge := ColorRect.new()
    rarity_badge.name = "RarityBadge"
    rarity_badge.custom_minimum_size = Vector2(4, 48)
    rarity_badge.color = Color("#888888")
    hbox.add_child(rarity_badge)
    
    ## 头像
    var avatar := TextureRect.new()
    avatar.name = "Avatar"
    avatar.custom_minimum_size = Vector2(48, 48)
    avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hbox.add_child(avatar)
    
    ## 信息区
    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 2)
    hbox.add_child(vbox)
    
    var name_label := Label.new()
    name_label.name = "NameLabel"
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override("font_color", Color("#E6C040"))
    vbox.add_child(name_label)
    
    var level_label := Label.new()
    level_label.name = "LevelLabel"
    level_label.add_theme_font_size_override("font_size", 11)
    level_label.add_theme_color_override("font_color", Color("#888888"))
    vbox.add_child(level_label)
    
    ## 技能充能条
    var gauge := ProgressBar.new()
    gauge.name = "SkillGauge"
    gauge.custom_minimum_size = Vector2(90, 4)
    gauge.max_value = 3
    gauge.value = 0
    gauge.show_percentage = false
    ## 通过 add_theme_stylebox_override 设底色和填充色
    vbox.add_child(gauge)
    
    return slot

func _update_partner_hud() -> void:
    if _run_controller == null:
        return
    
    var partners: Array = _run_controller.get_partners()  ## 需要 RC 暴露
    
    for i in range(_max_partner_slots):
        var slot: Control = _partner_slots[i] if i < _partner_slots.size() else null
        if slot == null:
            continue
        
        if i < partners.size():
            var partner = partners[i]
            _fill_partner_slot(slot, partner)
            slot.visible = true
        else:
            slot.visible = false
    
    ## 总面板：有伙伴时显示，无伙伴时隐藏
    partner_panel.visible = (partners.size() > 0)

func _fill_partner_slot(slot: Control, partner) -> void:
    var hbox: HBoxContainer = slot.get_child(0)
    var rarity_badge: ColorRect = hbox.get_node("RarityBadge")
    var avatar: TextureRect = hbox.get_node("Avatar")
    var vbox: VBoxContainer = hbox.get_child(2)
    var name_label: Label = vbox.get_node("NameLabel")
    var level_label: Label = vbox.get_node("LevelLabel")
    var gauge: ProgressBar = vbox.get_node("SkillGauge")
    
    var config_id: int = partner.partner_config_id if partner.has("partner_config_id") else 0
    var cfg: Dictionary = ConfigManager.get_partner_config(config_id)
    
    ## 稀有度色条
    var rarity: String = partner.rarity if partner.has("rarity") else cfg.get("rarity", "C")
    rarity_badge.color = ConfigManager.get_rarity_color(rarity)
    
    ## 头像
    var avatar_path: String = cfg.get("avatar_path", "")
    if not avatar_path.is_empty():
        avatar.texture = load(avatar_path)
    else:
        avatar.texture = null  ## 显示占位色
    
    ## 名字
    var p_name: String = partner.name if partner.has("name") else cfg.get("name", "???")
    name_label.text = p_name
    
    ## 等级
    var level: int = partner.level if partner.has("level") else 1
    level_label.text = "Lv.%d | %s" % [level, cfg.get("role", "???")]
    
    ## 技能充能
    var charge: int = partner.skill_charge if partner.has("skill_charge") else 0
    var charge_max: int = partner.skill_charge_max if partner.has("skill_charge_max") else cfg.get("skill_charge_max", 3)
    gauge.max_value = charge_max
    
    ## Tween 动画更新充能条
    var old_val: float = gauge.value
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(gauge, "value", float(charge), 0.3)
    
    ## 颜色：满充能闪烁暗金
    if charge >= charge_max:
        _flash_gauge_ready(gauge)
    else:
        _stop_gauge_flash(gauge)
        _set_gauge_fill_color(gauge, Color("#5A8FD0"))  ## 蓝

func _flash_gauge_ready(gauge: ProgressBar) -> void:
    ## 暗金色闪烁：0.8s 周期
    if gauge.has_meta("flash_tween"):
        var old: Tween = gauge.get_meta("flash_tween")
        if old != null and old.is_valid():
            old.kill()
    
    var tween := create_tween().set_loops()
    tween.tween_callback(_set_gauge_fill_color.bind(gauge, Color("#E6C040")))
    tween.tween_interval(0.4)
    tween.tween_callback(_set_gauge_fill_color.bind(gauge, Color("#FFF0AA")))
    tween.tween_interval(0.4)
    gauge.set_meta("flash_tween", tween)

func _stop_gauge_flash(gauge: ProgressBar) -> void:
    if gauge.has_meta("flash_tween"):
        var old: Tween = gauge.get_meta("flash_tween")
        if old != null and old.is_valid():
            old.kill()
        gauge.remove_meta("flash_tween")

func _set_gauge_fill_color(gauge: ProgressBar, color: Color) -> void:
    var fill_style := StyleBoxFlat.new()
    fill_style.bg_color = color
    gauge.add_theme_stylebox_override("fill", fill_style)
```

### 事件响应

```gdscript
func _on_partner_unlocked(config_id: int, partner_name: String, slot_index: int, turn: int, role: String) -> void:
    ## 新伙伴加入，播放解锁动画
    _update_partner_hud()
    
    ## 飘字提示
    _show_floating_text("+%s 加入队伍！" % partner_name, Color("#4ECDC4"))
    
    ## 解锁的 slot 缩放弹出动画
    if slot_index >= 0 and slot_index < _partner_slots.size():
        var slot: Control = _partner_slots[slot_index]
        slot.scale = Vector2(0.5, 0.5)
        slot.modulate.a = 0.0
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(slot, "scale", Vector2.ONE, 0.4)
        tween.parallel().tween_property(slot, "modulate:a", 1.0, 0.3)

func _on_partner_skill_triggered(config_id: int, skill_name: String, effect_desc: String) -> void:
    ## 伙伴技能触发，战斗日志追加 + 飘字
    if battle_log != null and battle_log.visible:
        battle_log.append_text("\n[color=#4ECDC4]★ %s 触发 %s！[/color] %s\n" % [
            _get_partner_name(config_id), skill_name, effect_desc
        ])
    _show_floating_text("%s: %s" % [skill_name, effect_desc], Color("#E6C040"))

func _on_partner_charge_changed(config_id: int, current: int, max_charge: int) -> void:
    ## 充能变化（战斗结算后），只更新对应 slot
    _update_partner_hud()
```

### `run_controller.gd` 新增接口

```gdscript
func get_partners() -> Array:
    ## 返回已招募伙伴列表（RuntimePartner 或 Dictionary）
    return _character_manager.get_partners() if _character_manager != null else []
```

---

## 涉及文件

1. `scenes/run_main/run_main.tscn` — 添加 `PartnerHUDLayer` (CanvasLayer) + `PartnerPanel` (VBoxContainer)
2. `scenes/run_main/run_main.gd` — `_init_partner_slots()`、`_update_partner_hud()`、事件响应
3. `scripts/autoload/config_manager.gd` — 新增 `get_partner_config()`、`get_partner_avatar_path()`、`get_rarity_color()`
4. `scripts/systems/run_controller.gd` — 新增 `get_partners()`
5. `scripts/data/runtime_partner.gd` — 确认字段完整（如没有该文件需新建）
6. `scripts/systems/character_manager.gd` — 确认 `get_partners()` 返回正确类型

---

## 测试清单

- [ ] 未招募伙伴时 PartnerPanel 完全隐藏
- [ ] 招募第 1 个伙伴后，PartnerPanel 显示，slot 从 0.5 缩放弹出到 1.0
- [ ] 显示正确头像、名字、等级、定位（输出/坦克/辅助）
- [ ] 稀有度色条颜色正确：C=灰 B=青 A=蓝 S=暗金
- [ ] 招募第 2~4 个伙伴后纵向排列，间距 8px
- [ ] 技能充能条从 0 渐变到当前值（0.3s Tween）
- [ ] 充能未满时填充蓝色
- [ ] 充能满时填充暗金并闪烁（0.8s 周期）
- [ ] 战斗结算后充能条正确更新
- [ ] 伙伴触发技能时战斗日志追加绿色高亮行
- [ ] 1280x720 窗口下伙伴面板仍可读，不重叠左侧按钮
- [ ] 切换分辨率后布局自适应（CanvasLayer 不受 Stretch 影响，需手动处理）

---

## 后续扩展（当前不做，预留接口）

- 点击伙伴 slot 弹出详情面板：技能描述、升级路线、属性加成
- 伙伴升级消耗金币/材料（升级按钮 + 确认弹窗）
- 伙伴羁绊系统：特定组合触发额外效果，HUD 中显示羁绊图标
- 伙伴换装/皮肤：头像路径动态切换