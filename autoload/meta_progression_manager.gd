extends Node

class_name MetaProgressionManager

## 局外养成系统 — 魔城币 + 解锁状态 + 账号绑定
## 独立于爬塔存档，user_id 隔离数据

var _user_id: String = "local_default"
var _mocheng_coin: int = 0
var _unlocked_heroes: Array[int] = [1]  # 默认解锁英雄1
var _unlocked_partners: Array[int] = []
var _unlocked_skins: Array[int] = []
var _best_score: int = 0
var _total_runs: int = 0

const META_FILE_TEMPLATE: String = "user://{user_id}_meta.json"
const SHOP_ITEMS_PATH: String = "res://resources/configs/shop_items.json"

var _shop_items: Dictionary = {}

func _ready() -> void:
	_load_shop_config()
	_load_meta()
	print("[MetaProgression] 初始化完成，user_id=%s，魔城币=%d" % [_user_id, _mocheng_coin])


## ===== 账号绑定 =====

func set_user_id(new_id: String) -> void:
	if new_id == _user_id:
		return
	# 保存旧用户数据
	_save_meta()
	# 切换用户
	_user_id = new_id
	_load_meta()
	print("[MetaProgression] 切换用户: %s，魔城币=%d" % [_user_id, _mocheng_coin])

func get_user_id() -> String:
	return _user_id


## ===== 魔城币 =====

func get_mocheng_coin() -> int:
	return _mocheng_coin

func add_mocheng_coin(amount: int) -> void:
	if amount <= 0:
		return
	_mocheng_coin += amount
	_save_meta()
	print("[MetaProgression] 魔城币 +%d = %d" % [amount, _mocheng_coin])

func spend_mocheng_coin(amount: int) -> bool:
	if amount <= 0:
		return false
	if _mocheng_coin < amount:
		print("[MetaProgression] 魔城币不足: %d < %d" % [_mocheng_coin, amount])
		return false
	_mocheng_coin -= amount
	_save_meta()
	print("[MetaProgression] 魔城币 -%d = %d" % [amount, _mocheng_coin])
	return true


## ===== 解锁状态 =====

func is_hero_unlocked(hero_config_id: int) -> bool:
	return _unlocked_heroes.has(hero_config_id)

func unlock_hero(hero_config_id: int) -> void:
	if not _unlocked_heroes.has(hero_config_id):
		_unlocked_heroes.append(hero_config_id)
		_save_meta()

func is_partner_unlocked(partner_config_id: int) -> bool:
	return _unlocked_partners.has(partner_config_id)

func unlock_partner(partner_config_id: int) -> void:
	if not _unlocked_partners.has(partner_config_id):
		_unlocked_partners.append(partner_config_id)
		_save_meta()

func is_skin_unlocked(skin_id: int) -> bool:
	return _unlocked_skins.has(skin_id)

func unlock_skin(skin_id: int) -> void:
	if not _unlocked_skins.has(skin_id):
		_unlocked_skins.append(skin_id)
		_save_meta()

func get_unlocked_heroes() -> Array[int]:
	return _unlocked_heroes.duplicate()

func get_unlocked_partners() -> Array[int]:
	return _unlocked_partners.duplicate()


## ===== 统计 =====

func record_run(score: int, reached_floor: int) -> void:
	_total_runs += 1
	if score > _best_score:
		_best_score = score
	_save_meta()
	print("[MetaProgression] 记录通关: score=%d, floor=%d, total_runs=%d, best=%d" % [score, reached_floor, _total_runs, _best_score])

func get_best_score() -> int:
	return _best_score

func get_total_runs() -> int:
	return _total_runs


## ===== 商店配置 =====

func _load_shop_config() -> void:
	var file := FileAccess.open(SHOP_ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_error("[MetaProgression] 商店配置文件不存在: %s" % SHOP_ITEMS_PATH)
		return
	var json_str := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_str)
	if parse_result != OK:
		push_error("[MetaProgression] 商店配置解析失败: %s" % json.get_error_message())
		return
	
	_shop_items = json.data
	print("[MetaProgression] 加载商店配置: heroes=%d, partners=%d, skins=%d" % [
		_shop_items.get("heroes", []).size(),
		_shop_items.get("partners", []).size(),
		_shop_items.get("skins", []).size()
	])

func get_shop_items(category: String) -> Array:
	return _shop_items.get(category, [])

func get_item_by_id(category: String, id: int) -> Dictionary:
	var items := get_shop_items(category)
	for item in items:
		if item.get("config_id", -1) == id:
			return item
	return {}


## ===== 持久化 =====

func _get_meta_file_path() -> String:
	return META_FILE_TEMPLATE.format({"user_id": _user_id})

func _save_meta() -> void:
	var data := {
		"user_id": _user_id,
		"mocheng_coin": _mocheng_coin,
		"unlocked_heroes": _unlocked_heroes,
		"unlocked_partners": _unlocked_partners,
		"unlocked_skins": _unlocked_skins,
		"best_score": _best_score,
		"total_runs": _total_runs,
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
	}
	
	var file_path := _get_meta_file_path()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[MetaProgression] 无法写入元数据文件: %s" % file_path)
		return
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[MetaProgression] 元数据已保存: %s" % file_path)

func _load_meta() -> void:
	var file_path := _get_meta_file_path()
	if not FileAccess.file_exists(file_path):
		print("[MetaProgression] 元数据文件不存在，使用默认值: %s" % file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[MetaProgression] 无法读取元数据文件: %s" % file_path)
		return
	
	var json_str := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_str)
	if parse_result != OK:
		push_error("[MetaProgression] 元数据解析失败: %s" % json.get_error_message())
		return
	
	var data := json.data
	_mocheng_coin = data.get("mocheng_coin", 0)
	_unlocked_heroes = data.get("unlocked_heroes", [1])
	_unlocked_partners = data.get("unlocked_partners", [])
	_unlocked_skins = data.get("unlocked_skins", [])
	_best_score = data.get("best_score", 0)
	_total_runs = data.get("total_runs", 0)
	print("[MetaProgression] 元数据已加载: 魔城币=%d, heroes=%s, partners=%s" % [
		_mocheng_coin, _unlocked_heroes, _unlocked_partners
	])


## ===== 服务器同步（预留接口） =====

func sync_to_server() -> void:
	## 预留：未来将本地数据同步到服务器
	## 调用时机：登录成功、手动同步按钮、每日首次启动
	push_warning("[MetaProgression] sync_to_server() 尚未实现")

func sync_from_server() -> void:
	## 预留：从服务器拉取最新数据（覆盖本地）
	## 调用时机：登录成功、数据冲突时
	push_warning("[MetaProgression] sync_from_server() 尚未实现")
