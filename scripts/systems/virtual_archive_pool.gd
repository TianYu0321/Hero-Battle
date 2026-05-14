class_name VirtualArchivePool
extends Node

var _virtual_archives: Array[Dictionary] = []
var _local_archives: Array[Dictionary] = []
var _shadows: Array = []  # Array of ShadowData
var _max_shadows_per_floor: int = 50

func _ready() -> void:
	_load_virtual_archives()
	load_shadows_from_disk()

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
			# 只接受 Dictionary 类型，防止格式错误数据进入数组
			if data is Dictionary and not data.is_empty():
				data["_source"] = "virtual"
				_virtual_archives.append(data)
				print("[VirtualArchivePool] 加载虚拟档案: %s" % file_name)
			else:
				push_warning("[VirtualArchivePool] 虚拟档案格式错误（非Dictionary）: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[VirtualArchivePool] 加载虚拟档案: %d个" % _virtual_archives.size())

func refresh_local_archives() -> void:
	_local_archives = SaveManager.load_archives("date", 9999, "")
	print("[VirtualArchivePool] 加载本地档案: %d个" % _local_archives.size())

func find_opponent_for_floor(_floor: int) -> Dictionary:
	refresh_local_archives()

	var candidates: Array[Dictionary] = []

	# 从本地档案筛选（final_turn >= _floor 且完整通关）
	for archive in _local_archives:
		if archive is Dictionary and archive.get("final_turn", 0) >= _floor and archive.get("is_fixed", false):
			candidates.append(archive)

	# 从虚拟档案筛选
	for archive in _virtual_archives:
		if archive is Dictionary and archive.get("final_turn", 0) >= _floor:
			candidates.append(archive)

	if candidates.is_empty():
		print("[VirtualArchivePool] 无匹配档案，返回空")
		return {}

	# 随机选一个
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var idx: int = rng.randi() % candidates.size()
	var selected: Dictionary = candidates[idx]
	print("[VirtualArchivePool] 选中对手: %s (层数:%d, 来源:%s)" % [
		selected.get("hero_name", "???"),
		selected.get("final_turn", 0),
		selected.get("_source", "local")
	])
	return selected

# ==================== 影子池 (Shadow Pool) ====================

func add_shadow(shadow) -> void:
	# 同层同用户去重：先删除旧影子
	_shadows = _shadows.filter(func(s): return not (s.user_id == shadow.user_id and s.floor == shadow.floor))
	_shadows.append(shadow)

	# 同层超过上限时，删除最旧的
	var floor_shadows := _shadows.filter(func(s): return s.floor == shadow.floor)
	if floor_shadows.size() > _max_shadows_per_floor:
		floor_shadows.sort_custom(func(a, b): return a.timestamp < b.timestamp)
		var oldest = floor_shadows[0]
		_shadows.erase(oldest)

	print("[VirtualArchivePool] 影子已添加: user=%s, floor=%d, 池大小=%d" % [shadow.user_id, shadow.floor, _shadows.size()])

func get_random_shadow_for_floor(floor: int, exclude_user_id: String = "") -> Object:
	var candidates := _shadows.filter(func(s): return s.floor == floor and s.user_id != exclude_user_id)
	if candidates.is_empty():
		return null

	# 加权随机：胜率高的影子更容易被匹配（增加挑战性）
	var total_weight: float = 0.0
	for s in candidates:
		total_weight += s.win_rate + 0.1  # +0.1避免0权重

	var roll := randf() * total_weight
	var cumulative: float = 0.0
	for s in candidates:
		cumulative += s.win_rate + 0.1
		if roll <= cumulative:
			return s

	return candidates[candidates.size() - 1]  # fallback

func get_shadow_count() -> int:
	return _shadows.size()

func get_shadow_count_for_floor(floor: int) -> int:
	var count: int = 0
	for s in _shadows:
		if s.floor == floor:
			count += 1
	return count

func get_shadow_pool_file_path(user_id: String = "") -> String:
	if user_id.is_empty():
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager")
		if sm != null:
			user_id = sm.get_user_id()
		else:
			user_id = "local_default"
	return "user://%s_shadow_pool.json" % user_id

func save_shadows_to_disk() -> void:
	var data: Array = []
	for s in _shadows:
		data.append(s.to_dict())
	var file_path: String = get_shadow_pool_file_path()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[VirtualArchivePool] 保存影子池失败: %s" % file_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[VirtualArchivePool] 影子池已保存: %d个 -> %s" % [_shadows.size(), file_path])

func load_shadows_from_disk() -> void:
	var file_path: String = get_shadow_pool_file_path()
	# 尝试迁移旧版全局影子池
	if not FileAccess.file_exists(file_path):
		var legacy_path: String = "user://shadow_pool.json"
		if FileAccess.file_exists(legacy_path):
			var leg_file := FileAccess.open(legacy_path, FileAccess.READ)
			if leg_file != null:
				var content: String = leg_file.get_as_text()
				leg_file.close()
				var new_file := FileAccess.open(file_path, FileAccess.WRITE)
				if new_file != null:
					new_file.store_string(content)
					new_file.close()
					print("[VirtualArchivePool] 影子池已从旧版迁移: %s -> %s" % [legacy_path, file_path])
	if not FileAccess.file_exists(file_path):
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		push_error("[VirtualArchivePool] 加载影子池失败")
		return
	var parsed: Variant = json.get_data()
	if not parsed is Array:
		return
	_shadows.clear()
	for entry in parsed:
		if entry is Dictionary:
			var sd = load("res://scripts/data/shadow_data.gd")
			_shadows.append(sd.from_dict(entry))
	print("[VirtualArchivePool] 影子池已加载: %d个" % _shadows.size())
