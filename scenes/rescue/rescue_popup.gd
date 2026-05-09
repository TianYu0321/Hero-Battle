class_name RescuePopup
extends Control

@onready var overlay: ColorRect = $Overlay
@onready var candidate_slots: Array[Control] = [
	$Overlay/Content/Candidate1,
	$Overlay/Content/Candidate2,
	$Overlay/Content/Candidate3,
]

func _ready() -> void:
	visible = false

func show_popup() -> void:
	visible = true

func hide_popup() -> void:
	visible = false
