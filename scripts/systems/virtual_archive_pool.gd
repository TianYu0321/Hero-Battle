class_name VirtualArchivePool
extends Node

var _virtual_archives: Array[Dictionary] = []
var _local_archives: Array[Dictionary] = []

func _ready() -> void:
	_load_virtual_archives()

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

func find_opponent_for_floor(floor: int) -> Dictionary:
	refresh_local_archives()

	var candidates: Array[Dictionary] = []

	# 从本地档案筛选（final_turn >= floor 且完整通关）
	for archive in _local_archives:
		if archive is Dictionary and archive.get("final_turn", 0) >= floor and archive.get("is_fixed", false):
			candidates.append(archive)

	# 从虚拟档案筛选
	for archive in _virtual_archives:
		if archive is Dictionary and archive.get("final_turn", 0) >= floor:
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
