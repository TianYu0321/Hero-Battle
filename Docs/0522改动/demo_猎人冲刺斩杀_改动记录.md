# Demo 猎人冲刺斩杀动画 — 改动记录

> 状态：调试中（Demo 定版后同步到 `battle_animation_panel.gd`）

---

## 一、Demo 场景改动

### 1. `scenes/demo/battle_actor_demo.tscn`

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| `BtnSupport` | `text` | `支援登场` | `猎人斩杀` |
| `BtnSupport` | `theme_override_colors/font_color` | `Color(0.28, 0.6, 0.82)` | `Color(0.75, 0.35, 0.9)` |
| `BtnSupport` | 信号连接 | `_on_support_pressed` | `_on_hunter_assist_pressed` |

### 2. `scenes/demo/battle_actor_demo.gd`

#### 新增变量
```gdscript
var _hunter_poses: Dictionary[String, Texture2D] = {}
```

#### `_ready()` 末尾新增加载
```gdscript
var _hunter_idle := _load_tex("assets/characters/partner/hunter/idle/idle.png")
var _hunter_ready := _load_tex("assets/characters/partner/hunter/ready/ready.png")
var _hunter_action := _load_tex("assets/characters/partner/hunter/action/action.png")
if _hunter_idle != null: _hunter_poses["idle"] = _hunter_idle
if _hunter_ready != null: _hunter_poses["ready"] = _hunter_ready
if _hunter_action != null: _hunter_poses["action"] = _hunter_action
```

#### 新增辅助函数 `_switch_partner_pose()`
- 切换 Sprite2D texture 时按尺寸差异补偿位移，保持角色中心近似不变

#### 删除旧函数 `_on_support_pressed()`
- 原「支援登场」动画（滑入→弹跳→治疗→滑出）已移除

#### 新增核心函数 `_on_hunter_assist_pressed()`
- **前提检查**：素材未加载完整时直接 return
- **scale**：`0.8`（从 `1.5` 下调）
- **动画流程**：
  1. `0.1s` 淡入 → 切换 `ready`（冲刺姿态）
  2. `0.22s` 高速冲刺到敌人位置（Quad EaseIn）
  3. 到达瞬间：切换 `action`（斩击姿态）+ `screen_shake(12, 0.2)` + `_flash_sprite(enemy)` + 伤害数字 + 拟声词「斩！」+ 敌人受击动画
  4. `0.18s` 穿出画面右侧（Quad EaseOut）+ 淡出删除
  5. 敌人回 idle

---

## 二、正式面板已预改（待 Demo 定版后确认）

### `scenes/run_main/battle_animation_panel.gd`

- 新增 `_hunter_poses` 变量
- `_ready()` 调用 `_load_hunter_poses()`
- `partner_assist` 事件：伙伴名为「猎人」时走 `_play_hunter_dash_slash()`
- 新增 `_load_hunter_poses()` / `_play_hunter_dash_slash()` / `_switch_partner_pose()`
- **注意**：正式面板里 scale 也改成了 `0.8`，若 Demo 定版时 scale 有变，需同步更新

---

## 三、素材清单

```
assets/characters/partner/hunter/
├── idle/idle.png      (600x480)  待机/登场姿态
├── ready/ready.png    (600x480)  冲刺姿态
└── action/action.png  (1000x480) 斩击姿态（含刀光）
```

---

## 四、待确认项（Demo 测试后决定）

- [ ] scale `0.8` 是否合适
- [ ] 冲刺时长 `0.22s` / 穿出时长 `0.18s` 节奏
- [ ] 起始/结束偏移距离 `700px`
- [ ] 是否需要加入 `VFX.create_dash_trail()` 拖尾粒子
- [ ] 是否需要 `VFX.freeze_frame()` 打击停顿
- [ ] 斩击特效（energy_burst / combo_ring）是否需要在 Demo 里用本地代码模拟
- [ ] 拟声词「斩！」的颜色 `#BF4DE6`
- [ ] `_switch_partner_pose()` 的尺寸补偿是否足够（action.png 比 idle 宽 400px）
