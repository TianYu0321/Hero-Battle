class_name ShopPopup
extends Control

@onready var _tab_container: TabContainer = $Content/VBoxContainer/TabContainer
@onready var _coin_label: Label = $Content/VBoxContainer/HeaderHBox/CoinLabel
@onready var _user_label: Label = $Content/VBoxContainer/HeaderHBox/UserLabel
@onready var _close_button: Button = $Content/VBoxContainer/HeaderHBox/CloseButton
@onready var _overlay: ColorRect = $Overlay
@onready var _content: Panel = $Content
@onready var _title_label: Label = $Content/VBoxContainer/HeaderHBox/TitleLabel

var _unlocked_heroes: Array = []
var _unlocked_partners: Array = []
var _current_coin: int = 0
var _current_user_id: String = "local_default"

signal closed

func _ready() -> void:
	visible = false
	_apply_outgame_style()
	_close_button.pressed.connect(hide_popup)
	# 移除不存在的皮肤页
	var skin_tab = _tab_container.get_node_or_null("皮肤")
	if skin_tab != null:
		skin_tab.queue_free()

func show_popup() -> void:
	visible = true
	refresh()

func hide_popup() -> void:
	for child in get_children():
		if child is Window:
			child.queue_free()
	visible = false
	closed.emit()

func refresh() -> void:
	_current_user_id = SaveManager.get_user_id()
	_load_unlock_state()
	_update_coin_display()
	_render_all_tabs()

func _load_unlock_state() -> void:
	var state := SaveManager.load_unlock_state(_current_user_id)
	_unlocked_heroes = state.get("unlocked_heroes", [1])
	_unlocked_partners = state.get("unlocked_partners", [])
	_current_coin = SaveManager.load_mocheng_coin(_current_user_id)

func _update_coin_display() -> void:
	_coin_label.text = "魔城币: %d" % _current_coin
	_user_label.text = "用户: %s" % _current_user_id

func _render_all_tabs() -> void:
	_render_hero_tab()
	_render_partner_tab()

func _render_hero_tab() -> void:
	var grid: GridContainer = _tab_container.get_node("英雄/ItemGrid")
	for child in grid.get_children():
		child.queue_free()
	
	var all_configs: Dictionary = ConfigManager.get_all_hero_configs()
	for hero_key in all_configs.keys():
		var cfg: Dictionary = all_configs[hero_key]
		var btn := _create_hero_button(hero_key, cfg)
		grid.add_child(btn)

func _render_partner_tab() -> void:
	var grid: GridContainer = _tab_container.get_node("伙伴/ItemGrid")
	for child in grid.get_children():
		child.queue_free()
	
	var all_configs: Dictionary = ConfigManager.get_all_partner_configs()
	for partner_key in all_configs.keys():
		var cfg: Dictionary = all_configs[partner_key]
		## 只显示商店可购买的伙伴（availability == "shop"）
		if cfg.get("availability", "hidden") != "shop":
			continue
		var btn := _create_partner_button(partner_key, cfg)
		grid.add_child(btn)

func _create_hero_button(hero_key: String, cfg: Dictionary) -> Button:
	var btn := Button.new()
	var hero_id: int = cfg.get("hero_id", 0)
	var hero_name: String = cfg.get("hero_name", "???")
	var desc: String = cfg.get("class_desc", "")
	var is_default: bool = cfg.get("is_default_unlock", false)
	var is_unlocked: bool = is_default or (hero_id in _unlocked_heroes)
	
	btn.text = "%s\n%s" % [hero_name, desc]
	btn.custom_minimum_size = Vector2(180, 132)
	btn.tooltip_text = desc
	OutgameUIStyle.apply_button(btn)
	
	if is_unlocked:
		btn.text += "\n已拥有"
		btn.modulate = Color(0.5, 0.5, 0.5)
		btn.disabled = true
	else:
		btn.text += "\n条件解锁"
		btn.disabled = true
	return btn

func _create_partner_button(partner_key: String, cfg: Dictionary) -> Button:
	var btn := Button.new()
	var pid: String = str(cfg.get("id", ""))
	var partner_name: String = cfg.get("name", "???")
	var desc: String = cfg.get("description", cfg.get("title", ""))
	var price: int = cfg.get("unlock_price_mocheng", 100)
	var is_default: bool = cfg.get("is_default_unlock", false)
	
	# 统一转字符串比较，避免 int/string 不匹配
	var unlocked_str: Array[String] = []
	for u in _unlocked_partners:
		unlocked_str.append(str(u))
	var is_unlocked: bool = is_default or (pid in unlocked_str)
	var can_afford: bool = _current_coin >= price
	
	btn.text = "%s\n魔城币 %d" % [partner_name, price]
	btn.custom_minimum_size = Vector2(180, 132)
	btn.tooltip_text = desc
	OutgameUIStyle.apply_button(btn, can_afford and not is_unlocked)
	
	if is_unlocked:
		btn.text += "\n已拥有"
		btn.modulate = Color(0.5, 0.5, 0.5)
		btn.disabled = true
	elif not can_afford:
		btn.modulate = Color(0.7, 0.3, 0.3)
		btn.disabled = true
	else:
		btn.pressed.connect(_on_purchase_requested.bind(partner_key, pid, price, partner_name))
	return btn

func _on_purchase_requested(partner_key: String, pid: String, cost: int, partner_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "确认购买"
	dialog.dialog_text = "花费 %d 魔城币购买 %s？" % [cost, partner_name]
	dialog.confirmed.connect(func():
		_confirm_purchase(pid, cost)
		if is_instance_valid(dialog):
			dialog.queue_free()
	)
	dialog.canceled.connect(func():
		if is_instance_valid(dialog):
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_purchase(pid: String, cost: int) -> void:
	if _current_coin < cost:
		return
	
	_current_coin -= cost
	SaveManager.save_mocheng_coin(_current_coin, _current_user_id)
	
	var unlocked: Array = SaveManager.load_unlock_state(_current_user_id).get("unlocked_partners", [])
	var unlocked_str: Array[String] = []
	for u in unlocked:
		unlocked_str.append(str(u))
	if not pid in unlocked_str:
		unlocked.append(int(pid) if pid.is_valid_int() else pid)
	
	SaveManager.save_unlock_state(_unlocked_heroes, unlocked, [], _current_user_id)
	_update_coin_display()
	_render_all_tabs()


func _apply_outgame_style() -> void:
	_overlay.color = Color(0, 0, 0, 0.72)
	OutgameUIStyle.apply_panel(_content, true)
	OutgameUIStyle.apply_label(_title_label, "title")
	OutgameUIStyle.apply_label(_coin_label, "section")
	OutgameUIStyle.apply_label(_user_label, "muted")
	OutgameUIStyle.apply_button(_close_button)
