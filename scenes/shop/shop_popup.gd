class_name ShopPopup
extends Control

@onready var overlay: ColorRect = $Overlay
@onready var item_container: VBoxContainer = $Overlay/Content/ItemContainer
@onready var leave_button: Button = $Overlay/Content/LeaveButton

func _ready() -> void:
	visible = false
	leave_button.pressed.connect(hide_popup)

func show_popup() -> void:
	visible = true

func hide_popup() -> void:
	visible = false
