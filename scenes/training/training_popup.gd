class_name TrainingPopup
extends Control

signal attr_selected(attr_type: int)
signal cancelled()

@onready var attr_buttons: Array[Button] = [
	$Overlay/Content/AttrButton1,
	$Overlay/Content/AttrButton2,
	$Overlay/Content/AttrButton3,
	$Overlay/Content/AttrButton4,
	$Overlay/Content/AttrButton5,
]
@onready var close_button: Button = $Overlay/Content/CloseButton

func _ready() -> void:
	visible = false
	for i in range(attr_buttons.size()):
		attr_buttons[i].pressed.connect(_on_attr_button_pressed.bind(i))
	close_button.pressed.connect(_on_close_pressed)

func show_popup() -> void:
	visible = true

func hide_popup() -> void:
	visible = false

func _on_attr_button_pressed(index: int) -> void:
	var attr_type: int = index + 1  # 1=体魄, 2=力量, 3=敏捷, 4=技巧, 5=精神
	attr_selected.emit(attr_type)
	hide_popup()

func _on_close_pressed() -> void:
	cancelled.emit()
	hide_popup()
