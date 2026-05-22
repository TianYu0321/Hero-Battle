# 任务卡：主菜单 UI 改造 — 明亮纸片剧场风格

## 目标

将主菜单从暗黑霓虹风格改造为明亮纸片剧场风格：按钮白底实色+贴纸厚度感边框、Tween弹性动画、花瓣氛围粒子、大标题阴影浮起感。

---

## 涉及文件

1. `scenes/main_menu/menu.gd` — 按钮样式生成、Tween动画、氛围粒子初始化
2. `scenes/main_menu/menu.tscn` — 节点结构调整（删暗黑雾效节点、加粒子挂载点）
3. `resources/themes/menu_theme.tres` — **新建** Theme资源，统一管理按钮/标签/文字样式
4. `resources/shaders/title_glow.gdshader` — **新建** 可选标题微发光Shader

---

## Step 1：新建 Theme 资源文件（推荐先做）

文件：`resources/themes/menu_theme.tres`

在 Godot 编辑器中操作：
1. 文件系统面板 → 右键 → 新建资源 → Theme
2. 保存为 `res://resources/themes/menu_theme.tres`
3. 在 Inspector 中展开 Default Base Scale / Default Font / Default Font Size 按需设置

**Button 样式（4态）**：

| 态 | 背景色 | 边框色 | 边框宽度(左/上/右/下) | 圆角 | 阴影大小 | 阴影色 | 阴影偏移 |
|----|--------|--------|----------------------|------|---------|--------|---------|
| normal | `#FFFFFF` | `#333333` | 1/1/1/3 | 4 | 3 | `rgba(0,0,0,0.08)` | (0,2) |
| hover | `#FFF8F0` | `#FF6B35` | 1/1/1/3 | 4 | 6 | `rgba(0,0,0,0.12)` | (0,3) |
| pressed | `#F0E8E0` | `#CC5520` | 1/1/1/3 | 4 | 0 | — | — |
| disabled | `#F5F5F5` | `#CCCCCC` | 1/1/1/2 | 4 | 0 | — | — |
| focus | `#FFFFFF` | `#FF6B35` | 2/2/2/2 | 4 | 4 | `rgba(255,107,53,0.15)` | (0,0) |

**操作**：在 Theme Inspector → Add Item Type → Button → 分别添加 normal/hover/pressed/disabled/focus 的 StyleBoxFlat。

**Label 样式**：
- TitleLabel（大号标题）：font_size = 72，font_color = `#1A1A1A`，shadow_size = 2，shadow_offset = (0,3)，shadow_color = `rgba(0,0,0,0.1)`
- MenuButton（按钮文字）：font_size = 24，font_color = `#333333`
- VersionLabel（版本号）：font_size = 14，font_color = `#999999`
- SubTitle/Hint：font_size = 16，font_color = `#666666`

**操作**：Theme → Add Item Type → Label → 分别设置不同 Label 的 font / font_size / color（通过代码引用时指定 Theme Type Variation）。

**字体**：
- 英文数字标题：加载 `Oxanium-Bold.ttf`（或等宽无衬线粗体）
- 中文正文按钮：加载 `NotoSansSC-Medium.ttf`
- 如果没有字体文件，先用 Godot 内置默认字体，后续替换

---

## Step 2：改造 `menu.gd` — 按钮样式与动画

### 2.1 删除旧的暗黑主题常量（如有）

搜索并删除以下常量（或注释掉，保留备用）：
```gdscript
# 如果存在这些常量，删除或替换为明亮风格常量
# const COLOR_BG = Color(0.06, 0.06, 0.08, 0.7)
# const COLOR_BTN_BG = Color(0.10, 0.10, 0.12)
# const COLOR_BTN_TEXT = Color(0.90, 0.75, 0.25)
```

### 2.2 加载 Theme 资源

在 `_ready()` 顶部添加：
```gdscript
@onready var menu_theme: Theme = preload("res://resources/themes/menu_theme.tres")
```

### 2.3 改造 `_setup_button_style()` 函数

当前函数生成暗金风格按钮，改为应用 Theme：

```gdscript
func _setup_button_style(button: Button) -> void:
    button.theme = menu_theme
    button.add_theme_font_size_override("font_size", 24)
    
    ## 如果 Theme 里已设好，这行可以省略；如果 Theme 没设font，这里指定
    # button.add_theme_font_override("font", preload("res://fonts/NotoSansSC-Medium.ttf"))
    
    ## 连接信号（保持原有逻辑）
    button.mouse_entered.connect(_on_button_hover.bind(button))
    button.mouse_exited.connect(_on_button_unhover.bind(button))
    button.focus_entered.connect(_on_button_focus.bind(button))
    button.focus_exited.connect(_on_button_unfocus.bind(button))
```

### 2.4 新增 Hover / Unhover / Focus Tween 动画

```gdscript
func _on_button_hover(button: Button) -> void:
    if button.disabled:
        return
    ## 停止可能正在进行的回位 Tween
    if button.has_meta("hover_tween"):
        var old: Tween = button.get_meta("hover_tween")
        if old != null and old.is_valid():
            old.kill()
    
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", Vector2(1.02, 1.02), 0.12)
    button.set_meta("hover_tween", tween)

func _on_button_unhover(button: Button) -> void:
    if button.disabled:
        return
    if button.has_meta("hover_tween"):
        var old: Tween = button.get_meta("hover_tween")
        if old != null and old.is_valid():
            old.kill()
    
    var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", Vector2.ONE, 0.15)
    button.set_meta("hover_tween", tween)

func _on_button_focus(button: Button) -> void:
    ## 键盘导航选中时额外视觉反馈
    if button.disabled:
        return
    var tween := create_tween()
    tween.tween_property(button, "scale", Vector2(1.01, 1.01), 0.08)

func _on_button_unfocus(button: Button) -> void:
    var tween := create_tween()
    tween.tween_property(button, "scale", Vector2.ONE, 0.10)
```

### 2.5 改造按钮按下动画（弹性效果）

在 `_on_menu_button_pressed()` 或每个按钮的 `pressed` 信号回调中添加：

```gdscript
func _on_menu_button_pressed(button: Button) -> void:
    AudioManager.play_ui("confirm")
    
    ## 弹性点击动画：快速缩小 → 弹性回位
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.05)
    tween.tween_property(button, "scale", Vector2.ONE, 0.15)
    
    await tween.finished
    
    ## 原有逻辑：切换场景/打开面板等
    match button.name:
        "StartButton": _on_start_button_pressed()
        "ContinueButton": _on_continue_button_pressed()
        ## ... 其他按钮
```

### 2.6 标题动画（入场效果）

```gdscript
@onready var title_label: Label = $TitleLabel

func _ready() -> void:
    ## ... 原有代码 ...
    _animate_title_entrance()

func _animate_title_entrance() -> void:
    ## 初始状态：标题在上方 30px 外，透明度 0
    title_label.modulate.a = 0.0
    title_label.position.y -= 30
    
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
    tween.parallel().tween_property(title_label, "position:y", title_label.position.y + 30, 0.6)
```

---

## Step 3：改造 `menu.tscn` — 节点结构调整

### 3.1 删除/修改暗黑氛围节点

| 节点路径 | 当前状态 | 操作 |
|---------|---------|------|
| `BackgroundLayer/FogSprite` | 雾效，暗黑氛围 | **删除** 或 visible=false |
| `BackgroundLayer/FloorLightOverlay` | 底部暗金光带脉动 | **删除** 或改为微弱白色暖光 overlay |

如果保留 `FloorLightOverlay`：
- color 改为 `Color(1.0, 0.95, 0.90, 0.03)` — 极微弱的暖白光
- 脉动幅度降低（alpha 0.02 ~ 0.05）

### 3.2 新增氛围粒子挂载点

在 `BackgroundLayer` 下新增：
```
BackgroundLayer
├── BackgroundTexture (保留)
├── (删除) FogSprite
├── (可选保留/修改) FloorLightOverlay
└── AmbientParticles (Node2D)  ← 新增
```

### 3.3 标题节点调整

`TitleLabel`：
- `horizontal_alignment` = CENTER
- `vertical_alignment` = CENTER
- `add_theme_font_size_override` 在 Theme 中统一设置
- 如果有单独的 Shadow 节点（某些项目会用 Label 叠两层做阴影），可以删除，改用 Theme 的 shadow 属性

---

## Step 4：新增氛围粒子 — 樱花/彩纸飘落

在 `menu.gd` 中新增 `_start_ambient_particles()`：

```gdscript
@onready var ambient_particles: Node2D = $BackgroundLayer/AmbientParticles

func _start_ambient_particles() -> void:
    var particles := GPUParticles2D.new()
    particles.name = "SakuraParticles"
    particles.position = Vector2(960, -50)  ## 1920x1080 顶部中央
    particles.amount = 80
    particles.lifetime = 8.0
    particles.preprocess = 5.0
    particles.visibility_rect = Rect2(-200, -200, 2240, 1480)
    
    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(1200, 10, 1)
    mat.direction = Vector3(0, 1, 0)
    mat.spread = 20.0
    mat.initial_velocity_min = 30.0
    mat.initial_velocity_max = 80.0
    mat.gravity = Vector3(0, 20, 0)  ## 缓慢下落
    mat.scale_min = 0.5
    mat.scale_max = 1.5
    mat.angle_min = -180.0
    mat.angle_max = 180.0  ## 旋转飘落
    mat.angular_velocity_min = -30.0
    mat.angular_velocity_max = 30.0
    mat.color = Color(1.0, 0.72, 0.77, 0.6)  ## 樱花粉
    
    ## 花瓣纹理：用程序生成的小椭圆
    var petal_texture := GradientTexture2D.new()
    petal_texture.gradient = Gradient.new()
    petal_texture.gradient.colors = [Color(1, 0.8, 0.85, 0.7), Color(1, 0.7, 0.75, 0)]
    petal_texture.width = 8
    petal_texture.height = 12
    petal_texture.fill_from = Vector2(0.5, 0)
    petal_texture.fill_to = Vector2(0.5, 1)
    particles.texture = petal_texture
    
    particles.process_material = mat
    ambient_particles.add_child(particles)
    
    ## 可选：第二层白色光点（更稀疏，营造竞技场灯光尘埃感）
    var dust := GPUParticles2D.new()
    dust.name = "DustParticles"
    dust.position = Vector2(960, 0)
    dust.amount = 40
    dust.lifetime = 6.0
    dust.preprocess = 4.0
    dust.visibility_rect = Rect2(-200, -200, 2240, 1480)
    
    var dust_mat := ParticleProcessMaterial.new()
    dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    dust_mat.emission_box_extents = Vector3(1400, 10, 1)
    dust_mat.direction = Vector3(0.05, 1, 0)
    dust_mat.spread = 10.0
    dust_mat.initial_velocity_min = 20.0
    dust_mat.initial_velocity_max = 50.0
    dust_mat.gravity = Vector3(0, 10, 0)
    dust_mat.scale_min = 0.3
    dust_mat.scale_max = 0.8
    dust_mat.color = Color(1.0, 0.95, 0.85, 0.3)  ## 暖白尘埃
    
    var dust_texture := GradientTexture2D.new()
    dust_texture.gradient = Gradient.new()
    dust_texture.gradient.colors = [Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)]
    dust_texture.width = 4
    dust_texture.height = 4
    dust.texture = dust_texture
    
    dust.process_material = dust_mat
    ambient_particles.add_child(dust)
```

在 `_ready()` 末尾调用：
```gdscript
func _ready() -> void:
    ## ... 原有代码 ...
    _start_ambient_particles()
```

---

## Step 5：可选 — 标题微发光 Shader

如果不做 Shader，标题用 Theme shadow 就够了。如果要更精致：

新建 `resources/shaders/title_glow.gdshader`：
```glsl
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;
uniform vec4 glow_color : source_color = vec4(1.0, 0.42, 0.21, 1.0);  // #FF6B35

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    // 只对文字边缘发光：利用文字 alpha 的导数
    float alpha = tex.a;
    float edge = alpha * (1.0 - alpha) * 4.0;  // 边缘检测近似
    edge = pow(edge, 0.5);
    
    vec3 glow = glow_color.rgb * glow_intensity * edge;
    COLOR = vec4(tex.rgb + glow, alpha);
}
```

给 `TitleLabel` 添加 ShaderMaterial，设置 `glow_intensity = 0.1`，`glow_color = #FF6B35`（活力橙）。

**注意**：这个 Shader 对普通 Label 效果有限（文字边缘锐利），更适合有抗锯齿的较大字号。如果觉得效果不明显，跳过这一步，用 Theme shadow 足够。

---

## Step 6：背景过渡（临时方案）

如果新背景图还没到位：

1. 在 `.tscn` 中给 `BackgroundTexture` 设一个纯色占位：
   - 删除 texture 属性（或设为空）
   - 在 `BackgroundTexture` 同级加一个 `ColorRect`，anchors_preset=FullRect，color=`#FAF8F5`（淡米白）
   - `BackgroundTexture` 的 modulate 保持 `#FFFFFF`

2. 新背景图到位后：
   - 删除占位 `ColorRect`
   - 给 `BackgroundTexture.texture` 加载新图
   - `stretch_mode = KEEP_ASPECT_CENTERED`
   - `expand_mode = IGNORE_SIZE`

---

## Step 7：_ready() 调用顺序整理

```gdscript
func _ready() -> void:
    ## 1. 基础初始化（保持原有）
    _load_fx_config()
    
    ## 2. 标题入场动画
    _animate_title_entrance()
    
    ## 3. 设置按钮样式（用 Theme）
    for btn in menu_buttons:
        _setup_button_style(btn)
    
    ## 4. 氛围粒子
    _start_ambient_particles()
    
    ## 5. 原有逻辑：版本号、继续游戏按钮状态等
    ## ...
    
    ## 6. 背景特效（保留 FloorLightOverlay 微弱脉动，或删除）
    # _start_floor_pulse()  ## 如果保留，修改颜色为暖白
```

---

## 测试清单

- [ ] 主菜单背景为明亮色调（淡米白或新背景图），无暗黑雾效
- [ ] 按钮白底+深灰边框+底部加粗（贴纸厚度感）
- [ ] 按钮 hover 边框变活力橙 #FF6B35，scale 1.02，阴影扩散
- [ ] 按钮点击 scale 0.96 → 弹性回位 1.0（0.05s + 0.15s）
- [ ] 键盘导航时按钮有 focus 态边框（橙色 glow）
- [ ] 标题文字大粗体（72px），从上方滑入+淡入，有轻微阴影浮起感
- [ ] 版本号/次要文字小字灰色，不抢眼
- [ ] 氛围粒子：粉色花瓣缓慢旋转飘落（数量适中不遮挡按钮）
- [ ] 氛围粒子：暖白尘埃更稀疏，营造灯光感
- [ ] 按钮文字在白底上清晰可读（对比度足够）
- [ ] 继续游戏按钮在无存档时 disabled，样式正确（灰底灰边框）
- [ ] 分辨率 1280x720 和 1920x1080 下按钮布局无重叠
- [ ] 切换场景时 LoadingScreen 正常（不受风格改动影响）

---

## 注意事项

1. **Theme 资源优先**：尽量把样式写在 `.tres` Theme 里，代码只负责应用 Theme 和 Tween 动画。这样以后改风格只需改一个 `.tres` 文件。

2. **字体文件**：如果没有 `NotoSansSC-Medium.ttf` 或 `Oxanium-Bold.ttf`，先用 Godot 内置默认字体，文件到位后在 Theme 中替换 `default_font`。

3. **雾效删除确认**：删除 `FogSprite` 前先确认它没被其他代码引用（搜索 `FogSprite` 或 `fog_sprite`）。

4. **FloorLightOverlay**：如果决定删除，同时删除 `menu.gd` 中的 `_start_floor_pulse()` 函数和对应 `@onready` 引用。

5. **粒子性能**：`amount=80+40=120`，在低端设备上如果掉帧，减到 `50+20` 或关闭 `DustParticles`。