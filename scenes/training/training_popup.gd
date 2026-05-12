class_name TrainingPopup
extends Control

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
	close_button.pressed.connect(hide_popup)

func show_popup() -> void:
	visible = true

func hide_popup() -> void:
	visible = false

func _on_attr_button_pressed(_index: int) -> void:
	pass
