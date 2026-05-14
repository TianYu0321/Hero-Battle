# 视觉/音频框架完善任务卡（方案C：混合方案）

## 核心思路
- **血条**：复制 Progress-bar-shader shader代码，纯shader无依赖
- **设置界面**：安装 basic-settings-menu 插件，开箱即用
- **占位图**：自己写 `draw_*()`，完全可控，美术出图后替换成本最低
- **主菜单背景**：自己写 `ParallaxBackground` + `CPUParticles2D`，Godot原生无依赖
- **动画**：复制 TweenFX 关键代码片段，不需要完整插件

---

## 任务1：血条样式重制（shader方案，2h）

### 来源
借鉴 **Progress-bar-shader**（5种血条样式 + 特效）

### 实现

**Step 1：新建血条shader**

文件：`shaders/health_bar.gdshader`

```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_low : source_color = vec4(1.0, 0.0, 0.0, 1.0);   // 红色（低血量）
uniform vec4 color_mid : source_color = vec4(1.0, 0.84, 0.0, 1.0);  // 黄色（中血量）
uniform vec4 color_high : source_color = vec4(0.2, 0.8, 0.3, 1.0);  // 绿色（高血量）
uniform float flash_speed : hint_range(0.0, 10.0) = 0.0;  // 低血量闪烁速度

void fragment() {
    vec2 uv = UV;
    
    // 根据进度裁剪
    if (uv.x > progress) {
        discard;
    }
    
    // 颜色渐变：红→黄→绿
    vec4 final_color;
    if (progress < 0.3) {
        final_color = mix(color_low, color_mid, progress / 0.3);
    } else {
        final_color = mix(color_mid, color_high, (progress - 0.3) / 0.7);
    }
    
    // 低血量闪烁
    if (progress < 0.3 && flash_speed > 0.0) {
        float flash = abs(sin(TIME * flash_speed));
        final_color = mix(final_color, vec4(1.0, 1.0, 1.0, 1.0), flash * 0.3);
    }
    
    COLOR = final_color;
}
```

**Step 2：应用到战斗面板**

文件：`scenes/run_main/battle_animation_panel.tscn`

```
HeroHpBar (TextureProgressBar 或 ColorRect)
  - material: ShaderMaterial
  - shader: res://shaders/health_bar.gdshader
EnemyHpBar (同上)
```

**Step 3：代码中更新进度**

文件：`scenes/run_main/battle_animation_panel.gd`

```gdscript
func _update_hp_display() -> void:
    var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
    var enemy_ratio: float = float(_enemy_hp) / maxi(1, _enemy_max_hp)
    
    # 通过shader uniform更新进度
    hero_hp_bar.material.set_shader_parameter("progress", hero_ratio)
    enemy_hp_bar.material.set_shader_parameter("progress", enemy_ratio)
    
    # 低血量时开启闪烁
    hero_hp_bar.material.set_shader_parameter("flash_speed", 5.0 if hero_ratio < 0.3 else 0.0)
```

---

## 任务2：设置界面（插件方案，2h）

### 来源
安装 **basic-settings-menu** 插件

### 实现

**Step 1：安装插件**

Godot编辑器 → AssetLib → 搜索 "basic settings menu" → 下载安装

**Step 2：配置设置项**

文件：`scenes/settings/settings_panel.gd`

```gdscript
extends Control

@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var ui_slider: HSlider = $VBoxContainer/UISlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var ambient_slider: HSlider = $VBoxContainer/AmbientSlider
@onready var shake_toggle: CheckButton = $VBoxContainer/ShakeToggle
@onready var damage_toggle: CheckButton = $VBoxContainer/DamageToggle

func _ready() -> void:
    # 加载保存的设置
    sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
    ui_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")))
    music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
    
    # 连接信号
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)
    ui_slider.value_changed.connect(_on_ui_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    shake_toggle.toggled.connect(_on_shake_toggled)
    damage_toggle.toggled.connect(_on_damage_toggled)

func _on_sfx_volume_changed(value: float) -> void:
    AudioManager.set_bus_volume("SFX", linear_to_db(value))
    save_settings()

func _on_ui_volume_changed(value: float) -> void:
    AudioManager.set_bus_volume("UI", linear_to_db(value))
    save_settings()

func _on_music_volume_changed(value: float) -> void:
    AudioManager.set_bus_volume("Music", linear_to_db(value))
    save_settings()

func _on_shake_toggled(enabled: bool) -> void:
    GameManager.screen_shake_enabled = enabled
    save_settings()

func _on_damage_toggled(enabled: bool) -> void:
    GameManager.damage_numbers_enabled = enabled
    save_settings()

func save_settings() -> void:
    var settings: Dictionary = {
        "sfx_volume": sfx_slider.value,
        "ui_volume": ui_slider.value,
        "music_volume": music_slider.value,
        "screen_shake": shake_toggle.button_pressed,
        "damage_numbers": damage_toggle.button_pressed
    }
    SaveManager.save_settings(settings)

func load_settings() -> void:
    var settings := SaveManager.load_settings()
    sfx_slider.value = settings.get("sfx_volume", 0.8)
    ui_slider.value = settings.get("ui_volume", 0.8)
    music_slider.value = settings.get("music_volume", 0.5)
    shake_toggle.button_pressed = settings.get("screen_shake", true)
    damage_toggle.button_pressed = settings.get("damage_numbers", true)
```

**Step 3：主菜单添加设置按钮**

文件：`scenes/main_menu/menu.gd`

```gdscript
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel

func _ready() -> void:
    settings_button.pressed.connect(_on_settings_pressed)
    settings_panel.visible = false

func _on_settings_pressed() -> void:
    AudioManager.play_sfx("ui_click")
    settings_panel.visible = true
    settings_panel.load_settings()
```

---

## 任务3：占位图程序化生成（自己写，2h）

### 来源
借鉴 **PrototypeSprite3D** 思路，自己实现

### 实现

**Step 1：英雄占位图**

文件：`scenes/run_main/battle_animation_panel.gd`

```gdscript
func _draw_hero_placeholder(pos: Vector2, size: Vector2, hero_id: int, is_alive: bool) -> void:
    var color: Color = Color(0.2, 0.6, 0.9) if is_alive else Color(0.3, 0.3, 0.3)
    var center: Vector2 = pos + size / 2
    var radius: float = min(size.x, size.y) / 2 - 5
    
    # 外圈发光边框
    draw_circle(center, radius + 3, Color(color.r, color.g, color.b, 0.3))
    # 主体圆形
    draw_circle(center, radius, color)
    # 内部几何图案区分英雄
    match hero_id:
        1:  # 战士 - 十字
            draw_line(center - Vector2(radius*0.5, 0), center + Vector2(radius*0.5, 0), Color.WHITE, 3)
            draw_line(center - Vector2(0, radius*0.5), center + Vector2(0, radius*0.5), Color.WHITE, 3)
        2:  # 法师 - 六角星
            draw_polygon(_get_star_points(center, radius*0.6, 6), Color.WHITE)
        3:  # 游侠 - 三角
            draw_polygon([center + Vector2(0, -radius*0.6), center + Vector2(-radius*0.5, radius*0.4), center + Vector2(radius*0.5, radius*0.4)], Color.WHITE)
    
    # 死亡时加X标记
    if not is_alive:
        draw_line(center - Vector2(radius*0.5, radius*0.5), center + Vector2(radius*0.5, radius*0.5), Color.RED, 4)
        draw_line(center + Vector2(-radius*0.5, radius*0.5), center + Vector2(radius*0.5, -radius*0.5), Color.RED, 4)
```

**Step 2：敌人占位图**

```gdscript
func _draw_enemy_placeholder(pos: Vector2, size: Vector2, enemy_type: String, is_boss: bool) -> void:
    var color: Color
    match enemy_type:
        "slime": color = Color(0.4, 0.8, 0.2)      # 史莱姆 - 绿
        "demon": color = Color(0.8, 0.2, 0.2)      # 恶魔 - 红
        "heavy": color = Color(0.5, 0.5, 0.6)      # 重甲 - 灰
        _: color = Color(0.6, 0.1, 0.1)            # 默认 - 暗红
    
    if is_boss:
        color = Color(0.9, 0.1, 0.9)  # Boss - 紫色
    
    var center: Vector2 = pos + size / 2
    var radius: float = min(size.x, size.y) / 2 - 5
    
    # 外圈
    draw_circle(center, radius + (5 if is_boss else 2), Color(color.r, color.g, color.b, 0.5))
    # 主体
    draw_circle(center, radius, color)
    # Boss加皇冠标记
    if is_boss:
        draw_polygon([
            center + Vector2(0, -radius*0.8),
            center + Vector2(-radius*0.3, -radius*0.5),
            center + Vector2(radius*0.3, -radius*0.5)
        ], Color(1, 0.84, 0))
```

**Step 3：伙伴占位图**

```gdscript
func _draw_partner_placeholder(pos: Vector2, size: Vector2, partner_level: int, is_active: bool) -> void:
    var color: Color = Color(0.3, 0.7, 0.9) if is_active else Color(0.3, 0.3, 0.3)
    var center: Vector2 = pos + size / 2
    var radius: float = min(size.x, size.y) / 2 - 2
    
    # 小圆形
    draw_circle(center, radius, color)
    # 等级角标
    draw_circle(center + Vector2(radius*0.7, -radius*0.7), 8, Color(0.2, 0.2, 0.2))
    draw_string(ThemeDB.fallback_font, center + Vector2(radius*0.7, -radius*0.7) + Vector2(-3, 3), str(partner_level), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)
```

**替换说明：**
美术出图后，只需把 `draw_*` 替换为 `draw_texture(texture, pos)`，其他逻辑不变。

---

## 任务4：主菜单背景（自己写，2h）

### 来源
借鉴 **Godot 4 Main Menu Template** 结构

### 实现

**Step 1：新建背景场景**

文件：`scenes/main_menu/menu_background.tscn`

```
CanvasLayer (z_index = -1)
  ColorRect (全屏渐变背景)
    color: Color(0.05, 0.05, 0.15, 1) → Color(0, 0, 0, 1) 渐变
  CPUParticles2D (火星粒子)
    amount: 100
    lifetime: 3.0
    emission_shape: CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    emission_rect_extents: Vector2(600, 400)
    direction: Vector2(0, -1)
    spread: 20
    gravity: Vector2(0, -20)
    initial_velocity_min: 20
    initial_velocity_max: 50
    scale_amount_min: 0.5
    scale_amount_max: 2.0
    color: Color(1, 0.5, 0, 0.8)
    color_ramp: Gradient (橙→红→透明)
  ParallaxBackground
    ParallaxLayer (motion_scale = Vector2(0.3, 0.3))
      Sprite2D (远景建筑剪影，modulate暗色)
    ParallaxLayer (motion_scale = Vector2(0.6, 0.6))
      Sprite2D (中景，较亮)
```

**Step 2：添加到主菜单**

文件：`scenes/main_menu/menu.tscn`

```
Control (根节点)
  MenuBackground (instance)  ← 新增
  TitleLabel
  ButtonContainer
    NewGameButton
    ContinueButton
    PVPButton
    ShopButton
    SettingsButton
    QuitButton
```

---

## 任务5：动画Tween片段（自己写，2h）

### 来源
借鉴 **TweenFX** 关键代码片段

### 实现

**Step 1：暴击伤害数字动画**

文件：`scenes/run_main/battle_animation_panel.gd`

```gdscript
func _show_damage_number(damage: int, is_crit: bool, is_miss: bool, is_chain: bool = false, chain_count: int = 0) -> void:
    var label := Label.new()
    label.text = str(damage)
    label.position = Vector2(randf_range(200, 400), 300)
    
    if is_crit:
        label.add_theme_font_size_override("font_size", 36)
        label.modulate = Color(1, 0.2, 0.2)
        
        # 暴击动画：缩放弹跳
        var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        label.scale = Vector2.ZERO
        tween.tween_property(label, "scale", Vector2.ONE * 1.5, 0.15)
        tween.tween_property(label, "scale", Vector2.ONE, 0.1)
        
        # 屏幕震动
        _screen_shake()
    
    elif is_chain:
        label.text = "CHAIN x%d! %d" % [chain_count, damage]
        label.modulate = Color(0.8, 0.2, 1.0)
        
        # 连锁动画：旋转上飘
        var tween := create_tween()
        tween.tween_property(label, "position:y", label.position.y - 100, 0.8)
        tween.parallel().tween_property(label, "rotation", 0.17, 0.8)  # 10度
        tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
    
    else:
        label.add_theme_font_size_override("font_size", 26)
        label.modulate = Color(1, 0.9, 0.4)
        
        # 普通动画：抛物线上飘
        var tween := create_tween()
        tween.tween_property(label, "position:y", label.position.y - 60, 0.5)
        tween.tween_property(label, "position:y", label.position.y - 50, 0.3)
        tween.tween_property(label, "modulate:a", 0.0, 0.5)
    
    add_child(label)
```

**Step 2：按钮悬停动画**

文件：`scenes/main_menu/menu.gd`

```gdscript
func _setup_button_hover(button: Button) -> void:
    button.mouse_entered.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2.ONE * 1.05, 0.15)
        tween.parallel().tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.15)
    )
    button.mouse_exited.connect(func():
        var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2.ONE, 0.15)
        tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.15)
    )
```

**Step 3：面板弹出动画**

```gdscript
func _show_panel(panel: Control) -> void:
    panel.visible = true
    panel.scale = Vector2(0.8, 0.8)
    panel.modulate.a = 0.0
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(panel, "scale", Vector2.ONE, 0.2)
    tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
```

**Step 4：狂暴红色边框脉冲**

文件：`scenes/run_main/battle_animation_panel.gd`

```gdscript
func _start_frenzy_border_pulse() -> void:
    var border := $FrenzyBorder  # ColorRect 覆盖全屏，只在边框可见
    border.visible = true
    border.color = Color(1, 0, 0, 0)
    
    var tween := create_tween().set_loops()
    tween.tween_property(border, "color:a", 0.3, 0.5)
    tween.tween_property(border, "color:a", 0.0, 0.5)
```

---

## 文件清单
| # | 文件 | 修改/新建内容 |
|:---:|:---|:---|
| 1 | `shaders/health_bar.gdshader` | 新建，血条shader（红→黄→绿渐变+低血量闪烁） |
| 2 | `scenes/run_main/battle_animation_panel.tscn` | 应用shader到HeroHpBar/EnemyHpBar |
| 3 | `scenes/run_main/battle_animation_panel.gd` | _update_hp_display() 更新shader uniform |
| 4 | `scenes/settings/settings_panel.tscn` | 新建（或插件生成） |
| 5 | `scenes/settings/settings_panel.gd` | 音量/震动/伤害数字设置逻辑 |
| 6 | `scenes/main_menu/menu.gd` | 添加设置按钮和设置面板入口 |
| 7 | `scenes/main_menu/menu_background.tscn` | 新建，动态背景+粒子+视差 |
| 8 | `scenes/main_menu/menu.tscn` | 添加MenuBackground实例 |
| 9 | `scenes/run_main/battle_animation_panel.gd` | 占位图draw函数 + Tween动画片段 |
| 10 | `autoload/audio_manager.gd` | 验证触发点完整性 |

## 验收标准
- [ ] 血条：红→黄→绿渐变，低血量闪烁，shader实现
- [ ] 设置界面：音量四滑块有效，设置持久化保存
- [ ] 占位图：英雄/敌人/伙伴有形状区分，不是纯色方块
- [ ] 主菜单背景：有粒子+视差滚动，不是纯色
- [ ] 动画：暴击缩放弹跳、连锁旋转上飘、按钮悬停放大、面板弹出淡入
- [ ] 狂暴：红色边框脉冲
- [ ] 音效：所有触发点有日志输出（占位生效）
