## res://autoload/save_manager.gd
## 模块: SaveManager
## 职责: 本地JSON存档读写，斗士档案生成与持久化
## 依赖: ConfigManager（引用数据结构）
## 被依赖: RunController, MenuUI
## class_name: SaveManager

extends Node

const _REQUIRED_SAVE_FIELDS: Array[String] = [
	"version",
	"hero_config_id",
	"current_floor",
]

var _current_version: int = 1

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("[SaveManager] Cannot open user:// directory")
		return
	if not dir.dir_exists("saves"):
		var err: Error = dir.make_dir("saves")
		if err != OK:
			push_error("[SaveManager] Failed to create saves directory: %d" % err)

func save_run_state(run_data: Dictionary, is_auto: bool = true) -> bool:
	var slot_id: int = 1
	var file_path: String = ConfigManager.SAVE_DIR + "save_%03d.json" % slot_id
	
	# 使用 RunSnapshot 统一存档格式
	var snapshot = RunSnapshot.from_dict(run_data)
	var data: Dictionary = snapshot.to_dict()
	data["timestamp"] = Time.get_unix_time_from_system()
	data["is_auto_save"] = is_auto

	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open file for writing: %s" % file_path)
		EventBus.save_failed.emit(FileAccess.get_open_error(), "Failed to open save file", {"slot": slot_id})
		return false

	file.store_string(json_text)
	file.close()

	EventBus.game_saved.emit(slot_id, data["timestamp"], data.get("current_floor", 0), is_auto)
	return true

func has_active_run() -> bool:
	print("[SaveManager] has_active_run 被调用")
	var latest_path: String = ""
	var latest_time: int = 0
	var dir: DirAccess = DirAccess.open(ConfigManager.SAVE_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("save_") and file_name.ends_with(".json"):
			var path: String = ConfigManager.SAVE_DIR + file_name
			var modified: int = FileAccess.get_modified_time(path)
			if modified > latest_time:
				latest_time = modified
				latest_path = path
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if latest_path.is_empty():
		print("[SaveManager] 检查结果: false (无存档文件)")
		return false
	
	var data = ModelsSerializer.load_json_file(latest_path)
	if data == null or data.is_empty():
		print("[SaveManager] 检查结果: false (存档为空)")
		return false
	
	var has_hero = data.has("hero_config_id") or data.has("hero_id")
	var has_floor = data.has("current_floor") and data.get("current_floor", 0) > 0
	var has_turn = data.has("current_turn") and data.get("current_turn", 0) > 0
	
	print("[SaveManager] 存档检查: has_hero=", has_hero, ", has_floor=", has_floor or has_turn, ", floor=", data.get("current_floor", data.get("current_turn", 0)))
	var result = has_hero and (has_floor or has_turn)
	print("[SaveManager] 检查结果: ", result)
	return result

func load_latest_run() -> Dictionary:
	var latest_path: String = ""
	var latest_time: int = 0
	var dir: DirAccess = DirAccess.open(ConfigManager.SAVE_DIR)
	if dir == null:
		push_warning("[SaveManager] Save directory not found")
		return {}

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("save_") and file_name.ends_with(".json"):
			var path: String = ConfigManager.SAVE_DIR + file_name
			var modified: int = FileAccess.get_modified_time(path)
			if modified > latest_time:
				latest_time = modified
				latest_path = path
		file_name = dir.get_next()
	dir.list_dir_end()

	if latest_path.is_empty():
		return {}

	var data: Dictionary = ModelsSerializer.load_json_file(latest_path)
	if data.is_empty():
		EventBus.load_failed.emit(4001, "Corrupt or empty save file", 1)
		return {}

	if not _validate_save_integrity(data):
		EventBus.load_failed.emit(4001, "Save file missing required fields", 1)
		return {}

	var version: int = data.get("version", 0)
	if version != _current_version:
		push_warning("[SaveManager] Save version mismatch: expected %d, got %d" % [_current_version, version])
		# 未来可在此添加版本升级/降级逻辑
		if version > _current_version:
			push_error("[SaveManager] Save version newer than game version, cannot load")
			EventBus.load_failed.emit(4002, "Save version newer than game", 1)
			return {}

	EventBus.game_loaded.emit(data)
	return data

func generate_fighter_archive(archive_data: Dictionary) -> Dictionary:
	var archive: Dictionary = archive_data.duplicate(true)
	if not archive.has("archive_id") or archive.get("archive_id", "").is_empty():
		archive["archive_id"] = _generate_archive_id()
	if not archive.has("created_at"):
		archive["created_at"] = Time.get_unix_time_from_system()
	archive["is_fixed"] = true

	var file_path: String = ConfigManager.ARCHIVE_FILE
	var existing: Dictionary = ModelsSerializer.load_json_file(file_path)
	if existing.is_empty():
		existing = {"version": _current_version, "archives": [], "last_updated": 0}
	if not existing.has("archives"):
		existing["archives"] = []
	existing["archives"].append(archive)
	existing["last_updated"] = Time.get_unix_time_from_system()
	existing["version"] = _current_version

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()
	else:
		push_error("[SaveManager] Failed to write archive file")

	EventBus.archive_generated.emit(archive)
	EventBus.archive_saved.emit(archive)
	return archive

func load_archives(sort_by: String = "date", limit: int = 100, filter_hero: String = "") -> Array[Dictionary]:
	var file_path: String = ConfigManager.ARCHIVE_FILE
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		data = {"archives": []}
	var archives: Array = data.get("archives", [])
	var result: Array[Dictionary] = []
	for entry in archives:
		if entry is Dictionary and entry.get("is_fixed", false):
			# 按主角名称过滤
			if not filter_hero.is_empty():
				var hero_name: String = entry.get("hero_name", "")
				if hero_name != filter_hero:
					continue
			result.append(entry)

	# 排序
	match sort_by:
		"score":
			result.sort_custom(func(a, b): return a.get("final_score", 0) > b.get("final_score", 0))
		"grade":
			var grade_order: Dictionary = {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1, "": 0}
			result.sort_custom(func(a, b): return grade_order.get(a.get("final_grade", ""), 0) > grade_order.get(b.get("final_grade", ""), 0))
		_:
			# 默认按日期降序（最新的在前面）
			result.sort_custom(func(a, b): return a.get("created_at", 0) > b.get("created_at", 0))

	return result.slice(0, limit)

func _validate_save_integrity(save_data: Dictionary) -> bool:
	for field in _REQUIRED_SAVE_FIELDS:
		if not save_data.has(field):
			push_warning("[SaveManager] Save missing required field: %s" % field)
			return false
	return true

func _generate_archive_id() -> String:
	var timestamp: int = Time.get_unix_time_from_system()
	var random_part: int = randi() % 10000
	return "ARC_%d_%04d" % [timestamp, random_part]

## 魔城币相关
func get_mocheng_coin() -> int:
	var data: Dictionary = _load_player_data()
	return data.get("mocheng_coin", 0)

func add_mocheng_coin(amount: int) -> void:
	var data: Dictionary = _load_player_data()
	data["mocheng_coin"] = data.get("mocheng_coin", 0) + amount
	_save_player_data(data)

func spend_mocheng_coin(amount: int) -> bool:
	var data: Dictionary = _load_player_data()
	var current: int = data.get("mocheng_coin", 0)
	if current < amount:
		return false
	data["mocheng_coin"] = current - amount
	_save_player_data(data)
	return true

func _load_player_data() -> Dictionary:
	var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		data = {"mocheng_coin": 0, "unlocked_partners": [], "net_wins": 0}
	return data

func _save_player_data(data: Dictionary) -> void:
	var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
