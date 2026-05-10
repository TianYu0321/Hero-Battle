## res://scripts/models/outgame_shop_model.gd
## 模块: OutgameShopModel
## 职责: 局外商店数据模型 -- 伙伴列表、魔城币、每日刷新
## 依赖: ConfigManager, EventBus, ModelsSerializer
## 被依赖: OutgameShopController
## class_name: OutgameShopModel

class_name OutgameShopModel
extends RefCounted

const _PARTNER_PRICE: int = 100       ## 每个伙伴100魔城币
const _DAILY_REFRESH_HOUR: int = 0    ## 每日0点刷新
const _PLAYER_DATA_FILE: String = "player_data.json"

var _available_partners: Array[String] = []      ## 当前可选伙伴ID列表
var _owned_partner_ids: Array[String] = []       ## 已拥有伙伴ID列表
var _mojo_coins: int = 0                         ## 当前魔城币
var _last_refresh_date: String = ""              ## 上次刷新日期(YYYY-MM-DD)
var _purchase_history: Array[Dictionary] = []    ## 购买历史
var _is_dirty: bool = false                      ## 数据是否已修改

## ============================================================
## 生命周期
## ============================================================

## 加载玩家数据（从player_data.json）
func load_player_data() -> void:
	var data: Dictionary = _load_player_data_from_disk()
	_owned_partner_ids = data.get("unlocked_partners", [])
	_mojo_coins = data.get("mocheng_coin", 0)
	_last_refresh_date = data.get("shop_last_refresh", "")
	_purchase_history = data.get("purchase_history", [])
	_available_partners = data.get("shop_available", [])

	## 首次打开或日期变更时自动刷新
	_check_daily_refresh()

## 检查每日刷新
func _check_daily_refresh() -> void:
	var today: String = Time.get_date_string_from_system()
	if _last_refresh_date != today:
		_refresh_shop()
		_last_refresh_date = today
		_save_to_disk()

## ============================================================
## 商店刷新
## ============================================================

## 刷新商店：随机4名未拥有伙伴
func _refresh_shop() -> void:
	## 获取所有可用伙伴ID
	var all_partners: Array[String] = ConfigManager.get_all_partner_ids()
	var candidates: Array[String] = []
	for pid: String in all_partners:
		if not pid in _owned_partner_ids:
			candidates.append(pid)

	## 随机打乱后取前4个
	candidates.shuffle()
	_available_partners = candidates.slice(0, 4)

	_is_dirty = true

## 手动刷新（玩家点击刷新按钮）
## v2: 手动刷新需消耗魔城币（可选功能，当前免费）
## @return: {success, error}
func manual_refresh() -> Dictionary:
	## 检查是否有足够的未拥有伙伴
	var all_partners: Array[String] = ConfigManager.get_all_partner_ids()
	var unowned_count: int = 0
	for pid: String in all_partners:
		if not pid in _owned_partner_ids:
			unowned_count += 1
	if unowned_count == 0:
		return {"success": false, "error": "所有伙伴已拥有，无可刷新伙伴"}

	_refresh_shop()
	_save_to_disk()
	return {"success": true}

## ============================================================
## 购买逻辑
## ============================================================

## 购买伙伴
## @return: {success, partner_id, remaining_coins, error}
func purchase_partner(partner_id: String) -> Dictionary:
	## 检查是否在可选列表
	if not partner_id in _available_partners:
		return {"success": false, "error": "该伙伴不在当前商店中"}

	## 检查是否已拥有
	if partner_id in _owned_partner_ids:
		return {"success": false, "error": "已拥有该伙伴"}

	## 检查魔城币
	if _mojo_coins < _PARTNER_PRICE:
		return {"success": false, "error": "魔城币不足（需要%d）" % _PARTNER_PRICE}

	## 扣除魔城币
	_mojo_coins -= _PARTNER_PRICE

	## 添加伙伴到已拥有列表
	_owned_partner_ids.append(partner_id)
	_available_partners.erase(partner_id)

	## 记录购买历史
	_purchase_history.append({
		"partner_id": partner_id,
		"price": _PARTNER_PRICE,
		"date": Time.get_datetime_string_from_system()
	})

	## 持久化
	_save_to_disk()

	return {
		"success": true,
		"partner_id": partner_id,
		"remaining_coins": _mojo_coins
	}

## ============================================================
## 持久化
## ============================================================

func _load_player_data_from_disk() -> Dictionary:
	var file_path: String = ConfigManager.SAVE_DIR + _PLAYER_DATA_FILE
	var data: Dictionary = ModelsSerializer.load_json_file(file_path)
	if data.is_empty():
		## 首次初始化
		data = {
			"mocheng_coin": 0,
			"unlocked_partners": [],
			"net_wins": 0,
			"shop_available": [],
			"shop_last_refresh": "",
			"purchase_history": []
		}
	return data

func _save_to_disk() -> void:
	var file_path: String = ConfigManager.SAVE_DIR + _PLAYER_DATA_FILE
	var data: Dictionary = _load_player_data_from_disk()

	## 合并修改后的数据
	data["mocheng_coin"] = _mojo_coins
	data["unlocked_partners"] = _owned_partner_ids
	data["shop_available"] = _available_partners
	data["shop_last_refresh"] = _last_refresh_date
	data["purchase_history"] = _purchase_history

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		_is_dirty = false
		## 同步通知SaveManager（如果其内部有缓存）
		EventBus.game_saved.emit(-1, Time.get_unix_time_from_system(), 0, true)
	else:
		push_error("[OutgameShopModel] Failed to write player data: %s" % file_path)

## ============================================================
## Getters
## ============================================================

func get_available_partners() -> Array[String]:
	return _available_partners.duplicate()

func get_mojo_coins() -> int:
	return _mojo_coins

func get_partner_price() -> int:
	return _PARTNER_PRICE

func is_partner_owned(partner_id: String) -> bool:
	return partner_id in _owned_partner_ids

func get_owned_partners() -> Array[String]:
	return _owned_partner_ids.duplicate()

func get_purchase_history() -> Array[Dictionary]:
	return _purchase_history.duplicate()

func get_last_refresh_date() -> String:
	return _last_refresh_date
