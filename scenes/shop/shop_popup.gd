class_name ShopPopup
extends Control

@onready var _tab_container: TabContainer = $Content/VBoxContainer/TabContainer
@onready var _coin_label: Label = $Content/VBoxContainer/HeaderHBox/CoinLabel
@onready var _user_label: Label = $Content/VBoxContainer/HeaderHBox/UserLabel
@onready var _close_button: Button = $Content/VBoxContainer/HeaderHBox/CloseButton

var _shop_items: Dictionary = {}
var _unlocked_heroes: Array[int] = []
var _unlocked_partners: Array[int] = []
var _unlocked_skins: Array[int] = []
var _current_coin: int = 0
var _current_user_id: String = "local_default"

signal closed

func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide_popup)
	_load_shop_items()

func show_popup() -> void:
	visible = true
	refresh()

func hide_popup() -> void:
	visible = false
	closed.emit()

func refresh() -> void:
	_current_user_id = SaveManager.get_user_id()
	_load_unlock_state()
	_update_coin_display()
	_render_all_tabs()

func _load_shop_items() -> void:
	var file := FileAccess.open("res://resources/configs/shop_items.json", FileAccess.READ)
	if file == null:
		push_error("[ShopPopup] 无法读取 shop_items.json")
		return
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		push_error("[ShopPopup] 解析 shop_items.json 失败")
		return
	_shop_items = json.get_data() as Dictionary

func _load_unlock_state() -> void:
	var state := SaveManager.load_unlock_state(_current_user_id)
	_unlocked_heroes = state.get("unlocked_heroes", [1])
	_unlocked_partners = state.get("unlocked_partners", [])
	_unlocked_skins = state.get("unlocked_skins", [])
	_current_coin = SaveManager.load_mocheng_coin(_current_user_id)

func _update_coin_display() -> void:
	_coin_label.text = "💰 %d" % _current_coin
	_user_label.text = "用户: %s" % _current_user_id

func _render_all_tabs() -> void:
	_render_tab("英雄", _shop_items.get("heroes", []), _unlocked_heroes)
	_render_tab("伙伴", _shop_items.get("partners", []), _unlocked_partners)
	_render_tab("皮肤", _shop_items.get("skins", []), _unlocked_skins)

func _render_tab(tab_name: String, items: Array, unlocked: Array[int]) -> void:
	var grid: GridContainer = _tab_container.get_node("%s/ItemGrid" % tab_name)
	for child in grid.get_children():
		child.queue_free()
	for item in items:
		var btn := _create_item_button(item, unlocked)
		grid.add_child(btn)

func _create_item_button(item: Dictionary, unlocked: Array[int]) -> Button:
	var btn := Button.new()
	var id: int = item.get("id", 0)
	var cost: int = item.get("cost", 0)
	var is_owned: bool = id in unlocked
	var can_afford: bool = _current_coin >= cost

	var item_name: String = item.get("name", "???")
	var desc: String = item.get("desc", "")

	btn.text = "%s\n💰 %d" % [item_name, cost]
	btn.custom_minimum_size = Vector2(100, 120)
	btn.tooltip_text = desc

	if is_owned:
		btn.text += "\n✅ 已拥有"
		btn.modulate = Color(0.5, 0.5, 0.5)
		btn.disabled = true
	elif not can_afford:
		btn.modulate = Color(0.7, 0.3, 0.3)
		btn.disabled = true
	else:
		btn.pressed.connect(_on_purchase_requested.bind(item))
	return btn

func _on_purchase_requested(item: Dictionary) -> void:
	var cost: int = item.get("cost", 0)
	var item_name: String = item.get("name", "???")

	var dialog := AcceptDialog.new()
	dialog.title = "确认购买"
	dialog.dialog_text = "花费 %d 魔城币购买 %s？" % [cost, item_name]
	dialog.confirmed.connect(func():
		_confirm_purchase(item)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_purchase(item: Dictionary) -> void:
	var id: int = item.get("id", 0)
	var cost: int = item.get("cost", 0)
	var type: String = _get_item_type(id)

	if _current_coin < cost:
		return

	_current_coin -= cost
	SaveManager.save_mocheng_coin(_current_coin, _current_user_id)

	match type:
		"hero":
			if not id in _unlocked_heroes:
				_unlocked_heroes.append(id)
		"partner":
			if not id in _unlocked_partners:
				_unlocked_partners.append(id)
		"skin":
			if not id in _unlocked_skins:
				_unlocked_skins.append(id)

	SaveManager.save_unlock_state(_unlocked_heroes, _unlocked_partners, _unlocked_skins, _current_user_id)
	_update_coin_display()
	_render_all_tabs()

func _get_item_type(id: int) -> String:
	if id < 100:
		return "hero"
	elif id < 1000:
		return "partner"
	else:
		return "skin"
