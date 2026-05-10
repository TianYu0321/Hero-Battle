## res://scripts/systems/outgame_shop_controller.gd
## 模块: OutgameShopController
## 职责: 局外商店控制器 -- 协调Model和View，处理购买/刷新逻辑
## 依赖: OutgameShopModel, OutgameShop(ConfigManager, EventBus)
## 被依赖: GameManager或其他场景切换器
## class_name: OutgameShopController

class_name OutgameShopController
extends Node

var _model: OutgameShopModel = null
var _view: OutgameShop = null
var _is_initialized: bool = false

## ============================================================
## 生命周期
## ============================================================

## 初始化控制器（创建并加载Model）
func initialize() -> void:
	if _is_initialized:
		return
	_model = OutgameShopModel.new()
	_model.load_player_data()
	_is_initialized = true
	push_warning("[OutgameShopController] Initialized")

## 清理
func _exit_tree() -> void:
	close_shop()
	_model = null

## ============================================================
## 商店开关
## ============================================================

## 打开商店 -- 传入View实例，绑定信号，显示数据
func open_shop(view: OutgameShop) -> void:
	if not _is_initialized:
		initialize()

	_view = view

	## 连接View信号
	if not _view.purchase_requested.is_connected(_on_purchase_requested):
		_view.purchase_requested.connect(_on_purchase_requested)
	if not _view.refresh_requested.is_connected(_on_refresh_requested):
		_view.refresh_requested.connect(_on_refresh_requested)
	if not _view.close_requested.is_connected(_on_close_requested):
		_view.close_requested.connect(_on_close_requested)

	## 显示商店数据
	_refresh_view_display()
	push_warning("[OutgameShopController] Shop opened")

## 关闭商店 -- 断开所有信号，清理引用
func close_shop() -> void:
	if _view != null:
		## 安全断开信号
		if _view.purchase_requested.is_connected(_on_purchase_requested):
			_view.purchase_requested.disconnect(_on_purchase_requested)
		if _view.refresh_requested.is_connected(_on_refresh_requested):
			_view.refresh_requested.disconnect(_on_refresh_requested)
		if _view.close_requested.is_connected(_on_close_requested):
			_view.close_requested.disconnect(_on_close_requested)

		## 通知View清理自身
		_view.cleanup_and_close()
		_view = null

	push_warning("[OutgameShopController] Shop closed")

## ============================================================
## View显示更新
## ============================================================

## 刷新View显示（从Model获取最新数据推送到View）
func _refresh_view_display() -> void:
	if _view == null:
		return

	_view.display_shop({
		"partners": _get_partner_display_data(),
		"mojo_coins": _model.get_mojo_coins(),
		"price": _model.get_partner_price()
	})

## 从Model和ConfigManager构建伙伴展示数据
func _get_partner_display_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pid: String in _model.get_available_partners():
		var cfg: Dictionary = ConfigManager.get_partner_config(pid)
		result.append({
			"id": pid,
			"name": cfg.get("name", pid),
			"title": cfg.get("title", ""),
			"rarity": cfg.get("rarity", 1),
			"avatar": cfg.get("icon_path", ""),
			"favored_attr": cfg.get("favored_attr", 0),
			"description": cfg.get("description", ""),
			"price": _model.get_partner_price(),
			"is_owned": false   ## 已在_available_partners中筛选过未拥有的
		})
	return result

## ============================================================
## 信号处理
## ============================================================

## 处理购买请求
func _on_purchase_requested(partner_id: String) -> void:
	var result: Dictionary = _model.purchase_partner(partner_id)

	if result.success:
		## 发射全局事件
		EventBus.mojo_coin_spent.emit(_model.get_partner_price(), partner_id)
		var cfg: Dictionary = ConfigManager.get_partner_config(partner_id)
		EventBus.partner_unlocked.emit(
			partner_id,
			cfg.get("name", partner_id),
			-1,     ## slot: -1 表示局外解锁，非局内加入
			-1,     ## join_turn: -1 表示局外
			"outgame_shop"
		)
		push_warning("[OutgameShopController] Partner purchased: %s" % partner_id)
	else:
		push_warning("[OutgameShopController] Purchase failed: %s" % result.get("error", ""))

	## 更新View
	_view.show_purchase_result(result)
	_view.update_mojo_coins(_model.get_mojo_coins())

	## 如果购买成功，需要刷新伙伴列表显示（该伙伴从列表中移除）
	if result.success:
		_refresh_view_display()

## 处理刷新请求
func _on_refresh_requested() -> void:
	var result: Dictionary = _model.manual_refresh()
	if result.success:
		push_warning("[OutgameShopController] Shop refreshed manually")
		_refresh_view_display()
	else:
		_view.show_refresh_result(result)

## 处理关闭请求
func _on_close_requested() -> void:
	close_shop()
