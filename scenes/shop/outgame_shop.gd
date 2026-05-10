## res://scenes/shop/outgame_shop.gd
## 模块: OutgameShop
## 职责: 局外商店UI -- 纯View层，只负责显示和用户交互
## 依赖: PartnerCard, ConfigManager
## 被依赖: OutgameShopController
## class_name: OutgameShop

class_name OutgameShop
extends Control

## ============================================================
## 信号
## ============================================================

## 用户请求购买某伙伴
signal purchase_requested(partner_id: String)
## 用户请求刷新商店
signal refresh_requested()
## 用户请求关闭商店
signal close_requested()

## ============================================================
## 节点引用 (@onready, 通过%UniqueName)
## ============================================================

@onready var _title_label: Label = %TitleLabel
@onready var _mojo_label: Label = %MojoCoinLabel
@onready var _partner_grid: GridContainer = %PartnerGrid
@onready var _refresh_btn: Button = %RefreshButton
@onready var _close_btn: Button = %CloseButton

## 伙伴卡片引用数组
var _partner_cards: Array[PartnerCard] = []

## ============================================================
## 生命周期
## ============================================================

func _ready() -> void:
	## 收集所有伙伴卡片引用
	for i in range(_partner_grid.get_child_count()):
		var child = _partner_grid.get_child(i)
		if child is PartnerCard:
			_partner_cards.append(child)
			## 连接购买信号（带索引绑定）
			child.buy_pressed.connect(_on_card_buy_pressed)

	## 连接顶部按钮信号
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	_close_btn.pressed.connect(_on_close_pressed)

	push_warning("[OutgameShop] View ready, cards: %d" % _partner_cards.size())

func _exit_tree() -> void:
	## 确保所有信号断开
	_cleanup_signals()

## ============================================================
## 公共接口（由Controller调用）
## ============================================================

## 显示商店数据
## @param data: {partners: Array[Dictionary], mojo_coins: int, price: int}
func display_shop(data: Dictionary) -> void:
	var partners: Array = data.get("partners", [])
	var coins: int = data.get("mojo_coins", 0)
	var price: int = data.get("price", 100)

	## 更新魔城币显示
	_update_mojo_coins(coins)

	## 更新每个卡片
	var card_count: int = _partner_cards.size()
	for i in range(card_count):
		var card: PartnerCard = _partner_cards[i]
		if i < partners.size():
			var p: Dictionary = partners[i]
			card.visible = true
			card.set_partner_data(p)
			card.set_price(price)
			card.set_can_afford(coins >= price)
		else:
			## 没有足够伙伴时隐藏多余卡片
			card.visible = false
			card.clear_data()

	push_warning("[OutgameShop] Displayed %d partners, coins: %d" % [partners.size(), coins])

## 显示购买结果
## @param result: {success, partner_id, remaining_coins, error}
func show_purchase_result(result: Dictionary) -> void:
	if result.success:
		var pid: String = result.get("partner_id", "")
		var cfg: Dictionary = ConfigManager.get_partner_config(pid)
		var name: String = cfg.get("name", pid)
		print("[OutgameShop] 购买成功: %s" % name)
		## TODO: 播放成功动画/音效
	else:
		var error: String = result.get("error", "未知错误")
		print("[OutgameShop] 购买失败: %s" % error)
		## TODO: 显示错误提示弹窗

## 显示刷新结果
func show_refresh_result(result: Dictionary) -> void:
	if not result.success:
		var error: String = result.get("error", "刷新失败")
		print("[OutgameShop] 刷新失败: %s" % error)

## 更新魔城币显示
func update_mojo_coins(coins: int) -> void:
	_update_mojo_coins(coins)
	## 同时更新所有卡片的可购买状态
	var price: int = 100
	if _partner_cards.size() > 0:
		## 从当前可见卡片获取价格（假设统一价格）
		var card = _partner_cards[0]
		if card.has_partner():
			for c in _partner_cards:
				if c.visible and c.has_partner():
					c.set_can_afford(coins >= price)

## 清理并关闭（由Controller调用）
func cleanup_and_close() -> void:
	_cleanup_signals()
	visible = false

## ============================================================
## 私有方法
## ============================================================

func _update_mojo_coins(coins: int) -> void:
	_mojo_label.text = "魔城币: %d" % coins

func _on_card_buy_pressed(partner_id: String) -> void:
	purchase_requested.emit(partner_id)

func _on_refresh_pressed() -> void:
	refresh_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

## 清理所有信号连接
func _cleanup_signals() -> void:
	## 断开刷新按钮
	if _refresh_btn != null and _refresh_btn.pressed.is_connected(_on_refresh_pressed):
		_refresh_btn.pressed.disconnect(_on_refresh_pressed)

	## 断开关闭按钮
	if _close_btn != null and _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.disconnect(_on_close_pressed)

	## 断开所有卡片信号
	for card in _partner_cards:
		if card != null:
			if card.buy_pressed.is_connected(_on_card_buy_pressed):
				card.buy_pressed.disconnect(_on_card_buy_pressed)
			card.disconnect_signals()

	## 断开自身发出的信号（外部连接）
	for conn in purchase_requested.get_connections():
		purchase_requested.disconnect(conn.callable)
	for conn in refresh_requested.get_connections():
		refresh_requested.disconnect(conn.callable)
	for conn in close_requested.get_connections():
		close_requested.disconnect(conn.callable)
