class_name CombatConfirmPanel
extends Panel

signal confirmed
signal cancelled

@onready var silhouette_rect: ColorRect = $SilhouetteRect
@onready var enemy_name_label: Label = $EnemyNameLabel
@onready var confirm_button: Button = $ConfirmButton
@onready var cancel_button: Button = $CancelButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	visible = false

func _on_confirm() -> void:
	confirmed.emit()

func _on_cancel() -> void:
	cancelled.emit()

func set_enemy(enemy_name: String) -> void:
	enemy_name_label.text = "敌人: %s" % enemy_name
