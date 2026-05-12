class_name ArchiveOverwriteDialog
extends Control

@onready var archive_list: VBoxContainer = $DialogPanel/ArchiveList
@onready var confirm_panel: HBoxContainer = $DialogPanel/ConfirmPanel
@onready var cancel_button: Button = $DialogPanel/CancelButton

var _archives: Array[Dictionary] = []
var _selected_index: int = -1
var _pending_new_archive: Dictionary = {}

signal archive_overwritten
signal cancelled

func _ready() -> void:
	confirm_panel.visible = false
	cancel_button.pressed.connect(_on_cancel)
	$DialogPanel/ConfirmPanel/YesButton.pressed.connect(_on_confirm_yes)
	$DialogPanel/ConfirmPanel/NoButton.pressed.connect(_on_confirm_no)

func show_dialog(archives: Array[Dictionary], new_archive: Dictionary) -> void:
	visible = true
	_archives = archives
	_pending_new_archive = new_archive
	_selected_index = -1
	confirm_panel.visible = false
	cancel_button.visible = true

	# 清空旧条目
	for child in archive_list.get_children():
		child.queue_free()

	# 生成档案条目
	for archive in archives:
		var btn := Button.new()
		var hero_name: String = archive.get("hero_name", "???")
		var grade: String = archive.get("final_grade", "?")
		var score: int = archive.get("final_score", 0)
		var turn: int = archive.get("final_turn", 0)
		btn.text = "%s  |  %s级  |  %d分  |  第%d层" % [hero_name, grade, score, turn]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_archive_selected.bind(archive.get("index", -1)))
		archive_list.add_child(btn)

func _on_archive_selected(index: int) -> void:
	_selected_index = index
	print("[OverwriteDialog] 选择覆盖目标: index=%d" % index)
	# 高亮选中的条目
	for i in range(archive_list.get_child_count()):
		var btn: Button = archive_list.get_child(i)
		btn.modulate = Color(1, 1, 1) if i == index else Color(0.7, 0.7, 0.7)

	# 显示确认面板
	confirm_panel.visible = true
	cancel_button.visible = false

func _on_confirm_yes() -> void:
	if _selected_index < 0:
		return
	print("[OverwriteDialog] 确认覆盖 index=%d" % _selected_index)
	var result = SaveManager.overwrite_archive(_selected_index, _pending_new_archive)
	if result:
		archive_overwritten.emit()
		visible = false
	else:
		push_error("[OverwriteDialog] 覆盖失败")

func _on_confirm_no() -> void:
	# 回到选择状态
	confirm_panel.visible = false
	cancel_button.visible = true
	_selected_index = -1
	for btn in archive_list.get_children():
		btn.modulate = Color(1, 1, 1)

func _on_cancel() -> void:
	cancelled.emit()
	visible = false
