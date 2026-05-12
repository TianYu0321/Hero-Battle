class_name RescuePopup
extends Control

func _ready() -> void:
	visible = false

func show_popup() -> void:
	visible = true

func hide_popup() -> void:
	visible = false
