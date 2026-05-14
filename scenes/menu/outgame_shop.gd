extends Control

class_name OutgameShop

## 局外商店 — TabContainer三标签页（英雄/伙伴/皮肤）
## 魔城币消费 + 解锁状态 + 确认弹窗

@onready var tab_container: TabContainer = $TabContainer
@onready var coin_label: Label = $CoinLabel
@onready var confirm_dialog: AcceptDialog = $ConfirmDialog

var _current_tab: String = "heroes"
var _selected_item: Dictionary = {}

func _ready() -> void:
	_update_coin_display()
	_refresh_all_tabs()
	
	# 标签切换
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# 确认弹窗
	confirm_dialog.confirmed.connect(_on_purchase_confirmed)
	confirm_dialog.canceled.connect(_on_purchase_cancelled)
	
	# 监听魔城币变化
	if EventBus != null:
		EventBus.currency_changed.connect(_on_currency_changed)

func _on_tab_changed(tab_index: int) -> void:
	match tab_index:
		0: _current_tab = "heroes"
		1: _current_tab = "partners"
		2: _current_tab = "skins"
	_refresh_current_tab()

func _refresh_all_tabs() -> void:
	_refresh_tab("heroes")
	_refresh_tab("partners")
	_refresh_tab("skins")

func _refresh_current_tab() -> void:
	_refresh_tab(_current_tab)

func _refresh_tab(category: String) -> void:
	var container := _get_tab_container(category)
	if container == null:
		return
	
	# 清空旧内容
	for child in container.get_children():
		child.queue_free()
	
	var items := MetaProgressionManager.get_shop_items(category)
	var coin := MetaProgressionManager.get_mocheng_coin()
	
	for item in items:
		var item_id: int = item.get("config_id", -1)
		var is_owned := _is_item_owned(category, item_id)
		var can_afford := coin >= item.get("unlock_cost", 999999) and not is_owned
		
		var item_button := _create_item_button(item, is_owned, can_afford)
		container.add_child(item_button)

func _create_item_button(item: Dictionary, is_owned: bool, can_afford: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 100)
	btn.disabled = not can_afford
	
	var name_str: String = item.get("name", "???")
	var cost: int = item.get("unlock_cost", 0)
	var desc: String = item.get("description", "")
	
	var status_text := ""
	if is_owned:
		status_text = " [已拥有]"
		btn.modulate = Color(0.7, 0.7, 0.7)
	elif cost == 0:
		status_text = " [免费]"
	else:
		status_text = " [%d魔城币]" % cost
	
	btn.text = name_str + status_text + "\n" + desc
	btn.pressed.connect(_on_item_pressed.bind(item))
	
	return btn

func _is_item_owned(category: String, item_id: int) -> bool:
	match category:
		"heroes":
			return MetaProgressionManager.is_hero_unlocked(item_id)
		"partners":
			return MetaProgressionManager.is_partner_unlocked(item_id)
		"skins":
			return MetaProgressionManager.is_skin_unlocked(item_id)
	return false

func _on_item_pressed(item: Dictionary) -> void:
	_selected_item = item
	var name_str: String = item.get("name", "???")
	var cost: int = item.get("unlock_cost", 0)
	var category: String = _current_tab
	
	if _is_item_owned(category, item.get("config_id", -1)):
		return  # 已拥有，不处理
	
	confirm_dialog.dialog_text = "确认购买 %s？\n需要 %d 魔城币" % [name_str, cost]
	confirm_dialog.popup_centered()

func _on_purchase_confirmed() -> void:
	if _selected_item.is_empty():
		return
	
	var cost: int = _selected_item.get("unlock_cost", 0)
	var item_id: int = _selected_item.get("config_id", -1)
	var category: String = _current_tab
	
	if not MetaProgressionManager.spend_mocheng_coin(cost):
		push_error("[OutgameShop] 购买失败：魔城币不足")
		return
	
	# 解锁
	match category:
		"heroes":
			MetaProgressionManager.unlock_hero(item_id)
		"partners":
			MetaProgressionManager.unlock_partner(item_id)
		"skins":
			MetaProgressionManager.unlock_skin(item_id)
	
	AudioManager.play_ui("purchase_success")
	_update_coin_display()
	_refresh_current_tab()
	print("[OutgameShop] 购买成功: %s (id=%d, cost=%d)" % [_selected_item.get("name"), item_id, cost])

func _on_purchase_cancelled() -> void:
	_selected_item = {}

func _update_coin_display() -> void:
	var coin := MetaProgressionManager.get_mocheng_coin()
	coin_label.text = "💰 魔城币: %d" % coin

func _on_currency_changed(new_amount: int, old_amount: int) -> void:
	_update_coin_display()
	_refresh_current_tab()

func _get_tab_container(category: String) -> Container:
	var tab_index := -1
	match category:
		"heroes": tab_index = 0
		"partners": tab_index = 1
		"skins": tab_index = 2
	
	if tab_index < 0:
		return null
	
	var tab := tab_container.get_tab_control(tab_index)
	if tab == null:
		return null
	
	# 查找 VBoxContainer 子节点
	for child in tab.get_children():
		if child is VBoxContainer or child is GridContainer:
			return child
	
	return null


func _on_back_button_pressed() -> void:
	AudioManager.play_ui("cancel")
	get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")

func _on_sync_button_pressed() -> void:
	AudioManager.play_ui("confirm")
	MetaProgressionManager.sync_to_server()
	print("[OutgameShop] 同步请求已发送")
