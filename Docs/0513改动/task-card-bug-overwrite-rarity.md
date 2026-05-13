# Bug修复任务卡：覆盖存档失效 + 商店伙伴评级

---

## Bug 1：覆盖存档没有作用（一直在覆盖评级D的档案，覆盖不掉）

### 根因

`get_archives_for_overwrite()` 调用 `load_archives("date", ...)`，该函数会**按日期降序排序**档案数组。返回的 `index` 是**排序后**的索引。

但 `overwrite_archive()` 直接读取 `archive.json` 的原始 `archives` 数组，不做排序。如果 `archive.json` 中的原始顺序和 `load_archives` 排序后的顺序不一致，`archives[index]` 就不是用户选择的那条档案。

**举例**：
- archive.json 原始顺序：[D级(旧), B级, A级, S级, C级]
- `load_archives("date")` 排序后：[S级(新), A级, B级, C级, D级]
- `get_archives_for_overwrite` 返回 index: 0=S, 1=A, 2=B, 3=C, 4=D
- 用户选 index=4 (要覆盖 D级)
- `overwrite_archive(4, ...)` 读取原始 archives[4] = C级（不是D级！）
- 结果：C级被覆盖成新的，D级还在，用户感觉"覆盖不掉"

### 修复

**文件：`autoload/save_manager.gd`**

修改 `get_archives_for_overwrite()`，直接读取原始 `archive.json`，不做排序：

```gdscript
func get_archives_for_overwrite() -> Array[Dictionary]:
    var file_path: String = ConfigManager.ARCHIVE_FILE
    var data: Dictionary = ModelsSerializer.load_json_file(file_path)
    if data.is_empty():
        return []
    # **关键**：直接读取原始 archives 数组，不做排序！
    var archives: Array = data.get("archives", [])
    var result: Array[Dictionary] = []
    for i in range(archives.size()):
        var entry: Dictionary = archives[i]
        result.append({
            "index": i,
            "hero_name": entry.get("hero_name", "???"),
            "final_grade": entry.get("final_grade", "?"),
            "final_score": entry.get("final_score", 0),
            "final_turn": entry.get("final_turn", 0),
            "created_at": entry.get("created_at", 0),
        })
    return result
```

**同时**，为了用户体验，`show_dialog` 中的档案条目可以按日期排序显示（但不改变原始索引），在按钮 text 中显示排序序号而不是原始 index：

```gdscript
# archive_overwrite_dialog.gd 的 show_dialog
# 可选：按日期排序显示，但绑定原始 index
func show_dialog(archives: Array[Dictionary], new_archive: Dictionary) -> void:
    ...
    # 按日期降序排序显示（最新的在最上面）
    var sorted = archives.duplicate()
    sorted.sort_custom(func(a, b): return a.get("created_at", 0) > b.get("created_at", 0))
    
    for archive in sorted:
        var btn := Button.new()
        var original_index: int = archive.get("index", -1)
        ...
        btn.pressed.connect(_on_archive_selected.bind(original_index))
```

但更简单的是：保持原始顺序显示（先创建的先显示），用户选哪个就覆盖哪个，索引天然一致。

---

## Bug 2：商店里的伙伴显示评级（稀有度 N/R/SR/SSR）

### 根因

`partner_card.gd` 中代码端agent自行添加了 `_rarity_label` 和 `_get_rarity_text()` 方法，显示伙伴稀有度。v2.0规格书中**完全没有伙伴稀有度/评级**这个设定。这是代码端agent的"创作"。

### 修复

**文件：`scenes/shop/partner_card.gd`**

删除评级相关代码：

```gdscript
# 删除这行：
# @onready var _rarity_label: Label = %RarityLabel

# 删除 _get_rarity_text 方法：
# func _get_rarity_text(rarity: int) -> String:
#     match rarity:
#         1: return "N"
#         ...

# set_partner_data 中删除这行：
# _rarity_label.text = _get_rarity_text(data.get("rarity", 1))
```

**文件：`scenes/shop/shop.gd`**

`set_partner_data` 不再传 `rarity`：

```gdscript
card.set_partner_data({
    "id": item["partner_key"],
    "name": item["name"],
    "title": item["title"],
    "description": item["description"],
    # 删除这行：
    # "rarity": item["rarity"],
    "is_owned": item["is_unlocked"],
})
```

**文件：`scenes/shop/partner_card.tscn`**

如果场景中有 `RarityLabel` 节点，删除它。

**文件：`resources/configs/partner_configs.json`**

如果配置了 `rarity` 字段，可以保留（不影响功能），但 `shop.gd` 不再读取它。

---

## 文件修改清单

| # | 文件 | 修改内容 | Bug |
|:---:|:---|:---|:---:|
| 1 | `autoload/save_manager.gd` | `get_archives_for_overwrite()` 直接读取原始 `archives`，不做排序 | Bug 1 |
| 2 | `scenes/shop/partner_card.gd` | 删除 `_rarity_label` 引用、`_get_rarity_text` 方法、`set_partner_data` 中的评级设置 | Bug 2 |
| 3 | `scenes/shop/shop.gd` | `set_partner_data` 不再传 `rarity` | Bug 2 |
| 4 | `scenes/shop/partner_card.tscn` | 删除 `RarityLabel` 节点（如果存在） | Bug 2 |

---

## 验收标准

### Bug 1
- [ ] 有5个档案时，覆盖选择列表显示的档案和实际被覆盖的档案一致
- [ ] 选择覆盖"评级D的档案"后，该档案确实被新数据覆盖（D级消失，新档案出现）
- [ ] 覆盖后档案总数仍为5（不是6）

### Bug 2
- [ ] 商店伙伴卡片不显示任何评级/稀有度标识（N/R/SR/SSR）
- [ ] 伙伴卡片只显示：名称、称号、描述、价格/已拥有状态
- [ ] `partner_card.gd` 中搜索不到 `rarity` 或 `_get_rarity_text`
