# Godot Warnings 清理任务卡

> 目标：清理运行时的 Godot 警告，提升代码质量和运行稳定性。

---

## 常见 GDScript Warning 类型（按优先级排序）

| 优先级 | Warning 类型 | 说明 | 常见修复方式 |
|:---:|:---|:---|:---|
| **高** | `UNUSED_VARIABLE` | 声明了变量但未使用 | 删除变量，或 `_ = 变量名` 标记为故意不用 |
| **高** | `UNUSED_PARAMETER` | 函数参数未使用 | 参数名前加 `_` 前缀（如 `_delta`） |
| **高** | `UNUSED_SIGNAL` | 声明了信号但未发射/连接 | 删除未使用的信号声明 |
| **中** | `NARROWING_CONVERSION` | 窄化转换（如 float→int 可能丢数据） | 显式 `int()` 转换，或检查类型 |
| **中** | `INTEGER_DIVISION` | 整数除法（如 `a / b` 两个都是 int） | 改为 `float(a) / b` 如果需要小数结果 |
| **中** | `RETURN_VALUE_DISCARDED` | 函数返回值被忽略 | 用 `_ = func()` 接收并丢弃，或检查是否需要返回值 |
| **中** | `SHADOWED_VARIABLE` | 变量遮蔽（内外同名） | 重命名变量 |
| **低** | `STANDALONE_EXPRESSION` | 独立表达式（无效果） | 删除或改为赋值/调用 |
| **低** | `UNREACHABLE_CODE` | 不可达代码 | 删除 |
| **低** | `UNUSED_PRIVATE_CLASS_VARIABLE` | 私有类变量未使用 | 删除 |

---

## 执行步骤

### Step 1：收集所有 Warnings

在 Godot 编辑器中运行项目（或命令行），收集完整警告列表：

```bash
# 命令行运行（输出 warnings 到日志）
godot --path . --headless 2>&1 | grep -i "warning"
```

或在 Godot 编辑器的 **底部面板 → 调试器 → 错误** 中查看所有 warnings。

将 warnings 按文件分类，格式：
```
文件:行号 | Warning类型 | 具体内容
```

### Step 2：按文件批量清理

对每个文件，按以下顺序处理：

#### 2a. 删除未使用的变量
```gdscript
# 旧代码
var temp_hp: int = 0
# 后续从未使用 temp_hp

# 修复：直接删除该行
```

#### 2b. 未使用的参数加 `_` 前缀
```gdscript
# 旧代码
func _process(delta: float) -> void:
    # delta 未使用

# 修复
func _process(_delta: float) -> void:
    ...
```

#### 2c. 整数除法改为浮点
```gdscript
# 旧代码
var ratio: float = hero_hp / max_hp   # 两个 int，结果是 int

# 修复
var ratio: float = float(hero_hp) / max_hp
```

#### 2d. 窄化转换显式处理
```gdscript
# 旧代码
var damage: int = base_damage * crit_multiplier   # float * float → 隐式转 int

# 修复
var damage: int = int(base_damage * crit_multiplier)
```

#### 2e. 丢弃返回值显式处理
```gdscript
# 旧代码
array.append(item)   # append 返回 bool，被忽略

# 修复
_ = array.append(item)
```

### Step 3：特殊文件处理

#### `run_main.gd` 常见 warnings
- `_on_rescue_partner_selected` 里的 `candidate` 变量可能未使用 → 检查是否确实需要
- `_show_modal_panel` 参数 `panel` 可能未使用 → 加 `_` 前缀或确认使用

#### `run_controller.gd` 常见 warnings
- `_run_battle_engine` 里的局部变量可能未使用
- 大量 `var result = ...` 但后续只用部分字段

#### `battle_animation_panel.gd` 常见 warnings
- 动画相关的临时变量
- `_show_damage_number` 里的 `tween` 变量（Tween 对象，可能需要引用保持）

#### `save_manager.gd` / `game_manager.gd` 常见 warnings
- 文件操作返回值未处理
- JSON 解析错误未处理

### Step 4：验证

每修改一个文件后，重新运行项目，确认该文件的 warnings 已清零，且没有引入新的运行时错误。

---

## 清理顺序建议

按文件优先级排序（从高频出现 warning 的文件开始）：

1. `scenes/run_main/run_main.gd` — UI 逻辑复杂，容易有未使用变量
2. `scenes/run_main/battle_animation_panel.gd` — 动画代码，临时变量多
3. `scripts/systems/run_controller.gd` — 战斗/流程控制，分支多
4. `scripts/systems/battle_playback_recorder.gd` — 回放逻辑
5. `autoload/save_manager.gd` — 存档逻辑
6. `autoload/game_manager.gd` — 场景切换
7. `scripts/systems/shop_system.gd` — 商店逻辑
8. `scripts/systems/pvp_director.gd` — PVP逻辑
9. `scripts/systems/event_forecast_system.gd` — 事件透视
10. `scripts/core/battle_engine.gd` — 战斗引擎

---

## 验收标准

- [ ] Godot 编辑器运行项目，warnings 数量从 ~170 降至 < 20（允许保留部分故意不用的变量）
- [ ] 游戏核心功能（爬塔/战斗/PVP/商店/档案）运行正常，无新增 bug
- [ ] 无运行时错误（红色报错）
- [ ] 代码编译无语法错误

---

## 注意事项

1. **不要无脑删除变量**：有些变量看似未使用，但可能是 `@onready var` 的节点引用，被其他函数隐式使用。删除前先确认。
2. **Tween 对象必须保持引用**：`var tween = create_tween()` 的 `tween` 变量如果删除，动画会立即停止。这种变量要保留，可以加 `_ = tween` 消除 warning，或改名为 `_tween`。
3. **信号声明不要删**：如果信号在运行时动态连接（如 `btn.pressed.connect(...)`），编辑器静态分析可能认为"未使用"，但实际上在用。这种信号保留。
4. **GDScript 的 `_` 前缀约定**：`_unused_var` 表示故意不使用的变量/参数，编辑器不会报 warning。
