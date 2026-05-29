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
	_migrate_old_saves()

func _ensure_save_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("[SaveManager] Cannot open user:// directory")
		return
	if not dir.dir_exists("saves"):
		var err: Error = dir.make_dir("saves")
		if err != OK:
			push_error("[SaveManager] Failed to create saves directory: %d" % err)

# ==========================================
# 新底层：加密 + 原子写入 + 备份 + 签名
# ==========================================

const ENCRYPTION_PASSWORD := "HeroBattle2025"
const CURRENT_SCHEMA_VERSION: int = 2  ## v2 = 加密格式
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".backup"

## 新文件路径（统一加密格式）
const RUN_FILE := "run.save"
const PLAYER_FILE := "player.save"
const SETTINGS_FILE := "settings.save"
const ARCHIVES_FILE := "archives.save"
const MochengCoin_FILE := "mocheng_coin.save"
const UNLOCK_STATE_FILE := "unlock_state.save"
const DAILY_COUNTERS_FILE := "daily_counters.save"

func _save_dict(file_name: String, data: Dictionary) -> bool:
	## 通用加密保存入口：深拷贝后注入 schema_version，原子写入
	var save_data: Dictionary = data.duplicate(true)
	save_data["schema_version"] = CURRENT_SCHEMA_VERSION
	return _write_encrypted(ConfigManager.SAVE_DIR + file_name, save_data)

func _load_dict(file_name: String) -> Dictionary:
	## 通用加密读取入口：自动校验签名 + Schema 迁移
	var file_path: String = ConfigManager.SAVE_DIR + file_name
	var data: Dictionary = _read_encrypted(file_path)
	if data.is_empty():
		return {}
	var schema: int = data.get("schema_version", 0)
	if schema < CURRENT_SCHEMA_VERSION:
		data = _migrate_data(data, schema, file_name)
	return data

func _write_encrypted(file_path: String, data: Dictionary) -> bool:
	## 1. JSON 序列化
	var json: String = JSON.stringify(data, "\t")
	## 2. 计算 MD5 签名
	var signature: String = json.md5_text()
	var payload: Dictionary = {"signature": signature, "data": data}
	var final_json: String = JSON.stringify(payload)
	## 3. 写入临时文件
	var temp_path: String = file_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open_encrypted_with_pass(temp_path, FileAccess.WRITE, ENCRYPTION_PASSWORD)
	if file == null:
		push_error("[SaveManager] Failed to open temp file for writing: %s" % temp_path)
		return false
	file.store_string(final_json)
	file.close()
	## 4. 原子替换：旧文件 → 备份，临时文件 → 正式文件
	if FileAccess.file_exists(file_path):
		var backup_path: String = file_path + BACKUP_SUFFIX
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var err2: Error = DirAccess.rename_absolute(file_path, backup_path)
		if err2 != OK:
			push_warning("[SaveManager] Failed to create backup: %d" % err2)
	## 5. 临时文件 → 正式文件
	var err: Error = DirAccess.rename_absolute(temp_path, file_path)
	if err != OK:
		push_error("[SaveManager] Failed to rename temp file: %d" % err)
		return false
	return true

func _read_encrypted(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, ENCRYPTION_PASSWORD)
	if file == null:
		push_error("[SaveManager] Failed to open file for reading: %s" % file_path)
		return {}
	var content: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or not (parsed is Dictionary):
		push_error("[SaveManager] Invalid save file format: %s" % file_path)
		return _try_backup_recovery(file_path)
	## 校验签名
	var stored_sig: String = parsed.get("signature", "")
	var data: Dictionary = parsed.get("data", {})
	var expected_sig: String = JSON.stringify(data).md5_text()
	if stored_sig != expected_sig:
		push_warning("[SaveManager] Save file signature mismatch: %s" % file_path)
		return _try_backup_recovery(file_path)
	return data

func _try_backup_recovery(file_path: String) -> Dictionary:
	var backup_path: String = file_path + BACKUP_SUFFIX
	if FileAccess.file_exists(backup_path):
		push_warning("[SaveManager] Attempting backup recovery: %s" % backup_path)
		return _read_encrypted(backup_path)
	return {}

func _migrate_data(data: Dictionary, old_schema: int, file_name: String) -> Dictionary:
	match file_name:
		RUN_FILE:
			if old_schema < 2:
				## v1→v2：旧明文JSON无额外字段需要迁移
				pass
		PLAYER_FILE:
			if old_schema < 2:
				pass
		_:
			pass
	data["schema_version"] = CURRENT_SCHEMA_VERSION
	return data

func save_run_state(run_data: Dictionary, is_auto: bool = true, _slot_id: int = 1, _user_id: String = current_user_id) -> bool:
	## 新实现：加密 + 原子写入
	var data: Dictionary = run_data.duplicate(true)
	data["timestamp"] = Time.get_unix_time_from_system()
	data["is_auto_save"] = is_auto
	
	var success := _save_dict(RUN_FILE, data)
	if success:
		print("[SaveManager] RUN存档已保存: %s" % RUN_FILE)
		EventBus.game_saved.emit(1, data["timestamp"], data.get("current_floor", 0), is_auto)
	else:
		EventBus.save_failed.emit(5001, "Failed to save run state", {"slot": 1})
	return success

func has_active_run(_user_id: String = current_user_id) -> bool:
	var data: Dictionary = _load_dict(RUN_FILE)
	if data.is_empty():
		## 尝试迁移旧版存档
		var migrated: bool = _migrate_old_saves()
		if migrated:
			data = _load_dict(RUN_FILE)
		if data.is_empty():
			return false
	return is_valid_save(data) and data.get("run_status", 1) == 1

func load_latest_run(_user_id: String = current_user_id) -> Dictionary:
	var data: Dictionary = _load_dict(RUN_FILE)
	if data.is_empty():
		var migrated: bool = _migrate_old_saves()
		if migrated:
			data = _load_dict(RUN_FILE)
		if data.is_empty():
			EventBus.load_failed.emit(4001, "No run save found", 1)
			return {}

	if not _validate_save_integrity(data):
		EventBus.load_failed.emit(4001, "Save file missing required fields", 1)
		return {}
	
	var run_status = data.get("run_status", 1)
	if run_status != 1:
		print("[SaveManager] 最新存档已完成(run_status=%d)，不可继续" % run_status)
		return {}

	EventBus.game_loaded.emit(data)
	return data

func _load_archive_data() -> Dictionary:
	var data: Dictionary = _load_dict(ARCHIVES_FILE)
	if data.is_empty():
		## 尝试从旧版迁移
		var legacy_path: String = ConfigManager.get_archive_file_path(current_user_id)
		if FileAccess.file_exists(legacy_path):
			var legacy: Dictionary = ModelsSerializer.load_json_file(legacy_path)
			if not legacy.is_empty():
				_save_dict(ARCHIVES_FILE, legacy)
				print("[SaveManager] 档案已从旧版迁移: %s -> %s" % [legacy_path, ARCHIVES_FILE])
				return legacy
		data = {"version": CURRENT_SCHEMA_VERSION, "archives": [], "last_updated": 0}
	if not data.has("archives"):
		data["archives"] = []
	return data

func get_archive_count() -> int:
	var data: Dictionary = _load_archive_data()
	var archives: Array = data.get("archives", [])
	return archives.size()


func get_archives_for_overwrite() -> Array[Dictionary]:
	var data: Dictionary = _load_archive_data()
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
	var data: Dictionary = _load_archive_data()
	var archives: Array = data.get("archives", [])
	if index < 0 or index >= archives.size():
		push_error("[SaveManager] 覆盖索引越界: %d, 总数: %d" % [index, archives.size()])
		return false

	new_archive["archive_id"] = archives[index].get("archive_id", _generate_archive_id())
	new_archive["created_at"] = Time.get_unix_time_from_system()
	new_archive["is_fixed"] = true
	archives[index] = new_archive
	data["last_updated"] = Time.get_unix_time_from_system()

	var success := _save_dict(ARCHIVES_FILE, data)
	if success:
		EventBus.archive_generated.emit(new_archive)
		EventBus.archive_saved.emit(new_archive)
		print("[SaveManager] 覆盖档案成功, index=%d" % index)
		return true
	else:
		push_error("[SaveManager] 覆盖档案失败: 无法写入文件")
		return false


func clear_all_archives() -> void:
	var success := _save_dict(ARCHIVES_FILE, {"version": CURRENT_SCHEMA_VERSION, "archives": [], "last_updated": 0})
	if success:
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

	var existing: Dictionary = _load_archive_data()

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
		existing["version"] = CURRENT_SCHEMA_VERSION

		var success := _save_dict(ARCHIVES_FILE, existing)
		if not success:
			push_error("[SaveManager] Failed to write archive file")

		EventBus.archive_generated.emit(archive)
		EventBus.archive_saved.emit(archive)
		return archive
	else:
		# 已满5个，不直接保存，返回特殊标记通知上层处理覆盖
		print("[SaveManager] 档案已满(5/5)，需要覆盖")
		return {"_needs_overwrite": true, "archive_data": archive}

func load_archives(sort_by: String = "date", limit: int = 100, filter_hero: String = "") -> Array[Dictionary]:
	var data: Dictionary = _load_archive_data()
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
	var new_amount: int = data.get("mocheng_coin", 0) + amount
	data["mocheng_coin"] = new_amount
	_save_player_data(data)
	# 同步到账号隔离的新存储，确保新旧系统数据一致
	save_mocheng_coin(new_amount)

func spend_mocheng_coin(amount: int) -> bool:
	var data: Dictionary = _load_player_data()
	var current: int = data.get("mocheng_coin", 0)
	if current < amount:
		return false
	var new_amount: int = current - amount
	data["mocheng_coin"] = new_amount
	_save_player_data(data)
	# 同步到账号隔离的新存储，确保新旧系统数据一致
	save_mocheng_coin(new_amount)
	return true

func load_player_data(_user_id: String = current_user_id) -> Dictionary:
	var data: Dictionary = _load_dict(PLAYER_FILE)
	if data.is_empty():
		## 尝试从旧版迁移
		var legacy_path: String = ConfigManager.SAVE_DIR + "player_data.json"
		if FileAccess.file_exists(legacy_path):
			data = ModelsSerializer.load_json_file(legacy_path)
			if not data.is_empty():
				_save_dict(PLAYER_FILE, data)
				DirAccess.remove_absolute(legacy_path)
				print("[SaveManager] 玩家数据已从旧版迁移")
		if data.is_empty():
			data = _create_default_player_data()
	if not data.has("unlocked_heroes"):
		data["unlocked_heroes"] = ["hero_warrior"]
	if not data.has("hero_best_scores"):
		data["hero_best_scores"] = {}
	if not data.has("achievements"):
		data["achievements"] = {}
	return data

func save_player_data(data: Dictionary, _user_id: String = current_user_id) -> void:
	_save_dict(PLAYER_FILE, data)

func _create_default_player_data() -> Dictionary:
	return {
		"mocheng_coin": 0,
		"unlocked_partners": [],
		"unlocked_heroes": ["hero_warrior"],
		"hero_best_scores": {},
		"net_wins": 0,
		"total_wins": 0,
		"total_losses": 0,
		"pvp_wins_today": 0,
		"last_pvp_date": "",
		"first_login": Time.get_unix_time_from_system(),
		"total_play_time": 0,
		"total_runs": 0,
		"total_victories": 0,
		"achievements": {},
		"pvp_history": [],
		"pvp_deck": {},
	}

func _migrate_run_state_from_legacy(_user_id: String) -> bool:
	## 旧版迁移已由 _migrate_old_saves() 统一处理
	return false

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


func unlock_achievement(achievement_id: String) -> bool:
	var data: Dictionary = load_player_data()
	var achievements: Dictionary = data.get("achievements", {})
	if not achievements.get(achievement_id, false):
		achievements[achievement_id] = true
		data["achievements"] = achievements
		save_player_data(data)
		print("[SaveManager] 解锁成就: %s" % achievement_id)
		return true
	return false


func get_achievements() -> Dictionary:
	return load_player_data().get("achievements", {})

func update_archive(archive_id: String, new_data: Dictionary) -> bool:
	var data: Dictionary = _load_archive_data()
	var archives: Array = data.get("archives", [])
	for i in range(archives.size()):
		var entry: Dictionary = archives[i]
		if entry.get("archive_id", "") == archive_id:
			## 合并更新，保留不可变字段
			var updated: Dictionary = entry.duplicate(true)
			for key in new_data.keys():
				if key in ["archive_id", "created_at"]:
					continue
				updated[key] = new_data[key]
			archives[i] = updated
			data["last_updated"] = Time.get_unix_time_from_system()
			var success := _save_dict(ARCHIVES_FILE, data)
			if success:
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
	var data: Dictionary = {
		"user_id": user_id,
		"amount": amount,
		"timestamp": Time.get_unix_time_from_system()
	}
	var success := _save_dict(MochengCoin_FILE, data)
	if not success:
		push_error("[SaveManager] 保存魔城币失败")
		return false
	EventBus.mocheng_coin_changed.emit(amount)
	## 同时同步到 player_data
	var legacy_data := load_player_data()
	legacy_data["mocheng_coin"] = amount
	save_player_data(legacy_data)
	return true

func load_mocheng_coin(_user_id: String = current_user_id) -> int:
	var data: Dictionary = _load_dict(MochengCoin_FILE)
	if data.is_empty():
		## 回退到 player_data
		return get_mocheng_coin()
	return data.get("amount", 0)

# --- 解锁状态（账号隔离）---
func save_unlock_state(
	unlocked_heroes: Array[int],
	unlocked_partners: Array[int],
	unlocked_skins: Array[int],
	user_id: String = current_user_id
) -> bool:
	var data: Dictionary = {
		"user_id": user_id,
		"unlocked_heroes": unlocked_heroes,
		"unlocked_partners": unlocked_partners,
		"unlocked_skins": unlocked_skins,
		"last_save": Time.get_unix_time_from_system()
	}
	var success := _save_dict(UNLOCK_STATE_FILE, data)
	if not success:
		push_error("[SaveManager] 保存解锁状态失败")
		return false
	print("[SaveManager] 解锁状态已保存")

	## 同时更新 player_data 以保持向后兼容
	_update_legacy_player_data(unlocked_heroes, unlocked_partners)
	return true

func load_unlock_state(_user_id: String = current_user_id) -> Dictionary:
	var data: Dictionary = _load_dict(UNLOCK_STATE_FILE)
	if data.is_empty():
		## 尝试从旧版迁移
		return _migrate_unlock_state_from_legacy(_user_id)
	return data

func _migrate_unlock_state_from_legacy(_user_id: String) -> Dictionary:
	var legacy: Dictionary = load_player_data()
	var unlocked_heroes: Array[int] = []
	var unlocked_partners: Array[int] = []
	var unlocked_skins: Array[int] = []

	## 迁移英雄解锁（字符串键 → 数字ID）
	for hero_key in legacy.get("unlocked_heroes", []):
		if hero_key is String:
			var cfg: Dictionary = ConfigManager.get_hero_config(hero_key)
			var hid: int = cfg.get("hero_id", 0)
			if hid > 0 and not hid in unlocked_heroes:
				unlocked_heroes.append(hid)

	## 迁移伙伴解锁（字符串数字 → 数字ID）
	for partner_str in legacy.get("unlocked_partners", []):
		var pid: int = int(str(partner_str))
		if pid > 0 and not pid in unlocked_partners:
			unlocked_partners.append(pid)

	## 如果 legacy 中没有任何解锁数据，设置默认
	if unlocked_heroes.is_empty():
		unlocked_heroes.append(1)  ## 默认解锁勇者

	var result: Dictionary = {
		"user_id": _user_id,
		"unlocked_heroes": unlocked_heroes,
		"unlocked_partners": unlocked_partners,
		"unlocked_skins": unlocked_skins,
		"last_save": 0
	}
	## 保存迁移后的数据
	save_unlock_state(unlocked_heroes, unlocked_partners, unlocked_skins, _user_id)
	return result

func _update_legacy_player_data(unlocked_heroes: Array[int], unlocked_partners: Array[int]) -> void:
	var data: Dictionary = load_player_data()

	## 数字ID → 字符串键
	var hero_keys: Array = []
	for hid in unlocked_heroes:
		var key: String = ConfigManager.get_hero_id_by_config_id(hid)
		if not key.is_empty() and not key in hero_keys:
			hero_keys.append(key)
	data["unlocked_heroes"] = hero_keys

	## 数字ID → 字符串
	var partner_strs: Array = []
	for pid in unlocked_partners:
		var s: String = str(pid)
		if not s in partner_strs:
			partner_strs.append(s)
	data["unlocked_partners"] = partner_strs

	save_player_data(data)

# --- 每日计数器 ---
func get_daily_counter(key: String) -> int:
	var data: Dictionary = _load_dict(DAILY_COUNTERS_FILE)
	if data.is_empty():
		return 0
	var today: String = Time.get_date_string_from_system()
	var entry: Dictionary = data.get(key, {})
	if entry.get("date", "") != today:
		return 0
	return int(entry.get("count", 0))

func increment_daily_counter(key: String) -> void:
	var data: Dictionary = _load_dict(DAILY_COUNTERS_FILE)
	var today: String = Time.get_date_string_from_system()
	var entry: Dictionary = data.get(key, {})
	if entry.get("date", "") != today:
		entry = {"date": today, "count": 0}
	entry["count"] = int(entry.get("count", 0)) + 1
	data[key] = entry
	_save_dict(DAILY_COUNTERS_FILE, data)

# 预留：服务器同步接口
func sync_mocheng_coin_to_server(user_id: String, amount: int) -> void:
	print("[SaveManager] 魔城币同步到服务器: user=%s, amount=%d" % [user_id, amount])

func sync_unlock_state_to_server(user_id: String, state: Dictionary) -> void:
	print("[SaveManager] 解锁状态同步到服务器: user=%s" % user_id)


# --- 设置持久化 ---
func save_settings(settings: Dictionary) -> void:
	_save_dict(SETTINGS_FILE, settings)

func load_settings() -> Dictionary:
	var data: Dictionary = _load_dict(SETTINGS_FILE)
	if data.is_empty():
		## 尝试从旧版迁移
		var legacy_path: String = "user://%s_settings.json" % current_user_id
		if FileAccess.file_exists(legacy_path):
			var file := FileAccess.open(legacy_path, FileAccess.READ)
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				data = json.get_data()
				_save_dict(SETTINGS_FILE, data)
				DirAccess.remove_absolute(legacy_path)
				print("[SaveManager] 设置已从旧版迁移")
			file.close()
	return data


func _migrate_old_saves() -> bool:
	## 启动时检查并迁移旧版明文存档到新版加密格式
	var migrated := false
	var old_files: Array[Dictionary] = [
		{"old": ConfigManager.SAVE_DIR + "%s_save_001.json" % current_user_id, "new": RUN_FILE},
		{"old": ConfigManager.SAVE_DIR + "save_001.json", "new": RUN_FILE},
		{"old": ConfigManager.SAVE_DIR + "player_data.json", "new": PLAYER_FILE},
		{"old": ConfigManager.SAVE_DIR + "%s_player_data.json" % current_user_id, "new": PLAYER_FILE},
		{"old": ConfigManager.SAVE_DIR + "archive.json", "new": ARCHIVES_FILE},
		{"old": ConfigManager.SAVE_DIR + "%s_archive.json" % current_user_id, "new": ARCHIVES_FILE},
		{"old": "user://%s_settings.json" % current_user_id, "new": SETTINGS_FILE},
		{"old": "user://%s_mocheng_coin.json" % current_user_id, "new": MochengCoin_FILE},
		{"old": "user://%s_meta_progression.json" % current_user_id, "new": UNLOCK_STATE_FILE},
		{"old": "user://%s_daily_counters.json" % current_user_id, "new": DAILY_COUNTERS_FILE},
		{"old": ConfigManager.get_archive_file_path(current_user_id), "new": ARCHIVES_FILE},
	]
	
	for mapping in old_files:
		var old_path: String = mapping["old"]
		var new_name: String = mapping["new"]
		if FileAccess.file_exists(old_path):
			## 如果新文件已存在，跳过（避免覆盖）
			if FileAccess.file_exists(ConfigManager.SAVE_DIR + new_name):
				continue
			## 某些旧文件在 user:// 根目录，需要确保 saves 目录存在
			_ensure_save_dir()
			var file := FileAccess.open(old_path, FileAccess.READ)
			if file == null:
				continue
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.get_data()
				if data is Dictionary:
					_save_dict(new_name, data)
					DirAccess.remove_absolute(old_path)
					print("[SaveManager] 旧存档已迁移: %s -> %s" % [old_path.get_file(), new_name])
					migrated = true
			file.close()
	
	return migrated
