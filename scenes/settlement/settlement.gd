class_name Settlement
extends Control

@onready var rating_label: Label = $RatingLabel
@onready var attr_labels: Array[Label] = [
	$AttrSnapshot/AttrLabel1,
	$AttrSnapshot/AttrLabel2,
	$AttrSnapshot/AttrLabel3,
	$AttrSnapshot/AttrLabel4,
	$AttrSnapshot/AttrLabel5,
]
@onready var archive_button: Button = $ArchiveButton
@onready var menu_button: Button = $MenuButton
@onready var view_archive_button: Button = $ViewArchiveButton
@onready var saved_hint_label: Label = $SavedHintLabel

var _archive_data: Dictionary = {}
var _archive_saved: bool = false

func _ready() -> void:
	archive_button.pressed.connect(_on_archive_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	if view_archive_button != null:
		view_archive_button.pressed.connect(_on_view_archive_button_pressed)
		view_archive_button.visible = false
	if saved_hint_label != null:
		saved_hint_label.visible = false

	# --- EventBus 信号订阅 ---
	EventBus.archive_saved.connect(_on_archive_saved)

	# 尝试从 GameManager 获取本次运行的档案数据
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and not gm.pending_archive.is_empty():
		_archive_data = gm.pending_archive.duplicate()
		_populate_from_data(_archive_data)
	else:
		#  fallback: 使用硬编码占位数据
		rating_label.text = "S"
		for i in range(attr_labels.size()):
			attr_labels[i].text = "属性%d: 50" % (i + 1)

func populate(archive: Dictionary) -> void:
	_archive_data = archive.duplicate()
	_populate_from_data(_archive_data)

func _populate_from_data(data: Dictionary) -> void:
	rating_label.text = data.get("final_grade", data.get("rating", "S"))
	var attr_names: Array[String] = ["体魄", "力量", "敏捷", "技巧", "精神"]
	var attrs: Array[int] = [
		data.get("attr_snapshot_vit", 50),
		data.get("attr_snapshot_str", 50),
		data.get("attr_snapshot_agi", 50),
		data.get("attr_snapshot_tec", 50),
		data.get("attr_snapshot_mnd", 50),
	]
	for i in range(min(attr_labels.size(), attrs.size())):
		attr_labels[i].text = "%s: %d" % [attr_names[i], attrs[i]]

func _on_archive_button_pressed() -> void:
	if _archive_data.is_empty():
		push_warning("[Settlement] No archive data available")
		return
	var saved: Dictionary = SaveManager.generate_fighter_archive(_archive_data)
	_archive_saved = true
	if saved_hint_label != null:
		saved_hint_label.text = "档案已保存"
		saved_hint_label.visible = true
	if view_archive_button != null:
		view_archive_button.visible = true
	archive_button.disabled = true

func _on_view_archive_button_pressed() -> void:
	EventBus.archive_view_requested.emit("")

func _on_menu_button_pressed() -> void:
	EventBus.back_to_menu_requested.emit()

# --- EventBus 信号处理 ---
# archive_saved 信号作为额外保险：即使档案从其他模块保存，
# 结算界面也会自动更新为"已保存"状态。

func _on_archive_saved(archive_data: Dictionary) -> void:
	if _archive_saved:
		return
	_archive_saved = true
	if saved_hint_label != null:
		saved_hint_label.text = "档案已保存"
		saved_hint_label.visible = true
	if view_archive_button != null:
		view_archive_button.visible = true
	if archive_button != null:
		archive_button.disabled = true
	print("[Settlement] 收到 archive_saved 信号，档案ID: %s" % archive_data.get("archive_id", "unknown"))
