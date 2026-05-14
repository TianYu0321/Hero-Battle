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
	
	# 使用 RunSnapshot 统一存档格式，同时保留原始数据中的额外字段（如 node_options）
	var snapshot = RunSnapshot.from_dict(run_data)
	var data: Dictionary = snapshot.to_dict()
	# 合并原始数据中的额外字段（RunSnapshot 未覆盖的字段）
	for key in run_data.keys():
		if not data.has(key):
			data[key] = run_data[key]
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
	
	print("[SaveManager] 存档已保存: %s" % file_path)
	print("[SaveManager] 内容预览: %s" % json_text.substr(0, 200))

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
	return is_valid_save(data) and data.get("run_status", 1) == 1

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
	
	var run_status = data.get("run_status", 1)
	if run_status != 1:
		print("[SaveManager] 最新存档已完成(run_status=%d)，不可继续" % run_status)
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

func get_archive_count() -> int:
	var file_path: String = ConfigManager.ARCHIVE_FILE
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		return 0
	var archives: Array = data.get("archives", [])
	return archives.size()


func get_archives_for_overwrite() -> Array[Dictionary]:
	var file_path: String = ConfigManager.ARCHIVE_FILE
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		return []
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


func overwrite_archive(index: int, new_archive: Dictionary) -> bool:
	var file_path: String = ConfigManager.ARCHIVE_FILE
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		return false
	var archives: Array = data.get("archives", [])
	if index < 0 or index >= archives.size():
		push_error("[SaveManager] 覆盖索引越界: %d, 总数: %d" % [index, archives.size()])
		return false

	new_archive["archive_id"] = archives[index].get("archive_id", _generate_archive_id())
	new_archive["created_at"] = Time.get_unix_time_from_system()
	new_archive["is_fixed"] = true
	archives[index] = new_archive
	data["last_updated"] = Time.get_unix_time_from_system()

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		EventBus.archive_generated.emit(new_archive)
		EventBus.archive_saved.emit(new_archive)
		print("[SaveManager] 覆盖档案成功, index=%d" % index)
		return true
	else:
		push_error("[SaveManager] 覆盖档案失败: 无法写入文件")
		return false


func clear_all_archives() -> void:
	var file_path: String = ConfigManager.ARCHIVE_FILE
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": _current_version, "archives": [], "last_updated": 0}, "\t"))
		file.close()
		print("[SaveManager] 已清空所有档案")
	else:
		push_error("[SaveManager] 清空档案失败: 无法写入文件")


func generate_fighter_archive(archive_data: Dictionary) -> Dictionary:
	var archive: Dictionary = archive_data.duplicate(true)
	if not archive.has("archive_id") or archive.get("archive_id", "").is_empty():
		archive["archive_id"] = _generate_archive_id()
	if not archive.has("created_at"):
		archive["created_at"] = Time.get_unix_time_from_system()
	archive["is_fixed"] = true
	# 初始化PVP字段（兼容旧档案）
	if not archive.has("net_wins"):
		archive["net_wins"] = 0
	if not archive.has("total_wins"):
		archive["total_wins"] = 0
	if not archive.has("total_losses"):
		archive["total_losses"] = 0

	var file_path: String = ConfigManager.ARCHIVE_FILE
	var existing: Dictionary = ModelsSerializer.load_json_file(file_path)
	if existing.is_empty():
		existing = {"version": _current_version, "archives": [], "last_updated": 0}
	if not existing.has("archives"):
		existing["archives"] = []

	var archives: Array = existing["archives"]

	# 清理：如果超过5个（旧数据/异常），保留最新的5个
	if archives.size() > 5:
		archives.sort_custom(func(a, b): return a.get("created_at", 0) > b.get("created_at", 0))
		archives.resize(5)
		print("[SaveManager] 档案数量超过5，已清理至最新的5个")

	# 如果未满5个，直接追加
	if archives.size() < 5:
		archives.append(archive)
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
	else:
		# 已满5个，不直接保存，返回特殊标记通知上层处理覆盖
		print("[SaveManager] 档案已满(5/5)，需要覆盖")
		return {"_needs_overwrite": true, "archive_data": archive}

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

func is_valid_save(save_data: Dictionary) -> bool:
	if save_data.is_empty():
		return false
	var required_fields = ["hero_config_id", "current_floor", "hero"]
	for field in required_fields:
		if not save_data.has(field):
			return false
	var floor = save_data.get("current_floor", 0)
	if floor < 1 or floor > 30:
		return false
	var hero = save_data.get("hero", {})
	if not hero.has("current_hp") or not hero.has("max_hp"):
		return false
	return true

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

func load_player_data() -> Dictionary:
	var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		data = {"mocheng_coin": 0, "unlocked_partners": [], "unlocked_heroes": ["hero_warrior"], "net_wins": 0, "total_wins": 0, "total_losses": 0, "pvp_wins_today": 0, "last_pvp_date": ""}
		if not data.has("unlocked_heroes"):
			data["unlocked_heroes"] = ["hero_warrior"]
	return data

func save_player_data(data: Dictionary) -> void:
	var file_path: String = ConfigManager.SAVE_DIR + "player_data.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func unlock_hero(hero_id: String) -> bool:
	var data = load_player_data()
	var unlocked: Array = data.get("unlocked_heroes", [])
	if not hero_id in unlocked:
		unlocked.append(hero_id)
		data["unlocked_heroes"] = unlocked
		save_player_data(data)
		print("[SaveManager] 解锁英雄: %s" % hero_id)
		return true
	return false

func update_archive(archive_id: String, new_data: Dictionary) -> bool:
	var file_path: String = ConfigManager.ARCHIVE_FILE
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		push_warning("[SaveManager] update_archive: archive file not found")
		return false
	var archives: Array = data.get("archives", [])
	for i in range(archives.size()):
		var entry: Dictionary = archives[i]
		if entry.get("archive_id", "") == archive_id:
			# 合并更新，保留不可变字段
			var updated: Dictionary = entry.duplicate(true)
			for key in new_data.keys():
				if key in ["archive_id", "created_at"]:
					continue
				updated[key] = new_data[key]
			archives[i] = updated
			data["last_updated"] = Time.get_unix_time_from_system()
			var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(data, "\t"))
				file.close()
				print("[SaveManager] 更新档案成功: %s" % archive_id)
				return true
			else:
				push_error("[SaveManager] 更新档案失败: 无法写入文件")
				return false
	push_warning("[SaveManager] update_archive: archive_id not found: %s" % archive_id)
	return false

# 兼容旧调用
func _load_player_data() -> Dictionary:
	return load_player_data()

func _save_player_data(data: Dictionary) -> void:
	save_player_data(data)


# ==================== 账号绑定系统 (Account-Bound Progression) ====================

var current_user_id: String = "local_default"

func set_user_id(user_id: String) -> void:
	current_user_id = user_id
	print("[SaveManager] 用户ID已设置: %s" % user_id)

func get_user_id() -> String:
	return current_user_id

# --- 魔城币（账号隔离）---
func save_mocheng_coin(amount: int, user_id: String = current_user_id) -> bool:
	var file_path: String = "user://%s_mocheng_coin.json" % user_id
	var data: Dictionary = {
		"user_id": user_id,
		"amount": amount,
		"timestamp": Time.get_unix_time_from_system()
	}
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 保存魔城币失败: %s" % file_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.mocheng_coin_changed.emit(amount)
	return true

func load_mocheng_coin(user_id: String = current_user_id) -> int:
	var file_path: String = "user://%s_mocheng_coin.json" % user_id
	if not FileAccess.file_exists(file_path):
		return 0
	var file := FileAccess.open(file_path, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result == OK:
		var data: Dictionary = json.get_data()
		if data.get("user_id", "") == user_id:
			return data.get("amount", 0)
	return 0

# --- 解锁状态（账号隔离）---
func save_unlock_state(
	unlocked_heroes: Array[int],
	unlocked_partners: Array[int],
	unlocked_skins: Array[int],
	user_id: String = current_user_id
) -> bool:
	var file_path: String = "user://%s_meta_progression.json" % user_id
	var data: Dictionary = {
		"user_id": user_id,
		"unlocked_heroes": unlocked_heroes,
		"unlocked_partners": unlocked_partners,
		"unlocked_skins": unlocked_skins,
		"last_save": Time.get_unix_time_from_system()
	}
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 保存解锁状态失败: %s" % file_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[SaveManager] 解锁状态已保存: %s" % file_path)

	# 同时更新旧版 player_data.json 以保持向后兼容
	_update_legacy_player_data(unlocked_heroes, unlocked_partners)
	return true

func load_unlock_state(user_id: String = current_user_id) -> Dictionary:
	var file_path: String = "user://%s_meta_progression.json" % user_id
	if not FileAccess.file_exists(file_path):
		# 尝试从旧版 player_data.json 迁移
		return _migrate_unlock_state_from_legacy(user_id)
	var file := FileAccess.open(file_path, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result == OK:
		var data: Dictionary = json.get_data()
		if data.get("user_id", "") == user_id:
			return data
	return _migrate_unlock_state_from_legacy(user_id)

func _migrate_unlock_state_from_legacy(user_id: String) -> Dictionary:
	var legacy: Dictionary = load_player_data()
	var unlocked_heroes: Array[int] = []
	var unlocked_partners: Array[int] = []
	var unlocked_skins: Array[int] = []

	# 迁移英雄解锁（字符串键 → 数字ID）
	for hero_key in legacy.get("unlocked_heroes", []):
		if hero_key is String:
			var cfg: Dictionary = ConfigManager.get_hero_config(hero_key)
			var hid: int = cfg.get("hero_id", 0)
			if hid > 0 and not hid in unlocked_heroes:
				unlocked_heroes.append(hid)

	# 迁移伙伴解锁（字符串数字 → 数字ID）
	for partner_str in legacy.get("unlocked_partners", []):
		var pid: int = int(str(partner_str))
		if pid > 0 and not pid in unlocked_partners:
			unlocked_partners.append(pid)

	# 如果 legacy 中没有任何解锁数据，设置默认
	if unlocked_heroes.is_empty():
		unlocked_heroes.append(1)  # 默认解锁勇者

	var result: Dictionary = {
		"user_id": user_id,
		"unlocked_heroes": unlocked_heroes,
		"unlocked_partners": unlocked_partners,
		"unlocked_skins": unlocked_skins,
		"last_save": 0
	}
	# 保存迁移后的数据
	save_unlock_state(unlocked_heroes, unlocked_partners, unlocked_skins, user_id)
	return result

func _update_legacy_player_data(unlocked_heroes: Array[int], unlocked_partners: Array[int]) -> void:
	var data: Dictionary = load_player_data()

	# 数字ID → 字符串键
	var hero_keys: Array = []
	for hid in unlocked_heroes:
		var key: String = ConfigManager.get_hero_id_by_config_id(hid)
		if not key.is_empty() and not key in hero_keys:
			hero_keys.append(key)
	data["unlocked_heroes"] = hero_keys

	# 数字ID → 字符串
	var partner_strs: Array = []
	for pid in unlocked_partners:
		var s: String = str(pid)
		if not s in partner_strs:
			partner_strs.append(s)
	data["unlocked_partners"] = partner_strs

	save_player_data(data)

# --- 每日计数器 ---
func get_daily_counter(key: String) -> int:
	var file_path: String = "user://%s_daily_counters.json" % current_user_id
	if not FileAccess.file_exists(file_path):
		return 0
	var file := FileAccess.open(file_path, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		return 0
	var data: Dictionary = json.get_data()
	var today: String = Time.get_date_string_from_system()
	var entry: Dictionary = data.get(key, {})
	if entry.get("date", "") != today:
		return 0
	return int(entry.get("count", 0))

func increment_daily_counter(key: String) -> void:
	var file_path: String = "user://%s_daily_counters.json" % current_user_id
	var data: Dictionary = {}
	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			data = json.get_data()
		file.close()

	var today: String = Time.get_date_string_from_system()
	var entry: Dictionary = data.get(key, {})
	if entry.get("date", "") != today:
		entry = {"date": today, "count": 0}
	entry["count"] = int(entry.get("count", 0)) + 1
	data[key] = entry

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

# 预留：服务器同步接口
func sync_mocheng_coin_to_server(user_id: String, amount: int) -> void:
	print("[SaveManager] 魔城币同步到服务器: user=%s, amount=%d" % [user_id, amount])

func sync_unlock_state_to_server(user_id: String, state: Dictionary) -> void:
	print("[SaveManager] 解锁状态同步到服务器: user=%s" % user_id)
