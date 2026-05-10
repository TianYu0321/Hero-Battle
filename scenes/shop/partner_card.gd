## res://scenes/shop/partner_card.gd
## 模块: PartnerCard
## 职责: 局外商店伙伴卡片UI -- 显示单个伙伴的信息和价格
## 依赖: 无（纯UI组件）
## 被依赖: OutgameShop
## class_name: PartnerCard

class_name PartnerCard
extends PanelContainer

## 信号: 用户点击购买按钮
signal buy_pressed(partner_id: String)

## 节点引用
@onready var _icon_texture: TextureRect = %PartnerIcon
@onready var _name_label: Label = %PartnerNameLabel
@onready var _title_label: Label = %PartnerTitleLabel
@onready var _desc_label: Label = %PartnerDescLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _price_label: Label = %PriceLabel
@onready var _buy_btn: Button = %BuyButton
@onready var _owned_overlay: Panel = %OwnedOverlay

var _partner_id: String = ""
var _is_owned: bool = false
var _can_afford: bool = true

## ============================================================
## 生命周期
## ============================================================

func _ready() -> void:
	_buy_btn.pressed.connect(_on_buy_pressed)
	_reset_display()

func _exit_tree() -> void:
	## 断开信号
	if _buy_btn != null and _buy_btn.pressed.is_connected(_on_buy_pressed):
		_buy_btn.pressed.disconnect(_on_buy_pressed)
	## 断开所有buy_pressed连接
	for conn in buy_pressed.get_connections():
		buy_pressed.disconnect(conn.callable)

## ============================================================
## 数据设置
## ============================================================

## 设置伙伴显示数据
func set_partner_data(data: Dictionary) -> void:
	_partner_id = data.get("id", "")
	_name_label.text = data.get("name", _partner_id)
	_title_label.text = data.get("title", "")
	_desc_label.text = data.get("description", "")
	_rarity_label.text = _get_rarity_text(data.get("rarity", 1))
	_is_owned = data.get("is_owned", false)
	_update_owned_state()

## 设置价格显示
func set_price(price: int) -> void:
	_price_label.text = "%d魔城币" % price

## 设置是否买得起（影响按钮状态）
func set_can_afford(can_afford: bool) -> void:
	_can_afford = can_afford
	_update_button_state()

## 获取伙伴ID
func get_partner_id() -> String:
	return _partner_id

## ============================================================
## 内部方法
## ============================================================

func _on_buy_pressed() -> void:
	if _is_owned or not _can_afford:
		return
	buy_pressed.emit(_partner_id)

func _reset_display() -> void:
	_name_label.text = "???"
	_title_label.text = ""
	_desc_label.text = ""
	_rarity_label.text = ""
	_price_label.text = "100魔城币"
	_buy_btn.disabled = true
	_owned_overlay.visible = false

func _update_owned_state() -> void:
	_owned_overlay.visible = _is_owned
	_buy_btn.disabled = _is_owned or not _can_afford

func _update_button_state() -> void:
	_buy_btn.disabled = _is_owned or not _can_afford

func _get_rarity_text(rarity: int) -> String:
	match rarity:
		1: return "N"
		2: return "R"
		3: return "SR"
		4: return "SSR"
		_: return "?"

## ============================================================
## 公共接口
## ============================================================

## 清空卡片数据（用于刷新后）
func clear_data() -> void:
	_partner_id = ""
	_is_owned = false
	_can_afford = true
	_reset_display()

## 检查此卡片是否已绑定伙伴数据
func has_partner() -> bool:
	return not _partner_id.is_empty()

## 断开外部信号（由父节点调用）
func disconnect_signals() -> void:
	for conn in buy_pressed.get_connections():
		buy_pressed.disconnect(conn.callable)
