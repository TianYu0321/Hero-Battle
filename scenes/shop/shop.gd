class_name ShopScene
extends Control

@onready var _mojo_label: Label = %MojoCoinLabel
@onready var _partner_grid: GridContainer = %PartnerGrid
@onready var _back_btn: Button = %BackButton
@onready var _insufficient_label: Label = $InsufficientCoinLabel

var _partner_cards: Array[PartnerCard] = []
var _player_data: Dictionary = {}
var _shop_items: Array[Dictionary] = []

func _ready() -> void:
	_load_player_data()
	_load_shop_items()
	_render_shop()
	
	_back_btn.pressed.connect(_on_back_pressed)
	
	print("[ShopScene] Ready, items: %d, coins: %d" % [_shop_items.size(), _player_data.get("mocheng_coin", 0)])

func _load_player_data() -> void:
	_player_data = SaveManager.load_player_data()
	if _player_data.is_empty():
		_player_data = {
			"mocheng_coin": 0,
			"unlocked_partners": [],
		}

func _load_shop_items() -> void:
	var all_configs: Dictionary = ConfigManager.get_all_partner_configs()
	var unlocked: Array = _player_data.get("unlocked_partners", [])
	
	_shop_items.clear()
	for partner_key in all_configs.keys():
		var p: Dictionary = all_configs[partner_key]
		var pid: String = str(p.get("id", ""))
		var is_default_unlock: bool = p.get("is_default_unlock", false)
		var is_unlocked: bool = is_default_unlock or (pid in unlocked)
		var price: int = p.get("unlock_price_mocheng", 100)
		
		_shop_items.append({
			"partner_key": partner_key,
			"partner_id": pid,
			"name": p.get("name", "???"),
			"title": p.get("title", ""),
			"description": p.get("description", ""),
			"price": price,
			"is_unlocked": is_unlocked,
		})

func _render_shop() -> void:
	var coins: int = _player_data.get("mocheng_coin", 0)
	_mojo_label.text = "魔城币: %d" % coins
	
	# 清空旧卡片
	for card in _partner_cards:
		if card != null:
			card.queue_free()
	_partner_cards.clear()
	
	for item in _shop_items:
		var card: PartnerCard = preload("res://scenes/shop/partner_card.tscn").instantiate()
		_partner_grid.add_child(card)
		_partner_cards.append(card)
		
		card.set_partner_data({
			"id": item["partner_key"],
			"name": item["name"],
			"title": item["title"],
			"description": item["description"],
			"is_owned": item["is_unlocked"],
		})
		card.set_price(item["price"])
		card.set_can_afford(coins >= item["price"] and not item["is_unlocked"])
		card.buy_pressed.connect(_on_card_buy_pressed)

func _on_card_buy_pressed(partner_key: String) -> void:
	for item in _shop_items:
		if item.get("partner_key", "") == partner_key:
			_process_purchase(item)
			return

func _process_purchase(item: Dictionary) -> void:
	var price: int = item["price"]
	var pid: String = item["partner_id"]
	
	if item["is_unlocked"]:
		return
	
	if not SaveManager.spend_mocheng_coin(price):
		_insufficient_label.visible = true
		print("[ShopScene] 购买失败: 魔城币不足")
		return
	
	var unlocked: Array = _player_data.get("unlocked_partners", [])
	if not pid in unlocked:
		unlocked.append(pid)
	_player_data["unlocked_partners"] = unlocked
	SaveManager.save_player_data(_player_data)
	
	EventBus.partner_unlocked.emit(
		item["partner_key"],
		item["name"],
		-1,
		-1,
		"outgame_shop"
	)
	
	print("[ShopScene] 购买成功: %s, 花费%d魔城币" % [item["name"], price])
	
	_insufficient_label.visible = false
	_load_player_data()
	_load_shop_items()
	_render_shop()

func _on_back_pressed() -> void:
	EventBus.back_to_menu_requested.emit()
