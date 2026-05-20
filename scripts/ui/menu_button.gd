extends TextureButton

@export var hover_scale: float = 1.05
@export var press_offset: float = 3.0
@export var anim_duration: float = 0.15

var _tween: Tween


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_on_resized)
	pivot_offset = size / 2.0


func _on_resized() -> void:
	pivot_offset = size / 2.0


func _on_mouse_entered() -> void:
	_tween = _create_tween()
	_tween.tween_property(self, "scale", Vector2(hover_scale, hover_scale), anim_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	_tween = _create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, anim_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_button_down() -> void:
	position.y += press_offset


func _on_button_up() -> void:
	position.y -= press_offset


func _create_tween() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	return create_tween()
