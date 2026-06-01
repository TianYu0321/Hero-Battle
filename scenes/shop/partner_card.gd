class_name PartnerCard
extends PanelContainer

signal buy_pressed(partner_key: String)

@onready var _card_bg: TextureRect = %CardBg
@onready var _name_label: Label = %NameLabel
@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _price_label: Label = %PriceLabel
@onready var _buy_button: Button = %BuyButton

var _partner_key: String = ""
var _is_owned: bool = false
var _can_afford: bool = false
var _price: int = 0


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	_refresh_button_state()


func set_partner_data(data: Dictionary) -> void:
	_partner_key = str(data.get("id", ""))
	_is_owned = data.get("is_owned", false)
	_name_label.text = data.get("name", "???")
	_title_label.text = data.get("title", "")
	_description_label.text = data.get("description", "")
	_card_bg.texture = ResourcePaths.load_texture_safe(ResourcePaths.get_partner_card_path(_partner_key, 1))
	_refresh_button_state()


func set_price(price: int) -> void:
	_price = price
	_price_label.text = "魔城币 %d" % _price


func set_can_afford(can_afford: bool) -> void:
	_can_afford = can_afford
	_refresh_button_state()


func _refresh_button_state() -> void:
	if not is_node_ready():
		return
	if _is_owned:
		_buy_button.text = "已拥有"
		_buy_button.disabled = true
		modulate = Color(0.65, 0.65, 0.65, 1.0)
		return
	_buy_button.text = "购买"
	_buy_button.disabled = not _can_afford
	modulate = Color.WHITE if _can_afford else Color(0.8, 0.8, 0.8, 1.0)


func _on_buy_pressed() -> void:
	if _partner_key.is_empty() or _is_owned or not _can_afford:
		return
	buy_pressed.emit(_partner_key)
