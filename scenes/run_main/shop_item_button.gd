class_name ShopItemButton
extends Button

@onready var name_label: Label = $InfoContainer/NameLabel
@onready var level_label: Label = $InfoContainer/LevelLabel
@onready var price_label: Label = $PriceLabel

var item_data: Dictionary = {}
var is_sold_out: bool = false

func setup(item: Dictionary) -> void:
	item_data = item
	is_sold_out = false
	modulate = Color(1, 1, 1)
	
	var item_type = item.get("item_type", "")
	
	match item_type:
		"partner_upgrade":
			name_label.text = item.get("name", "???")
			var current_lv = item.get("current_level", 1)
			var next_lv = mini(5, current_lv + 1)
			level_label.text = "LV%d → LV%d" % [current_lv, next_lv]
	
	price_label.text = "%d金币" % item.get("price", 0)
	
	var can_afford = item.get("can_afford", true)
	var max_level_reached = item.get("current_level", 1) >= 5
	disabled = not can_afford or max_level_reached
	if disabled:
		modulate = Color(0.5, 0.5, 0.5)

func mark_sold_out() -> void:
	is_sold_out = true
	disabled = true
	name_label.text += " (已售出)"
	modulate = Color(0.3, 0.3, 0.3)
