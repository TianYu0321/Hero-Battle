# Bug修复任务卡：PVP对手生成报错

> 错误：`Invalid call. Nonexistent function 'get' in base 'String'. res://scripts/systems/pvp_opponent_generator.gd`

---

## 根因

`virtual_archive_pool.gd` 加载虚拟档案时，`ModelsSerializer.load_json_file` 如果文件不存在或解析失败，可能返回 `String` 错误信息（而非 `Dictionary`）。`_virtual_archives` 数组因此可能包含 `String` 元素。

`find_opponent_for_floor` 随机选中了这个 `String`，传给 `generate_opponent_from_archive`，后者对 `String` 调用 `.get()` 报错。

---

## 修复

### 修复1：VirtualArchivePool 过滤非 Dictionary 档案（源头修复）

**文件：`scripts/systems/virtual_archive_pool.gd`**

```gdscript
func _load_virtual_archives() -> void:
    var dir_path: String = "res://resources/virtual_archives/"
    var dir: DirAccess = DirAccess.open(dir_path)
    if dir == null:
        push_warning("[VirtualArchivePool] 虚拟档案目录不存在: %s" % dir_path)
        return
    dir.list_dir_begin()
    var file_name: String = dir.get_next()
    while not file_name.is_empty():
        if file_name.ends_with(".json"):
            var file_path: String = dir_path + file_name
            var data = ModelsSerializer.load_json_file(file_path)
            # **关键修复**：只接受 Dictionary 类型
            if data is Dictionary and not data.is_empty():
                data["_source"] = "virtual"
                _virtual_archives.append(data)
                print("[VirtualArchivePool] 加载虚拟档案: %s" % file_name)
            else:
                push_warning("[VirtualArchivePool] 虚拟档案格式错误（非Dictionary）: %s" % file_name)
        file_name = dir.get_next()
    dir.list_dir_end()
    print("[VirtualArchivePool] 加载虚拟档案: %d个" % _virtual_archives.size())

func find_opponent_for_floor(floor: int) -> Dictionary:
    refresh_local_archives()
    var candidates: Array[Dictionary] = []
    
    # 从本地档案筛选
    for archive in _local_archives:
        if archive is Dictionary and archive.get("final_turn", 0) >= floor and archive.get("is_fixed", false):
            candidates.append(archive)
    
    # 从虚拟档案筛选（增加 is Dictionary 检查）
    for archive in _virtual_archives:
        if archive is Dictionary and archive.get("final_turn", 0) >= floor:
            candidates.append(archive)
    
    if candidates.is_empty():
        print("[VirtualArchivePool] 无匹配档案，返回空")
        return {}
    
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var idx: int = rng.randi() % candidates.size()
    var selected = candidates[idx]
    print("[VirtualArchivePool] 选中对手: %s (层数:%d, 来源:%s)" % [
        selected.get("hero_name", "???"),
        selected.get("final_turn", 0),
        selected.get("_source", "local")
    ])
    return selected
```

### 修复2：PvpOpponentGenerator 防御性检查

**文件：`scripts/systems/pvp_opponent_generator.gd`**

```gdscript
func generate_opponent_from_archive(archive_data: Dictionary, turn_number: int, player_state: Dictionary) -> Dictionary:
    # **防御性检查**
    if not archive_data is Dictionary:
        push_error("[PvpOpponentGenerator] archive_data 不是 Dictionary，fallback到AI生成")
        return generate_opponent(player_state, turn_number, false)
    
    print("[PvpOpponentGenerator] 从档案生成对手: %s" % archive_data.get("hero_name", "???"))
    ...
```

### 修复3：PvpOpponentGenerator 入口也加防御性检查

```gdscript
func generate_opponent(player_state: Dictionary, turn_number: int, use_archive: bool = true, archive_pool: VirtualArchivePool = null) -> Dictionary:
    # **防御性检查**
    if not player_state is Dictionary:
        push_error("[PvpOpponentGenerator] player_state 不是 Dictionary")
        player_state = {}
    
    if use_archive and archive_pool != null:
        var opponent_archive = archive_pool.find_opponent_for_floor(turn_number)
        # opponent_archive 可能是 {}（空Dictionary）或有效的Dictionary
        if opponent_archive is Dictionary and not opponent_archive.is_empty():
            return generate_opponent_from_archive(opponent_archive, turn_number, player_state)
        print("[PvpOpponentGenerator] 无档案匹配，fallback到AI生成")
    
    # fallback：原来的AI生成逻辑
    ...
```

---

## 验证方法

修复后，检查控制台输出：

1. 正常情况：`[VirtualArchivePool] 加载虚拟档案: 3个`，然后 `[VirtualArchivePool] 选中对手: XXX`
2. 如果虚拟档案格式错误：`[VirtualArchivePool] 虚拟档案格式错误（非Dictionary）: xxx.json`
3. PVP对手生成成功，不再报 `Nonexistent function 'get'` 错误

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/systems/virtual_archive_pool.gd` | `_load_virtual_archives` 增加 `data is Dictionary` 检查 |
| 2 | `scripts/systems/virtual_archive_pool.gd` | `find_opponent_for_floor` 增加 `archive is Dictionary` 检查 |
| 3 | `scripts/systems/pvp_opponent_generator.gd` | `generate_opponent_from_archive` 开头增加 `archive_data is Dictionary` 防御 |
| 4 | `scripts/systems/pvp_opponent_generator.gd` | `generate_opponent` 开头增加 `player_state is Dictionary` 防御 |

---

## 验收标准

- [ ] PVP对手生成不再报 `Nonexistent function 'get' in base 'String'`
- [ ] 控制台有 `[VirtualArchivePool] 加载虚拟档案: X个` 输出
- [ ] 如果虚拟档案JSON损坏/格式错误，控制台有警告但不崩溃
- [ ] 无匹配档案时正确fallback到AI生成
